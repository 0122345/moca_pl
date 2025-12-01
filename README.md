# 🚗 MOCA Mobility System - Database Documentation

## Project Information

- **Student**: 27438 Ntwari Ashimwe Fiacre
- **Course**: Database Development with PL/SQL (INSY 8311)
- **Date**: 17 November 2025
- **Database**: Oracle PL/SQL

---

## 📋 Table of Contents

1. [Database Schema Overview](#database-schema-overview)
2. [Entity Relationship Diagram](#entity-relationship-diagram)
3. [Table Definitions](#table-definitions)
4. [Sample Data](#sample-data)
5. [Window Functions - Business Analytics](#window-functions-business-analytics)
6. [Advanced Queries](#advanced-queries)

---

## Database Schema Overview

The MOCA Mobility System database consists of **8 core tables** designed to support ride-hailing operations across Rwanda:

| Table | Purpose | Records |
|-------|---------|---------|
| `users` | User accounts (riders, drivers, admins) | 10 users |
| `drivers` | Driver profiles and vehicle information | 5 drivers |
| `rides` | Ride transactions and trip details | 16 rides |
| `payments` | Payment transactions across multiple channels | 14 payments |
| `messages` | In-app communication between users | 5 messages |
| `tracking` | Real-time GPS location data | 6 tracking points |
| `driver_ratings` | Rider feedback and ratings | 10 ratings |
| `ride_requests_log` | Analytics log for matching efficiency | N/A |

---

## Entity Relationship Diagram

### Key Relationships

- **Users → Drivers**: One-to-One (driver is a specialized user)
- **Users → Rides**: One-to-Many (riders can request multiple rides)
- **Drivers → Rides**: One-to-Many (drivers fulfill multiple rides)
- **Rides → Payments**: One-to-Many (ride can have multiple payment attempts)
- **Rides → Messages**: One-to-Many (conversations during rides)
- **Drivers → Tracking**: One-to-Many (continuous location updates)
- **Rides → Ratings**: One-to-One (each completed ride gets one rating)

---

![ERD](/Moca_erd.png)

## Table Definitions

### 1. USERS Table

Core authentication and user management table.

```sql
CREATE TABLE users (
    user_id NUMBER PRIMARY KEY,
    full_name VARCHAR2(100) NOT NULL,
    email VARCHAR2(100) UNIQUE NOT NULL,
    phone VARCHAR2(15) NOT NULL,
    role VARCHAR2(20) CHECK (role IN ('rider', 'driver', 'admin')),
    password_hash VARCHAR2(255) NOT NULL,
    jwt_token VARCHAR2(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Business Rules**:

- Email must be unique across the system
- JWT tokens refresh daily for security
- Role determines system access permissions

---

### 2. DRIVERS Table

Extended driver information and performance metrics.

```sql
CREATE TABLE drivers (
    driver_id NUMBER PRIMARY KEY,
    user_id NUMBER NOT NULL,
    license_no VARCHAR2(50) NOT NULL,
    vehicle_type VARCHAR2(20) CHECK (vehicle_type IN ('car', 'moto', 'delivery')),
    vehicle_plate VARCHAR2(20) NOT NULL,
    rating NUMBER(3,2) DEFAULT 0.00,
    is_available NUMBER(1) DEFAULT 1,
    total_rides NUMBER DEFAULT 0,
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);
```

**Business Rules**:

- Rating is calculated as weighted average of all ratings
- `is_available` flag controls driver matching
- Total rides increments with each completed trip

---

### 3. RIDES Table

Core transaction table tracking all ride requests and completions.

```sql
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
    status VARCHAR2(20) CHECK (status IN ('requested', 'accepted', 'active', 'completed', 'canceled')),
    requested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    distance_km NUMBER(10,2),
    duration_minutes NUMBER,
    FOREIGN KEY (rider_id) REFERENCES users(user_id),
    FOREIGN KEY (driver_id) REFERENCES drivers(driver_id)
);
```

**Ride Status Flow**:

1. `requested` → Rider initiates request
2. `accepted` → Driver accepts ride
3. `active` → Trip in progress
4. `completed` → Trip finished successfully
5. `canceled` → Trip canceled by either party

---

### 4. PAYMENTS Table

Multi-channel payment transaction records.

```sql
CREATE TABLE payments (
    payment_id NUMBER PRIMARY KEY,
    ride_id NUMBER NOT NULL,
    amount NUMBER(10,2) NOT NULL,
    method VARCHAR2(20) CHECK (method IN ('nfc', 'momo', 'paypal', 'card', 'qr')),
    transaction_ref VARCHAR2(100) UNIQUE,
    is_successful NUMBER(1) DEFAULT 0,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    payment_details VARCHAR2(500),
    FOREIGN KEY (ride_id) REFERENCES rides(ride_id)
);
```

**Supported Payment Methods**:

- **NFC**: Apple Pay, Google Pay (contactless)
- **MoMo**: MTN Mobile Money, Airtel Money
- **Card**: Visa, Mastercard
- **PayPal**: International transactions
- **QR**: QR code-based payments

---

### 5. MESSAGES Table

In-app communication between riders and drivers.

```sql
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
```

---

### 6. TRACKING Table

Real-time GPS location data for active rides.

```sql
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
```

**Update Frequency**: Every 5 seconds during active rides

---

### 7. DRIVER_RATINGS Table

Post-ride feedback and rating system.

```sql
CREATE TABLE driver_ratings (
    rating_id NUMBER PRIMARY KEY,
    ride_id NUMBER NOT NULL,
    driver_id NUMBER NOT NULL,
    rider_id NUMBER NOT NULL,
    rating NUMBER(1) CHECK (rating BETWEEN 1 AND 5),
    comment VARCHAR2(500),
    rated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (ride_id) REFERENCES rides(ride_id),
    FOREIGN KEY (driver_id) REFERENCES drivers(driver_id),
    FOREIGN KEY (rider_id) REFERENCES users(user_id)
);
```

---

## Window Functions - Business Analytics

### CATEGORY 1: RANKING FUNCTIONS

#### Query 1.1: Top Drivers by Revenue using RANK()

Identify top-earning drivers for performance bonuses and incentives.

```sql
SELECT 
    u.full_name AS driver_name,
    d.vehicle_type,
    COUNT(r.ride_id) AS total_rides,
    SUM(r.fare_amount) AS total_revenue,
    RANK() OVER (ORDER BY SUM(r.fare_amount) DESC) AS revenue_rank,
    DENSE_RANK() OVER (ORDER BY SUM(r.fare_amount) DESC) AS dense_rank,
    ROW_NUMBER() OVER (ORDER BY SUM(r.fare_amount) DESC) AS row_num
FROM drivers d
JOIN users u ON d.user_id = u.user_id
JOIN rides r ON d.driver_id = r.driver_id
WHERE r.status = 'completed'
GROUP BY d.driver_id, u.full_name, d.vehicle_type
ORDER BY total_revenue DESC;
```

---

#### Query 1.2: Top 3 Riders by Region using ROW_NUMBER()

Target high-value customers per region for loyalty programs.

```sql
SELECT * FROM (
    SELECT 
        u.full_name AS rider_name,
        CASE 
            WHEN INSTR(r.pickup_location, 'Kigali') > 0 THEN 'Kigali'
            WHEN INSTR(r.pickup_location, 'Butare') > 0 THEN 'Butare'
            WHEN INSTR(r.pickup_location, 'Gisenyi') > 0 THEN 'Gisenyi'
            ELSE 'Other'
        END AS region,
        COUNT(r.ride_id) AS total_rides,
        SUM(r.fare_amount) AS total_spent,
        ROW_NUMBER() OVER (
            PARTITION BY CASE 
                WHEN INSTR(r.pickup_location, 'Kigali') > 0 THEN 'Kigali'
                WHEN INSTR(r.pickup_location, 'Butare') > 0 THEN 'Butare'
                ELSE 'Other'
            END 
            ORDER BY SUM(r.fare_amount) DESC
        ) AS rank_in_region
    FROM users u
    JOIN rides r ON u.user_id = r.rider_id
    WHERE u.role = 'rider' AND r.status = 'completed'
    GROUP BY u.user_id, u.full_name
) ranked_riders
WHERE rank_in_region <= 3
ORDER BY region, rank_in_region;
```

---

#### Query 1.3: Driver Performance Percentiles using PERCENT_RANK()

Categorize drivers into performance tiers for bonus structures.

```sql
SELECT 
    u.full_name AS driver_name,
    d.vehicle_type,
    d.rating AS current_rating,
    COUNT(r.ride_id) AS completed_rides,
    SUM(r.fare_amount) AS total_earnings,
    PERCENT_RANK() OVER (ORDER BY SUM(r.fare_amount)) AS earnings_percentile,
    CASE 
        WHEN PERCENT_RANK() OVER (ORDER BY SUM(r.fare_amount)) >= 0.8 THEN 'Elite Driver'
        WHEN PERCENT_RANK() OVER (ORDER BY SUM(r.fare_amount)) >= 0.6 THEN 'Gold Driver'
        WHEN PERCENT_RANK() OVER (ORDER BY SUM(r.fare_amount)) >= 0.4 THEN 'Silver Driver'
        ELSE 'Standard Driver'
    END AS performance_tier
FROM drivers d
JOIN users u ON d.user_id = u.user_id
JOIN rides r ON d.driver_id = r.driver_id
WHERE r.status = 'completed'
GROUP BY d.driver_id, u.full_name, d.vehicle_type, d.rating
ORDER BY total_earnings DESC;
```

---

### CATEGORY 2: AGGREGATE WINDOW FUNCTIONS

#### Query 2.1: Running Monthly Revenue using SUM() OVER()

Track cumulative business growth month-over-month.

```sql
SELECT 
    EXTRACT(YEAR FROM requested_at) AS year,
    EXTRACT(MONTH FROM requested_at) AS month,
    COUNT(ride_id) AS monthly_rides,
    SUM(fare_amount) AS monthly_revenue,
    SUM(SUM(fare_amount)) OVER (
        ORDER BY EXTRACT(YEAR FROM requested_at), EXTRACT(MONTH FROM requested_at)
        ROWS UNBOUNDED PRECEDING
    ) AS cumulative_revenue
FROM rides
WHERE status = 'completed'
GROUP BY EXTRACT(YEAR FROM requested_at), EXTRACT(MONTH FROM requested_at)
ORDER BY year, month;
```

---

#### Query 2.2: 3-Month Moving Average Rides using AVG() OVER()

Smooth seasonal trends to identify underlying demand patterns.

```sql
SELECT 
    EXTRACT(YEAR FROM requested_at) AS year,
    EXTRACT(MONTH FROM requested_at) AS month,
    COUNT(ride_id) AS monthly_rides,
    AVG(COUNT(ride_id)) OVER (
        ORDER BY EXTRACT(YEAR FROM requested_at), EXTRACT(MONTH FROM requested_at)
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS three_month_moving_avg
FROM rides
WHERE status = 'completed'
GROUP BY EXTRACT(YEAR FROM requested_at), EXTRACT(MONTH FROM requested_at)
ORDER BY year, month;
```

---

#### Query 2.3: Payment Method Performance Analysis

Compare payment method adoption against platform averages.

```sql
SELECT 
    payment_method,
    COUNT(ride_id) AS rides_using_method,
    SUM(fare_amount) AS total_revenue,
    AVG(fare_amount) AS avg_transaction_value,
    MIN(SUM(fare_amount)) OVER () AS worst_method_revenue,
    MAX(SUM(fare_amount)) OVER () AS best_method_revenue,
    ROUND(COUNT(ride_id) * 100.0 / SUM(COUNT(ride_id)) OVER (), 2) AS market_share_pct
FROM rides
WHERE status = 'completed'
GROUP BY payment_method
ORDER BY total_revenue DESC;
```

---

### CATEGORY 3: NAVIGATION FUNCTIONS

#### Query 3.1: Month-over-Month Growth using LAG()

Calculate revenue growth percentages to measure momentum.

```sql
SELECT 
    EXTRACT(YEAR FROM requested_at) AS year,
    EXTRACT(MONTH FROM requested_at) AS month,
    SUM(fare_amount) AS current_month_revenue,
    LAG(SUM(fare_amount), 1) OVER (
        ORDER BY EXTRACT(YEAR FROM requested_at), EXTRACT(MONTH FROM requested_at)
    ) AS previous_month_revenue,
    CASE 
        WHEN LAG(SUM(fare_amount), 1) OVER (
            ORDER BY EXTRACT(YEAR FROM requested_at), EXTRACT(MONTH FROM requested_at)
        ) IS NOT NULL THEN
            ROUND(
                ((SUM(fare_amount) - LAG(SUM(fare_amount), 1) OVER (
                    ORDER BY EXTRACT(YEAR FROM requested_at), EXTRACT(MONTH FROM requested_at)
                )) / LAG(SUM(fare_amount), 1) OVER (
                    ORDER BY EXTRACT(YEAR FROM requested_at), EXTRACT(MONTH FROM requested_at)
                )) * 100, 2
            )
        ELSE NULL
    END AS growth_percentage
FROM rides
WHERE status = 'completed'
GROUP BY EXTRACT(YEAR FROM requested_at), EXTRACT(MONTH FROM requested_at)
ORDER BY year, month;
```

---

#### Query 3.2: Rider Retention Analysis using LEAD()

Predict next ride timing for proactive engagement campaigns.

```sql
SELECT 
    u.full_name AS rider_name,
    r.requested_at AS current_ride_date,
    LEAD(r.requested_at, 1) OVER (
        PARTITION BY u.user_id ORDER BY r.requested_at
    ) AS next_ride_date,
    LEAD(r.requested_at, 1) OVER (
        PARTITION BY u.user_id ORDER BY r.requested_at
    ) - r.requested_at AS days_until_next_ride
FROM users u
JOIN rides r ON u.user_id = r.rider_id
WHERE u.role = 'rider' AND r.status = 'completed'
ORDER BY u.full_name, r.requested_at;
```

---

#### Query 3.3: Customer Journey Analysis using FIRST_VALUE() and LAST_VALUE()

Understand rider lifecycle from first to most recent ride.

```sql
SELECT DISTINCT
    u.user_id,
    u.full_name AS rider_name,
    FIRST_VALUE(r.requested_at) OVER (
        PARTITION BY u.user_id ORDER BY r.requested_at
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS first_ride_date,
    LAST_VALUE(r.requested_at) OVER (
        PARTITION BY u.user_id ORDER BY r.requested_at
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS last_ride_date,
    FIRST_VALUE(r.payment_method) OVER (
        PARTITION BY u.user_id ORDER BY r.requested_at
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS first_payment_method,
    LAST_VALUE(r.payment_method) OVER (
        PARTITION BY u.user_id ORDER BY r.requested_at
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS last_payment_method
FROM users u
JOIN rides r ON u.user_id = r.rider_id
WHERE u.role = 'rider' AND r.status = 'completed'
ORDER BY u.user_id;
```

---

### CATEGORY 4: DISTRIBUTION FUNCTIONS

#### Query 4.1: Rider Segmentation using NTILE(4)

Divide riders into quartiles for targeted marketing.

```sql
SELECT 
    u.full_name AS rider_name,
    COUNT(r.ride_id) AS total_rides,
    SUM(r.fare_amount) AS total_spent,
    AVG(r.fare_amount) AS avg_fare,
    NTILE(4) OVER (ORDER BY SUM(r.fare_amount)) AS spending_quartile,
    CASE NTILE(4) OVER (ORDER BY SUM(r.fare_amount))
        WHEN 4 THEN 'VIP Customer'
        WHEN 3 THEN 'High-Value Customer'
        WHEN 2 THEN 'Regular Customer'
        WHEN 1 THEN 'Casual User'
    END AS customer_segment
FROM users u
JOIN rides r ON u.user_id = r.rider_id
WHERE u.role = 'rider' AND r.status = 'completed'
GROUP BY u.user_id, u.full_name
ORDER BY total_spent DESC;
```

---

#### Query 4.2: Cumulative Distribution of Riders using CUME_DIST()

Understand spending distribution across customer base.

```sql
SELECT 
    u.full_name AS rider_name,
    SUM(r.fare_amount) AS total_spent,
    CUME_DIST() OVER (ORDER BY SUM(r.fare_amount)) AS cumulative_distribution,
    ROUND(CUME_DIST() OVER (ORDER BY SUM(r.fare_amount)) * 100, 1) AS percentile,
    CASE 
        WHEN CUME_DIST() OVER (ORDER BY SUM(r.fare_amount)) >= 0.90 THEN 'Top 10%'
        WHEN CUME_DIST() OVER (ORDER BY SUM(r.fare_amount)) >= 0.75 THEN 'Top 25%'
        WHEN CUME_DIST() OVER (ORDER BY SUM(r.fare_amount)) >= 0.50 THEN 'Top 50%'
        ELSE 'Bottom 50%'
    END AS spending_category
FROM users u
JOIN rides r ON u.user_id = r.rider_id
WHERE u.role = 'rider' AND r.status = 'completed'
GROUP BY u.user_id, u.full_name
ORDER BY total_spent DESC;
```

---

#### Query 4.3: Driver Performance by Vehicle Type using NTILE()

Rank drivers within their vehicle category.

```sql
SELECT 
    u.full_name AS driver_name,
    d.vehicle_type,
    d.rating,
    COUNT(r.ride_id) AS total_rides,
    SUM(r.fare_amount) AS total_earnings,
    NTILE(3) OVER (
        PARTITION BY d.vehicle_type 
        ORDER BY SUM(r.fare_amount)
    ) AS performance_tier,
    CASE NTILE(3) OVER (PARTITION BY d.vehicle_type ORDER BY SUM(r.fare_amount))
        WHEN 3 THEN 'Top Performer'
        WHEN 2 THEN 'Average Performer'
        WHEN 1 THEN 'Needs Improvement'
    END AS performance_category
FROM drivers d
JOIN users u ON d.user_id = u.user_id
JOIN rides r ON d.driver_id = r.driver_id
WHERE r.status = 'completed'
GROUP BY d.driver_id, u.full_name, d.vehicle_type, d.rating
ORDER BY d.vehicle_type, total_earnings DESC;
```

---

## Advanced Business Analytics Queries

### Query 5: Comprehensive Driver Performance Dashboard

Executive view of driver metrics with multiple analytical dimensions.

```sql
SELECT 
    u.full_name AS driver_name,
    d.vehicle_type,
    d.vehicle_plate,
    d.rating AS overall_rating,
    COUNT(r.ride_id) AS total_rides,
    SUM(r.fare_amount) AS total_earnings,
    AVG(r.fare_amount) AS avg_fare_per_ride,
    AVG(r.distance_km) AS avg_distance_km,
    RANK() OVER (ORDER BY SUM(r.fare_amount) DESC) AS earnings_rank,
    RANK() OVER (PARTITION BY d.vehicle_type ORDER BY SUM(r.fare_amount) DESC) AS rank_in_category,
    ROUND(SUM(r.fare_amount) / SUM(SUM(r.fare_amount)) OVER () * 100, 2) AS earnings_share_pct,
    SUM(SUM(r.fare_amount)) OVER (
        ORDER BY SUM(r.fare_amount) DESC
        ROWS UNBOUNDED PRECEDING
    ) AS cumulative_earnings
FROM drivers d
JOIN users u ON d.user_id = u.user_id
JOIN rides r ON d.driver_id = r.driver_id
WHERE r.status = 'completed'
GROUP BY d.driver_id, u.full_name, d.vehicle_type, d.vehicle_plate, d.rating
ORDER BY total_earnings DESC;
```

---

### Query 6: Payment Method Adoption Trend Analysis

Track payment method preferences and shifts over time.

```sql
SELECT 
    EXTRACT(YEAR FROM requested_at) AS year,
    EXTRACT(MONTH FROM requested_at) AS month,
    payment_method,
    COUNT(ride_id) AS transaction_count,
    SUM(fare_amount) AS method_revenue,
    ROUND(
        COUNT(ride_id) * 100.0 / 
        SUM(COUNT(ride_id)) OVER (
            PARTITION BY EXTRACT(YEAR FROM requested_at), EXTRACT(MONTH FROM requested_at)
        ), 2
    ) AS monthly_market_share_pct,
    LAG(COUNT(ride_id), 1) OVER (
        PARTITION BY payment_method
        ORDER BY EXTRACT(YEAR FROM requested_at), EXTRACT(MONTH FROM requested_at)
    ) AS previous_month_count
FROM rides
WHERE status = 'completed'
GROUP BY EXTRACT(YEAR FROM requested_at), EXTRACT(MONTH FROM requested_at), payment_method
ORDER BY year, month, method_revenue DESC;
```

---

### Query 7: Rider Lifetime Value (LTV) Analysis

Calculate total value and engagement metrics per rider.

```sql
SELECT 
    u.full_name AS rider_name,
    u.email,
    u.created_at AS registration_date,
    COUNT(r.ride_id) AS total_rides,
    SUM(r.fare_amount) AS lifetime_value,
    AVG(r.fare_amount) AS avg_order_value,
    MAX(r.requested_at) - MIN(r.requested_at) AS customer_lifespan_days,
    MAX(r.requested_at) AS last_ride_date,
    DENSE_RANK() OVER (ORDER BY SUM(r.fare_amount) DESC) AS ltv_rank,
    CASE 
        WHEN MAX(r.requested_at) >= CURRENT_TIMESTAMP - INTERVAL '30' DAY THEN 'Active'
        WHEN MAX(r.requested_at) >= CURRENT_TIMESTAMP - INTERVAL '90' DAY THEN 'At Risk'
        ELSE 'Churned'
    END AS customer_status
FROM users u
JOIN rides r ON u.user_id = r.rider_id
WHERE u.role = 'rider' AND r.status = 'completed'
GROUP BY u.user_id, u.full_name, u.email, u.created_at
ORDER BY lifetime_value DESC;
```

---

## Key Performance Indicators (KPIs)

### Business Metrics Dashboard

```sql
-- Overall Platform Health Metrics
SELECT 
    'Total Rides' AS metric,
    COUNT(*) AS value
FROM rides WHERE status = 'completed'
UNION ALL
SELECT 
    'Total Revenue',
    SUM(fare_amount)
FROM rides WHERE status = 'completed'
UNION ALL
SELECT 
    'Active Drivers',
    COUNT(*)
FROM drivers WHERE is_available = 1
UNION ALL
SELECT 
    'Average Rating',
    ROUND(AVG(rating), 2)
FROM driver_ratings
UNION ALL
SELECT 
    'Completion Rate (%)',
    ROUND(
        COUNT(CASE WHEN status = 'completed' THEN 1 END) * 100.0 / 
        COUNT(CASE WHEN status IN ('completed', 'canceled') THEN 1 END), 2
    )
FROM rides;
```

---

## Conclusion

This database schema provides a robust foundation for the MOCA Mobility System, supporting:

✅ **Multi-channel payment processing** (NFC, MoMo, Cards, PayPal, QR)  
✅ **Real-time location tracking** for driver and rider safety  
✅ **Comprehensive analytics** through window functions  
✅ **Rider and driver performance metrics** for business intelligence  
✅ **Flexible communication** through in-app messaging  
✅ **Scalable architecture** for future expansion  

The window function queries enable data-driven decision making for:

- **Driver incentive programs**
- **Customer segmentation and targeting**
- **Revenue forecasting and trend analysis**
- **Operational efficiency optimization**
- **Payment method strategy**

---

**Database Status**: ✅ Production Ready  
**Last Updated**: 17 November 2025  
**Total Tables**: 8  
**Total Sample Records**: 66  
**Indexing**: Optimized for query performance
