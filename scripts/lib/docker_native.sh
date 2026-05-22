#!/usr/bin/env bash
# Docker native build (Ubuntu 22.04) + cleanup helpers.

# Sets DOCKER=(docker) or DOCKER=(sudo docker). Returns 1 if unavailable.
_docker_cmd() {
  DOCKER=(docker)
  if ! command -v docker >/dev/null 2>&1; then
    echo "Error: docker not in PATH. Run: ./wallet.sh install-docker"
    return 1
  fi
  if ! docker info >/dev/null 2>&1; then
    if sudo docker info >/dev/null 2>&1; then
      DOCKER=(sudo docker)
      echo "Note: using sudo for docker. Prefer: newgrp docker"
    else
      echo "Error: Docker daemon not reachable."
      return 1
    fi
  fi
  return 0
}

# Remove wallet Docker containers; optional image + build/docker cache.
# Usage: docker_cleanup_wallet [--image] [--cache] [--yes]
docker_cleanup_wallet() {
  local ROOT="${WALLET_ROOT:?}"
  local IMAGE="${NATIVE_IMAGE:-zentra-wallet-native-build:ubuntu22}"
  local REMOVE_IMAGE=0 REMOVE_CACHE=0 ASSUME_YES=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --image) REMOVE_IMAGE=1; shift ;;
      --cache) REMOVE_CACHE=1; shift ;;
      --yes|-y) ASSUME_YES=1; shift ;;
      *) echo "Unknown option: $1"; return 1 ;;
    esac
  done

  _docker_cmd || return 1

  echo "==> Zentra Wallet Docker cleanup"
  echo "    Image: $IMAGE"
  echo ""

  local image_id=""
  image_id="$("${DOCKER[@]}" images -q "$IMAGE" 2>/dev/null | head -1 || true)"

  echo "==> Containers (running or stopped) from this image:"
  local -a container_ids=()
  if [[ -n "$image_id" ]]; then
    while IFS= read -r line; do
      [[ -n "$line" ]] && container_ids+=("$line")
    done < <("${DOCKER[@]}" ps -aq --filter "ancestor=$image_id" 2>/dev/null || true)
  fi

  if [[ ${#container_ids[@]} -eq 0 ]]; then
    echo "    (none — build uses --rm, so containers usually auto-delete)"
  else
    "${DOCKER[@]}" ps -a --format 'table {{.ID}}\t{{.Status}}\t{{.Image}}\t{{.Names}}' \
      --filter "ancestor=$image_id" 2>/dev/null || true
  fi

  echo ""
  echo "Will remove:"
  echo "  • ${#container_ids[@]} container(s) linked to $IMAGE"
  [[ "$REMOVE_IMAGE" -eq 1 ]] && echo "  • Docker image: $IMAGE"
  [[ "$REMOVE_CACHE" -eq 1 ]] && echo "  • Folder: $ROOT/build/docker/"
  echo "  • Stopped containers system-wide: docker container prune -f"
  echo ""

  if [[ "$ASSUME_YES" -ne 1 ]]; then
    read -r -p "Type yes to continue: " ans
    [[ "$ans" == "yes" ]] || { echo "Cancelled."; return 0; }
  fi

  if [[ ${#container_ids[@]} -gt 0 ]]; then
    echo "==> Removing containers…"
    "${DOCKER[@]}" rm -f "${container_ids[@]}"
  fi

  echo "==> Pruning stopped containers…"
  "${DOCKER[@]}" container prune -f

  if [[ "$REMOVE_IMAGE" -eq 1 ]]; then
    echo "==> Removing image $IMAGE…"
    "${DOCKER[@]}" rmi -f "$IMAGE" 2>/dev/null || echo "    (image not present or in use)"
  fi

  if [[ "$REMOVE_CACHE" -eq 1 ]]; then
    echo "==> Removing build/docker/…"
    rm -rf "$ROOT/build/docker"
  fi

  echo "==> Done."
  "${DOCKER[@]}" images "$IMAGE" 2>/dev/null || true
}

docker_native_build() {
  local ROOT="${WALLET_ROOT:?}"
  local DOCKER_DIR="$ROOT/docker/ubuntu22-native"
  local IMAGE="${NATIVE_IMAGE:-zentra-wallet-native-build:ubuntu22}"
  local ZENTRA_GIT_URL="${ZENTRA_GIT_URL:-https://github.com/Foisalislambd/zentra.git}"
  local THIRD_PARTY="$ROOT/third_party/zentra"

  _docker_cmd || return 1

  local RUN_UID RUN_GID
  if [[ -n "${SUDO_UID:-}" ]]; then
    RUN_UID="$SUDO_UID"
    RUN_GID="$SUDO_GID"
  else
    RUN_UID="$(id -u)"
    RUN_GID="$(id -g)"
  fi

  _resolve() {
    if [[ -n "${1:-}" && -d "$1" ]]; then
      echo "$(cd "$1" && pwd)"
      return
    fi
    if [[ -n "${ZENTRA_ROOT:-}" && -d "$ZENTRA_ROOT" ]]; then
      echo "$(cd "$ZENTRA_ROOT" && pwd)"
      return
    fi
    if [[ -d "$ROOT/../zentra/src/wallet/api" ]]; then
      echo "$(cd "$ROOT/../zentra" && pwd)"
      return
    fi
    if [[ -d "$THIRD_PARTY/src/wallet/api" ]]; then
      echo "$(cd "$THIRD_PARTY" && pwd)"
      return
    fi
    echo ""
  }

  local ZENTRA_HOST
  ZENTRA_HOST="$(_resolve "${1:-}")"

  if [[ -z "$ZENTRA_HOST" ]]; then
    echo "==> Cloning Zentra into $THIRD_PARTY"
    mkdir -p "$(dirname "$THIRD_PARTY")"
    if [[ -d "$THIRD_PARTY/.git" ]]; then
      git -C "$THIRD_PARTY" fetch --depth 1 origin
      git -C "$THIRD_PARTY" checkout -f
    else
      git clone --depth 1 "$ZENTRA_GIT_URL" "$THIRD_PARTY"
    fi
    ZENTRA_HOST="$(cd "$THIRD_PARTY" && pwd)"
  fi

  echo "==> Zentra source (host): $ZENTRA_HOST"
  echo "==> Wallet repo (host):   $ROOT"
  echo "==> Docker image:         $IMAGE"

  if [[ "${REBUILD_IMAGE:-0}" == "1" ]] || ! "${DOCKER[@]}" image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "==> Building Docker image (Ubuntu 22.04)..."
    "${DOCKER[@]}" build -t "$IMAGE" "$DOCKER_DIR"
  fi

  echo "==> Running native build in container (uid=$RUN_UID)..."
  "${DOCKER[@]}" run --rm \
    --user "${RUN_UID}:${RUN_GID}" \
    -e HOME=/tmp \
    -e JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}" \
    -e ZENTRA_ROOT=/zentra \
    -e WALLET_ROOT=/wallet \
    -v "$ROOT:/wallet" \
    -v "$ZENTRA_HOST:/zentra" \
    -w /wallet \
    "$IMAGE" \
    bash /wallet/docker/ubuntu22-native/build.sh

  echo
  echo "==> Done. Native library:"
  ls -la "$ROOT/packages/zentra_wallet_core/linux/libzentra_wallet_ffi.so"
}
