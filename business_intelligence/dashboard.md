# MOCA BI Dashboard Specification

Purpose
- Define KPIs, dimensions, and facts for executive, operations, finance, and safety dashboards.
- Provide SQL views and example queries tailored to the MOCA Oracle schema (db/scripts/db.schema.sql).

Primary KPIs (executive board)
- Rides Today: COUNT(rides where TRUNC(requested_at)=TRUNC(SYSDATE))
- Active Drivers Today: COUNT(DISTINCT driver_id with tracking timestamp today OR rides today)
- GMV Today: SUM(fare_amount for rides requested today)
- Payment Success Rate Today: successful payments / total payment attempts today
- Avg Time-to-Start (ETA proxy) 7d: avg(minutes between requested_at and started_at)
- Completion Rate Today: completed rides / requested rides today

Operations KPIs
- Ride Funnel by Day: requested, accepted, active, completed, canceled, paid
- Stuck Rides > 2h not completed
- Rider/Driver Activity by Hour heatmaps
- Messages per Ride (communication intensity)

Finance KPIs
- GMV trend by day, last 30 days
- Payment Method Mix and Success Rate
- Reconciliation: completed rides without successful payments

Safety/Quality KPIs
- Driver Rating Distribution and 7d average
- Speed Outliers (>120 km/h) and last-seen recency per driver
- Average Distance and Duration distribution

Star schema (analytics views)
- Dimensions
  - dim_date(date_key, date, day, month, year, dow, week, is_weekend)
  - dim_user(user_id, full_name, role)
  - dim_driver(driver_id, user_id, vehicle_type, vehicle_plate)
  - dim_payment_method(method_code, method_name)
  - dim_ride_status(status_code)
- Facts
  - fact_rides(ride_id, rider_id, driver_id, payment_method, status, requested_at, started_at, completed_at, fare_amount, distance_km, duration_minutes)
  - fact_payments(payment_id, ride_id, method, amount, is_successful, timestamp)
  - fact_tracking_daily(driver_id, day, points, avg_speed, max_speed, last_seen)
  - fact_messages_daily(ride_id, day, msgs)

SQL view definitions (create as needed)
-- dim_date (generate for +/- 2 years)
CREATE OR REPLACE VIEW dim_date AS
SELECT TRUNC(SYSDATE) - LEVEL + 1 AS date_key,
       TRUNC(SYSDATE) - LEVEL + 1 AS "date",
       TO_CHAR(TRUNC(SYSDATE) - LEVEL + 1, 'DD') AS day,
       TO_CHAR(TRUNC(SYSDATE) - LEVEL + 1, 'MM') AS month,
       TO_CHAR(TRUNC(SYSDATE) - LEVEL + 1, 'YYYY') AS year,
       TO_CHAR(TRUNC(SYSDATE) - LEVEL + 1, 'DY') AS dow,
       TO_CHAR(TRUNC(SYSDATE) - LEVEL + 1, 'IW') AS week,
       CASE WHEN TO_CHAR(TRUNC(SYSDATE) - LEVEL + 1,'DY') IN ('SAT','SUN') THEN 1 ELSE 0 END AS is_weekend
FROM dual CONNECT BY LEVEL <= 730;

-- dim_user
CREATE OR REPLACE VIEW dim_user AS
SELECT user_id, full_name, role
FROM users;

-- dim_driver
CREATE OR REPLACE VIEW dim_driver AS
SELECT d.driver_id, d.user_id, d.vehicle_type, d.vehicle_plate
FROM drivers d;

-- dim_payment_method
CREATE OR REPLACE VIEW dim_payment_method AS
SELECT 'nfc' AS method_code, 'NFC' AS method_name FROM dual UNION ALL
SELECT 'momo','Mobile Money' FROM dual UNION ALL
SELECT 'paypal','PayPal' FROM dual UNION ALL
SELECT 'card','Card' FROM dual UNION ALL
SELECT 'qr','QR' FROM dual;

-- dim_ride_status
CREATE OR REPLACE VIEW dim_ride_status AS
SELECT 'requested' AS status_code FROM dual UNION ALL
SELECT 'accepted' FROM dual UNION ALL
SELECT 'active' FROM dual UNION ALL
SELECT 'completed' FROM dual UNION ALL
SELECT 'canceled' FROM dual UNION ALL
SELECT 'paid' FROM dual;

-- fact_rides
CREATE OR REPLACE VIEW fact_rides AS
SELECT ride_id, rider_id, driver_id, payment_method, status,
       requested_at, started_at, completed_at,
       fare_amount, distance_km, duration_minutes
FROM rides;

-- fact_payments
CREATE OR REPLACE VIEW fact_payments AS
SELECT payment_id, ride_id, method, amount, is_successful, timestamp
FROM payments;

