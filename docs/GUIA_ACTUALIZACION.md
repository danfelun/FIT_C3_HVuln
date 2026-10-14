# FIT Lab - Actualizacion para despliegue reproducible

## Archivos

Sustituya `lab.sh`, `setup.sh` y `docker-compose.yml` por estas versiones. Incorpore `.env.example` y agregue las reglas de `.gitignore.fragment` al `.gitignore` existente. Conserve el `Dockerfile.metasploit` y los scripts de reconocimiento originales.

## Instalacion

```bash
git clone https://github.com/danfelun/FIT_C3_HVuln.git
cd FIT_C3_HVuln
cp .env.example .env
nano .env
chmod +x setup.sh lab.sh
./setup.sh
./lab.sh
```

`setup.sh` tambien crea `.env` si falta. La edicion previa permite adaptar el objetivo vulnerable antes de iniciar. Solo use direcciones de laboratorio bajo autorizacion.

## Verificacion

```bash
docker compose config --quiet
docker compose ps metasploit
docker compose exec metasploit msfconsole
```

Nmap, Nikto, Nuclei y ZAP se ejecutan como contenedores efimeros (`compose run --rm`), por lo que no deben aparecer siempre en `docker ps`. Metasploit permanece activo para `compose exec`.

## Precauciones

- La primera construccion de Kali/Metasploit puede tardar y requiere conectividad.
- `.env` se excluye de Git; `.env.example` es publicable. No guarde contrasenas reales en `.env.example`.
- Los puertos de Metasploit se publican solo en `127.0.0.1` por defecto.
- No use `docker system prune -af --volumes` como rutina de limpieza: afecta otros proyectos Docker del equipo.
- Para detener Metasploit: `docker compose stop metasploit`. Para eliminar los recursos de este proyecto: `docker compose down` (sin `-v` para conservar datos).
- Los comandos deben probarse en el equipo de destino. La validacion estatica no sustituye una prueba de despliegue real.
