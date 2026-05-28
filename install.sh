#!/usr/bin/env bash
# Instalador para Teamweaver (editor de landings).
# Uso (una sola línea en WSL Ubuntu):
#   curl -fsSL https://raw.githubusercontent.com/josepita/teamviewer/main/install.sh | bash
#
# Qué hace:
#  1. Comprueba que estamos en Linux/WSL con apt.
#  2. Instala git y Node.js LTS si faltan.
#  3. Clona el repo en ~/landings (o hace pull si ya existe).
#  4. npm install.
#  5. Arranca el servidor y abre el navegador en http://localhost:3333.

set -euo pipefail

REPO_URL="https://github.com/josepita/teamviewer.git"
TARGET_DIR="$HOME/landings"
PORT="${PORT:-3333}"

say() { printf "\n\033[1;36m▸ %s\033[0m\n" "$*"; }
ok()  { printf "\033[1;32m✓ %s\033[0m\n" "$*"; }
err() { printf "\033[1;31m✗ %s\033[0m\n" "$*" >&2; }

# 1. Comprobaciones básicas
if ! command -v apt-get >/dev/null 2>&1; then
  err "Este instalador asume WSL con Ubuntu/Debian (apt). Avisa a Jose."
  exit 1
fi

say "Comprobando herramientas (puede pedir tu contraseña de WSL)…"
NEED_INSTALL=()
command -v git  >/dev/null 2>&1 || NEED_INSTALL+=(git)
command -v curl >/dev/null 2>&1 || NEED_INSTALL+=(curl)

if [ ${#NEED_INSTALL[@]} -gt 0 ]; then
  sudo apt-get update -qq
  sudo apt-get install -y "${NEED_INSTALL[@]}"
fi
ok "git y curl listos."

# 2. Node.js (LTS) si no está, o si la versión es demasiado vieja
need_node=true
if command -v node >/dev/null 2>&1; then
  NODE_MAJOR=$(node -p "process.versions.node.split('.')[0]")
  if [ "$NODE_MAJOR" -ge 18 ]; then
    need_node=false
  fi
fi

if $need_node; then
  say "Instalando Node.js LTS (puede tardar 1-2 min)…"
  curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi
ok "Node $(node -v) listo."

# 3. Clonar o actualizar
if [ -d "$TARGET_DIR/.git" ]; then
  say "Ya existe $TARGET_DIR — actualizando…"
  git -C "$TARGET_DIR" pull --ff-only
else
  say "Clonando en $TARGET_DIR…"
  git clone "$REPO_URL" "$TARGET_DIR"
fi
ok "Código en $TARGET_DIR."

# 4. Dependencias
cd "$TARGET_DIR"
say "Instalando dependencias npm…"
npm install --silent
ok "Dependencias listas."

# 5. Arrancar y abrir el navegador
say "Arrancando el editor en http://localhost:$PORT"
echo "    (Para parar: Ctrl+C. Para volver a arrancar: cd ~/landings && ./start-editor.sh)"
echo

# Abrir el navegador de Windows tras un breve delay (en segundo plano)
(
  sleep 2
  if command -v wslview >/dev/null 2>&1; then
    wslview "http://localhost:$PORT" >/dev/null 2>&1 || true
  elif command -v cmd.exe >/dev/null 2>&1; then
    cmd.exe /c start "http://localhost:$PORT" >/dev/null 2>&1 || true
  fi
) &

exec node server.js
