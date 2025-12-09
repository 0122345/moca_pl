# MOCA Auditing and Monitoring Queries (Oracle)

Purpose
- Provide ready-to-run Oracle SQL to audit data quality, security posture proxies, operational integrity, payments reconciliation, and performance for the MOCA schema defined in db/scripts/db.schema.sql.
- These scripts are non-destructive. Run in read-only sessions for monitoring and BI validation.

Schema reference
- users(user_id, full_name, email, phone, role, password_hash, jwt_token, created_at)
- drivers(driver_id, user_id, license_no, vehicle_type, vehicle_plate, rating, is_available, total_rides)
- rides(ride_id, rider_id, driver_id, pickup_location, dropoff_location, pickup_latitude, pickup_longitude, dropoff_latitude, dropoff_longitude, fare_amount, payment_method, status, updated_at, requested_at, started_at, completed_at, distance_km, duration_minutes)
- payments(payment_id, ride_id, amount, method, transaction_ref, is_successful, timestamp, payment_details)
- messages(message_id, sender_id, receiver_id, ride_id, message_body, is_read, sent_at)
- tracking(tracking_id, driver_id, ride_id, latitude, longitude, speed, heading, timestamp)
- tracking_history(history_id, tracking_id, driver_id, ride_id, latitude, longitude, speed, heading, logged_at)
- driver_ratings(rating_id, ride_id, driver_id, rider_id, rating, rating_comment, rated_at)
- ride_requests_log(log_id, rider_id, pickup_location, dropoff_location, vehicle_type, requested_at, was_matched, time_to_match_seconds)

Conventions
- SYSDATE used for date boundaries; adjust to your TZ and reporting cutoffs.
- Flags: is_successful, is_read, is_available are 0/1 numeric.

1) Inventory and freshness
-- Row counts per table
SELECT table_name, num_rows
FROM user_tables
ORDER BY table_name;

-- Approx table sizes (in MB)
SELECT segment_name AS table_name,
       ROUND(SUM(bytes)/1024/1024,2) AS size_mb
FROM user_segments
WHERE segment_type='TABLE'
GROUP BY segment_name
ORDER BY size_mb DESC;

-- Recent activity snapshot (last 24h)
SELECT 'users' obj, COUNT(*) cnt FROM users WHERE created_at >= SYSDATE-1
UNION ALL
SELECT 'rides', COUNT(*) FROM rides WHERE requested_at >= SYSDATE-1
UNION ALL
SELECT 'payments', COUNT(*) FROM payments WHERE timestamp >= SYSDATE-1
UNION ALL
SELECT 'messages', COUNT(*) FROM messages WHERE sent_at >= SYSDATE-1
UNION ALL
SELECT 'tracking', COUNT(*) FROM tracking WHERE timestamp >= SYSDATE-1;

2) Data quality and referential integrity
-- Orphan checks
-- drivers without users
SELECT d.driver_id
FROM drivers d
LEFT JOIN users u ON u.user_id = d.user_id
WHERE u.user_id IS NULL;

-- rides with missing rider or driver references
SELECT r.ride_id, r.rider_id, r.driver_id
FROM rides r
LEFT JOIN users u ON u.user_id = r.rider_id
LEFT JOIN drivers d ON d.driver_id = r.driver_id
WHERE (r.rider_id IS NOT NULL AND u.user_id IS NULL)
   OR (r.driver_id IS NOT NULL AND d.driver_id IS NULL);

-- payments referencing non-existing ride
SELECT p.payment_id, p.ride_id
FROM payments p
LEFT JOIN rides r ON r.ride_id = p.ride_id
WHERE r.ride_id IS NULL;

-- messages with sender/receiver missing
SELECT m.message_id, m.sender_id, m.receiver_id, m.ride_id
FROM messages m
LEFT JOIN users su ON su.user_id = m.sender_id
LEFT JOIN users ru ON ru.user_id = m.receiver_id
LEFT JOIN rides r ON r.ride_id = m.ride_id
WHERE (su.user_id IS NULL OR ru.user_id IS NULL)
   OR (m.ride_id IS NOT NULL AND r.ride_id IS NULL);

-- tracking referencing missing driver/ride
SELECT t.tracking_id, t.driver_id, t.ride_id
FROM tracking t
LEFT JOIN drivers d ON d.driver_id = t.driver_id
LEFT JOIN rides r ON r.ride_id = t.ride_id
WHERE (t.driver_id IS NOT NULL AND d.driver_id IS NULL)
   OR (t.ride_id IS NOT NULL AND r.ride_id IS NULL);

