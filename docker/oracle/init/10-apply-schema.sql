-- Applies your schema scripts into FREEPDB1 as the application user

WHENEVER SQLERROR EXIT 1;

ALTER SESSION SET CONTAINER = FREEPDB1;

-- Connect as APP user for object creation
CONNECT fia_admin/"fiacre"@FREEPDB1

-- Core schema first
@@/opt/moca/db/scripts/db.schema.sql

-- Programmatic units and additional objects (order matters)
@@/opt/moca/db/scripts/moca_functions.sql
@@/opt/moca/db/scripts/moca_packages.sql
@@/opt/moca/db/scripts/moca_procedures.sql
@@/opt/moca/db/scripts/moca_triggers.sql
@@/opt/moca/db/scripts/moca_cursors.sql

-- Optional test data / unit tests
@@/opt/moca/db/scripts/moca_test_cases.sql

EXIT;