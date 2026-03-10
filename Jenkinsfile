pipeline {
    agent any

    tools {
        maven 'Maven3'
        jdk 'JDK17'
    }

    environment {
        // Seuil de décision DP-003
        COVERAGE_THRESHOLD = 80 
        METRICS_FILE = 'pipeline-metrics.csv'
    }

    stages {
        // STAGE 1: Build & Compilation
        stage('Build') {
            steps {
                script {
                    def start = System.currentTimeMillis()
                    sh 'mvn clean compile'
                    def duration = (System.currentTimeMillis() - start) / 1000
                    sh "echo 'DP-007: Build Success, duration: ${duration}s' >> decision.log"
                }
            }
        }

        // STAGE 2: Tests Unitaires
        stage('Unit Tests') {
            steps {
                script {
                    try {
                        sh 'mvn test'
                        sh "echo 'DP-004: Unit Tests Passed' >> decision.log"
                    } catch (Exception e) {
                        sh "echo 'DP-004: Unit Tests Failed' >> decision.log"
                        error "Tests unitaires échoués"
                    }
                }
            }
            post {
                always {
                    junit '**/target/surefire-reports/*.xml'
                }
            }
        }

        // STAGE 3: Analyse Statique (Checkstyle & SpotBugs)
        stage('Static Analysis') {
            steps {
                sh 'mvn checkstyle:check spotbugs:check'
                sh "echo 'DP-005/006: Static Analysis Completed' >> decision.log"
            }
        }

        // STAGE 4: Tests d'Intégration
        stage('Integration Tests') {
            steps {
                sh 'mvn verify -DskipUnitTests'
                sh "echo 'DP-011: Integration Tests Completed' >> decision.log"
            }
        }

        // STAGE 5: Couverture de Code (JaCoCo)
        stage('Code Coverage') {
            steps {
                script {
                    sh 'mvn jacoco:report'
                    // Simulation du point de décision DP-003
                    sh """
                        echo "Decision Point: DP-003 - Coverage Threshold Check"
                        echo "Logic: coverage >= ${env.COVERAGE_THRESHOLD}%"
                    """
                }
            }
        }

        // STAGE 6: Packaging & Docker
        stage('Package') {
            steps {
                sh 'mvn package -DskipTests'
                sh 'docker compose build'
                sh "echo 'DP-009: Docker Image Created' >> decision.log"
            }
        }

        // STAGE 7: Déploiement (Conditionnel sur Branche Main)
        stage('Deploy') {
            when { branch 'main' }
            steps {
                sh 'docker compose up -d'
                sh "echo 'DP-002: Deployment Executed on Main' >> decision.log"
            }
        }
    }

    // Instrumentation : Collecte automatique des métriques à la fin de chaque run
    post {
        always {
            script {
                def status = currentBuild.result ?: 'SUCCESS'
                def timestamp = new Date().format("yyyy-MM-dd'T'HH:mm:ssZ")
                sh "echo '${timestamp},${BUILD_NUMBER},${status}' >> ${METRICS_FILE}"
                archiveArtifacts artifacts: 'decision.log, pipeline-metrics.csv', fingerprint: true
            }
        }
    }
}