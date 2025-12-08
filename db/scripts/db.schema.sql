-- =====================================================
-- MOCA Mobility System - PL/SQL Database Schema
-- Course: Database Development with PL/SQL (INSY 8311)
-- Student: 27438 Ntwari Ashimwe Fiacre
-- Date: 17 November 2025
-- =====================================================

-- Idempotent cleanup so the script can be re-run safely
PROMPT Dropping existing objects (ignore errors if not present);

-- Drop tables (children first) if they exist
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE driver_ratings CASCADE CONSTRAINTS';
EXCEPTION
  WHEN OTHERS THEN IF SQLCODE != -942 THEN RAISE; END IF; -- ORA-00942 table or view does not exist
END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE tracking CASCADE CONSTRAINTS';
EXCEPTION
  WHEN OTHERS THEN IF SQLCODE != -942 THEN RAISE; END IF;
END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE messages CASCADE CONSTRAINTS';
EXCEPTION
  WHEN OTHERS THEN IF SQLCODE != -942 THEN RAISE; END IF;
END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE payments CASCADE CONSTRAINTS';
EXCEPTION
  WHEN OTHERS THEN IF SQLCODE != -942 THEN RAISE; END IF;
END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE rides CASCADE CONSTRAINTS';
EXCEPTION
  WHEN OTHERS THEN IF SQLCODE != -942 THEN RAISE; END IF;
END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE drivers CASCADE CONSTRAINTS';
EXCEPTION
  WHEN OTHERS THEN IF SQLCODE != -942 THEN RAISE; END IF;
END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE ride_requests_log CASCADE CONSTRAINTS';
EXCEPTION
  WHEN OTHERS THEN IF SQLCODE != -942 THEN RAISE; END IF;
END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE tracking_history CASCADE CONSTRAINTS';
EXCEPTION
  WHEN OTHERS THEN IF SQLCODE != -942 THEN RAISE; END IF;
END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE users CASCADE CONSTRAINTS';
EXCEPTION
  WHEN OTHERS THEN IF SQLCODE != -942 THEN RAISE; END IF;
END;
/

-- Drop sequences if they exist
BEGIN
  EXECUTE IMMEDIATE 'DROP SEQUENCE tracking_history_seq';
EXCEPTION
  WHEN OTHERS THEN IF SQLCODE != -2289 THEN RAISE; END IF; -- ORA-02289 sequence does not exist
END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP SEQUENCE log_seq';
EXCEPTION
  WHEN OTHERS THEN IF SQLCODE != -2289 THEN RAISE; END IF;
END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP SEQUENCE ratings_seq';
EXCEPTION
  WHEN OTHERS THEN IF SQLCODE != -2289 THEN RAISE; END IF;
END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP SEQUENCE tracking_seq';
EXCEPTION
  WHEN OTHERS THEN IF SQLCODE != -2289 THEN RAISE; END IF;
END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP SEQUENCE messages_seq';
EXCEPTION
  WHEN OTHERS THEN IF SQLCODE != -2289 THEN RAISE; END IF;
END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP SEQUENCE payments_seq';
EXCEPTION
  WHEN OTHERS THEN IF SQLCODE != -2289 THEN RAISE; END IF;
END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP SEQUENCE rides_seq';
EXCEPTION
  WHEN OTHERS THEN IF SQLCODE != -2289 THEN RAISE; END IF;
END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP SEQUENCE drivers_seq';
EXCEPTION
  WHEN OTHERS THEN IF SQLCODE != -2289 THEN RAISE; END IF;
END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP SEQUENCE users_seq';
EXCEPTION
  WHEN OTHERS THEN IF SQLCODE != -2289 THEN RAISE; END IF;
END;
/

-- STEP 1: CREATE DATABASE SCHEMA
-- =====================================================

