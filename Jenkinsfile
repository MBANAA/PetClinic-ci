pipeline {
    agent any
 
    triggers {
        cron('H * * * *')
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
        // Adaptez ce chemin à votre agent (doit être accessible en écriture et persister).
        MAVEN_OPTS = '-Dmaven.repo.local=/var/jenkins_cache/.m2/repository'
    }
 
    options {
        // Évite de garder des dizaines de vieux builds/artefacts qui ralentissent le SCM checkout
        buildDiscarder(logRotator(numToKeepStr: '20'))
        // Empêche deux runs concurrents de se marcher dessus sur docker compose
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
 
                    // Collecte CPU/RAM/DISK en une seule passe légère (évite sar 3s + top 3s = 6s perdues)
                    env.CPU  = sh(script: "top -bn1 | grep 'Cpu(s)' | awk '{print 100 - \$8}' 2>/dev/null || echo '10'", returnStdout: true).trim()
                    env.RAM  = sh(script: "free | grep Mem | awk '{print \$3/\$2 * 100.0}' 2>/dev/null || echo '15'", returnStdout: true).trim()
                    env.DISK = sh(script: "df / | tail -1 | awk '{print \$5}' | sed 's/%//' 2>/dev/null || echo '20'", returnStdout: true).trim()
 
                    sh "docker compose down -v || true"
 
                    // Pas de -o (offline) : avec un .m2 persistant (MAVEN_OPTS ci-dessus), Maven ne
                    // retélécharge déjà pas ce qui est en cache local, donc -o n'apporte rien de plus
                    // et casse le build tant que tous les plugins (checkstyle, javaformat...) n'ont
                    // pas encore été mis en cache au moins une fois.
                    // -T 1C : build multi-thread (utile si le pom a plusieurs modules ou plugins).
                    sh "./mvnw -B -T 1C clean"
 
                    if (fileExists('scripts/chaos_engine.sh')) {
                        sh "chmod +x scripts/chaos_engine.sh && ./scripts/chaos_engine.sh || true"
                    }
                }
            }
        }
 
        // Les tests, le build Docker et le scan de sécurité ne dépendent pas les uns des autres
        // (le build de l'image ne dépend pas du résultat des tests dans ce pipeline) : on les parallélise.
        stage('🧪🛡️ 2. Tests & Sécurité (parallèle)') {
            parallel {
                stage('Tests Unitaires') {
                    steps {
                        catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                            sh "./mvnw -B test -Dtest='*Tests' -DfailIfNoTests=false -Dmaven.test.failure.ignore=true"
                        }
                        script {
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
                            // BuildKit + cache pour réutiliser les layers d'un run à l'autre
                            sh "DOCKER_BUILDKIT=1 docker build --cache-from ${IMAGE_NAME}:latest -t ${IMAGE_NAME} -t ${IMAGE_NAME}:latest ."
                        }
                        script {
                            // Volume de cache pour la base de vulnérabilités Trivy : évite de la
                            // retélécharger à chaque run (souvent le plus gros poste de temps de ce stage).
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
                        // docker compose --wait attend déjà que le healthcheck passe : plus besoin
                        // d'une boucle de 15 essais x 3s (45s max). On garde un filet de sécurité court.
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
 
                // Le cache .m2 persistant (MAVEN_OPTS) évite déjà de retélécharger le plugin checkstyle
                // d'un run à l'autre, sans besoin de forcer le mode offline.
                sh "./mvnw -B checkstyle:check -Dcheckstyle.failOnViolation=false || true"
                def smells = 0
                if (fileExists('target/checkstyle-result.xml')) {
                    def smellsRaw = sh(script: "grep -c '<error' target/checkstyle-result.xml 2>/dev/null || echo 0", returnStdout: true).trim()
                    smells = smellsRaw.toInteger()
                }
 
                def failUnit = (env.F_UNIT ?: '0').toInteger()
                def failIt    = (env.F_IT   ?: '0').toInteger()
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
 
                def total_t = (System.currentTimeMillis() - env.START_P.toLong()) / 1000
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
            // until=6h au lieu de 1h : on garde le cache de build Docker plus longtemps
            // pour que --cache-from serve vraiment au run suivant.
            sh "docker system prune -f --filter 'until=6h' || true"
        }
    }
}