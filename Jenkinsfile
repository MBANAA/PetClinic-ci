pipeline {
    agent any
    environment {
        TESTCONTAINERS_RYUK_DISABLED = 'true'
        IMAGE_NAME = 'petclinic-app'
        MAX_BUILDS = 200
    }
    stages {
        stage('📊 1. Infrastructure Monitoring') {
            steps {
                script {
                    env.START_P = System.currentTimeMillis()
                    // Capture système
                    env.CPU = sh(script: "top -bn1 | grep 'Cpu(s)' | awk '{print 100 - \$8}'", returnStdout: true).trim()
                    env.RAM = sh(script: "free | grep Mem | awk '{print \$3/\$2 * 100.0}'", returnStdout: true).trim()
                    env.DISK = sh(script: "iostat -d | awk 'NF==6 {print \$3}' | tail -n 1 || echo 0", returnStdout: true).trim()
                    sh "docker compose down -v || true"
                    sh "./mvnw clean"
                }
            }
        }

        stage('🧪 2. Tests Applicatifs Divisés') {
            steps {
                script {
                    // Context vs Logic
                    def s1 = System.currentTimeMillis(); sh "./mvnw test -Dtest=PetClinicApplicationTests -Dmaven.test.failure.ignore=true"; env.T_CTX = (System.currentTimeMillis()-s1)/1000
                    def s2 = System.currentTimeMillis(); sh "./mvnw test -Dtest=EntityTests,FormattersTests -Dmaven.test.failure.ignore=true"; env.T_LOG = (System.currentTimeMillis()-s2)/1000
                    
                    // Domaines
                    def s3 = System.currentTimeMillis(); sh "./mvnw test -Dtest=OwnerControllerTests,OwnerTests -Dmaven.test.failure.ignore=true"; env.T_OWN = (System.currentTimeMillis()-s3)/1000
                    def s4 = System.currentTimeMillis(); sh "./mvnw test -Dtest=VetControllerTests,VetTests -Dmaven.test.failure.ignore=true"; env.T_VET = (System.currentTimeMillis()-s4)/1000
                    def s5 = System.currentTimeMillis(); sh "./mvnw test -Dtest=VisitControllerTests -Dmaven.test.failure.ignore=true"; env.T_VIS = (System.currentTimeMillis()-s5)/1000
                    
                    // Intégration
                    def s6 = System.currentTimeMillis(); sh "./mvnw test -Dtest=MySqlIntegrationTests -Dmaven.test.failure.ignore=true"; env.T_IT = (System.currentTimeMillis()-s6)/1000

                    // Récupération des échecs (via grep sur les XML)
                    env.F_UNIT = sh(script: "grep -r '<failure' target/surefire-reports/TEST-*ApplicationTests.xml | wc -l || echo 0", returnStdout: true).trim()
                    env.F_OWN = sh(script: "grep -r '<failure' target/surefire-reports/TEST-*.owner.*.xml | wc -l || echo 0", returnStdout: true).trim()
                    env.F_VET = sh(script: "grep -r '<failure' target/surefire-reports/TEST-*.vet.*.xml | wc -l || echo 0", returnStdout: true).trim()
                    env.F_VIS = sh(script: "grep -r '<failure' target/surefire-reports/TEST-*.Visit*.xml | wc -l || echo 0", returnStdout: true).trim()
                    env.F_IT = sh(script: "grep -r '<failure' target/surefire-reports/TEST-*IntegrationTests.xml | wc -l || echo 0", returnStdout: true).trim()
                }
            }
        }

        stage('🛡️ 3. Sécurité Granulaire (Trivy)') {
            steps {
                script {
                    sh "docker build -t ${IMAGE_NAME} ."
                    
                    // A. Scan de l'OS (Base Image)
                    def sc1 = System.currentTimeMillis()
                    env.V_OS = sh(script: "trivy image --scanners vuln --vuln-type os --severity HIGH --format json ${IMAGE_NAME} | grep -o '\"VulnerabilityID\"' | wc -l || echo 0", returnStdout: true).trim()
                    env.T_SOS = (System.currentTimeMillis()-sc1)/1000

                    // B. Scan des Dépendances (Library)
                    def sc2 = System.currentTimeMillis()
                    env.V_APP = sh(script: "trivy image --scanners vuln --vuln-type library --severity HIGH --format json ${IMAGE_NAME} | grep -o '\"VulnerabilityID\"' | wc -l || echo 0", returnStdout: true).trim()
                    env.T_SAPP = (System.currentTimeMillis()-sc2)/1000

                    // C. Scan de Configuration (IaC)
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
                // Qualité & Health
                env.SMELLS = sh(script: "sh ./mvnw checkstyle:check || true && grep -r '<error' target/checkstyle-result.xml | wc -l || echo 0", returnStdout: true).trim()
                sh "docker compose up -d && sleep 40"
                def h_code = sh(script: "curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/ || echo 000", returnStdout: true).trim()
                def total_t = (System.currentTimeMillis() - env.START_P.toLong()) / 1000

                // Export des 23 métriques (build_id + 22 valeurs)
                def data = "${env.BUILD_ID},${total_t},${env.T_CTX},${env.T_LOG},${env.T_OWN},${env.T_VET},${env.T_VIS},${env.T_IT},${env.T_SOS},${env.T_SAPP},${env.T_SCONF},${env.CPU},${env.RAM},${env.DISK},${env.F_UNIT},${env.F_OWN},${env.F_VET},${env.F_VIS},${env.F_IT},${env.SMELLS},${env.V_OS},${env.V_APP},${env.V_CONF},${h_code}"
                sh "./collect_metrics.sh ${data}"

                if (env.BUILD_NUMBER.toInteger() < env.MAX_BUILDS.toInteger()) {
                    build job: env.JOB_NAME, wait: false
                }
            }
        }
    }
}