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
                    // Mesures système
                    env.CPU = sh(script: "top -bn1 | grep 'Cpu(s)' | awk '{print 100 - \$8}'", returnStdout: true).trim()
                    env.RAM = sh(script: "free | grep Mem | awk '{print \$3/\$2 * 100.0}'", returnStdout: true).trim()
                    env.DISK = sh(script: "vmstat 1 2 | tail -n 1 | awk '{print \$9 + \$10}'", returnStdout: true).trim()
                    
                    sh "docker compose down -v || true"
                    
                    // SÉCURITÉ : On vérifie si le script de chaos existe avant de le lancer
                    if (fileExists('scripts/chaos_engine.sh')) {
                        sh "chmod +x scripts/chaos_engine.sh && ./scripts/chaos_engine.sh"
                    } else {
                        echo "⚠️ Attention: scripts/chaos_engine.sh absent du dépôt GitHub. Chaos sauté."
                    }
                    sh "./mvnw clean"
                }
            }
        }

        stage('🧪 2. Tests Applicatifs (Visualisés)') {
            steps {
                script {
                    // Exécution des tests par domaine
                    sh "./mvnw test -Dtest='**/*ApplicationTests' -Dmaven.test.failure.ignore=true"
                    sh "./mvnw test -Dtest='**/*EntityTests,**/*FormattersTests' -Dmaven.test.failure.ignore=true"
                    sh "./mvnw test -Dtest='**/*Owner*' -Dmaven.test.failure.ignore=true"
                    sh "./mvnw test -Dtest='**/*Vet*' -Dmaven.test.failure.ignore=true"
                    sh "./mvnw test -Dtest='**/*Visit*' -Dmaven.test.failure.ignore=true"
                    sh "./mvnw test -Dtest='**/*IntegrationTests' -Dmaven.test.failure.ignore=true"

                    // Mesures de temps et échecs (on initialise à 0 par défaut)
                    env.T_CTX = 0; env.T_LOG = 0; env.T_OWN = 0; env.T_VET = 0; env.T_VIS = 0; env.T_IT = 0
                    env.F_UNIT = sh(script: "grep -r '<failure' target/surefire-reports/TEST-*ApplicationTests.xml 2>/dev/null | wc -l || echo 0", returnStdout: true).trim()
                    env.F_OWN = sh(script: "grep -r '<failure' target/surefire-reports/TEST-*.owner.*.xml 2>/dev/null | wc -l || echo 0", returnStdout: true).trim()
                    env.F_VET = sh(script: "grep -r '<failure' target/surefire-reports/TEST-*.vet.*.xml 2>/dev/null | wc -l || echo 0", returnStdout: true).trim()
                    env.F_VIS = sh(script: "grep -r '<failure' target/surefire-reports/TEST-*.Visit*.xml 2>/dev/null | wc -l || echo 0", returnStdout: true).trim()
                    env.F_IT = sh(script: "grep -r '<failure' target/surefire-reports/TEST-*IntegrationTests.xml 2>/dev/null | wc -l || echo 0", returnStdout: true).trim()
                }
            }
        }

        stage('🛡️ 3. Sécurité Granulaire') {
            steps {
                script {
                    sh "docker build -t ${IMAGE_NAME} ."
                    env.V_OS = sh(script: "trivy image --scanners vuln --vuln-type os --severity HIGH --format json ${IMAGE_NAME} | grep -o '\"VulnerabilityID\"' | wc -l || echo 0", returnStdout: true).trim()
                    env.V_APP = sh(script: "trivy image --scanners vuln --vuln-type library --severity HIGH --format json ${IMAGE_NAME} | grep -o '\"VulnerabilityID\"' | wc -l || echo 0", returnStdout: true).trim()
                    env.V_CONF = sh(script: "trivy config --severity HIGH --format json . | grep -o '\"ID\"' | wc -l || echo 0", returnStdout: true).trim()
                }
            }
        }
    }

    post {
        always {
            script {
                // SÉCURITÉ : Ne plante pas si les tests n'ont pas tourné
                junit testResults: 'target/surefire-reports/*.xml', allowEmptyResults: true
                
                sh "./mvnw checkstyle:check || true"
                env.SMELLS = sh(script: "grep -r '<error' target/checkstyle-result.xml 2>/dev/null | wc -l || echo 0", returnStdout: true).trim()
                
                sh "docker compose up -d && sleep 40"
                def h_code = sh(script: "curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/ || echo 000", returnStdout: true).trim()
                def total_t = (System.currentTimeMillis() - env.START_P.toLong()) / 1000

                // Préparation des données pour le CSV
                def metrics = [
                    env.BUILD_ID, total_t, env.T_CTX, env.T_LOG, env.T_OWN, env.T_VET, env.T_VIS, env.T_IT, 
                    "0", "0", "0", // Scans temps (simplifié pour ce test)
                    env.CPU, env.RAM, env.DISK, 
                    env.F_UNIT, env.F_OWN, env.F_VET, env.F_VIS, env.F_IT, 
                    env.SMELLS, env.V_OS, env.V_APP, env.V_CONF, h_code
                ].join(',')

                if (fileExists('collect_metrics.sh')) {
                    sh "chmod +x collect_metrics.sh && ./collect_metrics.sh ${metrics}"
                }
            }
        }
    }
}