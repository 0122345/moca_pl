-- =====================================================
-- MOCA Mobility System - PL/SQL Functions
-- Purpose: Reusable helper functions complementing procedures, triggers, and cursors
-- Owner: Application schema (NOT SYS)
-- =====================================================

-- 1) Compute fare given distance and duration using same base/per-unit as procedures
CREATE OR REPLACE FUNCTION fn_compute_fare(
    p_distance_km      IN NUMBER,
    p_duration_minutes IN NUMBER
) RETURN NUMBER DETERMINISTIC
IS
    v_base   CONSTANT NUMBER := 1500; -- base fare (same as in complete_ride)
    v_per_km CONSTANT NUMBER := 300;  -- per km
    v_per_min CONSTANT NUMBER := 50;  -- per minute
    v_fare   NUMBER := v_base;
BEGIN
    IF p_distance_km IS NOT NULL THEN
        v_fare := v_fare + (p_distance_km * v_per_km);
    END IF;
    IF p_duration_minutes IS NOT NULL THEN
        v_fare := v_fare + (p_duration_minutes * v_per_min);
    END IF;
    RETURN ROUND(v_fare, 2);
END fn_compute_fare;
/

-- 2) Get current status for a ride
CREATE OR REPLACE FUNCTION fn_get_ride_status(
    p_ride_id IN NUMBER
) RETURN VARCHAR2
IS
    v_status rides.status%TYPE;
BEGIN
    SELECT status INTO v_status FROM rides WHERE ride_id = p_ride_id;
    RETURN v_status;
EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN NULL;
END fn_get_ride_status;
/

-- 3) Check if a ride has any successful payment (1/0)
CREATE OR REPLACE FUNCTION fn_is_ride_paid(
    p_ride_id IN NUMBER
) RETURN NUMBER
IS
    v_cnt NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_cnt
    FROM payments p
    WHERE p.ride_id = p_ride_id
      AND p.is_successful = 1;
    RETURN CASE WHEN v_cnt > 0 THEN 1 ELSE 0 END;
END fn_is_ride_paid;
/

-- 4) Is a driver currently marked available? (1/0)
CREATE OR REPLACE FUNCTION fn_driver_available(
    p_driver_id IN NUMBER
) RETURN NUMBER
IS
    v_av NUMBER;
BEGIN
    SELECT CASE WHEN is_available = 1 THEN 1 ELSE 0 END INTO v_av
    FROM drivers
    WHERE driver_id = p_driver_id;
    RETURN v_av;
EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN 0;
END fn_driver_available;
/

-- 5) Get NEXTVAL from a sequence by name (use with care)
CREATE OR REPLACE FUNCTION fn_next_id(
    p_sequence_name IN VARCHAR2
) RETURN NUMBER
IS
    v_sql  VARCHAR2(4000);
    v_id   NUMBER;
BEGIN
    -- Very basic validation: allow only alphanumerics and underscore to avoid SQL injection
    IF REGEXP_LIKE(p_sequence_name, '^[A-Za-z0-9_]+$') THEN
        v_sql := 'SELECT ' || p_sequence_name || '.NEXTVAL FROM dual';
        EXECUTE IMMEDIATE v_sql INTO v_id;
        RETURN v_id;
    ELSE
        RAISE_APPLICATION_ERROR(-20030, 'Invalid sequence name');
    END IF;
END fn_next_id;
/

-- 6) Does a user exist by email? (1/0)
CREATE OR REPLACE FUNCTION fn_user_exists(
    p_email IN VARCHAR2
) RETURN NUMBER
IS
    v_cnt NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_cnt FROM users WHERE email = p_email;
    RETURN CASE WHEN v_cnt > 0 THEN 1 ELSE 0 END;
END fn_user_exists;
/

-- 7) Validate payment method against allowed set (1/0)
CREATE OR REPLACE FUNCTION fn_payment_method_ok(
    p_method IN VARCHAR2
) RETURN NUMBER DETERMINISTIC
IS
BEGIN
    RETURN CASE WHEN LOWER(TRIM(p_method)) IN ('nfc','momo','paypal','card','qr') THEN 1 ELSE 0 END;
END fn_payment_method_ok;
/

-- 8) Validate vehicle type against allowed set (1/0)
CREATE OR REPLACE FUNCTION fn_vehicle_type_ok(
    p_type IN VARCHAR2
) RETURN NUMBER DETERMINISTIC
IS
BEGIN
    RETURN CASE WHEN LOWER(TRIM(p_type)) IN ('car','moto','delivery') THEN 1 ELSE 0 END;
END fn_vehicle_type_ok;
/

-- 9) Mask a Rwandan phone number for display (e.g., 0781234567 -> 078***4567)
CREATE OR REPLACE FUNCTION fn_mask_phone(
    p_phone IN VARCHAR2
) RETURN VARCHAR2 DETERMINISTIC
IS
    v_clean VARCHAR2(50) := REGEXP_REPLACE(p_phone, '[^0-9]+', '');
BEGIN
    IF v_clean IS NULL OR LENGTH(v_clean) < 6 THEN
        RETURN p_phone;
    END IF;
    RETURN SUBSTR(v_clean,1,3) || '***' || SUBSTR(v_clean, -4);
END fn_mask_phone;
/

-- 10) Compute total minutes between started_at and completed_at for a ride
CREATE OR REPLACE FUNCTION fn_time_to_complete(
    p_ride_id IN NUMBER
) RETURN NUMBER
IS
    v_started TIMESTAMP;
    v_completed TIMESTAMP;
    v_minutes NUMBER;
BEGIN
    SELECT started_at, completed_at INTO v_started, v_completed FROM rides WHERE ride_id = p_ride_id;
    IF v_started IS NULL OR v_completed IS NULL THEN
        RETURN NULL;
    END IF;
    -- Convert INTERVAL DAY TO SECOND to minutes
    v_minutes :=
          EXTRACT(DAY    FROM (v_completed - v_started)) * 1440
        + EXTRACT(HOUR   FROM (v_completed - v_started)) * 60
        + EXTRACT(MINUTE FROM (v_completed - v_started))
        + EXTRACT(SECOND FROM (v_completed - v_started)) / 60;
    RETURN v_minutes;
EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN NULL;
END fn_time_to_complete;
/

-- 11) Convenience: get current driver_id for a ride (nullable)
CREATE OR REPLACE FUNCTION fn_get_ride_driver(
    p_ride_id IN NUMBER
) RETURN NUMBER
IS
    v_driver_id NUMBER;
BEGIN
    SELECT driver_id INTO v_driver_id FROM rides WHERE ride_id = p_ride_id;
    RETURN v_driver_id;
EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN NULL;
END fn_get_ride_driver;
/

-- End of functions
