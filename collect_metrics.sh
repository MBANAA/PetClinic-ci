#!/bin/bash

# Configuration
DATA_DIR="pipeline-data"
CSV_FILE="$DATA_DIR/global_dataset.csv"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')

mkdir -p "$DATA_DIR"

# Récupération des arguments (Le 1er est maintenant l'ID Jenkins)
BUILD_ID=${1:-0}
TEST_TOTAL=${2:-0}
TEST_FAIL=${3:-0}
COVERAGE=${4:-0}
QUALITY=${5:-0}
DOCKER_SIZE=${6:-0}
HEALTH=${7:-000}

# Création de l'en-tête avec build_id
if [ ! -f "$CSV_FILE" ]; then
    echo "timestamp,build_id,tests_total,tests_failed,coverage,quality,size,health" > "$CSV_FILE"
fi

# Ajout de la ligne
echo "$TIMESTAMP,$BUILD_ID,$TEST_TOTAL,$TEST_FAIL,$COVERAGE,$QUALITY,$DOCKER_SIZE,$HEALTH" >> "$CSV_FILE"

echo "✅ Données ajoutées (Build ID: $BUILD_ID)"