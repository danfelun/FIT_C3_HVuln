#!/usr/bin/env bash
set -Eeuo pipefail
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$BASE_DIR"
echo "============================================================"
echo " FIT Lab - Preparacion reproducible"
echo "============================================================"
command -v docker >/dev/null || { echo "[ERROR] Instale Docker Engine"; exit 1; }
if docker info >/dev/null 2>&1; then
  DC=(docker)
elif command -v sudo >/dev/null && sudo docker info >/dev/null 2>&1; then
  DC=(sudo docker)
else
  echo "[ERROR] No hay conexion con Docker Engine"; exit 1
fi
"${DC[@]}" compose version >/dev/null || { echo "[ERROR] Se requiere Docker Compose v2"; exit 1; }
if [[ ! -f .env ]]; then
  cp .env.example .env
  chmod 600 .env
  echo "[INFO] Se creo .env desde .env.example. Revise FIT_TARGET y FIT_TARGET_URL."
else
  echo "[INFO] Se conserva el .env existente."
fi
mkdir -p resultados scripts/metasploit
[[ -f Dockerfile.metasploit ]] || { echo "[ERROR] Falta Dockerfile.metasploit"; exit 1; }
"${DC[@]}" compose config --quiet || { echo "[ERROR] Configuracion Compose invalida"; exit 1; }
echo "[1/4] Descargando imagenes publicas"
"${DC[@]}" compose pull nmap nikto nuclei zap
echo "[2/4] Construyendo Metasploit local"
"${DC[@]}" compose build metasploit
echo "[3/4] Iniciando solo el servicio persistente Metasploit"
"${DC[@]}" compose up -d --no-build metasploit
echo "[4/4] Validando msfconsole"
"${DC[@]}" compose exec -T metasploit sh -lc 'command -v msfconsole >/dev/null' || {
  echo "[ERROR] msfconsole no disponible; revise Dockerfile.metasploit"; exit 1;
}
"${DC[@]}" compose ps metasploit
printf '\n[OK] Preparacion finalizada. Ejecute ./lab.sh\n'
