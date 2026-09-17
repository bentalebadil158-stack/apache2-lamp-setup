# Apache 2 + LAMP setup

Script interactivo en Bash para preparar un sitio web en Apache2 sobre Ubuntu 20.04. El flujo instala un stack LAMP, crea la estructura del sitio, configura acceso HTTP y HTTPS, protege `/administrator` con autenticación básica y restringe el acceso a `/blog` desde `192.168.1.1`.

## Qué configura

- Apache2, PHP, MariaDB y utilidades necesarias para el sitio.
- Un VirtualHost HTTP (`:80`) y otro HTTPS (`:443`).
- Certificado autofirmado para pruebas locales.
- Sitio web, página 404, zona privada y enlace simbólico a `~/blog`.
- Fichero `.htpasswd` protegido para el usuario administrador.
- Logs separados en `/var/log/apache2/<dominio>`.

## Requisitos

- Ubuntu 20.04 o compatible con `apt`, ejecutado en una máquina de pruebas.
- IPv4 global activa y un usuario local con directorio `/home/<usuario>`.
- Acceso `sudo`/root y conexión a Internet para instalar paquetes y descargar la imagen 404.
- `whiptail`, `ip`, `awk`, `grep`, `wget` y `systemctl` (el script instala `whiptail` si falta).

## Uso

El script modifica configuración del sistema, permisos y servicios. Revísalo antes de ejecutarlo y utilízalo únicamente en una máquina bajo tu control:

```bash
chmod +x apache2-lamp-setup.sh
sudo ./apache2-lamp-setup.sh
```

Durante la ejecución se solicitarán el nombre DNS local, las credenciales de la zona privada y los datos del certificado autofirmado. Para acceder desde el propio laboratorio, añade el nombre elegido y su alias `www` al DNS o a `/etc/hosts` de cada cliente.

## Comprobaciones posteriores

```bash
apache2ctl configtest
apache2ctl -S
systemctl status apache2
```

El script crea los sitios `www.conf` y `www-ssl.conf` en `/etc/apache2/sites-available/`. El certificado autofirmado genera avisos del navegador y no debe utilizarse como certificado de producción.

## Seguridad y limitaciones

Este proyecto es educativo y está pensado para un laboratorio. La autenticación básica debe utilizarse siempre sobre HTTPS; el certificado incluido es autofirmado. Cambia la IP restringida, el dominio y los valores de ejemplo antes de reutilizarlo. No ejecutes el script en un servidor de producción sin revisar sus cambios, dependencias, permisos y reglas de firewall.

## Licencia

Este proyecto se publica bajo la licencia MIT. Consulta [LICENSE](LICENSE).
