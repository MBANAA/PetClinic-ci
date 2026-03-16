pipeline {
    agent any

    tools {
        maven 'Maven3'
        jdk 'JDK17'
    }

    environment {
        // Fichiers pour ton dataset de thèse (Phase 1)
        DECISION_LOG = 'decision_points.log'
        METRICS_CSV = 'pipeline_metrics.csv'
    }

    stages {
        stage('Initialisation') {
            steps {
                sh 'java -version'
                // Préparation des fichiers de collecte de données
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
                        // CORRECTIF : On force l'initialisation des données SQL pour éviter l'erreur "Owner not found"
                        // On utilise 'clean package' pour générer le .jar nécessaire à Docker
                        sh 'mvn clean package -Dspring.sql.init.mode=always'
                        sh "echo 'DP-007,BUILD_AND_TEST,SUCCESS,CONTINUE' >> ${DECISION_LOG}"
                    } catch (Exception e) {
                        sh "echo 'DP-007,BUILD_AND_TEST,FAILURE,HALT' >> ${DECISION_LOG}"
                        error "Le build ou les tests ont échoué. Cause probable : Incohérence des données SQL ou erreur de compilation."
                    }
                }
            }
            post {
                always { 
                    // Collecte des rapports de tests pour ton analyse de qualité
                    junit '**/target/surefire-reports/*.xml' 
                }
            }
        }

        stage('Validate Docker Compose') {
            steps {
                // Utilisation de docker-compose (syntaxe V1/V2 compatible)
                sh 'docker-compose config'
                sh "echo 'DP-010,DOCKER_CONFIG,VALID,CONTINUE' >> ${DECISION_LOG}"
            }
        }

        stage('Run Docker Compose') {
            steps {
                script {
                    try {
                        // Nettoyage et relancement
                        sh 'docker-compose down || true'
                        sh 'docker-compose up -d --build'
                        sh "echo 'DP-009,DOCKER_RUN,SUCCESS,CONTINUE' >> ${DECISION_LOG}"
                    } catch (Exception e) {
                        sh "echo 'DP-009,DOCKER_RUN,FAILURE,HALT' >> ${DECISION_LOG}"
                        error "Impossible de lancer les conteneurs Docker."
                    }
                }
            }
        }

        stage('Check Application Health') {
            steps {
                script {
                    echo "Attente du démarrage de l'application (45s)..."
                    sleep 45 
                    
                    // On teste l'accès à la page d'accueil
                    // Note : localhost:8080 fonctionne si le conteneur expose le port sur l'hôte Jenkins
                    def response = sh(script: 'curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 || echo "000"', returnStdout: true).trim()
                    
                    if (response == "200") {
                        sh "echo 'DP-002,HEALTHCHECK,HTTP_200,DONE' >> ${DECISION_LOG}"
                        echo "L'application PetClinic est en ligne !"
                    } else {
                        sh "echo 'DP-002,HEALTHCHECK,HTTP_${response},WARNING' >> ${DECISION_LOG}"
                        echo "Attention : L'application répond avec le code ${response}. Vérifiez les logs Docker."
                        // On ne bloque pas forcément le pipeline ici pour pouvoir analyser le résultat
                    }
                }
            }
        }
    }

    // SECTION COLLECTE DE DONNÉES POUR LA THÈSE (Phase 1, Etape 5)
    post {
        always {
            script {
                def status = currentBuild.result ?: 'SUCCESS'
                def duration = currentBuild.duration / 1000
                
                // Mise à jour du dataset CSV
                sh """
                    if [ ! -f ${METRICS_CSV} ]; then
                        echo 'timestamp,run_id,status,duration_sec' > ${METRICS_CSV}
                    fi
                    echo '${new Date().format("yyyy-MM-dd HH:mm")},${BUILD_NUMBER},${status},${duration}' >> ${METRICS_CSV}
                """
                
                // Archivage des preuves pour ton "Ground Truth"
                archiveArtifacts artifacts: "${DECISION_LOG}, ${METRICS_CSV}", allowEmptyArchive: true
                
                echo "Données de build archivées pour l'analyse de Phase 1."
            }
        }
    }
}
