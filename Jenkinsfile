pipeline {
    agent any

    environment {
        IMAGE_NAME = "petclinic-app"
        TESTCONTAINERS_RYUK_DISABLED = "true"
    }

    options {
        timestamps()
        ansiColor('xterm')
        timeout(time: 20, unit: 'MINUTES')
    }

    stages {

        stage('Clean Workspace') {
            steps {
                sh '''
                    docker compose down -v || true
                    ./mvnw clean
                '''
            }
        }

        stage('Build') {
            steps {
                sh './mvnw compile'
            }
        }

        stage('Unit Tests') {
            steps {
                sh './mvnw test -DfailIfNoTests=false'
            }
            post {
                always {
                    junit 'target/surefire-reports/*.xml'
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                sh "docker build -t ${IMAGE_NAME} ."
            }
        }

        stage('Security Scan') {
            steps {
                sh """
                docker run --rm \
                    -v /var/run/docker.sock:/var/run/docker.sock \
                    aquasec/trivy:latest image \
                    --severity HIGH,CRITICAL \
                    --exit-code 0 \
                    ${IMAGE_NAME}
                """
            }
        }

        stage('Smoke Test') {
            steps {
                sh '''
                    docker compose up -d

                    echo "Waiting application..."

                    for i in {1..30}; do
                        STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/ || true)

                        if [ "$STATUS" = "200" ]; then
                            echo "Application started."
                            exit 0
                        fi

                        sleep 5
                    done

                    echo "Application failed."
                    exit 1
                '''
            }
        }

    }

    post {

        always {

            sh 'docker compose down -v || true'

            sh './mvnw checkstyle:check || true'

            archiveArtifacts artifacts: 'target/**/*.xml', allowEmptyArchive: true

        }

        success {
            echo "Pipeline terminé avec succès."
        }

        unstable {
            echo "Pipeline terminé avec des avertissements."
        }

        failure {
            echo "Pipeline échoué."
        }
    }
}