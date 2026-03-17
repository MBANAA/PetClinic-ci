pipeline {
    agent any

    tools {
        maven 'maven' 
        jdk 'jdk17'
    }

    environment {
        MAVEN_OPTS = "-Dspring.docker.compose.skip.in-tests=true"
    }

    stages {
        // STAGE 1: Initialisation de l'environnement
        stage('1. Environment Setup') {
            steps {
                sh 'java -version'
                sh 'mvn -version'
                script {
                    try { sh 'docker compose version'; env.DOCKER_CMD = "docker compose" }
                    catch (Exception e) { env.DOCKER_CMD = "docker-compose" }
                }
            }
        }

        // STAGE 2: Récupération du code
        stage('2. Checkout Source') {
            steps {
                checkout scm
            }
        }

        // STAGE 3: Compilation du code source
        stage('3. Compile') {
            steps {
                sh 'mvn clean compile'
            }
        }

        // STAGE 4: Exécution des tests unitaires
        stage('4. Unit Tests') {
            steps {
                // On utilise H2 ici pour la rapidité et l'isolation
                sh 'mvn test -Dtest=!*IntegrationTests -Dspring.sql.init.mode=always'
            }
            post {
                always { junit '**/target/surefire-reports/*.xml' }
            }
        }

        // STAGE 5: Construction de l'artefact (JAR)
        stage('5. Package') {
            steps {
                sh 'mvn package -DskipTests'
            }
        }

        // STAGE 6: Déploiement de l'infrastructure Docker
        stage('6. Docker Deployment') {
            steps {
                script {
                    sh "${env.DOCKER_CMD} down --remove-orphans"
                    sh "${env.DOCKER_CMD} up -d --build"
                }
            }
        }

        // STAGE 7: Vérification de la disponibilité (Smoke Test)
        stage('7. Healthcheck') {
            steps {
                script {
                    echo "Waiting for PetClinic to be ready..."
                    sleep 30
                    sh "curl -sI http://localhost:8080 | grep 'HTTP/1.1 200' || (echo 'App not responding' && exit 1)"
                }
            }
        }
    }

    post {
        success { echo "Pipeline complet terminé avec succès (7/7 stages)." }
        failure { echo "Échec au cours du pipeline. Vérifiez le stage concerné." }
    }
}