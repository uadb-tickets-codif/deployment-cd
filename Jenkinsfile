def notify(String color, String msg) {
  echo "NOTIFICATION : ${msg}"
  try {
    slackSend(channel: '#devops-ci', color: color, message: msg,
              tokenCredentialId: 'slack-token', botUser: true)
  } catch (err) {
    echo "Slack non disponible : ${err.getMessage()}"
  }
}

// Mise à jour d'un service sans interruption : deux répliques pendant la bascule
def rollingUpdate(String service, String imageRegex) {
  withEnv(["SVC=${service}", "IMG_RE=${imageRegex}"]) {
    sh '''
      IMG=$(docker compose config --images | grep -E "$IMG_RE" | head -1)
      TARGET_ID=$(docker image inspect -f '{{.Id}}' "$IMG")
      OLD_IDS=$(docker compose ps -q $SVC | tr '\\n' ' ')

      if [ -z "$OLD_IDS" ]; then
        echo "Premier déploiement de $SVC"
        docker compose up -d --no-deps --wait $SVC
      else
        FIRST_OLD=$(echo $OLD_IDS | cut -d' ' -f1)
        RUNNING_ID=$(docker inspect -f '{{.Image}}' "$FIRST_OLD")
        if [ "$RUNNING_ID" = "$TARGET_ID" ]; then
          echo "$SVC déjà à jour ($IMG)"
        else
          echo "Mise à jour de $SVC : $IMG, démarrage d'une seconde réplique"
          docker compose up -d --no-deps --no-recreate --scale $SVC=2 $SVC

          NEW_ID=""
          for id in $(docker compose ps -q $SVC); do
            case " $OLD_IDS " in
              *" $id "*) ;;
              *) NEW_ID=$id ;;
            esac
          done
          echo "Nouvelle réplique : $NEW_ID"

          HEALTHY=no
          for i in $(seq 1 40); do
            S=$(docker inspect -f '{{.State.Health.Status}}' "$NEW_ID" 2>/dev/null || echo none)
            echo "Nouvelle réplique de $SVC : $S ($i/40)"
            if [ "$S" = "healthy" ]; then HEALTHY=yes; break; fi
            sleep 3
          done

          if [ "$HEALTHY" != "yes" ]; then
            echo "ECHEC : la nouvelle version de $SVC n'est pas saine, l'ancienne reste en service"
            docker logs --tail=40 "$NEW_ID" || true
            docker rm -f "$NEW_ID"
            exit 1
          fi

          echo "Les deux répliques de $SVC sont actives, le proxy les découvre"
          sleep 5
          echo "Retrait de l'ancienne réplique : $OLD_IDS"
          docker stop -t 20 $OLD_IDS
          docker rm $OLD_IDS
        fi
      fi
      docker compose ps $SVC
    '''
  }
}

pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '15'))
  }

  parameters {
    string(name: 'BACKEND_TAG',  defaultValue: 'latest', description: 'Tag de l image backend')
    string(name: 'FRONTEND_TAG', defaultValue: 'latest', description: 'Tag de l image frontend')
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Vérification de la configuration') {
      steps {
        sh '''
          export BACKEND_TAG=${BACKEND_TAG} FRONTEND_TAG=${FRONTEND_TAG}
          docker compose config --quiet
          docker compose config --images
        '''
      }
    }

    stage('Récupération des images') {
      steps {
        sh '''
          export BACKEND_TAG=${BACKEND_TAG} FRONTEND_TAG=${FRONTEND_TAG}
          docker compose pull --ignore-buildable
        '''
      }
    }

    stage('Base de données') {
      steps {
        sh '''
          export BACKEND_TAG=${BACKEND_TAG} FRONTEND_TAG=${FRONTEND_TAG}
          docker compose up -d --no-deps --wait postgres
        '''
      }
    }

    stage('Backend : mise à jour sans interruption') {
      steps {
        script {
          withEnv(["BACKEND_TAG=${params.BACKEND_TAG}", "FRONTEND_TAG=${params.FRONTEND_TAG}"]) {
            rollingUpdate('backend', '/backend:')
          }
        }
      }
    }

    stage('Proxy') {
      steps {
        sh '''
          export BACKEND_TAG=${BACKEND_TAG} FRONTEND_TAG=${FRONTEND_TAG}

          HASH=$(cat nginx/Dockerfile nginx/default.conf | sha256sum | cut -c1-12)
          if docker image inspect uadb-proxy:$HASH > /dev/null 2>&1; then
            echo "Proxy inchangé (config $HASH) : pas de reconstruction ni de redémarrage"
            docker tag uadb-proxy:$HASH uadb-proxy:local
          else
            echo "Nouvelle configuration du proxy ($HASH) : construction"
            docker compose build proxy
            docker tag uadb-proxy:local uadb-proxy:$HASH
          fi
          docker compose up -d --no-deps --wait proxy
        '''
      }
    }

    stage('Frontend : mise à jour sans interruption') {
      steps {
        script {
          withEnv(["BACKEND_TAG=${params.BACKEND_TAG}", "FRONTEND_TAG=${params.FRONTEND_TAG}"]) {
            rollingUpdate('frontend', '/frontend:')
          }
        }
      }
    }

    stage('Health check') {
      steps {
        sh '''
          echo "--- API via le proxy (3001) ---"
          docker compose exec -T proxy wget -qO- http://127.0.0.1:3001/health
          echo
          echo "--- Frontend via le proxy (3000) ---"
          docker compose exec -T proxy wget -qO /dev/null http://127.0.0.1:3000/ && echo "Frontend OK"
          echo "--- Conteneurs et versions ---"
          docker compose ps
          docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
        '''
      }
    }
  }

  post {
    failure {
      sh 'docker compose ps || true'
      script { notify('danger', "Déploiement ECHEC : ${env.BUILD_URL}") }
    }
    success {
      script { notify('good', "Déploiement OK : backend ${params.BACKEND_TAG}, frontend ${params.FRONTEND_TAG} (build #${env.BUILD_NUMBER})") }
    }
  }
}