# Database Triggers, Procedures, and Packages Documentation

## 1. Triggers

### 1.1. Automatic Timestamp Triggers

**Purpose:** Ensure consistency and reduce errors.

```sql
BEFORE INSERT ON USERS
SET created_at := SYSDATE;

BEFORE INSERT OR UPDATE ON RIDES
UPDATE updated_at := SYSDATE;
```

**Rationale:** Prevents application logic from missing timestamps.

### 1.2. Driver Availability Trigger

**Behavior:** Runs when a ride is completed.

```sql
WHEN RIDES.status changes to "COMPLETED":
UPDATE DRIVERS.is_available = 'Y';
```

**Rationale:** Automatically marks driver as available without relying on application code.

### 1.3. Prevent Overlapping Rides Trigger

**Behavior:** Checks that a driver does not accept a new ride while still active.

```sql
BEFORE INSERT OR UPDATE ON RIDES
IF :NEW.driver_id IS NOT NULL THEN
   VERIFY NO OTHER ACTIVE RIDE FOR THE DRIVER;
END IF;
```

**Rationale:** Protects system from logical conflicts.

### 1.4. Location Update Logging Trigger

**Behavior:** Logs each driver GPS update to a history table.

**Rationale:** Maintains audit trail of driver movements for analytics and safety purposes.

### 1.5. Payment Integrity Trigger

**Behavior:** Ensures a ride marked "PAID" has a valid payment entry.

**Rationale:** Prevents fraud or inconsistent financial data.

---

## 2. Procedures (Stored Procedures)

### 2.1. `request_ride(user_id, pickup_lat, pickup_lng, destination_lat, destination_lng)`

**Purpose:** Creates a ride request and returns available drivers.

**Rationale:** Encapsulates business logic for finding nearest drivers.

### 2.2. `assign_driver(ride_id, driver_id)`

**Purpose:** Assigns a driver and updates ride and driver records.

**Rationale:** Prevents multiple applications or services from conflicting.

### 2.3. `start_ride(ride_id)`

**Purpose:** Sets ride start time and activates billing timer.

### 2.4. `complete_ride(ride_id)`

**Purpose:** Calculates final fare (distance + time) and updates ride status.

**Rationale:** Critical shared business logic.

### 2.5. `record_payment(ride_id, amount, method)`

**Purpose:** Inserts payment record and marks ride as paid.

### 2.6. `update_driver_location(driver_id, lat, lng)`

**Purpose:** Stores real-time GPS updates (may trigger history logging).

### 2.7. `cancel_ride(ride_id, reason)`

**Purpose:** Handles cancellation business rules including:
- Late cancellation fees
- Restoring driver availability

### 2.8. `register_user` / `register_driver`

**Purpose:** Centralized validation for new account registrations.

---

## 3. Packages

Packages group related procedures and types together for better organization and maintainability.

### 3.1. Package: `ride_mgmt_pkg`

**Contains:**
- `request_ride`
- `assign_driver`
- `start_ride`
- `complete_ride`
- `cancel_ride`

**Rationale:** Groups all ride flow logic for clean and maintainable code organization.

### 3.2. Package: `billing_pkg`

**Contains:**
- `calculate_fare`
- `apply_peak_multiplier`
- `get_distance`
- `estimate_fare`

**Rationale:** Fare logic changes frequently and must be centralized for consistency.

### 3.3. Package: `user_mgmt_pkg`

**Contains:**
- `register_user`
- `update_user_profile`
- `get_user_rating`

### 3.4. Package: `driver_mgmt_pkg`

**Contains:**
- `register_driver`
- `update_driver_location`
- `set_driver_availability`
- `get_nearby_drivers`

**Rationale:** Keeps driver-related logic separate from ride management logic.

### 3.5. Package: `payment_pkg`

**Contains:**
- `record_payment`
- `refund_payment`
- `validate_payment_method`
- `generate_invoice`

**Rationale:** Financial code is isolated for enhanced security and auditing.

### 3.6. Package: `notifications_pkg`

