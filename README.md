# deployment-cd

Déploiement (Docker Compose + Jenkins) de la plateforme de gestion des tickets de restauration et de la codification (UADB, Master 2 SI-SR).

## Contenu
- docker-compose.yml : backend, frontend, PostgreSQL et volumes (à venir)
- .env : variables de démonstration (à venir)
- Jenkinsfile : pipeline de déploiement

## Déploiement
(à compléter)

## Dépôts liés
- backend-ci
- frontend-ci

## Équipe
Administrateurs systèmes et réseaux

## Jenkins
cd jenkins
docker compose up -d --build
Accès : http://localhost:8081
