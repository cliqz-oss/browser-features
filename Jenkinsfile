#!groovy

node("master") {
  stage 'checkout deps'
  checkout scm
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

  stage 'prepare workspace'
  sh 'rm -fr secure'
  sh 'cp -R /cliqz secure'

  stage 'build docker image'
  def imgName = "cliqz-oss/browser-features:${env.BUILD_TAG}"
  docker.build(imgName, ".")

  stage 'repack and upload'
  docker.image(imgName).inside {
    sh '/bin/bash ./repack_and_upload.sh '+XPI_URL
  }

  stage 'cleanup'
  sh 'rm -rf secure'
}
