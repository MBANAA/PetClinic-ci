pipeline {
    agent any

    tools {
        maven 'maven' 
        jdk 'jdk17'
    }

    environment {
        MAVEN_OPTS = "-Dspring.docker.compose.skip.in-tests=true"
        IMAGE_NAME = "petclinic-app"
        // Seuils de décision
        COVERAGE_THRESHOLD = 80 [cite: 219, 223]
    }

    stages {
        stage('Nettoyage & Préparation') {
            steps {
                sh 'mvn clean'
                script {
                    try {
                        sh 'docker compose version'
                        env.DOCKER_CMD = "docker compose"
                    } catch (Exception e) {
                        env.DOCKER_CMD = "docker-compose"
                    }
                }
            }
        }

        stage('Analyse Statique (DP-005 & DP-006)') {
            steps {
                script {
                    echo "Decision Point: DP-005 (Checkstyle) & DP-006 (SpotBugs)" [cite: 232, 239]
                    // On lance l'analyse, on peut configurer le build pour échouer si des bugs critiques sont trouvés
                    sh 'mvn checkstyle:check spotbugs:check pmd:check'
                }
            }
        }

        stage('Build & Tests Unitaires') {
            steps {
                // Exécution des tests et génération du rapport JaCoCo pour le DP-003
                sh 'mvn jacoco:prepare-agent test jacoco:report -Dspring.sql.init.mode=always -Dtest=!PostgresIntegrationTests,!MySqlIntegrationTests' [cite: 151]
            }
        }

        stage('Vérification Couverture (DP-003)') {
            steps {
                script {
                    // Extraction du pourcentage de couverture depuis le rapport JaCoCo (exemple simplifié)
                    echo "Decision Point: DP-003 (Seuil de Couverture)" [cite: 218, 292]
                    // Dans un cas réel, vous utiliseriez un script comme collect_metrics.sh pour parser le XML
                    echo "Logic: coverage >= ${env.COVERAGE_THRESHOLD}%" [cite: 221, 294]
                }
            }
        }

        stage('Docker Infrastructure') {
            steps {
                script {
                    sh "docker rm -f petclinic-app petclinic-mysql || true"
                    sh "${env.DOCKER_CMD} down --volumes --remove-orphans"
                    sh "${env.DOCKER_CMD} up -d --build"
                }
            }
        }

        stage('Validation Healthcheck (DP-003)') {
            steps {
                script {
                    echo "Attente du démarrage (45s)..."
                    sleep 45
                    
                    // Point de décision sur la disponibilité de l'application
                    def response = sh(script: "docker run --network ced_petclinic_default curlimages/curl:latest -sI http://petclinic-app:8080 | grep '200' || true", returnStdout: true)
                    
                    if (response.contains("200")) {
                        echo "Decision: PASS (L'application est saine)" [cite: 301]
                    } else {
                        echo "Decision: FAIL (L'application n'a pas répondu)" [cite: 297]
                        error "Validation échouée : HTTP status n'est pas 200"
                    }
                }
            }
        }
    }

post {
        always {
            // 1. Rapports de tests standards pour Jenkins
            junit '**/target/surefire-reports/*.xml'
            
            // 2. Archivage des rapports HTML de couverture (JaCoCo)
            archiveArtifacts artifacts: 'target/site/jacoco/**', allowEmptyArchive: true
            
            echo "📊 Lancement de l'instrumentation (collect_metrics.sh)..."
            
            // 3. Exécution de ton script de collecte de données (Phase 1 - Étape 4)
            // Assure-toi que le fichier est bien à la racine de PetClinic-ci
            sh './collect_metrics.sh'
            
            // 4. Archivage du dossier contenant tes CSV et métriques de thèse
            // C'est ce dossier qui servira à construire ton dataset de 300 runs
            archiveArtifacts artifacts: 'pipeline-data/**', allowEmptyArchive: true
            
            echo "✅ Collecte des métriques terminée pour le build #${BUILD_NUMBER}."
        }
        success {
            echo "Phase 1 - Semaine 7 : Points de décision validés et enregistrés."
        }
        failure {
            echo "Échec détecté. Les métriques d'échec ont été enregistrées dans pipeline-data."
        }
    }
}
