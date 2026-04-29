import groovy.transform.Field

// Définition de l'objet global pour stocker les métriques (évite le reset à 0)
@Field def metrics = [
    build: "0",
    test: "0",
    fail: "0",
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
                    // Correction des fins de ligne (Windows vs Linux) et permissions
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
                        // On compte les erreurs dans les rapports XML générés
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
                    
                    // Exécution des tests (ignore les échecs pour continuer le pipeline)
                    sh "./mvnw test -Dtest='!*IntegrationTests' -Dmaven.test.failure.ignore=true"
                    
                    // 1. Calcul du temps de build réel
                    metrics.build = ((System.currentTimeMillis() - start) / 1000).toString()
                    
                    // 2. Extraction robuste des tests via find et awk
                    def count = sh(script: "find target/surefire-reports/ -name '*.xml' -exec grep -l '<testcase' {} + | xargs grep -c '<testcase' | awk -F: '{sum += \$2} END {print sum}' || echo '0'", returnStdout: true).trim()
                    metrics.test = (count == "" || count == "null" || count == "0") ? "0" : count

                    // 3. Extraction des échecs (Failures)
                    def fails = sh(script: "find target/surefire-reports/ -name '*.xml' -exec grep -l '<failure' {} + | xargs grep -c '<failure' | awk -F: '{sum += \$2} END {print sum}' || echo '0'", returnStdout: true).trim()
                    metrics.fail = (fails == "" || fails == "null") ? "0" : fails
                    
                    echo "DEBUG: Capture terminée -> Build: ${metrics.build}s, Tests: ${metrics.test}"
                }
            }
        }

        stage('Docker Infrastructure') {
            steps {
                script {
                    sh "${env.DOCKER_CMD} up -d --build"
                    // Extraction de la taille réelle de l'image
                    def rawSize = sh(script: "docker images ${IMAGE_NAME} --format '{{.Size}}' | sed 's/MB//' | sed 's/GB/000/' || echo '0'", returnStdout: true).trim()
                    metrics.docker = rawSize
                }
            }
        }

        stage('Validation Healthcheck') {
            steps {
                script {
                    try {
                        echo "Attente du démarrage de l'application..."
                        sleep 30
                        // Détection dynamique du réseau docker
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
                // Création du dossier si inexistant
                sh "mkdir -p pipeline-data"

                def summary = """
                ====================================================
                📊 RÉSUMÉ DES MÉTRIQUES DU PIPELINE
                ====================================================
                ⏱️ Temps de Build    : ${metrics.build} secondes
                ✅ Tests trouvés     : ${metrics.test}
                ❌ Échecs Tests      : ${metrics.fail}
                ⚠️ Alertes Qualité   : ${metrics.quality}
                🐳 Taille Image      : ${metrics.docker} Mo
                💓 Status Health     : ${metrics.health}
                ====================================================
                """
                echo summary

                // Envoi des arguments au script de collecte (Ordre respecté pour ton CSV)
                // On passe les 7 arguments attendus par ton script collect_metrics.sh
                sh """
                    ./collect_metrics.sh \
                    '${metrics.build}' \
                    '${metrics.test}' \
                    '${metrics.fail}' \
                    '0' \
                    '0' \
                    '${metrics.docker}' \
                    '${metrics.health}'
                """

                echo "Dernière entrée dans le dataset :"
                sh "tail -n 1 pipeline-data/global_dataset.csv || echo 'Fichier CSV vide'"
            }
            archiveArtifacts artifacts: 'pipeline-data/*.csv', allowEmptyArchive: true
        }
    }
}