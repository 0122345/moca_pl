-- =====================================================
-- MOCA Mobility System - PL/SQL Database Schema
-- Course: Database Development with PL/SQL (INSY 8311)
-- Student: 27438 Ntwari Ashimwe Fiacre
-- Date: 17 November 2025
-- =====================================================

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
    status VARCHAR2(20) CHECK (status IN ('requested', 'accepted', 'active', 'completed', 'canceled', 'paid')) DEFAULT 'requested',
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
    comment VARCHAR2(500),
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
CREATE INDEX idx_users_email ON users(email);
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
INSERT INTO rides VALUES (rides_seq.NEXTVAL, 1001, 2001, 'KN 5 Ave, Kigali', 'KG 11 Ave, Kigali', -1.9441, 30.0619, -1.9506, 30.0944, 3500.00, 'momo', 'completed', TIMESTAMP '2024-06-15 08:30:00', TIMESTAMP '2024-06-15 08:32:00', TIMESTAMP '2024-06-15 08:47:00', 5.2, 15);
INSERT INTO rides VALUES (rides_seq.NEXTVAL, 1002, 2002, 'Nyarugenge, Kigali', 'Kimironko, Kigali', -1.9500, 30.0588, -1.9536, 30.1044, 2500.00, 'card', 'completed', TIMESTAMP '2024-06-18 14:20:00', TIMESTAMP '2024-06-18 14:21:00', TIMESTAMP '2024-06-18 14:32:00', 4.1, 11);
INSERT INTO rides VALUES (rides_seq.NEXTVAL, 1005, 2003, 'Remera, Kigali', 'Airport, Kigali', -1.9578, 30.1044, -1.9686, 30.1394, 4500.00, 'nfc', 'completed', TIMESTAMP '2024-07-02 06:15:00', TIMESTAMP '2024-07-02 06:16:00', TIMESTAMP '2024-07-02 06:35:00', 7.8, 19);
INSERT INTO rides VALUES (rides_seq.NEXTVAL, 1001, 2004, 'Kimihurura, Kigali', 'Downtown Kigali', -1.9447, 30.0958, -1.9536, 30.0588, 2000.00, 'momo', 'completed', TIMESTAMP '2024-07-10 10:45:00', TIMESTAMP '2024-07-10 10:46:00', TIMESTAMP '2024-07-10 10:56:00', 3.2, 10);
INSERT INTO rides VALUES (rides_seq.NEXTVAL, 1008, 2001, 'Gikondo, Kigali', 'Kacyiru, Kigali', -1.9833, 30.0747, -1.9447, 30.0958, 4000.00, 'qr', 'completed', TIMESTAMP '2024-07-22 16:30:00', TIMESTAMP '2024-07-22 16:32:00', TIMESTAMP '2024-07-22 16:52:00', 6.5, 20);
INSERT INTO rides VALUES (rides_seq.NEXTVAL, 1002, 2002, 'Nyamirambo, Kigali', 'CBD Kigali', -1.9719, 30.0472, -1.9536, 30.0588, 1800.00, 'card', 'completed', TIMESTAMP '2024-08-05 12:00:00', TIMESTAMP '2024-08-05 12:01:00', TIMESTAMP '2024-08-05 12:11:00', 2.8, 10);
INSERT INTO rides VALUES (rides_seq.NEXTVAL, 1005, 2003, 'Kicukiro, Kigali', 'Rebero, Kigali', -1.9833, 30.1044, -1.9578, 30.0906, 3200.00, 'momo', 'completed', TIMESTAMP '2024-08-14 18:20:00', TIMESTAMP '2024-08-14 18:22:00', TIMESTAMP '2024-08-14 18:38:00', 4.9, 16);
INSERT INTO rides VALUES (rides_seq.NEXTVAL, 1010, 2004, 'Gisozi, Kigali', 'Muhima, Kigali', -1.9283, 30.0833, -1.9578, 30.0644, 2800.00, 'nfc', 'completed', TIMESTAMP '2024-09-02 09:15:00', TIMESTAMP '2024-09-02 09:16:00', TIMESTAMP '2024-09-02 09:28:00', 3.8, 12);
INSERT INTO rides VALUES (rides_seq.NEXTVAL, 1001, 2001, 'Kagugu, Kigali', 'Kimironko Market', -1.9314, 30.1181, -1.9536, 30.1044, 2200.00, 'paypal', 'completed', TIMESTAMP '2024-09-18 15:45:00', TIMESTAMP '2024-09-18 15:46:00', TIMESTAMP '2024-09-18 15:56:00', 3.1, 10);
INSERT INTO rides VALUES (rides_seq.NEXTVAL, 1008, 2005, 'Kanombe, Kigali', 'Nyabugogo', -1.9686, 30.1394, -1.9419, 30.0594, 5500.00, 'momo', 'completed', TIMESTAMP '2024-10-01 07:30:00', TIMESTAMP '2024-10-01 07:32:00', TIMESTAMP '2024-10-01 07:58:00', 9.2, 26);
INSERT INTO rides VALUES (rides_seq.NEXTVAL, 1002, 2002, 'Kacyiru, Kigali', 'Gikondo Industrial', -1.9447, 30.0958, -1.9833, 30.0747, 3800.00, 'card', 'completed', TIMESTAMP '2024-10-12 11:20:00', TIMESTAMP '2024-10-12 11:21:00', TIMESTAMP '2024-10-12 11:40:00', 5.8, 19);
INSERT INTO rides VALUES (rides_seq.NEXTVAL, 1005, 2003, 'CBD Kigali', 'Rebero Hill', -1.9536, 30.0588, -1.9578, 30.0906, 3500.00, 'qr', 'completed', TIMESTAMP '2024-10-25 13:00:00', TIMESTAMP '2024-10-25 13:02:00', TIMESTAMP '2024-10-25 13:20:00', 5.1, 18);
INSERT INTO rides VALUES (rides_seq.NEXTVAL, 1010, 2004, 'Nyarutarama, Kigali', 'Kimihurura', -1.9369, 30.1133, -1.9447, 30.0958, 2400.00, 'momo', 'completed', TIMESTAMP '2024-11-03 08:45:00', TIMESTAMP '2024-11-03 08:46:00', TIMESTAMP '2024-11-03 08:58:00', 3.5, 12);
INSERT INTO rides VALUES (rides_seq.NEXTVAL, 1001, 2001, 'Airport Road', 'City Center', -1.9686, 30.1394, -1.9536, 30.0588, 5000.00, 'nfc', 'completed', TIMESTAMP '2024-11-10 17:30:00', TIMESTAMP '2024-11-10 17:32:00', TIMESTAMP '2024-11-10 17:56:00', 8.1, 24);
INSERT INTO rides VALUES (rides_seq.NEXTVAL, 1008, 2002, 'Kimironko, Kigali', 'Nyamirambo', -1.9536, 30.1044, -1.9719, 30.0472, 3000.00, 'card', 'active', TIMESTAMP '2024-11-17 10:15:00', TIMESTAMP '2024-11-17 10:16:00', NULL, NULL, NULL);
INSERT INTO rides VALUES (rides_seq.NEXTVAL, 1002, 2003, 'Remera, Kigali', 'Kicukiro Center', -1.9578, 30.1044, -1.9833, 30.1044, 2600.00, 'momo', 'requested', TIMESTAMP '2024-11-17 10:25:00', NULL, NULL, NULL, NULL);

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

COMMIT;