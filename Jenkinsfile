@Library('utilities') _

node('build-docker') {

  stage('Checkout') {
    checkout scm
  }

  stage('Package') {
    echo env.BRANCH_NAME
    sh "mkdir dist/"
    sh "zip -r dist/ci-${env.BUILD_NUMBER}.zip . -x *.git*"
    sh "cp dist/ci-${env.BUILD_NUMBER}.zip dist/ci-latest.zip"
  }

  stage('Archive') {
    archiveArtifacts artifacts: 'dist/*', fingerprint: true, onlyIfSuccessful: true
  }

  stage('Publish') {
    if (currentBuild.resultIsBetterOrEqualTo('SUCCESS')) {
      publishArtifact("dist/ci-${env.BUILD_NUMBER}.zip", 'ci')
      publishArtifact("dist/ci-latest.zip", 'ci')
    } else {
      echo 'Build was unsuccessful. Skipping publish of artifacts...'
    }
  }
}
