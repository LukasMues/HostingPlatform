pipeline {
    agent any

    environment {
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-creds')
        K8S_NAMESPACE = 'client1' 

        // App1 (Original Website) Configuration
        APP1_NAME = 'app1'
        APP1_IMAGE_REPO = 'kre1/website' 
        APP1_SOURCE_DIR = 'website/App1' // Lowercase 'w'
        APP1_DOCKERFILE = 'website/App1/Dockerfile' // Lowercase 'w'
        APP1_K8S_DEPLOYMENT_FILE = 'k8s/deployment.yaml'
        APP1_K8S_INGRESS_FILE = 'k8s/ingress.yaml'
        APP1_K8S_RESOURCE_NAME = 'website' 

        // App2 Configuration
        APP2_NAME = 'app2'
        APP2_IMAGE_REPO = 'kre1/app2'
        APP2_SOURCE_DIR = 'website/App2' // Lowercase 'w'
        APP2_DOCKERFILE = 'website/App2/Dockerfile' // Lowercase 'w'
        APP2_K8S_DEPLOYMENT_FILE = 'k8s/app2-deployment.yaml'
        APP2_K8S_INGRESS_FILE = 'k8s/app2-ingress.yaml'
        APP2_K8S_RESOURCE_NAME = 'app2-deployment' 
    }

    stages {
        stage('Clone Repository') {
            steps {
                git url: 'https://github.com/LukasMues/HostingPlatform.git', branch: 'main'
                script {
                    def changedFilesOutput = sh(script: "git diff --name-only ${env.GIT_PREVIOUS_COMMIT} ${env.GIT_COMMIT}", returnStdout: true).trim()
                    def changedFiles = []
                    if (changedFilesOutput) { 
                        changedFiles = changedFilesOutput.split('\\n')
                    }
                    echo "Changed files: ${changedFiles.join(', ')}"

                    env.DEPLOY_APP1 = "false"
                    env.DEPLOY_APP2 = "false"

                    for (String file : changedFiles) {
                        if (file.startsWith("${APP1_SOURCE_DIR}/")) {
                            env.DEPLOY_APP1 = "true"
                        }
                        if (file.startsWith("${APP2_SOURCE_DIR}/")) {
                            env.DEPLOY_APP2 = "true"
                        }
                    }
                    if (changedFiles.length == 0) { 
                        echo "No specific changed files detected. Assuming changes for both apps for safety."
                        env.DEPLOY_APP1 = "true"
                        env.DEPLOY_APP2 = "true"
                    }
                }
            }
        }

        stage('Ensure Namespace Exists') {
            steps {
                sh """
                    if ! kubectl get namespace ${K8S_NAMESPACE} > /dev/null 2>&1; then
                        kubectl create namespace ${K8S_NAMESPACE}
                        echo "Created namespace ${K8S_NAMESPACE}"
                    else
                        echo "Namespace ${K8S_NAMESPACE} already exists"
                    fi
                """
            }
        }

        stage('Build & Deploy App1') {
            when { expression { env.DEPLOY_APP1 == 'true' } }
            steps {
                script {
                    echo "Changes detected for App1 or full build. Proceeding with App1."
                    def IMAGE_TAG = new Date().format('yyyyMMdd-HHmm')
                    def APP_IMAGE_NAME = "${env.APP1_IMAGE_REPO}:${IMAGE_TAG}"

                    echo "Building App1: ${APP_IMAGE_NAME} from ${env.APP1_DOCKERFILE} with context ${env.APP1_SOURCE_DIR}"
                    sh "docker build -t ${APP_IMAGE_NAME} -f ${env.APP1_DOCKERFILE} ${env.APP1_SOURCE_DIR}"

                    echo "Pushing App1: ${APP_IMAGE_NAME}"
                    // Ensure DOCKERHUB_CREDENTIALS_USR and DOCKERHUB_CREDENTIALS_PSW are correctly sourced if not using withCredentials
                    // For pipelines, withCredentials is safer for handling passwords.
                    // This assumes DOCKERHUB_CREDENTIALS_PSW is available directly as an env var from the credentials binding.
                    sh "echo $DOCKERHUB_CREDENTIALS_PSW | docker login -u $DOCKERHUB_CREDENTIALS_USR --password-stdin"
                    sh "docker push ${APP_IMAGE_NAME}"

                    echo "Deploying App1 to Kubernetes"
                    sh """
                        sed -i "s|image: ${env.APP1_IMAGE_REPO}:.*|image: ${APP_IMAGE_NAME}|" ${env.APP1_K8S_DEPLOYMENT_FILE}
                        kubectl apply -f ${env.APP1_K8S_DEPLOYMENT_FILE} --namespace=${K8S_NAMESPACE}
                        kubectl rollout status deployment/${env.APP1_K8S_RESOURCE_NAME} --namespace=${K8S_NAMESPACE}
                        kubectl apply -f ${env.APP1_K8S_INGRESS_FILE} --namespace=${K8S_NAMESPACE}
                    """
                }
            }
        }

        stage('Build & Deploy App2') {
            when { expression { env.DEPLOY_APP2 == 'true' } }
            steps {
                script {
                    echo "Changes detected for App2 or full build. Proceeding with App2."
                    def IMAGE_TAG = new Date().format('yyyyMMdd-HHmm')
                    def APP_IMAGE_NAME = "${env.APP2_IMAGE_REPO}:${IMAGE_TAG}"

                    echo "Building App2: ${APP_IMAGE_NAME} from ${env.APP2_DOCKERFILE} with context ${env.APP2_SOURCE_DIR}"
                    sh "docker build -t ${APP_IMAGE_NAME} -f ${env.APP2_DOCKERFILE} ${env.APP2_SOURCE_DIR}"

                    echo "Pushing App2: ${APP_IMAGE_NAME}"
                    sh "echo $DOCKERHUB_CREDENTIALS_PSW | docker login -u $DOCKERHUB_CREDENTIALS_USR --password-stdin"
                    sh "docker push ${APP_IMAGE_NAME}"

                    echo "Deploying App2 to Kubernetes"
                    sh """
                        sed -i "s|image: ${env.APP2_IMAGE_REPO}:.*|image: ${APP_IMAGE_NAME}|" ${env.APP2_K8S_DEPLOYMENT_FILE}
                        kubectl apply -f ${env.APP2_K8S_DEPLOYMENT_FILE} --namespace=${K8S_NAMESPACE}
                        kubectl rollout status deployment/${env.APP2_K8S_RESOURCE_NAME} --namespace=${K8S_NAMESPACE}
                        kubectl apply -f ${env.APP2_K8S_INGRESS_FILE} --namespace=${K8S_NAMESPACE}
                    """
                }
            }
        }
    }
} 