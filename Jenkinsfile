pipeline {
    agent any
 
    environment {
        IMAGE_NAME  = 'petclinic-app'
        DATASET_CSV = 'metrics_dataset.csv'
        // Ryuk gère le nettoyage automatique des conteneurs de test en tâche de fond
        TESTCONTAINERS_RYUK_DISABLED = 'false'
    }
 
    stages {
        stage('📊 1. Init & Chaos') {
            steps {
                script {
                    env.START_P = System.currentTimeMillis().toString()
                    
                    echo "📊 Collecte des ressources système de l'agent..."
                    
                    // Échantillonnage CPU sur 3 secondes pour un compromis idéal vitesse/précision
                    env.CPU = sh(script: """
                        sar 1 3 | tail -1 | awk '{print 100 - \$NF}' 2>/dev/null || \
                        top -bn3 -d1 | grep 'Cpu(s)' | awk '{sum+=\$8} END {print 100 - (sum/3)}' 2>/dev/null || \
                        echo '10'
                    """, returnStdout: true).trim()
                    
                    env.RAM = sh(script: """
                        free | grep Mem | awk '{print \$3/\$2 * 100.0}' 2>/dev/null || echo '15'
                    """, returnStdout: true).trim()
                    
                    env.DISK = sh(script: """
                        df / | tail -1 | awk '{print \$5}' | sed 's/%//' 2>/dev/null || echo '20'
                    """, returnStdout: true).trim()
 
                    // Nettoyage initial préventif
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
                    // Extraction des échecs (failures + errors)
                    env.F_UNIT = sh(script: """
                        grep -ohE 'failures="[0-9]+"|errors="[0-9]+"' target/surefire-reports/*.xml 2>/dev/null \
                        | grep -o '[0-9]*' | awk '{s+=\$1} END {print s+0}' || echo '0'
                    """, returnStdout: true).trim()
                    
                    // Extraction des tests skippés
                    env.S_UNIT = sh(script: """
                        grep -ohE 'skipped="[0-9]+"' target/surefire-reports/*.xml 2>/dev/null \
                        | grep -o '[0-9]*' | awk '{s+=\$1} END {print s+0}' || echo '0'
                    """, returnStdout: true).trim()
                }
            }
        }
 
        stage('🧪 2b. Tests d\'Intégration') {
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    // Profil MySQL activé pour correspondre à PetClinic
                    sh "./mvnw test -Dtest='*IntegrationTests,!PostgresIntegrationTests' -Dspring.profiles.active=mysql -DfailIfNoTests=false -Dmaven.test.failure.ignore=true"
                }
                script {
                    // Extraction des échecs d'intégration
                    env.F_IT = sh(script: """
                        grep -ohE 'failures="[0-9]+"|errors="[0-9]+"' target/surefire-reports/*IntegrationTests.xml 2>/dev/null \
                        | grep -o '[0-9]*' | awk '{s+=\$1} END {print s+0}' || echo '0'
                    """, returnStdout: true).trim()
                    
                    // Extraction des tests d'intégration skippés
                    env.S_IT = sh(script: """
                        grep -ohE 'skipped="[0-9]+"' target/surefire-reports/*IntegrationTests.xml 2>/dev/null \
                        | grep -o '[0-9]*' | awk '{s+=\$1} END {print s+0}' || echo '0'
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
                    env.V_OS = sh(script: "${trivyCmd} 2>/dev/null | grep -o '\"VulnerabilityID\"' | wc -l || echo '0'", returnStdout: true).trim()
                }
            }
        }
 
        stage('🚀 4. Smoke Test') {
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    script {
                        // Lancement des conteneurs avec attente de leur état "healthy"
                        sh "docker compose up -d --wait petclinic-mysql petclinic-app"
 
                        def httpCode = '000'
                        // Boucle de vérification de l'état de l'application (10 essais max)
                        for (int i = 0; i < 10; i++) {
                            httpCode = sh(script: "curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/ || echo 000", returnStdout: true).trim()
                            
                            // 200, 302 (redirection vers login) ou 403 (sécurisé) confirment que Spring Boot écoute et tourne !
                            if (httpCode == '200' || httpCode == '302' || httpCode == '403') { 
                                echo "🎯 Smoke Test réussi avec succès ! L'application répond avec le code : ${httpCode}"
                                break 
                            }
                            sleep 3
                        }
                        env.H_CODE = httpCode
 
                        if (httpCode == '000') {
                            echo "⚠️ L'application n'a pas répondu à temps. Extraction des logs :"
                            sh "docker compose logs petclinic-app --tail 50 || true"
                        }
 
                        // Nettoyage immédiat des conteneurs du Smoke Test
                        sh "docker compose down -v || true"
                    }
                }
            }
        }
    }
 
    post {
        always {
            script {
                // Enregistrement des rapports de tests JUnit dans Jenkins
                junit testResults: 'target/surefire-reports/*.xml', allowEmptyResults: true
 
                // Analyse Checkstyle (ne fait jamais échouer le pipeline)
                sh "./mvnw checkstyle:check || true"
                def smells = '0'
                if (fileExists('target/checkstyle-result.xml')) {
                    smells = sh(script: "grep -c '<error' target/checkstyle-result.xml 2>/dev/null || echo 0", returnStdout: true).trim()
                }
 
                def total_t = (System.currentTimeMillis() - env.START_P.toLong()) / 1000
                def status  = currentBuild.currentResult ?: 'UNKNOWN'
 
                // Formatage de la ligne de données pour notre dataset
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
 
                // En-tête du fichier CSV
                def header = 'build_id,duration_s,cpu_pct,ram_pct,disk_pct,fail_unit,skip_unit,fail_it,skip_it,checkstyle_smells,vuln_high,http_code,build_status'
 
                if (!fileExists(env.DATASET_CSV)) {
                    writeFile file: env.DATASET_CSV, text: header + '\n'
                }
                sh "echo '${row}' >> ${env.DATASET_CSV}"
 
                // Sauvegarde du dataset dans les artefacts Jenkins
                archiveArtifacts artifacts: "${env.DATASET_CSV}", allowEmptyArchive: true
 
                if (fileExists('collect_metrics.sh')) {
                    sh "chmod +x collect_metrics.sh && ./collect_metrics.sh ${row} || true"
                }
 
                echo "✅ Run enregistré avec succès. Statut : ${status}. Entrée dataset : ${row}"
            }
        }
        cleanup {
            // Nettoyage final pour libérer de l'espace sur l'agent
            sh "docker compose down -v || true"
            sh "docker system prune -f --filter 'until=1h' || true"
        }
    }
}