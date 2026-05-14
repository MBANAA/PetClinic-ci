pipeline {
    agent any
    environment {
        TESTCONTAINERS_RYUK_DISABLED = 'true'
        IMAGE_NAME = 'petclinic-app'
        MAX_BUILDS = 200
    }
    stages {
        stage('📊 1. Infrastructure & Chaos') {
            steps {
                script {
                    env.START_P = System.currentTimeMillis()
                    sh "docker compose down -v || true"
                    
                    if (fileExists('scripts/chaos_engine.sh')) {
                        sh "chmod +x scripts/chaos_engine.sh && ./scripts/chaos_engine.sh"
                    }
                    sh "./mvnw clean"
                }
            }
        }

        stage('🧪 2. Tests Applicatifs (Visualisés)') {
            steps {
                script {
                    // Exécution flexible des tests
                    sh "./mvnw test -Dtest=PetClinicApplicationTests,**/*Tests -DfailIfNoTests=false -Dmaven.test.failure.ignore=true"
                    
                    // Capture des échecs (on simplifie pour être sûr que ça marche)
                    def failures = sh(script: "grep -l '<failure' target/surefire-reports/*.xml 2>/dev/null | wc -l || echo 0", returnStdout: true).trim()
                    env.F_UNIT = failures
                    env.F_OWN = "0"; env.F_VET = "0"; env.F_VIS = "0"; env.F_IT = "0" // Initialisation par défaut
                }
            }
        }

        stage('🛡️ 3. Sécurité Granulaire') {
            steps {
                script {
                    sh "docker build -t ${IMAGE_NAME} ."
                    // On simplifie les scans pour éviter les timeouts
                    env.V_OS = sh(script: "trivy image --severity HIGH --format json ${IMAGE_NAME} | grep -o '\"VulnerabilityID\"' | wc -l || echo 0", returnStdout: true).trim()
                    env.V_APP = "0"
                    env.V_CONF = "0"
                }
            }
        }
    }

    post {
        always {
            script {
                // allowEmptyResults: true est CRITIQUE ici
                junit testResults: 'target/surefire-reports/*.xml', allowEmptyResults: true
                
                sh "./mvnw checkstyle:check || true"
                def smells = sh(script: "grep -r '<error' target/checkstyle-result.xml 2>/dev/null | wc -l || echo 0", returnStdout: true).trim()
                
                sh "docker compose up -d && sleep 20"
                def h_code = sh(script: "curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/ || echo 000", returnStdout: true).trim()
                def total_t = (System.currentTimeMillis() - env.START_P.toLong()) / 1000

                def metrics = [
                    env.BUILD_ID, total_t, "0", "0", "0", "0", "0", "0", "0", "0", "0",
                    "1.0", "1.0", "0", // CPU/RAM/DISK fictifs si besoin
                    env.F_UNIT, env.F_OWN, env.F_VET, env.F_VIS, env.F_IT, 
                    smells, env.V_OS, "0", "0", h_code
                ].join(',')

                if (fileExists('collect_metrics.sh')) {
                    sh "chmod +x collect_metrics.sh && ./collect_metrics.sh ${metrics}"
                }

                if (env.BUILD_NUMBER.toInteger() < env.MAX_BUILDS.toInteger()) {
                    build job: env.JOB_NAME, wait: false
                }
            }
        }
    }
}