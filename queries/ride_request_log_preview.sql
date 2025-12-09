-- ride_request_log_preview.sql
-- Preview top-N rows from RIDE_REQUEST_LOG with optional ORDER BY.
-- Usage (SQL*Plus/SQLcl):
--   DEFINE N = 20
--   DEFINE ORDER_BY = CREATED_AT DESC
--   @queries/ride_request_log_preview.sql
-- Notes:
--   - If N is not provided, defaults to 10.
--   - If ORDER_BY is not provided, no ordering is applied.

SET SERVEROUTPUT ON SIZE UNLIMITED FORMAT WRAPPED
SET VERIFY OFF FEEDBACK ON PAGESIZE 1000 LINESIZE 32767 TRIMS ON

-- Resolve N with default value
COLUMN n NEW_VALUE _N
SELECT NVL('&N', '10') n FROM dual;

-- Resolve ORDER_BY (may be empty)
COLUMN ob NEW_VALUE _ORDER_BY
SELECT NVL('&ORDER_BY', '') ob FROM dual;

DECLARE
  v_n          PLS_INTEGER := TO_NUMBER('&&_N');
  v_order_by   VARCHAR2(4000) := '&&_ORDER_BY';
  v_sql        VARCHAR2(32767);
  v_cursor     INTEGER;
  v_col_cnt    INTEGER;
  v_desc_tab   DBMS_SQL.DESC_TAB2;
  v_status     INTEGER;

  v_val_varchar VARCHAR2(4000);
  v_val_num     NUMBER;
  v_val_date    DATE;
  v_val_ts      TIMESTAMP;
  v_val_ts_tz   TIMESTAMP WITH TIME ZONE;
  v_col_val     VARCHAR2(4000);
  v_col_type    PLS_INTEGER;

  PROCEDURE print_line(p_text VARCHAR2) IS
  BEGIN
    DBMS_OUTPUT.put_line(p_text);
  END;
BEGIN
  v_sql := 'SELECT * FROM RIDE_REQUEST_LOG';
  IF TRIM(v_order_by) IS NOT NULL THEN
    v_sql := v_sql || ' ORDER BY ' || v_order_by;
  END IF;
  v_sql := v_sql || ' FETCH FIRST ' || v_n || ' ROWS ONLY';

  v_cursor := DBMS_SQL.open_cursor;
  DBMS_SQL.parse(v_cursor, v_sql, DBMS_SQL.native);
  DBMS_SQL.describe_columns2(v_cursor, v_col_cnt, v_desc_tab);

  FOR i IN 1..v_col_cnt LOOP
    CASE v_desc_tab(i).col_type
      WHEN 2 THEN DBMS_SQL.define_column(v_cursor, i, v_val_num);
      WHEN 12 THEN DBMS_SQL.define_column(v_cursor, i, v_val_date);
      WHEN 180 THEN DBMS_SQL.define_column(v_cursor, i, v_val_ts);
      WHEN 181 THEN DBMS_SQL.define_column(v_cursor, i, v_val_ts_tz);
      ELSE DBMS_SQL.define_column(v_cursor, i, v_val_varchar, 4000);
    END CASE;
  END LOOP;

  v_status := DBMS_SQL.execute(v_cursor);

  print_line('');
  print_line('==== RIDE_REQUEST_LOG ====');

  -- Print header
  DECLARE
    v_header VARCHAR2(32767) := '';
  BEGIN
    FOR i IN 1..v_col_cnt LOOP
      v_header := v_header || CASE WHEN i>1 THEN ' | ' ELSE '' END || v_desc_tab(i).col_name;
    END LOOP;
    print_line(v_header);
    print_line(RPAD('-', LEAST(LENGTH(v_header), 250), '-'));
  END;

  -- Print rows
  WHILE DBMS_SQL.fetch_rows(v_cursor) > 0 LOOP
    DECLARE
      v_row VARCHAR2(32767) := '';
    BEGIN
      FOR i IN 1..v_col_cnt LOOP
        v_col_type := v_desc_tab(i).col_type;
        IF v_col_type = 2 THEN
          DBMS_SQL.column_value(v_cursor, i, v_val_num);
          v_col_val := TO_CHAR(v_val_num);
        ELSIF v_col_type = 12 THEN
          DBMS_SQL.column_value(v_cursor, i, v_val_date);
          v_col_val := TO_CHAR(v_val_date, 'YYYY-MM-DD HH24:MI:SS');
        ELSIF v_col_type = 180 THEN
          DBMS_SQL.column_value(v_cursor, i, v_val_ts);
          v_col_val := TO_CHAR(v_val_ts, 'YYYY-MM-DD HH24:MI:SS.FF3');
        ELSIF v_col_type = 181 THEN
          DBMS_SQL.column_value(v_cursor, i, v_val_ts_tz);
          v_col_val := TO_CHAR(v_val_ts_tz, 'YYYY-MM-DD HH24:MI:SS.FF3 TZH:TZM');
        ELSE
          DBMS_SQL.column_value(v_cursor, i, v_val_varchar);
          v_col_val := SUBSTR(v_val_varchar, 1, 2000);
        END IF;
        v_row := v_row || CASE WHEN i>1 THEN ' | ' ELSE '' END || NVL(v_col_val, 'NULL');
      END LOOP;
      print_line(SUBSTR(v_row, 1, 10000));
    END;
  END LOOP;

  DBMS_SQL.close_cursor(v_cursor);
EXCEPTION
  WHEN OTHERS THEN
    IF DBMS_SQL.is_open(v_cursor) THEN
      DBMS_SQL.close_cursor(v_cursor);
    END IF;
    print_line('Error previewing RIDE_REQUEST_LOG: '||SQLERRM);
END;
/
