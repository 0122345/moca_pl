-- TODO: MOCA procedures: core stored procedures for ride lifecycle, payments, and registrations

-- 2.1 request_ride: create a ride request and return a cursor of nearby/available drivers
CREATE OR REPLACE PROCEDURE request_ride(
	p_rider_id IN NUMBER,
	p_pickup_lat IN NUMBER,
	p_pickup_lng IN NUMBER,
	p_drop_lat IN NUMBER,
	p_drop_lng IN NUMBER,
	p_ride_id OUT NUMBER,
	p_available_drivers OUT SYS_REFCURSOR
) IS
BEGIN
	p_ride_id := rides_seq.NEXTVAL;
	INSERT INTO rides (ride_id, rider_id, driver_id, pickup_location, dropoff_location, pickup_latitude, pickup_longitude, dropoff_latitude, dropoff_longitude, status, requested_at)
	VALUES (p_ride_id, p_rider_id, NULL, NULL, NULL, p_pickup_lat, p_pickup_lng, p_drop_lat, p_drop_lng, 'requested', SYSTIMESTAMP);

	-- return up to 5 currently available drivers (simple selection — true geospatial matching belongs in driver_mgmt_pkg)
	OPEN p_available_drivers FOR
	SELECT driver_id, user_id, license_no, vehicle_type, vehicle_plate, rating
	FROM drivers
	WHERE is_available = 1
	ORDER BY rating DESC NULLS LAST
	FETCH FIRST 5 ROWS ONLY;

	COMMIT; -- commit the new ride record
EXCEPTION
	WHEN OTHERS THEN
		ROLLBACK;
		RAISE;
END request_ride;
/

-- 2.2 assign_driver: set driver for ride and mark driver not available
CREATE OR REPLACE PROCEDURE assign_driver(
	p_ride_id IN NUMBER,
	p_driver_id IN NUMBER
) IS
	v_exists NUMBER;
BEGIN
	SELECT COUNT(*) INTO v_exists FROM rides WHERE ride_id = p_ride_id;
	IF v_exists = 0 THEN
		RAISE_APPLICATION_ERROR(-20010, 'Ride not found');
	END IF;

	UPDATE rides SET driver_id = p_driver_id, status = 'accepted', updated_at = SYSTIMESTAMP WHERE ride_id = p_ride_id;
	UPDATE drivers SET is_available = 0 WHERE driver_id = p_driver_id;
	COMMIT;
EXCEPTION
	WHEN OTHERS THEN
		ROLLBACK;
		RAISE;
END assign_driver;
/

-- 2.3 start_ride: set started_at and switch status to active
CREATE OR REPLACE PROCEDURE start_ride(
	p_ride_id IN NUMBER
) IS
BEGIN
	UPDATE rides SET started_at = SYSTIMESTAMP, status = 'active', updated_at = SYSTIMESTAMP WHERE ride_id = p_ride_id;
	COMMIT;
EXCEPTION
	WHEN OTHERS THEN
		ROLLBACK;
		RAISE;
END start_ride;
/

-- 2.4 complete_ride: set completed_at, compute and store fare, increment driver ride counter
CREATE OR REPLACE PROCEDURE complete_ride(
	p_ride_id IN NUMBER,
	p_distance_km IN NUMBER DEFAULT NULL,
	p_duration_minutes IN NUMBER DEFAULT NULL
) IS
	v_driver_id NUMBER;
	v_base NUMBER := 1500; -- base fare in local cents/units
	v_per_km NUMBER := 300; -- per km
	v_per_min NUMBER := 50; -- per minute
	v_fare NUMBER;
	v_dist NUMBER;
	v_dur NUMBER;
BEGIN
	-- Update ride distances & timestamps
	UPDATE rides
	SET completed_at = SYSTIMESTAMP,
		distance_km = NVL(p_distance_km, distance_km),
		duration_minutes = NVL(p_duration_minutes, duration_minutes),
		updated_at = SYSTIMESTAMP
	WHERE ride_id = p_ride_id
	RETURNING driver_id INTO v_driver_id;

	-- compute fare if we have metrics (read from table into local vars)
	SELECT distance_km, duration_minutes INTO v_dist, v_dur FROM rides WHERE ride_id = p_ride_id;
	v_fare := v_base;
	IF v_dist IS NOT NULL THEN
		v_fare := v_fare + (v_dist * v_per_km);
	END IF;
	IF v_dur IS NOT NULL THEN
		v_fare := v_fare + (v_dur * v_per_min);
	END IF;

	UPDATE rides SET fare_amount = ROUND(v_fare,2), status = 'completed', updated_at = SYSTIMESTAMP WHERE ride_id = p_ride_id;

	-- increment driver's total rides if driver exists
	IF v_driver_id IS NOT NULL THEN
		UPDATE drivers SET total_rides = NVL(total_rides,0) + 1 WHERE driver_id = v_driver_id;
	END IF;

	COMMIT;
EXCEPTION
	WHEN NO_DATA_FOUND THEN
		ROLLBACK;
		RAISE_APPLICATION_ERROR(-20011, 'Ride not found while completing');
	WHEN OTHERS THEN
		ROLLBACK;
		RAISE;
END complete_ride;
/

-- 2.5 record_payment: insert payment and, on success, mark ride as PAID
CREATE OR REPLACE PROCEDURE record_payment(
	p_ride_id IN NUMBER,
	p_amount IN NUMBER,
	p_method IN VARCHAR2,
	p_transaction_ref OUT VARCHAR2,
	p_success OUT NUMBER
) IS
	v_new_id NUMBER;
