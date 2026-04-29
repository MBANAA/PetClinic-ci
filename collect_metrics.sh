#!/bin/bash

# Configuration
DATA_DIR="pipeline-data"
CSV_FILE="$DATA_DIR/global_dataset.csv"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')

# Création du dossier
mkdir -p "$DATA_DIR"

# Récupération des arguments
BUILD_TIME=${1:-0}
TEST_TOTAL=${2:-0}
TEST_FAIL=${3:-0}
COVERAGE=${4:-0}
QUALITY=${5:-0}
DOCKER_SIZE=${6:-0}
HEALTH=${7:-000}

# Création de l'en-tête si le fichier n'existe pas
if [ ! -f "$CSV_FILE" ]; then
    echo "timestamp,build_time,tests_total,tests_failed,coverage,quality,size,health" > "$CSV_FILE"
fi

# Ajout de la ligne (SANS guillemets complexes pour éviter l'erreur EOF)
echo "$TIMESTAMP,$BUILD_TIME,$TEST_TOTAL,$TEST_FAIL,$COVERAGE,$QUALITY,$DOCKER_SIZE,$HEALTH" >> "$CSV_FILE"

echo "Donnees ajoutees au dataset avec succes."