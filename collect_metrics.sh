#!/bin/bash

# --- CONFIGURATION ---
CSV_FILE="pipeline-data/global_dataset.csv"
mkdir -p pipeline-data

# --- MÉTRIQUES DE DIAGNOSTIC EXISTANTES ---
JAVA_VER=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2 || echo "NOT_FOUND")
DISK_SPACE=$(df -h . | tail -1 | awk '{print $4}')
DOCKER_READY=$(docker ps >/dev/null 2>&1 && echo "READY" || echo "FAILED")
MVNW_READY=$([ -f "./mvnw" ] && echo "EXISTS" || echo "MISSING")

# --- NOUVELLES MÉTRIQUES TECHNIQUES ---
# 1. RAM Disponible en Mo
RAM_FREE=$(free -m | awk '/^Mem:/{print $4}' || echo "0")

# 2. Charge Système (Load Average sur 1 min)
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | cut -d',' -f1 | xargs || echo "0")

# 3. Latence Réseau (Ping vers Google DNS en ms)
# Utile pour vérifier si Maven bloque à cause d'une connexion lente
NET_LATENCY=$(ping -c 1 8.8.8.8 | grep 'time=' | awk -F'time=' '{print $2}' | cut -d' ' -f1 || echo "0")

# 4. Nombre d'images Docker sur le serveur
# Permet de voir si le serveur s'encombre
DOCKER_IMG_COUNT=$(docker images -q | wc -l || echo "0")

# --- RÉCUPÉRATION DES STATUTS JENKINS ---
B_ST=${1:-"SKIPPED"}
T_ST=${2:-"SKIPPED"}
Q_ST=${3:-"SKIPPED"}
D_ST=${4:-"SKIPPED"}
H_ST=${5:-"SKIPPED"}

# --- ÉCRITURE DANS LE CSV ---
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)

# Nouvelle structure avec 15 colonnes
echo "${BUILD_NUMBER},${TIMESTAMP},${B_ST},${T_ST},${Q_ST},${D_ST},${H_ST},${JAVA_VER},${DISK_SPACE},${DOCKER_READY},${MVNW_READY},${RAM_FREE},${LOAD_AVG},${NET_LATENCY},${DOCKER_IMG_COUNT}" >> "$CSV_FILE"

echo "📊 METRIQUES : RAM=${RAM_FREE}MB | Load=${LOAD_AVG} | Ping=${NET_LATENCY}ms | Docker_Img=${DOCKER_IMG_COUNT}"