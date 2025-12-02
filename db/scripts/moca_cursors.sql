-- =====================================================
-- CURSOR 1: ACTIVE_RIDES_CURSOR
-- Purpose: Retrieve all active and ongoing rides with
-- associated rider and driver information for real-time
-- tracking and dispatch management
-- =====================================================
CREATE OR REPLACE PACKAGE ride_cursor_pkg AS
    CURSOR active_rides_cursor IS
        SELECT 
            r.ride_id,
            r.rider_id,
            u_rider.full_name AS rider_name,
            u_rider.phone AS rider_phone,
            r.driver_id,
            u_driver.full_name AS driver_name,
            u_driver.phone AS driver_phone,
            d.rating AS driver_rating,
            r.pickup_location,
            r.dropoff_location,
            r.pickup_latitude,
            r.pickup_longitude,
            r.dropoff_latitude,
            r.dropoff_longitude,
            r.status,
            r.requested_at,
            r.started_at,
            r.distance_km,
            r.duration_minutes,
            r.fare_amount
        FROM rides r
        INNER JOIN users u_rider ON r.rider_id = u_rider.user_id
        LEFT JOIN drivers d ON r.driver_id = d.driver_id
        LEFT JOIN users u_driver ON d.user_id = u_driver.user_id
        WHERE r.status IN ('requested', 'accepted', 'active')
        ORDER BY r.requested_at DESC;
    
    PROCEDURE process_active_rides;
END ride_cursor_pkg;
/

CREATE OR REPLACE PACKAGE BODY ride_cursor_pkg AS
    PROCEDURE process_active_rides AS
        v_ride active_rides_cursor%ROWTYPE;
    BEGIN
        OPEN active_rides_cursor;
        LOOP
            FETCH active_rides_cursor INTO v_ride;
            EXIT WHEN active_rides_cursor%NOTFOUND;
            -- Process active ride data
            -- Real-time tracking and dispatch operations
        END LOOP;
        CLOSE active_rides_cursor;
    END process_active_rides;
END ride_cursor_pkg;
/

-- =====================================================
-- CURSOR 2: AVAILABLE_DRIVERS_CURSOR
-- Purpose: Retrieve all available drivers sorted by
-- proximity, rating, and current ride load for optimal
-- ride assignment and dispatch operations
-- =====================================================
CREATE OR REPLACE PACKAGE driver_cursor_pkg AS
    CURSOR available_drivers_cursor IS
        SELECT 
            d.driver_id,
            u.full_name AS driver_name,
            u.phone AS driver_phone,
            d.vehicle_type,
            d.vehicle_plate,
            d.rating,
            d.total_rides,
            d.is_available,
            t.latitude AS current_latitude,
            t.longitude AS current_longitude,
            t.speed AS current_speed,
            t.timestamp AS last_update,
            COUNT(CASE WHEN r.status = 'active' THEN 1 END) AS active_rides_count
        FROM drivers d
        INNER JOIN users u ON d.user_id = u.user_id
        LEFT JOIN tracking t ON d.driver_id = t.driver_id 
            AND t.timestamp = (SELECT MAX(timestamp) FROM tracking 
                              WHERE driver_id = d.driver_id)
        LEFT JOIN rides r ON d.driver_id = r.driver_id 
            AND r.status IN ('active', 'accepted')
        WHERE d.is_available = 1
        GROUP BY d.driver_id, u.full_name, u.phone, d.vehicle_type, 
                 d.vehicle_plate, d.rating, d.total_rides, d.is_available,
                 t.latitude, t.longitude, t.speed, t.timestamp
        ORDER BY d.rating DESC, active_rides_count ASC;
    
    PROCEDURE process_available_drivers;
END driver_cursor_pkg;
/

CREATE OR REPLACE PACKAGE BODY driver_cursor_pkg AS
    PROCEDURE process_available_drivers AS
        v_driver available_drivers_cursor%ROWTYPE;
    BEGIN
        OPEN available_drivers_cursor;
        LOOP
            FETCH available_drivers_cursor INTO v_driver;
            EXIT WHEN available_drivers_cursor%NOTFOUND;
            -- Filter drivers by location proximity
            -- Assign ride to best matching driver
            -- Dispatch notifications
        END LOOP;
        CLOSE available_drivers_cursor;
    END process_available_drivers;
