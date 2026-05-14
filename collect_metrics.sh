#!/bin/bash
CSV_FILE="pipeline-data/ultra_granular_dataset.csv"
mkdir -p pipeline-data

# Initialisation du Header complet
if [ ! -f "$CSV_FILE" ]; then
    echo "timestamp,build_id,total_t,context_t,logic_t,owner_t,vet_t,visit_t,it_mysql_t,scan_os_t,scan_app_t,scan_conf_t,cpu_load,ram_usage,disk_io,unit_fail,owner_f,vet_f,visit_f,it_mysql_f,smells,vuln_os,vuln_app,vuln_conf,h_code" > "$CSV_FILE"
fi

TIMESTAMP=$(date "+%Y-%m-%d_%H-%M-%S")
echo "$TIMESTAMP,$*" >> "$CSV_FILE"