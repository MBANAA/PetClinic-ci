#!/bin/bash

DATA_DIR="pipeline-data"
CSV_FILE="$DATA_DIR/global_dataset.csv"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')

mkdir -p "$DATA_DIR"

# Capture des 18 arguments envoyés par Jenkins
BUILD_ID=${1:-0}
BRANCH=${2:-"unknown"}
COMMIT=${3:-"none"}
AUTHOR=${4:-"unknown"}
FILES_CHANGED=${5:-0}
LOC=${6:-0}
BUILD_TIME=${7:-0}
TEST_TIME=${8:-0}
SYS_CPU=${9:-0}
SYS_RAM=${10:-0}
TEST_TOTAL=${11:-0}
TEST_FAIL=${12:-0}
TEST_SKIP=${13:-0}
COVERAGE=${14:-0}
SMELLS=${15:-0}
VULN_CRIT=${16:-0}
VULN_HIGH=${17:-0}
DOCKER_SIZE=${18:-0}
HEALTH=${19:-000}

# Création de l'en-tête Ultime pour le Machine Learning
if [ ! -f "$CSV_FILE" ]; then
    echo "timestamp,build_id,branch,commit,author,files_changed,loc,build_time_sec,test_time_sec,sys_cpu_load,sys_ram_free_mb,tests_total,tests_failed,tests_skipped,coverage_pct,code_smells,vuln_critical,vuln_high,docker_size_mb,health_code" > "$CSV_FILE"
fi

# Injection de la donnée (20 colonnes au total avec le timestamp)
echo "$TIMESTAMP,$BUILD_ID,$BRANCH,$COMMIT,$AUTHOR,$FILES_CHANGED,$LOC,$BUILD_TIME,$TEST_TIME,$SYS_CPU,$SYS_RAM,$TEST_TOTAL,$TEST_FAIL,$TEST_SKIP,$COVERAGE,$SMELLS,$VULN_CRIT,$VULN_HIGH,$DOCKER_SIZE,$HEALTH" >> "$CSV_FILE"

echo "✅ AIOps Dataset mis à jour avec succès (Build #$BUILD_ID)"