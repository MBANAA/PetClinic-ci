pipeline {
    agent any
    
    environment {
        TESTCONTAINERS_RYUK_DISABLED = 'true'
        IMAGE_NAME = 'petclinic-app'
        // Variables pour centraliser les résultats
        F_UNIT = '0'; F_IT = '0'; V_OS = '0'
    }

    stages {
        stage('📊 1. Init & Chaos') {
            steps {
                script {
                    env.START_P = System.currentTimeMillis()
                    // Capture système
                    env.CPU = sh(script: "top -bn1 | grep 'Cpu(s)' | awk '{print 100 - \$8}'", returnStdout: true).trim()
                    env.RAM = sh(script: "free | grep Mem | awk '{print \$3/\$2 * 100.0}'", returnStdout: true).trim()
                    env.DISK = sh(script: "df / | tail -1 | awk '{print \$5}' | sed 's/%//'", returnStdout: true).trim()
                    
                    sh "docker compose down -v || true"
                    sh "./mvnw clean"
                    
                    if (fileExists('scripts/chaos_engine.sh')) {
                        sh "chmod +x scripts/chaos_engine.sh && ./scripts/chaos_engine.sh"
                    }
                }
            }
        }

        stage('🧪 2a. Tests Unitaires') {
            steps {
                script {
                    sh "./mvnw test -Dtest=*Tests -DfailIfNoTests=false -Dmaven.test.failure.ignore=true"
                    env.F_UNIT = sh(script: "grep -l '<failure' target/surefire-reports/*.xml 2>/dev/null | wc -l || echo 0", returnStdout: true).trim()
                }
            }
        }

        stage('🧪 2b. Tests d\'Intégration') {
            steps {
                script {
                    sh "./mvnw test -Dtest=*IntegrationTests -DfailIfNoTests=false -Dmaven.test.failure.ignore=true"
                    env.F_IT = sh(script: "grep -l '<failure' target/surefire-reports/*.xml 2>/dev/null | wc -l || echo 0", returnStdout: true).trim()
                }
            }
        }

        stage('🛡️ 3. Sécurité (Trivy)') {
            steps {
                script {
                    sh "docker build -t ${IMAGE_NAME} ."
                    // Scan via Docker pour éviter les erreurs d'installation
                    def trivyCmd = "docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest image --severity HIGH --format json ${IMAGE_NAME}"
                    
                    echo "Analyse de sécurité en cours..."
                    env.V_OS = sh(script: "${trivyCmd} | grep -o '\"VulnerabilityID\"' | wc -l || echo 0", returnStdout: true).trim()
                }
            }
        }

        stage('🚀 4. Smoke Test') {
            steps {
                script {
                    sh "docker compose up -d && sleep 20"
                    env.H_CODE = sh(script: "curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/ || echo 000", returnStdout: true).trim()
                    sh "docker compose down"
                }
            }
        }
    }

    post {
        always {
            script {
                // Publication des rapports JUnit
                junit testResults: 'target/surefire-reports/*.xml', allowEmptyResults: true
                
                // Analyse Checkstyle
                sh "./mvnw checkstyle:check || true"
                def smells = sh(script: "grep -r '<error' target/checkstyle-result.xml 2>/dev/null | wc -l || echo 0", returnStdout: true).trim()
                
                def total_t = (System.currentTimeMillis() - env.START_P.toLong()) / 1000

                // Assemblage de la ligne de métriques
                def metrics = [
                    env.BUILD_ID, total_t, env.CPU, env.RAM, env.DISK, 
                    env.F_UNIT, env.F_IT, smells, env.V_OS, env.H_CODE
                ].join(',')

                if (fileExists('collect_metrics.sh')) {
                    sh "chmod +x collect_metrics.sh && ./collect_metrics.sh ${metrics}"
                }

                echo "Build terminé avec succès. La boucle automatique a été désactivée."
                
                // Le bloc de relance (build job: ...) a été supprimé ici.
            }
        }
    }
}