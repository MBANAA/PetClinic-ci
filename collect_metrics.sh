#!/bin/bash

# Dossier où sera stocké le dataset
DATA_DIR="pipeline-data"
CSV_FILE="$DATA_DIR/global_dataset.csv"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')

mkdir -p "$DATA_DIR"

# Récupération des métriques depuis Jenkins
BUILD_TIME=${1:-0}
TEST_TOTAL=${2:-0}
TEST_FAIL=${3:-0}
COVERAGE=${4:-0}
QUALITY=${5:-0}
DOCKER_SIZE=${6:-0}
HEALTH=${7:-000}

# Création de l'en-tête seulement si le fichier est vide ou inexistant
if [ ! -f "$CSV_FILE" ]; then
    echo "timestamp,build_time,tests_total,tests_failed,coverage,quality_alerts,size_mb,health_code" > "$CSV_FILE"
fi

# AJOUT de la donnée (L'opérateur >> est crucial pour créer le dataset)
echo "$TIMESTAMP,$BUILD_TIME,$TEST_TOTAL,$TEST_FAIL,$COVERAGE,$QUALITY,$DOCKER_SIZE,$HEALTH" >> "$CSV_FILE"s: $TEST_TOTAL, Health: $HEALTH_STATUS"
echo "-------------------------------------------------------"