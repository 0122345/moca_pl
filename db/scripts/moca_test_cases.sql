-- =====================================================
-- MOCA Test Harness: Procedures, Functions, Triggers, Cursors
-- Purpose: Execute an end-to-end flow to validate key DB objects
-- Usage: Run in SQL*Plus, SQLcl, or any client with DBMS_OUTPUT enabled
-- =====================================================

SET SERVEROUTPUT ON SIZE 1000000 FORMAT WRAPPED;
WHENEVER SQLERROR CONTINUE;

PROMPT === MOCA TEST HARNESS START ===
DECLARE
  -- Users
  v_rider_user_id   NUMBER;
  v_driver_user_id  NUMBER;
  v_driver_id       NUMBER;

  -- Ride lifecycle
  v_ride_id         NUMBER;
  v_nearby_drivers  SYS_REFCURSOR;
  v_tmp_num         NUMBER;
  v_tmp_vc          VARCHAR2(4000);

  -- Payment
  v_txn_ref         VARCHAR2(200);
  v_paid            NUMBER;
  v_fare_calc       NUMBER;
  v_fare_stored     NUMBER;

  -- Aux
  v_cnt             NUMBER;
  v_status          VARCHAR2(100);
  v_is_av           NUMBER;
BEGIN
  DBMS_OUTPUT.PUT_LINE('Step 0: Pre-check sequences/tables presence (light-touch)');
  BEGIN
    SELECT COUNT(*) INTO v_cnt FROM user_sequences WHERE sequence_name IN (
      'USERS_SEQ','DRIVERS_SEQ','RIDES_SEQ','PAYMENTS_SEQ','TRACKING_SEQ','TRACKING_HISTORY_SEQ'
    );
    DBMS_OUTPUT.PUT_LINE('  Sequences present (count known names) = ' || v_cnt);
  EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('  Skipped sequences check: ' || SQLERRM); END;

  DBMS_OUTPUT.PUT_LINE('Step 1: Register rider and driver');
  BEGIN
    -- Rider
    register_user(
      p_full_name      => 'Test Rider',
      p_email          => 'testrider+' || TO_CHAR(SYSTIMESTAMP,'YYYYMMDDHH24MISSFF3') || '@example.com',
      p_phone          => '+250788000111',
      p_role           => 'rider',
      p_password_hash  => 'hash_rider',
      p_user_id        => v_rider_user_id
    );
    DBMS_OUTPUT.PUT_LINE('  Rider user_id = ' || v_rider_user_id);

    -- Driver user
    register_user(
      p_full_name      => 'Test Driver',
      p_email          => 'testdriver+' || TO_CHAR(SYSTIMESTAMP,'YYYYMMDDHH24MISSFF3') || '@example.com',
      p_phone          => '+250788000222',
      p_role           => 'driver',
      p_password_hash  => 'hash_driver',
      p_user_id        => v_driver_user_id
    );
    DBMS_OUTPUT.PUT_LINE('  Driver user_id = ' || v_driver_user_id);

    -- Register driver
    register_driver(
      p_user_id     => v_driver_user_id,
      p_license_no  => 'LIC' || TO_CHAR(TRUNC(DBMS_RANDOM.VALUE(10000,99999))),
      p_vehicle_type=> 'car',
      p_vehicle_plate=>'RAB-001A',
      p_driver_id   => v_driver_id
    );
    DBMS_OUTPUT.PUT_LINE('  Driver driver_id = ' || v_driver_id);
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('  ERROR in registration: ' || SQLERRM); RAISE;
  END;

  DBMS_OUTPUT.PUT_LINE('Step 2: Request ride and get available drivers (ref cursor)');
  BEGIN
    request_ride(
      p_rider_id          => v_rider_user_id,
      p_pickup_lat        => -1.957875, -- Kigali approx
      p_pickup_lng        => 30.112735,
      p_drop_lat          => -1.944072,
      p_drop_lng          => 30.061885,
      p_ride_id           => v_ride_id,
      p_available_drivers => v_nearby_drivers
    );
    DBMS_OUTPUT.PUT_LINE('  Ride requested, ride_id = ' || v_ride_id);

    -- Show up to 3 returned drivers
    DECLARE
      TYPE t_drv IS RECORD (
        driver_id     NUMBER,
        user_id       NUMBER,
        license_no    VARCHAR2(200),
        vehicle_type  VARCHAR2(50),
        vehicle_plate VARCHAR2(50),
        rating        NUMBER
      );
      r t_drv;
      i PLS_INTEGER := 0;
    BEGIN
      LOOP
        FETCH v_nearby_drivers INTO r;
        EXIT WHEN v_nearby_drivers%NOTFOUND OR i >= 3;
        i := i + 1;
        DBMS_OUTPUT.PUT_LINE('   -> Nearby driver #' || i || ' id='||r.driver_id||' plate='||r.vehicle_plate||' rating='||NVL(r.rating,0));
      END LOOP;
      CLOSE v_nearby_drivers;
    END;
  EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('  ERROR in request_ride: ' || SQLERRM); RAISE; END;

  DBMS_OUTPUT.PUT_LINE('Step 3: Assign driver, start ride and update locations');
  BEGIN
    assign_driver(p_ride_id => v_ride_id, p_driver_id => v_driver_id);
    DBMS_OUTPUT.PUT_LINE('  Driver assigned');

    -- Trigger sync: driver availability should be 0 now
    v_is_av := fn_driver_available(v_driver_id);
    DBMS_OUTPUT.PUT_LINE('  Driver available after assign? ' || v_is_av);

    start_ride(p_ride_id => v_ride_id);
    DBMS_OUTPUT.PUT_LINE('  Ride started');

    update_driver_location(v_driver_id, -1.9578, 30.1127, v_ride_id);
    update_driver_location(v_driver_id, -1.9520, 30.0900, v_ride_id);
    update_driver_location(v_driver_id, -1.9440, 30.0618, v_ride_id);
    DBMS_OUTPUT.PUT_LINE('  Locations updated (tracking + history trigger)');
  EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('  ERROR in assign/start/update: ' || SQLERRM); RAISE; END;

  DBMS_OUTPUT.PUT_LINE('Step 4: Complete ride and verify fare');
  BEGIN
    complete_ride(p_ride_id => v_ride_id, p_distance_km => 7.2, p_duration_minutes => 18);
    DBMS_OUTPUT.PUT_LINE('  Ride completed');

    SELECT fare_amount, status INTO v_fare_stored, v_status FROM rides WHERE ride_id = v_ride_id;
    v_fare_calc := fn_compute_fare(7.2, 18);
    DBMS_OUTPUT.PUT_LINE('  Fare stored='||v_fare_stored||' | Fare computed='||v_fare_calc);
  EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('  ERROR in completion/fare: ' || SQLERRM); RAISE; END;

  DBMS_OUTPUT.PUT_LINE('Step 5: Record payment and validate PAID status (trigger guards)');
  BEGIN
    record_payment(p_ride_id => v_ride_id, p_amount => v_fare_stored, p_method => 'card', p_transaction_ref => v_txn_ref, p_success => v_paid);
    DBMS_OUTPUT.PUT_LINE('  Payment success='||v_paid||' txn='||v_txn_ref);

    SELECT status INTO v_status FROM rides WHERE ride_id = v_ride_id;
    DBMS_OUTPUT.PUT_LINE('  Ride status after payment='||v_status);
  EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('  ERROR in payment: ' || SQLERRM); RAISE; END;

  DBMS_OUTPUT.PUT_LINE('Step 6: Function checks (exists/validation/masking)');
  BEGIN
    DBMS_OUTPUT.PUT_LINE('  fn_user_exists(rider email) -> '|| fn_user_exists('testrider@example.com'));
    DBMS_OUTPUT.PUT_LINE('  fn_payment_method_ok(card) -> '|| fn_payment_method_ok('card'));
    DBMS_OUTPUT.PUT_LINE('  fn_vehicle_type_ok(car) -> '|| fn_vehicle_type_ok('car'));
    DBMS_OUTPUT.PUT_LINE('  fn_mask_phone(+250788000222) -> '|| fn_mask_phone('+250 788 000 222'));

    v_is_av := fn_driver_available(v_driver_id);
    DBMS_OUTPUT.PUT_LINE('  fn_driver_available(after complete) -> '|| v_is_av);

    v_tmp_num := fn_time_to_complete(v_ride_id);
    DBMS_OUTPUT.PUT_LINE('  fn_time_to_complete(ride) minutes -> ' || NVL(TO_CHAR(v_tmp_num),'NULL'));

    v_tmp_num := fn_is_ride_paid(v_ride_id);
    DBMS_OUTPUT.PUT_LINE('  fn_is_ride_paid(ride) -> '||v_tmp_num);
  EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('  ERROR in function checks: ' || SQLERRM); RAISE; END;

  DBMS_OUTPUT.PUT_LINE('Step 7: Cursor packages smoke (OPEN/FETCH/CLOSE)');
  BEGIN
    -- Active rides cursor (likely empty after completion, but ensure open/close works)
    DECLARE
      v_active_row ride_cursor_pkg.active_rides_cursor%ROWTYPE;
    BEGIN
      OPEN ride_cursor_pkg.active_rides_cursor;
      FETCH ride_cursor_pkg.active_rides_cursor INTO v_active_row;
      IF ride_cursor_pkg.active_rides_cursor%FOUND THEN
        DBMS_OUTPUT.PUT_LINE('  ride_cursor_pkg.active_rides_cursor -> at least 1 row');
      ELSE
        DBMS_OUTPUT.PUT_LINE('  ride_cursor_pkg.active_rides_cursor -> no rows (expected if all rides completed)');
      END IF;
      CLOSE ride_cursor_pkg.active_rides_cursor;
    END;

    -- Available drivers cursor
    DECLARE
      v_driver_row driver_cursor_pkg.available_drivers_cursor%ROWTYPE;
    BEGIN
      OPEN driver_cursor_pkg.available_drivers_cursor;
      FETCH driver_cursor_pkg.available_drivers_cursor INTO v_driver_row;
      IF driver_cursor_pkg.available_drivers_cursor%FOUND THEN
        DBMS_OUTPUT.PUT_LINE('  driver_cursor_pkg.available_drivers_cursor -> at least 1 row');
      ELSE
        DBMS_OUTPUT.PUT_LINE('  driver_cursor_pkg.available_drivers_cursor -> no rows');
      END IF;
      CLOSE driver_cursor_pkg.available_drivers_cursor;
    END;

    -- Pending payments cursor
    DECLARE
      v_payment_row payment_cursor_pkg.pending_payments_cursor%ROWTYPE;
    BEGIN
      OPEN payment_cursor_pkg.pending_payments_cursor;
      FETCH payment_cursor_pkg.pending_payments_cursor INTO v_payment_row;
      IF payment_cursor_pkg.pending_payments_cursor%FOUND THEN
        DBMS_OUTPUT.PUT_LINE('  payment_cursor_pkg.pending_payments_cursor -> at least 1 row');
      ELSE
        DBMS_OUTPUT.PUT_LINE('  payment_cursor_pkg.pending_payments_cursor -> no rows (expected if payments reconciled)');
      END IF;
      CLOSE payment_cursor_pkg.pending_payments_cursor;
    END;
  EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('  ERROR in cursor smoke: ' || SQLERRM); RAISE; END;

  DBMS_OUTPUT.PUT_LINE('Step 8: Trigger evidence checks');
  BEGIN
    SELECT COUNT(*) INTO v_cnt FROM tracking_history WHERE ride_id = v_ride_id;
    DBMS_OUTPUT.PUT_LINE('  tracking_history rows for ride -> ' || v_cnt);

    SELECT is_available INTO v_is_av FROM drivers WHERE driver_id = v_driver_id;
    DBMS_OUTPUT.PUT_LINE('  driver.is_available after completion -> ' || v_is_av);
  EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('  ERROR in trigger evidence checks: ' || SQLERRM); RAISE; END;

  DBMS_OUTPUT.PUT_LINE('All steps executed.');
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('FATAL ERROR in test harness: ' || SQLERRM);
END;
/

PROMPT === MOCA TEST cases END ===
