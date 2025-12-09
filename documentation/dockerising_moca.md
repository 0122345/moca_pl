# Oracle FREE (gvenzl/oracle-free) for MOCA

This setup runs Oracle FREE in Docker, creates PDB FREEPDB1, an app user fia_admin/fiacre, and loads your MOCA SQL scripts on first startup.

Structure
- docker-compose.yml: container definition, port exposure and volumes
- init/*.sql: initialization scripts run automatically at first container start
- ../../db/scripts: your checked-in SQL scripts mounted read-only

Prerequisites
- Docker Desktop for Windows
- At least ~4 GB RAM available for Docker

Usage
1) Open PowerShell
2) `cd d:\moca\docker\oracle`
3) `docker compose up -d`
4) First start takes several minutes. Check logs:
   `docker compose logs -f oracle`
   Wait for 'DATABASE IS READY TO USE!'

Connect
- SQLPlus:  `sqlplus fia_admin/fiacre@//localhost:1521/FREEPDB1`
- SQLcl:    sql /nolog then conn fia_admin/fiacre@//localhost:1521/FREEPDB1
- JDBC:     `jdbc:oracle:thin:@//localhost:1521/FREEPDB1`
- Node `oracledb connectString: //localhost:1521/FREEPDB1`

Environment and defaults
- Service name (PDB): FREEPDB1
- Username: fia_admin
- Password: fiacre
- Listener port: 1521 (host mapped)

Common operations
- Stop:         `docker compose stop`
- Start:        `docker compose start`
- Recreate:     `docker compose down && docker compose up -d`
- Destroy data: `docker compose down -v`  (drops the persistent volume)


## OUTPUT