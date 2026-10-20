#!/bin/bash
# Startup script de la VM vm-backoffice-01: instala Docker Engine
# y deja el contenedor del backoffice listo para levantarse.
set -e

apt-get update
apt-get install -y ca-certificates curl gnupg

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

systemctl enable docker
systemctl start docker

# La imagen del backoffice se publica en Artifact Registry desde CI/CD;
# aquí solo se deja Docker listo. El despliegue del contenedor se hace con:
#   docker run -d --restart unless-stopped --env-file .env -p 8080:8080 <REGION>-docker.pkg.dev/<PROYECTO>/backoffice/backoffice:latest
