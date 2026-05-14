pipeline {
    agent any
    
    environment {
        TESTCONTAINERS_RYUK_DISABLED = 'true'
        IMAGE_NAME = 'petclinic-app'
        MAX_BUILDS = 200
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
                    // On lance uniquement les tests unitaires (rapides)
                    sh "./mvnw test -Dtest=*Tests -DfailIfNoTests=false -Dmaven.test.failure.ignore=true"
                    env.F_UNIT = sh(script: "grep -l '<failure' target/surefire-reports/*.xml 2>/dev/null | wc -l || echo 0", returnStdout: true).trim()
                }
            }
        }

        stage('🧪 2b. Tests d\'Intégration') {
            steps {
                script {
                    // On lance les tests d'intégration (plus lourds, souvent avec DB)
                    sh "./mvnw test -Dtest=*IntegrationTests -DfailIfNoTests=false -Dmaven.test.failure.ignore=true"
                    env.F_IT = sh(script: "grep -l '<failure' target/surefire-reports/*.xml 2>/dev/null | wc -l || echo 0", returnStdout: true).trim()
                }
            }
        }

        stage('🛡️ 3. Sécurité (Trivy)') {
            steps {
                script {
                    // Construction de l'image Docker
                    sh "docker build -t ${IMAGE_NAME} ."
                    
                    // Correction : Utilisation de Trivy via Docker pour éviter "command not found"
                    def trivyCmd = "docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest image --severity HIGH --format json ${IMAGE_NAME}"
                    
                    echo "Analyse de sécurité en cours..."
                    env.V_OS = sh(script: "${trivyCmd} | grep -o '\"VulnerabilityID\"' | wc -l || echo 0", returnStdout: true).trim()
                    echo "Nombre de vulnérabilités : ${env.V_OS}"
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
                // Publication JUnit pour l'interface Jenkins
                junit testResults: 'target/surefire-reports/*.xml', allowEmptyResults: true
                
                // Analyse Checkstyle (Dette technique)
                sh "./mvnw checkstyle:check || true"
                def smells = sh(script: "grep -r '<error' target/checkstyle-result.xml 2>/dev/null | wc -l || echo 0", returnStdout: true).trim()
                
                def total_t = (System.currentTimeMillis() - env.START_P.toLong()) / 1000

                // Préparation de la ligne CSV (Dataset)
                // Format: ID, Temps, CPU, RAM, DISK, F_UNIT, F_IT, SMELLS, VULN, HTTP_CODE
                def metrics = [
                    env.BUILD_ID, total_t, env.CPU, env.RAM, env.DISK, 
                    env.F_UNIT, env.F_IT, smells, env.V_OS, env.H_CODE
                ].join(',')

                if (fileExists('collect_metrics.sh')) {
                    sh "chmod +x collect_metrics.sh && ./collect_metrics.sh ${metrics}"
                }

                // Relance automatique jusqu'à 200 builds
                if (env.BUILD_NUMBER.toInteger() < env.MAX_BUILDS.toInteger()) {
                    echo "Build ${env.BUILD_NUMBER} terminé. Relance du suivant..."
                    build job: env.JOB_NAME, wait: false
                }
            }
        }
    }
}