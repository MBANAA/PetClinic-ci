pipeline {
    agent any

    tools {
        maven 'maven' 
        jdk 'jdk17'
    }

    environment {
        // Empêche Docker Compose de démarrer pendant 'mvn test'
        MAVEN_OPTS = "-Dspring.docker.compose.skip.in-tests=true"
    }

    stages {
        stage('1. Environment Setup') {
            steps {
                script {
                    try { sh 'docker compose version'; env.DOCKER_CMD = "docker compose" }
                    catch (Exception e) { env.DOCKER_CMD = "docker-compose" }
                }
            }
        }

        stage('2. Checkout Source') {
            steps { checkout scm }
        }

        stage('3. Compile') {
            steps { sh 'mvn clean compile' }
        }

        stage('4. Unit Tests') {
            steps {
                // On force le mode d'initialisation SQL directement en ligne de commande
                sh 'mvn test -Dtest=!*IntegrationTests -Dspring.sql.init.mode=always -Dspring.jpa.defer-datasource-initialization=true'
            }
            post {
                always { junit '**/target/surefire-reports/*.xml' }
            }
        }

        stage('5. Package') {
            steps { sh 'mvn package -DskipTests' }
        }

        stage('6. Docker Deployment') {
            steps {
                script {
                    sh "${env.DOCKER_CMD} down --remove-orphans"
                    sh "${env.DOCKER_CMD} up -d --build"
                }
            }
        }

        stage('7. Healthcheck') {
            steps {
                script {
                    echo "Waiting for app to start..."
                    sleep 30
                    sh "curl -sI http://localhost:8080 | grep 'HTTP/1.1 200' || exit 1"
                }
            }
        }
    }
}