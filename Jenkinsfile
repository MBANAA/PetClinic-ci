
pipeline {
    agent any
 
    environment {
        TESTCONTAINERS_RYUK_DISABLED = 'true'
        IMAGE_NAME  = 'petclinic-app'
        DATASET_CSV = 'metrics_dataset.csv'
    }
 
    stages {
        stage('📊 1. Init & Chaos') {
            steps {
                script {
                    env.START_P = System.currentTimeMillis().toString()
                    env.CPU  = sh(script: "top -bn1 | grep 'Cpu(s)' | awk '{print 100 - \$8}'", returnStdout: true).trim()
                    env.RAM  = sh(script: "free | grep Mem | awk '{print \$3/\$2 * 100.0}'", returnStdout: true).trim()
                    env.DISK = sh(script: "df / | tail -1 | awk '{print \$5}' | sed 's/%//'", returnStdout: true).trim()
 
                    sh "docker compose down -v || true"
                    sh "./mvnw -B clean"
 
                    if (fileExists('scripts/chaos_engine.sh')) {
                        sh "chmod +x scripts/chaos_engine.sh && ./scripts/chaos_engine.sh || true"
                    }
                }
            }
        }
 
        stage('🧪 2a. Tests Unitaires') {
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    sh "./mvnw test -Dtest='*Tests' -DfailIfNoTests=false -Dmaven.test.failure.ignore=true"
                }
                script {
                    env.F_UNIT = sh(script: "grep -l '<failure' target/surefire-reports/*.xml 2>/dev/null | wc -l", returnStdout: true).trim()
                }
            }
        }
 
        stage('🧪 2b. Tests d\'Intégration') {
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    sh "./mvnw test -Dtest='*IntegrationTests' -DfailIfNoTests=false -Dmaven.test.failure.ignore=true"
                }
                script {
                    env.F_IT = sh(script: "grep -l '<failure' target/surefire-reports/*.xml 2>/dev/null | wc -l", returnStdout: true).trim()
                }
            }
        }
 
        stage('🛡️ 3. Sécurité (Trivy)') {
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    sh "docker build -t ${IMAGE_NAME} ."
                }
                script {
                    def trivyCmd = "docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest image --severity HIGH,CRITICAL --format json --quiet ${IMAGE_NAME}"
                    env.V_OS = sh(script: "${trivyCmd} 2>/dev/null | grep -o '\"VulnerabilityID\"' | wc -l", returnStdout: true).trim()
                }
            }
        }
 
        stage('🚀 4. Smoke Test') {
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    script {
                        sh "docker compose up -d"
                        def httpCode = '000'
                        for (int i = 0; i < 10; i++) {
                            httpCode = sh(script: "curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/ || echo 000", returnStdout: true).trim()
                            if (httpCode == '200') { break }
                            sleep 3
                        }
                        env.H_CODE = httpCode
                        sh "docker compose down -v || true"
                    }
                }
            }
        }
    }
 
    post {
        always {
            script {
                junit testResults: 'target/surefire-reports/*.xml', allowEmptyResults: true
 
                sh "./mvnw checkstyle:check || true"
                def smells = '0'
                if (fileExists('target/checkstyle-result.xml')) {
                    smells = sh(script: "grep -c '<error' target/checkstyle-result.xml 2>/dev/null || echo 0", returnStdout: true).trim()
                }
 
                def total_t = (System.currentTimeMillis() - env.START_P.toLong()) / 1000
 
                // Ligne de métriques -> une ligne = une observation du dataset
                def row = [
                    env.BUILD_ID,
                    total_t,
                    env.CPU  ?: '0',
                    env.RAM  ?: '0',
                    env.DISK ?: '0',
                    env.F_UNIT ?: '0',
                    env.F_IT   ?: '0',
                    smells,
                    env.V_OS   ?: '0',
                    env.H_CODE ?: '000'
                ].join(',')
 
                def header = 'build_id,duration_s,cpu_pct,ram_pct,disk_pct,fail_unit,fail_it,checkstyle_smells,vuln_high,http_code'
 
                if (!fileExists(env.DATASET_CSV)) {
                    writeFile file: env.DATASET_CSV, text: header + '\n'
                }
                sh "echo '${row}' >> ${env.DATASET_CSV}"
 
                archiveArtifacts artifacts: "${env.DATASET_CSV}", allowEmptyArchive: true
 
                // Optionnel : script externe si présent (ex: envoi vers une BDD ou un stockage central)
                if (fileExists('collect_metrics.sh')) {
                    sh "chmod +x collect_metrics.sh && ./collect_metrics.sh ${row} || true"
                }
 
                echo "Build terminé. Dataset mis à jour : ${env.DATASET_CSV}"
            }
        }
        cleanup {
            sh "docker compose down -v || true"
        }
    }
}