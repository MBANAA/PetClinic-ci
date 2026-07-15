pipeline {
    agent any
 
    environment {
        IMAGE_NAME  = 'petclinic-app'
        DATASET_CSV = 'metrics_dataset.csv'
        // Urgent : Évite la dérive des ressources et nettoie les conteneurs orphelins
        TESTCONTAINERS_RYUK_DISABLED = 'true'
    }
 
    stages {
        stage('📊 1. Init & Chaos') {
            steps {
                script {
                    env.START_P = System.currentTimeMillis().toString()
                    
                    // Échantillonnage CPU sur 5 secondes pour une moyenne fiable (évite le 0% ponctuel)
                    echo "Calcul de la moyenne CPU en cours (échantillonnage 5s)..."
                    env.CPU = sh(script: """
                        sar 1 5 | tail -1 | awk '{print 100 - \$NF}' 2>/dev/null || \
                        top -bn5 -d1 | grep 'Cpu(s)' | awk '{sum+=\$8} END {print 100 - (sum/5)}'
                    """, returnStdout: true).trim()
                    
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
                    // Compte failures + errors
                    env.F_UNIT = sh(script: """
                        grep -ohE 'failures="[0-9]+"|errors="[0-9]+"' target/surefire-reports/*.xml 2>/dev/null \
                        | grep -o '[0-9]*' | awk '{s+=\$1} END {print s+0}'
                    """, returnStdout: true).trim()
                    
                    // Compte les tests skippés
                    env.S_UNIT = sh(script: """
                        grep -ohE 'skipped="[0-9]+"' target/surefire-reports/*.xml 2>/dev/null \
                        | grep -o '[0-9]*' | awk '{s+=\$1} END {print s+0}'
                    """, returnStdout: true).trim()
                }
            }
        }
 
        stage('🧪 2b. Tests d\'Intégration') {
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    // Activation explicite du profil mysql pour s'aligner avec l'infra cible
                    sh "./mvnw test -Dtest='*IntegrationTests,!PostgresIntegrationTests' -Dspring.profiles.active=mysql -DfailIfNoTests=false -Dmaven.test.failure.ignore=true"
                }
                script {
                    // Compte failures + errors
                    env.F_IT = sh(script: """
                        grep -ohE 'failures="[0-9]+"|errors="[0-9]+"' target/surefire-reports/*IntegrationTests.xml 2>/dev/null \
                        | grep -o '[0-9]*' | awk '{s+=\$1} END {print s+0}'
                    """, returnStdout: true).trim()
                    
                    // Compte les tests skippés
                    env.S_IT = sh(script: """
                        grep -ohE 'skipped="[0-9]+"' target/surefire-reports/*IntegrationTests.xml 2>/dev/null \
                        | grep -o '[0-9]*' | awk '{s+=\$1} END {print s+0}'
                    """, returnStdout: true).trim()
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
                        sh "docker compose up -d --wait petclinic-mysql petclinic-app"
 
                        def httpCode = '000'
                        for (int i = 0; i < 10; i++) {
                            // Ciblage de /actuator/health pour éviter le 403 potentiel de l'index
                            httpCode = sh(script: "curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/actuator/health || echo 000", returnStdout: true).trim()
                            if (httpCode == '200') { break }
                            sleep 3
                        }
                        env.H_CODE = httpCode
 
                        if (httpCode != '200') {
                            echo "⚠️ Code HTTP inattendu (${httpCode}). Logs de l'app :"
                            sh "docker compose logs petclinic-app --tail 50 || true"
                        }
 
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
                def status  = currentBuild.currentResult ?: 'UNKNOWN'
 
                // Ligne CSV ordonnée avec les tests skippés
                def row = [
                    env.BUILD_ID,
                    total_t,
                    env.CPU  ?: '0',
                    env.RAM  ?: '0',
                    env.DISK ?: '0',
                    env.F_UNIT ?: '0',
                    env.S_UNIT ?: '0',
                    env.F_IT   ?: '0',
                    env.S_IT   ?: '0',
                    smells,
                    env.V_OS  ?: '0',
                    env.H_CODE ?: '000',
                    status
                ].join(',')
 
                // En-tête mis à jour du CSV
                def header = 'build_id,duration_s,cpu_pct,ram_pct,disk_pct,fail_unit,skip_unit,fail_it,skip_it,checkstyle_smells,vuln_high,http_code,build_status'
 
                if (!fileExists(env.DATASET_CSV)) {
                    writeFile file: env.DATASET_CSV, text: header + '\n'
                }
                sh "echo '${row}' >> ${env.DATASET_CSV}"
 
                archiveArtifacts artifacts: "${env.DATASET_CSV}", allowEmptyArchive: true
 
                if (fileExists('collect_metrics.sh')) {
                    sh "chmod +x collect_metrics.sh && ./collect_metrics.sh ${row} || true"
                }
 
                echo "Build terminé (${status}). Dataset mis à jour : ${env.DATASET_CSV}"
            }
        }
        cleanup {
            sh "docker compose down -v || true"
            sh "docker system prune -f --filter 'until=1h' || true"
        }
    }
}