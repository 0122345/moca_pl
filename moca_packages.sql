-- TODO: MOCA packages: grouped PL/SQL packages for ride, billing, user/driver/payment and notifications

-- PACKAGE: billing_pkg
CREATE OR REPLACE PACKAGE billing_pkg IS
	FUNCTION calculate_fare(p_distance_km NUMBER, p_duration_minutes NUMBER) RETURN NUMBER;
	FUNCTION apply_peak_multiplier(p_amount NUMBER, p_multiplier NUMBER) RETURN NUMBER;
	FUNCTION estimate_fare(p_distance_km NUMBER, p_duration_minutes NUMBER) RETURN NUMBER;
END billing_pkg;
/

CREATE OR REPLACE PACKAGE BODY billing_pkg IS
	FUNCTION calculate_fare(p_distance_km NUMBER, p_duration_minutes NUMBER) RETURN NUMBER IS
		v_base NUMBER := 1500;
		v_per_km NUMBER := 300;
		v_per_min NUMBER := 50;
		v_total NUMBER := 0;
	BEGIN
		v_total := v_base;
		IF p_distance_km IS NOT NULL THEN
			v_total := v_total + (p_distance_km * v_per_km);
		END IF;
		IF p_duration_minutes IS NOT NULL THEN
			v_total := v_total + (p_duration_minutes * v_per_min);
		END IF;
		RETURN ROUND(v_total, 2);
	END calculate_fare;

	FUNCTION apply_peak_multiplier(p_amount NUMBER, p_multiplier NUMBER) RETURN NUMBER IS
	BEGIN
		RETURN ROUND(p_amount * NVL(p_multiplier, 1), 2);
	END apply_peak_multiplier;

	FUNCTION estimate_fare(p_distance_km NUMBER, p_duration_minutes NUMBER) RETURN NUMBER IS
	BEGIN
		RETURN calculate_fare(p_distance_km, p_duration_minutes);
	END estimate_fare;
END billing_pkg;
/

-- PACKAGE: ride_mgmt_pkg
CREATE OR REPLACE PACKAGE ride_mgmt_pkg IS
	PROCEDURE request_ride(p_rider_id IN NUMBER, p_pickup_lat IN NUMBER, p_pickup_lng IN NUMBER, p_drop_lat IN NUMBER, p_drop_lng IN NUMBER, p_ride_id OUT NUMBER, p_available_drivers OUT SYS_REFCURSOR);
	PROCEDURE assign_driver(p_ride_id IN NUMBER, p_driver_id IN NUMBER);
	PROCEDURE start_ride(p_ride_id IN NUMBER);
	PROCEDURE complete_ride(p_ride_id IN NUMBER, p_distance_km IN NUMBER DEFAULT NULL, p_duration_minutes IN NUMBER DEFAULT NULL);
	PROCEDURE cancel_ride(p_ride_id IN NUMBER, p_reason IN VARCHAR2, p_fee OUT NUMBER);
END ride_mgmt_pkg;
/

CREATE OR REPLACE PACKAGE BODY ride_mgmt_pkg IS
	PROCEDURE request_ride(p_rider_id IN NUMBER, p_pickup_lat IN NUMBER, p_pickup_lng IN NUMBER, p_drop_lat IN NUMBER, p_drop_lng IN NUMBER, p_ride_id OUT NUMBER, p_available_drivers OUT SYS_REFCURSOR) IS
	BEGIN
		-- delegate to standalone procedure
		request_ride(p_rider_id, p_pickup_lat, p_pickup_lng, p_drop_lat, p_drop_lng, p_ride_id, p_available_drivers);
	END request_ride;

	PROCEDURE assign_driver(p_ride_id IN NUMBER, p_driver_id IN NUMBER) IS
	BEGIN
		assign_driver(p_ride_id, p_driver_id);
	END assign_driver;

	PROCEDURE start_ride(p_ride_id IN NUMBER) IS
	BEGIN
		start_ride(p_ride_id);
	END start_ride;

	PROCEDURE complete_ride(p_ride_id IN NUMBER, p_distance_km IN NUMBER DEFAULT NULL, p_duration_minutes IN NUMBER DEFAULT NULL) IS
	BEGIN
		complete_ride(p_ride_id, p_distance_km, p_duration_minutes);
	END complete_ride;

	PROCEDURE cancel_ride(p_ride_id IN NUMBER, p_reason IN VARCHAR2, p_fee OUT NUMBER) IS
	BEGIN
		cancel_ride(p_ride_id, p_reason, p_fee);
	END cancel_ride;
END ride_mgmt_pkg;
/

-- PACKAGE: user_mgmt_pkg
CREATE OR REPLACE PACKAGE user_mgmt_pkg IS
	PROCEDURE register_user(p_full_name IN VARCHAR2, p_email IN VARCHAR2, p_phone IN VARCHAR2, p_role IN VARCHAR2, p_password_hash IN VARCHAR2, p_user_id OUT NUMBER);
	PROCEDURE update_user_profile(p_user_id IN NUMBER, p_full_name IN VARCHAR2, p_phone IN VARCHAR2);
	FUNCTION get_user_rating(p_user_id IN NUMBER) RETURN NUMBER;
