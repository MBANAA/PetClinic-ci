import groovy.transform.Field

@Field def metrics = [
    build: "0", test: "0", fail: "0", 
    coverage: "0", quality: "0", docker: "0", health: "0"
]

pipeline {
    agent any
    environment {
        MAVEN_OPTS = '-Dspring.docker.compose.skip.in-tests=true'
        IMAGE_NAME = 'petclinic-app'
    }

    stages {
        stage('Initialisation') {
            steps {
                script {
                    sh 'sed -i "s/\\r//" mvnw *.sh || true'
                    sh 'chmod +x mvnw collect_metrics.sh'
                    sh './mvnw clean'
                }
            }
        }

        stage('Qualité & Sécurité Code') {
            steps {
                script {
                    // Checkstyle + Spotbugs
                    sh './mvnw checkstyle:check spotbugs:check || true'
                    metrics.quality = sh(script: "grep -r '<error' target/*.xml 2>/dev/null | wc -l || echo '0'", returnStdout: true).trim()
                }
            }
        }

        stage('Build & Tests avec Couverture') {
            steps {
                script {
                    def start = System.currentTimeMillis()
                    // Exécution avec JaCoCo pour la couverture
                    sh "./mvnw test jacoco:report -Dmaven.test.failure.ignore=true"
                    
                    metrics.build = ((System.currentTimeMillis() - start) / 1000).toString()
                    
                    // Extraction Tests & Fails
                    metrics.test = sh(script: "find target/surefire-reports/ -name '*.xml' -exec grep -c '<testcase' {} + | awk '{s+=\$1} END {print s}' || echo '0'", returnStdout: true).trim()
                    metrics.fail = sh(script: "find target/surefire-reports/ -name '*.xml' -exec grep -c '<failure' {} + | awk '{s+=\$1} END {print s}' || echo '0'", returnStdout: true).trim()
                    
                    // Extraction Couverture % (via jacoco.csv)
                    def cov = sh(script: "if [ -f target/site/jacoco/jacoco.csv ]; then tail -n +2 target/site/jacoco/jacoco.csv | awk -F, '{instructions += \$4 + \$5; covered += \$5} END {print int(covered/instructions*100)}'; else echo '0'; fi", returnStdout: true).trim()
                    metrics.coverage = cov ?: "0"
                }
            }
        }

        stage('Sécurité Docker (Trivy)') {
            steps {
                script {
                    sh "docker compose build"
                    // Scan de l'image pour les vulnérabilités critiques
                    def trivyCount = sh(script: "docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image --severity CRITICAL --quiet --format json ${IMAGE_NAME} | grep -o 'VulnerabilityID' | wc -l || echo '0'", returnStdout: true).trim()
                    // On peut ajouter ces vulnérabilités aux alertes qualité
                    metrics.quality = (metrics.quality.toInteger() + trivyCount.toInteger()).toString()
                }
            }
        }

        stage('Déploiement & Health') {
            steps {
                script {
                    sh "docker compose up -d"
                    sleep 20
                    def response = sh(script: "docker run --network bridge curlimages/curl:latest -s -o /dev/null -w '%{http_code}' http://$(hostname -I | awk '{print \$1}'):8080 || echo '000'", returnStdout: true).trim()
                    metrics.health = response
                    
                    def size = sh(script: "docker images ${IMAGE_NAME} --format '{{.Size}}' | sed 's/MB//' || echo '0'", returnStdout: true).trim()
                    metrics.docker = size
                }
            }
        }
    }

    post {
        always {
            script {
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
                archiveArtifacts artifacts: 'pipeline-data/*.csv', allowEmptyArchive: true
            }
        }
    }
}