pipeline {
    agent any

    environment {
        // Désactivation de Docker Compose dans Maven pour éviter le conflit "Jackson/End-of-input"
        MAVEN_OPTS = "-Dspring.docker.compose.skip.in-tests=true -Dspring.sql.init.mode=always"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build & Unit Tests') {
            steps {
                script {
                    // On exécute uniquement les tests unitaires isolés (sans les intégrations lourdes)
                    // -Dtest=!PostgresIntegrationTests,!PetClinicIntegrationTests,!ClinicServiceTests
                    sh 'mvn clean package -DskipTests=false -Dtest=UnitTest* -Dspring.test.context.cache.maxSize=0'
                }
            }
        }

        stage('Integration Tests') {
            steps {
                script {
                    // Ici, on lance les tests d'intégration avec le profil nécessaire
                    // On ajoute -Dspring.profiles.active=postgres si besoin
                    sh 'mvn test -Dtest=PostgresIntegrationTests,ClinicServiceTests -Dspring.profiles.active=postgres'
                }
            }
        }
    }

    post {
        always {
            junit '**/target/surefire-reports/*.xml'
        }
    }
}
