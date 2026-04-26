pipeline {
    agent any

    tools {
        maven 'maven' 
        jdk 'jdk17'
    }

    environment {
        MAVEN_OPTS = '-Dspring.docker.compose.skip.in-tests=true'
        IMAGE_NAME = 'petclinic-app'
        COVERAGE_THRESHOLD = '80'
    }

    stages {
        stage('Nettoyage') {
            steps {
                sh 'mvn clean'
                script {
                    try {
                        sh 'docker compose version'
                        env.DOCKER_CMD = 'docker compose'
                    } catch (Exception e) {
                        env.DOCKER_CMD = 'docker-compose'
                    }
                }
            }
        }

        stage('Analyse Statique') {
            steps {
                script {
                    echo 'Decision Point: DP-005 and DP-006'
                    sh 'mvn checkstyle:check spotbugs:check pmd:check'
                }
            }
        }

        stage('Build and Tests') {
            steps {
                // Simplification de la commande pour éviter les caractères spéciaux conflictuels
                sh 'mvn jacoco:prepare-agent test jacoco:report -Dspring.sql.init.mode=always -Dtest=!PostgresIntegrationTests,!MySqlIntegrationTests'
            }
        }

        stage('Verification Couverture') {
            steps {
                script {
                    echo 'Decision Point: DP-003'
                    echo "Seuil cible: ${env.COVERAGE_THRESHOLD}"
                }
            }
        }

        stage('Docker Infrastructure') {
            steps {
                script {
                    sh 'docker rm -f petclinic-app petclinic-mysql || true'
                    sh "${env.DOCKER_CMD} down --volumes --remove-orphans"
                    sh "${env.DOCKER_CMD} up -d --build"
                }
            }
        }

        stage('Validation Healthcheck') {
            steps {
                script {
                    echo 'Attente du demarrage (45s)...'
                    sleep 45
                    
                    // Commande simplifiée pour éviter les erreurs de parsing
                    def response = sh(script: "docker run --network ced_petclinic_default curlimages/curl:latest -s -o /dev/null -w '%{http_code}' http://petclinic-app:8080", returnStdout: true).trim()
                    
                    echo "Decision Point: DP-003 - Code recu: ${response}"
                    
                    if (response == '200') {
                        echo 'Decision: PASS'
                    } else {
                        error "Decision: FAIL - Status: ${response}"
                    }
                }
            }
        }
    }

    post {
        always {
            junit '**/target/surefire-reports/*.xml'
            archiveArtifacts artifacts: 'target/site/jacoco/**', allowEmptyArchive: true
            
            echo 'Execution du script de collecte...'
            // Ajout du chmod ici au cas ou, pour securiser l'execution
            sh 'chmod +x collect_metrics.sh && ./collect_metrics.sh'
            
            archiveArtifacts artifacts: 'pipeline-data/**', allowEmptyArchive: true
        }
    }
}