-- ENUM domain validations
-- Invalid user role
SELECT * FROM users WHERE role NOT IN ('rider','driver','admin');

-- Invalid vehicle_type
SELECT * FROM drivers WHERE vehicle_type NOT IN ('car','moto','delivery');

-- Invalid payment method in rides/payments
SELECT ride_id, payment_method FROM rides WHERE payment_method IS NOT NULL AND payment_method NOT IN ('nfc','momo','paypal','card','qr');
SELECT payment_id, method FROM payments WHERE method NOT IN ('nfc','momo','paypal','card','qr');

-- Invalid ride status
SELECT ride_id, status FROM rides WHERE status NOT IN ('requested','accepted','active','completed','canceled','paid');

-- Temporal anomalies
SELECT ride_id, requested_at, started_at, completed_at
FROM rides
WHERE (started_at IS NOT NULL AND requested_at IS NOT NULL AND started_at < requested_at)
   OR (completed_at IS NOT NULL AND started_at IS NOT NULL AND completed_at < started_at);

-- Geographic bounds sanity checks (lat [-90..90], lon [-180..180])
SELECT ride_id, pickup_latitude, pickup_longitude, dropoff_latitude, dropoff_longitude
FROM rides
WHERE (pickup_latitude  IS NOT NULL AND (pickup_latitude  < -90 OR pickup_latitude  > 90))
   OR (dropoff_latitude IS NOT NULL AND (dropoff_latitude < -90 OR dropoff_latitude > 90))
   OR (pickup_longitude  IS NOT NULL AND (pickup_longitude  < -180 OR pickup_longitude  > 180))
   OR (dropoff_longitude IS NOT NULL AND (dropoff_longitude < -180 OR dropoff_longitude > 180));

-- Driver rating outliers
SELECT driver_id, rating
FROM drivers
WHERE rating < 0 OR rating > 5;

-- Driver_ratings value checks (1..5)
SELECT * FROM driver_ratings WHERE rating NOT BETWEEN 1 AND 5;

3) Payments reconciliation and anomalies
-- Rides completed with no successful payment (candidate debts)
SELECT r.ride_id, r.fare_amount, r.payment_method, r.status
FROM rides r
LEFT JOIN (
  SELECT ride_id, MAX(is_successful) AS has_success
  FROM payments
  GROUP BY ride_id
) p ON p.ride_id = r.ride_id
WHERE r.status IN ('completed','paid')
  AND NVL(p.has_success,0) = 0;

-- Payments with no associated ride record
SELECT p.*
FROM payments p
LEFT JOIN rides r ON r.ride_id = p.ride_id
WHERE r.ride_id IS NULL;

-- Duplicate transaction_ref detection
SELECT transaction_ref, COUNT(*) dup_count
FROM payments
WHERE transaction_ref IS NOT NULL
GROUP BY transaction_ref
HAVING COUNT(*) > 1;

-- Negative or zero amounts
SELECT * FROM payments WHERE amount <= 0;

-- Amount mismatch tolerance (e.g., > 2% difference vs fare_amount)
SELECT r.ride_id, r.fare_amount, SUM(p.amount) paid_amount
FROM rides r
JOIN payments p ON p.ride_id = r.ride_id AND p.is_successful = 1
GROUP BY r.ride_id, r.fare_amount
HAVING ABS(NVL(SUM(p.amount),0) - NVL(r.fare_amount,0)) > (NVL(r.fare_amount,0) * 0.02);

-- Payment channel mix and success rate (last 30 days)
SELECT method,
       COUNT(*) total_attempts,
       SUM(CASE WHEN is_successful = 1 THEN 1 ELSE 0 END) success_count,
       ROUND(100 * AVG(CASE WHEN is_successful = 1 THEN 1 ELSE 0 END),2) success_rate_pct
FROM payments
WHERE timestamp >= SYSDATE - 30
GROUP BY method
ORDER BY success_count DESC;

4) Operational integrity and funnel
-- Ride status funnel (last 7 days by day)
SELECT TRUNC(requested_at) as day,
       SUM(CASE WHEN status = 'requested' THEN 1 ELSE 0 END) requested,
       SUM(CASE WHEN status = 'accepted'  THEN 1 ELSE 0 END) accepted,
       SUM(CASE WHEN status = 'active'    THEN 1 ELSE 0 END) active,
       SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) completed,
       SUM(CASE WHEN status = 'canceled'  THEN 1 ELSE 0 END) canceled,
       SUM(CASE WHEN status = 'paid'      THEN 1 ELSE 0 END) paid