END driver_cursor_pkg;
/

-- =====================================================
-- CURSOR 3: PENDING_PAYMENTS_CURSOR
-- Purpose: Retrieve all rides with completed status
-- but pending or failed payment transactions for
-- financial reconciliation and payment follow-up
-- =====================================================
CREATE OR REPLACE PACKAGE payment_cursor_pkg AS
    CURSOR pending_payments_cursor IS
        SELECT 
            r.ride_id,
            r.rider_id,
            u.full_name AS rider_name,
            u.email AS rider_email,
            u.phone AS rider_phone,
            r.driver_id,
            d_user.full_name AS driver_name,
            r.fare_amount,
            r.payment_method,
            r.completed_at,
            p.payment_id,
            p.amount AS paid_amount,
            p.is_successful,
            p.transaction_ref,
            p.timestamp AS payment_timestamp,
            CASE 
                WHEN p.payment_id IS NULL THEN 'No Payment Record'
                WHEN p.is_successful = 0 THEN 'Failed'
                WHEN r.fare_amount > p.amount THEN 'Partial'
                ELSE 'Complete'
            END AS payment_status
        FROM rides r
        INNER JOIN users u ON r.rider_id = u.user_id
        LEFT JOIN drivers d ON r.driver_id = d.driver_id
        LEFT JOIN users d_user ON d.user_id = d_user.user_id
        LEFT JOIN payments p ON r.ride_id = p.ride_id
        WHERE r.status = 'completed'
        AND (p.payment_id IS NULL OR p.is_successful = 0 
             OR r.fare_amount > p.amount)
        ORDER BY r.completed_at DESC;
    
    PROCEDURE process_pending_payments;
END payment_cursor_pkg;
/

CREATE OR REPLACE PACKAGE BODY payment_cursor_pkg AS
    PROCEDURE process_pending_payments AS
        v_payment pending_payments_cursor%ROWTYPE;
    BEGIN
        OPEN pending_payments_cursor;
        LOOP
            FETCH pending_payments_cursor INTO v_payment;
            EXIT WHEN pending_payments_cursor%NOTFOUND;
            -- Send payment reminders to riders
            -- Retry failed payments
            -- Log discrepancies for accounting
        END LOOP;
        CLOSE pending_payments_cursor;
    END process_pending_payments;
END payment_cursor_pkg;
/

-- =====================================================
-- CURSOR 4: DRIVER_PERFORMANCE_CURSOR
-- Purpose: Retrieve comprehensive driver performance
-- metrics including ratings, ride statistics, earnings,
-- and activity history for driver analytics and ranking
-- =====================================================
CREATE OR REPLACE PACKAGE analytics_cursor_pkg AS
    CURSOR driver_performance_cursor IS
        SELECT 
            d.driver_id,
            u.full_name AS driver_name,
            d.vehicle_type,
            d.rating,
            d.total_rides,
            COUNT(r.ride_id) AS completed_rides_period,
            ROUND(AVG(r.distance_km), 2) AS avg_distance_km,
            ROUND(AVG(r.duration_minutes), 2) AS avg_duration_minutes,
            ROUND(SUM(r.fare_amount), 2) AS total_earnings,
            ROUND(SUM(r.fare_amount) / COUNT(r.ride_id), 2) AS avg_fare,
            COUNT(DISTINCT dr.rating_id) AS total_ratings,
            ROUND(AVG(dr.rating), 2) AS avg_rider_rating,
            MIN(r.completed_at) AS first_ride_date,
            MAX(r.completed_at) AS last_ride_date
        FROM drivers d
        INNER JOIN users u ON d.user_id = u.user_id
        LEFT JOIN rides r ON d.driver_id = r.driver_id 
            AND r.status = 'completed'
            AND r.completed_at >= TRUNC(SYSDATE) - 30
        LEFT JOIN driver_ratings dr ON d.driver_id = dr.driver_id
        GROUP BY d.driver_id, u.full_name, d.vehicle_type, d.rating, d.total_rides
        ORDER BY d.rating DESC, total_earnings DESC;
    
    PROCEDURE generate_performance_report;
END analytics_cursor_pkg;
/

