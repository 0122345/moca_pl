-- Runs automatically by gvenzl/oracle-free during the very first container startup.
-- Ensures PDB FREEPDB1 is open and creates application user fiacre with required grants.

WHENEVER SQLERROR EXIT 1;

-- Open the PDB and save state
ALTER PLUGGABLE DATABASE FREEPDB1 OPEN;
ALTER PLUGGABLE DATABASE FREEPDB1 SAVE STATE;

-- Create user in the PDB
ALTER SESSION SET CONTAINER = FREEPDB1;

-- Create user if not exists pattern (Oracle lacks IF NOT EXISTS for user).
DECLARE
  l_cnt INTEGER;
BEGIN
  SELECT COUNT(*) INTO l_cnt FROM dba_users WHERE username = 'FIA_ADMIN';
  IF l_cnt = 0 THEN
    EXECUTE IMMEDIATE 'CREATE USER fia_admin IDENTIFIED BY "fiacre"';
    EXECUTE IMMEDIATE 'ALTER USER fia_admin QUOTA UNLIMITED ON users';

    -- grants
    EXECUTE IMMEDIATE 'GRANT CREATE SESSION TO fia_admin';
    EXECUTE IMMEDIATE 'GRANT CONNECT, RESOURCE TO fia_admin';
    EXECUTE IMMEDIATE 'GRANT CREATE TABLE, CREATE SEQUENCE, CREATE TRIGGER, CREATE PROCEDURE TO fia_admin';
  END IF;
END;
/

-- Make default schema usable
ALTER USER fia_admin DEFAULT TABLESPACE users;
ALTER USER fia_admin TEMPORARY TABLESPACE temp;

-- Optional: ensure synonyms or roles can be used by scripts
GRANT UNLIMITED TABLESPACE TO fia_admin;

EXIT;