FROM rides
WHERE requested_at >= TRUNC(SYSDATE) - 7
GROUP BY TRUNC(requested_at)
ORDER BY day;

-- Stuck rides (requested or active for > 2 hours without completion)
SELECT r.*
FROM rides r
WHERE (
  r.status IN ('requested','accepted','active')
  AND NVL(r.updated_at, r.requested_at) < SYSDATE - (2/24)
);

-- Messages density per ride (potentially high comms = pickup issues)
SELECT r.ride_id,
       COUNT(m.message_id) msg_count
FROM rides r
LEFT JOIN messages m ON m.ride_id = r.ride_id
GROUP BY r.ride_id
ORDER BY msg_count DESC FETCH FIRST 20 ROWS ONLY;

-- Tracking recency by driver (last point per driver)
SELECT t.driver_id,
       MAX(t.timestamp) last_seen,
       ROUND(24*(SYSDATE - MAX(t.timestamp)),2) hours_since_seen
FROM tracking t
GROUP BY t.driver_id
ORDER BY last_seen DESC;

-- Speed outliers (> 120 km/h suggests GPS noise)
SELECT * FROM tracking WHERE speed > 120;

-- Estimate average ETA proxy: requested->started duration (mins)
SELECT ROUND(AVG((CAST(started_at AS DATE) - CAST(requested_at AS DATE))*24*60),2) avg_minutes_to_start
FROM rides
WHERE started_at IS NOT NULL AND requested_at IS NOT NULL
  AND requested_at >= SYSDATE - 30;

5) Growth and retention highlights
-- Daily new users, daily rides, daily GMV (last 30 days)
WITH rides_day AS (
  SELECT TRUNC(requested_at) day, COUNT(*) rides, NVL(SUM(fare_amount),0) gmv
  FROM rides
  WHERE requested_at >= TRUNC(SYSDATE) - 30
  GROUP BY TRUNC(requested_at)
), users_day AS (
  SELECT TRUNC(created_at) day, COUNT(*) new_users
  FROM users
  WHERE created_at >= TRUNC(SYSDATE) - 30
  GROUP BY TRUNC(created_at)
)
SELECT d.day,
       NVL(u.new_users,0) new_users,
       NVL(r.rides,0) rides,
       NVL(r.gmv,0) gmv
FROM (
  SELECT TRUNC(SYSDATE) - LEVEL + 1 AS day FROM dual CONNECT BY LEVEL <= 30
) d
LEFT JOIN users_day u ON u.day = d.day
LEFT JOIN rides_day r ON r.day = d.day
ORDER BY d.day;

-- ARPU proxy (GMV / active riders per day)
WITH riders_per_day AS (
  SELECT TRUNC(requested_at) day, COUNT(DISTINCT rider_id) riders
  FROM rides
  WHERE requested_at >= TRUNC(SYSDATE) - 30
  GROUP BY TRUNC(requested_at)
), gmv_per_day AS (
  SELECT TRUNC(requested_at) day, SUM(NVL(fare_amount,0)) gmv
  FROM rides
  WHERE requested_at >= TRUNC(SYSDATE) - 30
  GROUP BY TRUNC(requested_at)
)
SELECT g.day,
       g.gmv,
       r.riders,
       CASE WHEN r.riders=0 THEN NULL ELSE ROUND(g.gmv / r.riders,2) END AS arpu
FROM gmv_per_day g
LEFT JOIN riders_per_day r ON r.day = g.day
ORDER BY g.day;

