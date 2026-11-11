#!/usr/bin/env bash
set -euo pipefail

old=$(docker compose ps -q backend)
docker compose pull backend || echo "pull ignoré (tag local)"
# démarre un 2e réplica avec le nouveau tag, sans toucher à l'ancien
docker compose up -d --no-deps --scale backend=2 --no-recreate backend

# attend que le nouveau réplica soit healthy
for i in $(seq 1 30); do
  new=$(docker compose ps -q backend | grep -v "$old" || true)
  if [ -n "$new" ] && [ "$(docker inspect -f '{{.State.Health.Status}}' "$new")" = "healthy" ]; then break; fi
  sleep 2
done
[ "$(docker inspect -f '{{.State.Health.Status}}' "$new")" = "healthy" ] || { echo "Le nouveau backend n'est pas healthy"; exit 1; }

# retire l'ancien réplica
docker stop "$old" && docker rm "$old"
docker compose up -d --no-deps --scale backend=1 --no-recreate backend
docker compose ps
