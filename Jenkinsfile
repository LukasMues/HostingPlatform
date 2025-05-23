pipeline {
    agent any

    environment {
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-creds') // your Jenkins credential ID
        IMAGE_NAME = 'kre1/website7'
        IMAGE_TAG = "${new Date().format('yyyyMMdd-HHmm')}"
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

        stage('Update Kubernetes Deployment') {
            steps {
                sh '''
                    sed -i "s|image: kre1/website:.*|image: ${IMAGE_NAME}:${IMAGE_TAG}|" k8s/deployment.yaml
                    kubectl apply -f k8s/deployment.yaml --namespace=client1 --validate=false
                    kubectl rollout status deployment/website --namespace=client1
                '''
            }
        }
    }
}
