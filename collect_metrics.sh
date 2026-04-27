#!/bin/bash

# --- CONFIGURATION ---
OUTPUT_DIR="pipeline-data/runs/run-${BUILD_NUMBER}"
mkdir -p "$OUTPUT_DIR"
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)

# Récupération des arguments envoyés par Jenkins
# Usage: ./collect_metrics.sh [Status_Build] [Status_Test] [Status_Quality] [Status_Docker] [Status_Health]
ST_BUILD=${1:-"UNKNOWN"}
ST_TEST=${2:-"UNKNOWN"}
ST_QUALITY=${3:-"UNKNOWN"}
ST_DOCKER=${4:-"UNKNOWN"}
ST_HEALTH=${5:-"UNKNOWN"}

# --- EXTRACTION DES MÉTRIQUES TECHNIQUES ---
# On analyse les fichiers pour voir s'ils sont vides ou absents
[ -s "target/site/jacoco/jacoco.xml" ] && VAL_JACOCO="PRESENT" || VAL_JACOCO="MISSING"
[ -d "target/surefire-reports" ] && VAL_TESTS="PRESENT" || VAL_TESTS="MISSING"

# --- MÉTRIQUES INFRASTRUCTURE ---
MEM_USAGE=$(free | grep Mem | awk '{print $3/$2 * 100.0}')
CPU_IDLE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')

# --- CONSTRUCTION DU VECTEUR DE RÉPONSE ---
# Format : BuildID, Date, Commit, Build_Status, Test_Status, Qual_Status, Docker_Status, Health_Status, Jacoco_File, Test_File, Mem%, Cpu%
echo "${BUILD_NUMBER},${TIMESTAMP},${GIT_COMMIT},${ST_BUILD},${ST_TEST},${ST_QUALITY},${ST_DOCKER},${ST_HEALTH},${VAL_JACOCO},${VAL_TESTS},${MEM_USAGE},${CPU_IDLE}" >> pipeline-data/global_dataset.csv

echo "✅ Pipeline response recorded for all stages."AILURES}" >> pipeline-data/global_dataset.csv