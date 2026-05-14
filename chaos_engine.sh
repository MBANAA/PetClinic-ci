#!/bin/bash
mkdir -p scripts
SCENARIO=$((RANDOM % 5))

# Nettoyage
pkill -f "stress-ng" || true
git checkout src/main/java/org/springframework/samples/petclinic/owner/Owner.java || true

case $SCENARIO in
    0) echo "SCENARIO: HEALTHY" ;;
    1) (stress-ng --cpu 2 --cpu-load 80 --timeout 600s &) ;;
    2) (stress-ng --vm 1 --vm-bytes 1G --timeout 600s &) ;;
    3) sed -i 's/return "owners\/createOrUpdateOwnerForm";/return null;/g' src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java ;;
    4) echo "SCENARIO: NETWORK_LATENCY" ;;
esac