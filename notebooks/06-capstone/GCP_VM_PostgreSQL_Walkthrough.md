# GCP VM + PostgreSQL Walkthrough — DS2002 Capstone (Optional Extension)

This guide walks you through spinning up a GCP Compute Engine VM, installing PostgreSQL on it, opening the firewall so your Colab notebook can connect, and writing / querying data from Python. This replaces SQLite with a real client-server database and is closer to how production data pipelines are built.

This is **not required** for the capstone. It is here for teams that want to go further.

---

## Prerequisites

- You have completed the `GCP_Console_Walkthrough.md` steps and can authenticate from Colab.
- You know your GCP **project ID**: `ds2002sp26`
- You know your **team number** (e.g., `team-05`).

---

## 1. Create the VM

1. Open the GCP Console: [https://console.cloud.google.com](https://console.cloud.google.com).
2. Select the course project (`ds2002sp26`) from the project selector at the top.
3. In the left navigation menu, click **Compute Engine** → **VM instances**.
4. Click **Create Instance** at the top.

Fill in the fields **exactly** as shown below:

| Field | Value |
|---|---|
| **Name** | `ds2002-team-XX-pg` (replace XX with your team number) |
| **Region** | `us-east1` |
| **Zone** | `us-east1-b` |
| **Machine type** | `e2-micro` (free-tier eligible, under General Purpose → E2) |
| **Boot disk OS** | `Debian GNU/Linux 12 (bookworm)` |
| **Boot disk size** | `10 GB` |
| **Firewall** | Leave both checkboxes (HTTP/HTTPS) **unchecked** — you will add a targeted rule in Step 3 |

5. Leave everything else at the default.
6. Click **Create** at the bottom. The VM will take about 30–60 seconds to start.
7. Once the status dot turns **green**, your VM is running. Note the **External IP** shown in the VM list — you will need it later.

---

## 2. Install PostgreSQL on the VM

1. In the VM list, click the **SSH** button on the right side of your VM's row. A browser terminal window opens — this is a full Linux shell running on your VM.

2. Run the following commands **one block at a time** in the SSH terminal:

### 2a. Update packages and install PostgreSQL

```bash
sudo apt-get update
sudo apt-get install -y postgresql postgresql-contrib
```

This installs PostgreSQL 15 (the version in Debian 12's default repos). When it finishes, the service starts automatically.

### 2b. Verify the service is running

```bash
sudo systemctl status postgresql
```

You should see `Active: active (running)`. Press `q` to exit.

### 2c. Create a database user and database

Switch to the `postgres` Linux user, then open the PostgreSQL prompt:

```bash
sudo -i -u postgres
psql
```

Inside the `psql` prompt, run these SQL commands. Replace `yourpassword` with a real password you will remember — you will need it in your Colab notebook.

```sql
CREATE USER capstone WITH PASSWORD 'yourpassword';
CREATE DATABASE ev_analytics OWNER capstone;
GRANT ALL PRIVILEGES ON DATABASE ev_analytics TO capstone;
\q
```

After `\q`, type `exit` to leave the `postgres` Linux user shell and return to your normal shell.

```bash
exit
```

---

## 3. Configure PostgreSQL to Accept Remote Connections

By default, PostgreSQL only listens on `localhost` and blocks all remote logins. You need to change two configuration files.

### 3a. Edit `postgresql.conf` — tell Postgres to listen on all interfaces

Find the config file:

```bash
sudo find /etc/postgresql -name "postgresql.conf"
```

It will be something like `/etc/postgresql/15/main/postgresql.conf`. Open it:

```bash
sudo nano /etc/postgresql/15/main/postgresql.conf
```

Find the line that reads:

```
#listen_addresses = 'localhost'
```

Change it to (remove the `#` and change the value):

```
listen_addresses = '*'
```

Save the file: press **Ctrl+O**, then **Enter**, then **Ctrl+X** to exit.

### 3b. Edit `pg_hba.conf` — tell Postgres to accept password logins from the internet

Find the file:

```bash
sudo find /etc/postgresql -name "pg_hba.conf"
```

Open it:

```bash
sudo nano /etc/postgresql/15/main/pg_hba.conf
```

Scroll to the bottom of the file. You will see a block that looks like:

```
# TYPE  DATABASE        USER            ADDRESS                 METHOD
local   all             all                                     peer
host    all             all             127.0.0.1/32            md5
host    all             all             ::1/128                 md5
```

Add **one new line** at the very bottom:

```
host    ev_analytics    capstone        0.0.0.0/0               md5
```

What this line means:
- `host` — a TCP/IP (network) connection
- `ev_analytics` — only this database (not everything on the server)
- `capstone` — only this user
- `0.0.0.0/0` — from any IP address (Google Colab's IP changes every session, so you cannot lock it to a specific address)
- `md5` — require a password

> **Security note:** `0.0.0.0/0` means anyone who knows the password and port can attempt to connect. This is acceptable for a short-lived student VM because: (a) the GCP firewall you set up next further restricts access, and (b) the VM should be **stopped when not in use**. Do not use `0.0.0.0/0` in a production system.

Save and exit: **Ctrl+O** → **Enter** → **Ctrl+X**.

### 3c. Restart PostgreSQL to apply both changes

```bash
sudo systemctl restart postgresql
sudo systemctl status postgresql
```

Confirm it shows `Active: active (running)`.

---

## 4. Open Port 5432 in the GCP Firewall

This is the most critical step. The VM has two layers of networking: the OS-level firewall (not used by default in Debian on GCP) and the **GCP VPC firewall**. The GCP firewall is what actually blocks external traffic, and you must explicitly open port 5432.

### 4a. Navigate to Firewall Rules

1. In the GCP Console left menu, go to **VPC network** → **Firewall**.
2. Click **Create Firewall Rule** at the top.

### 4b. Fill in the rule exactly

| Field | Value | Notes |
|---|---|---|
| **Name** | `allow-postgres-5432` | Lowercase, hyphens only |
| **Network** | `default` | The course project uses the default VPC |
| **Priority** | `1000` | Leave at default |
| **Direction of traffic** | `Ingress` | Incoming connections to your VM |
| **Action on match** | `Allow` | |
| **Targets** | `Specified target tags` | Do not select "All instances" |
| **Target tags** | `postgres-server` | You will assign this tag to your VM in the next step |
| **Source filter** | `IPv4 ranges` | |
| **Source IPv4 ranges** | `0.0.0.0/0` | See security note below |
| **Protocols and ports** | Select **Specified protocols and ports** → check **TCP** → enter `5432` | Port 5432 only — not a wide-open rule |

3. Leave everything else at default.
4. Click **Create**.

> **Why `0.0.0.0/0` here?** Google Colab notebooks run on dynamic GCP infrastructure. Their external IP changes every session and cannot be predicted in advance. The rule is still narrow because it only opens port 5432 (not all ports) and is further constrained to only VMs tagged `postgres-server`.

> **More secure alternative (optional):** Before you start your Colab session, run `!curl ifconfig.me` in a Colab cell to get its current IP. Then edit this firewall rule to use that specific IP (e.g., `34.86.5.112/32`) instead of `0.0.0.0/0`. This closes the hole to everyone else. You will need to update it each session since the IP changes.

### 4c. Assign the firewall tag to your VM

1. Go back to **Compute Engine** → **VM instances**.
2. Click on your VM's **name** (not the SSH button) to open its details page.
3. Click **Edit** at the top.
4. Scroll down to **Network tags**.
5. Type `postgres-server` in the tags field and press Enter so it appears as a tag chip.
6. Scroll to the bottom and click **Save**.

The firewall rule now applies specifically to your VM.

### 4d. Verify the port is reachable (from inside the VM)

Back in your VM's SSH terminal, check that PostgreSQL is actually listening on port 5432:

```bash
sudo ss -tlnp | grep 5432
```

You should see a line containing `0.0.0.0:5432`, confirming PostgreSQL is listening on all interfaces.

---

## 5. Find Your VM's External IP

1. Go to **Compute Engine** → **VM instances**.
2. Look at the **External IP** column for your VM.
3. Copy that IP address — you will paste it into your Colab notebook.

> **Note:** The external IP is **ephemeral** by default. It changes every time you stop and restart the VM. If this becomes inconvenient, you can reserve a static IP under **VPC network** → **IP addresses**, but that costs a small amount of money. For the capstone, just look it up each time you restart.

---

## 6. Connect to PostgreSQL from Google Colab

Open your team's Colab notebook and run the following cells.

### 6a. Install the Python PostgreSQL driver

```python
!pip install psycopg2-binary -q
```

### 6b. Set your connection parameters

```python
# Replace these values with your own
VM_EXTERNAL_IP = "34.X.X.X"   # The External IP from Step 5
DB_NAME        = "ev_analytics"
DB_USER        = "capstone"
DB_PASSWORD    = "yourpassword"   # The password you set in Step 2c
DB_PORT        = 5432
```

### 6c. Test the connection

```python
import psycopg2

conn = psycopg2.connect(
    host=DB_PASSWORD,
    dbname=DB_NAME,
    user=DB_USER,
    password=DB_PASSWORD,
    port=DB_PORT
)
print("Connected successfully!")
conn.close()
```

If you see `Connected successfully!` you are done with setup. If you get a timeout or connection refused error, work through the troubleshooting section at the end of this guide.

---

## 7. Create Tables and Write Data

This section mirrors what you did with SQLite, but now using PostgreSQL on your VM.

### 7a. Create a connection helper

```python
import psycopg2
import psycopg2.extras  # for execute_values (bulk inserts)
import pandas as pd

def get_conn():
    return psycopg2.connect(
        host=VM_EXTERNAL_IP,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        port=DB_PORT
    )
```

### 7b. Create tables

```python
create_tables_sql = """
CREATE TABLE IF NOT EXISTS station_locations (
    station_id      TEXT PRIMARY KEY,
    city            TEXT,
    state           TEXT,
    latitude        NUMERIC(9, 6),
    longitude       NUMERIC(9, 6),
    operator        TEXT
);

CREATE TABLE IF NOT EXISTS vehicle_types (
    vehicle_type_id TEXT PRIMARY KEY,
    make            TEXT,
    model           TEXT,
    year            INTEGER,
    battery_kwh     NUMERIC(6, 2)
);

CREATE TABLE IF NOT EXISTS charging_sessions (
    session_id          TEXT PRIMARY KEY,
    station_id          TEXT REFERENCES station_locations(station_id),
    vehicle_type_id     TEXT REFERENCES vehicle_types(vehicle_type_id),
    session_start       TIMESTAMP,
    session_end         TIMESTAMP,
    energy_kwh          NUMERIC(8, 3),
    peak_kw             NUMERIC(6, 2),
    cost_usd            NUMERIC(8, 2)
);

CREATE TABLE IF NOT EXISTS daily_demand_summary (
    summary_date        DATE,
    station_id          TEXT REFERENCES station_locations(station_id),
    total_sessions      INTEGER,
    total_energy_kwh    NUMERIC(10, 3),
    avg_peak_kw         NUMERIC(6, 2),
    PRIMARY KEY (summary_date, station_id)
);
"""

with get_conn() as conn:
    with conn.cursor() as cur:
        cur.execute(create_tables_sql)
    conn.commit()
    print("Tables created.")
```

### 7c. Load a CSV and insert rows into PostgreSQL

```python
# Load the stations CSV (already downloaded from GCS)
stations_df = pd.read_csv("data/station_locations.csv")

insert_sql = """
    INSERT INTO station_locations (station_id, city, state, latitude, longitude, operator)
    VALUES %s
    ON CONFLICT (station_id) DO NOTHING;
"""

rows = list(stations_df[["station_id", "city", "state",
                          "latitude", "longitude", "operator"]].itertuples(index=False, name=None))

with get_conn() as conn:
    with conn.cursor() as cur:
        psycopg2.extras.execute_values(cur, insert_sql, rows, page_size=500)
    conn.commit()
    print(f"Inserted {len(rows)} station rows.")
```

Repeat the same pattern for `vehicle_types` and `charging_sessions`.

### 7d. Run a SELECT query and load results into a DataFrame

```python
query = """
    SELECT
        sl.city,
        sl.state,
        COUNT(cs.session_id)            AS total_sessions,
        ROUND(SUM(cs.energy_kwh)::numeric, 2)  AS total_energy_kwh,
        ROUND(AVG(cs.cost_usd)::numeric, 2)     AS avg_cost_usd
    FROM charging_sessions cs
    JOIN station_locations sl ON cs.station_id = sl.station_id
    GROUP BY sl.city, sl.state
    ORDER BY total_energy_kwh DESC
    LIMIT 10;
"""

with get_conn() as conn:
    results_df = pd.read_sql(query, conn)

results_df
```

### 7e. Write a cleaned DataFrame back to PostgreSQL

```python
from sqlalchemy import create_engine

# SQLAlchemy connection string for PostgreSQL
engine = create_engine(
    f"postgresql+psycopg2://{DB_USER}:{DB_PASSWORD}@{VM_EXTERNAL_IP}:{DB_PORT}/{DB_NAME}"
)

# Example: write a cleaned DataFrame directly
cleaned_sessions_df.to_sql(
    "charging_sessions",
    engine,
    if_exists="append",   # use "replace" to drop and recreate the table
    index=False,
    method="multi",       # batches rows for better performance
    chunksize=500
)

print("DataFrame written to PostgreSQL.")
```

---

## 8. Key Differences: PostgreSQL vs. SQLite

| Topic | SQLite (previous approach) | PostgreSQL (this guide) |
|---|---|---|
| **Where it runs** | Inside your Colab session memory | On a persistent VM in the cloud |
| **Connection** | `sqlite3.connect("file.db")` | `psycopg2.connect(host=..., ...)` |
| **Data persists after Colab restarts?** | No — you re-download the `.db` each time | Yes — data lives on the VM disk |
| **Multiple users can write at once?** | No | Yes |
| **Data types** | Loose (stores most things as TEXT) | Strict (`NUMERIC`, `TIMESTAMP`, `DATE`, etc.) |
| **`ON CONFLICT` / upserts** | `INSERT OR IGNORE` | `INSERT ... ON CONFLICT DO NOTHING` |
| **Auto-increment primary key** | `INTEGER PRIMARY KEY` | `SERIAL PRIMARY KEY` or `BIGSERIAL` |
| **Casting** | Implicit | Explicit: `SUM(col)::numeric` |

---

## 9. Stopping the VM When You Are Done

**Always stop your VM when you are not actively using it.** An e2-micro running 24/7 for a month will consume course credits.

1. Go to **Compute Engine** → **VM instances**.
2. Check the box next to your VM.
3. Click **Stop** at the top (not Delete — you want to keep your data).
4. Confirm the stop.

When you come back, click **Start / Resume**. Wait for the green dot. Copy the **new External IP** (it changes on every start) and update `VM_EXTERNAL_IP` in your Colab notebook.

---

## 10. Troubleshooting

### `Connection timed out` or `Connection refused`

Work through this checklist in order:

1. **Is the VM running?** Check Compute Engine → VM instances. The dot must be green.
2. **Is the firewall rule applied?** Confirm the VM has the `postgres-server` network tag (VM details → Edit → Network tags) and that the `allow-postgres-5432` rule targets that tag.
3. **Is PostgreSQL listening on all interfaces?** SSH into the VM and run `sudo ss -tlnp | grep 5432`. You should see `0.0.0.0:5432`. If you only see `127.0.0.1:5432`, re-check your `listen_addresses = '*'` change in `postgresql.conf` and restart: `sudo systemctl restart postgresql`.
4. **Did you restart PostgreSQL after editing the config files?** `sudo systemctl restart postgresql`.
5. **Is the external IP correct?** Copy it fresh from the Console — it changes every VM restart.

### `FATAL: password authentication failed for user "capstone"`

- Re-check the password. It is case-sensitive.
- Re-set it inside the VM: `sudo -i -u postgres psql -c "ALTER USER capstone WITH PASSWORD 'newpassword';"`

### `FATAL: database "ev_analytics" does not exist`

- Re-check the database name (case-sensitive in some contexts).
- Verify from the VM: `sudo -i -u postgres psql -l` — this lists all databases.

### `psycopg2.OperationalError: could not connect to server`

- Make sure you installed `psycopg2-binary` (not just `psycopg2`) in Colab: `!pip install psycopg2-binary -q`.

---

## Quick Reference

| Task | Where / Command |
|---|---|
| Create VM | Console → Compute Engine → VM instances → Create Instance |
| SSH into VM | Console → Compute Engine → VM instances → SSH button |
| Install PostgreSQL | `sudo apt-get install -y postgresql postgresql-contrib` |
| Open config file | `sudo nano /etc/postgresql/15/main/postgresql.conf` |
| Open pg_hba file | `sudo nano /etc/postgresql/15/main/pg_hba.conf` |
| Restart PostgreSQL | `sudo systemctl restart postgresql` |
| Create firewall rule | Console → VPC network → Firewall → Create Firewall Rule |
| Find external IP | Console → Compute Engine → VM instances (External IP column) |
| Connect from Colab | `psycopg2.connect(host=IP, dbname=..., user=..., password=..., port=5432)` |
| Stop VM when done | Console → Compute Engine → VM instances → Stop |
