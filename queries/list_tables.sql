-- list_tables.sql
-- Lists all tables accessible to the current user (schema) with basic metadata.
-- Usage (inside SQL*Plus/SQLcl):
--   @queries/list_tables.sql

SET PAGESIZE 50000 LINESIZE 200 TRIMS ON TAB OFF VERIFY OFF FEEDBACK ON
COLUMN owner FORMAT A20
COLUMN table_name FORMAT A40
COLUMN tablespace_name FORMAT A20
COLUMN status FORMAT A8
 
PROMPT Listing tables for current user (USER_TABLES):
SELECT table_name,
       tablespace_name,
       status,
       num_rows,
       blocks
  FROM user_tables
 ORDER BY table_name;

PROMPT 
PROMPT Optional: All visible tables (ALL_TABLES) with owner (may be many rows):
SELECT owner,
       table_name,
       temporary,
       nested,
       iot_type
  FROM all_tables
 ORDER BY owner, table_name;