BEGIN
	v_new_id := payments_seq.NEXTVAL;
	p_transaction_ref := 'TXN' || TO_CHAR(SYSTIMESTAMP,'YYYYMMDDHH24MISSFF3') || v_new_id;

	INSERT INTO payments (payment_id, ride_id, amount, method, transaction_ref, is_successful, timestamp, payment_details)
	VALUES (v_new_id, p_ride_id, p_amount, p_method, p_transaction_ref, 1, SYSTIMESTAMP, p_method || ' payment');

	-- mark ride as paid only if payment succeeded
	UPDATE rides SET status = 'paid', updated_at = SYSTIMESTAMP WHERE ride_id = p_ride_id;

	p_success := 1;
	COMMIT;
EXCEPTION
	WHEN OTHERS THEN
		ROLLBACK;
		p_success := 0;
		RAISE;
END record_payment;
/

-- 2.6 update_driver_location: insert new tracking entry (history trigger will log)
CREATE OR REPLACE PROCEDURE update_driver_location(
	p_driver_id IN NUMBER,
	p_latitude IN NUMBER,
	p_longitude IN NUMBER,
	p_ride_id IN NUMBER DEFAULT NULL
) IS
	v_tracking_id NUMBER;
BEGIN
	v_tracking_id := tracking_seq.NEXTVAL;
	INSERT INTO tracking (tracking_id, driver_id, ride_id, latitude, longitude, speed, heading, timestamp)
	VALUES (v_tracking_id, p_driver_id, p_ride_id, p_latitude, p_longitude, NULL, NULL, SYSTIMESTAMP);

	COMMIT;
EXCEPTION
	WHEN OTHERS THEN
		ROLLBACK; RAISE;
END update_driver_location;
/

-- 2.7 cancel_ride: cancel a ride, optionally apply late cancellation fee and restore driver availability
CREATE OR REPLACE PROCEDURE cancel_ride(
	p_ride_id IN NUMBER,
	p_reason IN VARCHAR2,
	p_fee OUT NUMBER
) IS
	v_started_at TIMESTAMP;
	v_status VARCHAR2(30);
	v_driver_id NUMBER;
BEGIN
	SELECT started_at, status, driver_id INTO v_started_at, v_status, v_driver_id FROM rides WHERE ride_id = p_ride_id;

	-- determine fee: 0 if not started and recently requested, else a small fee
	IF v_status = 'requested' THEN
		p_fee := 0;
	ELSE
		p_fee := 500; -- flat late-cancel fee
	END IF;

	UPDATE rides SET status = 'canceled', updated_at = SYSTIMESTAMP WHERE ride_id = p_ride_id;

	-- optionally record a charge as a Payment record with is_successful=0 (or a different mechanism depending on ops)
	IF p_fee > 0 THEN
		INSERT INTO payments (payment_id, ride_id, amount, method, transaction_ref, is_successful, timestamp, payment_details)
		VALUES (payments_seq.NEXTVAL, p_ride_id, p_fee, 'cancellation', 'CANCEL' || TO_CHAR(SYSTIMESTAMP,'YYYYMMDDHH24MISS'), 0, SYSTIMESTAMP, p_reason);
	END IF;

	-- driver availability will be handled by the status change trigger
	COMMIT;
EXCEPTION
	WHEN NO_DATA_FOUND THEN
		ROLLBACK; RAISE_APPLICATION_ERROR(-20012, 'Ride not found');
	WHEN OTHERS THEN
		ROLLBACK; RAISE;
END cancel_ride;
/

-- 2.8 register_user: central validation and creation
CREATE OR REPLACE PROCEDURE register_user(
	p_full_name IN VARCHAR2,
	p_email IN VARCHAR2,
	p_phone IN VARCHAR2,
	p_role IN VARCHAR2,
	p_password_hash IN VARCHAR2,
	p_user_id OUT NUMBER
) IS
BEGIN
	-- ensure email not already used
	DECLARE v_exists NUMBER; BEGIN SELECT COUNT(*) INTO v_exists FROM users WHERE email = p_email; IF v_exists > 0 THEN RAISE_APPLICATION_ERROR(-20020,'Email already exists'); END IF; END;

	p_user_id := users_seq.NEXTVAL;
	INSERT INTO users (user_id, full_name, email, phone, role, password_hash, jwt_token, created_at)
	VALUES (p_user_id, p_full_name, p_email, p_phone, p_role, p_password_hash, NULL, SYSTIMESTAMP);
	COMMIT;
EXCEPTION
	WHEN OTHERS THEN
		ROLLBACK; RAISE;
END register_user;
/

CREATE OR REPLACE PROCEDURE register_driver(
	p_user_id IN NUMBER,
	p_license_no IN VARCHAR2,
	p_vehicle_type IN VARCHAR2,
	p_vehicle_plate IN VARCHAR2,
	p_driver_id OUT NUMBER
) IS
	v_user_exists NUMBER;
BEGIN
	SELECT COUNT(*) INTO v_user_exists FROM users WHERE user_id = p_user_id AND role = 'driver';
	IF v_user_exists = 0 THEN
		RAISE_APPLICATION_ERROR(-20021, 'User does not exist or is not designated as a driver');
	END IF;

	p_driver_id := drivers_seq.NEXTVAL;
	INSERT INTO drivers (driver_id, user_id, license_no, vehicle_type, vehicle_plate, rating, is_available, total_rides)
	VALUES (p_driver_id, p_user_id, p_license_no, p_vehicle_type, p_vehicle_plate, 0.0, 1, 0);
	COMMIT;
EXCEPTION
	WHEN OTHERS THEN
		ROLLBACK; RAISE;
END register_driver;
/
