#!groovy

properties([
    parameters([
        string(name: 'XPI_URL', defaultValue: 'https://addons.mozilla.org/firefox/downloads/latest-beta/8542/addon-8542-latest.xpi?src=dp-btn-devchannel'),
        string(name: 'XPI_SIGN_CREDENTIALS', defaultValue: '41572f9c-06aa-46f0-9c3b-b7f4f78e9caa'),
        string(name: 'XPI_SIGN_REPO_URL', defaultValue: 'git@github.com:cliqz/xpi-sign.git'),
        string(name: 'CHANNEL', defaultValue: 'browser')
    ])
])

node('master') {
    def imgName

    stage('checkout deps') {
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
                credentialsId: params.XPI_SIGN_CREDENTIALS,
                url: params.XPI_SIGN_REPO_URL
            ]]
        ])
    }

    stage('prepare workspace') {
        sh 'rm -fr secure'
        sh 'cp -R /cliqz secure'
    }

    stage('build docker image') {
        imgName = "cliqz-oss/browser-features:${env.BUILD_TAG}"
        docker.build(imgName, '.')
    }

    stage('repack and upload') {
        docker.image(imgName).inside {
            withEnv([
                'RANDFILE=.rnd'
            ]) {
                def addonId = sh(returnStdout: true, script: "/bin/bash ./repack_and_upload.sh ${params.XPI_URL} ${params.CHANNEL} | grep 'Addon:' | head -n 1").trim()
                currentBuild.description = addonId
            }
        }
    }

    stage('cleanup') {
        sh 'rm -rf secure'
    }
}
