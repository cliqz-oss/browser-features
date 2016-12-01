#!groovy

node("master") {
  stage('checkout deps') {
      git 'https://github.com/cliqz-oss/browser-features.git'
      checkout([
        $class: 'GitSCM',
        branches: [[name: '*/cliqz-ci']],
        doGenerateSubmoduleConfigurations: false,
        extensions: [[
          $class: 'RelativeTargetDirectory',
          relativeTargetDir: 'xpi-sign'
        ]],
        submoduleCfg: [],
        userRemoteConfigs: [[
          credentialsId: XPI_SIGN_CREDENTIALS,
          url: XPI_SIGN_REPO_URL
        ]]
      ])
  }

  stage('prepare workspace') {
    sh 'rm -fr secure'
    sh 'cp -R /cliqz secure'
  }

  stage('build docker image') {
    def imgName = "cliqz-oss/browser-features:${env.BUILD_TAG}"
    docker.build(imgName, ".")
  }
  stage('repack and upload') {
      docker.image(imgName).inside {
        withCredentials([
            file(credentialsId: '173621c3-7549-4e29-8005-04175db53e37', variable: 'XPISIGN_CERT'),
            file(credentialsId: '3496a127-ea1c-40ab-95ee-7c830dea2a40', variable: 'XPISIGN_PASS'),
            [$class: 'AmazonWebServicesCredentialsBinding', accessKeyVariable: 'AWS_ACCESS_KEY_ID', credentialsId: '    62c70c1d-7d0a-4eb8-9987-38288ebf25cf', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'],
            file(credentialsId: '368f4e39-a1c0-4e11-bafa-e14be548e3ae', variable: 'BALROG_CREDS')]) {
                sh '/bin/bash ./repack_and_upload.sh '+XPI_URL
        }
      }
  }

}
