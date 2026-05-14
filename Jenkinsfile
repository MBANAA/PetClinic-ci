pipeline {
    agent any

    environment {
        // Désactive Ryuk pour éviter les erreurs de connexion Docker
        TESTCONTAINERS_RYUK_DISABLED = 'true'
        IMAGE_NAME = 'petclinic-app'
    }

    stages {
        stage('Checkout & System Metrics') {
            steps {
                script {
                    env.START_TIME = System.currentTimeMillis().toString()
                    checkout scm
                    
                    // Nettoyage préventif
                    sh "docker compose down --remove-orphans || true"
                    sh "./mvnw clean"
                    
                    echo "Collecte des métriques système..."
                    sh "uptime"
                    sh "free -m"
                }
            }
        }

        stage('Build & Unit Tests') {
            steps {
                script {
                    // Ici on lance tout d'un coup : Clean + Test + Package
                    // Le flag -Dmaven.test.failure.ignore=true est crucial pour ton dataset
                    sh "./mvnw clean package jacoco:report -Dmaven.test.failure.ignore=true"
                }
            }
        }

        stage('Security Scan (Trivy)') {
            steps {
                script {
                    echo "Analyse de sécurité de l'image..."
                    // Scan direct après le build de l'image (si présente)
                    sh "docker build -t ${IMAGE_NAME} ."
                    sh "docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image --severity HIGH,CRITICAL ${IMAGE_NAME} || true"
                }
            }
        }

        stage('Deployment & Healthcheck') {
            steps {
                script {
                    sh "docker compose up -d"
                    echo "Stabilisation de l'application (45s)..."
                    sleep 45
                    
                    // Test de l'application
                    sh "curl -f http://localhost:8080/ || echo 'App non prête'"
                }
            }
        }

        stage('Collect Metrics') {
            steps {
                script {
                    // Calcul du temps total
                    def duration = (System.currentTimeMillis() - env.START_TIME.toLong()) / 1000
                    echo "Durée totale du build : ${duration}s"
                    
                    // Commande pour extraire les résultats des tests pour ton CSV
                    sh """
                        TOTAL=\$(find target/surefire-reports/ -name 'TEST-*.xml' | xargs grep -c '<testcase' | awk -F: '{sum += \$2} END {print sum}')
                        FAILED=\$(find target/surefire-reports/ -name 'TEST-*.xml' | xargs grep -c '<failure' | awk -F: '{sum += \$2} END {print sum}')
                        echo "Tests: \$TOTAL | Failed: \$FAILED"
                        
                        # Ton script de collecte ici
                        ./collect_metrics.sh ${env.BUILD_ID} main \$TOTAL \$FAILED ${duration}
                    """
                }
            }
        }
    }

    post {
        always {
            // Nettoyage final pour ne pas saturer le serveur
            sh "docker compose down || true"
            archiveArtifacts artifacts: 'target/*.jar, pipeline-data/*.csv', allowEmptyArchive: true
        }
    }
}