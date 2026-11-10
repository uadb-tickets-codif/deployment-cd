# deployment-cd

Déploiement (Docker Compose + Jenkins) de la plateforme de gestion des tickets de restauration et de la codification (UADB, Master 2 SI-SR).

## Contenu
- `docker-compose.yml` : PostgreSQL 16, backend, frontend, réseau interne `uadb-net`, volumes `postgres_data` et `uploads_data`, healthchecks.
- `.env.example` : modèle des variables (le vrai `.env` n'est jamais versionné).
- `Jenkinsfile` : pipeline de déploiement (à compléter, carte 26).
- `jenkins/` : Dockerfile et compose du Jenkins du projet.

## Prérequis
Docker et Docker Compose v2.

## Configuration
```bash
cp .env.example .env
```
Renseigner dans `.env` :
- `POSTGRES_USER`, `POSTGRES_PASSWORD` (lettres et chiffres uniquement, il est inséré dans une URL), `POSTGRES_DB`
- `JWT_SECRET` : valeur aléatoire d'au moins 32 caractères (`openssl rand -hex 32`)
- `BACKEND_IMAGE=groupe9/backend` et `FRONTEND_IMAGE=groupe9/frontend`
- `BACKEND_TAG` et `FRONTEND_TAG` : `latest` ou un numéro de build précis

## Déploiement
```bash
docker compose pull
docker compose up -d
docker compose ps
```
Accès : frontend http://localhost:3000, API http://localhost:3001, santé http://localhost:3001/health

## Persistance
- `postgres_data` : base de données
- `uploads_data` : fichiers téléversés, montés dans `/app/uploads`

Arrêt en conservant les données : `docker compose down`.
Ne jamais utiliser `docker compose down -v` (supprime les volumes).

## Notes
- `NEXT_PUBLIC_API_URL` est figée au build de l'image frontend : la CI doit la construire avec l'adresse publique du serveur.
- Le `.env` de production est généré par Jenkins à partir de ses credentials.

## Jenkins
```bash
cd jenkins
docker compose up -d --build
```
Accès : http://localhost:8081

## Dépôts liés
- backend-ci
- frontend-ci

## Équipe
Administrateurs systèmes et réseaux
