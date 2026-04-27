#!/bin/bash

# --- CONFIGURATION ---
CSV_FILE="pipeline-data/global_dataset.csv"
mkdir -p pipeline-data

# --- DIAGNOSTIC ---
JAVA_VER=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2 || echo "NOT_FOUND")
DISK_SPACE=$(df -h . | tail -1 | awk '{print $4}')
DOCKER_READY=$(docker ps >/dev/null 2>&1 && echo "READY" || echo "FAILED")
MVNW_READY=$([ -f "./mvnw" ] && echo "EXISTS" || echo "MISSING")

# --- PERFORMANCE (Sécurisée) ---
RAM_FREE=$(free -m | awk '/^Mem:/{print $4}' || echo "0")
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | cut -d',' -f1 | xargs || echo "0")

# Correction Latence : on ajoute un timeout et une valeur par défaut
NET_LATENCY=$(ping -c 1 -W 2 8.8.8.8 | grep 'time=' | awk -F'time=' '{print $2}' | cut -d' ' -f1)
if [ -z "$NET_LATENCY" ]; then NET_LATENCY="0"; fi

DOCKER_IMG_COUNT=$(docker images -q | wc -l || echo "0")

# --- STATUTS (Arguments passés par Jenkins) ---
B_ST=${1:-"ERROR"}
T_ST=${2:-"ERROR"}
Q_ST=${3:-"ERROR"}
D_ST=${4:-"ERROR"}
H_ST=${5:-"ERROR"}

# --- ÉCRITURE CSV ---
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
# Vérifie bien l'ordre ici : Build_ID, Timestamp, Statuts..., Métriques...
echo "${BUILD_NUMBER},${TIMESTAMP},${B_ST},${T_ST},${Q_ST},${D_ST},${H_ST},${JAVA_VER},${DISK_SPACE},${DOCKER_READY},${MVNW_READY},${RAM_FREE},${LOAD_AVG},${NET_LATENCY},${DOCKER_IMG_COUNT}" >> "$CSV_FILE"

echo "✅ Dataset mis à jour (Build $BUILD_NUMBER)"