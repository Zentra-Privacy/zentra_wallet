#!/usr/bin/env bash
install_docker_engine() {
  local SUDO=""
  if [[ "$(id -u)" -ne 0 ]]; then
    command -v sudo >/dev/null 2>&1 || { echo "Error: sudo required."; return 1; }
    SUDO="sudo"
  fi

  if ! command -v apt-get >/dev/null 2>&1; then
    echo "Error: Debian/Ubuntu (apt-get) required."
    return 1
  fi

  echo "==> Removing old/conflicting Docker packages (if any)"
  $SUDO apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

  echo "==> Installing prerequisites"
  $SUDO apt-get update
  $SUDO apt-get install -y ca-certificates curl gnupg

  echo "==> Adding Docker official GPG key and apt repository"
  $SUDO install -m 0755 -d /etc/apt/keyrings
  if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | $SUDO gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    $SUDO chmod a+r /etc/apt/keyrings/docker.gpg
  fi

  . /etc/os-release
  local ARCH CODENAME
  ARCH="$(dpkg --print-architecture)"
  CODENAME="${VERSION_CODENAME:-$(lsb_release -cs 2>/dev/null || echo noble)}"
  echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${CODENAME} stable" \
    | $SUDO tee /etc/apt/sources.list.d/docker.list >/dev/null

  echo "==> Installing Docker Engine + Compose + Buildx"
  $SUDO apt-get update
  $SUDO apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  $SUDO systemctl enable docker
  $SUDO systemctl start docker

  if [[ "$(id -u)" -ne 0 ]]; then
    $SUDO usermod -aG docker "$(whoami)"
    echo "IMPORTANT: log out/in or run: newgrp docker"
  fi

  $SUDO docker --version
  $SUDO docker compose version
  $SUDO docker run --rm hello-world
  echo "==> Docker installed. Next: ./wallet.sh build-docker"
}
