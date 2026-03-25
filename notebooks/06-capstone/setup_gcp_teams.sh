#!/usr/bin/env bash
#
# DS2002 Capstone — GCP Team Provisioning Script
#
# INSTRUCTOR ONLY. Do not distribute to students.
#
# This script has two phases:
#   Phase 1: Create bucket, upload raw data, create service accounts + keys.
#            Run this BEFORE March 30. No student roster needed.
#
#   Phase 2: Add student Google emails to the project with scoped IAM roles.
#            Run this AFTER March 30, once you have the roster.
#
# Prerequisites:
#   - gcloud CLI installed and authenticated (gcloud auth login)
#   - You have Owner or Editor on the target GCP project
#   - The raw data files exist in ./data/
#
# Usage:
#   ./setup_gcp_teams.sh phase1
#   ./setup_gcp_teams.sh phase2
#
# -----------------------------------------------------------------------

set -euo pipefail

# -- CONFIGURATION (edit these) --
PROJECT_ID="YOUR_GCP_PROJECT_ID"          # <-- replace with your project ID
BUCKET_NAME="ds2002-capstone-sp26"
REGION="us-east1"
NUM_TEAMS=20
DATA_DIR="./data"
ROSTER_FILE="./student_roster.csv"
KEY_OUTPUT_DIR="./team-keys"

# -- PHASE 1 --
phase1() {
    echo "=== Phase 1: Bucket + Service Accounts ==="
    echo "Project: ${PROJECT_ID}"
    echo ""

    gcloud config set project "${PROJECT_ID}"

    # Create bucket
    echo "[1/5] Creating bucket gs://${BUCKET_NAME} ..."
    if gsutil ls -b "gs://${BUCKET_NAME}" 2>/dev/null; then
        echo "       Bucket already exists. Skipping."
    else
        gsutil mb -p "${PROJECT_ID}" -l "${REGION}" "gs://${BUCKET_NAME}"
    fi

    # Upload raw data
    echo "[2/5] Uploading raw data to gs://${BUCKET_NAME}/raw-data/ ..."
    gsutil -m cp "${DATA_DIR}/charging_sessions.csv" "gs://${BUCKET_NAME}/raw-data/"
    gsutil -m cp "${DATA_DIR}/station_locations.csv" "gs://${BUCKET_NAME}/raw-data/"
    gsutil -m cp "${DATA_DIR}/vehicle_types.csv" "gs://${BUCKET_NAME}/raw-data/"
    gsutil -m cp "${DATA_DIR}/grid_operators.csv" "gs://${BUCKET_NAME}/raw-data/"
    gsutil -m cp "${DATA_DIR}/energy_and_demand.db" "gs://${BUCKET_NAME}/raw-data/"

    # Create team folders (placeholder objects)
    echo "[3/5] Creating team folders ..."
    for i in $(seq -w 1 ${NUM_TEAMS}); do
        gsutil cp /dev/null "gs://${BUCKET_NAME}/team-${i}/.keep"
    done

    # Create service accounts + keys
    echo "[4/5] Creating ${NUM_TEAMS} service accounts ..."
    mkdir -p "${KEY_OUTPUT_DIR}"
    for i in $(seq -w 1 ${NUM_TEAMS}); do
        SA_NAME="ds2002-team-${i}"
        SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

        if gcloud iam service-accounts describe "${SA_EMAIL}" --project="${PROJECT_ID}" 2>/dev/null; then
            echo "       ${SA_NAME} already exists. Skipping creation."
        else
            gcloud iam service-accounts create "${SA_NAME}" \
                --project="${PROJECT_ID}" \
                --display-name="DS2002 Capstone Team ${i}"
        fi

        # Generate JSON key
        KEY_FILE="${KEY_OUTPUT_DIR}/${SA_NAME}-key.json"
        if [ -f "${KEY_FILE}" ]; then
            echo "       Key file for ${SA_NAME} already exists. Skipping."
        else
            gcloud iam service-accounts keys create "${KEY_FILE}" \
                --iam-account="${SA_EMAIL}" \
                --project="${PROJECT_ID}"
        fi
    done

    # Grant bucket access to all service accounts
    echo "[5/5] Granting storage.objectUser to each service account ..."
    for i in $(seq -w 1 ${NUM_TEAMS}); do
        SA_EMAIL="ds2002-team-${i}@${PROJECT_ID}.iam.gserviceaccount.com"
        gsutil iam ch "serviceAccount:${SA_EMAIL}:objectViewer" "gs://${BUCKET_NAME}"
        gsutil iam ch "serviceAccount:${SA_EMAIL}:objectCreator" "gs://${BUCKET_NAME}"
    done

    echo ""
    echo "=== Phase 1 Complete ==="
    echo "Bucket:       gs://${BUCKET_NAME}"
    echo "Raw data:     gs://${BUCKET_NAME}/raw-data/"
    echo "Team folders: gs://${BUCKET_NAME}/team-01/ through team-${NUM_TEAMS}/"
    echo "Keys:         ${KEY_OUTPUT_DIR}/"
    echo ""
    echo "Next steps:"
    echo "  1. Distribute one key file per team (securely — do not post publicly)."
    echo "  2. After teams form on March 30, fill in student_roster.csv and run:"
    echo "     ./setup_gcp_teams.sh phase2"
}

# -- PHASE 2 --
phase2() {
    echo "=== Phase 2: Add Student Emails to Project IAM ==="
    echo "Project: ${PROJECT_ID}"
    echo "Roster:  ${ROSTER_FILE}"
    echo ""

    if [ ! -f "${ROSTER_FILE}" ]; then
        echo "ERROR: ${ROSTER_FILE} not found."
        echo "Create it with columns: email,team"
        echo "Example:"
        echo "  abc1de@virginia.edu,team-01"
        echo "  xyz2fg@virginia.edu,team-01"
        exit 1
    fi

    gcloud config set project "${PROJECT_ID}"

    COUNT=0
    # Skip header row
    tail -n +2 "${ROSTER_FILE}" | while IFS=',' read -r email team; do
        # Trim whitespace
        email=$(echo "${email}" | xargs)
        team=$(echo "${team}" | xargs)

        if [ -z "${email}" ]; then
            continue
        fi

        echo "  Adding ${email} (${team}) ..."

        # Viewer role: lets them browse the Console
        gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
            --member="user:${email}" \
            --role="roles/viewer" \
            --condition=None \
            --quiet 2>/dev/null || true

        # Storage object access
        gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
            --member="user:${email}" \
            --role="roles/storage.objectUser" \
            --condition=None \
            --quiet 2>/dev/null || true

        COUNT=$((COUNT + 1))
    done

    echo ""
    echo "=== Phase 2 Complete ==="
    echo "Students added. They can now log into the GCP Console at:"
    echo "  https://console.cloud.google.com/?project=${PROJECT_ID}"
}

# -- MAIN --
case "${1:-}" in
    phase1) phase1 ;;
    phase2) phase2 ;;
    *)
        echo "Usage: $0 {phase1|phase2}"
        echo ""
        echo "  phase1  Create bucket, upload data, create service accounts + keys"
        echo "  phase2  Add student emails to project IAM (requires student_roster.csv)"
        exit 1
        ;;
esac
