#!groovy

node {
  stage 'checkout deps'
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
      credentialsId: '27da958c-432d-4255-bb57-abf00bb670d6',
      url: 'git@github.com:cliqz/xpi-sign'
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
