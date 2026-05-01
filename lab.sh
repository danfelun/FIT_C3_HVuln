#!/usr/bin/env bash
set -u

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$BASE_DIR/resultados"
TARGET=""
TARGET_URL=""
RUN_DIR=""

mkdir -p "$RESULTS_DIR"

banner() {
  clear
  echo "============================================================"
  echo "  FIT Lab - Fundamentos de Intrusion y Testing"
  echo "  Nmap + Nikto + Nuclei + OWASP ZAP + Metasploit"
  echo "============================================================"
  echo
}

pause() {
  echo
  read -rp "Presiona ENTER para continuar..." _
}

check_requirements() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "[!] Docker no esta instalado o no esta en el PATH."
    exit 1
  fi
  if ! docker compose version >/dev/null 2>&1; then
    echo "[!] Docker Compose v2 no esta disponible."
    exit 1
  fi
}

normalize_target() {
  local input="$1"
  TARGET="$input"
  if [[ "$input" =~ ^https?:// ]]; then
    TARGET_URL="$input"
    TARGET="${input#http://}"
    TARGET="${TARGET#https://}"
    TARGET="${TARGET%%/*}"
  else
    TARGET_URL="http://$input"
  fi
}

ask_target() {
  echo "Indica la IP o URL de la VM vulnerable."
  echo "Ejemplo IP: 192.168.56.101"
  echo "Ejemplo URL: http://192.168.56.101"
  echo
  read -rp "Objetivo: " input
  if [[ -z "$input" ]]; then
    echo "[!] Debes indicar un objetivo."
    pause
    return 1
  fi
  normalize_target "$input"
  local stamp
  stamp="$(date +%Y%m%d_%H%M%S)"
  RUN_DIR="$RESULTS_DIR/${stamp}_${TARGET//[^a-zA-Z0-9_.-]/_}"
  mkdir -p "$RUN_DIR"
  echo "$TARGET" > "$RUN_DIR/target.txt"
  echo "$TARGET_URL" > "$RUN_DIR/target_url.txt"
  echo "[+] Objetivo definido: $TARGET"
  echo "[+] URL web base: $TARGET_URL"
  echo "[+] Resultados: $RUN_DIR"
  pause
}

ensure_target() {
  if [[ -z "$TARGET" || -z "$RUN_DIR" ]]; then
    ask_target || return 1
  fi
}

pull_images() {
  banner
  echo "[+] Descargando/actualizando imagenes Docker..."
  cd "$BASE_DIR" || exit 1
  docker compose --profile tools pull
  pause
}

run_nmap() {
  ensure_target || return 1
  banner
  echo "[+] Ejecutando Nmap contra $TARGET"
  local out_rel
  out_rel="$(basename "$RUN_DIR")/01_nmap_servicios.txt"
  cd "$BASE_DIR" || exit 1
  docker compose run --rm nmap -sV -sC -Pn "$TARGET" -oN "/resultados/$out_rel"
  echo "[+] Reporte generado: resultados/$out_rel"
  pause
}

run_nikto() {
  ensure_target || return 1
  banner
  echo "[+] Ejecutando Nikto contra $TARGET_URL"
  local out_rel
  out_rel="$(basename "$RUN_DIR")/02_nikto.txt"
  cd "$BASE_DIR" || exit 1
  docker compose run --rm nikto -h "$TARGET_URL" -output "/resultados/$out_rel" || true
  echo "[+] Reporte generado: resultados/$out_rel"
  pause
}

run_nuclei() {
  ensure_target || return 1
  banner
  echo "[+] Ejecutando Nuclei contra $TARGET_URL"
  local out_rel
  out_rel="$(basename "$RUN_DIR")/03_nuclei.txt"
  cd "$BASE_DIR" || exit 1
  docker compose run --rm nuclei -u "$TARGET_URL" -o "/resultados/$out_rel" || true
  echo "[+] Reporte generado: resultados/$out_rel"
  pause
}

run_zap() {
  ensure_target || return 1
  banner
  echo "[+] Ejecutando OWASP ZAP Baseline contra $TARGET_URL"
  echo "[i] ZAP puede retornar codigo 1 o 2 cuando encuentra alertas; no necesariamente es fallo."
  local run_base html json
  run_base="$(basename "$RUN_DIR")"
  html="${run_base}/04_zap_baseline.html"
  json="${run_base}/04_zap_baseline.json"
  cd "$BASE_DIR" || exit 1
  docker compose run --rm zap zap-baseline.py -t "$TARGET_URL" -r "resultados/$html" -J "resultados/$json" || true
  echo "[+] Reportes generados:"
  echo "    resultados/$html"
  echo "    resultados/$json"
  pause
}

open_metasploit() {
  ensure_target || return 1
  banner
  echo "[+] Abriendo Metasploit Framework"
  echo
  echo "Sugerencia dentro de msfconsole:"
  echo "  setg RHOSTS $TARGET"
  echo "  setg RPORT 80"
  echo "  resource /workspace/scripts/http_recon.rc"
  echo
  echo "Para SMB, si el objetivo expone 445:"
  echo "  setg RHOSTS $TARGET"
  echo "  resource /workspace/scripts/smb_recon.rc"
  echo
  cd "$BASE_DIR" || exit 1
  docker compose run --rm metasploit msfconsole
}

full_scan() {
  ensure_target || return 1
  banner
  echo "[+] Ejecutando flujo completo contra $TARGET"
  echo "[+] Resultados: $RUN_DIR"
  cd "$BASE_DIR" || exit 1

  local run_base
  run_base="$(basename "$RUN_DIR")"

  echo "[1/4] Nmap"
  docker compose run --rm nmap -sV -sC -Pn "$TARGET" -oN "/resultados/$run_base/01_nmap_servicios.txt" || true

  echo "[2/4] Nikto"
  docker compose run --rm nikto -h "$TARGET_URL" -output "/resultados/$run_base/02_nikto.txt" || true

  echo "[3/4] Nuclei"
  docker compose run --rm nuclei -u "$TARGET_URL" -o "/resultados/$run_base/03_nuclei.txt" || true

  echo "[4/4] OWASP ZAP Baseline"
  docker compose run --rm zap zap-baseline.py -t "$TARGET_URL" -r "resultados/$run_base/04_zap_baseline.html" -J "resultados/$run_base/04_zap_baseline.json" || true

  generate_summary
  echo "[+] Flujo completo finalizado."
  pause
}

generate_summary() {
  ensure_target || return 1
  local summary
  summary="$RUN_DIR/00_resumen.md"
  cat > "$summary" <<EOF
# Resumen de ejecucion

- Objetivo: $TARGET
- URL base: $TARGET_URL
- Fecha: $(date)

## Archivos generados

- 01_nmap_servicios.txt
- 02_nikto.txt
- 03_nuclei.txt
- 04_zap_baseline.html
- 04_zap_baseline.json

## Guia de analisis

1. Revise en Nmap los puertos abiertos y versiones detectadas.
2. Compare los hallazgos web de Nikto, Nuclei y ZAP.
3. Identifique vulnerabilidades repetidas entre herramientas.
4. Use Metasploit solo para validar en el entorno autorizado de laboratorio.
5. Documente evidencia, impacto y recomendacion.
EOF
  echo "[+] Resumen generado: $summary"
}

show_results() {
  banner
  echo "Resultados disponibles:"
  echo
  find "$RESULTS_DIR" -maxdepth 2 -type f | sort | sed "s|$BASE_DIR/||"
  pause
}

menu() {
  while true; do
    banner
    echo "Objetivo actual: ${TARGET:-no definido}"
    echo "URL web: ${TARGET_URL:-no definida}"
    echo
    echo "1) Definir/cambiar objetivo"
    echo "2) Descargar/actualizar imagenes Docker"
    echo "3) Ejecutar Nmap"
    echo "4) Ejecutar Nikto"
    echo "5) Ejecutar Nuclei"
    echo "6) Ejecutar OWASP ZAP Baseline"
    echo "7) Abrir Metasploit"
    echo "8) Ejecutar Full Scan"
    echo "9) Ver archivos generados"
    echo "0) Salir"
    echo
    read -rp "Seleccione una opcion: " opt
    case "$opt" in
      1) ask_target ;;
      2) pull_images ;;
      3) run_nmap ;;
      4) run_nikto ;;
      5) run_nuclei ;;
      6) run_zap ;;
      7) open_metasploit ;;
      8) full_scan ;;
      9) show_results ;;
      0) exit 0 ;;
      *) echo "Opcion invalida"; pause ;;
    esac
  done
}

check_requirements
if [[ $# -gt 0 ]]; then
  normalize_target "$1"
  stamp="$(date +%Y%m%d_%H%M%S)"
  RUN_DIR="$RESULTS_DIR/${stamp}_${TARGET//[^a-zA-Z0-9_.-]/_}"
  mkdir -p "$RUN_DIR"
fi
menu
