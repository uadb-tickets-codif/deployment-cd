// Pipeline CD : à compléter (carte 26)

def notify(String color, String msg) {
  echo "NOTIFICATION : ${msg}"
  try {
    slackSend(channel: '#devops-ci', color: color, message: msg,
              tokenCredentialId: 'slack-token', botUser: true)
  } catch (err) {
    echo "Slack non disponible : ${err.getMessage()}"
  }
}

pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
  }

  parameters {
    string(name: 'BACKEND_TAG',  defaultValue: 'latest', description: 'Tag de l image backend')
    string(name: 'FRONTEND_TAG', defaultValue: 'latest', description: 'Tag de l image frontend')
  }

  environment {
    //COMPOSE_PROJECT_NAME = 'uadb-services'
    BACKEND_SERVICE      = 'backend'
    FRONTEND_SERVICE     = 'frontend'
    BACKEND_PORT         = '3001'
    FRONTEND_PORT        = '3000'
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Récupération des images') {
      steps {
        sh '''
          export BACKEND_TAG=${BACKEND_TAG} FRONTEND_TAG=${FRONTEND_TAG}
          docker compose pull
        '''
      }
    }

    stage('Déploiement') {
      steps {
        sh '''
          export BACKEND_TAG=${BACKEND_TAG} FRONTEND_TAG=${FRONTEND_TAG}
          docker compose up -d --remove-orphans
          docker compose ps
        '''
      }
    }

    stage('Health check') {
      steps {
        sh '''
          check() {
            SERVICE=$1; URL=$2
            for i in $(seq 1 30); do
              if docker compose exec -T $SERVICE wget -q -O /dev/null $URL; then
                echo "$SERVICE : OK"
                return 0
              fi
              echo "$SERVICE : en attente ($i/30)"
              sleep 5
            done
            echo "$SERVICE : ECHEC"
            docker compose logs --tail=50 $SERVICE
            return 1
          }
          check $BACKEND_SERVICE  http://127.0.0.1:$BACKEND_PORT/health
          check $FRONTEND_SERVICE http://127.0.0.1:$FRONTEND_PORT/
        '''
      }
    }
  }

  post {
    success {
      script { notify('good', "Déploiement OK : backend ${params.BACKEND_TAG}, frontend ${params.FRONTEND_TAG}") }
    }
    failure {
      script { notify('danger', "Déploiement ECHEC : ${env.BUILD_URL}") }
    }
  }
}
