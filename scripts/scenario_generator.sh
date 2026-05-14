#!/bin/bash
# scripts/scenario_generator.sh

SCENARIO=$((RANDOM % 100))
echo "🎲 Tirage au sort du scénario : $SCENARIO"

if [ $SCENARIO -lt 20 ]; then
    echo "⚠️ FAIL : Erreur de Test (Logiciel)"
    echo 'package org.springframework.samples.petclinic; import org.junit.jupiter.api.Test; import static org.junit.jupiter.api.Assertions.fail; class InjectedFailTest { @Test void forceFail() { fail("Anomalie injectée pour IA"); } }' > src/test/java/org/springframework/samples/petclinic/InjectedFailTest.java

elif [ $SCENARIO -lt 40 ]; then
    echo "🔥 FAIL : Surcharge CPU (Infrastructure)"
    timeout 120s sha512sum /dev/zero &

elif [ $SCENARIO -lt 55 ]; then
    echo "🌐 FAIL : Problème Réseau/Wrapper (Permissions)"
    chmod -x mvnw

elif [ $SCENARIO -lt 70 ]; then
    echo "🐳 FAIL : Conflit de Port Docker (Infrastructure)"
    docker run -d --name port-blocker -p 8080:80 nginx || true

else
    echo "✅ SUCCÈS : Build Nominal"
fi