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
                    // Mesures système robustes (sans iostat)
                    env.CPU = sh(script: "top -bn1 | grep 'Cpu(s)' | awk '{print 100 - \$8}'", returnStdout: true).trim()
                    env.RAM = sh(script: "free | grep Mem | awk '{print \$3/\$2 * 100.0}'", returnStdout: true).trim()
                    env.DISK = sh(script: "vmstat 1 2 | tail -n 1 | awk '{print \$9 + \$10}'", returnStdout: true).trim()
                    
                    sh "docker compose down -v || true"
                    sh "chmod +x scripts/chaos_engine.sh && ./scripts/chaos_engine.sh"
                    sh "./mvnw clean"
                }
            }
        }

        stage('🧪 2. Tests Applicatifs (Visualisés)') {
            steps {
                script {
                    // Division des tests avec patterns globaux (plus robuste)
                    def s1 = System.currentTimeMillis(); sh "./mvnw test -Dtest='**/*ApplicationTests' -Dmaven.test.failure.ignore=true"; env.T_CTX = (System.currentTimeMillis()-s1)/1000
                    def s2 = System.currentTimeMillis(); sh "./mvnw test -Dtest='**/*EntityTests,**/*FormattersTests' -Dmaven.test.failure.ignore=true"; env.T_LOG = (System.currentTimeMillis()-s2)/1000
                    def s3 = System.currentTimeMillis(); sh "./mvnw test -Dtest='**/*Owner*' -Dmaven.test.failure.ignore=true"; env.T_OWN = (System.currentTimeMillis()-s3)/1000
                    def s4 = System.currentTimeMillis(); sh "./mvnw test -Dtest='**/*Vet*' -Dmaven.test.failure.ignore=true"; env.T_VET = (System.currentTimeMillis()-s4)/1000
                    def s5 = System.currentTimeMillis(); sh "./mvnw test -Dtest='**/*Visit*' -Dmaven.test.failure.ignore=true"; env.T_VIS = (System.currentTimeMillis()-s5)/1000
                    def s6 = System.currentTimeMillis(); sh "./mvnw test -Dtest='**/*IntegrationTests' -Dmaven.test.failure.ignore=true"; env.T_IT = (System.currentTimeMillis()-s6)/1000

                    // Comptage des échecs
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
                    
                    def sc1 = System.currentTimeMillis()
                    env.V_OS = sh(script: "trivy image --scanners vuln --vuln-type os --severity HIGH --format json ${IMAGE_NAME} | grep -o '\"VulnerabilityID\"' | wc -l || echo 0", returnStdout: true).trim()
                    env.T_SOS = (System.currentTimeMillis()-sc1)/1000

                    def sc2 = System.currentTimeMillis()
                    env.V_APP = sh(script: "trivy image --scanners vuln --vuln-type library --severity HIGH --format json ${IMAGE_NAME} | grep -o '\"VulnerabilityID\"' | wc -l || echo 0", returnStdout: true).trim()
                    env.T_SAPP = (System.currentTimeMillis()-sc2)/1000

                    def sc3 = System.currentTimeMillis()
                    env.V_CONF = sh(script: "trivy config --severity HIGH --format json . | grep -o '\"ID\"' | wc -l || echo 0", returnStdout: true).trim()
                    env.T_SCONF = (System.currentTimeMillis()-sc3)/1000
                }
            }
        }
    }

    post {
        always {
            script {
                // Visualisation des tests dans Jenkins
                junit 'target/surefire-reports/*.xml'
                
                // Analyse statique
                sh "./mvnw checkstyle:check || true"
                env.SMELLS = sh(script: "grep -r '<error' target/checkstyle-result.xml 2>/dev/null | wc -l || echo 0", returnStdout: true).trim()
                
                // Déploiement et Healthcheck
                sh "docker compose up -d && sleep 40"
                def h_code = sh(script: "curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/ || echo 000", returnStdout: true).trim()
                def total_t = (System.currentTimeMillis() - env.START_P.toLong()) / 1000

                // Assemblage sécurisé (remplacement des null par 0)
                def metrics = [
                    env.BUILD_ID, total_t, env.T_CTX ?: 0, env.T_LOG ?: 0, env.T_OWN ?: 0, 
                    env.T_VET ?: 0, env.T_VIS ?: 0, env.T_IT ?: 0, env.T_SOS ?: 0, 
                    env.T_SAPP ?: 0, env.T_SCONF ?: 0, env.CPU, env.RAM, env.DISK, 
                    env.F_UNIT ?: 0, env.F_OWN ?: 0, env.F_VET ?: 0, env.F_VIS ?: 0, 
                    env.F_IT ?: 0, env.SMELLS ?: 0, env.V_OS ?: 0, env.V_APP ?: 0, 
                    env.V_CONF ?: 0, h_code
                ].join(',')

                sh "chmod +x collect_metrics.sh && ./collect_metrics.sh ${metrics}"

                if (env.BUILD_NUMBER.toInteger() < env.MAX_BUILDS.toInteger()) {
                    build job: env.JOB_NAME, wait: false
                }
            }
        }
    }
}