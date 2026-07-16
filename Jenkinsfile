pipeline {
    agent any

    triggers {
        cron('H/30 * * * *')
    }

    environment {
        IMAGE_NAME  = 'petclinic-app'
        DATASET_CSV = 'metrics_dataset.csv'
        TESTCONTAINERS_RYUK_DISABLED = 'true'
        TESTCONTAINERS_HOST_OVERRIDE = 'host.docker.internal'
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '20'))
        disableConcurrentBuilds()
        timestamps()
    }

    stages {

        stage('Init') {
            steps {
                script {
                    env.START_P = System.currentTimeMillis().toString()
                    env.CPU  = sh(script: "top -bn1 | grep 'Cpu(s)' | awk '{print 100 - \$8}' || echo 0", returnStdout: true).trim()
                    env.RAM  = sh(script: "free | grep Mem | awk '{print \$3/\$2 * 100.0}'", returnStdout: true).trim()
                    env.DISK = sh(script: "df / | tail -1 | awk '{print \$5}' | sed 's/%//'", returnStdout: true).trim()

                    sh "docker compose down -v || true"
                    sh "./mvnw -B clean"
                }
            }
        }

        stage('Diagnostic Reseau Docker') {
            steps {
                sh '''
                    echo "=== 1. Contexte d'execution de l'agent ==="
                    if [ -f /.dockerenv ]; then
                        echo "L'agent Jenkins tourne DANS un conteneur."
                    else
                        echo "L'agent Jenkins tourne sur l'hote."
                    fi
                    hostname

                    echo "=== 2. Reseaux Docker attaches a ce conteneur ==="
                    docker inspect $(hostname) --format '{{json .NetworkSettings.Networks}}' 2>/dev/null || echo "Impossible d'inspecter ce conteneur."

                    echo "=== 3. Passerelle du reseau bridge par defaut ==="
                    docker network inspect bridge --format '{{json .IPAM.Config}}' 2>/dev/null || echo "Reseau bridge introuvable."

                    echo "=== 4. Resolution DNS de host.docker.internal ==="
                    getent hosts host.docker.internal 2>/dev/null || echo "host.docker.internal non resolu."

                    echo "=== 5. Conteneur MySQL jetable pour test de joignabilite ==="
                    docker run -d --rm -p 0:3306 --name diag-mysql -e MYSQL_ROOT_PASSWORD=test mysql:8.4 >/dev/null
                    sleep 10
                    PORT=$(docker port diag-mysql 3306/tcp | head -1 | cut -d: -f2)
                    echo "Port publie sur l'hote : $PORT"

                    echo "=== 6. Test de connexion depuis 3 adresses candidates ==="
                    for HOST in "127.0.0.1" "host.docker.internal" "172.17.0.1"; do
                        echo "--- Test vers $HOST:$PORT ---"
                        timeout 5 bash -c "cat < /dev/null > /dev/tcp/$HOST/$PORT" 2>/dev/null \
                            && echo "OK : $HOST:$PORT JOIGNABLE" \
                            || echo "ECHEC : $HOST:$PORT injoignable"
                    done

                    docker rm -f diag-mysql >/dev/null 2>&1 || true
                '''
            }
        }

        stage('Tests Unitaires') {
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    sh "./mvnw -B test -Dtest='*Tests,!*IntegrationTests' -DfailIfNoTests=false -Dmaven.test.failure.ignore=true"
                }
                script {
                    env.F_UNIT = sh(script: "grep -ohE 'failures=\"[0-9]+\"|errors=\"[0-9]+\"' target/surefire-reports/*.xml 2>/dev/null | grep -o '[0-9]*' | awk '{s+=\$1} END {print s+0}'", returnStdout: true).trim()
                }
            }
        }

        stage('Tests Integration') {
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    sh "./mvnw -B test -Dtest='*IntegrationTests,!PostgresIntegrationTests' -Dspring.profiles.active=mysql -DfailIfNoTests=false -Dmaven.test.failure.ignore=true"
                }
                script {
                    env.F_IT = sh(script: "grep -ohE 'failures=\"[0-9]+\"|errors=\"[0-9]+\"' target/surefire-reports/*IntegrationTests.xml target/surefire-reports/*MySql*.xml 2>/dev/null | grep -o '[0-9]*' | awk '{s+=\$1} END {print s+0}'", returnStdout: true).trim()
                }
            }
        }

        stage('Build & Trivy') {
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    sh "docker build -t ${IMAGE_NAME} ."
                }
                script {
                    env.V_OS = sh(script: "docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy-cache:/root/.cache/ aquasec/trivy:latest image --severity HIGH,CRITICAL --format json --quiet ${IMAGE_NAME} 2>/dev/null | grep -o '\"VulnerabilityID\"' | wc -l", returnStdout: true).trim()
                }
            }
        }

        stage('Smoke Test') {
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    script {
                        sh "docker compose up -d --wait --wait-timeout 60 petclinic-mysql petclinic-app"
                        env.H_CODE = sh(script: "curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/ || echo 000", returnStdout: true).trim()
                        sh "docker compose down -v || true"
                    }
                }
            }
        }
    }

    post {
        always {
            script {
                junit testResults: 'target/surefire-reports/*.xml', allowEmptyResults: true

                sh "./mvnw -B checkstyle:check || true"
                def smells = '0'
                if (fileExists('target/checkstyle-result.xml')) {
                    smells = sh(script: "grep -c '<error' target/checkstyle-result.xml 2>/dev/null || echo 0", returnStdout: true).trim()
                }

                def total_t = (System.currentTimeMillis() - env.START_P.toLong()) / 1000
                def status  = currentBuild.currentResult ?: 'UNKNOWN'

                def row = [
                    env.BUILD_ID, total_t,
                    env.CPU ?: '0', env.RAM ?: '0', env.DISK ?: '0',
                    env.F_UNIT ?: '0', env.F_IT ?: '0', smells,
                    env.V_OS ?: '0', env.H_CODE ?: '000', status
                ].join(',')

                def header = 'build_id,duration_s,cpu_pct,ram_pct,disk_pct,fail_unit,fail_it,checkstyle_smells,vuln_high,http_code,build_status'

                if (!fileExists(env.DATASET_CSV)) {
                    writeFile file: env.DATASET_CSV, text: header + '\n'
                }
                sh "echo '${row}' >> ${env.DATASET_CSV}"
                archiveArtifacts artifacts: "${env.DATASET_CSV}", allowEmptyArchive: true
            }
        }
        cleanup {
            sh "docker compose down -v || true"
            sh "docker system prune -f --filter 'until=6h' || true"
        }
    }
}