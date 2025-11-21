#!/bin/bash

# ==============================================================================
# SCRIPT DE DESPLIEGUE AUTOMÁTICO PARA SECGEN (TFG-Pedro José Gabaldón Penalva)
# ==============================================================================
# Prepara una máquina para ejecutar el escenario.
# ==============================================================================

set -e # Detener el script si algo falla

# COLORES
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}[INFO] Iniciando despliegue de entorno SecGen (TFG)...${NC}"

# 0. VERIFICACIÓN DE UBICACIÓN
if [ ! -f "Gemfile" ]; then
    echo -e "${RED}[ERROR] No se encuentra el archivo 'Gemfile'.${NC}"
    echo "Por favor, ejecuta este script desde la raíz de la carpeta SecGen."
    exit 1
fi

# 1. DEPENDENCIAS DEL SISTEMA
echo -e "${GREEN}[1/6] Actualizando sistema e instalando librerías...${NC}"
sudo apt-get update
sudo apt-get install -y \
    git curl wget build-essential \
    autoconf bison patch rustc libssl-dev libyaml-dev libreadline6-dev \
    zlib1g-dev libgmp-dev libncurses5-dev libffi-dev libgdbm6 libgdbm-dev \
    libdb-dev uuid-dev steghide

# 2. VIRTUALBOX, VAGRANT Y RED
echo -e "${GREEN}[2/6] Configurando Virtualización y Redes...${NC}"
sudo apt-get install -y virtualbox

if ! command -v vagrant &> /dev/null; then
    wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt-get update && sudo apt-get install -y vagrant
fi

# Crear la red Host-Only necesaria para Kali y las máquinas(192.168.56.1)
echo "Configurando adaptador de red vboxnet0..."
if ! VBoxManage list hostonlyifs | grep -q "vboxnet0"; then
    VBoxManage hostonlyif create
fi
# Forzar la IP de la puerta de enlace (vital para que la VM tenga la 192.168.56.x)
VBoxManage hostonlyif ipconfig vboxnet0 --ip 192.168.56.1 --netmask 255.255.255.0

# 3. RUBY (RBENV)
echo -e "${GREEN}[3/6] Instalando Ruby 2.7.8...${NC}"

if [ ! -d "$HOME/.rbenv" ]; then
    git clone https://github.com/rbenv/rbenv.git ~/.rbenv
    mkdir -p "$HOME/.rbenv/plugins"
    git clone https://github.com/rbenv/ruby-build.git "$HOME/.rbenv/plugins/ruby-build"
    
    # Añadir al bashrc para el futuro
    echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
    echo 'eval "$(rbenv init -)"' >> ~/.bashrc
fi

# Cargar rbenv en ESTA sesión del script
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"

if ! rbenv versions | grep -q "2.7.8"; then
    echo "Compilando Ruby 2.7.8 (Paciencia, tarda unos minutos)..."
    rbenv install 2.7.8
fi

rbenv local 2.7.8
rbenv global 2.7.8

# 4. GEMAS Y BUNDLER
echo -e "${GREEN}[4/6] Instalando dependencias de Ruby (Gems)...${NC}"
gem install bundler -v 2.2.22
bundle _2.2.22_ install

# 5. SIDELOADING DE LA BOX (PARA DESCARGAR LAS BOXES EN LOCAL)
echo -e "${GREEN}[5/6] Configurando imagen base (Vagrant Box)...${NC}"
SECGEN_BOX_NAME="modules_bases_debian_stretch_desktop_kde"

if ! vagrant box list | grep -q "^$SECGEN_BOX_NAME"; then
    echo "Descargando box oficial y parcheando nombre..."
    # Descargar
    vagrant box add secgen/debian_stretch_desktop_kde --provider virtualbox --force || true
    
    # Localizar descarga
    SOURCE_DIR=$(find ~/.vagrant.d/boxes -maxdepth 1 -type d -name "secgen-VAGRANTSLASH-debian_stretch_desktop_kde" | head -n 1)
    TARGET_DIR="$HOME/.vagrant.d/boxes/$SECGEN_BOX_NAME"

    if [ -d "$SOURCE_DIR" ]; then
        # Copiar con el nombre correcto
        cp -r "$SOURCE_DIR" "$TARGET_DIR"
        # Borrar metadata para evitar updates
        rm -f "$TARGET_DIR/metadata_url"
        echo "Box instalada correctamente como '$SECGEN_BOX_NAME'"
    else
        echo -e "${RED}[ERROR] No se pudo descargar la box de Vagrant Cloud.${NC}"
        exit 1
    fi
else
    echo "La box ya está configurada."
fi

# 6. FINALIZAR
echo -e "${BLUE}=============================================================${NC}"
echo -e "${BLUE} ENTORNO LISTO. EJECUTA ./launch.sh ${NC}"
echo -e "${BLUE}=============================================================${NC}"
