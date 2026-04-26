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
                    echo "Démarrage de l'infrastructure via ${env.DOCKER_CMD}..."
                    // On reconstruit les images pour être sûr d'avoir le dernier code
                    //sh "${env.DOCKER_CMD} down --remove-orphans"
                    //sh "${env.DOCKER_CMD} up -d --build"
                    sh 'docker compose down --remove-orphans'
                    sh 'docker compose up -d'
                }
            }
        }

        stage('Validation (Healthcheck)') {
            steps {
                script {
                    echo "Attente du démarrage (30s)..."
                    sleep 30
                    // Vérifie si la page d'accueil répond (HTTP 200)
                    sh "curl -sI http://localhost:8080 | grep 'HTTP/1.1 200' || (echo 'L'application n'est pas prête' && exit 1)"
                }
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