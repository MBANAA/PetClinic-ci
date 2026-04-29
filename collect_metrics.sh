#!/bin/bash

DATA_DIR="pipeline-data"
CSV_FILE="$DATA_DIR/global_dataset.csv"
DATE=$(date '+%Y-%m-%d_%H-%M-%S')

mkdir -p "$DATA_DIR"

# Récupération des 7 arguments envoyés par Jenkins
BUILD_TIME=$1
TEST_TOTAL=$2
TEST_FAIL=$3
COVERAGE=$4
QUALITY=$5
DOCKER_SIZE=$6
HEALTH=$7

# Création de l'en-tête si nécessaire
if [ ! -f "$CSV_FILE" ]; then
    echo "timestamp,build_time,tests,fails,coverage,quality,size,health" > "$CSV_FILE"
fi

# Écriture de la ligne
echo "$DATE,$BUILD_TIME,$TEST_TOTAL,$TEST_FAIL,$COVERAGE,$QUALITY,$DOCKER_SIZE,$HEALTH" >> "$CSV_FILE"