#!/bin/bash
# scripts/clean_env.sh

echo "🧹 Remise à zéro de l'environnement..."

# 1. Arrêt des pannes d'infrastructure
killall sha512sum 2>/dev/null || true

# 2. Suppression des conteneurs parasites (conflit de port)
docker rm -f port-blocker 2>/dev/null || true

# 3. Restauration des fichiers de code et droits
rm -f src/test/java/org/springframework/samples/petclinic/InjectedFailTest.java
chmod +x mvnw

# 4. Nettoyage Maven
./mvnw clean > /dev/null 2>&1

echo "✨ Environnement prêt."