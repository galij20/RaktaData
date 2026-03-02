-- ============================================
-- VERIFICATION QUERIES
-- Run these after inserting seed data to verify
-- everything is working correctly
-- ============================================

-- 1. Check all users created
-- SELECT * FROM users;

-- 2. Check donor eligibility after donations
-- SELECT donor_id, donor_name, eligibility_status,
--        last_donation_date FROM donor;
-- Expected:
-- Donors 1-8: eligibility_status = TRUE 
-- Donors 10-11: eligibility_status = FALSE 

-- 3. Check blood stock expiry dates (Trigger 2)
-- SELECT stock_id, blood_group, component_type,
--        available_units, added_date, expiry_date
-- FROM blood_stock ORDER BY stock_id;
-- Expected:
-- Platelets: expiry = today + 5 days 
-- Whole Blood: expiry = today + 35 days 
-- PRBC: expiry = today + 35 days 
-- FFP: expiry = today + 365 days 
-- stock_id 14: expiry = yesterday (for expiry test) 

-- 4. Check blood requests (Trigger 3)
-- SELECT request_id, blood_group, component_type,
--        quantity, status, rejected_reason
-- FROM blood_request;
-- Expected:
-- request_id 1: PENDING 
-- request_id 2: PENDING 
-- request_id 3: REJECTED (Insufficient stock) 
-- request_id 4: PENDING 
-- request_id 5: PENDING 

-- 5. Check views
-- SELECT * FROM urgent_fulfillment_list;
-- SELECT * FROM blood_availability_summary;
-- SELECT * FROM emergency_donor_list WHERE donor_blood_group = 'A+';
-- SELECT * FROM donor_donation_history WHERE donor_id = 1;
-- SELECT * FROM blood_stock_batch_details;


-- ============================================
-- TRIGGER TESTS
-- Run these one by one after seed data is loaded
-- ============================================

-- TEST TRIGGER 1: Donor eligibility
-- Insert a new donation for donor 1
-- INSERT INTO donation
--     (donor_id, donation_date, quantity, donor_blood_group, component_type)
-- VALUES (1, CURRENT_DATE, 1.00, 'A+', 'Whole Blood');
--
-- Check donor 1 eligibility (should be FALSE now)
-- SELECT donor_id, donor_name, eligibility_status, last_donation_date
-- FROM donor WHERE donor_id = 1;

-- ─────────────────────────────────────────────

-- TEST TRIGGER 2: Auto expiry date
-- Already tested by blood_stock inserts above
-- Verify with:
-- SELECT stock_id, component_type, expiry_date,
--        expiry_date - CURRENT_DATE AS days_remaining
-- FROM blood_stock ORDER BY stock_id;

-- ─────────────────────────────────────────────

-- TEST TRIGGER 3: Auto reject
-- Already tested by request_id = 3 above
-- Verify with:
-- SELECT request_id, status, rejected_reason
-- FROM blood_request WHERE request_id = 3;

-- ─────────────────────────────────────────────

-- TEST TRIGGER 4: last_updated refresh
-- UPDATE blood_stock SET available_units = 10
-- WHERE stock_id = 1;
--
-- SELECT stock_id, available_units, last_updated
-- FROM blood_stock WHERE stock_id = 1;
-- Expected: last_updated = current timestamp 


-- ============================================
-- PROCEDURE TESTS
-- Run these after verifying triggers work
-- ============================================

-- TEST PROCEDURE 1: approve_blood_request
-- Approve request 1 (O+ Whole Blood, 2 units)
-- CALL approve_blood_request(1, 1);
--
-- Verify:
-- SELECT request_id, status FROM blood_request WHERE request_id = 1;
-- Expected: APPROVED 
--
-- SELECT * FROM blood_availability_summary
-- WHERE blood_group = 'O+' AND component_type = 'Whole Blood';
-- Expected: total_available_units = 10 (12 - 2) 
--
-- SELECT * FROM stock_audit_summary LIMIT 1;
-- Expected: action = REQUEST_FULFILLED 

-- ─────────────────────────────────────────────

-- TEST PROCEDURE 2: reject_blood_request
-- Reject request 4 (AB+ FFP)
-- CALL reject_blood_request(4, 2, 'Patient condition changed');
--
-- Verify:
-- SELECT request_id, status, rejected_reason
-- FROM blood_request WHERE request_id = 4;
-- Expected: REJECTED, reason = 'Patient condition changed' 

-- ─────────────────────────────────────────────

-- TEST PROCEDURE 3: add_blood_stock
-- Add new batch of B+ Platelets
-- CALL add_blood_stock('B+', 'Platelets', 4.00, 1);
--
-- Verify:
-- SELECT * FROM blood_stock_batch_details
-- WHERE blood_group = 'B+' AND component_type = 'Platelets';
-- Expected: new batch with expiry = today + 5 days 
--
-- SELECT * FROM stock_audit_summary LIMIT 1;
-- Expected: action = DONATION_ADD 

-- ─────────────────────────────────────────────

-- TEST PROCEDURE 4: manual_stock_adjustment
-- Adjust stock_id = 1 from current units to 3
-- CALL manual_stock_adjustment(1, 3.00, 1);
--
-- Verify:
-- SELECT stock_id, available_units, last_updated
-- FROM blood_stock WHERE stock_id = 1;
-- Expected: available_units = 3.00 
--           last_updated = current timestamp 
--
-- SELECT * FROM stock_audit_summary
-- WHERE action = 'MANUAL_ADJUSTMENT';
-- Expected: new MANUAL_ADJUSTMENT record 

-- ─────────────────────────────────────────────

-- TEST EXPIRY CLEANUP:
-- stock_id = 14 has expiry = yesterday
-- Run cleanup function manually:
-- SELECT fn_cleanup_expired_stock();
--
-- Verify blood_stock (row should be deleted):
-- SELECT * FROM blood_stock WHERE stock_id = 14;
-- Expected: no rows 
--
-- Verify stock_transaction (should be logged):
-- SELECT * FROM stock_audit_summary
-- WHERE action = 'EXPIRED';
-- Expected: EXPIRED record for B- Platelets 


-- ============================================
-- CLEAN UP AFTER TESTING
-- Run this block to wipe all test data
-- and start fresh with real world data
-- ============================================

-- TRUNCATE TABLE stock_transaction RESTART IDENTITY CASCADE;
-- TRUNCATE TABLE blood_request RESTART IDENTITY CASCADE;
-- TRUNCATE TABLE blood_stock RESTART IDENTITY CASCADE;
-- TRUNCATE TABLE donation RESTART IDENTITY CASCADE;
-- TRUNCATE TABLE donor RESTART IDENTITY CASCADE;
-- TRUNCATE TABLE customer RESTART IDENTITY CASCADE;
-- TRUNCATE TABLE staff RESTART IDENTITY CASCADE;
-- TRUNCATE TABLE admin RESTART IDENTITY CASCADE;
-- TRUNCATE TABLE users RESTART IDENTITY CASCADE;
