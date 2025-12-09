# MOCA KPI Definitions

Purpose
- Establish canonical definitions for metrics used across dashboards and reports.
- Align KPIs with the Oracle schema to ensure reproducibility and auditability.

General conventions
- Timezone: database server local time (SYSDATE). If reporting TZ differs, adjust at BI layer or use AT TIME ZONE.
- Day grain: TRUNC(timestamp) defines the reporting day.
- Flags: 1=true, 0=false for is_successful, is_read, is_available.
- GMV: sum of gross fares before fees/discounts. Use rides.fare_amount.

Core entities and grains
- Ride grain: one row per ride_id.
- Payment grain: one row per payment_id; multiple rows may exist per ride_id (e.g., retries, split payments).
- Tracking grain: one row per tracking point; aggregate to daily when used in KPIs.
- Message grain: one row per message_id; aggregate to ride or daily.

KPIs
1) Rides Today
Definition: Number of rides requested on the reporting date.
Formula (SQL):
` SELECT COUNT(*) FROM rides WHERE TRUNC(requested_at)=TRUNC(SYSDATE);`
Grain: daily and intraday.

2) Active Drivers Today
Definition: Count of distinct drivers who either generated tracking points today or were assigned to rides requested today.
Formula (SQL):
`SELECT COUNT(DISTINCT driver_id)
FROM (
  SELECT driver_id FROM rides WHERE TRUNC(requested_at)=TRUNC(SYSDATE) AND driver_id IS NOT NULL
  UNION
  SELECT driver_id FROM tracking WHERE TRUNC(timestamp)=TRUNC(SYSDATE)
);`
Grain: daily.

3) GMV (Gross Merchandise Value)
Definition: Sum of fare_amount for requested rides within the period.
Formula (SQL): `SELECT SUM(NVL(fare_amount,0)) FROM rides WHERE requested_at BETWEEN :start AND :end;`
Grain: any; default daily.

4) Payment Success Rate
Definition: Share of payment attempts that are successful in the period.
Formula (SQL):
`SELECT ROUND(100*AVG(CASE WHEN is_successful=1 THEN 1 ELSE 0 END),2)
FROM payments
WHERE timestamp BETWEEN :start AND :end;`
Grain: any; default daily.

5) Completion Rate
Definition: Completed rides divided by requested rides in period.
Formula (SQL):
`WITH r AS (
  SELECT COUNT(*) requested
  FROM rides WHERE requested_at BETWEEN :start AND :end
), c AS (
  SELECT COUNT(*) completed
  FROM rides WHERE status='completed' AND requested_at BETWEEN :start AND :end
)
SELECT CASE WHEN r.requested=0 THEN NULL ELSE ROUND(100*c.completed/r.requested,2) END AS completion_rate_pct
FROM r, c;`
Grain: daily.

6) Average Time to Start (ETA proxy)
Definition: Average minutes from request to ride start for rides that started in the window.
Formula (SQL):
`SELECT ROUND(AVG((CAST(started_at AS DATE) - CAST(requested_at AS DATE))*24*60),2)
FROM rides
WHERE started_at BETWEEN :start AND :end;`
Grain: daily; exclude missing timestamps.

7) Average Ride Duration
Definition: Average minutes from start to completion for completed rides.
Formula (SQL):
SELECT ROUND(AVG((CAST(completed_at AS DATE) - CAST(started_at AS DATE))*24*60),2)
FROM rides
WHERE completed_at BETWEEN :start AND :end;
Grain: daily.

8) Match Rate (Requests -> Matched)
Definition: Share of ride requests that got matched to a driver.
Source: ride_requests_log.was_matched.
Formula (SQL):
SELECT ROUND(100*AVG(CASE WHEN was_matched=1 THEN 1 ELSE 0 END),2)
FROM ride_requests_log
WHERE requested_at BETWEEN :start AND :end;
Grain: daily.

9) Average Time to Match
Definition: Mean of time_to_match_seconds for matched requests.
Formula (SQL):
SELECT ROUND(AVG(CASE WHEN was_matched=1 THEN time_to_match_seconds END),2)
FROM ride_requests_log
WHERE requested_at BETWEEN :start AND :end;
Grain: daily.

10) Payment Method Mix
Definition: Distribution of payment attempts by channel in a period.
Formula (SQL):
SELECT method,
       COUNT(*) attempts,
       ROUND(100*RATIO_TO_REPORT(COUNT(*)) OVER (),2) pct
FROM payments
WHERE timestamp BETWEEN :start AND :end
GROUP BY method;
Grain: channel x period.

11) Reconciliation Gap (Completed w/o Success Payment)
Definition: Count of rides with status in ('completed','paid') but no successful payments.
Formula (SQL):
SELECT COUNT(*)
FROM (
  SELECT r.ride_id
  FROM rides r
  LEFT JOIN (
    SELECT ride_id, MAX(is_successful) AS has_success
    FROM payments
    GROUP BY ride_id
  ) p ON p.ride_id = r.ride_id
  WHERE r.status IN ('completed','paid') AND NVL(p.has_success,0)=0
);
Grain: count in period or absolute.

12) Driver Rating (Avg)
Definition: Average of drivers.rating or derived from driver_ratings table.
Formula (SQL): SELECT ROUND(AVG(rating),2) FROM drivers; -- snapshot value
Alternative per period: SELECT ROUND(AVG(rating),2) FROM driver_ratings WHERE rated_at BETWEEN :start AND :end;
Grain: snapshot or period.

13) Speed Outlier Rate
Definition: Share of tracking rows with speed > 120 km/h.
Formula (SQL):
SELECT ROUND(100*AVG(CASE WHEN speed>120 THEN 1 ELSE 0 END),2)
FROM tracking
WHERE timestamp BETWEEN :start AND :end;
Grain: daily.

14) ARPU (GMV per unique rider)
Definition: GMV divided by distinct riders who requested rides in the period.
Formula (SQL):
WITH g AS (
  SELECT SUM(NVL(fare_amount,0)) gmv
  FROM rides WHERE requested_at BETWEEN :start AND :end
), r AS (
  SELECT COUNT(DISTINCT rider_id) riders
  FROM rides WHERE requested_at BETWEEN :start AND :end
)
SELECT CASE WHEN r.riders=0 THEN NULL ELSE ROUND(g.gmv/r.riders,2) END AS arpu
FROM g, r;
Grain: daily.

15) Messages per Ride (Avg)
Definition: Average number of chat messages per ride in the period.
Formula (SQL):
WITH m AS (
  SELECT ride_id, COUNT(*) msgs
  FROM messages
  WHERE sent_at BETWEEN :start AND :end
  GROUP BY ride_id
)
SELECT ROUND(AVG(msgs),2) FROM m;
Grain: daily.

Dimensional attributes
- Date: date_key from dim_date or TRUNC(<timestamp>). Use calendar fields for slicing (year, month, week, dow).
- Geography: textual addresses exist; lat/lon available per ride. For mapping, use pickup_* and dropoff_*.
- User role: from users.role; driver attributes from drivers.vehicle_type, rating.
- Payment channel: from payments.method or rides.payment_method.
- Ride status: categorical funnel stages in rides.status.

Quality and exclusions
- Exclude rides with missing requested_at from time-based KPIs.
- For duration-based metrics, require both endpoints present.
- Cap or Winsorize speeds > 150 km/h if used for averages.

Versioning
- Maintain semantic versioning for KPI changes. Add a changelog section with dates and rationale when formulas evolve.
