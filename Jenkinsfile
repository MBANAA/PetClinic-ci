stage('🔍 Diagnostic Reseau Docker') {
            steps {
                sh '''
                    echo "=== 1. Contexte d'execution de l'agent ==="
                    if [ -f /.dockerenv ]; then
                        echo "L'agent Jenkins tourne DANS un conteneur."
                    else
                        echo "L'agent Jenkins tourne sur l'hote (pas de /.dockerenv)."
                    fi
                    hostname
                    echo ""

                    echo "=== 2. Reseaux Docker attaches a ce conteneur (si applicable) ==="
                    docker inspect $(hostname) --format '{{json .NetworkSettings.Networks}}' 2>/dev/null || echo "Impossible d'inspecter ce conteneur (agent non conteneurise ou hostname non resolu)."
                    echo ""

                    echo "=== 3. Passerelle du reseau bridge par defaut ==="
                    docker network inspect bridge --format '{{json .IPAM.Config}}' 2>/dev/null || echo "Reseau bridge introuvable."
                    echo ""

                    echo "=== 4. Test de resolution DNS de host.docker.internal ==="
                    getent hosts host.docker.internal 2>/dev/null || echo "host.docker.internal non resolu par DNS local."
                    echo ""

                    echo "=== 5. Demarrage d'un conteneur MySQL jetable pour tester la joignabilite ==="
                    docker run -d --rm -p 0:3306 --name diag-mysql -e MYSQL_ROOT_PASSWORD=test mysql:8.4 >/dev/null
                    echo "Attente du demarrage MySQL (10s)..."
                    sleep 10
                    PORT=$(docker port diag-mysql 3306/tcp | head -1 | cut -d: -f2)
                    echo "Port publie sur l'hote : $PORT"
                    echo ""

                    echo "=== 6. Test de connexion depuis 3 adresses candidates ==="
                    for HOST in "127.0.0.1" "host.docker.internal" "172.17.0.1"; do
                        echo "--- Test vers $HOST:$PORT ---"
                        timeout 5 bash -c "cat < /dev/null > /dev/tcp/$HOST/$PORT" 2>/dev/null \
                            && echo "OK : $HOST:$PORT est JOIGNABLE" \
                            || echo "ECHEC : $HOST:$PORT n'est PAS joignable"
                    done
                    echo ""

                    echo "=== 7. Nettoyage ==="
                    docker rm -f diag-mysql >/dev/null 2>&1 || true
                    echo "Termine."
                '''
            }
        }