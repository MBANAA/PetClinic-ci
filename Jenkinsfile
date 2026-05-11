import groovy.transform.Field

@Field def metrics = [
    branch: "unknown",
    commit: "unknown",
    loc: "0",
    build: "0",
    test: "0",
    fail: "0",
    coverage: "0",
    quality: "0",    // Alertes Statiques (Checkstyle, etc.)
    critical: "0",   // Failles Trivy CRITICAL
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
        stage('Nettoyage et Contextualisation') {
            steps {
                script {
                    sh 'sed -i "s/\\r//" mvnw collect_metrics.sh || true'
                    sh 'chmod +x mvnw collect_metrics.sh'
                    sh './mvnw clean'
                    
                    // --- NOUVELLES MÉTRIQUES DE CONTEXTE ---
                    metrics.branch = env.BRANCH_NAME ?: "main"
                    metrics.commit = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                    metrics.loc = sh(script: "find src -name '*.java' | xargs wc -l | grep total | awk '{print \$1}' || echo '0'", returnStdout: true).trim()
                    
                    env.DOCKER_CMD = sh(script: "docker compose version >/dev/null 2>&1 && echo 'docker compose' || echo 'docker-compose'", returnStdout: true).trim()
                }
            }
        }

        stage('Analyse Statique') {
            steps {
                script {
                    try {
                        sh './mvnw checkstyle:check spotbugs:check pmd:check || true'
                        metrics.quality = sh(script: "grep -r '<error' target/*.xml 2>/dev/null | wc -l || echo '0'", returnStdout: true).trim()
                    } catch (e) { metrics.quality = "-1" }
                }
            }
        }

        stage('Build et Tests Unitaires') {
            steps {
                script {
                    def start = System.currentTimeMillis()
                    sh "./mvnw test jacoco:report -Dtest='!*IntegrationTests' -Dmaven.test.failure.ignore=true"
                    metrics.build = ((System.currentTimeMillis() - start) / 1000).toString()
                    
                    metrics.test = sh(script: "find target/surefire-reports/ -name '*.xml' -exec grep -l '<testcase' {} + | xargs grep -c '<testcase' | awk -F: '{sum += \$2} END {print sum}' || echo '0'", returnStdout: true).trim()
                    metrics.fail = sh(script: "find target/surefire-reports/ -name '*.xml' -exec grep -l '<failure' {} + | xargs grep -c '<failure' | awk -F: '{sum += \$2} END {print sum}' || echo '0'", returnStdout: true).trim()
                    
                    def cov = sh(script: "if [ -f target/site/jacoco/jacoco.csv ]; then tail -n +2 target/site/jacoco/jacoco.csv | awk -F, '{instructions += \$4 + \$5; covered += \$5} END {print int(covered/instructions*100)}'; else echo '0'; fi", returnStdout: true).trim()
                    metrics.coverage = cov ?: "0"
                }
            }
        }

        stage('Docker & Sécurité Scan') {
            steps {
                script {
                    sh "${env.DOCKER_CMD} up -d --build"
                    def imageId = sh(script: "docker ps --filter name=${IMAGE_NAME} --format '{{.Image}}' | head -n 1", returnStdout: true).trim()
                    
                    if (imageId) {
                        metrics.docker = sh(script: "docker images ${imageId} --format '{{.Size}}' | sed 's/MB//g; s/GB/000/g' | head -n 1", returnStdout: true).trim()
                        // Séparation des failles CRITIQUES
                        metrics.critical = sh(script: "docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image --severity CRITICAL --quiet ${imageId} | grep 'Total: ' | grep -oE '[0-9]+' | head -n 1 || echo '0'", returnStdout: true).trim()
                    }
                }
            }
        }

        stage('Validation Healthcheck') {
            steps {
                script {
                    try {
                        sleep 15
                        def networkName = sh(script: "docker network ls --filter name=petclinic --format '{{.Name}}' | head -n 1", returnStdout: true).trim() ?: "bridge"
                        metrics.health = sh(script: "docker run --network ${networkName} curlimages/curl:latest -s -o /dev/null -w '%{http_code}' http://petclinic-app:8080 || echo '000'", returnStdout: true).trim()
                    } catch (e) { metrics.health = "500" }
                }
            }
        }
    }

    post {
        always {
            script {
                sh "mkdir -p pipeline-data"
                // APPEL UNIQUE avec 11 paramètres pour un dataset riche
                sh "./collect_metrics.sh ${env.BUILD_ID} ${metrics.branch} ${metrics.commit} ${metrics.loc} ${metrics.build} ${metrics.test} ${metrics.fail} ${metrics.coverage} ${metrics.quality} ${metrics.critical} ${metrics.docker} ${metrics.health}"
            }
            archiveArtifacts artifacts: 'pipeline-data/*.csv', allowEmptyArchive: true
        }
    }
}