END user_mgmt_pkg;
/

CREATE OR REPLACE PACKAGE BODY user_mgmt_pkg IS
	PROCEDURE register_user(p_full_name IN VARCHAR2, p_email IN VARCHAR2, p_phone IN VARCHAR2, p_role IN VARCHAR2, p_password_hash IN VARCHAR2, p_user_id OUT NUMBER) IS
	BEGIN
		register_user(p_full_name, p_email, p_phone, p_role, p_password_hash, p_user_id);
	END register_user;

	PROCEDURE update_user_profile(p_user_id IN NUMBER, p_full_name IN VARCHAR2, p_phone IN VARCHAR2) IS
	BEGIN
		UPDATE users SET full_name = p_full_name, phone = p_phone WHERE user_id = p_user_id; COMMIT;
	EXCEPTION WHEN OTHERS THEN ROLLBACK; RAISE; END update_user_profile;

	FUNCTION get_user_rating(p_user_id IN NUMBER) RETURN NUMBER IS
		v_avg NUMBER;
	BEGIN
		SELECT AVG(rating) INTO v_avg FROM driver_ratings WHERE driver_id = p_user_id;
		RETURN NVL(v_avg,0);
	EXCEPTION WHEN NO_DATA_FOUND THEN
		RETURN 0;
	END get_user_rating;
END user_mgmt_pkg;
/

-- PACKAGE: driver_mgmt_pkg
CREATE OR REPLACE PACKAGE driver_mgmt_pkg IS
	PROCEDURE register_driver(p_user_id IN NUMBER, p_license_no IN VARCHAR2, p_vehicle_type IN VARCHAR2, p_vehicle_plate IN VARCHAR2, p_driver_id OUT NUMBER);
	PROCEDURE update_driver_location(p_driver_id IN NUMBER, p_latitude IN NUMBER, p_longitude IN NUMBER, p_ride_id IN NUMBER := NULL);
	PROCEDURE set_driver_availability(p_driver_id IN NUMBER, p_available IN NUMBER);
	PROCEDURE get_nearby_drivers(p_lat IN NUMBER, p_lng IN NUMBER, p_limit IN NUMBER, p_cursor OUT SYS_REFCURSOR);
END driver_mgmt_pkg;
/

CREATE OR REPLACE PACKAGE BODY driver_mgmt_pkg IS
	PROCEDURE register_driver(p_user_id IN NUMBER, p_license_no IN VARCHAR2, p_vehicle_type IN VARCHAR2, p_vehicle_plate IN VARCHAR2, p_driver_id OUT NUMBER) IS
	BEGIN
		register_driver(p_user_id, p_license_no, p_vehicle_type, p_vehicle_plate, p_driver_id);
	END register_driver;

	PROCEDURE update_driver_location(p_driver_id IN NUMBER, p_latitude IN NUMBER, p_longitude IN NUMBER, p_ride_id IN NUMBER := NULL) IS
	BEGIN
		update_driver_location(p_driver_id, p_latitude, p_longitude, p_ride_id);
	END update_driver_location;

	PROCEDURE set_driver_availability(p_driver_id IN NUMBER, p_available IN NUMBER) IS
	BEGIN
		UPDATE drivers SET is_available = p_available WHERE driver_id = p_driver_id; COMMIT;
	EXCEPTION WHEN OTHERS THEN ROLLBACK; RAISE; END set_driver_availability;

	PROCEDURE get_nearby_drivers(p_lat IN NUMBER, p_lng IN NUMBER, p_limit IN NUMBER, p_cursor OUT SYS_REFCURSOR) IS
	BEGIN
		-- Simple stub: return available drivers ordered by rating, real geospatial search would be done elsewhere
		OPEN p_cursor FOR SELECT driver_id, user_id, license_no, vehicle_type, vehicle_plate, rating FROM drivers WHERE is_available = 1 ORDER BY rating DESC FETCH FIRST NVL(p_limit,5) ROWS ONLY;
	END get_nearby_drivers;
END driver_mgmt_pkg;
/

-- PACKAGE: payment_pkg
CREATE OR REPLACE PACKAGE payment_pkg IS
	PROCEDURE record_payment(p_ride_id IN NUMBER, p_amount IN NUMBER, p_method IN VARCHAR2, p_transaction_ref OUT VARCHAR2, p_success OUT NUMBER);
	PROCEDURE refund_payment(p_payment_id IN NUMBER, p_amount IN NUMBER);
	FUNCTION validate_payment_method(p_method IN VARCHAR2) RETURN NUMBER;
	PROCEDURE generate_invoice(p_ride_id IN NUMBER, p_invoice OUT VARCHAR2);
