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
        sh '''
          export BACKEND_TAG=${BACKEND_TAG} FRONTEND_TAG=${FRONTEND_TAG}

          BACKEND_IMG=$(docker compose config --images | grep -E '/backend:' | head -1)
          TARGET_ID=$(docker image inspect -f '{{.Id}}' "$BACKEND_IMG")
          OLD_IDS=$(docker compose ps -q backend | tr '\\n' ' ')

          if [ -z "$OLD_IDS" ]; then
            echo "Premier déploiement du backend"
            docker compose up -d --no-deps --wait backend
          else
            FIRST_OLD=$(echo $OLD_IDS | cut -d' ' -f1)
            RUNNING_ID=$(docker inspect -f '{{.Image}}' "$FIRST_OLD")
            if [ "$RUNNING_ID" = "$TARGET_ID" ]; then
              echo "Backend déjà à jour ($BACKEND_IMG)"
            else
              echo "Mise à jour : $BACKEND_IMG, démarrage d'une seconde réplique"
              docker compose up -d --no-deps --no-recreate --scale backend=2 backend

              NEW_ID=""
              for id in $(docker compose ps -q backend); do
                case " $OLD_IDS " in
                  *" $id "*) ;;
                  *) NEW_ID=$id ;;
                esac
              done
              echo "Nouvelle réplique : $NEW_ID"

              HEALTHY=no
              for i in $(seq 1 40); do
                S=$(docker inspect -f '{{.State.Health.Status}}' "$NEW_ID" 2>/dev/null || echo none)
                echo "Nouvelle réplique : $S ($i/40)"
                if [ "$S" = "healthy" ]; then HEALTHY=yes; break; fi
                sleep 3
              done

              if [ "$HEALTHY" != "yes" ]; then
                echo "ECHEC : la nouvelle version n'est pas saine, l'ancienne reste en service"
                docker logs --tail=40 "$NEW_ID" || true
                docker rm -f "$NEW_ID"
                exit 1
              fi

              echo "Les deux répliques sont actives, le proxy les découvre"
              sleep 5
              echo "Retrait de l'ancienne réplique : $OLD_IDS"
              docker stop -t 20 $OLD_IDS
              docker rm $OLD_IDS
            fi
          fi
          docker compose ps backend
        '''
      }
    }

    stage('Proxy') {
      steps {
        sh '''
          export BACKEND_TAG=${BACKEND_TAG} FRONTEND_TAG=${FRONTEND_TAG}
          NEED_BUILD=no
          if ! docker image inspect uadb-proxy:local > /dev/null 2>&1; then NEED_BUILD=yes; fi
          if [ -n "$(git diff --name-only HEAD~1 HEAD -- nginx 2>/dev/null)" ]; then NEED_BUILD=yes; fi
          if [ "$NEED_BUILD" = "yes" ]; then
            echo "Construction de l'image du proxy"
            docker compose build proxy
          else
            echo "Proxy inchangé : pas de reconstruction ni de redémarrage"
          fi
          docker compose up -d --no-deps --wait proxy
        '''
      }
    }

    stage('Frontend') {
      steps {
        sh '''
          export BACKEND_TAG=${BACKEND_TAG} FRONTEND_TAG=${FRONTEND_TAG}
          docker compose up -d --no-deps --wait frontend
        '''
      }
    }

    stage('Health check') {
      steps {
        sh '''
          echo "--- /health via le proxy ---"
          docker compose exec -T proxy wget -qO- http://127.0.0.1:3001/health
          echo
          echo "--- Frontend ---"
          docker compose exec -T frontend wget -qO /dev/null http://127.0.0.1:3000/ && echo "Frontend OK"
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
      script { notify('good', "Déploiement OK : backend ${params.BACKEND_TAG}, frontend ${params.FRONTEND_TAG}") }
    }
  }
}