pipeline {
    agent any

    tools {
        maven 'Maven3'
        jdk 'JDK17'
    }

    environment {
        // Configuration pour la recherche (Phase 1)
        METRICS_FILE = 'pipeline_history.csv'
        LOG_FILE = 'decision.log'
    }

    stages {
        stage('Initialisation') {
            steps {
                sh 'java -version'
                // Nettoyage pour éviter les conflits de builds précédents
                sh 'mvn clean'
                sh 'docker compose down -v || true'
                sh "echo '--- Nouveau Build: ${BUILD_NUMBER} ---' > ${LOG_FILE}"
            }
        }

        stage('Clone Repository') {
            steps {
                git branch: 'main', url: 'https://github.com/MBANAA/PetClinic-ci.git'
            }
        }

        stage('Build & Compile') {
            steps {
                // Compilation seule pour valider la syntaxe
                sh 'mvn clean compile'
                sh "echo 'DP-001: Compilation Success' >> ${LOG_FILE}"
            }
        }

        stage('Unit Tests (H2 Isolation)') {
            steps {
                script {
                    try {
                        // LA CORRECTION : Utilisation de H2 pour éviter les erreurs de connexion DB
                        // Cela permet de valider la logique du code sans dépendre de Docker
                        sh 'mvn test -Dspring.profiles.active=h2'
                        sh "echo 'DP-004: Unit Tests Passed (H2 Profile)' >> ${LOG_FILE}"
                    } catch (Exception e) {
                        sh "echo 'DP-004: Unit Tests Failed' >> ${LOG_FILE}"
                        currentBuild.result = 'FAILURE'
                        error "Arrêt : Échec des tests unitaires."
                    }
                }
            }
            post {
                always {
                    junit '**/target/surefire-reports/*.xml'
                }
            }
        }

        stage('Static Analysis') {
            steps {
                // Analyse de la qualité du code (Phase 1.3 du guide)
                sh 'mvn checkstyle:check || true'
                sh "echo 'DP-005: Static Analysis Performed' >> ${LOG_FILE}"
            }
        }

        stage('Package Application') {
            steps {
                sh 'mvn package -DskipTests'
                sh "echo 'DP-008: JAR Packaging Success' >> ${LOG_FILE}"
            }
        }

        stage('Docker Deployment') {
            steps {
                // Validation et lancement de l'infrastructure
                sh 'docker compose config'
                sh 'docker compose up -d --build'
                sh "echo 'DP-009: Docker Infrastructure Ready' >> ${LOG_FILE}"
            }
        }

        stage('Healthcheck') {
            steps {
                script {
                    sh 'sleep 30' // Temps pour que MySQL/Postgres démarre dans Docker
                    def response = sh(script: "curl -s http://localhost:8080", returnStatus: true)
                    if (response == 0) {
                        sh "echo 'DP-002: Application Reachable' >> ${LOG_FILE}"
                    } else {
                        sh "echo 'DP-002: Application Unreachable' >> ${LOG_FILE}"
                        error "L'application n'a pas démarré correctement."
                    }
                }
            }
        }
    }

    // COLLECTE DES DONNÉES POUR LE DATASET IA (Phase 1 - Étape 5)
    post {
        always {
            script {
                def status = currentBuild.result ?: 'SUCCESS'
                def timestamp = new Date().format("yyyy-MM-dd'T'HH:mm:ss")
                // Création de la ligne CSV pour ta future analyse IA
                sh "echo '${timestamp},${BUILD_NUMBER},${status}' >> ${METRICS_FILE}"
                
                // Archivage des résultats pour ton dossier de thèse
                archiveArtifacts artifacts: "${LOG_FILE}, ${METRICS_FILE}, **/target/*.jar", allowEmptyArchive: true
            }
        }
    }
}