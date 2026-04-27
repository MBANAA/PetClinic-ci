#!/bin/bash

# Configuration explicite de l'application étudiée
APP_NAME="Spring-PetClinic"
OUTPUT_DIR="pipeline-data/runs/run-${BUILD_NUMBER}"
mkdir -p "$OUTPUT_DIR"

echo "📊 Collecte des métriques pour l'application : $APP_NAME"

# Ajout de l'identifiant dans le dataset global
# Cela permet de mélanger plusieurs applications plus tard si besoin
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
echo "${BUILD_NUMBER},${APP_NAME},${TIMESTAMP},${GIT_COMMIT},${COVERAGE},${FAILURES}" >> pipeline-data/global_dataset.csv