# DS2002 Capstone Project: EV Charging Station Analytics — Cloud Pipeline Edition

**University of Virginia | DS2002 Data Science Systems**
**Capstone Group Project — 4 Weeks**

---

## Background

In 2024, Charlottesville installed a network of public EV charging stations across the city and surrounding Albemarle County. Usage data started flowing immediately — session logs, station metadata, vehicle types, grid capacity readings — but the data is spread across multiple systems, riddled with quality issues, and sitting in flat files on a local drive. Nobody has cleaned it. Nobody has connected it to weather or energy price data. And the city transportation office is asking hard questions: Where should we add chargers next year? Are there demand surges we can predict? Is the grid keeping up?

Your team has been brought in as the city's data consultants. You have raw data, and you have questions that need answers. But this time, you are not working locally. Your data pipeline runs through **Google Cloud Storage**, and your cleaned data lives in a **SQLite database** that you manage in the cloud. This is the real-world pattern: messy data goes into cloud storage, gets cleaned and transformed, and lands in a queryable format for analysis.

**Read this entire brief before starting.** It is your roadmap for the next four weeks.

---

## Team Requirements

- **Group size:** 3-4 students
- **Duration:** 4 weeks
- **Language:** Python (all work must be in Python)
- **Environment:** Kaggle Notebook
- **Required libraries:** `pandas`, `matplotlib` and/or `seaborn`, `sqlite3`, `requests`, `google-cloud-storage`
- **Cloud services:** Google Cloud Storage (GCS) — provided via course GCP project

---

## Cloud Pipeline Architecture

Your capstone must follow this pipeline. Every team does the same pattern.

```
Kaggle Notebook
    |
    |-- google-cloud-storage (Python SDK)
    |
    v
GCS Bucket: ds2002-capstone-sp26
    |-- raw-data/              (instructor-provided, read-only for you)
    |   |-- charging_sessions.csv
    |   |-- station_locations.csv
    |   |-- vehicle_types.csv
    |   |-- grid_operators.csv
    |   |-- energy_and_demand.db
    |
    |-- team-XX/               (your team's workspace in the cloud)
    |   |-- cleaned_sessions.csv
    |   |-- cleaned_stations.csv
    |   |-- ev_analytics.db
    |   |-- (any other artifacts)
    |
    |-- Python ETL in your notebook (pandas)
    |
    v
SQLite Database (local or re-uploaded to GCS)
    |-- cleaned tables
    |-- joined/enriched tables
    |
    v
Analysis + Visualization (pandas, matplotlib, seaborn)
```

### What "Cloud" Means Here

1. Your raw data lives in a GCS bucket, not on your local machine.
2. You download it programmatically from GCS using Python — not by clicking a download button.
3. After cleaning, you upload your cleaned files back to your team folder in GCS.
4. You authenticate to GCS using a service account key provided to your team.

This is the same pattern used in production data pipelines at companies that process data at scale. The only difference is scale — you are working with thousands of rows instead of billions.

---

## Supplied Data Files

You are provided with **5 data files** in the `raw-data/` prefix of the GCS bucket (also available in the `data/` directory of this repository for local testing). All files contain **intentional data quality issues** that you must identify and fix.

| File | Format | Description | Approximate Size |
|------|--------|-------------|-----------------|
| `charging_sessions.csv` | CSV | Session-level charging transaction records across Charlottesville stations (Jan-Dec 2025) | ~27,000 rows |
| `station_locations.csv` | CSV | Charging station metadata (Charlottesville area) | ~21 rows |
| `vehicle_types.csv` | CSV | Vehicle and connector type reference list | ~42 rows |
| `grid_operators.csv` | CSV | Regional grid operator capacity and pricing | 5 rows |
| `energy_and_demand.db` | SQLite | Database with `daily_demand_summary` and `grid_capacity_levels` tables | ~8,400 rows total |

### Known Data Issues (You Must Discover and Fix These)

The data is messy on purpose. Expect problems such as:

- Duplicate records
- Missing values (empty strings, "NULL", "N/A", "NaN", "None")
- Inconsistent date/time formats across rows
- The same vehicle appearing under **multiple IDs and name variants** (this is your Pop-Tarts problem)
- Inconsistent capitalization and spacing in vehicle names, categories, and states
- Station ID format inconsistencies across files (dashes, underscores, no separator)
- Data type issues (dollar signs in numeric fields, tildes in capacity numbers)
- Negative kWh values (data entry errors)
- Missing latitude/longitude for some stations
- Inconsistent state abbreviations ("VA", "Va.", "Virginia", "virginia")
- Payment method inconsistencies (same method recorded different ways)

---

## Weather / Energy API Requirement

