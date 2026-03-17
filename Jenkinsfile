pipeline {
    agent any

    tools {
        maven 'Maven3' // Assure-toi que le nom correspond à ta config Jenkins
        jdk 'JDK17'   // Assure-toi que le nom correspond à ta config Jenkins
    }

    environment {
        // On évite que Spring ne tente de gérer Docker pendant le build Maven
        MAVEN_OPTS = "-Dspring.docker.compose.skip.in-tests=true"
    }

    stages {
        stage('Check Environment') {
            steps {
                sh 'java -version'
                sh 'mvn -version'
                // On vérifie quelle version de docker compose est disponible
                script {
                    try {
                        sh 'docker compose version'
                        env.DOCKER_CMD = "docker compose"
                    } catch (Exception e) {
                        sh 'docker-compose version'
                        env.DOCKER_CMD = "docker-compose"
                    }
                }
            }
        }

        stage('Build Application') {
            steps {
                // On compile et on saute les tests ici pour valider l'infrastructure d'abord
                sh 'mvn clean package -DskipTests'
            }
        }

        stage('Run Infrastructure') {
            steps {
                script {
                    // Arrêt des anciens conteneurs et démarrage des nouveaux
                    sh "${env.DOCKER_CMD} down"
                    sh "${env.DOCKER_CMD} up -d"
                }
            }
        }

        stage('Healthcheck') {
            steps {
                script {
                    echo "Attente du démarrage de l'application..."
                    // On attend que l'app réponde sur le port 8080
                    sleep 20
                    sh "curl -f http://localhost:8080 || exit 1"
                }
            }
        }
    }

    post {
        always {
            echo "Nettoyage ou archivage des résultats..."
        }
        failure {
            echo "Le pipeline a échoué. Vérifiez si Docker est bien installé sur le serveur Jenkins."
        }
    }
}
