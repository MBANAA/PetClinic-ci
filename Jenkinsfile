pipeline {
    agent any

    tools {
        maven 'Maven3'
        jdk 'JDK17'
    }

    environment {
        // Fichiers pour ton dataset de thèse
        DECISION_LOG = 'decision_points.log'
        METRICS_CSV = 'pipeline_metrics.csv'
    }

    stages {
        stage('Initialisation') {
            steps {
                sh 'java -version'
                // On prépare les fichiers de logs
                sh "echo '--- Build No: ${BUILD_NUMBER} ---' > ${DECISION_LOG}"
                sh "echo 'DP-001,INITIALIZATION,SUCCESS,CONTINUE' >> ${DECISION_LOG}"
            }
        }

        stage('Clone Repository') {
            steps {
                git branch: 'main', url: 'https://github.com/MBANAA/PetClinic-ci.git'
                sh "echo 'DP-008,SCM_CLONE,SUCCESS,CONTINUE' >> ${DECISION_LOG}"
            }
        }

        stage('Build & Unit Tests') {
            steps {
                script {
                    try {
                        // IMPORTANT: On retire -DskipTests pour avoir des données de test !
                        sh 'mvn clean package'
                        sh "echo 'DP-007,BUILD_AND_TEST,SUCCESS,CONTINUE' >> ${DECISION_LOG}"
                    } catch (Exception e) {
                        sh "echo 'DP-007,BUILD_AND_TEST,FAILURE,HALT' >> ${DECISION_LOG}"
                        error "Le build ou les tests ont échoué."
                    }
                }
            }
            post {
                always { junit '**/target/surefire-reports/*.xml' }
            }
        }

        stage('Validate Docker Compose') {
            steps {
                // CORRECTION: Utilisation de 'docker-compose' (avec tiret)
                sh 'docker-compose config'
                sh "echo 'DP-010,DOCKER_CONFIG,VALID,CONTINUE' >> ${DECISION_LOG}"
            }
        }

        stage('Run Docker Compose') {
            steps {
                script {
                    try {
                        sh 'docker-compose down || true'
                        sh 'docker-compose up -d --build'
                        sh "echo 'DP-009,DOCKER_RUN,SUCCESS,CONTINUE' >> ${DECISION_LOG}"
                    } catch (Exception e) {
                        sh "echo 'DP-009,DOCKER_RUN,FAILURE,HALT' >> ${DECISION_LOG}"
                        error "Échec du lancement des conteneurs."
                    }
                }
            }
        }

        stage('Check Application') {
            steps {
                script {
                    sh 'sleep 30' // Temps pour que Spring Boot démarre vraiment
                    // On vérifie si l'app répond (Point de décision DP-002)
                    def response = sh(script: 'curl -s -o /dev/null -w "%{http_code}" http://localhost:8080', returnStdout: true).trim()
                    
                    if (response == "200") {
                        sh "echo 'DP-002,HEALTHCHECK,HTTP_200,DONE' >> ${DECISION_LOG}"
                        echo "L'application est en ligne !"
                    } else {
                        sh "echo 'DP-002,HEALTHCHECK,HTTP_${response},WARNING' >> ${DECISION_LOG}"
                        error "L'application répond avec l'erreur ${response}"
                    }
                }
            }
        }
    }

    // COLLECTE AUTOMATISÉE POUR LE DATASET (Phase 1, Etape 5)
    post {
        always {
            script {
                def status = currentBuild.result ?: 'SUCCESS'
                def duration = currentBuild.duration / 1000
                
                // On crée une ligne CSV pour ton futur dataset PhD
                sh """
                    if [ ! -f ${METRICS_CSV} ]; then
                        echo 'timestamp,run_id,status,duration' > ${METRICS_CSV}
                    fi
                    echo '${new Date().format("yyyy-MM-dd HH:mm")},${BUILD_NUMBER},${status},${duration}' >> ${METRICS_CSV}
                """
                
                // Archivage des fichiers pour ton analyse
                archiveArtifacts artifacts: "${DECISION_LOG}, ${METRICS_CSV}", allowEmptyArchive: true
                
                // Nettoyage pour éviter les conflits au prochain run
                // sh 'docker-compose down' // Optionnel si tu veux laisser l'app tourner
            }
        }
    }
}