CREATE OR REPLACE PACKAGE BODY analytics_cursor_pkg AS
    PROCEDURE generate_performance_report AS
        v_performance driver_performance_cursor%ROWTYPE;
    BEGIN
        OPEN driver_performance_cursor;
        LOOP
            FETCH driver_performance_cursor INTO v_performance;
            EXIT WHEN driver_performance_cursor%NOTFOUND;
            -- Generate driver performance reports
            -- Identify top and underperforming drivers
            -- Calculate incentives and bonuses
        END LOOP;
        CLOSE driver_performance_cursor;
    END generate_performance_report;
END analytics_cursor_pkg;
/

-- =====================================================
-- CURSOR 5: LOCATION_HISTORY_CURSOR
-- Purpose: Retrieve historical location tracking data
-- for a specific ride or driver session, used for
-- analytics, safety audits, and route verification
-- =====================================================
CREATE OR REPLACE PACKAGE tracking_cursor_pkg AS
    TYPE location_record IS RECORD (
        history_id tracking_history.history_id%TYPE,
        driver_id tracking_history.driver_id%TYPE,
        vehicle_type drivers.vehicle_type%TYPE,
        vehicle_plate drivers.vehicle_plate%TYPE,
        driver_name users.full_name%TYPE,
        ride_id tracking_history.ride_id%TYPE,
        pickup_location rides.pickup_location%TYPE,
        dropoff_location rides.dropoff_location%TYPE,
        latitude tracking_history.latitude%TYPE,
        longitude tracking_history.longitude%TYPE,
        speed tracking_history.speed%TYPE,
        heading tracking_history.heading%TYPE,
        logged_at tracking_history.logged_at%TYPE
    );
    
    CURSOR location_history_cursor(p_ride_id NUMBER) IS
        SELECT 
            th.history_id,
            th.driver_id,
            d.vehicle_type,
            d.vehicle_plate,
            u.full_name AS driver_name,
            th.ride_id,
            r.pickup_location,
            r.dropoff_location,
            th.latitude,
            th.longitude,
            th.speed,
            th.heading,
            th.logged_at
        FROM tracking_history th
        INNER JOIN drivers d ON th.driver_id = d.driver_id
        INNER JOIN users u ON d.user_id = u.user_id
        INNER JOIN rides r ON th.ride_id = r.ride_id
        WHERE th.ride_id = p_ride_id
        ORDER BY th.logged_at ASC;
    
    PROCEDURE verify_route_history(p_ride_id NUMBER);
END tracking_cursor_pkg;
/

CREATE OR REPLACE PACKAGE BODY tracking_cursor_pkg AS
    PROCEDURE verify_route_history(p_ride_id NUMBER) AS
        v_location location_record;
        v_total_distance NUMBER := 0;
    BEGIN
        OPEN location_history_cursor(p_ride_id);
        LOOP
            FETCH location_history_cursor INTO v_location;
            EXIT WHEN location_history_cursor%NOTFOUND;
            -- Reconstruct ride route
            -- Calculate total distance traveled
            -- Verify deviation from intended route
            -- Generate safety audit reports
        END LOOP;
        CLOSE location_history_cursor;
    END verify_route_history;
END tracking_cursor_pkg;
/

-- =====================================================
-- END OF CURSORS DEFINITION
-- =====================================================
-- Summary of Cursors:
-- 1. ACTIVE_RIDES_CURSOR: Real-time ride tracking
--    Location: ride_cursor_pkg
--    Purpose: Track ongoing rides with full participant info
--
-- 2. AVAILABLE_DRIVERS_CURSOR: Driver dispatch optimization
--    Location: driver_cursor_pkg
--    Purpose: Find best available drivers for ride assignment
--
-- 3. PENDING_PAYMENTS_CURSOR: Payment reconciliation
--    Location: payment_cursor_pkg
--    Purpose: Identify and process incomplete payments
--
-- 4. DRIVER_PERFORMANCE_CURSOR: Analytics and reporting
--    Location: analytics_cursor_pkg
--    Purpose: Generate performance metrics and rankings
--
-- 5. LOCATION_HISTORY_CURSOR: Route verification & audit
--    Location: tracking_cursor_pkg
--    Purpose: Audit driver routes and track history
-- =====================================================
 