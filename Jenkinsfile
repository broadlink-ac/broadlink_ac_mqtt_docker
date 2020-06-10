pipeline {
  agent any
  // Configuration for the variables used for this specific repo
  environment {
    BUILDS_DISCORD=credentials('build_webhook_url')
    GITHUB_TOKEN=credentials('github-token')
    EXT_GIT_BRANCH = 'master'
    EXT_USER = 'liaan'
    EXT_REPO = 'broadlink_ac_mqtt'
    BUILD_VERSION_ARG = 'AC2MQTT_VERSION'
    GH_USER = 'broadlink-ac'
    GH_REPO = 'broadlink_ac_mqtt_docker'
    CONTAINER_NAME = 'broadlink_ac'
    DOCKERHUB_IMAGE = 'broadlinkac/broadlink_ac_mqtt'
    DIST_IMAGE = 'alpine'
  }
  stages {
    // Setup all the basic environment variables needed for the build
    stage("Set ENV Variables base"){
      steps{
        script{
          env.EXIT_STATUS = ''
          env.GH_RELEASE = sh(
            script: '''docker run --rm alexeiled/skopeo sh -c 'skopeo inspect docker://docker.io/'${DOCKERHUB_IMAGE}':latest 2>/dev/null' | jq -r '.Labels.build_version' | awk '{print $3}' | grep '\\-gh' || : ''',
            returnStdout: true).trim()
          env.GITHUB_DATE = sh(
            script: '''date '+%Y-%m-%dT%H:%M:%S%:z' ''',
            returnStdout: true).trim()
          env.COMMIT_SHA = sh(
            script: '''git rev-parse HEAD''',
            returnStdout: true).trim()
          env.CODE_URL = 'https://github.com/' + env.GH_USER + '/' + env.GH_REPO + '/commit/' + env.GIT_COMMIT
          env.DOCKERHUB_LINK = 'https://hub.docker.com/r/' + env.DOCKERHUB_IMAGE + '/tags/'
          env.PULL_REQUEST = env.CHANGE_ID
          env.TEMPLATED_FILES = 'Jenkinsfile README.md LICENSE'
        }
        script{
          env.GH_RELEASE_NUMBER = sh(
            script: '''echo ${GH_RELEASE} |sed 's/^.*-gh//g' ''',
            returnStdout: true).trim()
        }
        script{
          env.GH_TAG_NUMBER = sh(
            script: '''#! /bin/bash
                       tagsha=$(git rev-list -n 1 ${GH_RELEASE} 2>/dev/null)
                       if [ "${tagsha}" == "${COMMIT_SHA}" ]; then
                         echo ${GH_RELEASE_NUMBER}
                       elif [ -z "${GIT_COMMIT}" ]; then
                         echo ${GH_RELEASE_NUMBER}
                       else
                         echo $((${GH_RELEASE_NUMBER} + 1))
                       fi''',
            returnStdout: true).trim()
        }
      }
    }
    /* ########################
       External Release Tagging
       ######################## */
    // If this is a stable github release use the latest endpoint from github to determine the ext tag
    stage("Set ENV github_stable"){
     steps{
       script{
         env.EXT_RELEASE = sh(
           script: '''curl -s https://api.github.com/repos/${EXT_USER}/${EXT_REPO}/releases/latest | jq -r '. | .tag_name' ''',
           returnStdout: true).trim()
       }
     }
    }
    // If this is a stable or devel github release generate the link for the build message
    stage("Set ENV github_link"){
     steps{
       script{
         env.RELEASE_LINK = 'https://github.com/' + env.EXT_USER + '/' + env.EXT_REPO + '/releases/tag/' + env.EXT_RELEASE
       }
     }
    }
    // If this is a master build use live docker endpoints
    stage("Set ENV live build"){
      when {
        branch "master"
        environment name: 'CHANGE_ID', value: ''
      }
      steps {
        script{
          env.IMAGE = env.DOCKERHUB_IMAGE
          env.GITHUBIMAGE = 'docker.pkg.github.com/' + env.GH_USER + '/' + env.GH_REPO + '/' + env.CONTAINER_NAME
          env.CI_TAGS = env.EXT_RELEASE_CLEAN + '-gh' + env.GH_TAG_NUMBER
          env.META_TAG = env.EXT_RELEASE_CLEAN + '-gh' + env.GH_TAG_NUMBER
        }
      }
    }
    /* ###############
       Build Container
       ############### */
    // Build Docker container for push to LS Repo
    stage('Build-Single') {
      when {
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        sh "docker build --no-cache --pull -t ${IMAGE}:${META_TAG} \
        --build-arg ${BUILD_VERSION_ARG}=${EXT_RELEASE} --build-arg VERSION=\"${META_TAG}\" --build-arg BUILD_DATE=${GITHUB_DATE} ."
      }
    }
    // Take the image we just built and dump package versions for comparison
    stage('Update-packages') {
      when {
        branch "master"
        environment name: 'CHANGE_ID', value: ''
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        sh '''#! /bin/bash
              set -e
              TEMPDIR=$(mktemp -d)
              LOCAL_CONTAINER=${IMAGE}:${META_TAG}
              docker run --rm --entrypoint '/bin/sh' -v ${TEMPDIR}:/tmp ${LOCAL_CONTAINER} -c '\
                apk info -v > /tmp/package_versions.txt && \
                sort -o /tmp/package_versions.txt  /tmp/package_versions.txt && \
                chmod 777 /tmp/package_versions.txt'
              NEW_PACKAGE_TAG=$(md5sum ${TEMPDIR}/package_versions.txt | cut -c1-8 )
              echo "Package tag sha from current packages in buit container is ${NEW_PACKAGE_TAG} comparing to old ${PACKAGE_TAG} from github"
              if [ "${NEW_PACKAGE_TAG}" != "${PACKAGE_TAG}" ]; then
                git clone https://github.com/${GH_USER}/${GH_REPO}.git ${TEMPDIR}/${GH_REPO}
                git --git-dir ${TEMPDIR}/${GH_REPO}/.git checkout -f master
                cp ${TEMPDIR}/package_versions.txt ${TEMPDIR}/${GH_REPO}/
                cd ${TEMPDIR}/${GH_REPO}/
                wait
                git add package_versions.txt
                git commit -m 'Bot Updating Package Versions'
                git push https://BroadlinkAc-CI:${GITHUB_TOKEN}@github.com/${GH_USER}/${GH_REPO}.git --all
                echo "true" > /tmp/packages-${COMMIT_SHA}-${BUILD_NUMBER}
                echo "Package tag updated, stopping build process"
              else
                echo "false" > /tmp/packages-${COMMIT_SHA}-${BUILD_NUMBER}
                echo "Package tag is same as previous continue with build process"
              fi
              rm -Rf ${TEMPDIR}'''
        script{
          env.PACKAGE_UPDATED = sh(
            script: '''cat /tmp/packages-${COMMIT_SHA}-${BUILD_NUMBER}''',
            returnStdout: true).trim()
        }
      }
    }
    // Exit the build if the package file was just updated
    stage('PACKAGE-exit') {
      when {
        branch "master"
        environment name: 'CHANGE_ID', value: ''
        environment name: 'PACKAGE_UPDATED', value: 'true'
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        script{
          env.EXIT_STATUS = 'ABORTED'
        }
      }
    }
    // Exit the build if this is just a package check and there are no changes to push
    stage('PACKAGECHECK-exit') {
      when {
        branch "master"
        environment name: 'CHANGE_ID', value: ''
        environment name: 'PACKAGE_UPDATED', value: 'false'
        environment name: 'EXIT_STATUS', value: ''
        expression {
          params.PACKAGE_CHECK == 'true'
        }
      }
      steps {
        script{
          env.EXIT_STATUS = 'ABORTED'
        }
      }
    }
    /* ##################
         Release Logic
       ################## */
    // If this is an amd64 only image only push a single image
    stage('Docker-Push-Single') {
      when {
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        withCredentials([
          [
            $class: 'UsernamePasswordMultiBinding',
            credentialsId: 'docker-ci',
            usernameVariable: 'DOCKERUSER',
            passwordVariable: 'DOCKERPASS'
          ]
        ]) {
          retry(5) {
            sh '''#! /bin/bash
                  set -e
                  echo $DOCKERPASS | docker login -u $DOCKERUSER --password-stdin
                  echo $GITHUB_TOKEN | docker login docker.pkg.github.com -u BroadlinkAc-CI --password-stdin
                  for PUSHIMAGE in "${GITHUBIMAGE}" "${GITLABIMAGE}" "${IMAGE}"; do
                    docker tag ${IMAGE}:${META_TAG} ${PUSHIMAGE}:${META_TAG}
                    docker tag ${PUSHIMAGE}:${META_TAG} ${PUSHIMAGE}:latest
                    docker push ${PUSHIMAGE}:latest
                    docker push ${PUSHIMAGE}:${META_TAG}
                  done
               '''
          }
          sh '''#! /bin/bash
                for DELETEIMAGE in "${GITHUBIMAGE}" "{GITLABIMAGE}" "${IMAGE}"; do
                  docker rmi \
                  ${DELETEIMAGE}:${META_TAG} \
                  ${DELETEIMAGE}:latest || :
                done
             '''
        }
      }
    }
    // If this is a public release tag it in the LS Github
    stage('Github-Tag-Push-Release') {
      when {
        branch "master"
        expression {
          env.GH_RELEASE != env.EXT_RELEASE_CLEAN + '-gh' + env.GH_TAG_NUMBER
        }
        environment name: 'CHANGE_ID', value: ''
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        echo "Pushing New tag for current commit ${EXT_RELEASE_CLEAN}-gh${GH_TAG_NUMBER}"
        sh '''curl -H "Authorization: token ${GITHUB_TOKEN}" -X POST https://api.github.com/repos/${GH_USER}/${GH_REPO}/git/tags \
        -d '{"tag":"'${EXT_RELEASE_CLEAN}'-gh'${GH_TAG_NUMBER}'",\
             "object": "'${COMMIT_SHA}'",\
             "message": "Tagging Release '${EXT_RELEASE_CLEAN}'-gh'${GH_TAG_NUMBER}' to master",\
             "type": "commit",\
             "tagger": {"name": "Jenkins","email": "jenkins@jenkins.com","date": "'${GITHUB_DATE}'"}}' '''
        echo "Pushing New release for Tag"
        sh '''#! /bin/bash
              curl -s https://api.github.com/repos/${EXT_USER}/${EXT_REPO}/releases/latest | jq '. |.body' | sed 's:^.\\(.*\\).$:\\1:' > releasebody.json
              echo '{"tag_name":"'${EXT_RELEASE_CLEAN}'-gh'${GH_TAG_NUMBER}'",\
                     "target_commitish": "master",\
                     "name": "'${EXT_RELEASE_CLEAN}'-gh'${GH_TAG_NUMBER}'",\
                     "body": "**Changes:**\\n\\n**'${EXT_REPO}' Changes:**\\n\\n' > start
              printf '","draft": false,"prerelease": false}' >> releasebody.json
              paste -d'\\0' start releasebody.json > releasebody.json.done
              curl -H "Authorization: token ${GITHUB_TOKEN}" -X POST https://api.github.com/repos/${GH_USER}/${GH_REPO}/releases -d @releasebody.json.done'''
      }
    }
  }
  /* ######################
     Send status to Discord
     ###################### */
  post {
    always {
      script{
        if (env.EXIT_STATUS == "ABORTED"){
          sh 'echo "build aborted"'
        }
        else if (currentBuild.currentResult == "SUCCESS"){
          sh ''' curl -X POST -H "Content-Type: application/json" --data '{"avatar_url": "https://wiki.jenkins-ci.org/download/attachments/2916393/headshot.png","embeds": [{"color": 1681177,\
                 "description": "**Build:**  '${BUILD_NUMBER}'\\n**Status:**  Success\\n**Job:** '${RUN_DISPLAY_URL}'\\n**Change:** '${CODE_URL}'\\n**External Release:**: '${RELEASE_LINK}'\\n**DockerHub:** '${DOCKERHUB_LINK}'\\n"}],\
                 "username": "Jenkins"}' ${BUILDS_DISCORD} '''
        }
        else {
          sh ''' curl -X POST -H "Content-Type: application/json" --data '{"avatar_url": "https://wiki.jenkins-ci.org/download/attachments/2916393/headshot.png","embeds": [{"color": 16711680,\
                 "description": "**Build:**  '${BUILD_NUMBER}'\\n**Status:**  failure\\n**Job:** '${RUN_DISPLAY_URL}'\\n**Change:** '${CODE_URL}'\\n**External Release:**: '${RELEASE_LINK}'\\n**DockerHub:** '${DOCKERHUB_LINK}'\\n"}],\
                 "username": "Jenkins"}' ${BUILDS_DISCORD} '''
        }
      }
    }
    cleanup {
      cleanWs()
    }
  }
 }
