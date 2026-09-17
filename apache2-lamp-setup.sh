#!/bin/bash

# Shell Script para aprender directivas de Apache donde se irán añadiendo paso a paso para que de tiempo a probarlas desde el navegador

# versión parte2: Creación estructura www, activación configuración, comprobaciones con chromium-browser en script adicional: apache.parte2.comprobaciones.sh

# Adil Bentaleb - Nov-2026

# Instanciar la variable de abajo con la IP de la máquina donde se va a ejecutar

# Probado en UBUNTU 20.04

# Crea un sitio donde haya una subcarpeta/zona de acceso por autenticación utilizando el módulo auth_basic. Dicha carpeta se llamará "administrator".

# Comprueba el acceso por enlace simbólico al blog. Modifica el sitio para que la IP 192.168.1.1 no pueda navegar el blog.

# Permite que dicho sitio se pueda navegar tanto por http como por https.

IP_SERVIDOR=$(ip -4 -o addr show scope global up | awk 'NR==1 {split($4, a, "/"); print a[1]}')

user=$(whoami)

if [[ -z "$IP_SERVIDOR" ]]; then
  echo "Error: no se ha podido detectar una IPv4 global del servidor." >&2
  exit 1
fi

# ============================================================================
# CONFIGURACIÓN Y SEGURIDAD
# ============================================================================

set -o errexit
set -o nounset
set -o pipefail

trap 'rm -f -- "${INPUT_FILE:-}" "${DOWNLOAD_FILE:-}"' EXIT

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Error: falta el comando requerido: $1" >&2
    exit 1
  }
}

if [[ $EUID -ne 0 ]]; then
  echo "No eres root... :'("
  echo "Ejecuta el script con sudo: sudo $0"
  exit 1
fi

# Dependencias mínimas para que la interfaz y las comprobaciones funcionen.
if ! command -v whiptail >/dev/null 2>&1; then
  apt update
  apt install -y whiptail
fi

require_command ip
require_command awk
require_command grep
require_command wget
require_command systemctl

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME="/home/$TARGET_USER"

if [[ ! -d "$TARGET_HOME" ]]; then
  echo "Error: no existe el directorio personal de $TARGET_USER: $TARGET_HOME" >&2
  exit 1
fi

INPUT_FILE=$(mktemp)
DOWNLOAD_FILE=""

# INSTALACIÓN

if (whiptail --title "Hola sr. $user! :)" --yes-button "Adelante!" --no-button "No, ya está instalado" --yesno "¿Procedemos con la instalación de LAMP?" 8 78) then

# FIX: se añade apache2-utils, necesario para htpasswd más abajo (a veces no viene con lamp-server^)

    apt update && apt install -y lamp-server^ tree apache2-utils openssl

else

    echo "Has seleccionado No, el if toma el valor de \\$? y continuo con el script"

fi



if (whiptail --title "Escribe el DNS web que va usar Sin WWW: " --inputbox "Nombre del sitio web:" 8 78 2> "$INPUT_FILE") then

  nombre_web=$(<"$INPUT_FILE")

# FIX: se ha eliminado el "echo >> /etc/hosts" que había aquí, porque duplicaba la línea

# en /etc/hosts sin importar la respuesta que dieras en la siguiente pregunta de confirmación.

fi

if [[ -z "${nombre_web:-}" ]]; then
  echo "Error: no se ha indicado el nombre DNS del sitio web." >&2
  exit 1
fi

if [[ ! "$nombre_web" =~ ^[A-Za-z0-9.-]+$ ]]; then
  echo "Error: el nombre DNS contiene caracteres no válidos: $nombre_web" >&2
  exit 1
fi

if (whiptail --title "Escribiendo en el fichero hosts: $IP_SERVIDOR $nombre_web" --yes-button "Aceptar" --no-button "Cancelar" --yesno "¿Modifico /etc/hosts?" 8 78) then

  if ! awk -v ip="$IP_SERVIDOR" -v host="$nombre_web" '$1 == ip && ($2 == host || $3 == host || $2 == "www." host || $3 == "www." host) { found=1; exit } END { exit !found }' /etc/hosts; then
    echo "$IP_SERVIDOR $nombre_web www.$nombre_web" >> /etc/hosts
  else
    echo "La entrada de $nombre_web ya existe en /etc/hosts; no se duplica."
  fi

fi



#COMANDOS CREACIÓN ESTRUCTURA WEB

#Sitio navegable con www.delarioja.red

echo "Creando estructura de web $nombre_web"; sleep 1

mkdir -p "/var/www/$nombre_web/administrator"

mkdir -p "/var/log/apache2/$nombre_web"

mkdir -p "$TARGET_HOME/blog"

if [[ ! -e "/var/www/$nombre_web/blog" ]]; then
  ln -s "$TARGET_HOME/blog" "/var/www/$nombre_web/blog"
fi



# FIX: se comprueba que el wget funcione antes de continuar

DOWNLOAD_FILE=$(mktemp)
if wget -q -O "$DOWNLOAD_FILE" https://delarioja.org/web_images/404.png; then
  mv "$DOWNLOAD_FILE" "/var/www/$nombre_web/404.png"

else

  rm -f "$DOWNLOAD_FILE"
  echo "Aviso: no se pudo descargar 404.png, continúo sin ella"

fi



# Cuando naveguemos $nombre_web/blog seguira el acceso directo que acabamos de crear

