import groovy.transform.Field

@Field def metrics = [
    // Contexte & Git
    branch: "unknown", commit: "unknown", author: "unknown", files_changed: "0", loc: "0",
    // Temps & Performance
    build_total_time: "0", test_time: "0", sys_cpu_load: "0", sys_ram_free: "0",
    // Qualité & Tests
    test_total: "0", test_fail: "0", test_skip: "0", coverage: "0", code_smells: "0",
    // Sécurité & Docker
    vuln_critical: "0", vuln_high: "0", docker_size: "0", health_code: "0"
]

pipeline {
    agent any

    environment {
        MAVEN_OPTS = '-Dspring.docker.compose.skip.in-tests=true'
        IMAGE_NAME = 'petclinic-app'
    }

    stages {
        stage('Initialisation & Nettoyage') {
            steps {
                script {
                    def startTotal = System.currentTimeMillis()
                    env.START_TIME = startTotal.toString()

                    // Nettoyer l'ancien dataset une seule fois pour corriger les titres (Optionnel après le 1er build)
                    // sh 'rm -f pipeline-data/global_dataset.csv'

                    sh 'sed -i "s/\\r//" mvnw collect_metrics.sh || true'
                    sh 'chmod +x mvnw collect_metrics.sh'
                    
                    // --- VARIABILITÉ POUR L'IA ---
                    // Ajoute une ligne de commentaire au hasard pour faire varier les LoC et le Commit
                    sh "echo '// AI Training Build: ${env.BUILD_ID}' >> src/main/java/org/springframework/samples/petclinic/PetClinicApplication.java"
                    
                    sh './mvnw clean'
                    
                    metrics.branch = env.BRANCH_NAME ?: "main"
                    metrics.commit = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                    metrics.author = sh(script: "git log -1 --format='%aN' | tr ' ' '_'", returnStdout: true).trim() ?: "unknown"
                    metrics.files_changed = sh(script: "git show --format='' --name-only | awk 'NF' | wc -l", returnStdout: true).trim() ?: "0"
                    metrics.loc = sh(script: "find src -name '*.java' | xargs wc -l | grep total | awk '{print \$1}' || echo '0'", returnStdout: true).trim()
                    
                    metrics.sys_cpu_load = sh(script: "uptime | awk -F'load average:' '{ print \$2 }' | awk '{print \$1}' | tr -d ','", returnStdout: true).trim() ?: "0"
                    metrics.sys_ram_free = sh(script: "free -m | awk '/^Mem:/{print \$4}'", returnStdout: true).trim() ?: "0"
                    
                    env.DOCKER_CMD = sh(script: "docker compose version >/dev/null 2>&1 && echo 'docker compose' || echo 'docker-compose'", returnStdout: true).trim()
                }
            }
        }

        stage('Analyse & Tests Parallèles') {
            parallel {
                stage('Analyse Statique') {
                    steps {
                        script {
                            try {
                                sh './mvnw checkstyle:check spotbugs:check pmd:check || true'
                                metrics.code_smells = sh(script: "grep -r '<error' target/*.xml 2>/dev/null | wc -l || echo '0'", returnStdout: true).trim()
                            } catch (e) { metrics.code_smells = "-1" }
                        }
                    }
                }
                stage('Tests Unitaires & Couverture') {
                    steps {
                        script {
                            def startTest = System.currentTimeMillis()
                            sh "./mvnw test jacoco:report -Dtest='!*IntegrationTests' -Dmaven.test.failure.ignore=true"
                            metrics.test_time = ((System.currentTimeMillis() - startTest) / 1000).toString()
                            
                            metrics.test_total = sh(script: "find target/surefire-reports/ -name '*.xml' -exec grep -l '<testcase' {} + | xargs grep -c '<testcase' | awk -F: '{sum += \$2} END {print sum}' || echo '0'", returnStdout: true).trim()
                            metrics.test_fail = sh(script: "find target/surefire-reports/ -name '*.xml' -exec grep -l '<failure' {} + | xargs grep -c '<failure' | awk -F: '{sum += \$2} END {print sum}' || echo '0'", returnStdout: true).trim()
                            metrics.test_skip = sh(script: "find target/surefire-reports/ -name '*.xml' -exec grep -l '<skipped' {} + | xargs grep -c '<skipped' | awk -F: '{sum += \$2} END {print sum}' || echo '0'", returnStdout: true).trim()
                            
                            def cov = sh(script: "if [ -f target/site/jacoco/jacoco.csv ]; then tail -n +2 target/site/jacoco/jacoco.csv | awk -F, '{instructions += \$4 + \$5; covered += \$5} END {print int(covered/instructions*100)}'; else echo '0'; fi", returnStdout: true).trim()
                            metrics.coverage = cov ?: "0"
                        }
                    }
                }
            }
        }

        stage('Docker & Sécurité Scan') {
            steps {
                script {
                    sh "${env.DOCKER_CMD} up -d --build"
                    def imageId = sh(script: "docker ps --filter name=${IMAGE_NAME} --format '{{.Image}}' | head -n 1", returnStdout: true).trim()
                    
                    if (imageId) {
                        // Nettoyage de l'unité MB/GB pour n'avoir que le chiffre
                        metrics.docker_size = sh(script: "docker images ${imageId} --format '{{.Size}}' | sed 's/MB//g; s/GB//g' | head -n 1", returnStdout: true).trim()
                        
                        metrics.vuln_critical = sh(script: "docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image --severity CRITICAL --quiet ${imageId} | grep 'Total: ' | grep -oE '[0-9]+' | head -n 1 || echo '0'", returnStdout: true).trim()
                        metrics.vuln_high = sh(script: "docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image --severity HIGH --quiet ${imageId} | grep 'Total: ' | grep -oE '[0-9]+' | head -n 1 || echo '0'", returnStdout: true).trim()
                    }
                }
            }
        }

        stage('Validation Healthcheck') {
            steps {
                script {
                    try {
                        echo "Waiting for application to be ready..."
                        sleep 45 // Augmenté pour éviter le code 000
                        def networkName = sh(script: "docker network ls --filter name=petclinic --format '{{.Name}}' | head -n 1", returnStdout: true).trim() ?: "bridge"
                        metrics.health_code = sh(script: "docker run --network ${networkName} curlimages/curl:latest -s -o /dev/null -w '%{http_code}' http://petclinic-app:8080 || echo '000'", returnStdout: true).trim()
                    } catch (e) { metrics.health_code = "500" }
                }
            }
        }
    }

    post {
        always {
            script {
                metrics.build_total_time = ((System.currentTimeMillis() - env.START_TIME.toLong()) / 1000).toString()
                
                sh "mkdir -p pipeline-data"
                
                def args = [
                    env.BUILD_ID,
                    metrics.branch,
                    metrics.commit,
                    metrics.author,
                    metrics.files_changed,
                    metrics.loc,
                    metrics.build_total_time,
                    metrics.test_time,
                    metrics.sys_cpu_load,
                    metrics.sys_ram_free,
                    metrics.test_total,
                    metrics.test_fail,
                    metrics.test_skip,
                    metrics.coverage,
                    metrics.code_smells,
                    metrics.vuln_critical,
                    metrics.vuln_high,
                    metrics.docker_size,
                    metrics.health_code
                ].join(' ')

                sh "./collect_metrics.sh ${args}"
            }
            archiveArtifacts artifacts: 'pipeline-data/*.csv', allowEmptyArchive: true
        }
    }
}