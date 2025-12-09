-- show_row_counts.sql
-- Shows estimated and exact row counts for all tables in the current user schema.
-- Usage:
--   @queries/show_row_counts.sql
-- Notes:
--   - USER_TABLES.NUM_ROWS is based on statistics and may be stale.
--   - Exact counts use a SQL-generated approach without dynamic PL/SQL.

SET PAGESIZE 50000 LINESIZE 200 TRIMS ON TAB OFF VERIFY OFF FEEDBACK ON
COLUMN table_name FORMAT A40
COLUMN est_rows FORMAT 999,999,999,999
COLUMN exact_rows FORMAT 999,999,999,999

PROMPT Estimated row counts from USER_TABLES (may be stale):
SELECT table_name,
       NVL(num_rows, 0) AS est_rows
  FROM user_tables
 ORDER BY table_name;

PROMPT 
PROMPT Exact row counts (this may take time on large tables):
-- This uses XML/DBMS_XMLGEN to avoid dynamic PL/SQL blocks in a script
-- and still compute exact COUNT(*) per table.
WITH t AS (
  SELECT table_name FROM user_tables
)
SELECT t.table_name,
       TO_NUMBER(EXTRACTVALUE(XMLTYPE(DBMS_XMLGEN.GETXML('SELECT COUNT(*) c FROM '||t.table_name)), '/ROWSET/ROW/C')) AS exact_rows
  FROM t
 ORDER BY t.table_name;
