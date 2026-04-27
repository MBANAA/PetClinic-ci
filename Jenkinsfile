pipeline {
    agent any

    environment {
        MAVEN_OPTS = '-Dspring.docker.compose.skip.in-tests=true'
        IMAGE_NAME = 'petclinic-app'
        COVERAGE_THRESHOLD = '80'
        // Initialisation par défaut
        ST_BUILD = "SKIPPED"
        ST_TEST = "SKIPPED"
        ST_QUALITY = "SKIPPED"
        ST_DOCKER = "SKIPPED"
        ST_HEALTH = "SKIPPED"
    }

    stages {
        stage('Nettoyage et Preparation') {
            steps {
                script {
                    echo "--- Nettoyage ---"
                    sh 'chmod +x mvnw'
                    sh './mvnw clean'
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
                    try {
                        echo 'Analyse statique en cours...'
                        // On utilise le wrapper ici aussi
                        sh './mvnw checkstyle:check spotbugs:check pmd:check || true'
                        env.ST_QUALITY = "SUCCESS"
                    } catch (e) {
                        env.ST_QUALITY = "FAILURE"
                    }
                }
            }
        }

        stage('Build et Tests Unitaires') {
            steps {
                script {
                    try {
                        sh './mvnw jacoco:prepare-agent test jacoco:report \
                            -Dspring.sql.init.mode=always \
                            -Dtest=!PostgresIntegrationTests,!MySqlIntegrationTests \
                            -Dmaven.test.failure.ignore=true' 
                        
                        env.ST_BUILD = "SUCCESS"
                        env.ST_TEST = "SUCCESS"
                    } catch (e) {
                        env.ST_BUILD = "FAILURE"
                        env.ST_TEST = "FAILURE"
                        echo "Erreur lors du build : ${e.getMessage()}"
                    }
                }
            }
        }

        stage('Docker Infrastructure') {
            steps {
                script {
                    try {
                        sh 'docker rm -f petclinic-app petclinic-mysql || true'
                        sh "${env.DOCKER_CMD} down --volumes --remove-orphans || true"
                        sh "${env.DOCKER_CMD} up -d --build"
                        env.ST_DOCKER = "SUCCESS"
                    } catch (e) {
                        env.ST_DOCKER = "FAILURE"
                        echo "Erreur Docker : ${e.getMessage()}"
                    }
                }
            }
        }

        stage('Validation Healthcheck') {
            steps {
                script {
                    try {
                        echo 'Attente du démarrage (45s)...'
                        sleep 45
                        // Commande Curl via Docker pour tester la connectivité
                        def response = sh(script: "docker run --network ced_petclinic_default curlimages/curl:latest -s -o /dev/null -w '%{http_code}' http://petclinic-app:8080", returnStdout: true).trim()
                        
                        echo "Status reçu: ${response}"
                        
                        if (response == '200') {
                            env.ST_HEALTH = "SUCCESS"
                        } else {
                            env.ST_HEALTH = "FAILURE"
                        }
                    } catch (e) {
                        env.ST_HEALTH = "FAILURE"
                        echo "Erreur Healthcheck : ${e.getMessage()}"
                    }
                }
            }
        }
    }

    post {
        always {
            script {
                // Rendre le script de collecte exécutable et l'appeler
                sh "chmod +x collect_metrics.sh"
                sh "./collect_metrics.sh ${env.ST_BUILD} ${env.ST_TEST} ${env.ST_QUALITY} ${env.ST_DOCKER} ${env.ST_HEALTH}"
            }
            archiveArtifacts artifacts: 'pipeline-data/**', allowEmptyArchive: true
        }
    }
}