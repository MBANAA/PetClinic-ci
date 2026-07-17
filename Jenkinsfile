pipeline {
    agent any
 
    triggers {
        cron('H/30 * * * *')
    }
 
    environment {
        IMAGE_NAME  = 'petclinic-app'
        DATASET_CSV = 'metrics_dataset.csv'
 
        // --- CORRECTIFS RÉSEAU & TESTCONTAINERS ---
        TESTCONTAINERS_RYUK_DISABLED = 'true'
        DOCKER_HOST = 'unix:///var/run/docker.sock'
        TESTCONTAINERS_HOST_IP = '127.0.0.1'
        TESTCONTAINERS_REUSE_ENABLE = 'true'
 
        // --- CACHE MAVEN PERSISTANT (hors workspace pour survivre entre builds) ---
        MAVEN_OPTS = '-Dmaven.repo.local=/var/jenkins_cache/.m2/repository'
    }
 
    options {
        buildDiscarder(logRotator(numToKeepStr: '20'))
        disableConcurrentBuilds()
        timestamps()
    }
 
    stages {
        stage('📊 1. Init & Chaos') {
            steps {
                script {
                    env.START_P = System.currentTimeMillis().toString()
 
                    def gitDiff = sh(script: "git diff --shortstat HEAD~1 HEAD 2>/dev/null || echo '0 files changed, 0 insertions, 0 deletions'", returnStdout: true).trim()
 
                    env.INSERTIONS = sh(script: "echo '${gitDiff}' | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo '0'", returnStdout: true).trim()
                    env.DELETIONS  = sh(script: "echo '${gitDiff}' | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo '0'", returnStdout: true).trim()
 
                    // Collecte CPU/RAM/DISK en une seule passe légère
                    env.CPU  = sh(script: "top -bn1 | grep 'Cpu(s)' | awk '{print 100 - \$8}' 2>/dev/null || echo '10'", returnStdout: true).trim()
                    env.RAM  = sh(script: "free | grep Mem | awk '{print \$3/\$2 * 100.0}' 2>/dev/null || echo '15'", returnStdout: true).trim()
                    env.DISK = sh(script: "df / | tail -1 | awk '{print \$5}' | sed 's/%//' 2>/dev/null || echo '20'", returnStdout: true).trim()
 
                    sh "docker compose down -v || true"
                    sh "./mvnw -B -T 1C clean"
 
                    if (fileExists('scripts/chaos_engine.sh')) {
                        sh "chmod +x scripts/chaos_engine.sh && ./scripts/chaos_engine.sh || true"
                    }
                }
            }
        }
 
        stage('🧪🛡️ 2. Tests & Sécurité (parallèle)') {
            parallel {
                stage('Tests Unitaires') {
                    steps {
                        catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                            sh "./mvnw -B test -Dtest='*Tests' -DfailIfNoTests=false -Dmaven.test.failure.ignore=true"
                        }
                        script {
                            // Échappement correct du signe $ pour awk dans une double quote Jenkins
                            env.F_UNIT = sh(script: """
                                grep -ohE 'failures="[0-9]+"|errors="[0-9]+"' target/surefire-reports/*.xml 2>/dev/null \
                                | grep -o '[0-9]*' | awk '{s+=\$1} END {print s+0}' || echo '0'
                            """, returnStdout: true).trim()
 
                            env.S_UNIT = sh(script: """
                                grep -ohE 'skipped="[0-9]+"' target/surefire-reports/*.xml 2>/dev/null \
                                | grep -o '[0-9]*' | awk '{s+=\$1} END {print s+0}' || echo '0'
                            """, returnStdout: true).trim()
                        }
                    }
                }
 
                stage('Tests Intégration') {
                    steps {
                        catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                            sh """
                                ./mvnw -B test \
                                -Dtest='*IntegrationTests,!PostgresIntegrationTests' \
                                -Dspring.profiles.active=mysql \
                                -DfailIfNoTests=false \
                                -Dmaven.test.failure.ignore=true \
                                -Dtestcontainers.container.startup.timeout=180 \
                                -Dtestcontainers.use.host.network=true
                            """
                        }
                        script {
                            env.F_IT = sh(script: """
                                grep -ohE 'failures="[0-9]+"|errors="[0-9]+"' target/surefire-reports/*IntegrationTests.xml target/surefire-reports/*MySql*.xml 2>/dev/null \
                                | grep -o '[0-9]*' | awk '{s+=\$1} END {print s+0}' || echo '0'
                            """, returnStdout: true).trim()
 
                            env.S_IT = sh(script: """
                                grep -ohE 'skipped="[0-9]+"' target/surefire-reports/*IntegrationTests.xml target/surefire-reports/*MySql*.xml 2>/dev/null \
                                | grep -o '[0-9]*' | awk '{s+=\$1} END {print s+0}' || echo '0'
                            """, returnStdout: true).trim()
                        }
                    }
                }
 
                stage('Build Image + Trivy') {
                    steps {
                        catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                            sh "DOCKER_BUILDKIT=1 docker build --cache-from ${IMAGE_NAME}:latest -t ${IMAGE_NAME} -t ${IMAGE_NAME}:latest ."
                        }
                        script {
                            def trivyCmd = "docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy-cache:/root/.cache/ aquasec/trivy:latest image --severity HIGH,CRITICAL --format json --quiet ${IMAGE_NAME}"
                            env.V_OS = sh(script: "${trivyCmd} 2>/dev/null | grep -o '\"VulnerabilityID\"' | wc -l || echo '0'", returnStdout: true).trim()
                        }
                    }
                }
            }
        }
 
        stage('🚀 3. Smoke Test') {
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    script {
                        sh "docker compose up -d --wait --wait-timeout 60 petclinic-mysql petclinic-app"
 
                        def httpCode = sh(script: "curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/ || echo 000", returnStdout: true).trim()
 
                        if (!(httpCode in ['200', '302', '403'])) {
                            for (int i = 0; i < 3; i++) {
                                sleep 3
                                httpCode = sh(script: "curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/ || echo 000", returnStdout: true).trim()
                                if (httpCode in ['200', '302', '403']) { break }
                            }
                        }
                        env.H_CODE = httpCode
 
                        if (httpCode == '000') {
                            echo "⚠️ L'application n'a pas répondu à temps. Extraction des logs :"
                            sh "docker compose logs petclinic-app --tail 50 || true"
                        } else {
                            echo "🎯 Smoke Test réussi ! Code HTTP : ${httpCode}"
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
 
                sh "./mvnw -B checkstyle:check -Dcheckstyle.failOnViolation=false || true"
                def smells = 0
                if (fileExists('target/checkstyle-result.xml')) {
                    def smellsRaw = sh(script: "grep -c '<error' target/checkstyle-result.xml 2>/dev/null || echo 0", returnStdout: true).trim()
                    smells = smellsRaw.toInteger()
                }
 
                // Utilisation systématique de valeurs par défaut pour éviter les null pointer exceptions
                def failUnit = (env.F_UNIT ?: '0').toInteger()
                def failIt   = (env.F_IT   ?: '0').toInteger()
                def httpCode  = env.H_CODE ?: '000'
 
                def finalStatus = 'SUCCESS'
                def appIsUp = (httpCode == '200' || httpCode == '302' || httpCode == '403')
 
                if (!appIsUp) {
                    finalStatus = 'FAILURE'
                } else if (failUnit > 5 || failIt > 5) {
                    finalStatus = 'FAILURE'
                } else if (failUnit > 0 || failIt > 0 || smells > 200) {
                    finalStatus = 'UNSTABLE'
                } else {
                    finalStatus = 'SUCCESS'
                }
 
                currentBuild.result = finalStatus
 
                // Calcul robuste du temps de run
                def startTime = env.START_P ? env.START_P.toLong() : System.currentTimeMillis()
                def total_t = (System.currentTimeMillis() - startTime) / 1000
                
                def row = [
                    env.BUILD_ID,
                    total_t,
                    env.CPU        ?: '0',
                    env.RAM        ?: '0',
                    env.DISK       ?: '0',
                    env.INSERTIONS ?: '0',
                    env.DELETIONS  ?: '0',
                    failUnit,
                    env.S_UNIT     ?: '0',
                    failIt,
                    env.S_IT       ?: '0',
                    smells,
                    env.V_OS       ?: '0',
                    httpCode,
                    finalStatus
                ].join(',')
 
                def header = 'build_id,duration_s,cpu_pct,ram_pct,disk_pct,lines_added,lines_deleted,fail_unit,skip_unit,fail_it,skip_it,checkstyle_smells,vuln_high,http_code,build_status'
 
                if (!fileExists(env.DATASET_CSV)) {
                    writeFile file: env.DATASET_CSV, text: header + '\n'
                }
                sh "echo '${row}' >> ${env.DATASET_CSV}"
 
                archiveArtifacts artifacts: "${env.DATASET_CSV}", allowEmptyArchive: true
 
                if (fileExists('collect_metrics.sh')) {
                    sh "chmod +x collect_metrics.sh && ./collect_metrics.sh ${row} || true"
                }
 
                echo "✅ Run enregistré avec succès. Statut assigné : ${finalStatus}. Métriques : ${row}"
            }
        }
        cleanup {
            sh "docker compose down -v || true"
            sh "docker system prune -f --filter 'until=6h' || true"
        }
    }
}