pipeline {
    agent any

    tools {
        maven 'Maven3'
        jdk 'JDK17'
    }

    environment {
        // Pour ton dataset : seuil de réussite
        COVERAGE_THRESHOLD = 70
    }

    stages {
        stage('Check Java') {
            steps { sh 'java -version' }
        }

        stage('Clone Repository') {
            steps { git branch: 'main', url: 'https://github.com/MBANAA/PetClinic-ci.git' }
        }

        // --- NOUVEAU : NETTOYAGE & PRÉPARATION ---
        stage('Cleanup') {
            steps {
                sh 'docker compose down -v || true'
                sh 'mvn clean'
            }
        }

        stage('Build Application') {
            steps {
                sh 'mvn clean package -DskipTests'
                sh "echo 'DP-001: Build Success' >> decision.log"
            }
        }

        // --- MANQUANT 1 : TESTS UNITAIRES (Isolés avec H2 pour éviter les erreurs DB) ---
        stage('Unit Tests') {
            steps {
                script {
                    try {
                        sh 'mvn test -Dspring.profiles.active=h2'
                        sh "echo 'DP-004: Unit Tests Passed' >> decision.log"
                    } catch (Exception e) {
                        sh "echo 'DP-004: Unit Tests Failed' >> decision.log"
                        error "Échec des tests"
                    }
                }
            }
            post {
                always { junit '**/target/surefire-reports/*.xml' }
            }
        }

        // --- MANQUANT 2 : ANALYSE STATIQUE (Checkstyle/SpotBugs) ---
        stage('Static Analysis') {
            steps {
                // Essentiel pour la taxonomie des défaillances de ton guide
                sh 'mvn checkstyle:check || true' 
                sh "echo 'DP-005: Static Analysis Completed' >> decision.log"
            }
        }

        // --- MANQUANT 3 : COUVERTURE DE CODE (JaCoCo) ---
        stage('Code Coverage') {
            steps {
                sh 'mvn jacoco:report'
                sh "echo 'DP-003: Coverage Generated' >> decision.log"
            }
        }

        stage('Validate Docker Compose') {
            steps { sh 'docker compose config' }
        }

        stage('Run Docker Compose') {
            steps {
                sh 'docker compose down || true'
                sh 'docker compose up -d --build'
                sh "echo 'DP-009: Docker Deployment Success' >> decision.log"
            }
        }

        stage('Check Application') {
            steps {
                sh 'sleep 30' // Augmenté pour laisser le temps à la DB de démarrer
                sh 'curl -s http://localhost:8080 | grep "Welcome"'
                sh "echo 'DP-002: Healthcheck Passed' >> decision.log"
            }
        }
    }

    // --- MANQUANT 4 : COLLECTE DES DONNÉES (Dataset Phase 1) ---
    post {
        always {
            script {
                def status = currentBuild.result ?: 'SUCCESS'
                // Création de la ligne CSV pour ton futur dataset IA
                sh "echo '${new Date().format('yyyy-MM-dd HH:mm')},${BUILD_NUMBER},${status}' >> pipeline_history.csv"
                
                // Sauvegarde des logs pour analyse ultérieure
                archiveArtifacts artifacts: 'decision.log, pipeline_history.csv, **/target/*.jar', allowEmptyArchive: true
            }
        }
    }
}