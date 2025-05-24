pipeline {
    agent any

    environment {
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-creds') // your Jenkins credential ID
        IMAGE_NAME = 'kre1/website'
        IMAGE_TAG = "${new Date().format('yyyyMMdd-HHmm')}"
        NAMESPACE = 'client1'
    }

    stages {
        stage('Clone Repository') {
            steps {
                git url: 'https://github.com/LukasMues/HostingPlatform.git', branch: 'main'
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .'
            }
        }

        stage('Push to Docker Hub') {
            steps {
                sh 'echo $DOCKERHUB_CREDENTIALS_PSW | docker login -u $DOCKERHUB_CREDENTIALS_USR --password-stdin'
                sh 'docker push ${IMAGE_NAME}:${IMAGE_TAG}'
            }
        }

        stage('Ensure Namespace Exists') {
            steps {
                sh '''
                    if ! kubectl get namespace ${NAMESPACE} &> /dev/null; then
                        kubectl create namespace ${NAMESPACE}
                        echo "Created namespace ${NAMESPACE}"
                    else
                        echo "Namespace ${NAMESPACE} already exists"
                    fi
                '''
            }
        }

        stage('Update Kubernetes Deployment') {
            steps {
                sh '''
                    sed -i "s|image: kre1/website:.*|image: ${IMAGE_NAME}:${IMAGE_TAG}|" k8s/deployment.yaml
                    kubectl apply -f k8s/deployment.yaml --namespace=${NAMESPACE}
                    kubectl rollout status deployment/website --namespace=${NAMESPACE}
                '''
            }
        }
    }
}