-- fact_tracking_daily
CREATE OR REPLACE VIEW fact_tracking_daily AS
SELECT driver_id,
       TRUNC(timestamp) AS day,
       COUNT(*) AS points,
       ROUND(AVG(speed),2) AS avg_speed,
       MAX(speed) AS max_speed,
       MAX(timestamp) AS last_seen
FROM tracking
GROUP BY driver_id, TRUNC(timestamp);

-- fact_messages_daily
CREATE OR REPLACE VIEW fact_messages_daily AS
SELECT ride_id,
       TRUNC(sent_at) AS day,
       COUNT(*) AS msgs
FROM messages
GROUP BY ride_id, TRUNC(sent_at);

Example queries for charts
-- Executive: Today overview
SELECT 'rides_today' AS metric, COUNT(*) AS value FROM rides WHERE TRUNC(requested_at)=TRUNC(SYSDATE)
UNION ALL
SELECT 'active_drivers_today', COUNT(DISTINCT driver_id)
FROM (
  SELECT driver_id FROM rides WHERE TRUNC(requested_at)=TRUNC(SYSDATE) AND driver_id IS NOT NULL
  UNION
  SELECT driver_id FROM tracking WHERE TRUNC(timestamp)=TRUNC(SYSDATE)
)
UNION ALL
SELECT 'gmv_today', NVL(SUM(fare_amount),0) FROM rides WHERE TRUNC(requested_at)=TRUNC(SYSDATE);

-- Payment success rate today
SELECT CASE WHEN COUNT(*)=0 THEN NULL ELSE ROUND(100*AVG(CASE WHEN is_successful=1 THEN 1 ELSE 0 END),2) END AS success_rate_pct
FROM payments
WHERE TRUNC(timestamp)=TRUNC(SYSDATE);

-- GMV trend (last 30 days)
SELECT TRUNC(requested_at) AS day, SUM(NVL(fare_amount,0)) gmv
FROM rides
WHERE requested_at >= TRUNC(SYSDATE) - 30
GROUP BY TRUNC(requested_at)
ORDER BY day;

-- Payment method mix (last 7 days)
SELECT method, COUNT(*) attempts,
       SUM(CASE WHEN is_successful=1 THEN 1 ELSE 0 END) successes,
       ROUND(100*AVG(CASE WHEN is_successful=1 THEN 1 ELSE 0 END),2) success_rate_pct
FROM fact_payments
WHERE timestamp >= SYSDATE - 7
GROUP BY method
ORDER BY successes DESC;

-- Ride funnel last 7 days
SELECT TRUNC(requested_at) day,
       SUM(CASE WHEN status='requested' THEN 1 ELSE 0 END) requested,
       SUM(CASE WHEN status='accepted'  THEN 1 ELSE 0 END) accepted,
       SUM(CASE WHEN status='active'    THEN 1 ELSE 0 END) active,
       SUM(CASE WHEN status='completed' THEN 1 ELSE 0 END) completed,
       SUM(CASE WHEN status='canceled'  THEN 1 ELSE 0 END) canceled,
       SUM(CASE WHEN status='paid'      THEN 1 ELSE 0 END) paid
FROM fact_rides
WHERE requested_at >= TRUNC(SYSDATE) - 7
GROUP BY TRUNC(requested_at)
ORDER BY day;

-- Messages per ride scatter (top 20)
SELECT r.ride_id, NVL(m.msgs,0) msgs
FROM rides r
LEFT JOIN (
  SELECT ride_id, COUNT(*) msgs FROM messages GROUP BY ride_id
) m ON m.ride_id = r.ride_id
ORDER BY msgs DESC FETCH FIRST 20 ROWS ONLY;

-- Driver last seen heatmap (by hour for last 24h)
SELECT TO_CHAR(timestamp, 'YYYY-MM-DD HH24') AS hour_bucket, COUNT(DISTINCT driver_id) drivers_seen
FROM tracking
WHERE timestamp >= SYSDATE - 1
GROUP BY TO_CHAR(timestamp, 'YYYY-MM-DD HH24')
ORDER BY hour_bucket;

-- Average minutes to start (last 30 days)
SELECT ROUND(AVG((CAST(started_at AS DATE) - CAST(requested_at AS DATE))*24*60),2) avg_minutes_to_start
FROM rides
WHERE requested_at >= SYSDATE - 30 AND started_at IS NOT NULL;

Embedding and connectivity
- Use business_intelligence/bi_connectivity.md for connection details to Oracle via your BI tool.
- Recommended tools: Power BI (ODBC/Oracle connector), Tableau, Oracle Analytics Cloud.
- Persist views in the DB for consistent semantics across dashboards.

Performance guidance
- Ensure stats are fresh: DBMS_STATS.GATHER_SCHEMA_STATS.
- Index filters used in dashboards: rides(status, requested_at), payments(timestamp, method, is_successful), tracking(timestamp), messages(sent_at).
- For large ranges, aggregate to daily via fact_*_daily views to reduce BI load.
