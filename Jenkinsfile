pipeline {

    agent any

    tools {
        maven 'Maven3'
        jdk 'JDK17'
    }

    environment {
        APP_NAME = "petclinic-app"
        DOCKER_IMAGE = "petclinic-app:latest"
    }

    stages {
        
stage('Check Java') {
    steps {
        sh 'java -version'
    }
}
        stage('Clone Repository') {
            steps {
                git branch: 'main', url: 'https://github.com/MBANAA/PetClinic-ci.git'
            }
        }

        stage('Build Application') {
            steps {
                sh 'mvn clean package -DskipTests'
            }
        }

        stage('Run Tests') {
            steps {
                sh 'mvn test'
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'docker build -t $DOCKER_IMAGE .'
            }
        }

        stage('Stop Old Container') {
            steps {
                sh 'docker rm -f petclinic-container || true'
            }
        }

        stage('Run Docker Container') {
            steps {
                sh 'docker run -d -p 8080:8080 --name petclinic-container $DOCKER_IMAGE'
            }
        }

    }

    post {

        success {
            echo 'Pipeline executed successfully!'
        }

        failure {
            echo 'Pipeline failed!'
        }

    }

}