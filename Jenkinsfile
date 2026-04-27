pipeline {
    agent any

    environment {
        ST_BUILD = "PENDING"
        ST_TEST = "PENDING"
    }

    stages {
        stage('Initialisation') {
            steps {
                script {
                    echo "--- NETTOYAGE ET FIX DES PERMISSIONS ---"
                    // On convertit les fichiers au cas où
                    sh "sed -i 's/\\r//' collect_metrics.sh"
                    sh "chmod +x collect_metrics.sh"
                    env.ST_BUILD = "READY"
                }
            }
        }

        stage('Compilation') {
            steps {
                script {
                    try {
                        echo "--- TENTATIVE DE COMPILATION VIA MAVEN SYSTEME ---"
                        // On utilise 'mvn' au lieu de './mvnw' pour éviter le bug CRLF
                        sh 'mvn clean compile -DskipTests'
                        env.ST_BUILD = "SUCCESS"
                    } catch (e) {
                        env.ST_BUILD = "FAILURE"
                        echo "ERREUR : ${e.getMessage()}"
                    }
                }
            }
        }
    }

    post {
        always {
            script {
                // On s'assure d'avoir des valeurs pour le CSV
                def b_stat = env.ST_BUILD ?: "CRASH_SYSTEME"
                def t_stat = env.ST_TEST ?: "SKIPPED"
                
                sh "./collect_metrics.sh ${b_stat} ${t_stat} SKIPPED SKIPPED SKIPPED"
            }
            archiveArtifacts artifacts: 'pipeline-data/**', allowEmptyArchive: true
        }
    }
}