#!/usr/bin/env bash
set -u

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$BASE_DIR/resultados"
TARGET=""
TARGET_URL=""
RUN_DIR=""

if docker ps >/dev/null 2>&1; then
  DOCKER_CMD="docker"
elif sudo docker ps >/dev/null 2>&1; then
  DOCKER_CMD="sudo docker"
else
  DOCKER_CMD="docker"
fi

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

  if ! $DOCKER_CMD compose version >/dev/null 2>&1; then
    echo "[!] Docker Compose v2 no esta disponible."
    exit 1
  fi

  if ! $DOCKER_CMD ps >/dev/null 2>&1; then
    echo "[!] No fue posible conectar con el servicio Docker."
    echo "    Intenta: sudo systemctl start docker"
    exit 1
  fi
}

fix_permissions() {
  mkdir -p "$RESULTS_DIR"
  chmod -R 777 "$RESULTS_DIR" 2>/dev/null || true
}

normalize_target() {
  local input="$1"
  input="$(echo "$input" | xargs)"
  TARGET="$input"

  if [[ "$input" =~ ^https?:// ]]; then
    TARGET_URL="$input"
    TARGET="${input#http://}"
    TARGET="${TARGET#https://}"
    TARGET="${TARGET%%/*}"
    TARGET="${TARGET%%:*}"
  else
    TARGET_URL="http://$input"
  fi
}

create_run_dir() {
  local stamp
  stamp="$(date +%Y%m%d_%H%M%S)"
  RUN_DIR="$RESULTS_DIR/${stamp}_${TARGET//[^a-zA-Z0-9_.-]/_}"
  mkdir -p "$RUN_DIR"
  chmod -R 777 "$RUN_DIR" 2>/dev/null || true
  echo "$TARGET" > "$RUN_DIR/target.txt"
  echo "$TARGET_URL" > "$RUN_DIR/target_url.txt"
}

ask_target() {
  echo "Indica la IP o URL de la VM vulnerable."
  echo "Ejemplo IP: 192.168.56.101"
  echo "Ejemplo URL: http://192.168.56.101:8080"
  echo
  read -rp "Objetivo: " input

  if [[ -z "$input" ]]; then
    echo "[!] Debes indicar un objetivo."
    pause
    return 1
  fi

  normalize_target "$input"
  create_run_dir
  fix_permissions

  echo "[+] Objetivo definido: $TARGET"
  echo "[+] URL web base: $TARGET_URL"
  echo "[+] Resultados: $RUN_DIR"
  pause
}

ensure_target() {
  if [[ -z "$TARGET" || -z "$RUN_DIR" ]]; then
    ask_target || return 1
  fi

  mkdir -p "$RUN_DIR"
  fix_permissions
}

compose_run() {
  cd "$BASE_DIR" || exit 1
  $DOCKER_CMD compose run --rm "$@"
}

compose_pull() {
  cd "$BASE_DIR" || exit 1
  echo "[+] Actualizando imagenes publicas..."
  echo "[i] Metasploit usa imagen local (fit-metasploit:local), por eso no se descarga con pull."
  echo "[i] Para reconstruir Metasploit, ejecuta: ./setup.sh"
  echo
  $DOCKER_CMD compose pull nmap nikto nuclei zap
}

pull_images() {
  banner
  echo "[+] Descargando/actualizando imagenes Docker..."
  compose_pull
  pause
}

nmap_report_path() {
  echo "$RUN_DIR/01_nmap_servicios.txt"
}

detect_web_urls_from_nmap() {
  local nmap_file
  nmap_file="$(nmap_report_path)"

  if [[ ! -f "$nmap_file" ]]; then
    echo ""
    return 0
  fi

  awk '
    /^[0-9]+\/tcp[[:space:]]+open/ && tolower($0) ~ /http|ssl\/http|http-proxy|http-alt/ {
      split($1,a,"/")
      port=a[1]
      line=tolower($0)
      if (line ~ /ssl\/http|https|443\/tcp/) {
        print "https://" target ":" port
      } else {
        print "http://" target ":" port
      }
    }
  ' target="$TARGET" "$nmap_file" | sort -u
}

select_web_url() {
  local detected urls_count selected
  detected="$(detect_web_urls_from_nmap)"
  urls_count="$(echo "$detected" | sed '/^$/d' | wc -l)"

  if [[ -z "$detected" || "$urls_count" -eq 0 ]]; then
    echo "[!] No se detectaron servicios HTTP/HTTPS en el reporte de Nmap."
    echo "[i] Se usara la URL definida manualmente: $TARGET_URL"
    return 0
  fi

  echo "[+] Servicios web detectados desde Nmap:"
  echo "$detected" | nl -w2 -s") "
  echo

  if [[ "$urls_count" -eq 1 ]]; then
    TARGET_URL="$(echo "$detected" | head -n1)"
    echo "[+] Se usara automaticamente: $TARGET_URL"
    return 0
  fi

  echo "Seleccione la URL que desea analizar."
  echo "Presione ENTER para usar la primera opcion."
  read -rp "Opcion: " selected

  if [[ -z "$selected" ]]; then
    selected=1
  fi

  TARGET_URL="$(echo "$detected" | sed -n "${selected}p")"

  if [[ -z "$TARGET_URL" ]]; then
    TARGET_URL="$(echo "$detected" | head -n1)"
  fi

  echo "[+] Se usara: $TARGET_URL"
}

run_nmap() {
  ensure_target || return 1
  banner
  echo "[+] Ejecutando Nmap contra $TARGET"
  echo "[i] Modo: todos los puertos TCP (-p-), versiones (-sV), scripts basicos (-sC), sin ping previo (-Pn)."

  local run_base
  run_base="$(basename "$RUN_DIR")"

  compose_run nmap \
    -p- -sV -sC -Pn --open "$TARGET" \
    -oN "/resultados/$run_base/01_nmap_servicios.txt" || true

  echo "[+] Reporte generado: resultados/$run_base/01_nmap_servicios.txt"
  pause
}

run_nmap_vuln() {
  ensure_target || return 1
  banner
  echo "[+] Ejecutando Nmap --script vuln contra $TARGET"

  local run_base
  run_base="$(basename "$RUN_DIR")"

  compose_run nmap \
    -p- --script vuln -Pn "$TARGET" \
    -oN "/resultados/$run_base/02_nmap_vuln.txt" || true

  echo "[+] Reporte generado: resultados/$run_base/02_nmap_vuln.txt"
  pause
}

run_nikto() {
  ensure_target || return 1
  banner
  select_web_url
  echo
  echo "[+] Ejecutando Nikto contra $TARGET_URL"

  local run_base
  run_base="$(basename "$RUN_DIR")"

  compose_run nikto \
    -h "$TARGET_URL" \
    -output "/resultados/$run_base/03_nikto.txt" || true

  if [[ -f "$RUN_DIR/03_nikto.txt" ]]; then
    echo "[+] Reporte generado: resultados/$run_base/03_nikto.txt"
  else
    echo "[!] Nikto finalizo, pero no se encontro el reporte esperado."
    echo "    Verifica imagen: ghcr.io/sullo/nikto:latest"
    echo "    Verifica volumen: ./resultados:/resultados"
  fi

  pause
}

run_nuclei() {
  ensure_target || return 1
  banner
  select_web_url
  echo
  echo "[+] Ejecutando Nuclei contra $TARGET_URL"

  local run_base
  run_base="$(basename "$RUN_DIR")"

  compose_run nuclei \
    -u "$TARGET_URL" \
    -o "/resultados/$run_base/04_nuclei.txt" || true

  echo "[+] Reporte generado: resultados/$run_base/04_nuclei.txt"
  pause
}

run_zap() {
  ensure_target || return 1
  banner
  select_web_url
  echo
  echo "[+] Ejecutando OWASP ZAP Baseline contra $TARGET_URL"
  echo "[i] ZAP puede retornar codigo 1 o 2 cuando encuentra alertas; no necesariamente es fallo."

  local run_base
  run_base="$(basename "$RUN_DIR")"

  compose_run zap \
    zap-baseline.py \
    -t "$TARGET_URL" \
    -r "resultados/$run_base/05_zap_baseline.html" \
    -J "resultados/$run_base/05_zap_baseline.json" || true

  echo "[+] Reportes generados:"
  echo "    resultados/$run_base/05_zap_baseline.html"
  echo "    resultados/$run_base/05_zap_baseline.json"
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
  $DOCKER_CMD exec -it fit-metasploit msfconsole
}

full_scan() {
  ensure_target || return 1
  banner
  echo "[+] Ejecutando flujo completo contra $TARGET"
  echo "[+] Resultados: $RUN_DIR"
  echo

  local run_base
  run_base="$(basename "$RUN_DIR")"

  echo "[1/5] Nmap - Descubrimiento de servicios"
  compose_run nmap \
    -p- -sV -sC -Pn --open "$TARGET" \
    -oN "/resultados/$run_base/01_nmap_servicios.txt" || true

  echo
  echo "[2/5] Nmap - Scripts de vulnerabilidad"
  compose_run nmap \
    -p- --script vuln -Pn "$TARGET" \
    -oN "/resultados/$run_base/02_nmap_vuln.txt" || true

  echo
  select_web_url
  echo

  echo "[3/5] Nikto"
  compose_run nikto \
    -h "$TARGET_URL" \
    -output "/resultados/$run_base/03_nikto.txt" || true

  echo
  echo "[4/5] Nuclei"
  compose_run nuclei \
    -u "$TARGET_URL" \
    -o "/resultados/$run_base/04_nuclei.txt" || true

  echo
  echo "[5/5] OWASP ZAP Baseline"
  compose_run zap \
    zap-baseline.py \
    -t "$TARGET_URL" \
    -r "resultados/$run_base/05_zap_baseline.html" \
    -J "resultados/$run_base/05_zap_baseline.json" || true

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
- URL base usada: $TARGET_URL
- Fecha: $(date)

## Archivos esperados

- 01_nmap_servicios.txt
- 02_nmap_vuln.txt
- 03_nikto.txt
- 04_nuclei.txt
- 05_zap_baseline.html
- 05_zap_baseline.json

## Interpretacion

- 01_nmap_servicios.txt muestra puertos abiertos, servicios y versiones.
- 02_nmap_vuln.txt contiene hallazgos sugeridos por NSE (--script vuln).
- Los hallazgos deben validarse manualmente antes de considerarse vulnerabilidades reales.

## Guia de analisis

1. Revise en Nmap los puertos abiertos y versiones detectadas.
2. Identifique los puertos HTTP/HTTPS detectados por Nmap.
3. Compare los hallazgos web de Nikto, Nuclei y ZAP.
4. Identifique vulnerabilidades repetidas entre herramientas.
5. Use Metasploit solo para validar en el entorno autorizado de laboratorio.
6. Documente evidencia, impacto y recomendacion.
EOF

  chmod 666 "$summary" 2>/dev/null || true
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
    echo "2) Descargar/actualizar imagenes publicas"
    echo "3) Ejecutar Nmap"
    echo "4) Ejecutar Nmap --script vuln"
    echo "5) Ejecutar Nikto"
    echo "6) Ejecutar Nuclei"
    echo "7) Ejecutar OWASP ZAP Baseline"
    echo "8) Abrir Metasploit"
    echo "9) Ejecutar Full Scan"
    echo "10) Ver archivos generados"
    echo "0) Salir"
    echo
    read -rp "Seleccione una opcion: " opt

    case "$opt" in
      1) ask_target ;;
      2) pull_images ;;
      3) run_nmap ;;
      4) run_nmap_vuln ;;
      5) run_nikto ;;
      6) run_nuclei ;;
      7) run_zap ;;
      8) open_metasploit ;;
      9) full_scan ;;
      10) show_results ;;
      0) exit 0 ;;
      *) echo "Opcion invalida"; pause ;;
    esac
  done
}

check_requirements

if [[ $# -gt 0 ]]; then
  normalize_target "$1"
  create_run_dir
  fix_permissions
fi

menu
