# Guia corta para estudiantes

## Proposito

Ejecutar un proceso basico de intrusión controlada contra la VM vulnerable asignada en el curso.

## Paso 1: Validar IP de la VM

Desde la máquina anfitriona:

```bash
ping <IP_VM>
```

## Paso 2: Iniciar laboratorio

```bash
chmod +x lab.sh
./lab.sh
```

## Paso 3: Descargar imagenes

En el menu seleccione:

```text
2) Descargar/actualizar imagenes Docker
```

## Paso 4: Definir objetivo

Seleccione:

```text
1) Definir/cambiar objetivo
```

Ingrese la IP o URL de la VM.

## Paso 5: Ejecutar full scan

Seleccione:

```text
8) Ejecutar Full Scan
```

## Paso 6: Revisar resultados

Los reportes quedan en:

```text
resultados/<fecha>_<objetivo>/
```

Revise primero Nmap y luego los reportes web.

## Paso 7: Metasploit

Abra Metasploit desde el menu:

```text
7) Abrir Metasploit
```

Comandos sugeridos:

```text
setg RHOSTS <IP_VM>
setg RPORT 80
resource /workspace/scripts/http_recon.rc
```

## Entregable

Informe corto con:

1. IP objetivo.
2. Puertos abiertos.
3. Servicios detectados.
4. Tres hallazgos relevantes.
5. Evidencia.
6. Recomendaciones.