# FIX: heredoc SIN comillas ("<<EOF" en vez de "<<'EOF'") para que $nombre_web se sustituya de verdad,

# si no, el HTML acaba literalmente con el texto "$nombre_web" en vez del valor.

cat <<EOF > $TARGET_HOME/blog/index.html

<!DOCTYPE html>

<meta charset="UTF-8">

<html lang="es">

<head>

<meta property="og:title" content="Adil Bentaleb - Portfolio">

<meta property="og:description" content="Portfolio de Adil Bentaleb - Sistemas, Redes y Administración IT">

<meta property="og:image" content="https://bentaleb-adil.pages.dev/preview.png">

<meta property="og:url" content="https://bentaleb-adil.pages.dev/">

<meta property="og:type" content="website">

<style>

  :root{

    --bg:#fafafa;

    --surface:#ffffff;

    --border:#e5e5e5;

    --border-strong:#d4d4d4;

    --text:#171717;

    --text-dim:#6b7280;

    --text-faint:#9ca3af;

    --accent:#4f46e5;

    --accent-soft:#eef2ff;

    --accent-ring:#c7d2fe;

    --radius:16px;

  }

  *{box-sizing:border-box;margin:0;padding:0;}

  html{scroll-behavior:smooth;}

  body{

    background:var(--bg);

    color:var(--text);

    font-family:'Inter',sans-serif;

    line-height:1.6;

    -webkit-font-smoothing:antialiased;

  }

  .mono{font-family:'JetBrains Mono',monospace;}

  a{color:inherit;text-decoration:none;}

  .wrap{max-width:880px;margin:0 auto;padding:0 24px;}

  section{padding:88px 0;}

  h2{font-size:30px;font-weight:700;margin-bottom:12px;letter-spacing:-0.02em;}

  .eyebrow{font-size:13px;font-weight:600;color:var(--accent);margin-bottom:10px;}

  .section-sub{color:var(--text-dim);font-size:15px;margin-bottom:40px;max-width:560px;}



  /* NAV */

  nav{

    position:sticky;top:0;z-index:50;

    background:rgba(250,250,250,0.85);backdrop-filter:blur(10px);

    border-bottom:1px solid var(--border);

  }

  nav .wrap{display:flex;align-items:center;justify-content:space-between;height:68px;max-width:960px;}

  nav .logo{font-weight:700;font-size:15px;letter-spacing:-0.01em;}

  nav ul{display:flex;gap:8px;list-style:none;}

  nav ul li a{font-size:14px;color:var(--text-dim);padding:8px 14px;border-radius:8px;transition:all .15s;}

  nav ul li a:hover{color:var(--text);background:var(--surface);}

  .navtoggle{display:none;background:none;border:none;font-size:20px;cursor:pointer;}

  @media(max-width:720px){

    nav ul{display:none;}

    .navtoggle{display:block;}

    nav ul.open{

      display:flex;flex-direction:column;position:absolute;top:68px;left:0;right:0;

      background:var(--surface);padding:16px 24px;gap:4px;border-bottom:1px solid var(--border);

    }

  }



  /* HERO */

  .hero{padding:80px 0 60px;}

  .hero-top{display:flex;gap:32px;align-items:center;flex-wrap:wrap;}

  .avatar{

    width:112px;height:112px;border-radius:50%;flex-shrink:0;

    border:4px solid var(--surface);box-shadow:0 0 0 1px var(--border), 0 8px 24px rgba(0,0,0,0.06);

    overflow:hidden;background:var(--accent-soft);

  }

  .avatar img{width:100%;height:100%;object-fit:cover;display:block;}

  .badge{

    display:inline-flex;align-items:center;gap:7px;

    font-size:13px;font-weight:500;color:#059669;

    background:#ecfdf5;border:1px solid #a7f3d0;

    padding:6px 14px;border-radius:999px;margin-bottom:16px;

  }

  .badge::before{content:"";width:6px;height:6px;border-radius:50%;background:#059669;display:inline-block;}

  .hero h1{font-size:44px;line-height:1.1;font-weight:800;letter-spacing:-0.02em;margin-bottom:6px;}

  .hero .role{font-size:18px;color:var(--accent);font-weight:600;margin-bottom:2px;}

  .hero .loc{font-size:14px;color:var(--text-faint);}

  .hero p.lead{max-width:600px;color:var(--text-dim);font-size:16px;margin:28px 0 32px;}

  .ctas{display:flex;gap:12px;flex-wrap:wrap;margin-bottom:48px;}

  .btn{

    padding:11px 22px;border-radius:10px;font-size:14px;font-weight:600;

    display:inline-block;transition:all .15s;

  }

  .btn-primary{background:var(--text);color:#fff;}

  .btn-primary:hover{background:#000;}

  .btn-secondary{border:1px solid var(--border-strong);color:var(--text);background:var(--surface);}

  .btn-secondary:hover{border-color:var(--text);}

  .stats{display:flex;gap:0;border:1px solid var(--border);border-radius:var(--radius);overflow:hidden;background:var(--surface);}

  .stat{flex:1;padding:20px 24px;border-right:1px solid var(--border);}

  .stat:last-child{border-right:none;}

  .stat .num{font-size:26px;font-weight:800;letter-spacing:-0.01em;}

  .stat .label{font-size:13px;color:var(--text-dim);margin-top:2px;}

  @media(max-width:600px){.hero-top{flex-direction:column;align-items:flex-start;} .stats{flex-direction:column;} .stat{border-right:none;border-bottom:1px solid var(--border);} .stat:last-child{border-bottom:none;}}



  /* CARD GRID (about) */

  .stack-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(190px,1fr));gap:14px;margin-top:36px;}

  .stack-item{background:var(--surface);border:1px solid var(--border);border-radius:var(--radius);padding:20px;transition:border-color .15s;}

  .stack-item:hover{border-color:var(--border-strong);}

  .stack-item .icon-emoji{font-size:22px;margin-bottom:10px;display:block;}

  .stack-item h4{font-size:14.5px;margin-bottom:4px;font-weight:600;}

  .stack-item p{font-size:13px;color:var(--text-dim);margin:0;}



  /* EXPERIENCE */

  .job{background:var(--surface);border:1px solid var(--border);border-radius:var(--radius);padding:28px;margin-bottom:16px;}

  .job-head{display:flex;justify-content:space-between;flex-wrap:wrap;gap:8px;margin-bottom:4px;}

  .job-head h3{font-size:17px;font-weight:700;}

  .job-head .dates{font-size:13px;color:var(--accent);font-weight:600;background:var(--accent-soft);padding:4px 10px;border-radius:999px;white-space:nowrap;height:fit-content;}

  .job .company{color:var(--text-dim);font-size:14px;margin-bottom:16px;}

  .job ul{padding-left:18px;color:var(--text-dim);font-size:14.5px;}

  .job ul li{margin-bottom:7px;}



  /* EDUCATION */

  .edu-row{display:flex;gap:20px;padding:18px 0;border-top:1px solid var(--border);align-items:baseline;}

  .edu-row:first-of-type{border-top:none;}

  .edu-row .yr{color:var(--accent);font-size:13px;font-weight:700;min-width:48px;}

  .edu-row h4{font-size:15px;margin-bottom:2px;font-weight:600;}

  .edu-row p{font-size:13.5px;color:var(--text-dim);}



  /* SKILLS */

  .skill-groups{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:16px;}

  .skill-card{background:var(--surface);border:1px solid var(--border);border-radius:var(--radius);padding:22px;}

  .skill-card h4{font-size:14px;margin-bottom:16px;display:flex;align-items:center;gap:8px;font-weight:600;}

  .skill-card h4 .em{font-size:17px;}

  .bar-row{margin-bottom:13px;}

  .bar-row:last-child{margin-bottom:0;}

  .bar-row .bar-label{display:flex;justify-content:space-between;font-size:13px;margin-bottom:6px;}

  .bar-row .bar-label b{font-weight:500;}

  .bar-row .bar-label span{color:var(--text-faint);font-size:12px;}

  .bar-track{height:6px;background:var(--accent-soft);border-radius:4px;overflow:hidden;}

  .bar-fill{height:100%;border-radius:4px;background:var(--accent);width:0;transition:width 1.1s ease;}



  /* PROJECTS */

  .proj-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:16px;}

  .proj-card{background:var(--surface);border:1px solid var(--border);border-radius:var(--radius);padding:22px;display:flex;flex-direction:column;transition:border-color .15s, transform .15s;}

  .proj-card:hover{border-color:var(--border-strong);transform:translateY(-2px);}

  .proj-card h4{font-size:15.5px;margin-bottom:8px;font-weight:600;}

  .proj-card p{font-size:13.5px;color:var(--text-dim);flex:1;margin-bottom:14px;}

  .proj-card .tags{display:flex;flex-wrap:wrap;gap:6px;margin-bottom:14px;}

  .proj-card .tags span{font-size:11px;color:var(--accent);background:var(--accent-soft);padding:3px 9px;border-radius:999px;font-weight:500;}

  .proj-card a{font-size:13px;font-weight:600;color:var(--text);}

  .proj-card a:hover{color:var(--accent);}



  /* LANGUAGES */

  .lang-row{display:flex;flex-wrap:wrap;gap:12px;}

  .lang-item{background:var(--surface);border:1px solid var(--border);border-radius:12px;padding:14px 20px;flex:1;min-width:140px;}

  .lang-item .name{font-size:14.5px;font-weight:600;}

  .lang-item .level{font-size:12px;color:var(--text-faint);margin-top:2px;}



  /* CONTACT */

  .contact-card{background:var(--text);color:#fff;border-radius:20px;padding:48px;text-align:center;}

  .contact-card h2{color:#fff;}

  .contact-card p{color:#a3a3a3;margin-bottom:28px;max-width:440px;margin-left:auto;margin-right:auto;}

  .contact-ctas{display:flex;gap:12px;justify-content:center;flex-wrap:wrap;}

  .contact-ctas a{padding:12px 24px;border-radius:10px;font-size:14px;font-weight:600;}

  .contact-ctas a.primary{background:#fff;color:#000;}

  .contact-ctas a.secondary{border:1px solid #404040;color:#fff;}

  .contact-loc{margin-top:24px;font-size:13px;color:#737373;}



  footer{text-align:center;padding:32px 0;color:var(--text-faint);font-size:13px;}



  .reveal{opacity:0;transform:translateY(20px);transition:opacity .6s ease, transform .6s ease;}

  .reveal.visible{opacity:1;transform:translateY(0);}

</style>

</head>

<body>



<nav>

  <div class="wrap">

    <a href="#inicio" class="logo">Adil Bentaleb</a>

    <button class="navtoggle" onclick="document.getElementById('navlinks').classList.toggle('open')">☰</button>

    <ul id="navlinks">

      <li><a href="#sobre-mi">Sobre mí</a></li>

      <li><a href="#experiencia">Experiencia</a></li>

      <li><a href="#formacion">Formación</a></li>

      <li><a href="#skills">Skills</a></li>

      <li><a href="#proyectos">Proyectos</a></li>

      <li><a href="#contacto">Contacto</a></li>

    </ul>

  </div>

</nav>



<header id="inicio" class="hero">

  <div class="wrap">

    <div class="hero-top">

      <div class="avatar">

        <img src="data:image/jpeg;base64,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" alt="Adil Bentaleb">

      </div>

      <div>

        <div class="badge">Disponible para nuevas oportunidades</div>

        <div class="role">Administrador de Sistemas Junior</div>

        <h1>Adil Bentaleb</h1>

        <div class="loc">Logroño, La Rioja · ASIR 2025</div>

      </div>

    </div>

    <p class="lead">Técnico informático con formación ASIR y experiencia práctica en soporte N1/N2, Active Directory y monitorización de infraestructura. Complemento la formación con un homelab propio donde despliego y administro Proxmox VE, Zabbix y redes segmentadas.</p>

    <div class="ctas">

      <a href="#contacto" class="btn btn-primary">Contactar</a>

      <a href="https://www.linkedin.com/in/adil-bentaleb-83472a209" class="btn btn-secondary" target="_blank">LinkedIn</a>

    </div>

    <div class="stats">

      <div class="stat"><div class="num" data-count="2025">0</div><div class="label">ASIR Grado Superior</div></div>

      <div class="stat"><div class="num" data-count="3">0</div><div class="label">Proyectos en GitHub</div></div>

      <div class="stat"><div class="num" data-count="5">0</div><div class="label">Idiomas</div></div>

    </div>

  </div>

</header>



<section id="sobre-mi" class="reveal">

  <div class="wrap">

    <div class="eyebrow">Sobre mí</div>

    <h2>Vocación por los sistemas y las redes</h2>

    <p class="section-sub">Mi trayectoria combina formación ASIR con experiencia práctica en soporte técnico, y un homelab personal donde sigo aprendiendo.</p>

    <p style="color:var(--text-dim);max-width:640px;margin-bottom:12px;">Técnico informático con vocación por los sistemas y las redes. Mi trayectoria combina la formación ASIR con experiencia práctica en soporte técnico: desde un hospital de alta criticidad en Barcelona hasta atención directa a usuarios y reparación de hardware en retail.</p>

    <p style="color:var(--text-dim);max-width:640px;margin-bottom:12px;">Fuera del trabajo, mantengo un homelab propio donde practico administración real de infraestructura — Proxmox VE, Zabbix, redes segmentadas — y publico los proyectos documentados en GitHub.</p>

    <p style="color:var(--text-dim);max-width:640px;">Actualmente busco una posición junior de administrador de sistemas o soporte IT donde aportar esta base y seguir creciendo técnicamente, con la vista puesta en certificaciones cloud (AZ-900) a corto plazo.</p>

    <div class="stack-grid">

      <div class="stack-item"><span class="icon-emoji">🖥️</span><h4>Sistemas</h4><p>Windows Server, Linux, Active Directory, GPOs</p></div>

      <div class="stack-item"><span class="icon-emoji">⚡</span><h4>Virtualización</h4><p>Proxmox VE, KVM, LXC, VMware</p></div>

      <div class="stack-item"><span class="icon-emoji">📡</span><h4>Monitorización</h4><p>Zabbix, Wireshark, análisis de tráfico</p></div>

      <div class="stack-item"><span class="icon-emoji">🌐</span><h4>Redes</h4><p>TCP/IP, VLANs, Cisco IOS, DNS/DHCP</p></div>

      <div class="stack-item"><span class="icon-emoji">🔧</span><h4>Soporte</h4><p>Help Desk N1/N2, ticketing, hardware</p></div>

      <div class="stack-item"><span class="icon-emoji">📧</span><h4>Microsoft 365</h4><p>Outlook, Teams, OneDrive, SharePoint</p></div>

    </div>

  </div>

</section>



<section id="experiencia" class="reveal">

  <div class="wrap">

    <div class="eyebrow">Trayectoria</div>

    <h2>Experiencia profesional</h2>

    <p class="section-sub">Soporte técnico y administración de sistemas en entornos exigentes.</p>



    <div class="job">

      <div class="job-head"><h3>Técnico Informático</h3><span class="dates">2024 – [MES/AÑO]</span></div>

      <div class="company">La Casa del PC · Alcampo, Logroño</div>

      <ul>

        <li>Diagnóstico y reparación de ordenadores, impresoras, TPV, verificadores de precios y balanzas electrónicas.</li>

        <li>Resolución de incidencias software: reinstalaciones, actualizaciones de SO, configuración de usuarios.</li>

        <li>Instalación y mantenimiento de la red informática interna del establecimiento.</li>

        <li>Soporte técnico directo a usuarios finales y clientes.</li>

      </ul>

    </div>



    <div class="job">

      <div class="job-head"><h3>Técnico Informático Polivalente</h3><span class="dates">2023 – 2024</span></div>

      <div class="company">Hospital San Juan de Dios · Barcelona</div>

      <ul>

        <li>Soporte técnico integral N1/N2 a más de 200 usuarios en entorno sanitario de alta criticidad.</li>

        <li>Administración básica de Active Directory: cuentas, grupos de seguridad y GPOs.</li>

        <li>Gestión de incidencias mediante ticketing con cumplimiento de SLAs.</li>

        <li>Instalación y mantenimiento de estaciones de trabajo y dispositivos de red.</li>

      </ul>

    </div>



    <div class="job">

      <div class="job-head"><h3>Experiencia previa</h3><span class="dates">2013 – 2017</span></div>

      <div class="company">Marruecos</div>

      <ul>

        <li>Mantenimiento de equipos informáticos y soporte técnico básico en entorno industrial, antes de establecerme en España.</li>

      </ul>

    </div>

  </div>

</section>



<section id="formacion" class="reveal">

  <div class="wrap">

    <div class="eyebrow">Formación</div>

    <h2>Formación académica</h2>

    <div style="background:var(--surface);border:1px solid var(--border);border-radius:var(--radius);padding:8px 28px;margin-top:28px;">

      <div class="edu-row"><div class="yr">2025</div><div><h4>FP Grado Superior — ASIR</h4><p>Centro Integrado Público FPD, La Rioja</p></div></div>

      <div class="edu-row"><div class="yr">2024</div><div><h4>Certificado de Ofimática (125h)</h4><p>Centro Integrado Público FPD, La Rioja</p></div></div>

      <div class="edu-row"><div class="yr">2023</div><div><h4>Google IT Support Professional Certificate</h4><p>Google / Coursera</p></div></div>

      <div class="edu-row"><div class="yr">—</div><div><h4>Preparando AZ-900 (Azure Fundamentals)</h4><p>En curso</p></div></div>

    </div>

  </div>

</section>



<section id="skills" class="reveal">

  <div class="wrap">

    <div class="eyebrow">Competencias</div>

    <h2>Skills técnicas</h2>

    <p class="section-sub">Base técnica construida en formación, trabajo y proyectos propios.</p>

    <div class="skill-groups">

      <div class="skill-card">

        <h4><span class="em">🖥️</span> Sistemas operativos</h4>

        <div class="bar-row"><div class="bar-label"><b>Windows Server / Desktop</b><span>90%</span></div><div class="bar-track"><div class="bar-fill" data-w="90"></div></div></div>

        <div class="bar-row"><div class="bar-label"><b>Linux (Ubuntu/CentOS)</b><span>75%</span></div><div class="bar-track"><div class="bar-fill" data-w="75"></div></div></div>

        <div class="bar-row"><div class="bar-label"><b>Active Directory / GPO</b><span>80%</span></div><div class="bar-track"><div class="bar-fill" data-w="80"></div></div></div>

      </div>

      <div class="skill-card">

        <h4><span class="em">⚡</span> Virtualización</h4>

        <div class="bar-row"><div class="bar-label"><b>Proxmox VE (KVM/LXC)</b><span>78%</span></div><div class="bar-track"><div class="bar-fill" data-w="78"></div></div></div>

        <div class="bar-row"><div class="bar-label"><b>VMware / ESXi</b><span>68%</span></div><div class="bar-track"><div class="bar-fill" data-w="68"></div></div></div>

      </div>

      <div class="skill-card">

        <h4><span class="em">📡</span> Monitorización</h4>

        <div class="bar-row"><div class="bar-label"><b>Zabbix</b><span>75%</span></div><div class="bar-track"><div class="bar-fill" data-w="75"></div></div></div>

        <div class="bar-row"><div class="bar-label"><b>Wireshark</b><span>72%</span></div><div class="bar-track"><div class="bar-fill" data-w="72"></div></div></div>

      </div>

      <div class="skill-card">

        <h4><span class="em">🌐</span> Redes</h4>

        <div class="bar-row"><div class="bar-label"><b>TCP/IP · DNS · DHCP</b><span>85%</span></div><div class="bar-track"><div class="bar-fill" data-w="85"></div></div></div>

        <div class="bar-row"><div class="bar-label"><b>Cisco IOS · VLANs</b><span>70%</span></div><div class="bar-track"><div class="bar-fill" data-w="70"></div></div></div>

      </div>

      <div class="skill-card">

        <h4><span class="em">🔧</span> Soporte técnico</h4>

        <div class="bar-row"><div class="bar-label"><b>Help Desk N1/N2</b><span>95%</span></div><div class="bar-track"><div class="bar-fill" data-w="95"></div></div></div>

        <div class="bar-row"><div class="bar-label"><b>Hardware / Reparación</b><span>90%</span></div><div class="bar-track"><div class="bar-fill" data-w="90"></div></div></div>

        <div class="bar-row"><div class="bar-label"><b>Ticketing (Jira/Freshdesk)</b><span>78%</span></div><div class="bar-track"><div class="bar-fill" data-w="78"></div></div></div>

      </div>

      <div class="skill-card">

        <h4><span class="em">📧</span> Microsoft 365</h4>

        <div class="bar-row"><div class="bar-label"><b>Outlook / Teams / SharePoint</b><span>80%</span></div><div class="bar-track"><div class="bar-fill" data-w="80"></div></div></div>

        <div class="bar-row"><div class="bar-label"><b>Bash / PowerShell</b><span>65%</span></div><div class="bar-track"><div class="bar-fill" data-w="65"></div></div></div>

      </div>

    </div>

  </div>

</section>



<section id="proyectos" class="reveal">

  <div class="wrap">

    <div class="eyebrow">Trabajo</div>

    <h2>Proyectos técnicos</h2>

    <p class="section-sub">Proyectos de formación y homelab, documentados y publicados en GitHub.</p>

    <div class="proj-grid">

      <div class="proj-card">

        <h4>🏢 Infraestructura Windows Server + AD</h4>

        <p>Diseño e implementación de dominio con Windows Server 2022: AD DS, DNS, DHCP, GPOs y políticas de seguridad. Proyecto final ASIR.</p>

        <div class="tags"><span>Windows Server</span><span>Active Directory</span><span>GPO</span></div>

      </div>

      <div class="proj-card">

        <h4>⚡ Virtualización con Proxmox VE</h4>

        <p>Hipervisor bare-metal, VMs (KVM) y contenedores LXC, red en bridge, ZFS, live migration entre nodos y snapshots automáticos.</p>

        <div class="tags"><span>Proxmox</span><span>KVM</span><span>ZFS</span></div>

      </div>

      <div class="proj-card">

        <h4>📊 Monitorización con Zabbix</h4>

        <p>Servidor Zabbix 6 sobre Ubuntu, agentes, templates personalizados y alertas por umbral CPU/RAM/disco en tiempo real.</p>

        <div class="tags"><span>Zabbix</span><span>Linux</span></div>

      </div>

      <div class="proj-card">

        <h4>🛡️ enruta-nat</h4>

        <p>Script interactivo en Bash para configurar un servidor Linux como router NAT con iptables, con menú whiptail y detección automática de interfaz.</p>

        <div class="tags"><span>Bash</span><span>iptables</span></div>

        <a href="https://github.com/bentalebadil158-stack/enruta-nat" target="_blank">Ver en GitHub →</a>

      </div>

      <div class="proj-card">

        <h4>🌍 ZoneCraft</h4>

        <p>Herramienta interactiva para crear y configurar zonas DNS directas e inversas en BIND9, con validación de sintaxis integrada.</p>

        <div class="tags"><span>DNS</span><span>BIND9</span></div>

        <a href="https://github.com/bentalebadil158-stack/zonecraft" target="_blank">Ver en GitHub →</a>

      </div>

      <div class="proj-card">

        <h4>📶 DHCP Manager</h4>

        <p>Gestor interactivo de servidores DHCP en Linux: creación de hosts fijos, configuración de subredes y backup automático.</p>

        <div class="tags"><span>DHCP</span><span>Bash</span></div>

        <a href="https://github.com/bentalebadil158-stack/DHCP-Manager" target="_blank">Ver en GitHub →</a>

      </div>

    </div>

  </div>

</section>



<section id="idiomas" class="reveal">

  <div class="wrap">

    <div class="eyebrow">Idiomas</div>

    <h2>Idiomas</h2>

    <div class="lang-row">

      <div class="lang-item"><div class="name">Árabe</div><div class="level">NATIVO</div></div>

      <div class="lang-item"><div class="name">Castellano</div><div class="level">ALTO · C1</div></div>

      <div class="lang-item"><div class="name">Inglés</div><div class="level">INTERMEDIO · B1</div></div>

      <div class="lang-item"><div class="name">Francés</div><div class="level">ALTO</div></div>

      <div class="lang-item"><div class="name">Catalán</div><div class="level">BÁSICO</div></div>

    </div>

  </div>

</section>



<section id="contacto" class="reveal">

  <div class="wrap">

    <div class="contact-card">

      <h2>¿Hablamos?</h2>

      <p>Disponible para nuevas oportunidades de administrador de sistemas junior o soporte IT.</p>

      <div class="contact-ctas">

        <a href="https://www.linkedin.com/in/adil-bentaleb-83472a209" class="primary" target="_blank">Contactar por LinkedIn</a>

        <a href="https://github.com/bentalebadil158-stack" class="secondary" target="_blank">Ver GitHub</a>

      </div>

      <div class="contact-loc">Logroño, La Rioja, España</div>

    </div>

  </div>

</section>



<footer>Diseñado & desarrollado por Adil Bentaleb · Logroño, La Rioja</footer>



<script>

  document.querySelectorAll('.stat .num').forEach(el => {

    const target = parseInt(el.getAttribute('data-count'), 10);

    let current = 0;

    const step = Math.max(1, Math.ceil(target / 40));

    function tick(){

      current += step;

      if(current >= target){ el.textContent = target; return; }

      el.textContent = current;

      requestAnimationFrame(tick);

    }

    setTimeout(tick, 400);

  });



  const revealEls = document.querySelectorAll('.reveal');

  const observer = new IntersectionObserver((entries) => {

    entries.forEach(entry => {

      if(entry.isIntersecting){

        entry.target.classList.add('visible');

        entry.target.querySelectorAll('.bar-fill').forEach(bar => {

          bar.style.width = bar.getAttribute('data-w') + '%';

        });

        observer.unobserve(entry.target);

      }

    });

  }, { threshold: 0.12 });

  revealEls.forEach(el => observer.observe(el));

</script>



</body>

</html>



EOF



# Cuando error 404 en $nombre_web

cat <<EOF > /var/www/$nombre_web/no-encontrada.htm

<!DOCTYPE html>

<html lang="es">

<head>

<meta charset="UTF-8">

<title>Página no encontrada — $nombre_web</title>

<meta name="description" content="Página no encontrada">

<style>

  :root{

    --bg:#fafafa;

    --surface:#ffffff;

    --border:#e5e5e5;

    --text:#171717;

    --text-dim:#6b7280;

    --accent:#4f46e5;

    --accent-soft:#eef2ff;

  }

  *{box-sizing:border-box;margin:0;padding:0;}

  body{

    background:var(--bg);

    color:var(--text);

    font-family:'Inter',sans-serif;

    min-height:100vh;

    display:flex;

    align-items:center;

    justify-content:center;

    padding:24px;

  }

  .card{

    background:var(--surface);

    border:1px solid var(--border);

    border-radius:20px;

    padding:48px;

    max-width:520px;

    text-align:center;

    box-shadow:0 8px 24px rgba(0,0,0,0.04);

  }

  .code{

    display:inline-block;

    font-size:13px;

    font-weight:600;

    color:var(--accent);

    background:var(--accent-soft);

    padding:6px 16px;

    border-radius:999px;

    margin-bottom:20px;

  }

  h1{

    font-size:32px;

    font-weight:800;

    letter-spacing:-0.02em;

    margin-bottom:12px;

  }

  p{

    color:var(--text-dim);

    font-size:15px;

    line-height:1.6;

    margin-bottom:8px;

  }

  .site{

    font-weight:600;

    color:var(--text);

  }

  pre{

    background:var(--bg);

    border:1px solid var(--border);

    border-radius:10px;

    padding:10px 14px;

    font-size:12px;

    color:var(--text-dim);

    margin:20px 0;

    text-align:left;

    overflow-x:auto;

  }

  a{

    display:inline-block;

    margin-top:8px;

    font-size:14px;

    font-weight:600;

    color:#fff;

    background:var(--text);

    padding:11px 24px;

    border-radius:10px;

    text-decoration:none;

  }

  a:hover{background:#000;}

</style>

</head>

<body>

  <div class="card">

    <span class="code">Error 404</span>

    <h1>Página no encontrada</h1>

    <p>El recurso que buscas no existe en <span class="site">$nombre_web</span>.</p>

    <pre>ErrorDocument 404 /no-encontrada.htm</pre>

    <a href="/">Volver al inicio</a>

  </div>

</body>

</html>

EOF



# Cuando naveguemos $nombre_web/administrator

cat <<EOF > /var/www/$nombre_web/administrator/index.html

  <html>

    <head>

      <title>Página de administración o BACKEND</title>

      <meta name="description" content="BACKEND de $nombre_web">

      <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>

                </head>

    <body><h1>BACKEND de $nombre_web</h1></br> <h2>Probando autenticación basic pero con capa de seguridad SSL si se pone https delante de la URL</h2>

    </body>

        </html>

EOF



{

    echo -e "XXX\n0\nCambiando grupo propietario www-data... \nXXX"

# FIX: se incluye también el directorio de logs en el cambio de propietario

    chown -R :www-data $TARGET_HOME/blog /var/www/$nombre_web/ /var/log/apache2/$nombre_web

    echo -e "XXX\n33\nCambiando grupo propietario www-data... HECHO.\nXXX"

    sleep 0.5



    echo -e "XXX\n33\nCambiando permisos de directorios... \nXXX"

    find $TARGET_HOME/blog -type d -exec chmod g=rwxs "{}" \\;

    find /var/www/$nombre_web/ -type d -exec chmod g=rwxs "{}" \\;

    echo -e "XXX\n66\nCambiando permisos de directorios... HECHO.\nXXX"

    sleep 1



    echo -e "XXX\n66\nCambiando permisos de ficheros... \nXXX"

    find $TARGET_HOME/blog -type f -exec chmod g=rw  "{}" \\;

    find /var/www/$nombre_web/ -type f -exec chmod g=rw  "{}" \\;

    echo -e "XXX\n100\nCambiando permisos de ficheros... HECHO.\nXXX"

    sleep 0.5



} | whiptail --title "Cambiando permisos" --gauge "Espere por favor" 6 60 0



# FIX: se saca esta línea fuera del pipe del gauge (dentro no era fiable, el protocolo

# del --gauge espera solo líneas "XXX/número/texto/XXX" y esto se podía perder)

if id -nG www-data | tr ' ' '\n' | grep -qx "$TARGET_USER"; then
  echo "www-data ya pertenece al grupo $TARGET_USER."
else
  usermod -aG "$TARGET_USER" www-data
fi

# Permite atravesar el directorio HOME mediante su grupo sin abrirlo a otros usuarios.
chmod g+x "$TARGET_HOME" # si no no puede acceder a /home/$TARGET_USER y por tanto tampoco a sus subcarpetas



#ZONA PRIVADA

read -r -p "Generando fichero de claves .htpasswd para acceso basic a carpetas inseguras protegidas por contraseña (pulsa Enter para Continuar)"

mkdir -p /var/www/passwd
chown root:www-data /var/www/passwd
chmod 750 /var/www/passwd

read -r -p "Introduzca el nombre del Usuario que va a ser propietario : " UserAdmin
if [[ -z "$UserAdmin" || "$UserAdmin" =~ [[:space:]] ]]; then
  echo "Error: el usuario de administración no puede estar vacío ni contener espacios." >&2
  exit 1
fi

echo "Generando /var/www/passwd/.htpasswd, introduce contraseña de "$UserAdmin" cuando se te pida (pulsa Enter para Continuar)"

htpasswd -c "/var/www/passwd/.htpasswd" "$UserAdmin"
chmod 640 /var/www/passwd/.htpasswd
chown root:www-data /var/www/passwd/.htpasswd

# por si queremos probar también grupos

cat > "/var/www/passwd/.htgroup" <<EOF

Matrix: $UserAdmin

EOF



if ! command -v openssl >/dev/null 2>&1; then
  apt update
  apt install -y openssl
fi



read -r -p "Generando clave y certificado autofirmado para el SSL de www-ssl.conf. ¡Atención! es importante que pongas *.delarioja.red cuando se te pida el FQDN del certificado (pulsa Enter para Continuar)"

openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
  -keyout "/etc/ssl/private/www.$nombre_web.key" \
  -out "/etc/ssl/certs/www.$nombre_web.crt"

chown root:ssl-cert "/etc/ssl/private/www.$nombre_web.key"

chmod 640 "/etc/ssl/private/www.$nombre_web.key"



# FIX: heredoc SIN comillas para que $nombre_web se sustituya, pero escapando \${APACHE_LOG_DIR}

# porque esa es una variable de entorno de Apache (definida en envvars), NO de bash:

# si no se escapa, bash intenta expandirla, no existe, y queda vacía en el fichero de config.

cat > /etc/apache2/sites-available/www-ssl.conf <<EOF

  <VirtualHost *:443>

    ServerName $nombre_web

    ServerAlias www.$nombre_web

    DocumentRoot /var/www/$nombre_web

    ErrorDocument 404 /no-encontrada.htm

    ErrorLog \${APACHE_LOG_DIR}/$nombre_web/error.log

    CustomLog \${APACHE_LOG_DIR}/$nombre_web/access.log combined

    <Directory "/var/www/$nombre_web">

         AllowOverride All

         Require all granted

    </Directory>

    <Directory "/var/www/$nombre_web/blog">

         Options -Indexes +FollowSymLinks

         AllowOverride None

          # FIX: aquí faltaba la restricción pedida en el enunciado:

          # que la IP 192.168.1.1 no pueda navegar el blog.

         <RequireAll>

           Require all granted

           Require not ip 192.168.1.1

         </RequireAll>

    </Directory>

    <Directory "/var/www/$nombre_web/administrator">

         AuthType Basic

         AuthName "Acceso restringido"

         AuthUserFile "/var/www/passwd/.htpasswd"

         Require user $UserAdmin

          #AuthGroupFile "/var/www/passwd/.htgroup"

          #Require group Matrix

          #Require valid-user

    </Directory>

    SSLEngine on

    SSLCertificateFile /etc/ssl/certs/www.$nombre_web.crt

    SSLCertificateKeyFile /etc/ssl/private/www.$nombre_web.key

     #SSLCipherSuite RSA:+HIGH:+MEDIUM

     #SSLProtocol all

     #<IfModule mod_userdir.c>

                 #    UserDir disabled

     #</IfModule>

  </VirtualHost>

EOF



# FIX: faltaba el VirtualHost por :80. El enunciado pide navegar el sitio TANTO por http

# como por https, así que se crea un segundo fichero de sitio para el puerto 80

# (mismo contenido, sin bloque SSL, y con la misma restricción de IP en el blog).

cat > /etc/apache2/sites-available/www.conf <<EOF

  <VirtualHost *:80>

    ServerName $nombre_web

    ServerAlias www.$nombre_web

    DocumentRoot /var/www/$nombre_web

    ErrorDocument 404 /no-encontrada.htm

    ErrorLog \${APACHE_LOG_DIR}/$nombre_web/error.log

    CustomLog \${APACHE_LOG_DIR}/$nombre_web/access.log combined

    <Directory "/var/www/$nombre_web">

         AllowOverride All

         Require all granted

    </Directory>

    <Directory "/var/www/$nombre_web/blog">

         Options -Indexes +FollowSymLinks

         AllowOverride None

         <RequireAll>

           Require all granted

           Require not ip 192.168.1.1

         </RequireAll>

    </Directory>

    <Directory "/var/www/$nombre_web/administrator">

         AuthType Basic

         AuthName "Acceso restringido"

         AuthUserFile "/var/www/passwd/.htpasswd"

         Require user $UserAdmin

    </Directory>

  </VirtualHost>

EOF



read -r -p "Habilito módulos ssl, authz_groupfile y authz_host (Pulsa Enter)"

a2enmod ssl auth_basic authz_groupfile authz_host



read -r -p "Activando sitios (http y https) y reiniciando (Pulse Enter)"

a2ensite www-ssl

a2ensite www

echo "Validando configuración de Apache antes del reinicio..."
apache2ctl configtest

echo "Ejecutando systemctl restart apache2 (atención abrimos los puertos 80 y 443)"; sleep 1
systemctl restart apache2

read -r -p "Compruebo configuración y muestro VirtualHost actualmente activos (Pulse Enter)"
apache2ctl configtest
apache2ctl -S
