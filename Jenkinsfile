pipeline {
    agent any

    tools {
        // Remplace 'maven' et 'jdk17' par les noms EXACTS configurés dans ton Jenkins
        maven 'maven' 
        jdk 'jdk17'
    }

    environment {
        // Empêche Spring de tenter de piloter Docker pendant que Maven compile
        MAVEN_OPTS = "-Dspring.docker.compose.skip.in-tests=true"
        // Nom de l'image Docker pour ton projet
        IMAGE_NAME = "petclinic-app"
    }

    stages {
        stage('Nettoyage & Préparation') {
            steps {
                sh 'mvn clean'
                script {
                    // Détection dynamique de la commande Docker Compose (V1 vs V2)
                    try {
                        sh 'docker compose version'
                        env.DOCKER_CMD = "docker compose"
                    } catch (Exception e) {
                        env.DOCKER_CMD = "docker-compose"
                    }
                }
            }
        }

        stage('Build & Tests Unitaires') {
            steps {
                // On lance les tests qui ne nécessitent pas de base de données externe
                // On force le chargement des données SQL pour H2
                sh 'mvn package -Dspring.sql.init.mode=always -Dtest=!PostgresIntegrationTests,!MySqlIntegrationTests'
            }
        }

stage('Diagnostic') {
    steps {
        sh 'whoami'
        sh 'groups'
        sh 'which docker || echo "docker non trouvé"'
        sh 'docker --version || echo "docker ne repond pas"'
    }
}


     stage('Docker Infrastructure') {
            steps {
                script {
                    echo "Nettoyage forcé des anciens conteneurs..."
                    // Supprime les conteneurs par leur nom exact, ignore l'erreur s'ils n'existent pas
                    sh 'docker rm -f petclinic-app petclinic-mysql || true'
                    
                    echo "Démarrage de l'infrastructure..."
                    sh "${env.DOCKER_CMD} down --volumes --remove-orphans"
                    sh "${env.DOCKER_CMD} up -d --build"
                }
            }
        }

  stage('Validation (Healthcheck)') {
            steps {
                script {
                    echo "Attente du démarrage de Spring Boot..."
                    // On augmente un peu le temps pour laisser MySQL et Spring s'aligner
                    sleep 45 
                    
                    // On interroge le conteneur par son nom sur le réseau Docker
                    sh "docker exec jenkins curl -sI http://petclinic-app:8080 | grep 'HTTP/1.1 200' || (echo 'Lapplication nest pas encore prête' && exit 1)"
                }
            }
        }

    post {
        always {
            // Archive les rapports de tests pour les voir dans l'interface Jenkins
            junit '**/target/surefire-reports/*.xml'
        }
        success {
            echo "Phase 1 terminée avec succès : Environnement Stable et Reproductible."
        }
        failure {
            echo "Échec détecté. Consultez les logs Docker avec : docker logs <container_id>"
        }
    }
}