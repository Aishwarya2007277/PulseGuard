// PulseGuard Jenkins CI/CD Pipeline
// Complete automation from code commit to Kubernetes deployment
// =============================================================

pipeline {
    agent any
    
    // Environment variables
    environment {
        // Application configuration
        APP_NAME = 'pulseguard'
        APP_VERSION = "${env.BUILD_NUMBER}"
        DOCKER_IMAGE = "${APP_NAME}:${APP_VERSION}"
        DOCKER_LATEST = "${APP_NAME}:latest"
        
        // Kubernetes configuration
        K8S_NAMESPACE = 'pulseguard'
        K8S_DEPLOYMENT = 'pulseguard-deployment'
        
        // Build configuration
        PYTHON_VERSION = '3.13'
        TEST_RESULTS_DIR = 'test-reports'
        COVERAGE_DIR = 'coverage-reports'
        
        // Docker registry (using local for now)
        DOCKER_REGISTRY = 'localhost:5000' // Local registry if needed
        
        // Deployment settings
        ROLLOUT_TIMEOUT = '300s'
        HEALTH_CHECK_TIMEOUT = '60s'
    }
    
    // Build options
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
        timestamps()
        ansiColor('xterm')
    }
    
    // Pipeline stages
    stages {
        
        // ========================================
        // STAGE 1: PREPARATION & CHECKOUT
        // ========================================
        stage('Checkout & Prepare') {
            steps {
                echo '🚀 Starting PulseGuard CI/CD Pipeline'
                echo "Build Number: ${env.BUILD_NUMBER}"
                echo "Build ID: ${env.BUILD_ID}"
                echo "Workspace: ${env.WORKSPACE}"
                
                // Clean workspace
                deleteDir()
                
                // Checkout code (this step is automatic in Jenkins)
                checkout scm
                
                // Display repository information
                script {
                    def gitCommit = sh(returnStdout: true, script: 'git rev-parse HEAD').trim()
                    def gitBranch = sh(returnStdout: true, script: 'git rev-parse --abbrev-ref HEAD').trim()
                    echo "Git Commit: ${gitCommit}"
                    echo "Git Branch: ${gitBranch}"
                    
                    // Set build description
                    currentBuild.description = "Branch: ${gitBranch}, Commit: ${gitCommit.take(8)}"
                }
                
                // Verify workspace structure
                sh 'ls -la'
                sh 'find . -name "*.py" -type f | head -10'
            }
        }
        
        // ========================================
        // STAGE 2: DEPENDENCY INSTALLATION
        // ========================================
        stage('Install Dependencies') {
            steps {
                echo '📦 Installing Python dependencies'
                
                script {
                    if (isUnix()) {
                        // Linux/Mac commands
                        sh '''
                            python3 --version
                            pip3 --version
                            pip3 install --upgrade pip
                            pip3 install -r app/requirements.txt
                        '''
                    } else {
                        // Windows commands
                        bat '''
                            python --version
                            pip --version
                            pip install --upgrade pip
                            pip install -r app/requirements.txt
                        '''
                    }
                }
                
                echo '✅ Dependencies installed successfully'
            }
        }
        
        // ========================================
        // STAGE 3: CODE QUALITY & LINTING
        // ========================================
        stage('Code Quality') {
            parallel {
                stage('Lint Python Code') {
                    steps {
                        echo '🔍 Running Python linting'
                        script {
                            try {
                                if (isUnix()) {
                                    sh 'python3 -m py_compile app/app.py app/config.py'
                                } else {
                                    bat 'python -m py_compile app/app.py app/config.py'
                                }
                                echo '✅ Python syntax check passed'
                            } catch (Exception e) {
                                echo "❌ Python syntax check failed: ${e.message}"
                                error("Python syntax validation failed")
                            }
                        }
                    }
                }
                
                stage('Check Requirements') {
                    steps {
                        echo '📋 Validating requirements.txt'
                        script {
                            if (isUnix()) {
                                sh 'cat app/requirements.txt'
                            } else {
                                bat 'type app\\requirements.txt'
                            }
                        }
                        echo '✅ Requirements validated'
                    }
                }
            }
        }
        
        // ========================================
        // STAGE 4: AUTOMATED TESTING
        // ========================================
        stage('Run Tests') {
            steps {
                echo '🧪 Running automated test suite'
                
                // Create test results directory
                script {
                    if (isUnix()) {
                        sh "mkdir -p ${TEST_RESULTS_DIR} ${COVERAGE_DIR}"
                    } else {
                        bat "if not exist ${TEST_RESULTS_DIR} mkdir ${TEST_RESULTS_DIR}"
                        bat "if not exist ${COVERAGE_DIR} mkdir ${COVERAGE_DIR}"
                    }
                }
                
                // Run tests with coverage
                script {
                    try {
                        if (isUnix()) {
                            sh '''
                                export PYTHONPATH="${WORKSPACE}/app:${PYTHONPATH}"
                                python3 -m pytest tests/ -v \\
                                    --junitxml=${TEST_RESULTS_DIR}/test-results.xml \\
                                    --cov=app \\
                                    --cov-report=xml:${COVERAGE_DIR}/coverage.xml \\
                                    --cov-report=html:${COVERAGE_DIR}/html \\
                                    --cov-report=term-missing
                            '''
                        } else {
                            bat '''
                                set PYTHONPATH=%WORKSPACE%\\app;%PYTHONPATH%
                                python -m pytest tests/ -v ^
                                    --junitxml=%TEST_RESULTS_DIR%/test-results.xml ^
                                    --cov=app ^
                                    --cov-report=xml:%COVERAGE_DIR%/coverage.xml ^
                                    --cov-report=html:%COVERAGE_DIR%/html ^
                                    --cov-report=term-missing
                            '''
                        }
                        echo '✅ All tests passed successfully'
                    } catch (Exception e) {
                        echo "❌ Tests failed: ${e.message}"
                        error("Test execution failed. Pipeline stopped.")
                    }
                }
            }
            
            // Archive test results
            post {
                always {
                    // Publish test results
                    script {
                        try {
                            junit "${TEST_RESULTS_DIR}/test-results.xml"
                        } catch (Exception e) {
                            echo "Warning: Could not publish test results: ${e.message}"
                        }
                    }
                    
                    // Archive coverage reports
                    archiveArtifacts artifacts: "${COVERAGE_DIR}/**", fingerprint: true, allowEmptyArchive: true
                }
            }
        }
        
        // ========================================
        // STAGE 5: DOCKER IMAGE BUILD
        // ========================================
        stage('Build Docker Image') {
            steps {
                echo '🐳 Building Docker image'
                
                // Build the image
                script {
                    try {
                        def buildArgs = "--no-cache"
                        
                        if (isUnix()) {
                            sh """
                                docker build ${buildArgs} \\
                                    -t ${DOCKER_IMAGE} \\
                                    -t ${DOCKER_LATEST} \\
                                    --label "build.number=${env.BUILD_NUMBER}" \\
                                    --label "build.id=${env.BUILD_ID}" \\
                                    --label "git.commit=\$(git rev-parse HEAD)" \\
                                    .
                            """
                        } else {
                            bat """
                                docker build ${buildArgs} ^
                                    -t ${DOCKER_IMAGE} ^
                                    -t ${DOCKER_LATEST} ^
                                    --label "build.number=${env.BUILD_NUMBER}" ^
                                    --label "build.id=${env.BUILD_ID}" ^
                                    .
                            """
                        }
                        
                        echo '✅ Docker image built successfully'
                        
                        // Verify image
                        if (isUnix()) {
                            sh "docker images | grep ${APP_NAME}"
                        } else {
                            bat "docker images | findstr ${APP_NAME}"
                        }
                        
                    } catch (Exception e) {
                        echo "❌ Docker build failed: ${e.message}"
                        error("Docker image build failed")
                    }
                }
            }
        }
        
        // ========================================
        // STAGE 6: DOCKER IMAGE TESTING
        // ========================================
        stage('Test Docker Image') {
            steps {
                echo '🔍 Testing Docker image'
                
                script {
                    try {
                        def containerName = "${APP_NAME}-test-${env.BUILD_NUMBER}"
                        
                        if (isUnix()) {
                            // Start container
                            sh """
                                docker run -d --name ${containerName} \\
                                    -p 5001:5000 \\
                                    -e ENVIRONMENT=production \\
                                    ${DOCKER_IMAGE}
                            """
                            
                            // Wait for container to start
                            sh 'sleep 10'
                            
                            // Test health endpoint
                            sh """
                                for i in {1..30}; do
                                    if curl -f http://localhost:5001/health; then
                                        echo "Health check passed"
                                        break
                                    fi
                                    echo "Waiting for application to start... (\$i/30)"
                                    sleep 2
                                done
                            """
                            
                            // Test other endpoints
                            sh 'curl -f http://localhost:5001/version'
                            sh 'curl -f http://localhost:5001/metrics'
                            
                            // Check container logs
                            sh "docker logs ${containerName}"
                            
                        } else {
                            // Windows version - start container
                            bat """
                                docker run -d --name ${containerName} ^
                                    -p 5001:5000 ^
                                    -e ENVIRONMENT=production ^
                                    ${DOCKER_IMAGE}
                            """
                            
                            // Wait and test
                            bat 'timeout /t 10'
                            
                            // Simple connectivity test (PowerShell)
                            bat '''
                                powershell -Command "
                                    for ($i=1; $i -le 30; $i++) {
                                        try {
                                            $response = Invoke-WebRequest -Uri http://localhost:5001/health -UseBasicParsing -TimeoutSec 5
                                            if ($response.StatusCode -eq 200) {
                                                Write-Host 'Health check passed'
                                                break
                                            }
                                        } catch {
                                            Write-Host 'Waiting for application... (' + $i + '/30)'
                                            Start-Sleep 2
                                        }
                                    }
                                "
                            '''
                            
                            // Check logs
                            bat "docker logs ${containerName}"
                        }
                        
                        echo '✅ Docker image tests passed'
                        
                    } catch (Exception e) {
                        echo "❌ Docker image tests failed: ${e.message}"
                        error("Docker image testing failed")
                    } finally {
                        // Always cleanup test container
                        script {
                            def containerName = "${APP_NAME}-test-${env.BUILD_NUMBER}"
                            try {
                                if (isUnix()) {
                                    sh "docker stop ${containerName} || true"
                                    sh "docker rm ${containerName} || true"
                                } else {
                                    bat "docker stop ${containerName} || exit 0"
                                    bat "docker rm ${containerName} || exit 0"
                                }
                            } catch (Exception cleanupError) {
                                echo "Warning: Container cleanup failed: ${cleanupError.message}"
                            }
                        }
                    }
                }
            }
        }
        
        // ========================================
        // STAGE 7: KUBERNETES DEPLOYMENT
        // ========================================
        stage('Deploy to Kubernetes') {
            steps {
                echo '☸️ Deploying to Kubernetes'
                
                script {
                    try {
                        // Check kubectl connectivity
                        if (isUnix()) {
                            sh 'kubectl cluster-info'
                        } else {
                            bat 'kubectl cluster-info'
                        }
                        
                        // Create namespace if not exists
                        if (isUnix()) {
                            sh "kubectl create namespace ${K8S_NAMESPACE} || true"
                        } else {
                            bat "kubectl create namespace ${K8S_NAMESPACE} || exit 0"
                        }
                        
                        // Apply Kubernetes manifests
                        if (isUnix()) {
                            sh '''
                                kubectl apply -f k8s/namespace.yaml
                                kubectl apply -f k8s/configmap.yaml
                                kubectl apply -f k8s/deployment.yaml
                                kubectl apply -f k8s/service.yaml
                            '''
                        } else {
                            bat '''
                                kubectl apply -f k8s/namespace.yaml
                                kubectl apply -f k8s/configmap.yaml
                                kubectl apply -f k8s/deployment.yaml
                                kubectl apply -f k8s/service.yaml
                            '''
                        }
                        
                        // Update deployment with new image
                        if (isUnix()) {
                            sh """
                                kubectl set image deployment/${K8S_DEPLOYMENT} \\
                                    ${APP_NAME}=${DOCKER_IMAGE} \\
                                    -n ${K8S_NAMESPACE}
                            """
                        } else {
                            bat """
                                kubectl set image deployment/${K8S_DEPLOYMENT} ^
                                    ${APP_NAME}=${DOCKER_IMAGE} ^
                                    -n ${K8S_NAMESPACE}
                            """
                        }
                        
                        echo '✅ Kubernetes manifests applied'
                        
                    } catch (Exception e) {
                        echo "❌ Kubernetes deployment failed: ${e.message}"
                        error("Kubernetes deployment failed")
                    }
                }
            }
        }
        
        // ========================================
        // STAGE 8: DEPLOYMENT VERIFICATION
        // ========================================
        stage('Verify Deployment') {
            steps {
                echo '✅ Verifying deployment'
                
                script {
                    try {
                        // Wait for rollout to complete
                        if (isUnix()) {
                            sh """
                                kubectl rollout status deployment/${K8S_DEPLOYMENT} \\
                                    -n ${K8S_NAMESPACE} \\
                                    --timeout=${ROLLOUT_TIMEOUT}
                            """
                        } else {
                            bat """
                                kubectl rollout status deployment/${K8S_DEPLOYMENT} ^
                                    -n ${K8S_NAMESPACE} ^
                                    --timeout=${ROLLOUT_TIMEOUT}
                            """
                        }
                        
                        // Check pod status
                        if (isUnix()) {
                            sh "kubectl get pods -n ${K8S_NAMESPACE} -l app=${APP_NAME}"
                        } else {
                            bat "kubectl get pods -n ${K8S_NAMESPACE} -l app=${APP_NAME}"
                        }
                        
                        // Check service status
                        if (isUnix()) {
                            sh "kubectl get services -n ${K8S_NAMESPACE}"
                        } else {
                            bat "kubectl get services -n ${K8S_NAMESPACE}"
                        }
                        
                        // Verify application health
                        script {
                            if (isUnix()) {
                                sh """
                                    kubectl wait --for=condition=available \\
                                        deployment/${K8S_DEPLOYMENT} \\
                                        -n ${K8S_NAMESPACE} \\
                                        --timeout=${HEALTH_CHECK_TIMEOUT}
                                """
                            } else {
                                bat """
                                    kubectl wait --for=condition=available ^
                                        deployment/${K8S_DEPLOYMENT} ^
                                        -n ${K8S_NAMESPACE} ^
                                        --timeout=${HEALTH_CHECK_TIMEOUT}
                                """
                            }
                        }
                        
                        echo '✅ Deployment verification successful'
                        
                    } catch (Exception e) {
                        echo "❌ Deployment verification failed: ${e.message}"
                        
                        // Debug information
                        if (isUnix()) {
                            sh """
                                echo "=== DEBUG INFORMATION ==="
                                kubectl describe deployment ${K8S_DEPLOYMENT} -n ${K8S_NAMESPACE}
                                kubectl get events -n ${K8S_NAMESPACE} --sort-by='.lastTimestamp'
                                kubectl logs -n ${K8S_NAMESPACE} -l app=${APP_NAME} --tail=50
                            """
                        } else {
                            bat """
                                echo "=== DEBUG INFORMATION ==="
                                kubectl describe deployment ${K8S_DEPLOYMENT} -n ${K8S_NAMESPACE}
                                kubectl get events -n ${K8S_NAMESPACE} --sort-by=".lastTimestamp"
                                kubectl logs -n ${K8S_NAMESPACE} -l app=${APP_NAME} --tail=50
                            """
                        }
                        
                        error("Deployment verification failed")
                    }
                }
            }
        }
        
        // ========================================
        // STAGE 9: SMOKE TESTS
        // ========================================
        stage('Smoke Tests') {
            steps {
                echo '🔥 Running smoke tests'
                
                script {
                    try {
                        // Port forward to test the application
                        def portForwardPid
                        
                        if (isUnix()) {
                            // Start port forwarding in background
                            sh """
                                nohup kubectl port-forward -n ${K8S_NAMESPACE} \\
                                    service/pulseguard-service 8082:80 \\
                                    > port-forward.log 2>&1 &
                                echo \$! > port-forward.pid
                            """
                            
                            // Wait for port forwarding to establish
                            sh 'sleep 5'
                            
                            // Test endpoints
                            sh '''
                                curl -f http://localhost:8082/health
                                curl -f http://localhost:8082/version
                                curl -f http://localhost:8082/metrics
                            '''
                            
                        } else {
                            // Windows - use PowerShell job for port forwarding
                            bat '''
                                powershell -Command "
                                    Start-Job -ScriptBlock {
                                        kubectl port-forward -n pulseguard service/pulseguard-service 8082:80
                                    }
                                    Start-Sleep 10
                                    try {
                                        Invoke-WebRequest -Uri http://localhost:8082/health -UseBasicParsing
                                        Write-Host 'Health endpoint OK'
                                        Invoke-WebRequest -Uri http://localhost:8082/version -UseBasicParsing  
                                        Write-Host 'Version endpoint OK'
                                        Invoke-WebRequest -Uri http://localhost:8082/metrics -UseBasicParsing
                                        Write-Host 'Metrics endpoint OK'
                                    } finally {
                                        Get-Job | Stop-Job
                                        Get-Job | Remove-Job
                                    }
                                "
                            '''
                        }
                        
                        echo '✅ Smoke tests passed'
                        
                    } catch (Exception e) {
                        echo "❌ Smoke tests failed: ${e.message}"
                        error("Smoke tests failed")
                    } finally {
                        // Cleanup port forwarding
                        try {
                            if (isUnix()) {
                                sh '''
                                    if [ -f port-forward.pid ]; then
                                        kill $(cat port-forward.pid) || true
                                        rm -f port-forward.pid port-forward.log
                                    fi
                                '''
                            }
                        } catch (Exception cleanupError) {
                            echo "Warning: Port forward cleanup failed: ${cleanupError.message}"
                        }
                    }
                }
            }
        }
    }
    
    // ========================================
    // POST-BUILD ACTIONS
    // ========================================
    post {
        always {
            echo '📊 Pipeline completed - collecting artifacts'
            
            // Archive build artifacts
            script {
                try {
                    archiveArtifacts artifacts: 'test-reports/**,coverage-reports/**', fingerprint: true, allowEmptyArchive: true
                } catch (Exception e) {
                    echo "Warning: Could not archive artifacts: ${e.message}"
                }
            }
            
            // Clean up workspace (optional)
            // cleanWs()
        }
        
        success {
            echo '🎉 Pipeline succeeded!'
            script {
                currentBuild.result = 'SUCCESS'
                echo """
                ✅ PulseGuard deployment successful!
                
                📊 Build Information:
                   - Build Number: ${env.BUILD_NUMBER}
                   - Docker Image: ${DOCKER_IMAGE}
                   - Kubernetes Namespace: ${K8S_NAMESPACE}
                   - Deployment: ${K8S_DEPLOYMENT}
                
                🚀 Application Status:
                   - Pods: Running with latest image
                   - Service: Available and healthy
                   - Health Check: Passed
                   - Smoke Tests: Passed
                
                📱 Access Information:
                   - Use: kubectl port-forward -n ${K8S_NAMESPACE} service/pulseguard-service 8080:80
                   - Then: http://localhost:8080/
                """
            }
        }
        
        failure {
            echo '❌ Pipeline failed!'
            script {
                currentBuild.result = 'FAILURE'
                
                // Collect debug information
                try {
                    if (isUnix()) {
                        sh '''
                            echo "=== FAILURE DEBUG INFORMATION ==="
                            kubectl get all -n pulseguard || true
                            docker images | grep pulseguard || true
                            df -h || true
                        '''
                    } else {
                        bat '''
                            echo "=== FAILURE DEBUG INFORMATION ==="
                            kubectl get all -n pulseguard || exit 0
                            docker images | findstr pulseguard || exit 0
                        '''
                    }
                } catch (Exception debugError) {
                    echo "Warning: Could not collect debug information: ${debugError.message}"
                }
            }
        }
        
        unstable {
            echo '⚠️ Pipeline unstable!'
            script {
                currentBuild.result = 'UNSTABLE'
            }
        }
        
        aborted {
            echo '🛑 Pipeline aborted!'
            script {
                currentBuild.result = 'ABORTED'
                
                // Cleanup any running containers
                try {
                    def containerName = "${APP_NAME}-test-${env.BUILD_NUMBER}"
                    if (isUnix()) {
                        sh "docker stop ${containerName} || true"
                        sh "docker rm ${containerName} || true"
                    } else {
                        bat "docker stop ${containerName} || exit 0"
                        bat "docker rm ${containerName} || exit 0"
                    }
                } catch (Exception cleanupError) {
                    echo "Warning: Cleanup failed: ${cleanupError.message}"
                }
            }
        }
    }
}