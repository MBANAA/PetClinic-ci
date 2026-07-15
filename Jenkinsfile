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
                    docker compose down -v --remove-orphans || true
                    docker rm -f petclinic-app petclinic-mysql || true
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
                    # Lancement de l'infrastructure
                    docker compose up -d

                    echo "Attente du démarrage de l'application..."
                    
                    # Boucle de vérification robuste (20 essais de 5 secondes)
                    for i in {1..20}
                    do
                        # Utilisation d'un conteneur curl éphémère connecté au réseau de l'application
                        STATUS=$(docker run --rm --network ced_petclinic_default curlimages/curl:latest -s -o /dev/null -w "%{http_code}" http://petclinic-app:8080 || true)

                        if [ "$STATUS" = "200" ]; then
                            echo "Application disponible (HTTP 200) !"
                            exit 0
                        fi

                        echo "L'application n'est pas encore prête... essai $i/20 (Code HTTP reçu : $STATUS)"
                        sleep 5
                    done

                    echo "L'application a mis trop de temps à démarrer."
                    docker compose logs
                    exit 1
                '''
            }
        }
    }

    post {
        always {
            // Nettoyage complet pour ne pas encombrer l'espace disque du serveur
            sh '''
                docker compose down -v --remove-orphans || true
                docker rm -f petclinic-app petclinic-mysql || true
            '''
            archiveArtifacts artifacts: 'target/**/*.jar', allowEmptyArchive: true
        }

        success {
            echo "✅ Pipeline terminé avec succès !"
        }

        failure {
            echo "❌ Le pipeline a échoué. Inspecte les logs ci-dessus pour comprendre l'erreur."
        }
    }
}