**Contains:**
- `send_sms`
- `send_push_notification`
- `notify_driver_of_ride_request`
- `notify_user_ride_arrived`

**Rationale:** Keeps communication channels organized and centralized.

---

## 4. Cursors

The following PL/SQL cursors are provided in `moca_cursors.sql` to support operational workflows, reporting, and auditing. Each cursor is exposed inside a package and has an accompanying processing procedure.

### 4.1. `ACTIVE_RIDES_CURSOR` (package: `ride_cursor_pkg`)

**Purpose:** Retrieve ongoing rides with full rider and (when assigned) driver information for real-time tracking and dispatch operations.

**Key fields returned:** `ride_id`, `rider_id`, `rider_name`, `driver_id`, `driver_name`, `driver_rating`, `pickup_location`, `dropoff_location`, `status`, `requested_at`, `started_at`, `fare_amount`.

**Usage:** Called by monitoring or dispatch services to list rides in `requested`, `accepted`, or `active` states.

### 4.2. `AVAILABLE_DRIVERS_CURSOR` (package: `driver_cursor_pkg`)

**Purpose:** Find drivers that are currently available, along with the latest tracking point and vehicle metadata. Results are ordered to favor high-rated and lightly loaded drivers.

**Key fields returned:** `driver_id`, `driver_name`, `vehicle_type`, `vehicle_plate`, `rating`, `is_available`, `current_latitude`, `current_longitude`, `last_update`, `active_rides_count`.

**Usage:** Used during `request_ride` processing to select candidate drivers for assignment and to display nearby drivers in the app.

### 4.3. `PENDING_PAYMENTS_CURSOR` (package: `payment_cursor_pkg`)

**Purpose:** Identify rides that are `completed` but have missing, failed, or partial payment records for reconciliation and follow-up.

**Key fields returned:** `ride_id`, `rider_id`, `rider_name`, `fare_amount`, `payment_id`, `paid_amount`, `is_successful`, `transaction_ref`, `payment_status` (No Payment / Failed / Partial / Complete).

**Usage:** Finance jobs or retry processors use this cursor to trigger reminders, retry logic, or accounting adjustments.

### 4.4. `DRIVER_PERFORMANCE_CURSOR` (package: `analytics_cursor_pkg`)

**Purpose:** Produce driver-level metrics (ratings, completed rides, averages, and earnings) for analytics, leaderboards and incentive calculations.

**Key fields returned:** `driver_id`, `driver_name`, `total_rides`, `completed_rides_period`, `avg_distance_km`, `avg_duration_minutes`, `total_earnings`, `avg_fare`, `total_ratings`, `avg_rider_rating`, `first_ride_date`, `last_ride_date`.

**Usage:** Scheduled reporting and dashboards use this cursor to generate performance reports and identify drivers for rewards or coaching.

### 4.5. `LOCATION_HISTORY_CURSOR` (package: `tracking_cursor_pkg`)

**Purpose:** Return the ordered history of tracking points for a given ride (stored in `tracking_history`) to reconstruct routes, calculate distances between points, and support audits or safety investigations.

**Key fields returned:** `history_id`, `driver_id`, `driver_name`, `ride_id`, `pickup_location`, `dropoff_location`, `latitude`, `longitude`, `speed`, `heading`, `logged_at`.

**Usage:** Safety, dispute resolution, and analytics use this cursor to verify routes, detect deviations, and compute travelled distance.

---

## Example System Flow

The following sequence illustrates how these components work together:

1. User requests ride → `ride_mgmt_pkg.request_ride`
2. Find nearest drivers → `driver_mgmt_pkg.get_nearby_drivers`
3. Driver accepts → `ride_mgmt_pkg.assign_driver`
4. Ride starts → `ride_mgmt_pkg.start_ride`
5. Ride ends → `ride_mgmt_pkg.complete_ride`
6. Fare calculated → `billing_pkg.calculate_fare`
7. Payment processed → `payment_pkg.record_payment`
8. Triggers automatically update timestamps and driver availability
