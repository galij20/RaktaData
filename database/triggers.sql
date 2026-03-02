-- Triggers for Blood Bank Management System

-- Trigger to update donor eligibility after a donation is made
CREATE OR REPLACE FUNCTION fn_update_donor_eligibility()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE donor
    SET
        last_donation_date = NEW.donation_date,
        eligibility_status = FALSE
    WHERE donor_id = NEW.donor_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_donor_eligibility
AFTER INSERT ON donation
FOR EACH ROW
EXECUTE FUNCTION fn_update_donor_eligibility();


--2 Trigger to set expiry date for blood stock based on component type
CREATE OR REPLACE FUNCTION fn_set_expiry_date()
RETURNS TRIGGER AS $$
BEGIN
    NEW.expiry_date := CASE NEW.component_type
        WHEN 'Platelets'   THEN CURRENT_DATE + INTERVAL '5 days'
        WHEN 'Whole Blood' THEN CURRENT_DATE + INTERVAL '35 days'
        WHEN 'PRBC'        THEN CURRENT_DATE + INTERVAL '35 days'
        WHEN 'FFP'         THEN CURRENT_DATE + INTERVAL '365 days'
        ELSE CURRENT_DATE + INTERVAL '35 days'  -- safe default
    END;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_set_expiry_date
BEFORE INSERT ON blood_stock
FOR EACH ROW
EXECUTE FUNCTION fn_set_expiry_date();


--3 Trigger to auto-reject blood requests if insufficient stock is available
CREATE OR REPLACE FUNCTION fn_auto_reject_request()
RETURNS TRIGGER AS $$
DECLARE
    v_total_available DECIMAL(5,2);
BEGIN
    -- Sum available units across all active batches
    SELECT COALESCE(SUM(available_units), 0)
    INTO v_total_available
    FROM blood_stock
    WHERE blood_group = NEW.blood_group
    AND component_type = NEW.component_type;

-- If total available < requested quantity, auto-reject
    IF v_total_available < NEW.quantity THEN
        NEW.status          := 'REJECTED';
        NEW.rejected_reason := 'Insufficient stock';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_auto_reject_request
BEFORE INSERT ON blood_request
FOR EACH ROW
EXECUTE FUNCTION fn_auto_reject_request();

--4 Trigger to update last_updated timestamp on blood_stock updates
CREATE OR REPLACE FUNCTION fn_update_stock_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_updated := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_stock_timestamp
BEFORE UPDATE ON blood_stock
FOR EACH ROW
EXECUTE FUNCTION fn_update_stock_timestamp();


--5 Trigger to validate that donation blood group matches donor's known blood group
CREATE OR REPLACE FUNCTION fn_validate_donation_blood_group()
RETURNS TRIGGER AS $$
DECLARE
    v_donor_blood_group blood_group_type;
BEGIN
    -- Get donor's actual blood group
    SELECT donor_blood_group
    INTO v_donor_blood_group
    FROM donor
    WHERE donor_id = NEW.donor_id;

    -- If donor has a known blood group
    -- and it doesn't match donation blood group
    -- raise an error
    IF v_donor_blood_group IS NOT NULL 
    AND NEW.donor_blood_group IS NOT NULL
    AND v_donor_blood_group != NEW.donor_blood_group THEN
        RAISE EXCEPTION 
            'Blood group mismatch! Donor % has blood group % but donation records %',
            NEW.donor_id, v_donor_blood_group, NEW.donor_blood_group;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_donation_blood_group
BEFORE INSERT ON donation
FOR EACH ROW
EXECUTE FUNCTION fn_validate_donation_blood_group();