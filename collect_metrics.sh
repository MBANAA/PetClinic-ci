#!/bin/bash

# --- CONFIGURATION ---
CSV_FILE="pipeline-data/global_dataset.csv"

# --- NOUVELLES MÉTRIQUES DE DIAGNOSTIC ---
# 1. Vérifier si Java est accessible
JAVA_VER=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2 || echo "NOT_FOUND")

# 2. Vérifier l'espace disque restant (en Go) sur la partition courante
DISK_SPACE=$(df -h . | tail -1 | awk '{print $4}')

# 3. Vérifier si le démon Docker répond
DOCKER_READY=$(docker ps >/dev/null 2>&1 && echo "READY" || echo "FAILED")

# 4. Vérifier si le Wrapper Maven existe
MVNW_READY=$([ -f "./mvnw" ] && echo "EXISTS" || echo "MISSING")

# --- RÉCUPÉRATION DES STATUTS JENKINS ---
B_ST=${1:-"SKIPPED"}
T_ST=${2:-"SKIPPED"}
Q_ST=${3:-"SKIPPED"}
D_ST=${4:-"SKIPPED"}
H_ST=${5:-"SKIPPED"}

# --- ÉCRITURE DANS LE CSV ---
# On ajoute les colonnes : Java_Ver, Disk, Docker_Status, Mvnw_Status
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
echo "${BUILD_NUMBER},${TIMESTAMP},${B_ST},${T_ST},${Q_ST},${D_ST},${H_ST},${JAVA_VER},${DISK_SPACE},${DOCKER_READY},${MVNW_READY}" >> "$CSV_FILE"

echo "🔍 DIAGNOSTIC : Java=$JAVA_VER | Disk=$DISK_SPACE | Docker=$DOCKER_READY | Mvnw=$MVNW_READY"