import groovy.transform.Field

@Field def metrics = [
    build: "0",
    test: "0",
    fail: "0",
    coverage: "0", // Ajouté
    quality: "0",
    docker: "0",
    health: "0"
]

pipeline {
    agent any

    environment {
        MAVEN_OPTS = '-Dspring.docker.compose.skip.in-tests=true'
        IMAGE_NAME = 'petclinic-app'
    }

    stages {
        stage('Nettoyage et Preparation') {
            steps {
                script {
                    sh 'sed -i "s/\\r//" mvnw collect_metrics.sh || true'
                    sh 'chmod +x mvnw collect_metrics.sh'
                    sh './mvnw clean'
                    env.DOCKER_CMD = sh(script: "docker compose version >/dev/null 2>&1 && echo 'docker compose' || echo 'docker-compose'", returnStdout: true).trim()
                }
            }
        }

        stage('Analyse Statique') {
            steps {
                script {
                    try {
                        sh './mvnw checkstyle:check spotbugs:check pmd:check || true'
                        def alerts = sh(script: "grep -r '<error' target/*.xml 2>/dev/null | wc -l || echo '0'", returnStdout: true).trim()
                        metrics.quality = alerts
                    } catch (e) {
                        metrics.quality = "-1"
                    }
                }
            }
        }

        stage('Build et Tests Unitaires') {
            steps {
                script {
                    def start = System.currentTimeMillis()
                    // Ajout de jacoco:report pour la couverture
                    sh "./mvnw test jacoco:report -Dtest='!*IntegrationTests' -Dmaven.test.failure.ignore=true"
                    
                    metrics.build = ((System.currentTimeMillis() - start) / 1000).toString()
                    
                    // Extraction Tests & Failures
                    metrics.test = sh(script: "find target/surefire-reports/ -name '*.xml' -exec grep -l '<testcase' {} + | xargs grep -c '<testcase' | awk -F: '{sum += \$2} END {print sum}' || echo '0'", returnStdout: true).trim()
                    metrics.fail = sh(script: "find target/surefire-reports/ -name '*.xml' -exec grep -l '<failure' {} + | xargs grep -c '<failure' | awk -F: '{sum += \$2} END {print sum}' || echo '0'", returnStdout: true).trim()
                    
                    // Extraction Couverture (%)
                    def cov = sh(script: "if [ -f target/site/jacoco/jacoco.csv ]; then tail -n +2 target/site/jacoco/jacoco.csv | awk -F, '{instructions += \$4 + \$5; covered += \$5} END {print int(covered/instructions*100)}'; else echo '0'; fi", returnStdout: true).trim()
                    metrics.coverage = cov ?: "0"
                }
            }
        }

  stage('Docker & Sécurité Scan') {
            steps {
                script {
                    sh "${env.DOCKER_CMD} up -d --build"
                    
                    // 1. On récupère l'ID de l'image associée au conteneur qui tourne
                    def imageId = sh(script: "docker ps --filter name=petclinic-app --format '{{.Image}}' | head -n 1", returnStdout: true).trim()
                    
                    if (imageId) {
                        // 2. Extraction de la taille avec l'ID trouvé
                        def rawSize = sh(script: "docker images ${imageId} --format '{{.Size}}' | sed 's/MB//g; s/GB/000/g' | head -n 1", returnStdout: true).trim()
                        metrics.docker = rawSize ?: "0"
                        
                        // 3. Scan Trivy avec l'ID (plus sûr que le nom)
                        def trivyCount = sh(script: "docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image --severity CRITICAL --quiet ${imageId} | grep 'Total: ' | grep -oE '[0-9]+' | head -n 1 || echo '0'", returnStdout: true).trim()
                        metrics.quality = (metrics.quality.toInteger() + (trivyCount ?: "0").toInteger()).toString()
                    } else {
                        echo "ATTENTION: Conteneur non trouvé, impossible de mesurer la taille."
                        metrics.docker = "0"
                    }
                }
            }
        }

        stage('Validation Healthcheck') {
            steps {
                script {
                    try {
                        sleep 30
                        def networkName = sh(script: "docker network ls --filter name=petclinic --format '{{.Name}}' | head -n 1", returnStdout: true).trim() ?: "bridge"
                        def response = sh(script: "docker run --network ${networkName} curlimages/curl:latest -s -o /dev/null -w '%{http_code}' http://petclinic-app:8080 || echo '000'", returnStdout: true).trim()
                        metrics.health = response
                    } catch (e) {
                        metrics.health = "500"
                    }
                }
            }
        }
    }

    post {
        always {
            script {
                sh "mkdir -p pipeline-data"
		sh "./collect_metrics.sh ${env.BUILD_ID} ${metrics.test} ${metrics.fail} ${metrics.coverage} ${metrics.quality} ${metrics.docker} ${metrics.health}"

                def summary = """
                ====================================================
                📊 RÉSUMÉ DES MÉTRIQUES DU PIPELINE
                ====================================================
                ⏱️ Temps de Build    : ${metrics.build} s
                ✅ Tests trouvés     : ${metrics.test}
                ❌ Échecs Tests      : ${metrics.fail}
                📈 Couverture Code   : ${metrics.coverage}%
                ⚠️ Alertes (Qual+Sec): ${metrics.quality}
                🐳 Taille Image      : ${metrics.docker} Mo
                💓 Status Health     : ${metrics.health}
                ====================================================
                """
                echo summary

                // Envoi des 7 arguments réels au script
                sh """
                    ./collect_metrics.sh \
                    '${metrics.build}' \
                    '${metrics.test}' \
                    '${metrics.fail}' \
                    '${metrics.coverage}' \
                    '${metrics.quality}' \
                    '${metrics.docker}' \
                    '${metrics.health}'
                """
            }
            archiveArtifacts artifacts: 'pipeline-data/*.csv', allowEmptyArchive: true
        }
    }
}