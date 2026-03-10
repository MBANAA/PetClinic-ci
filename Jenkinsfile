pipeline {
    agent any

    tools {
        maven 'Maven3'
        jdk 'JDK17'
    }

    environment {
        DECISION_LOG = 'pipeline_decisions.log'
        METRICS_CSV = 'dataset_metrics.csv'
    }

    stages {
        stage('0. Checkout & Init') {
            steps {
                git branch: 'main', url: 'https://github.com/MBANAA/PetClinic-ci.git'
                sh "echo '--- RUN ${BUILD_NUMBER} ---' > ${DECISION_LOG}"
            }
        }

        stage('1. Build (Compilation)') {
            steps {
                // Compile le code source (src/main/java) sans lancer les tests
                sh 'mvn clean compile'
                sh "echo 'DP-007,BUILD,PASS,CONTINUE' >> ${DECISION_LOG}"
            }
        }

        // --- NOUVEAU STAGE : VÉRIFICATION QUALITÉ ET FICHIERS CRITIQUES ---
        stage('2. Quality & Critical Files Check') {
            steps {
                script {
                    echo "Vérification des fichiers de configuration..."
                    
                    // 1. Vérification que le pom.xml est bien formé (pas de balise cassée)
                    sh 'mvn validate'
                    
                    // 2. Analyse Statique du code (Checkstyle & Spotbugs)
                    // Cela génère des échecs de qualité pour ton dataset
                    sh 'mvn checkstyle:check spotbugs:check || true'
                    
                    // 3. Scan de sécurité rudimentaire sur le application.properties
                    // On vérifie qu'aucun mot de passe en clair n'est laissé dans les configs
                    def configCheck = sh(script: "grep -i 'password=root' src/main/resources/application.properties", returnStatus: true)
                    if (configCheck == 0) {
                        sh "echo 'DP-006,SECURITY_CHECK,WARNING,HARDCODED_PASSWORD' >> ${DECISION_LOG}"
                        echo "ATTENTION: Mot de passe en clair détecté !"
                    } else {
                        sh "echo 'DP-006,SECURITY_CHECK,PASS,CONTINUE' >> ${DECISION_LOG}"
                    }
                }
            }
        }

        stage('3. Unit Testing') {
            steps {
                // Exécute les tests dans src/test/java, mais ignore les tests d'intégration lourds
                sh 'mvn test -Dspring.profiles.active=h2 -Dtest=!*IntegrationTests'
                sh "echo 'DP-004,UNIT_TESTS,PASS,CONTINUE' >> ${DECISION_LOG}"
            }
            post { always { junit '**/target/surefire-reports/*.xml' } }
        }

        stage('4. Integration Testing (Testcontainers)') {
            steps {
                // Exécute uniquement les tests d'intégration (qui démarrent une vraie base via Testcontainers)
                sh 'mvn test -Dtest=*IntegrationTests'
                sh "echo 'DP-011,INTEGRATION_TESTS,PASS,CONTINUE' >> ${DECISION_LOG}"
            }
        }

        stage('5. Code Coverage (JaCoCo)') {
            steps {
                // Vérifie quel pourcentage du code est couvert par les tests (DP-003)
                sh 'mvn jacoco:report'
                sh "echo 'DP-003,COVERAGE,GENERATED,CONTINUE' >> ${DECISION_LOG}"
            }
        }

        stage('6. Package & Docker Image') {
            steps {
                // Crée le fichier .jar final et l'image Docker
                sh 'mvn package -DskipTests'
                sh 'docker build -t petclinic:latest .'
                sh "echo 'DP-009,PACKAGE,PASS,CONTINUE' >> ${DECISION_LOG}"
            }
        }
    }

    // --- INSTRUMENTATION ET COLLECTE (OBLIGATOIRE PHASE 1) ---
    post {
        always {
            script {
                def status = currentBuild.result ?: 'SUCCESS'
                sh "echo '${BUILD_NUMBER},${status},${currentBuild.duration}' >> ${METRICS_CSV}"
                archiveArtifacts artifacts: "${DECISION_LOG}, ${METRICS_CSV}, target/*.jar", allowEmptyArchive: true
            }
        }
    }
}