#!/bin/bash

# Configuration
DATA_DIR="pipeline-data"
CSV_FILE="$DATA_DIR/global_dataset.csv"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')

mkdir -p "$DATA_DIR"

# Récupération des 12 arguments (Date + 11 variables)
BUILD_ID=${1:-0}
BRANCH=${2:-"main"}
COMMIT=${3:-"none"}
LOC=${4:-0}
BUILD_TIME=${5:-0}
TEST_TOTAL=${6:-0}
TEST_FAIL=${7:-0}
COVERAGE=${8:-0}
QUALITY_ALERTS=${9:-0}
CRITICAL_VULN=${10:-0}
DOCKER_SIZE=${11:-0}
HEALTH=${12:-000}

# Création de l'en-tête riche
if [ ! -f "$CSV_FILE" ]; then
    echo "timestamp,build_id,branch,commit,loc,build_time,tests_total,tests_failed,coverage,quality_alerts,critical_vuln,size_mb,health_code" > "$CSV_FILE"
fi

# Ajout de la ligne formatée
echo "$TIMESTAMP,$BUILD_ID,$BRANCH,$COMMIT,$LOC,$BUILD_TIME,$TEST_TOTAL,$TEST_FAIL,$COVERAGE,$QUALITY_ALERTS,$CRITICAL_VULN,$DOCKER_SIZE,$HEALTH" >> "$CSV_FILE"

echo "✅ Dataset enrichi mis à jour (Build #$BUILD_ID - LoC: $LOC)"