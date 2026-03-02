--procedure for approving blood requests by admin
CREATE OR REPLACE PROCEDURE approve_blood_request(
    p_request_id  INT,
    p_admin_id    INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    -- Request details
    v_blood_group     blood_group_type;
    v_component_type  component_type;
    v_quantity        DECIMAL(5,2);
    v_request_status  request_status;

    -- Stock details
    v_total_available DECIMAL(5,2);
    v_stock_id        INT;
BEGIN
    -- ─── Step 1: Get request details ───
    SELECT
        blood_group,
        component_type,
        quantity,
        status
    INTO
        v_blood_group,
        v_component_type,
        v_quantity,
        v_request_status
    FROM blood_request
    WHERE request_id = p_request_id;

    -- ─── Step 2: Check request exists ───
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Request ID % not found', p_request_id;
    END IF;

    -- ─── Step 3: Check request is still PENDING ───
    -- Another admin might have already handled it
    IF v_request_status != 'PENDING' THEN
        RAISE EXCEPTION 'Request ID % is already %',
            p_request_id, v_request_status;
    END IF;

    -- ─── Step 4: Check total available stock ───
    SELECT COALESCE(SUM(available_units), 0)
    INTO v_total_available
    FROM blood_stock
    WHERE blood_group = v_blood_group
    AND component_type = v_component_type;

    -- ─── Step 5: Reject if insufficient stock ───
    IF v_total_available < v_quantity THEN
        UPDATE blood_request
        SET
            status          = 'REJECTED',
            rejected_reason = 'Stock depleted during processing'
        WHERE request_id = p_request_id;

        RAISE NOTICE 'Request % rejected: insufficient stock', 
            p_request_id;
        RETURN;
    END IF;

    -- ─── Step 6: Lock oldest batch (FIFO) ───
    -- SELECT FOR UPDATE locks this row so no other
    -- admin can take from it simultaneously
    SELECT stock_id
    INTO v_stock_id
    FROM blood_stock
    WHERE blood_group = v_blood_group
    AND component_type = v_component_type
    AND available_units > 0
    ORDER BY expiry_date ASC              -- oldest batch first (FIFO)
    LIMIT 1
    FOR UPDATE;                           -- row level lock

    -- ─── Step 7: Subtract units from stock ───
    UPDATE blood_stock
    SET available_units = available_units - v_quantity
    WHERE stock_id = v_stock_id;
    -- Trigger 4 fires here automatically
    -- updating last_updated timestamp

    -- ─── Step 8: Update request to APPROVED ───
    UPDATE blood_request
    SET status = 'APPROVED'
    WHERE request_id = p_request_id;

    -- ─── Step 9: Log to stock_transaction ───
    INSERT INTO stock_transaction
        (stock_id, admin_id, request_id, quantity, action)
    VALUES
        (v_stock_id, p_admin_id, p_request_id, 
         v_quantity, 'REQUEST_FULFILLED');

    RAISE NOTICE 'Request % approved successfully. % units of % % subtracted from batch %',
        p_request_id, v_quantity, v_blood_group, 
        v_component_type, v_stock_id;

-- ─── Error handling: auto rollback on failure ───
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error approving request %: %', 
        p_request_id, SQLERRM;
    RAISE;
END;

-- procedure for rejecting blood requests by admin
CREATE OR REPLACE PROCEDURE reject_blood_request(
    p_request_id  INT,
    p_admin_id    INT,
    p_reason      VARCHAR(255)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_request_status request_status;
BEGIN
    -- ─── Step 1: Check request exists and is PENDING ───
    SELECT status
    INTO v_request_status
    FROM blood_request
    WHERE request_id = p_request_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Request ID % not found', p_request_id;
    END IF;

    IF v_request_status != 'PENDING' THEN
        RAISE EXCEPTION 'Request ID % is already %',
            p_request_id, v_request_status;
    END IF;

    -- ─── Step 2: Update request to REJECTED ───
    UPDATE blood_request
    SET
        status          = 'REJECTED',
        rejected_reason = p_reason
    WHERE request_id = p_request_id;

    RAISE NOTICE 'Request % rejected by Admin %. Reason: %',
        p_request_id, p_admin_id, p_reason;

EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error rejecting request %: %',
        p_request_id, SQLERRM;
    RAISE;
END;
$$;


-- Procedure to add new blood stock by admin
CREATE OR REPLACE PROCEDURE add_blood_stock(
    p_blood_group    blood_group_type,
    p_component_type component_type,
    p_units          DECIMAL(5,2),
    p_admin_id       INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_stock_id   INT;
    v_expiry_date DATE;
BEGIN
    -- ─── Step 1: Validate units > 0 ───
    IF p_units <= 0 THEN
        RAISE EXCEPTION 'Units must be greater than 0';
    END IF;

    -- ─── Step 2: Insert new batch into blood_stock ───
    -- Trigger 2 (trg_set_expiry_date) fires automatically
    -- and sets expiry_date based on component_type
    INSERT INTO blood_stock
        (blood_group, component_type, available_units)
    VALUES
        (p_blood_group, p_component_type, p_units)
    RETURNING stock_id, expiry_date
    INTO v_stock_id, v_expiry_date;

    -- ─── Step 3: Log to stock_transaction ───
    INSERT INTO stock_transaction
        (stock_id, admin_id, request_id, quantity, action)
    VALUES
        (v_stock_id, p_admin_id, NULL, 
         p_units, 'DONATION_ADD');

    RAISE NOTICE 'Stock added successfully. Batch ID: %, 
        Blood Group: %, Component: %, Units: %, Expires: %',
        v_stock_id, p_blood_group, p_component_type,
        p_units, v_expiry_date;

EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error adding stock: %', SQLERRM;
    RAISE;
END;
$$;

-- Procedure to manually adjust stock units by admin
CREATE OR REPLACE PROCEDURE manual_stock_adjustment(
    p_stock_id   INT,
    p_new_units  DECIMAL(5,2),
    p_admin_id   INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_old_units  DECIMAL(5,2);
    v_difference DECIMAL(5,2);
BEGIN
    -- ─── Step 1: Validate new units >= 0 ───
    IF p_new_units < 0 THEN
        RAISE EXCEPTION 'Units cannot be negative';
    END IF;

    -- ─── Step 2: Get current units ───
    SELECT available_units
    INTO v_old_units
    FROM blood_stock
    WHERE stock_id = p_stock_id
    FOR UPDATE;                           -- lock the row

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Stock ID % not found', p_stock_id;
    END IF;

    -- ─── Step 3: Calculate difference ───
    v_difference := p_new_units - v_old_units;

    -- No change needed
    IF v_difference = 0 THEN
        RAISE NOTICE 'No change needed. Units already %', 
            v_old_units;
        RETURN;
    END IF;

    -- ─── Step 4: Update units ───
    UPDATE blood_stock
    SET available_units = p_new_units
    WHERE stock_id = p_stock_id;
    -- Trigger 4 fires here automatically
    -- updating last_updated timestamp

    -- ─── Step 5: Log adjustment ───
    INSERT INTO stock_transaction
        (stock_id, admin_id, request_id, quantity, action)
    VALUES
        (p_stock_id, p_admin_id, NULL,
         ABS(v_difference), 'MANUAL_ADJUSTMENT');

    RAISE NOTICE 'Stock % adjusted from % to % units by Admin %',
        p_stock_id, v_old_units, p_new_units, p_admin_id;

EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error adjusting stock %: %', 
        p_stock_id, SQLERRM;
    RAISE;
END;
$$;