-- Create Users Table
CREATE TABLE users (
    user_id NUMBER PRIMARY KEY,
    full_name VARCHAR2(100) NOT NULL,
    email VARCHAR2(100) UNIQUE NOT NULL,
    phone VARCHAR2(15) NOT NULL,
    role VARCHAR2(20) CHECK (role IN ('rider', 'driver', 'admin')) NOT NULL,
    password_hash VARCHAR2(255) NOT NULL,
    jwt_token VARCHAR2(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Create Drivers Table
CREATE TABLE drivers (
    driver_id NUMBER PRIMARY KEY,
    user_id NUMBER NOT NULL,
    license_no VARCHAR2(50) NOT NULL,
    vehicle_type VARCHAR2(20) CHECK (vehicle_type IN ('car', 'moto', 'delivery')) NOT NULL,
    vehicle_plate VARCHAR2(20) NOT NULL,
    rating NUMBER(3,2) DEFAULT 0.00,
    is_available NUMBER(1) DEFAULT 1,
    total_rides NUMBER DEFAULT 0,
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);

-- Create Rides Table
CREATE TABLE rides (
    ride_id NUMBER PRIMARY KEY,
    rider_id NUMBER NOT NULL,
    driver_id NUMBER,
    pickup_location VARCHAR2(200) NOT NULL,
    dropoff_location VARCHAR2(200) NOT NULL,
    pickup_latitude NUMBER(10,8),
    pickup_longitude NUMBER(11,8),
    dropoff_latitude NUMBER(10,8),
    dropoff_longitude NUMBER(11,8),
    fare_amount NUMBER(10,2),
    payment_method VARCHAR2(20) CHECK (payment_method IN ('nfc', 'momo', 'paypal', 'card', 'qr')),
    -- added 'paid' to allow explicit paid state, and added updated_at for automatic timestamping
    status VARCHAR2(20) DEFAULT 'requested' CHECK (status IN ('requested', 'accepted', 'active', 'completed', 'canceled', 'paid')),
    updated_at TIMESTAMP,
    requested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    distance_km NUMBER(10,2),
    duration_minutes NUMBER,
    FOREIGN KEY (rider_id) REFERENCES users(user_id),
    FOREIGN KEY (driver_id) REFERENCES drivers(driver_id)
);

-- Create Payments Table
CREATE TABLE payments (
    payment_id NUMBER PRIMARY KEY,
    ride_id NUMBER NOT NULL,
    amount NUMBER(10,2) NOT NULL,
    method VARCHAR2(20) CHECK (method IN ('nfc', 'momo', 'paypal', 'card', 'qr')) NOT NULL,
    transaction_ref VARCHAR2(100) UNIQUE,
    is_successful NUMBER(1) DEFAULT 0,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    payment_details VARCHAR2(500),
    FOREIGN KEY (ride_id) REFERENCES rides(ride_id)
);

-- Create Messages Table
CREATE TABLE messages (
    message_id NUMBER PRIMARY KEY,
    sender_id NUMBER NOT NULL,
    receiver_id NUMBER NOT NULL,
    ride_id NUMBER,
    message_body VARCHAR2(1000) NOT NULL,
    is_read NUMBER(1) DEFAULT 0,
    sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (sender_id) REFERENCES users(user_id),
    FOREIGN KEY (receiver_id) REFERENCES users(user_id),
    FOREIGN KEY (ride_id) REFERENCES rides(ride_id)
);

-- Create Real-Time Tracking Table
CREATE TABLE tracking (
    tracking_id NUMBER PRIMARY KEY,
    driver_id NUMBER NOT NULL,
    ride_id NUMBER,
    latitude NUMBER(10,8) NOT NULL,
    longitude NUMBER(11,8) NOT NULL,
    speed NUMBER(5,2) DEFAULT 0,
    heading NUMBER(5,2),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (driver_id) REFERENCES drivers(driver_id),
    FOREIGN KEY (ride_id) REFERENCES rides(ride_id)
);

-- Create Driver Ratings Table
CREATE TABLE driver_ratings (
    rating_id NUMBER PRIMARY KEY,
    ride_id NUMBER NOT NULL,
    driver_id NUMBER NOT NULL,
    rider_id NUMBER NOT NULL,
    rating NUMBER(1) CHECK (rating BETWEEN 1 AND 5) NOT NULL,
    rating_comment VARCHAR2(500),
    rated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (ride_id) REFERENCES rides(ride_id),
    FOREIGN KEY (driver_id) REFERENCES drivers(driver_id),
    FOREIGN KEY (rider_id) REFERENCES users(user_id)
);

-- Create Ride Requests Log Table (for analytics)
CREATE TABLE ride_requests_log (
    log_id NUMBER PRIMARY KEY,
    rider_id NUMBER NOT NULL,
    pickup_location VARCHAR2(200),
    dropoff_location VARCHAR2(200),
    vehicle_type VARCHAR2(20),
    requested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    was_matched NUMBER(1) DEFAULT 0,
    time_to_match_seconds NUMBER,
    FOREIGN KEY (rider_id) REFERENCES users(user_id)
);

-- =====================================================
-- STEP 2: CREATE SEQUENCES FOR AUTO-INCREMENT
-- =====================================================

CREATE SEQUENCE users_seq START WITH 1001 INCREMENT BY 1;
CREATE SEQUENCE drivers_seq START WITH 2001 INCREMENT BY 1;
CREATE SEQUENCE rides_seq START WITH 3001 INCREMENT BY 1;
CREATE SEQUENCE payments_seq START WITH 4001 INCREMENT BY 1;
CREATE SEQUENCE messages_seq START WITH 5001 INCREMENT BY 1;
CREATE SEQUENCE tracking_seq START WITH 6001 INCREMENT BY 1;
CREATE SEQUENCE ratings_seq START WITH 7001 INCREMENT BY 1;
CREATE SEQUENCE log_seq START WITH 8001 INCREMENT BY 1;

-- =====================================================
-- STEP 3: CREATE INDEXES FOR PERFORMANCE
-- =====================================================

-- Users indexes
-- Skipped: users(email) is already indexed via the UNIQUE constraint on email
-- CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_users_role ON users(role);

-- Drivers indexes
CREATE INDEX idx_drivers_user ON drivers(user_id);
CREATE INDEX idx_drivers_available ON drivers(is_available);
CREATE INDEX idx_drivers_vehicle_type ON drivers(vehicle_type);

-- Rides indexes
CREATE INDEX idx_rides_rider ON rides(rider_id);
CREATE INDEX idx_rides_driver ON rides(driver_id);
CREATE INDEX idx_rides_status ON rides(status);
CREATE INDEX idx_rides_date ON rides(requested_at);

-- Payments indexes
CREATE INDEX idx_payments_ride ON payments(ride_id);
CREATE INDEX idx_payments_method ON payments(method);
CREATE INDEX idx_payments_success ON payments(is_successful);

-- Tracking indexes
CREATE INDEX idx_tracking_driver ON tracking(driver_id);
CREATE INDEX idx_tracking_ride ON tracking(ride_id);
CREATE INDEX idx_tracking_timestamp ON tracking(timestamp);

-- History table to store an immutable log of tracking updates (for the location update logging trigger)
CREATE TABLE tracking_history (
    history_id NUMBER PRIMARY KEY,
    tracking_id NUMBER,
    driver_id NUMBER NOT NULL,
    ride_id NUMBER,
    latitude NUMBER(10,8) NOT NULL,
    longitude NUMBER(11,8) NOT NULL,
    speed NUMBER(5,2) DEFAULT 0,
    heading NUMBER(5,2),
    logged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (driver_id) REFERENCES drivers(driver_id),
    FOREIGN KEY (ride_id) REFERENCES rides(ride_id)
);

CREATE SEQUENCE tracking_history_seq START WITH 9001 INCREMENT BY 1;


-- =====================================================
-- STEP 4: INSERT SAMPLE DATA
-- =====================================================

-- Insert Users (Riders and Drivers)
INSERT INTO users VALUES (users_seq.NEXTVAL, 'Jean Baptiste Uwimana', 'jean.uwimana@moca.rw', '0781234567', 'rider', 'hashed_password_1', NULL, CURRENT_TIMESTAMP);
INSERT INTO users VALUES (users_seq.NEXTVAL, 'Marie Claire Mukasine', 'marie.mukasine@moca.rw', '0782345678', 'rider', 'hashed_password_2', NULL, CURRENT_TIMESTAMP);
INSERT INTO users VALUES (users_seq.NEXTVAL, 'Patrick Nkurunziza', 'patrick.nkuru@moca.rw', '0783456789', 'driver', 'hashed_password_3', NULL, CURRENT_TIMESTAMP);
INSERT INTO users VALUES (users_seq.NEXTVAL, 'Agnes Mukabaranga', 'agnes.muka@moca.rw', '0784567890', 'driver', 'hashed_password_4', NULL, CURRENT_TIMESTAMP);
INSERT INTO users VALUES (users_seq.NEXTVAL, 'Samuel Habimana', 'samuel.habi@moca.rw', '0785678901', 'rider', 'hashed_password_5', NULL, CURRENT_TIMESTAMP);
INSERT INTO users VALUES (users_seq.NEXTVAL, 'Grace Uwamahoro', 'grace.uwama@moca.rw', '0786789012', 'driver', 'hashed_password_6', NULL, CURRENT_TIMESTAMP);
INSERT INTO users VALUES (users_seq.NEXTVAL, 'Emmanuel Bizimana', 'emma.bizi@moca.rw', '0787890123', 'driver', 'hashed_password_7', NULL, CURRENT_TIMESTAMP);
INSERT INTO users VALUES (users_seq.NEXTVAL, 'Esperance Nyiraneza', 'esp.nyira@moca.rw', '0788901234', 'rider', 'hashed_password_8', NULL, CURRENT_TIMESTAMP);
INSERT INTO users VALUES (users_seq.NEXTVAL, 'David Mugisha', 'david.mugi@moca.rw', '0789012345', 'driver', 'hashed_password_9', NULL, CURRENT_TIMESTAMP);
INSERT INTO users VALUES (users_seq.NEXTVAL, 'Immaculee Uwera', 'imma.uwera@moca.rw', '0780123456', 'rider', 'hashed_password_10', NULL, CURRENT_TIMESTAMP);

-- Insert Drivers
INSERT INTO drivers VALUES (drivers_seq.NEXTVAL, 1003, 'DL2023001', 'car', 'RAD123A', 4.5, 1, 45);
INSERT INTO drivers VALUES (drivers_seq.NEXTVAL, 1004, 'DL2023002', 'moto', 'RAD456B', 4.8, 1, 120);
INSERT INTO drivers VALUES (drivers_seq.NEXTVAL, 1006, 'DL2023003', 'car', 'RAD789C', 4.2, 1, 67);
INSERT INTO drivers VALUES (drivers_seq.NEXTVAL, 1007, 'DL2023004', 'moto', 'RAD012D', 4.9, 1, 89);
INSERT INTO drivers VALUES (drivers_seq.NEXTVAL, 1009, 'DL2023005', 'delivery', 'RAD345E', 4.6, 1, 34);

-- Insert Rides (Last 6 months of data)
INSERT INTO rides (ride_id, rider_id, driver_id, pickup_location, dropoff_location, pickup_latitude, pickup_longitude, dropoff_latitude, dropoff_longitude, fare_amount, payment_method, status, updated_at, requested_at, started_at, completed_at, distance_km, duration_minutes)
VALUES (rides_seq.NEXTVAL, 1001, 2001, 'KN 5 Ave, Kigali', 'KG 11 Ave, Kigali', -1.9441, 30.0619, -1.9506, 30.0944, 3500.00, 'momo', 'completed', NULL, TIMESTAMP '2024-06-15 08:30:00', TIMESTAMP '2024-06-15 08:32:00', TIMESTAMP '2024-06-15 08:47:00', 5.2, 15);
INSERT INTO rides (ride_id, rider_id, driver_id, pickup_location, dropoff_location, pickup_latitude, pickup_longitude, dropoff_latitude, dropoff_longitude, fare_amount, payment_method, status, updated_at, requested_at, started_at, completed_at, distance_km, duration_minutes)
VALUES (rides_seq.NEXTVAL, 1002, 2002, 'Nyarugenge, Kigali', 'Kimironko, Kigali', -1.9500, 30.0588, -1.9536, 30.1044, 2500.00, 'card', 'completed', NULL, TIMESTAMP '2024-06-18 14:20:00', TIMESTAMP '2024-06-18 14:21:00', TIMESTAMP '2024-06-18 14:32:00', 4.1, 11);
INSERT INTO rides (ride_id, rider_id, driver_id, pickup_location, dropoff_location, pickup_latitude, pickup_longitude, dropoff_latitude, dropoff_longitude, fare_amount, payment_method, status, updated_at, requested_at, started_at, completed_at, distance_km, duration_minutes)
VALUES (rides_seq.NEXTVAL, 1005, 2003, 'Remera, Kigali', 'Airport, Kigali', -1.9578, 30.1044, -1.9686, 30.1394, 4500.00, 'nfc', 'completed', NULL, TIMESTAMP '2024-07-02 06:15:00', TIMESTAMP '2024-07-02 06:16:00', TIMESTAMP '2024-07-02 06:35:00', 7.8, 19);
INSERT INTO rides (ride_id, rider_id, driver_id, pickup_location, dropoff_location, pickup_latitude, pickup_longitude, dropoff_latitude, dropoff_longitude, fare_amount, payment_method, status, updated_at, requested_at, started_at, completed_at, distance_km, duration_minutes)
VALUES (rides_seq.NEXTVAL, 1001, 2004, 'Kimihurura, Kigali', 'Downtown Kigali', -1.9447, 30.0958, -1.9536, 30.0588, 2000.00, 'momo', 'completed', NULL, TIMESTAMP '2024-07-10 10:45:00', TIMESTAMP '2024-07-10 10:46:00', TIMESTAMP '2024-07-10 10:56:00', 3.2, 10);
INSERT INTO rides (ride_id, rider_id, driver_id, pickup_location, dropoff_location, pickup_latitude, pickup_longitude, dropoff_latitude, dropoff_longitude, fare_amount, payment_method, status, updated_at, requested_at, started_at, completed_at, distance_km, duration_minutes)
VALUES (rides_seq.NEXTVAL, 1008, 2001, 'Gikondo, Kigali', 'Kacyiru, Kigali', -1.9833, 30.0747, -1.9447, 30.0958, 4000.00, 'qr', 'completed', NULL, TIMESTAMP '2024-07-22 16:30:00', TIMESTAMP '2024-07-22 16:32:00', TIMESTAMP '2024-07-22 16:52:00', 6.5, 20);
INSERT INTO rides (ride_id, rider_id, driver_id, pickup_location, dropoff_location, pickup_latitude, pickup_longitude, dropoff_latitude, dropoff_longitude, fare_amount, payment_method, status, updated_at, requested_at, started_at, completed_at, distance_km, duration_minutes)
VALUES (rides_seq.NEXTVAL, 1002, 2002, 'Nyamirambo, Kigali', 'CBD Kigali', -1.9719, 30.0472, -1.9536, 30.0588, 1800.00, 'card', 'completed', NULL, TIMESTAMP '2024-08-05 12:00:00', TIMESTAMP '2024-08-05 12:01:00', TIMESTAMP '2024-08-05 12:11:00', 2.8, 10);
INSERT INTO rides (ride_id, rider_id, driver_id, pickup_location, dropoff_location, pickup_latitude, pickup_longitude, dropoff_latitude, dropoff_longitude, fare_amount, payment_method, status, updated_at, requested_at, started_at, completed_at, distance_km, duration_minutes)
VALUES (rides_seq.NEXTVAL, 1005, 2003, 'Kicukiro, Kigali', 'Rebero, Kigali', -1.9833, 30.1044, -1.9578, 30.0906, 3200.00, 'momo', 'completed', NULL, TIMESTAMP '2024-08-14 18:20:00', TIMESTAMP '2024-08-14 18:22:00', TIMESTAMP '2024-08-14 18:38:00', 4.9, 16);
INSERT INTO rides (ride_id, rider_id, driver_id, pickup_location, dropoff_location, pickup_latitude, pickup_longitude, dropoff_latitude, dropoff_longitude, fare_amount, payment_method, status, updated_at, requested_at, started_at, completed_at, distance_km, duration_minutes)
VALUES (rides_seq.NEXTVAL, 1010, 2004, 'Gisozi, Kigali', 'Muhima, Kigali', -1.9283, 30.0833, -1.9578, 30.0644, 2800.00, 'nfc', 'completed', NULL, TIMESTAMP '2024-09-02 09:15:00', TIMESTAMP '2024-09-02 09:16:00', TIMESTAMP '2024-09-02 09:28:00', 3.8, 12);
INSERT INTO rides (ride_id, rider_id, driver_id, pickup_location, dropoff_location, pickup_latitude, pickup_longitude, dropoff_latitude, dropoff_longitude, fare_amount, payment_method, status, updated_at, requested_at, started_at, completed_at, distance_km, duration_minutes)
VALUES (rides_seq.NEXTVAL, 1001, 2001, 'Kagugu, Kigali', 'Kimironko Market', -1.9314, 30.1181, -1.9536, 30.1044, 2200.00, 'paypal', 'completed', NULL, TIMESTAMP '2024-09-18 15:45:00', TIMESTAMP '2024-09-18 15:46:00', TIMESTAMP '2024-09-18 15:56:00', 3.1, 10);
INSERT INTO rides (ride_id, rider_id, driver_id, pickup_location, dropoff_location, pickup_latitude, pickup_longitude, dropoff_latitude, dropoff_longitude, fare_amount, payment_method, status, updated_at, requested_at, started_at, completed_at, distance_km, duration_minutes)
VALUES (rides_seq.NEXTVAL, 1008, 2005, 'Kanombe, Kigali', 'Nyabugogo', -1.9686, 30.1394, -1.9419, 30.0594, 5500.00, 'momo', 'completed', NULL, TIMESTAMP '2024-10-01 07:30:00', TIMESTAMP '2024-10-01 07:32:00', TIMESTAMP '2024-10-01 07:58:00', 9.2, 26);
INSERT INTO rides (ride_id, rider_id, driver_id, pickup_location, dropoff_location, pickup_latitude, pickup_longitude, dropoff_latitude, dropoff_longitude, fare_amount, payment_method, status, updated_at, requested_at, started_at, completed_at, distance_km, duration_minutes)
VALUES (rides_seq.NEXTVAL, 1002, 2002, 'Kacyiru, Kigali', 'Gikondo Industrial', -1.9447, 30.0958, -1.9833, 30.0747, 3800.00, 'card', 'completed', NULL, TIMESTAMP '2024-10-12 11:20:00', TIMESTAMP '2024-10-12 11:21:00', TIMESTAMP '2024-10-12 11:40:00', 5.8, 19);
INSERT INTO rides (ride_id, rider_id, driver_id, pickup_location, dropoff_location, pickup_latitude, pickup_longitude, dropoff_latitude, dropoff_longitude, fare_amount, payment_method, status, updated_at, requested_at, started_at, completed_at, distance_km, duration_minutes)
VALUES (rides_seq.NEXTVAL, 1005, 2003, 'CBD Kigali', 'Rebero Hill', -1.9536, 30.0588, -1.9578, 30.0906, 3500.00, 'qr', 'completed', NULL, TIMESTAMP '2024-10-25 13:00:00', TIMESTAMP '2024-10-25 13:02:00', TIMESTAMP '2024-10-25 13:20:00', 5.1, 18);
INSERT INTO rides (ride_id, rider_id, driver_id, pickup_location, dropoff_location, pickup_latitude, pickup_longitude, dropoff_latitude, dropoff_longitude, fare_amount, payment_method, status, updated_at, requested_at, started_at, completed_at, distance_km, duration_minutes)
VALUES (rides_seq.NEXTVAL, 1010, 2004, 'Nyarutarama, Kigali', 'Kimihurura', -1.9369, 30.1133, -1.9447, 30.0958, 2400.00, 'momo', 'completed', NULL, TIMESTAMP '2024-11-03 08:45:00', TIMESTAMP '2024-11-03 08:46:00', TIMESTAMP '2024-11-03 08:58:00', 3.5, 12);
INSERT INTO rides (ride_id, rider_id, driver_id, pickup_location, dropoff_location, pickup_latitude, pickup_longitude, dropoff_latitude, dropoff_longitude, fare_amount, payment_method, status, updated_at, requested_at, started_at, completed_at, distance_km, duration_minutes)
VALUES (rides_seq.NEXTVAL, 1001, 2001, 'Airport Road', 'City Center', -1.9686, 30.1394, -1.9536, 30.0588, 5000.00, 'nfc', 'completed', NULL, TIMESTAMP '2024-11-10 17:30:00', TIMESTAMP '2024-11-10 17:32:00', TIMESTAMP '2024-11-10 17:56:00', 8.1, 24);
INSERT INTO rides (ride_id, rider_id, driver_id, pickup_location, dropoff_location, pickup_latitude, pickup_longitude, dropoff_latitude, dropoff_longitude, fare_amount, payment_method, status, updated_at, requested_at, started_at, completed_at, distance_km, duration_minutes)
VALUES (rides_seq.NEXTVAL, 1008, 2002, 'Kimironko, Kigali', 'Nyamirambo', -1.9536, 30.1044, -1.9719, 30.0472, 3000.00, 'card', 'active', NULL, TIMESTAMP '2024-11-17 10:15:00', TIMESTAMP '2024-11-17 10:16:00', NULL, NULL, NULL);
INSERT INTO rides (ride_id, rider_id, driver_id, pickup_location, dropoff_location, pickup_latitude, pickup_longitude, dropoff_latitude, dropoff_longitude, fare_amount, payment_method, status, updated_at, requested_at, started_at, completed_at, distance_km, duration_minutes)
VALUES (rides_seq.NEXTVAL, 1002, 2003, 'Remera, Kigali', 'Kicukiro Center', -1.9578, 30.1044, -1.9833, 30.1044, 2600.00, 'momo', 'requested', NULL, TIMESTAMP '2024-11-17 10:25:00', NULL, NULL, NULL, NULL);

-- Insert Payments
INSERT INTO payments VALUES (payments_seq.NEXTVAL, 3001, 3500.00, 'momo', 'MOMO2024061512345', 1, TIMESTAMP '2024-06-15 08:47:30', 'MTN Mobile Money');
INSERT INTO payments VALUES (payments_seq.NEXTVAL, 3002, 2500.00, 'card', 'CARD2024061867890', 1, TIMESTAMP '2024-06-18 14:32:15', 'Visa **** 4532');
INSERT INTO payments VALUES (payments_seq.NEXTVAL, 3003, 4500.00, 'nfc', 'NFC2024070211223', 1, TIMESTAMP '2024-07-02 06:35:45', 'Apple Pay');
INSERT INTO payments VALUES (payments_seq.NEXTVAL, 3004, 2000.00, 'momo', 'MOMO2024071044556', 1, TIMESTAMP '2024-07-10 10:56:20', 'Airtel Money');
INSERT INTO payments VALUES (payments_seq.NEXTVAL, 3005, 4000.00, 'qr', 'QR2024072277889', 1, TIMESTAMP '2024-07-22 16:52:30', 'QR Payment Gateway');
INSERT INTO payments VALUES (payments_seq.NEXTVAL, 3006, 1800.00, 'card', 'CARD2024080533221', 1, TIMESTAMP '2024-08-05 12:11:10', 'Mastercard **** 8765');
INSERT INTO payments VALUES (payments_seq.NEXTVAL, 3007, 3200.00, 'momo', 'MOMO2024081466554', 1, TIMESTAMP '2024-08-14 18:38:25', 'MTN Mobile Money');
INSERT INTO payments VALUES (payments_seq.NEXTVAL, 3008, 2800.00, 'nfc', 'NFC2024090299887', 1, TIMESTAMP '2024-09-02 09:28:40', 'Google Pay');
INSERT INTO payments VALUES (payments_seq.NEXTVAL, 3009, 2200.00, 'paypal', 'PAYPAL202409188877', 1, TIMESTAMP '2024-09-18 15:56:15', 'PayPal Transaction');
INSERT INTO payments VALUES (payments_seq.NEXTVAL, 3010, 5500.00, 'momo', 'MOMO2024100155443', 1, TIMESTAMP '2024-10-01 07:58:20', 'Airtel Money');
INSERT INTO payments VALUES (payments_seq.NEXTVAL, 3011, 3800.00, 'card', 'CARD2024101222334', 1, TIMESTAMP '2024-10-12 11:40:35', 'Visa **** 2341');
INSERT INTO payments VALUES (payments_seq.NEXTVAL, 3012, 3500.00, 'qr', 'QR2024102566778', 1, TIMESTAMP '2024-10-25 13:20:50', 'QR Payment Gateway');
INSERT INTO payments VALUES (payments_seq.NEXTVAL, 3013, 2400.00, 'momo', 'MOMO2024110388990', 1, TIMESTAMP '2024-11-03 08:58:15', 'MTN Mobile Money');
INSERT INTO payments VALUES (payments_seq.NEXTVAL, 3014, 5000.00, 'nfc', 'NFC2024111011223', 1, TIMESTAMP '2024-11-10 17:56:30', 'Apple Pay');

-- Insert Messages
INSERT INTO messages VALUES (messages_seq.NEXTVAL, 1001, 1003, 3001, 'I am at the main entrance', 1, TIMESTAMP '2024-06-15 08:31:00');
INSERT INTO messages VALUES (messages_seq.NEXTVAL, 1003, 1001, 3001, 'I can see you, arriving in 1 minute', 1, TIMESTAMP '2024-06-15 08:31:30');
INSERT INTO messages VALUES (messages_seq.NEXTVAL, 1002, 1004, 3002, 'Please use the back gate', 1, TIMESTAMP '2024-06-18 14:21:15');
INSERT INTO messages VALUES (messages_seq.NEXTVAL, 1005, 1006, 3003, 'On my way to airport, heavy traffic', 1, TIMESTAMP '2024-07-02 06:20:00');
INSERT INTO messages VALUES (messages_seq.NEXTVAL, 1008, 1003, 3005, 'Can you wait 2 minutes? Just finishing payment', 1, TIMESTAMP '2024-07-22 16:31:00');

-- Insert Tracking Data (sample real-time tracking points)
INSERT INTO tracking VALUES (tracking_seq.NEXTVAL, 2001, 3001, -1.9441, 30.0619, 25.5, 90, TIMESTAMP '2024-06-15 08:32:00');
INSERT INTO tracking VALUES (tracking_seq.NEXTVAL, 2001, 3001, -1.9465, 30.0700, 35.2, 85, TIMESTAMP '2024-06-15 08:37:00');
INSERT INTO tracking VALUES (tracking_seq.NEXTVAL, 2001, 3001, -1.9490, 30.0822, 40.0, 78, TIMESTAMP '2024-06-15 08:42:00');
INSERT INTO tracking VALUES (tracking_seq.NEXTVAL, 2001, 3001, -1.9506, 30.0944, 15.0, 70, TIMESTAMP '2024-06-15 08:46:00');
INSERT INTO tracking VALUES (tracking_seq.NEXTVAL, 2002, 3015, -1.9578, 30.1044, 28.3, 120, TIMESTAMP '2024-11-17 10:16:00');
INSERT INTO tracking VALUES (tracking_seq.NEXTVAL, 2002, 3015, -1.9620, 30.0900, 32.1, 115, TIMESTAMP '2024-11-17 10:20:00');

-- Insert Driver Ratings
INSERT INTO driver_ratings VALUES (ratings_seq.NEXTVAL, 3001, 2001, 1001, 5, 'Excellent driver, very professional', TIMESTAMP '2024-06-15 08:50:00');
INSERT INTO driver_ratings VALUES (ratings_seq.NEXTVAL, 3002, 2002, 1002, 5, 'Fast and safe ride', TIMESTAMP '2024-06-18 14:35:00');
INSERT INTO driver_ratings VALUES (ratings_seq.NEXTVAL, 3003, 2003, 1005, 4, 'Good service but took longer route', TIMESTAMP '2024-07-02 06:40:00');
INSERT INTO driver_ratings VALUES (ratings_seq.NEXTVAL, 3004, 2004, 1001, 5, 'Amazing moto driver, very skilled', TIMESTAMP '2024-07-10 11:00:00');
INSERT INTO driver_ratings VALUES (ratings_seq.NEXTVAL, 3005, 2001, 1008, 4, 'Professional and courteous', TIMESTAMP '2024-07-22 17:00:00');
INSERT INTO driver_ratings VALUES (ratings_seq.NEXTVAL, 3006, 2002, 1002, 5, 'Quick pickup and smooth ride', TIMESTAMP '2024-08-05 12:15:00');
INSERT INTO driver_ratings VALUES (ratings_seq.NEXTVAL, 3007, 2003, 1005, 4, 'Good driver, clean car', TIMESTAMP '2024-08-14 18:45:00');
INSERT INTO driver_ratings VALUES (ratings_seq.NEXTVAL, 3008, 2004, 1010, 5, 'Best moto ride ever!', TIMESTAMP '2024-09-02 09:35:00');
INSERT INTO driver_ratings VALUES (ratings_seq.NEXTVAL, 3009, 2001, 1001, 4, 'Reliable as always', TIMESTAMP '2024-09-18 16:00:00');
INSERT INTO driver_ratings VALUES (ratings_seq.NEXTVAL, 3010, 2005, 1008, 5, 'Delivery was perfect and on time', TIMESTAMP '2024-10-01 08:05:00');

-- Additional 100 Ride Requests Log test rows
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1001, 'KN 5 Ave, Kigali', 'KG 11 Ave, Kigali', 'car', TIMESTAMP '2024-06-16 08:05:00', 1, 60);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1002, 'Nyamirambo, Kigali', 'CBD Kigali', 'moto', TIMESTAMP '2024-06-16 09:10:00', 1, 120);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1005, 'Remera, Kigali', 'Airport, Kigali', 'car', TIMESTAMP '2024-06-17 07:45:00', 1, 90);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1008, 'Kicukiro, Kigali', 'Rebero, Kigali', 'delivery', TIMESTAMP '2024-06-17 12:20:00', 0, NULL);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1010, 'Gisozi, Kigali', 'Muhima, Kigali', 'moto', TIMESTAMP '2024-06-18 10:15:00', 1, 75);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1001, 'Kacyiru, Kigali', 'Gikondo Industrial', 'car', TIMESTAMP '2024-06-19 14:30:00', 1, 140);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1002, 'Kimironko Market', 'Kagugu, Kigali', 'moto', TIMESTAMP '2024-06-20 08:50:00', 1, 55);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1005, 'Kanombe, Kigali', 'Nyabugogo', 'delivery', TIMESTAMP '2024-06-20 18:05:00', 1, 210);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1008, 'Nyarutarama, Kigali', 'Kimihurura', 'car', TIMESTAMP '2024-06-21 07:32:00', 1, 80);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1010, 'Airport Road', 'City Center', 'n/a', TIMESTAMP '2024-06-21 17:25:00', 0, NULL);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1001, 'Kabeza, Kigali', 'Kanombe, Kigali', 'moto', TIMESTAMP '2024-06-22 09:05:00', 1, 65);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1002, 'Kigali Heights', 'Kacyiru Police', 'car', TIMESTAMP '2024-06-22 11:40:00', 1, 95);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1005, 'Nyabugogo', 'Kimironko, Kigali', 'delivery', TIMESTAMP '2024-06-22 16:10:00', 1, 230);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1008, 'Gikondo, Kigali', 'Kicukiro Center', 'moto', TIMESTAMP '2024-06-23 07:58:00', 1, 70);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1010, 'Remera, Kigali', 'Amahoro Stadium', 'car', TIMESTAMP '2024-06-23 12:25:00', 1, 85);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1001, 'Kimironko, Kigali', 'Masoro SEZ', 'delivery', TIMESTAMP '2024-06-24 10:00:00', 0, NULL);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1002, 'Gisozi Genocide Memorial', 'Kimironko Market', 'car', TIMESTAMP '2024-06-24 15:10:00', 1, 110);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1005, 'Kimironko Bus Park', 'Kagugu, Kigali', 'moto', TIMESTAMP '2024-06-25 08:05:00', 1, 45);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1008, 'Kacyiru, Kigali', 'CBD Kigali', 'car', TIMESTAMP '2024-06-25 17:40:00', 1, 150);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1010, 'Rwanda Revenue Authority', 'Soras, Kigali', 'moto', TIMESTAMP '2024-06-26 09:25:00', 1, 75);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1001, 'Kimironko, Kigali', 'Kimironko Market', 'delivery', TIMESTAMP '2024-06-26 13:50:00', 1, 200);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1002, 'Nyarugenge, Kigali', 'Kacyiru, Kigali', 'car', TIMESTAMP '2024-06-27 10:35:00', 0, NULL);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1005, 'Kimihurura, Kigali', 'Kacyiru, Kigali', 'moto', TIMESTAMP '2024-06-27 18:15:00', 1, 65);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1008, 'Remera, Kigali', 'Airport, Kigali', 'car', TIMESTAMP '2024-06-28 05:55:00', 1, 85);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1010, 'Kigali Convention Centre', 'Kacyiru, Kigali', 'moto', TIMESTAMP '2024-06-28 22:10:00', 1, 70);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1001, 'Kimironko, Kigali', 'Remera, Kigali', 'car', TIMESTAMP '2024-06-29 07:45:00', 1, 60);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1002, 'Gikondo Industrial', 'Gahanga', 'delivery', TIMESTAMP '2024-06-29 16:05:00', 0, NULL);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1005, 'Gikondo, Kigali', 'Kagarama, Kigali', 'moto', TIMESTAMP '2024-06-30 08:20:00', 1, 55);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1008, 'Kagarama, Kigali', 'Rebero, Kigali', 'car', TIMESTAMP '2024-06-30 12:50:00', 1, 95);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1010, 'Kibagabaga Hospital', 'Kimironko, Kigali', 'moto', TIMESTAMP '2024-06-30 18:30:00', 1, 65);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1001, 'Kabeza, Kigali', 'Kanombe Airport', 'car', TIMESTAMP '2024-07-01 06:10:00', 1, 100);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1002, 'Gahanga, Kigali', 'SEZ, Kigali', 'delivery', TIMESTAMP '2024-07-01 09:25:00', 1, 260);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1005, 'Kigali Heights', 'Kimironko, Kigali', 'moto', TIMESTAMP '2024-07-01 13:05:00', 1, 50);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1008, 'Kicukiro Center', 'Gikondo Industrial', 'car', TIMESTAMP '2024-07-01 19:20:00', 1, 140);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1010, 'Nyamirambo, Kigali', 'Kacyiru, Kigali', 'moto', TIMESTAMP '2024-07-02 08:30:00', 1, 80);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1001, 'Nyarugenge, Kigali', 'Gisozi, Kigali', 'car', TIMESTAMP '2024-07-02 12:15:00', 1, 105);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1002, 'Kimironko, Kigali', 'Nyarutarama, Kigali', 'moto', TIMESTAMP '2024-07-02 17:45:00', 1, 70);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1005, 'Gisozi, Kigali', 'Kagugu, Kigali', 'car', TIMESTAMP '2024-07-03 09:00:00', 1, 85);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1008, 'Kacyiru, Kigali', 'Remera, Kigali', 'delivery', TIMESTAMP '2024-07-03 11:50:00', 1, 240);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1010, 'Kimironko, Kigali', 'Kibagabaga, Kigali', 'moto', TIMESTAMP '2024-07-03 20:25:00', 0, NULL);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1001, 'Kicukiro, Kigali', 'Gikondo, Kigali', 'car', TIMESTAMP '2024-07-04 07:35:00', 1, 90);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1002, 'Ndera, Kigali', 'Kimironko, Kigali', 'moto', TIMESTAMP '2024-07-04 10:45:00', 1, 60);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1005, 'Kigali Arena', 'Remera, Kigali', 'car', TIMESTAMP '2024-07-04 18:00:00', 1, 100);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1008, 'Masaka, Kigali', 'SEZ, Kigali', 'delivery', TIMESTAMP '2024-07-05 08:10:00', 1, 300);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1010, 'Gashyuha, Kigali', 'Kimihurura, Kigali', 'moto', TIMESTAMP '2024-07-05 12:30:00', 1, 85);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1001, 'Kimisagara, Kigali', 'Nyabugogo', 'car', TIMESTAMP '2024-07-05 16:25:00', 1, 95);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1002, 'Biryogo, Kigali', 'Nyamirambo, Kigali', 'moto', TIMESTAMP '2024-07-06 09:40:00', 1, 55);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1005, 'Kacyiru Police', 'Ministry of Justice', 'car', TIMESTAMP '2024-07-06 14:50:00', 1, 110);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1008, 'Kicukiro, Kigali', 'Kabeza, Kigali', 'moto', TIMESTAMP '2024-07-06 20:10:00', 0, NULL);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1010, 'Kimironko, Kigali', 'Kibiraro, Kigali', 'car', TIMESTAMP '2024-07-07 07:25:00', 1, 85);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1001, 'Gacuriro, Kigali', 'Nyarutarama, Kigali', 'moto', TIMESTAMP '2024-07-07 12:40:00', 1, 65);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1002, 'Kaltura, Kigali', 'Gikondo, Kigali', 'delivery', TIMESTAMP '2024-07-07 15:15:00', 1, 280);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1005, 'Kigali Business Center', 'Remera, Kigali', 'car', TIMESTAMP '2024-07-08 09:05:00', 1, 95);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1008, 'Kacyiru, Kigali', 'Kigali Convention Centre', 'moto', TIMESTAMP '2024-07-08 13:35:00', 1, 70);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1010, 'Kigali Serena Hotel', 'CBD Kigali', 'car', TIMESTAMP '2024-07-08 18:45:00', 1, 120);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1001, 'Kimironko, Kigali', 'Sonatubes, Kigali', 'moto', TIMESTAMP '2024-07-09 08:20:00', 1, 60);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1002, 'Gikondo, Kigali', 'Kicukiro, Kigali', 'car', TIMESTAMP '2024-07-09 11:10:00', 1, 100);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1005, 'Remera, Kigali', 'Kabeza, Kigali', 'moto', TIMESTAMP '2024-07-09 20:00:00', 1, 55);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1008, 'Kicukiro, Kigali', 'Masaka, Kigali', 'delivery', TIMESTAMP '2024-07-10 07:45:00', 1, 320);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1010, 'Kigali Arena', 'BK Arena Parking', 'moto', TIMESTAMP '2024-07-10 21:35:00', 1, 75);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1001, 'Gisozi, Kigali', 'Kacyiru, Kigali', 'car', TIMESTAMP '2024-07-11 10:05:00', 1, 110);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1002, 'Kicukiro, Kigali', 'Rebero, Kigali', 'car', TIMESTAMP '2024-07-11 13:25:00', 0, NULL);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1005, 'Kigali Airport', 'Remera, Kigali', 'moto', TIMESTAMP '2024-07-11 16:50:00', 1, 65);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1008, 'Kimironko, Kigali', 'Kagugu, Kigali', 'car', TIMESTAMP '2024-07-12 07:30:00', 1, 100);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1010, 'Kacyiru, Kigali', 'Nyarugenge, Kigali', 'moto', TIMESTAMP '2024-07-12 09:05:00', 1, 85);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1001, 'Gikondo Industrial', 'SEZ, Kigali', 'delivery', TIMESTAMP '2024-07-12 11:40:00', 1, 290);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1002, 'Kibagabaga, Kigali', 'Kimironko, Kigali', 'car', TIMESTAMP '2024-07-12 15:15:00', 1, 105);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1005, 'Kacyiru, Kigali', 'Kimironko, Kigali', 'moto', TIMESTAMP '2024-07-13 08:20:00', 1, 55);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1008, 'Remera, Kigali', 'Kigali Arena', 'car', TIMESTAMP '2024-07-13 12:30:00', 1, 115);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1010, 'Gisozi, Kigali', 'Kimironko, Kigali', 'moto', TIMESTAMP '2024-07-13 19:25:00', 0, NULL);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1001, 'Nyarutarama, Kigali', 'Kagugu, Kigali', 'car', TIMESTAMP '2024-07-14 09:00:00', 1, 95);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1002, 'Kicukiro, Kigali', 'Ndera, Kigali', 'moto', TIMESTAMP '2024-07-14 11:35:00', 1, 70);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1005, 'SEZ, Kigali', 'Masaka, Kigali', 'delivery', TIMESTAMP '2024-07-14 15:45:00', 1, 310);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1008, 'Kacyiru, Kigali', 'Gisozi, Kigali', 'car', TIMESTAMP '2024-07-15 07:10:00', 1, 100);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1010, 'Kimironko, Kigali', 'Remera, Kigali', 'moto', TIMESTAMP '2024-07-15 13:20:00', 1, 65);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1001, 'Kagugu, Kigali', 'Kibagabaga, Kigali', 'car', TIMESTAMP '2024-07-15 18:00:00', 1, 105);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1002, 'Kicukiro, Kigali', 'Sonatubes, Kigali', 'moto', TIMESTAMP '2024-07-16 08:40:00', 1, 60);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1005, 'Nyabugogo', 'Kimisagara, Kigali', 'car', TIMESTAMP '2024-07-16 12:15:00', 1, 120);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1008, 'Biryogo, Kigali', 'Rugunga, Kigali', 'moto', TIMESTAMP '2024-07-16 19:20:00', 1, 70);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1010, 'Kacyiru, Kigali', 'Kigali Heights', 'car', TIMESTAMP '2024-07-17 07:55:00', 1, 110);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1001, 'Kagugu, Kigali', 'Gacuriro, Kigali', 'moto', TIMESTAMP '2024-07-17 11:45:00', 1, 65);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1002, 'Rwandex, Kigali', 'Gikondo Industrial', 'delivery', TIMESTAMP '2024-07-17 16:05:00', 1, 295);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1005, 'Kimironko, Kigali', 'Kibagabaga Hospital', 'car', TIMESTAMP '2024-07-18 09:10:00', 1, 95);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1008, 'Kimihurura, Kigali', 'Kacyiru Police', 'moto', TIMESTAMP '2024-07-18 14:25:00', 1, 80);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1010, 'Kigali Convention Centre', 'RDB, Kigali', 'car', TIMESTAMP '2024-07-18 18:50:00', 1, 120);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1001, 'Kicukiro, Kigali', 'Masaka, Kigali', 'moto', TIMESTAMP '2024-07-19 07:20:00', 1, 70);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1002, 'Kimironko Market', 'Nyarutarama, Kigali', 'car', TIMESTAMP '2024-07-19 10:30:00', 1, 100);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1005, 'Gikondo, Kigali', 'Kabeza, Kigali', 'moto', TIMESTAMP '2024-07-19 21:05:00', 1, 60);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1008, 'Kacyiru, Kigali', 'Kimironko Bus Park', 'car', TIMESTAMP '2024-07-20 08:00:00', 1, 115);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1010, 'Remera, Kigali', 'Kimironko, Kigali', 'moto', TIMESTAMP '2024-07-20 12:35:00', 0, NULL);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1001, 'Kimironko, Kigali', 'Kagugu, Kigali', 'car', TIMESTAMP '2024-07-20 17:40:00', 1, 105);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1002, 'Kigarama, Kigali', 'Nyarugunga, Kigali', 'moto', TIMESTAMP '2024-07-21 09:15:00', 1, 75);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1005, 'Kabeza, Kigali', 'Kanombe, Kigali', 'car', TIMESTAMP '2024-07-21 11:50:00', 1, 90);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1008, 'Kagugu, Kigali', 'Kibagabaga, Kigali', 'moto', TIMESTAMP '2024-07-21 19:35:00', 1, 70);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1010, 'Kimironko, Kigali', 'Kimironko Market', 'delivery', TIMESTAMP '2024-07-22 10:05:00', 1, 260);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1001, 'Gisozi, Kigali', 'Remera, Kigali', 'car', TIMESTAMP '2024-07-22 14:20:00', 1, 110);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1002, 'Kacyiru, Kigali', 'City Center', 'moto', TIMESTAMP '2024-07-22 18:55:00', 1, 85);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1005, 'Nyarugenge, Kigali', 'Kacyiru, Kigali', 'car', TIMESTAMP '2024-07-23 08:30:00', 0, NULL);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1008, 'Kimironko, Kigali', 'Kicukiro, Kigali', 'moto', TIMESTAMP '2024-07-23 12:10:00', 1, 65);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1010, 'Kabeza, Kigali', 'Remera, Kigali', 'car', TIMESTAMP '2024-07-23 16:40:00', 1, 95);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1001, 'Masaka, Kigali', 'SEZ, Kigali', 'delivery', TIMESTAMP '2024-07-24 09:20:00', 1, 320);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1002, 'Kinyinya, Kigali', 'Kibagabaga, Kigali', 'moto', TIMESTAMP '2024-07-24 11:55:00', 1, 60);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1005, 'Kicukiro, Kigali', 'Remera, Kigali', 'car', TIMESTAMP '2024-07-24 19:25:00', 1, 105);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1008, 'Kinyinya, Kigali', 'Gacuriro, Kigali', 'moto', TIMESTAMP '2024-07-25 07:35:00', 1, 70);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1010, 'RDB, Kigali', 'Kigali Convention Centre', 'car', TIMESTAMP '2024-07-25 12:45:00', 1, 120);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1001, 'Kacyiru, Kigali', 'Kigali Heights', 'moto', TIMESTAMP '2024-07-25 18:10:00', 1, 75);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1002, 'Nyarugenge, Kigali', 'Kigali Serena Hotel', 'car', TIMESTAMP '2024-07-26 08:00:00', 1, 130);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1005, 'Kimisagara, Kigali', 'Nyabugogo', 'moto', TIMESTAMP '2024-07-26 11:30:00', 1, 60);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1008, 'Biryogo, Kigali', 'Nyamirambo, Kigali', 'car', TIMESTAMP '2024-07-26 20:05:00', 1, 100);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1010, 'Kacyiru Police', 'Ministry of Justice', 'moto', TIMESTAMP '2024-07-27 09:25:00', 1, 80);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1001, 'Kigali Heights', 'Kacyiru, Kigali', 'car', TIMESTAMP '2024-07-27 14:40:00', 1, 115);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1002, 'Kimironko, Kigali', 'Kibagabaga, Kigali', 'moto', TIMESTAMP '2024-07-27 18:50:00', 1, 60);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1005, 'Remera, Kigali', 'Amahoro Stadium', 'car', TIMESTAMP '2024-07-28 10:10:00', 0, NULL);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1008, 'Kacyiru, Kigali', 'Gisozi, Kigali', 'moto', TIMESTAMP '2024-07-28 12:25:00', 1, 70);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1010, 'Kagugu, Kigali', 'Gacuriro, Kigali', 'car', TIMESTAMP '2024-07-28 19:30:00', 1, 110);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1001, 'Kimironko Market', 'Kimironko, Kigali', 'delivery', TIMESTAMP '2024-07-29 08:15:00', 1, 240);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1002, 'Gisozi, Kigali', 'Kacyiru, Kigali', 'moto', TIMESTAMP '2024-07-29 13:20:00', 1, 75);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1005, 'Kacyiru, Kigali', 'Kigali Convention Centre', 'car', TIMESTAMP '2024-07-29 17:35:00', 1, 120);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1008, 'Kibagabaga, Kigali', 'Kimironko, Kigali', 'moto', TIMESTAMP '2024-07-30 08:05:00', 1, 65);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1010, 'Nyamirambo, Kigali', 'CBD Kigali', 'car', TIMESTAMP '2024-07-30 10:50:00', 1, 130);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1001, 'Kacyiru, Kigali', 'RDB, Kigali', 'moto', TIMESTAMP '2024-07-30 19:00:00', 1, 80);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1002, 'Remera, Kigali', 'Kacyiru, Kigali', 'car', TIMESTAMP '2024-07-31 07:35:00', 1, 105);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1005, 'Kicukiro, Kigali', 'Kagarama, Kigali', 'moto', TIMESTAMP '2024-07-31 12:45:00', 1, 60);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1008, 'Kabeza, Kigali', 'Kanombe Airport', 'car', TIMESTAMP '2024-07-31 18:20:00', 1, 115);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1010, 'Kacyiru, Kigali', 'Kigali Heights', 'moto', TIMESTAMP '2024-08-01 09:05:00', 1, 70);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1001, 'Kigali Arena', 'Remera, Kigali', 'car', TIMESTAMP '2024-08-01 11:35:00', 1, 95);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1002, 'Masaka, Kigali', 'SEZ, Kigali', 'delivery', TIMESTAMP '2024-08-01 16:55:00', 1, 330);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1005, 'Kimironko, Kigali', 'Kagugu, Kigali', 'moto', TIMESTAMP '2024-08-01 20:10:00', 0, NULL);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1008, 'Kigali Serena Hotel', 'Kacyiru, Kigali', 'car', TIMESTAMP '2024-08-02 08:40:00', 1, 115);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1010, 'Kacyiru, Kigali', 'RDB, Kigali', 'moto', TIMESTAMP '2024-08-02 13:15:00', 1, 85);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1001, 'Nyarugenge, Kigali', 'Kimironko, Kigali', 'car', TIMESTAMP '2024-08-02 17:50:00', 1, 135);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1002, 'Gisozi, Kigali', 'Remera, Kigali', 'moto', TIMESTAMP '2024-08-03 07:20:00', 1, 70);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1005, 'Kigali Business Center', 'CBD Kigali', 'car', TIMESTAMP '2024-08-03 11:45:00', 1, 120);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1008, 'Kibagabaga, Kigali', 'Kimironko Market', 'delivery', TIMESTAMP '2024-08-03 15:05:00', 1, 280);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1010, 'Kacyiru, Kigali', 'Kimironko Bus Park', 'moto', TIMESTAMP '2024-08-04 09:15:00', 1, 75);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1001, 'Nyamirambo, Kigali', 'Kacyiru, Kigali', 'car', TIMESTAMP '2024-08-04 12:35:00', 1, 125);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1002, 'Kimironko, Kigali', 'Kacyiru, Kigali', 'moto', TIMESTAMP '2024-08-04 18:00:00', 1, 70);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1005, 'Remera, Kigali', 'Kigali Arena', 'car', TIMESTAMP '2024-08-05 08:10:00', 1, 110);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1008, 'Kicukiro, Kigali', 'Gikondo, Kigali', 'moto', TIMESTAMP '2024-08-05 13:30:00', 1, 65);
INSERT INTO ride_requests_log VALUES (log_seq.NEXTVAL, 1010, 'SEZ, Kigali', 'Masaka, Kigali', 'delivery', TIMESTAMP '2024-08-05 16:45:00', 1, 340);

COMMIT;