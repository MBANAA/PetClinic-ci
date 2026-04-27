pipeline {
    agent any

    environment {
        // Initialisation propre
        ST_BUILD = "PENDING"
        ST_TEST = "PENDING"
    }

    stages {
     stage('Initialisation') {
            steps {
                script {
                    echo "--- NETTOYAGE DES CARACTÈRES WINDOWS ---"
                    // Cette commande supprime les \r (CR) pour convertir en format Linux (LF)
                    sh "sed -i 's/\\r//' mvnw"
                    sh "sed -i 's/\\r//' collect_metrics.sh"
                    
                    sh 'chmod +x mvnw'
                    sh 'chmod +x collect_metrics.sh'
                    
                    env.ST_BUILD = "STARTED"
                }
            }
        }

        stage('Compilation') {
            steps {
                script {
                    try {
                        // On utilise ./mvnw pour ne pas dépendre du bloc 'tools'
                        sh './mvnw clean compile -DskipTests'
                        env.ST_BUILD = "SUCCESS"
                    } catch (e) {
                        env.ST_BUILD = "FAILURE"
                        echo "Erreur de compilation : ${e.getMessage()}"
                    }
                }
            }
        }
    }

    post {
        always {
            script {
                // On s'assure que les variables ne sont pas vides pour le CSV
                def b_stat = env.ST_BUILD ?: "FAILED_AT_START"
                def t_stat = env.ST_TEST ?: "SKIPPED"
                
                sh "./collect_metrics.sh ${b_stat} ${t_stat} SKIPPED SKIPPED SKIPPED"
            }
            archiveArtifacts artifacts: 'pipeline-data/**', allowEmptyArchive: true
        }
    }
}