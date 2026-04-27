pipeline {
    agent any

    environment {
        MAVEN_OPTS = '-Dspring.docker.compose.skip.in-tests=true'
        IMAGE_NAME = 'petclinic-app'
        
        // Initialisation des métriques (valeurs par défaut numériques pour le CSV)
        ST_BUILD = "0"     // Sera le temps de build en secondes
        ST_TEST = "0"      // Sera le nombre de tests réussis
        ST_QUALITY = "0"   // Sera le nombre d'alertes trouvées
        ST_DOCKER = "0"    // Sera la taille de l'image en Mo
        ST_HEALTH = "0"    // Sera le code HTTP (ex: 200)
    }

    stages {
        stage('Nettoyage et Preparation') {
            steps {
                script {
                    sh 'sed -i "s/\\r//" mvnw collect_metrics.sh || true'
                    sh 'chmod +x mvnw'
                    sh './mvnw clean'
                    env.DOCKER_CMD = sh(script: "docker compose version >/dev/null 2>&1 && echo 'docker compose' || echo 'docker-compose'", returnStdout: true).trim()
                }
            }
        }

        stage('Analyse Statique') {
            steps {
                script {
                    try {
                        // On compte le nombre de lignes d'alertes dans les rapports
                        sh './mvnw checkstyle:check spotbugs:check pmd:check || true'
                        def alerts = sh(script: "grep -r '<error' target/*.xml 2>/dev/null | wc -l || echo '0'", returnStdout: true).trim()
                        env.ST_QUALITY = alerts
                    } catch (e) {
                        env.ST_QUALITY = "-1"
                    }
                }
            }
        }

stage('Build et Tests Unitaires') {
    steps {
        script {
            def start = System.currentTimeMillis()
            try {
                // On s'assure que le wrapper est exécutable
                sh 'chmod +x mvnw'
                sh "./mvnw jacoco:prepare-agent test jacoco:report -Dtest='!*IntegrationTests' -Dmaven.test.failure.ignore=true"
                
                // Calcul du temps de build (conversion en secondes)
                long end = System.currentTimeMillis()
                env.ST_BUILD = ((end - start) / 1000).toString()
                
                // Extraction du nombre de tests : on cherche dans les rapports XML
                def testCount = sh(script: "grep -s 'tests=\"' target/surefire-reports/*.xml | awk -F'tests=\"' '{print \$2}' | awk -F'\"' '{print \$1}' | awk '{sum += \$1} END {print sum}' || echo '0'", returnStdout: true).trim()
                env.ST_TEST = testCount ?: "0"
                
                // Extraction de la qualité (nb d'erreurs Checkstyle)
                def qualityErrors = sh(script: "grep -c '<error' target/checkstyle-result.xml || echo '0'", returnStdout: true).trim()
                env.ST_QUALITY = qualityErrors
                
            } catch (e) {
                env.ST_BUILD = "-1"
                echo "Erreur Build: ${e.getMessage()}"
            }
        }
    }
}

        stage('Docker Infrastructure') {
            steps {
                script {
                    try {
                        sh "${env.DOCKER_CMD} up -d --build"
                        // Métrique: Taille de l'image en Mo
                        def size = sh(script: "docker images ${IMAGE_NAME} --format '{{.Size}}' | sed 's/MB//' || echo '0'", returnStdout: true).trim()
                        env.ST_DOCKER = size
                    } catch (e) {
                        env.ST_DOCKER = "-1"
                    }
                }
            }
        }

        stage('Validation Healthcheck') {
            steps {
                script {
                    try {
                        sleep 45
                        def networkName = sh(script: "docker network ls --filter name=petclinic --format '{{.Name}}' | head -n 1", returnStdout: true).trim() ?: "bridge"
                        def response = sh(script: "docker run --network ${networkName} curlimages/curl:latest -s -o /dev/null -w '%{http_code}' http://petclinic-app:8080", returnStdout: true).trim()
                        
                        // Métrique: Le code HTTP réel (200, 404, 500, etc.)
                        env.ST_HEALTH = response
                    } catch (e) {
                        env.ST_HEALTH = "000"
                    }
                }
            }
        }
    }

  post {
    always {
        script {
            sh "chmod +x collect_metrics.sh"
            // On force l'utilisation des variables d'environnement mises à jour
            sh "./collect_metrics.sh '${env.ST_BUILD}' '${env.ST_TEST}' '${env.ST_QUALITY}' '${env.ST_DOCKER}' '${env.ST_HEALTH}'"
        }
    }
}
}