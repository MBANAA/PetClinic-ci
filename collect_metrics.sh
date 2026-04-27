#!/bin/bash
# collect_metrics.sh

# Récupération des arguments numériques
BUILD_TIME=${1:-0}
TEST_TOTAL=${2:-0}
TEST_FAIL=${3:-0}
TEST_TIME=${4:-0}
COVERAGE=${5:-0}
IMAGE_SIZE=${6:-0}
HEALTH_CODE=${7:-0}

# Métriques système
DATE_NOW=$(date "+%Y-%m-%d_%H-%M-%S")
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//' || echo "0")
MEM_USED=$(command -v free >/dev/null && free -m | awk 'NR==2 {print $3}' || echo "0")
CPU_LOAD=$(command -v top >/dev/null && top -bn1 | grep "Cpu(s)" | awk '{print $2}' || echo "0")

# CSV Header (pour référence) : 
# Date, BuildTime, TestTotal, TestFail, TestTime, Coverage, ImgSize, Health, Disk, Mem, CPU
echo "${DATE_NOW},${BUILD_TIME},${TEST_TOTAL},${TEST_FAIL},${TEST_TIME},${COVERAGE},${IMAGE_SIZE},${HEALTH_CODE},${DISK_USAGE},${MEM_USED},${CPU_LOAD}" >> pipeline-data/global_dataset.csv