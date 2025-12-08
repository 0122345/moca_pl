#🧾Oracle Database: PDB Management

Environment
- Oracle Database 26ai Free Edition running in Docker (host: Windows 11)

Overview
This repository documents a hands-on lab for creating, managing, and deleting Oracle pluggable databases (PDBs) using Oracle 26ai running inside Docker. The exercises demonstrate PDB creation, verification, and cleanup. Screenshots from the lab are included in the `screenshots/db/db_creation` folder.

## Key artifacts
- Created PDB: `mon_27438_fiacre_moca_db`
- Admin user: `fia_admin`
- Password: `fiacre`
- db_name: `moca_db`

Commands used (examples)
The following SQL and Docker examples illustrate the steps performed during the lab. Adapt identifiers and file paths to your environment.


1) SET UP DOCKER environment

OPen Terminal and type

```bash
    docker pull gvenzl/oracle-free
```

2) SET UP ORACLE GVENZL/ORACLE-FREE with name, port, and password

     ```bash
          docker run -d \
           --name oracle-free \
          -p 1521:1521 \
          -e ORACLE_PASSWORD=fiacre \
          gvenzl/oracle-free
    ```    


3) After run this command to see logs to wait and see if db is ready for use

     `docker logs oracle-free -f`

4) Use SQL*Plus inside the container:

`docker exec -it oracle-free sqlplus sys/fiacre@localhost:1521/FREEPDB1 as sysdba`

![alt](/screenshots/db/db_creation/runningsqlplus.png)

<b>Find the REAL directory paths

Run inside the container:

```bash
docker exec -it oracle-free bash
```

Then:

```bash
ls -R /opt/oracle/oradata
```
</b>

5) Create a pluggable database (example)

```sql
CREATE PLUGGABLE DATABASE mon_27438_fiacre_moca_db
  ADMIN USER fia_admin IDENTIFIED BY fiacre
  FILE_NAME_CONVERT = (
    '/opt/oracle/oradata/FREE/pdbseed/',
    '/opt/oracle/oradata/FREE/mon_27438_fiacre_moca_db/'
  );

```

![alt](/screenshots/db/db_creation/creatingpdb.png)

6) Open the PDB

```sql
ALTER PLUGGABLE DATABASE ntwari_27438_fiacre_moca_db OPEN;
```

7) save state:

```sql
ALTER PLUGGABLE DATABASE mon_27438_fiacre_moca_db SAVE STATE;
```

<b>Verify PDBs</b>

```sql
SHOW PDBS;
```

![alt](/screenshots/db/db_creation/creatingpdb.png)

8) Grant DBA / Super Admin Privileges

```sql 
GRANT DBA TO fia_admin;
ALTER USER fia_admin QUOTA UNLIMITED ON USERS;
```

9) Connect directly to your new PDB

```sql 
sqlplus fia_admin/fiacre@localhost:1521/NTWARI_27438_FIACRE_MOCA_DB
```

10)SQL Developer Connection Settings

Connection Name `moca_pdb`

Username `fia_admin`

Password `fiacre`

[`checked`] Check Save Password

Connection Type
Basic

Role `SYSDBA`

🟩 Hostname `localhost`

🟩 Port `1521`

🟩 Service name (very important! `MON_27438_FIACRE_MOCA_DB`

✔ Select Service name, not SID.

✔ Test connection, then Connect and save
![alt](/screenshots/db/db_creation/connectingtovscode.png)


<b>Reproducibility checklist</b>
- Ensure Docker is installed and running on the host.
- Use an Oracle 26ai Free image compatible with your host OS.
- Confirm the container has adequate memory and disk for Oracle.
- Adjust file name conversion paths when cloning or creating PDBs.

Conclusion
This is almost or some of activity I did on creating pluggable db
