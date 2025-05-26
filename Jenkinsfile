pipeline {
    agent any

    environment {
        DOCKERHUB_CREDENTIALS_ID = 'dockerhub-creds' // ID of the Docker Hub credentials in Jenkins
        CLIENT_BASE_DIR          = '.' // Assumes client folders (client1, client2) are at the root. Change if they are nested.
        APPS_SUB_DIR             = 'website' // Subdirectory within each client folder for apps
        K8S_SUB_DIR              = 'k8s'     // Subdirectory within each client folder for K8s manifests
        CONFIG_FILE_NAME         = '.jenkins_config.properties'
        IMAGE_PLACEHOLDER_TAG    = 'PLACEHOLDER'
    }

    stages {
        stage('Discover Clients & Changes') {
            steps {
                script {
                    env.CLIENTS_TO_PROCESS = '' // Comma-separated list of client folder names to process
                    def changedFilesOutput = sh(script: "git diff --name-only ${env.GIT_PREVIOUS_COMMIT} ${env.GIT_COMMIT}", returnStdout: true).trim()
                    def changedFiles = []
                    if (changedFilesOutput) {
                        changedFiles = changedFilesOutput.split('\\n')
                    }
                    echo "Changed files in this commit (repo root): ${changedFiles.join(', ')}"

                    def clientList = []
                    // Discover client directories by listing subdirectories at CLIENT_BASE_DIR that contain a CONFIG_FILE_NAME
                    // This is more robust than just listing all dirs. Excludes .git, etc.
                    try {
                        def findClientDirsCmd = "find ${env.CLIENT_BASE_DIR} -maxdepth 1 -type d -exec test -f {}/${env.CONFIG_FILE_NAME} \\; -print | cut -d'/' -f2 || true"
                        if (isUnix()) {
                             findClientDirsCmd = "find ${env.CLIENT_BASE_DIR} -maxdepth 1 -type d -exec test -f {}/${env.CONFIG_FILE_NAME} \\; -print | cut -d'/' -f2 || true"
                        } else { // Basic ls for non-unix, less precise, might need refinement for Windows
                            // This Windows version is a placeholder and might require a more robust PowerShell script for discovery
                            // It simply lists directories at the root. You'd then rely on the .jenkins_config.properties check later.
                            findClientDirsCmd = "cmd /c dir /b /ad ${env.CLIENT_BASE_DIR} || true"
                        }
                        
                        def discoveredClientNames = sh(script: findClientDirsCmd, returnStdout: true).trim().split('[\r\n]+')
                        
                        for (String clientName : discoveredClientNames) {
                            if (clientName && !clientName.isEmpty() && clientName != "." && clientName != ".." && !clientName.startsWith(".git")) {
                                // Further check if the config file actually exists, as ls/dir might not be as precise as find
                                if (fileExists("${env.CLIENT_BASE_DIR}/${clientName}/${env.CONFIG_FILE_NAME}")) {
                                    clientList.add(clientName.trim())
                                }
                            }
                        }
                    } catch (Exception e) {
                        echo "Warning: Could not robustly list client directories. Error: ${e.getMessage()}"
                    }
                    clientList = clientList.unique().sort() // Ensure unique and sorted
                    echo "Discovered potential client folders: ${clientList.join(', ')}"

                    def clientsToProcessList = []
                    boolean jenkinsfileChanged = false
                    for (String file : changedFiles) {
                        if (file.equals("Jenkinsfile")) {
                            jenkinsfileChanged = true
                            break
                        }
                    }

                    if (changedFiles.isEmpty() || jenkinsfileChanged) {
                        if (jenkinsfileChanged) {
                            echo "Detected changes in the root Jenkinsfile. Flagging all clients for processing."
                        } else {
                            echo "No specific changed files detected at repo level (or first run). Flagging all discovered clients for processing."
                        }
                        clientsToProcessList.addAll(clientList)
                    } else {
                        echo "Specific changed files detected. Determining affected clients..."
                        for (String clientName : clientList) {
                            String clientDirInRepo = "${env.CLIENT_BASE_DIR}/${clientName}/".replaceAll("./", "") // Path relative to repo root
                            boolean clientAffected = false
                            for (String file : changedFiles) {
                                if (file.startsWith(clientDirInRepo)) {
                                    clientAffected = true
                                    break
                                }
                            }
                            if (clientAffected) {
                                if (!clientsToProcessList.contains(clientName)) {
                                    clientsToProcessList.add(clientName)
                                    echo "Client ${clientName} is affected by changes."
                                }
                            }
                        }
                    }

                    if (clientsToProcessList.isEmpty() && !clientList.isEmpty()) {
                        echo "No changes detected impacting any specific client folder or the root Jenkinsfile. No clients will be processed."
                    } else if (clientList.isEmpty()){
                        echo "No client folders with ${env.CONFIG_FILE_NAME} found in ${env.CLIENT_BASE_DIR}/"
                    }

                    env.CLIENTS_TO_PROCESS = clientsToProcessList.unique().join(',') // Ensure unique before joining
                    echo "Client folders flagged for processing: ${env.CLIENTS_TO_PROCESS ?: 'None'}"
                    env.GLOBAL_CHANGED_FILES = changedFiles.join(',') // Store for later stages
                }
            }
        }

        stage('Process Clients') {
            when { expression { env.CLIENTS_TO_PROCESS != '' } }
            steps {
                script {
                    if (env.CLIENTS_TO_PROCESS.isEmpty()) {
                        echo "No clients to process. Skipping."
                        return
                    }
                    def clients = env.CLIENTS_TO_PROCESS.split(',').collect{ it.trim() }.findAll{ !it.isEmpty() }
                    def globalChangedFilesList = env.GLOBAL_CHANGED_FILES ? env.GLOBAL_CHANGED_FILES.split(',') : [] // Retrieve and split
                    
                    for (String clientName : clients) {
                        echo "=================================================================="
                        echo "Processing Client: ${clientName}"
                        echo "=================================================================="
                        
                        // Define client-specific paths
                        def clientDirPath = "${env.CLIENT_BASE_DIR}/${clientName}".replaceAll("./", "")
                        def clientConfigFile = "${clientDirPath}/${env.CONFIG_FILE_NAME}"
                        def clientAppsBaseDir = "${clientDirPath}/${env.APPS_SUB_DIR}"
                        def clientK8sManifestsDir = "${clientDirPath}/${env.K8S_SUB_DIR}"

                        // Load client-specific properties
                        def props = readProperties file: clientConfigFile
                        def k8sNamespace = props.K8S_NAMESPACE
                        def dockerRegistryUser = props.DOCKER_REGISTRY_USER

                        if (!k8sNamespace || !dockerRegistryUser) {
                            echo "ERROR: K8S_NAMESPACE or DOCKER_REGISTRY_USER not found in ${clientConfigFile} for client ${clientName}. Skipping this client."
                            currentBuild.result = 'FAILURE'
                            continue
                        }
                        echo "Client ${clientName} - K8S Namespace: ${k8sNamespace}, Docker User: ${dockerRegistryUser}"

                        // Ensure K8s Namespace Exists for this client
                        sh """
                            if ! kubectl get namespace ${k8sNamespace} > /dev/null 2>&1; then
                                kubectl create namespace ${k8sNamespace}
                                echo "Created namespace ${k8sNamespace} for client ${clientName}"
                            else
                                echo "Namespace ${k8sNamespace} for client ${clientName} already exists"
                            fi
                        """

                        // Discover and process apps for this client
                        def appList = []
                        try {
                            def findAppsCmd = "find ${clientAppsBaseDir} -maxdepth 1 -mindepth 1 -type d -printf '%f\\n' || true" // More robust way to get just subdir names
                            if (!isUnix()) {
                                findAppsCmd = "cmd /c dir /b /ad ${clientAppsBaseDir} || true" // Basic Windows version, should be okay
                            }
                            def discoveredAppNames = sh(script: findAppsCmd, returnStdout: true).trim().split('[\r\n]+')
                            for(String appNameEntry : discoveredAppNames) {
                                if (appNameEntry && !appNameEntry.isEmpty() && !appNameEntry.contains('ls -d') && !appNameEntry.contains('File Not Found')) {
                                    appList.add(appNameEntry.trim())
                                }
                            }
                        } catch (Exception e) {
                            echo "Warning: Could not list app directories in ${clientAppsBaseDir}. Error: ${e.getMessage()}"
                        }
                        appList = appList.unique().sort()
                        echo "Client ${clientName} - Discovered apps: ${appList.join(', ')}"
                        if (appList.isEmpty()){ 
                            echo "Client ${clientName} - No apps found in ${clientAppsBaseDir}."
                            continue // Move to next client if no apps
                        }

                        // Determine which of this client's apps need deployment based on `globalChangedFilesList`
                        def appsToDeployForThisClient = []
                        // A client is processed if its folder was in CLIENTS_TO_PROCESS.
                        // Now, determine if ALL apps for this client deploy, or only changed ones.

                        boolean deployAllAppsForThisClientBecauseClientFolderWasFlagged = env.CLIENTS_TO_PROCESS.split(',').contains(clientName)
                        boolean jenkinsfileOrNoSpecificChangesTriggeredAll = env.GLOBAL_CHANGED_FILES.isEmpty() || env.GLOBAL_CHANGED_FILES.split(',').contains("Jenkinsfile")


                        if (jenkinsfileOrNoSpecificChangesTriggeredAll && deployAllAppsForThisClientBecauseClientFolderWasFlagged) {
                            echo "Client ${clientName}: Jenkinsfile changed or no specific file changes; deploying all apps for this flagged client."
                            appsToDeployForThisClient.addAll(appList)
                        } else if (deployAllAppsForThisClientBecauseClientFolderWasFlagged) {
                            // Client folder was flagged. Check for specific app changes within it.
                            // If specific app changes, deploy only those.
                            // If client folder was flagged due to a non-app change (e.g. k8s manifest at client level, or .jenkins_config), deploy all its apps.
                            boolean specificAppChangedInThisClient = false
                            for (String appName : appList) {
                                String appSourceDirInRepo = "${clientAppsBaseDir}/${appName}/".replaceAll("./","")
                                for (String file : globalChangedFilesList) {
                                    if (file.startsWith(appSourceDirInRepo)) {
                                        if (!appsToDeployForThisClient.contains(appName)) {
                                            appsToDeployForThisClient.add(appName)
                                        }
                                        specificAppChangedInThisClient = true
                                        // Do not break here, collect all changed apps for this client
                                    }
                                }
                            }
                            if (!specificAppChangedInThisClient && !appList.isEmpty()) {
                                // Client folder was impacted, but no specific *app source* files.
                                // This implies a change to client-level k8s, .jenkins_config, or other non-app files.
                                // In this case, re-deploy all apps for this client.
                                echo "Client ${clientName}: Client folder was impacted by non-app-specific changes (e.g., k8s config, client config). Deploying all apps for this client."
                                appsToDeployForThisClient.clear() // Clear any potentially added apps if logic was mixed
                                appsToDeployForThisClient.addAll(appList)
                            } else if (appsToDeployForThisClient.isEmpty() && !appList.isEmpty()) {
                                // This case should ideally not be hit if the client was flagged and had apps,
                                // unless only non-relevant files within client dir changed.
                                // To be safe, if client was flagged but no apps selected, deploy all.
                                echo "Client ${clientName}: Client folder was impacted, but no specific app changes identified. Deploying all apps for this client as a precaution."
                                appsToDeployForThisClient.addAll(appList)
                            }
                        }


                        if (appsToDeployForThisClient.isEmpty()) {
                            echo "Client ${clientName} - No specific app changes detected that require deployment."
                            continue
                        }
                        echo "Client ${clientName} - Apps to deploy: ${appsToDeployForThisClient.join(', ')}"

                        for (String appName : appsToDeployForThisClient) {
                            echo "-----------------------------------------------------           "
                            echo "Client ${clientName} - Processing Application: ${appName}"
                            echo "-----------------------------------------------------           "

                            def appNameLower = appName.toLowerCase()
                            def imageRepo = "${dockerRegistryUser}/${appNameLower}" // Use client-specific docker user
                            def imageTag = new Date().format('yyyyMMdd-HHmm')
                            def fullImageName = "${imageRepo}:${imageTag}"
                            def appSourceDir = "${clientAppsBaseDir}/${appName}"
                            def appDockerfile = "${appSourceDir}/Dockerfile"
                            def k8sDeploymentFile = "${clientK8sManifestsDir}/${appNameLower}-deployment.yaml"
                            def k8sResourceName = "${appNameLower}-deployment"

                            if (!fileExists(appDockerfile)) {
                                echo "WARNING: Client ${clientName} - Dockerfile not found for ${appName} at ${appDockerfile}. Skipping."
                                continue
                            }
                            if (!fileExists(k8sDeploymentFile)) {
                                echo "WARNING: Client ${clientName} - K8s deployment manifest not found for ${appName} at ${k8sDeploymentFile}. Skipping."
                                continue
                            }

                            try {
                                echo "Client ${clientName} - Building ${appName}: ${fullImageName} from ${appDockerfile} with context ${appSourceDir}"
                                sh "docker build -t ${fullImageName} -f ${appDockerfile} ${appSourceDir}"

                                echo "Client ${clientName} - Pushing ${appName}: ${fullImageName}"
                                withCredentials([usernamePassword(credentialsId: env.DOCKERHUB_CREDENTIALS_ID, usernameVariable: 'DOCKER_LOGIN_USER', passwordVariable: 'DOCKER_LOGIN_PASS')]) {
                                    sh "echo $DOCKER_LOGIN_PASS | docker login -u $DOCKER_LOGIN_USER --password-stdin"
                                }
                                sh "docker push ${fullImageName}"

                                echo "Client ${clientName} - Deploying ${appName} to K8s namespace ${k8sNamespace}"
                                def originalImagePattern = "image: ${imageRepo}:${env.IMAGE_PLACEHOLDER_TAG}"
                                def sedCmd = "sed -i 's|${originalImagePattern}|image: ${fullImageName}|' ${k8sDeploymentFile}"
                                echo "Updating deployment YAML: ${sedCmd}"
                                sh sedCmd
                                
                                sh "kubectl apply -f ${k8sDeploymentFile} --namespace=${k8sNamespace}"
                                sh "kubectl rollout status deployment/${k8sResourceName} --namespace=${k8sNamespace} --timeout=300s"
                                
                                echo "Client ${clientName} - Successfully processed ${appName}."
                            } catch (Exception e) {
                                echo "ERROR: Client ${clientName} - Processing application ${appName}: ${e.getMessage()}"
                                currentBuild.result = 'FAILURE'
                            }
                        }
                    }
                    if (currentBuild.result != 'SUCCESS' && currentBuild.result != 'UNSTABLE') {
                        error "One or more clients or applications failed to process."
                    }
                }
            }
        }
    }
} 