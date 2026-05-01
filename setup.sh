#!/usr/bin/env bash
set -e

echo "============================================================"
echo "  FIT Lab - Despliegue automatizado"
echo "============================================================"

if ! command -v docker >/dev/null 2>&1; then
  echo "[!] Docker no está instalado."
  exit 1
fi

if docker ps >/dev/null 2>&1; then
  DOCKER_CMD="docker"
else
  DOCKER_CMD="sudo docker"
fi

echo "[+] Creando carpetas necesarias..."
mkdir -p resultados
mkdir -p scripts/metasploit
chmod -R 777 resultados

echo "[+] Validando Dockerfile de Metasploit..."
if [ ! -f Dockerfile.metasploit ]; then
  echo "[!] No existe Dockerfile.metasploit"
  exit 1
fi

echo "[+] Construyendo imagen local de Metasploit..."
$DOCKER_CMD compose build metasploit

echo "[+] Descargando y levantando contenedores..."
$DOCKER_CMD compose up -d --build

echo "[+] Verificando estado..."
$DOCKER_CMD compose ps

echo
echo "[OK] Laboratorio desplegado correctamente."
echo
echo "Ejecuta ahora:"
echo "  ./lab.sh"