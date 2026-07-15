pipeline {
    agent any

    environment {
        IMAGE_NAME = "petclinic-app:${BUILD_NUMBER}"
        TESTCONTAINERS_RYUK_DISABLED = "true"

        F_UNIT = "0"
        F_IT = "0"
        V_OS = "0"
    }

    stages {

        stage('Préparation') {
            steps {
                script {
                    env.START = System.currentTimeMillis()

                    sh '''
                    docker compose down || true
                    chmod +x mvnw
                    '''
                }
            }
        }

        stage('Compilation & Tests') {
            parallel {

                stage('Tests Unitaires') {
                    steps {
                        sh "./mvnw test -Dtest=*Tests -DfailIfNoTests=false"
                    }
                }

                stage('Tests Intégration') {
                    steps {
                        sh "./mvnw test -Dtest=*IntegrationTests -DfailIfNoTests=false"
                    }
                }
            }
        }

        stage('Build Docker') {
            steps {
                sh "docker build -t ${IMAGE_NAME} ."
            }
        }

        stage('Analyse Trivy') {
            steps {
                sh """
                docker run --rm \
                  -v /var/run/docker.sock:/var/run/docker.sock \
                  -v \$HOME/.cache/trivy:/root/.cache \
                  aquasec/trivy image \
                  --severity HIGH,CRITICAL \
                  ${IMAGE_NAME}
                """
            }
        }

        stage('Smoke Test') {
            steps {
                sh '''
                docker compose up -d

                for i in {1..30}
                do
                    if curl -fs http://localhost:8080 > /dev/null
                    then
                        exit 0
                    fi
                    sleep 2
                done

                exit 1
                '''
            }
        }

    }

    post {

        always {

            junit 'target/surefire-reports/*.xml'

            sh 'docker compose down || true'

            script {

                def duration = (System.currentTimeMillis()-env.START.toLong())/1000

                echo """
==========================
Pipeline terminé

Durée : ${duration} sec

Image : ${IMAGE_NAME}

==========================
"""
            }
        }
    }
}