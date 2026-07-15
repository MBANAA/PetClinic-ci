pipeline {
    agent any

    environment {
        TESTCONTAINERS_RYUK_DISABLED = 'true'
        IMAGE_NAME = 'petclinic-app'
    }

    options {
        timeout(time: 20, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Clean') {
            steps {
                sh '''
                    docker compose down -v || true
                    ./mvnw clean
                '''
            }
        }

        stage('Unit Tests') {
            steps {
                sh '''
                    ./mvnw test \
                    -DfailIfNoTests=false \
                    -Dmaven.test.failure.ignore=true
                '''
            }

            post {
                always {
                    junit 'target/surefire-reports/*.xml'
                }
            }
        }

        stage('Build') {
            steps {
                sh './mvnw package -DskipTests'
            }
        }

        stage('Docker Build') {
            steps {
                sh '''
                    docker build -t ${IMAGE_NAME}:latest .
                '''
            }
        }

        stage('Trivy Scan') {
            steps {
                sh '''
                    docker run --rm \
                    -v /var/run/docker.sock:/var/run/docker.sock \
                    aquasec/trivy:latest image \
                    --severity HIGH,CRITICAL \
                    --no-progress \
                    ${IMAGE_NAME}:latest || true
                '''
            }
        }

        stage('Smoke Test') {
            steps {

                sh '''
                    docker compose up -d

                    echo "Attente du démarrage..."

                    for i in {1..20}
                    do
                        STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 || true)

                        if [ "$STATUS" = "200" ]; then
                            echo "Application disponible."
                            exit 0
                        fi

                        sleep 5
                    done

                    echo "Application indisponible."

                    docker compose logs

                    exit 1
                '''
            }
        }

    }

    post {

        always {

            sh '''
                docker compose down -v || true
            '''

            archiveArtifacts artifacts: 'target/**/*.jar', allowEmptyArchive: true

        }

        success {
            echo "Pipeline terminé avec succès."
        }

        failure {
            echo "Pipeline échoué."
        }
    }
}