#!/bin/bash

# Configuration
DATA_DIR="pipeline-data"
CSV_FILE="$DATA_DIR/global_dataset.csv"
DATE=$(date '+%Y-%m-%d_%H-%M-%S')

# Création du dossier si inexistant
mkdir -p "$DATA_DIR"

# Récupération des 7 arguments
BUILD_TIME=${1:-0}
TEST_TOTAL=${2:-0}
TEST_FAIL=${3:-0}
COVERAGE=${4:-0}
QUALITY_ALERTS=${5:-0}
DOCKER_SIZE=${6:-0}
HEALTH_STATUS=${7:-000}

# Création de l'en-tête si le fichier est nouveau
if [ ! -f "$CSV_FILE" ]; then
    echo "timestamp,build_duration_sec,tests_total,tests_failed,coverage_percent,quality_alerts,image_size_mb,health_code" > "$CSV_FILE"
fi

# Ajout de la ligne de données
echo "$DATE,$BUILD_TIME,$TEST_TOTAL,$TEST_FAIL,$COVERAGE,$QUALITY_ALERTS,$DOCKER_SIZE,$HEALTH_STATUS" >> "$CSV_FILE"

echo "-------------------------------------------------------"
echo "✅ Métriques enregistrées avec succès dans $CSV_FILE"
echo "📊 Récap : Build: ${BUILD_TIME}s | Tests: $TEST_TOTAL | Cov: ${COVERAGE}% | Status: $HEALTH_STATUS"
echo "-------------------------------------------------------"