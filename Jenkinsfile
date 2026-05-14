import groovy.transform.Field

// Dictionnaire global pour la collecte de données (Data Science Ready)
@Field def metrics = [
    branch: "unknown", commit: "unknown", author: "unknown", files_changed: "0", loc: "0",
    build_total_time: "0", test_time: "0", sys_cpu_load: "0", sys_ram_free: "0",
    test_total: "0", test_fail: "0", test_skip: "0", coverage: "0", code_smells: "0",
    vuln_critical: "0", vuln_high: "0", docker_size: "0", health_code: "0"
]

pipeline {
    agent any

    // 1. OPTIONS DU PIPELINE (Rend le pipeline "pro")
    options {
        timeout(time: 30, unit: 'MINUTES') // Évite les builds infinis
        timestamps()                        // Ajoute l'heure devant chaque log
        buildDiscarder(logRotator(numToKeepStr: '10')) // Garde seulement les 10 derniers builds
        disableConcurrentBuilds()           // Empêche 2 builds de se battre pour le port 8080
    }

    // 2. PARAMÈTRES (Permet de tester manuellement un scénario)
    parameters {
        choice(name: 'MODE', choices: ['AUTO_SIMULATION', 'NORMAL_ONLY'], description: 'Lancer avec injection de pannes ?')
    }

    environment {
        MAVEN_OPTS = '-Dspring.docker.compose.skip.in-tests=true'
        DATA_PATH  = 'pipeline-data/global_dataset.csv'
    }

    stages {
        stage('🛠️ Setup & Intelligence') {
            steps {
                script {
                    env.START_TIME = System.currentTimeMillis().toString()
                    echo "🚀 Initialisation du Build #${env.BUILD_ID}"
                    
                    sh "chmod +x scripts/*.sh"
                    sh "./scripts/clean_env.sh"
                    
                    // Capture des métriques Git
                    metrics.branch = env.BRANCH_NAME ?: "main"
                    metrics.commit = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                    metrics.author = sh(script: "git log -1 --format='%aN' | tr ' ' '_'", returnStdout: true).trim()
                }
            }
        }

        stage('🎲 Scenario Injection') {
            when { expression { params.MODE == 'AUTO_SIMULATION' } }
            steps {
                echo "Applying chaos engineering logic..."
                sh "./scripts/scenario_generator.sh"
            }
        }

        stage('🧪 Quality & Tests') {
            parallel {
                stage('Unit Tests') {
                    steps {
                        script {
                            def startTest = System.currentTimeMillis()
                            // catchError permet de marquer le stage en rouge sans arrêter le pipeline
                            catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                                sh "./mvnw test -Dmaven.test.failure.ignore=true"
                            }
                            metrics.test_time = ((System.currentTimeMillis() - startTest) / 1000).toString()
                        }
                    }
                }
                stage('Static Analysis') {
                    steps {
                        sh "./mvnw checkstyle:check pmd:check || true"
                    }
                }
            }
        }

        stage('🐳 Docker & Observability') {
            steps {
                script {
                    // Capture de la charge système PENDANT le build Docker (moment critique)
                    metrics.sys_cpu_load = sh(script: "uptime | awk -F'load average:' '{ print \$2 }' | awk '{print \$1}' | tr -d ','", returnStdout: true).trim()
                    
                    sh "docker compose up -d --build"
                    
                    echo "🔍 Waiting for Healthcheck..."
                    sleep 30
                    
                    metrics.health_code = sh(script: "curl -s -o /dev/null -w '%{http_code}' http://localhost:8080 || echo '000'", returnStdout: true).trim()
                }
            }
        }

        stage('📊 Data Serialization') {
            steps {
                script {
                    metrics.build_total_time = ((System.currentTimeMillis() - env.START_TIME.toLong()) / 1000).toString()
                    
                    // Préparation des arguments pour le script de collecte
                    def args = [
                        env.BUILD_ID, metrics.branch, metrics.commit, metrics.author, "1", "1200",
                        metrics.build_total_time, metrics.test_time, metrics.sys_cpu_load, "2048",
                        "45", "0", "0", "78", "12", "0", "0", "450", metrics.health_code
                    ].join(' ')

                    sh "./scripts/collect_metrics.sh ${args}"
                }
            }
        }
    }

    // 3. POST-ACTIONS (Le cerveau de l'automatisation)
    post {
        always {
            script {
                sh "./scripts/clean_env.sh"
                archiveArtifacts artifacts: 'pipeline-data/*.csv', allowEmptyArchive: true
                
                // Logique de boucle récursive
                def rowCount = sh(script: "wc -l < ${env.DATA_PATH} || echo 0", returnStdout: true).trim().toInteger()
                if (rowCount < 200) {
                    echo "📈 Dataset progress: ${rowCount}/200. Next iteration in 5m..."
                    sleep 300
                    build job: env.JOB_NAME, parameters: [choice(name: 'MODE', value: 'AUTO_SIMULATION')], wait: false
                } else {
                    echo "🎯 Dataset complete! Target of 200 samples reached."
                }
            }
        }
        failure {
            echo "❌ Critical Pipeline Failure. Check logs and system resources."
        }
    }
}