You **must** pull external data from a **free API** and integrate it into your analysis. This is not optional — Question 3 depends on it, and external context strengthens your other answers.

### Suggested Free APIs (Pick One or Both)

1. **Open-Meteo** — [https://open-meteo.com/](https://open-meteo.com/)
   - Completely free, no API key required
   - Historical weather data: temperature, precipitation, wind speed
   - Simple REST API, JSON responses
   - *Recommended for ease of use*

2. **EIA Open Data (U.S. Energy Information Administration)** — [https://www.eia.gov/opendata/](https://www.eia.gov/opendata/)
   - Free with API key registration
   - Electricity prices, generation mix, demand data by region
   - Useful for energy cost correlation

3. **OpenWeatherMap** — [https://openweathermap.org/api](https://openweathermap.org/api)
   - Free tier available
   - Historical weather data
   - Widely documented

### What You Must Demonstrate

- Python code that calls the API (using `requests`)
- Parsing the API response into a pandas DataFrame
- Joining external data with your charging/demand data
- Handling any timezone or date alignment issues

---

## Analytical Questions

Your notebook must answer all 5 questions below. Each answer should include **code, a visualization, and a written explanation** in markdown cells.

### Question 1: Demand Surge Identification

> Which time periods experienced the greatest charging demand surges compared to the baseline? Quantify the percentage increase in daily sessions and total kWh delivered for each surge period, and visualize the daily trend across the full year.

**Requires:** Cleaning session data (deduplication, fixing timestamps, removing bad rows), defining baseline vs. surge periods, grouping by date, line chart or bar chart of daily volume, percentage calculations.

---

### Question 2: The Vehicle Consolidation Problem

> After standardizing all vehicle ID variants into canonical vehicle names, what is the true daily charging volume by vehicle type? How does the uncleaned (fragmented) view compare to the cleaned (consolidated) view? What operational decisions would differ between the two views?

**Requires:** Building a vehicle ID mapping table, consolidating fragmented records, side-by-side visualization (before vs. after cleaning), written analysis of how fragmentation distorts the picture.

---

### Question 3: Weather and Grid Correlation

> Using weather data pulled from your chosen API, how do temperature extremes (heat waves, cold snaps) correlate with daily charging demand and grid load percentage? Is there a detectable lag between temperature spikes and charging surges?

**Requires:** API integration, date alignment, correlation analysis (scatter plot, heatmap, or time-series overlay), joining weather data with the `daily_demand_summary` and `grid_capacity_levels` tables, lag analysis discussion.

---

### Question 4: Station-Level Geographic Patterns

> Do all charging stations experience the same usage patterns, or do some stations consistently outperform others? Identify the top 5 and bottom 5 stations by total kWh delivered, and investigate whether geographic location (region, proximity to university, highway access) explains the differences.

**Requires:** Joining station location data with session data, geographic grouping, comparing usage across stations, bar chart or grouped comparison, outlier identification, written interpretation.

---

### Question 5: The Connector Type Investigation

> The data shows sessions across four connector types (CCS, CHAdeMO, J1772, Tesla Supercharger). Using the SQLite database tables, investigate whether connector type preferences are shifting over time. Is the CHAdeMO decline real, or is it a data artifact caused by vehicle ID fragmentation and missing connector records? Present your evidence and make a recommendation: should the city invest in more CHAdeMO ports or reallocate that budget to CCS?

**Requires:** Querying the SQLite database with `sqlite3` + `pandas`, cross-referencing with the session CSV, connector/vehicle audit, evidence-based written argument, supporting visualization.

---

## Cloud Deliverables

In addition to the analytical work, your team must demonstrate the cloud pipeline:

### Cloud Checkpoint (Required)

- Working GCS authentication from your Kaggle notebook
- Your team folder exists in the bucket and contains at least one uploaded file
- You can programmatically list, download, and upload files to your team folder
- Your cleaned data files are uploaded to your team folder in GCS

---

## Deliverables

### 1. Python Notebook

A single Kaggle notebook (`.ipynb`) containing:

- **Cloud Setup:** GCS authentication, downloading raw data from the bucket, uploading cleaned data to your team folder
- **Data Loading:** All CSVs loaded with pandas, SQLite queried with `sqlite3`, external API data pulled with `requests`
- **Data Cleaning Pipeline:** A clear section showing your wrangling steps (dedup, vehicle ID consolidation, timestamp fixes, missing value handling, type conversions)
- **Analysis:** All 5 questions answered with code, visualizations, and markdown explanations
- **Visualizations:** Minimum **6 plots** using `matplotlib`, `seaborn`, and/or `plotly`
- **Markdown Cells:** Explain your methodology, findings, and reasoning throughout

### 2. Reflection Write-Up

Included in your notebook (at the end) or as a separate markdown file. Each team member should contribute. Answer all 5 reflection questions below.

---

## Reflection Questions

Answer each question thoughtfully (one solid paragraph minimum per question).

**1. Data Quality Impact**
> Describe a specific data quality issue you found in the supplied data. How did your cleaning decision change the outcome of your analysis? What would have happened if you had skipped it?

**2. Cloud Pipeline Experience**
> What was the most confusing or frustrating part of working with GCS? What would you do differently if you had to set up a cloud pipeline from scratch? How does working with cloud storage compare to working with local files?

**3. ETL Trade-offs**
> You made choices about how to standardize vehicle IDs, handle missing timestamps, and join external API data. Pick one decision and explain: what alternative approach could you have taken, and how might it have changed your results?

**4. Pipeline Trust**
> Based on your experience in this project, what is the most fragile part of your data pipeline? If this pipeline had to run automatically every day, what would break first?

**5. Team Collaboration**
> How did your team divide the work? What would you do differently if you had another week? What was the most valuable skill each team member contributed?

---

## 4-Week Timeline

### Week 1: Cloud Setup, Data Ingestion, and Exploration

- Read this brief thoroughly
- Complete the GCP Console walkthrough and authenticate from Kaggle
- Create your team folder in the GCS bucket
- Download raw data from GCS programmatically
- Explore the data: `.shape`, `.dtypes`, `.info()`, `.describe()`, `.isnull().sum()`
- Identify all data quality issues
- Set up your external API: test calls, pull sample data
- **Milestone:** GCS auth working, raw data downloaded, initial data exploration complete

### Week 2: Cleaning and ETL

- Build your cleaning pipeline: dedup, standardize vehicle IDs, fix timestamps, normalize categories, handle missing values, fix data types
- Join external API data with your session/demand data
- Load cleaned data into SQLite
- Upload cleaned data to your GCS team folder
- **Milestone:** Clean DataFrames and SQLite database ready for analysis

### Week 3: Analysis and Visualization

- Answer Questions 1-5 using your cleaned data
- Query the SQLite database for Question 5
- Create all required visualizations (minimum 6 charts/plots)
- Write markdown explanations for each question
- **Milestone:** All 5 questions answered with supporting code, visuals, and written analysis

### Week 4: Polish, Present, and Submit

- Organize your notebook: clear section headers, clean code, no leftover debugging cells
- Write reflection responses (all 5 questions, every team member contributes)
- Prepare presentation (8 minutes per team)
- Peer review within your team
- Final run: Restart kernel and run all cells top-to-bottom
- **Milestone:** Final notebook submitted, presentation delivered

---

## Grading Rubric

| Component | Weight | What We're Looking For |
|-----------|--------|----------------------|
| **Cloud Pipeline** | 15% | Working GCS auth, programmatic upload/download, team folder with cleaned data, demonstrated cloud workflow in notebook |
| **Data Cleaning** | 20% | Thoroughness of cleaning pipeline; handling of duplicates, missing values, vehicle ID consolidation, type fixes; code clarity |
| **API Integration** | 10% | Working API calls, proper parsing, date alignment, meaningful join with charging/demand data |
| **Analytical Questions (1-5)** | 25% | Correct methodology, sound reasoning, clear answers supported by data |
| **Visualizations** | 15% | Minimum 6 plots; appropriate chart types; clear labels, titles, and legends; visual storytelling |
| **Reflection Write-Up** | 15% | Thoughtful, specific responses; demonstrates understanding of cloud pipelines, ETL trade-offs, and data pipeline risks |

---

## Important Notes

- **Do not fabricate data.** All external data must come from a real API call demonstrated in your notebook.
- **Show your work.** We want to see the messy data, your cleaning steps, and the clean result. Do not just show the final output.
- **Comment your code** where logic is non-obvious, but avoid narrating every line.
- **Cite your API source** and include the base URL you used.
- **Do not share your team's GCS service account key** outside your team. Treat it like a password.
- The supplied data is synthetic but designed to mirror patterns you would see in real municipal EV charging networks.

---

## Repository Structure

```
06-capstone/
  DS2002_Capstone_Project_Brief.md     <- You are here
  GCP_Console_Walkthrough.md           <- Cloud setup guide
  data/
    charging_sessions.csv              <- ~27,000 messy session records
    station_locations.csv              <- Station metadata
    vehicle_types.csv                  <- Vehicle/connector reference
    grid_operators.csv                 <- Grid operator info
    energy_and_demand.db               <- SQLite: daily_demand_summary + grid_capacity_levels
  setup_gcp_teams.sh                   <- Instructor-only: GCP provisioning script
  student_roster.csv                   <- Instructor-only: team roster template
```

Good luck. Charge up.
