-- preview_top_n.sql
-- Generate and execute SELECT statements to preview top-N rows for every table in the current user schema.
-- Usage:
--   DEFINE N = 10; -- optional, default 10
--   @queries/preview_top_n.sql
-- Notes:
--   - Uses SQL*Plus substitution variable N (default 10)
--   - Uses DBMS_SQL to safely execute dynamic SQL per table
--   - Prints column headings and first N rows per table

SET SERVEROUTPUT ON SIZE UNLIMITED FORMAT WRAPPED
SET VERIFY OFF FEEDBACK ON PAGESIZE 1000 LINESIZE 32767 TRIMS ON

COLUMN previewing FORMAT A80

-- Default N to 10 if not provided
COLUMN n NEW_VALUE _N
SELECT NVL('&N', '10') n FROM dual;

DECLARE
  v_n            PLS_INTEGER := TO_NUMBER('&&_N');
  v_sql          VARCHAR2(32767);
  v_cursor       INTEGER;
  v_col_cnt      INTEGER;
  v_desc_tab     DBMS_SQL.DESC_TAB2;
  v_status       INTEGER;
  v_owner        VARCHAR2(128) := USER;

  PROCEDURE print_line(p_text VARCHAR2) IS
  BEGIN
    DBMS_OUTPUT.put_line(p_text);
  END;

  FUNCTION safe_quote(p_identifier VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    -- naive quote for identifiers; assumes created without quotes
    RETURN '"' || REPLACE(p_identifier, '"', '""') || '"';
  END;

  PROCEDURE execute_and_print(p_table VARCHAR2) IS
    v_val_varchar VARCHAR2(4000);
    v_val_num     NUMBER;
    v_val_date    DATE;
    v_val_ts      TIMESTAMP;
    v_val_ts_tz   TIMESTAMP WITH TIME ZONE;
    v_val_int     BINARY_INTEGER;
    v_col_val     VARCHAR2(4000);
    v_col_type    PLS_INTEGER;
  BEGIN
    v_sql := 'SELECT * FROM '||safe_quote(p_table)||' FETCH FIRST '||v_n||' ROWS ONLY';
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
    print_line('==== '||p_table||' ====');

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
      print_line('Error previewing table '||p_table||': '||SQLERRM);
  END;

BEGIN
  FOR r IN (
    SELECT table_name FROM user_tables ORDER BY table_name
  ) LOOP
    execute_and_print(r.table_name);
  END LOOP;
END;
/