6) Indexing and performance aides
-- Check for missing common FK indexes (may already exist via script)
-- rides(rider_id), rides(driver_id), payments(ride_id), messages(sender_id), messages(receiver_id), tracking(driver_id), tracking(ride_id)
SELECT 'rides(rider_id)'   AS fk, COUNT(*) idx
FROM user_indexes WHERE table_name='RIDES' AND index_name IN (SELECT index_name FROM user_ind_columns WHERE table_name='RIDES' AND column_name='RIDER_ID')
UNION ALL
SELECT 'rides(driver_id)', COUNT(*) FROM user_indexes WHERE table_name='RIDES' AND index_name IN (SELECT index_name FROM user_ind_columns WHERE table_name='RIDES' AND column_name='DRIVER_ID')
UNION ALL
SELECT 'payments(ride_id)', COUNT(*) FROM user_indexes WHERE table_name='PAYMENTS' AND index_name IN (SELECT index_name FROM user_ind_columns WHERE table_name='PAYMENTS' AND column_name='RIDE_ID')
UNION ALL
SELECT 'messages(sender_id)', COUNT(*) FROM user_indexes WHERE table_name='MESSAGES' AND index_name IN (SELECT index_name FROM user_ind_columns WHERE table_name='MESSAGES' AND column_name='SENDER_ID')
UNION ALL
SELECT 'messages(receiver_id)', COUNT(*) FROM user_indexes WHERE table_name='MESSAGES' AND index_name IN (SELECT index_name FROM user_ind_columns WHERE table_name='MESSAGES' AND column_name='RECEIVER_ID')
UNION ALL
SELECT 'tracking(driver_id)', COUNT(*) FROM user_indexes WHERE table_name='TRACKING' AND index_name IN (SELECT index_name FROM user_ind_columns WHERE table_name='TRACKING' AND column_name='DRIVER_ID')
UNION ALL
SELECT 'tracking(ride_id)', COUNT(*) FROM user_indexes WHERE table_name='TRACKING' AND index_name IN (SELECT index_name FROM user_ind_columns WHERE table_name='TRACKING' AND column_name='RIDE_ID');

-- Heavy tables by last analyzed stats
SELECT table_name, num_rows, last_analyzed
FROM user_tables
ORDER BY NVL(last_analyzed, TO_DATE('1970-01-01','YYYY-MM-DD')) DESC;

-- Suggest gathering stats (execute with privileges; here just the command reference)
-- EXEC DBMS_STATS.GATHER_SCHEMA_STATS(ownname => USER, estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE, cascade => TRUE);

7) Security and access proxies
-- Daily JWT presence by user role (proxy for token usage if populated externally)
SELECT role,
       COUNT(*) users_total,
       SUM(CASE WHEN jwt_token IS NOT NULL THEN 1 ELSE 0 END) with_jwt,
       ROUND(100 * AVG(CASE WHEN jwt_token IS NOT NULL THEN 1 ELSE 0 END),2) pct_with_jwt
FROM users
GROUP BY role;

-- Potential duplicate accounts by phone/email (should be unique by schema)
SELECT 'email' AS field, email AS value, COUNT(*) cnt
FROM users
GROUP BY email
HAVING COUNT(*) > 1
UNION ALL
SELECT 'phone', phone, COUNT(*)
FROM users
GROUP BY phone
HAVING COUNT(*) > 1;

8) Ride-request funnel from log table
-- Match rate and time-to-match distribution (last 30 days)
SELECT TRUNC(requested_at) day,
       COUNT(*) total_requests,
       SUM(CASE WHEN was_matched=1 THEN 1 ELSE 0 END) matched,
       ROUND(100 * AVG(CASE WHEN was_matched=1 THEN 1 ELSE 0 END),2) match_rate_pct,
       ROUND(AVG(CASE WHEN was_matched=1 THEN time_to_match_seconds END),2) avg_secs_to_match
FROM ride_requests_log
WHERE requested_at >= TRUNC(SYSDATE) - 30
GROUP BY TRUNC(requested_at)
ORDER BY day;

-- Invalid vehicle_type markers in log (allowing 'n/a' as data source noise)
SELECT *
FROM ride_requests_log
WHERE vehicle_type IS NOT NULL
  AND vehicle_type NOT IN ('car','moto','delivery','n/a');

9) Scheduling and operations
-- Recommended approach: wrap critical checks as views or stored procedures and schedule with DBMS_SCHEDULER.
-- Example job definition (requires privileges):
-- BEGIN
--   DBMS_SCHEDULER.CREATE_JOB(
--     job_name        => 'JOB_AUDIT_DAILY',
--     job_type        => 'PLSQL_BLOCK',
--     job_action      => q'[ BEGIN NULL; END; ]',
--     start_date      => SYSTIMESTAMP,
--     repeat_interval => 'FREQ=DAILY;BYHOUR=06;BYMINUTE=00;BYSECOND=00',
--     enabled         => TRUE,
--     comments        => 'Daily MOCA audit job placeholder');
-- END;
-- /

Notes
- Adjust time windows and thresholds per SLA.
- If additional audit sources exist (e.g., auth logs), integrate them via external tables or streams.
- Keep this file under version control alongside schema migrations to evolve checks with the model.
