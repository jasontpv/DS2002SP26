# GCP Console Walkthrough — DS2002 Capstone

This guide walks you through the Google Cloud Platform tools you will use in the capstone. Keep it open as a reference. You will do most of your actual work from a Google Colab notebook using Python, but understanding the Console gives you visibility into what is happening on the cloud side.

---

## 1. Logging into the GCP Console

You have been granted access to the course GCP project using your UVA Google account.

1. Open your browser and go to [https://console.cloud.google.com](https://console.cloud.google.com).
2. Sign in with your **@virginia.edu** email (or whichever Google account your instructor registered).
3. After signing in, you should see the project selector in the top navigation bar. Click it and select the course project.

![GCP Console — Cloud Storage overview](console.png)

If you do not see the course project listed, contact your instructor. It means your email has not been added to the project IAM yet.

---

## 2. Navigating to Cloud Storage

Cloud Storage is where your raw data and team files live.

1. In the left sidebar (or the hamburger menu), click **Cloud Storage** > **Buckets**.
2. You should see a bucket named `ds2002-capstone-sp26`.
3. Click on the bucket name to open it.

![Bucket contents — raw-data and team folders](bucket.png)

Inside the bucket you will see:

```
ds2002-capstone-sp26/
  raw-data/                <- instructor-provided data (read these, do not modify)
    charging_sessions.csv
    station_locations.csv
    vehicle_types.csv
    grid_operators.csv
    energy_and_demand.db
  team-01/                 <- Team 01's workspace
  team-02/                 <- Team 02's workspace
  ...
  team-20/                 <- Team 20's workspace
```


**You can read anything in the bucket.** You can only write to your own team folder. If you try to delete or overwrite something in `raw-data/` or another team's folder, it will fail.

---

## 3. Understanding Your Access (IAM)

You have two types of access:

### Console Access (your UVA email)
- **Role: Viewer + Storage Object User**
- You can browse the Console, see the bucket, view files, and upload/download to your team folder.
- You cannot create or delete projects, spin up expensive services, or change IAM settings.
- You will not be charged for anything. The instructor's project credits cover all usage.

### Programmatic Access (your own Google account from Colab)
- You authenticate from your Colab notebook using the same `@virginia.edu` account.
- One line of code: `from google.colab import auth; auth.authenticate_user()`
- A Google sign-in window pops up. Sign in. Done.

Your UVA email is both your "badge to walk around the building" and the identity your code uses. No keys, no tokens, no extra tools.

---

## 4. Creating Your Team Folder

Your team folder already exists in the bucket (created by the setup script), but your first cloud task is to verify you can access it and upload a test file.

### From the Console (manual check)

1. Navigate to your team folder inside the bucket (e.g., `team-05/`).
2. You should see a `.keep` placeholder file.
3. Click **Upload Files** and upload any small text file to confirm write access works.

![Team folder in the bucket](bucket.png)

### From Your Colab Notebook (you will do this in the April 1 lab)

```python
from google.colab import auth
auth.authenticate_user()

from google.cloud import storage
client = storage.Client(project="ds2002sp26")
bucket = client.bucket("ds2002-capstone-sp26")

# List files in your team folder
blobs = list(bucket.list_blobs(prefix="team-05/"))
for b in blobs:
    print(b.name)
```

When you run `auth.authenticate_user()`, Colab will pop up a Google sign-in window. Sign in with your `@virginia.edu` account. That is it. No tokens, no CLI tools, no expiration to worry about.

---

## 6. Downloading Raw Data from GCS (Python)

Once authenticated, downloading files from the bucket is straightforward:

```python
import os

bucket = client.bucket("ds2002-capstone-sp26")

files_to_download = [
    "raw-data/charging_sessions.csv",
    "raw-data/station_locations.csv",
    "raw-data/vehicle_types.csv",
    "raw-data/grid_operators.csv",
    "raw-data/energy_and_demand.db",
]

os.makedirs("data", exist_ok=True)

for file_path in files_to_download:
    blob = bucket.blob(file_path)
    local_name = os.path.join("data", os.path.basename(file_path))
    blob.download_to_filename(local_name)
    print(f"Downloaded {file_path} -> {local_name}")
```

After this, you have local copies in your notebook environment and can work with them using pandas and sqlite3 as usual.

---

## 7. Uploading Cleaned Data to Your Team Folder

After your ETL is done:

```python
team_prefix = "team-05"

files_to_upload = [
    "cleaned_sessions.csv",
    "cleaned_stations.csv",
    "ev_analytics.db",
]

for filename in files_to_upload:
    blob = bucket.blob(f"{team_prefix}/{filename}")
    blob.upload_from_filename(filename)
    print(f"Uploaded {filename} -> gs://ds2002-capstone-sp26/{team_prefix}/{filename}")
```

---

## 8. Optional Extension: Spinning Up a VM

This section is **not required** for the capstone. It is here for students who want to go further.

The idea: instead of running SQLite locally in your notebook, you spin up a small cloud VM, copy your `.db` file there, and query it remotely. This is closer to how a production database works (compute and storage separated, database lives on a server).

### Steps (high-level)

1. In the Console, go to **Compute Engine** > **VM instances**.
2. Click **Create Instance**.
3. Choose:
   - **Name:** `ds2002-team-XX-vm`
   - **Region:** us-east1
   - **Machine type:** e2-micro (free tier eligible)
   - **Boot disk:** Debian GNU/Linux, 10 GB
4. Click **Create**.


5. Once the VM is running, click **SSH** to open a terminal in the browser.
6. In the SSH terminal:

```bash
sudo apt-get update && sudo apt-get install -y sqlite3
gsutil cp gs://ds2002-capstone-sp26/team-05/ev_analytics.db .
sqlite3 ev_analytics.db "SELECT COUNT(*) FROM daily_demand_summary;"
```

7. When you are done, **stop or delete the VM** to avoid unnecessary charges.

### Why this matters

In a real production environment, your database would not live inside a Jupyter notebook. It would live on a dedicated server (or a managed service like Cloud SQL or BigQuery). This exercise gives you a taste of that architecture.

### Cost warning

An e2-micro VM is free-tier eligible, but if you leave it running 24/7 for weeks it can accumulate charges. **Always stop or delete your VM when you are not using it.** The instructor's credits cover reasonable usage but not waste.

---

## Quick Reference

| Task | Where |
|------|-------|
| Browse bucket and files | Console > Cloud Storage > Buckets |
| Check your IAM roles | Console > IAM & Admin > IAM |
| Authenticate from Colab | `from google.colab import auth; auth.authenticate_user()` |
| Download a file | `bucket.blob("path").download_to_filename("local")` |
| Upload a file | `bucket.blob("path").upload_from_filename("local")` |
| List files in a folder | `bucket.list_blobs(prefix="team-XX/")` |
| Spin up a VM (optional) | Console > Compute Engine > VM instances |
