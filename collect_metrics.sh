#!/bin/bash

# --- Configuration ---
DATA_DIR="pipeline-data"
CSV_FILE="$DATA_DIR/petclinic_performance_dataset.csv"
mkdir -p "$DATA_DIR"

# --- 1. Enrichissement du Contexte (Métadonnées) ---
# Indispensable pour lier une performance à une version précise du code
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
COMMIT_ID=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

# --- 2. Nettoyage des Données (Data Sanitization) ---
# On s'assure que seules des valeurs numériques entrent dans le CSV (on retire 's', 'Mo', etc.)
sanitize() {
    echo "$1" | sed 's/[^0-9.]//g' | sed 's/^$/0/'
}

BUILD_TIME=$(sanitize "${1}")
TEST_TOTAL=$(sanitize "${2}")
TEST_FAIL=$(sanitize "${3}")
COVERAGE=$(sanitize "${4}")
QUALITY=$(sanitize "${5}")
DOCKER_SIZE=$(sanitize "${6}")
HEALTH_CODE=$(echo "${7:-000}" | tr -d '[:space:]')

# --- 3. Création de l'en-tête (Structure Professionnelle) ---
if [ ! -f "$CSV_FILE" ]; then
    echo "timestamp,commit_id,branch,build_time_sec,tests_total,tests_failed,coverage_pct,quality_alerts,image_size_mb,health_status" > "$CSV_FILE"
fi

# --- 4. Écriture Atomique ---
# On construit la ligne dans une variable pour éviter les écritures partielles
NEW_ENTRY="$TIMESTAMP,$COMMIT_ID,$BRANCH_NAME,$BUILD_TIME,$TEST_TOTAL,$TEST_FAIL,$COVERAGE,$QUALITY,$DOCKER_SIZE,$HEALTH_CODE"

# Utilisation d'un verrouillage (lock) si plusieurs builds tournent en même temps
exec 200>>"$CSV_FILE.lock"
flock -x 200

echo "$NEW_ENTRY" >> "$CSV_FILE"

flock -u 200
# --- ------------------- ---

echo "✅ Dataset mis à jour avec le commit $COMMIT_ID (Status: $HEALTH_CODE)"