END payment_pkg;
/

CREATE OR REPLACE PACKAGE BODY payment_pkg IS
	PROCEDURE record_payment(p_ride_id IN NUMBER, p_amount IN NUMBER, p_method IN VARCHAR2, p_transaction_ref OUT VARCHAR2, p_success OUT NUMBER) IS
	BEGIN
		record_payment(p_ride_id, p_amount, p_method, p_transaction_ref, p_success);
	END record_payment;

	PROCEDURE refund_payment(p_payment_id IN NUMBER, p_amount IN NUMBER) IS
	BEGIN
		UPDATE payments SET is_successful = 0, payment_details = payment_details || ' | REFUND ' || p_amount WHERE payment_id = p_payment_id; COMMIT;
	EXCEPTION WHEN OTHERS THEN ROLLBACK; RAISE; END refund_payment;

	FUNCTION validate_payment_method(p_method IN VARCHAR2) RETURN NUMBER IS
	BEGIN
		IF p_method IN ('nfc','momo','paypal','card','qr') THEN
			RETURN 1; -- ok
		ELSE
			RETURN 0; -- unsupported
		END IF;
	END validate_payment_method;

	PROCEDURE generate_invoice(p_ride_id IN NUMBER, p_invoice OUT VARCHAR2) IS
		v_fare NUMBER;
	BEGIN
		SELECT fare_amount INTO v_fare FROM rides WHERE ride_id = p_ride_id;
		p_invoice := 'INVOICE: Ride=' || p_ride_id || ' Amount=' || NVL(TO_CHAR(v_fare),'0');
	EXCEPTION WHEN NO_DATA_FOUND THEN p_invoice := 'No such ride'; END generate_invoice;
END payment_pkg;
/

-- PACKAGE: notifications_pkg (lightweight DB-side stubs for the prototype)
CREATE OR REPLACE PACKAGE notifications_pkg IS
	PROCEDURE send_sms(p_to IN VARCHAR2, p_body IN VARCHAR2);
	PROCEDURE send_push_notification(p_user_id IN NUMBER, p_title IN VARCHAR2, p_body IN VARCHAR2);
	PROCEDURE notify_driver_of_ride_request(p_driver_id IN NUMBER, p_ride_id IN NUMBER);
	PROCEDURE notify_user_ride_arrived(p_user_id IN NUMBER, p_ride_id IN NUMBER);
END notifications_pkg;
/

CREATE OR REPLACE PACKAGE BODY notifications_pkg IS
	PROCEDURE send_sms(p_to IN VARCHAR2, p_body IN VARCHAR2) IS
	BEGIN
		-- In a real system this would call an external gateway. For now insert an admin message into messages table
		INSERT INTO messages (message_id, sender_id, receiver_id, ride_id, message_body, is_read, sent_at)
		VALUES (messages_seq.NEXTVAL, 0, 0, NULL, '[SMS to '||p_to||'] '||p_body, 0, SYSTIMESTAMP);
		COMMIT;
	EXCEPTION WHEN OTHERS THEN ROLLBACK; RAISE; END send_sms;

	PROCEDURE send_push_notification(p_user_id IN NUMBER, p_title IN VARCHAR2, p_body IN VARCHAR2) IS
	BEGIN
		INSERT INTO messages (message_id, sender_id, receiver_id, ride_id, message_body, is_read, sent_at)
		VALUES (messages_seq.NEXTVAL, 0, p_user_id, NULL, '[PUSH] ' || p_title || ' - ' || p_body, 0, SYSTIMESTAMP);
		COMMIT;
	EXCEPTION WHEN OTHERS THEN ROLLBACK; RAISE; END send_push_notification;

	PROCEDURE notify_driver_of_ride_request(p_driver_id IN NUMBER, p_ride_id IN NUMBER) IS
	BEGIN
		INSERT INTO messages (message_id, sender_id, receiver_id, ride_id, message_body, is_read, sent_at)
		VALUES (messages_seq.NEXTVAL, 0, (SELECT user_id FROM drivers WHERE driver_id = p_driver_id), p_ride_id, 'New ride request: '||p_ride_id, 0, SYSTIMESTAMP);
		COMMIT;
	EXCEPTION WHEN OTHERS THEN ROLLBACK; RAISE; END notify_driver_of_ride_request;

	PROCEDURE notify_user_ride_arrived(p_user_id IN NUMBER, p_ride_id IN NUMBER) IS
	BEGIN
		INSERT INTO messages (message_id, sender_id, receiver_id, ride_id, message_body, is_read, sent_at)
		VALUES (messages_seq.NEXTVAL, 0, p_user_id, p_ride_id, 'Your driver has arrived for ride '||p_ride_id, 0, SYSTIMESTAMP);
		COMMIT;
	EXCEPTION WHEN OTHERS THEN ROLLBACK; RAISE; END notify_user_ride_arrived;
END notifications_pkg;
/
