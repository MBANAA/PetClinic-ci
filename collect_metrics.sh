#!/bin/bash

CSV_FILE="pipeline-data/global_dataset.csv"
mkdir -p pipeline-data

BUILD_NUMBER="${1:-UNKNOWN}"
ST_BUILD="${2:-NOT_RUN}"
ST_TEST="${3:-NOT_RUN}"
ST_QUALITY="${4:-NOT_RUN}"
ST_DOCKER="${5:-NOT_RUN}"
ST_HEALTH="${6:-NOT_RUN}"
DURATION_SEC="${7:-0}"
COVERAGE="${8:-NA}"

TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)

JAVA_VER=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2 || echo "NOT_FOUND")
DISK_SPACE=$(df -h . | tail -1 | awk '{print $4}')
DOCKER_READY=$(docker ps >/dev/null 2>&1 && echo "READY" || echo "FAILED")
MVNW_READY=$([ -f "./mvnw" ] && echo "EXISTS" || echo "MISSING")

# Créer l'en-tête si le fichier n'existe pas encore
if [ ! -f "$CSV_FILE" ]; then
  echo "build_number,timestamp,build_status,test_status,quality_status,docker_status,health_status,duration_sec,coverage_percent,java_version,disk_space,docker_ready,mvnw_ready" > "$CSV_FILE"
fi

echo "${BUILD_NUMBER},${TIMESTAMP},${ST_BUILD},${ST_TEST},${ST_QUALITY},${ST_DOCKER},${ST_HEALTH},${DURATION_SEC},${COVERAGE},${JAVA_VER},${DISK_SPACE},${DOCKER_READY},${MVNW_READY}" >> "$CSV_FILE"

echo "Métriques enregistrées : build=${BUILD_NUMBER}, build=${ST_BUILD}, test=${ST_TEST}, quality=${ST_QUALITY}, docker=${ST_DOCKER}, health=${ST_HEALTH}, duration=${DURATION_SEC}s, coverage=${COVERAGE}%"