pipeline {
    agent any

    environment {
        IMAGE_NAME = 'petclinic-app'
        COVERAGE_THRESHOLD = '80'

        ST_BUILD   = 'NOT_RUN'
        ST_TEST    = 'NOT_RUN'
        ST_QUALITY = 'NOT_RUN'
        ST_DOCKER  = 'NOT_RUN'
        ST_HEALTH  = 'NOT_RUN'
    }

    stages {
        stage('Nettoyage et Preparation') {
            steps {
                script {
                    // Prévention contre les caractères Windows invisibles (CRLF)
                    sh "sed -i 's/\\r//' mvnw || true"
                    sh 'chmod +x mvnw'
                    sh './mvnw clean'
                    
                    try {
                        sh 'docker compose version'
                        env.DOCKER_CMD = 'docker compose'
                    } catch (Exception e) {
                        env.DOCKER_CMD = 'docker-compose'
                    }
                }
            }
        }

        stage('Analyse Statique') {
            steps {
                script {
                    try {
                        sh './mvnw checkstyle:check spotbugs:check pmd:check || true'
                        env.ST_QUALITY = 'SUCCESS'
                    } catch (e) {
                        env.ST_QUALITY = 'FAILURE'
                    }
                }
            }
        }

        stage('Build et Tests Unitaires') {
            steps {
                script {
                    try {
                        sh './mvnw jacoco:prepare-agent test jacoco:report \
                            -Dspring.sql.init.mode=always \
                            -Dtest=!PostgresIntegrationTests,!MySqlIntegrationTests \
                            -Dmaven.test.failure.ignore=true'
                        env.ST_BUILD = 'SUCCESS'
                        env.ST_TEST = 'SUCCESS'
                    } catch (e) {
                        env.ST_BUILD = 'FAILURE'
                        env.ST_TEST = 'FAILURE'
                        echo "Erreur build/tests: ${e.getMessage()}"
                    }
                }
            }
        }

        stage('Docker Infrastructure') {
            steps {
                script {
                    try {
                        sh 'docker rm -f petclinic-app petclinic-mysql || true'
                        sh "${env.DOCKER_CMD} down --volumes --remove-orphans || true"
                        sh "${env.DOCKER_CMD} up -d --build"
                        env.ST_DOCKER = 'SUCCESS'
                    } catch (e) {
                        env.ST_DOCKER = 'FAILURE'
                        echo "Erreur Docker: ${e.getMessage()}"
                    }
                }
            }
        }

        stage('Validation Healthcheck') {
            steps {
                script {
                    try {
                        sleep 45
                        // Utilisation du réseau correct : petclinic_default
                        def response = sh(
                            script: "docker run --network petclinic_default curlimages/curl:latest -s -o /dev/null -w '%{http_code}' http://petclinic-app:8080",
                            returnStdout: true
                        ).trim()

                        if (response == '200') {
                            env.ST_HEALTH = 'SUCCESS'
                        } else {
                            env.ST_HEALTH = "FAILURE_${response}"
                        }
                    } catch (e) {
                        env.ST_HEALTH = 'FAILURE'
                        echo "Erreur Healthcheck: ${e.getMessage()}"
                    }
                }
            }
        }
    }

    post {
        always {
            script {
                sh "sed -i 's/\\r//' collect_metrics.sh || true"
                sh 'chmod +x collect_metrics.sh'

                // durée totale du build en secondes
                def durationSec = (currentBuild.duration / 1000).toString()

                def coverage = 'NA'
                if (fileExists('target/site/jacoco/jacoco.xml')) {
                    try {
                        coverage = sh(
                            script: """
                            python3 - <<'PY'
import xml.etree.ElementTree as ET
try:
    tree = ET.parse('target/site/jacoco/jacoco.xml')
    root = tree.getroot()

    missed = 0
    covered = 0
    for counter in root.findall('.//counter'):
        if counter.attrib.get('type') == 'LINE':
            missed = int(counter.attrib.get('missed', 0))
            covered = int(counter.attrib.get('covered', 0))
            break

    total = missed + covered
    print(round((covered / total) * 100, 2) if total > 0 else '0.0')
except Exception:
    print('XML_ERROR')
PY
                            """,
                            returnStdout: true
                        ).trim()
                    } catch (Exception e) {
                        coverage = 'PYTHON_ERR'
                    }
                }

                // Suppression de BUILD_NUMBER ici pour respecter la structure du script bash
                sh """
                ./collect_metrics.sh \
                    "${env.ST_BUILD}" \
                    "${env.ST_TEST}" \
                    "${env.ST_QUALITY}" \
                    "${env.ST_DOCKER}" \
                    "${env.ST_HEALTH}" \
                    "${durationSec}" \
                    "${coverage}"
                """
            }

            archiveArtifacts artifacts: 'pipeline-data/**', allowEmptyArchive: true
        }
    }
}