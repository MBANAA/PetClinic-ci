pipeline {
    agent any

    environment {
        IMAGE_NAME = "petclinic-app"
        TESTCONTAINERS_RYUK_DISABLED = "true"
    }

    options {
        timestamps()
        timeout(time: 20, unit: 'MINUTES')
    }

    stages {

        stage('🧹 Clean') {
            steps {
                sh '''
                    docker compose down -v || true
                    ./mvnw clean
                '''
            }
        }

        stage('🔨 Build & Unit Tests') {
            steps {
                sh './mvnw test -DfailIfNoTests=false'
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'target/surefire-reports/*.xml'
                }
            }
        }

        stage('🐳 Build Docker Image') {
            steps {
                sh "docker build -t ${IMAGE_NAME} ."
            }
        }

        stage('🔒 Security Scan (Trivy)') {
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

        stage('🚀 Smoke Test') {
            steps {
                sh '''
                    docker compose up -d

                    echo "Attente du démarrage de l'application..."

                    for i in $(seq 1 30)
                    do
                        STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/ || true)

                        if [ "$STATUS" = "200" ]; then
                            echo "Application démarrée."
                            exit 0
                        fi

                        sleep 2
                    done

                    echo "L'application ne répond pas."
                    docker compose logs
                    exit 1
                '''
            }
        }

        stage('📊 Checkstyle') {
            steps {
                sh './mvnw checkstyle:check || true'
            }
        }

    }

    post {

        always {

            script {

                archiveArtifacts artifacts: 'target/**/*.xml', allowEmptyArchive: true

                sh '''
                    mkdir -p metrics

                    echo "Build ID : ${BUILD_ID}" > metrics/build-info.txt
                    echo "Date : $(date)" >> metrics/build-info.txt
                    echo "CPU :" >> metrics/build-info.txt
                    top -bn1 | head -5 >> metrics/build-info.txt || true

                    echo "" >> metrics/build-info.txt

                    echo "RAM :" >> metrics/build-info.txt
                    free -h >> metrics/build-info.txt || true

                    echo "" >> metrics/build-info.txt

                    echo "DISK :" >> metrics/build-info.txt
                    df -h >> metrics/build-info.txt || true
                '''

                archiveArtifacts artifacts: 'metrics/*', allowEmptyArchive: true

                sh 'docker compose down -v || true'
            }
        }

        success {
            echo 'Pipeline exécuté avec succès.'
        }

        unstable {
            echo 'Pipeline terminé avec des avertissements.'
        }

        failure {
            echo 'Pipeline en échec.'
        }
    }
}