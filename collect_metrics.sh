#!/bin/bash

# Configuration des fichiers
OUTPUT_DIR="pipeline-data/runs/run-${BUILD_NUMBER}"
mkdir -p "$OUTPUT_DIR"
CSV_FILE="pipeline-data/global_dataset.csv"

# Initialisation de l'en-tête si le fichier n'existe pas
if [ ! -f "$CSV_FILE" ]; then
    echo "BuildID,AppName,Timestamp,Commit,ST_Build,ST_Test,ST_Quality,ST_Docker,ST_Health,Coverage,Failures" > "$CSV_FILE"
fi

# Récupération des statuts (Arguments $1 à $5)
# On utilise une valeur par défaut "NOT_STARTED" si l'argument est vide
B_ST=${1:-"NOT_STARTED"}
T_ST=${2:-"NOT_STARTED"}
Q_ST=${3:-"NOT_STARTED"}
D_ST=${4:-"NOT_STARTED"}
H_ST=${5:-"NOT_STARTED"}

# Extraction des données réelles (Phase 1 - Dataset de valeur)
if [ -f "target/site/jacoco/jacoco.xml" ]; then
    COVERAGE=$(grep -oP 'instructions.*?covered="\K[^"]+' target/site/jacoco/jacoco.xml | head -1)
else
    COVERAGE="0"
fi

if [ -d "target/surefire-reports" ]; then
    TEST_FAIL=$(grep -r "<failure" target/surefire-reports/*.xml 2>/dev/null | wc -l)
else
    TEST_FAIL="0"
fi

TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
APP_NAME="Spring-PetClinic"

# Écriture de la ligne de données
echo "${BUILD_NUMBER},${APP_NAME},${TIMESTAMP},${GIT_COMMIT},${B_ST},${T_ST},${Q_ST},${D_ST},${H_ST},${COVERAGE},${TEST_FAIL}" >> "$CSV_FILE"

echo "📊 [DATASET] Métriques enregistrées : Build=${B_ST}, Tests=${T_ST}, Coverage=${COVERAGE}%"