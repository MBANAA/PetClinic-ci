#!/bin/bash

# --- Configuration ---
DATA_DIR="pipeline-data"
CSV_FILE="$DATA_DIR/global_dataset.csv"
TIMESTAMP=$(date '+%Y-%m-%d_%H:%M:%S')

# Création du dossier de stockage si inexistant
mkdir -p "$DATA_DIR"

# --- Récupération des 7 arguments envoyés par Jenkins ---
# Syntaxe ${1:-0} : utilise l'argument 1, ou 0 par défaut si vide
BUILD_TIME=${1:-0}
TEST_TOTAL=${2:-0}
TEST_FAIL=${3:-0}
COVERAGE=${4:-0}
QUALITY_ALERTS=${5:-0}
DOCKER_SIZE=${6:-0}
HEALTH_STATUS=${7:-000}

# --- Gestion du fichier CSV ---

# 1. Si le fichier n'existe pas, on crée l'en-tête (Header)
if [ ! -f "$CSV_FILE" ]; then
    echo "timestamp,build_duration_sec,tests_total,tests_failed,coverage_percent,quality_alerts,image_size_mb,health_code" > "$CSV_FILE"
    echo "🆕 Nouveau fichier CSV créé : $CSV_FILE"
fi

# 2. Ajout de la ligne de données (Append)
echo "$TIMESTAMP,$BUILD_TIME,$TEST_TOTAL,$TEST_FAIL,$COVERAGE,$QUALITY_ALERTS,$DOCKER_SIZE,$HEALTH_STATUS" >> "$CSV_FILE"

# --- Affichage de confirmation dans les logs Jenkins ---
echo "-------------------------------------------------------"
echo "✅ Métriques enregistrées avec succès"
echo "📂 Fichier : $CSV_FILE"
echo "📝 Ligne ajoutée : $TIMESTAMP, Build: ${BUILD_TIME}s, Tests: $TEST_TOTAL, Health: $HEALTH_STATUS"
echo "-------------------------------------------------------"