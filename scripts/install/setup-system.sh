#!/bin/bash
# setup-system.sh - Installation des dépendances système pour TimeVox

set -e

# Variables
SCRIPT_NAME="setup-system.sh"
LOG_FILE="/tmp/timevox_install.log"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Fonction de logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [$SCRIPT_NAME] $1" | tee -a "$LOG_FILE"
}

print_status() {
    echo -e "${BLUE}[SYSTEM]${NC} $1"
    log "$1"
}

print_success() {
    echo -e "${GREEN}[SYSTEM]${NC} $1"
    log "SUCCESS: $1"
}

print_error() {
    echo -e "${RED}[SYSTEM]${NC} $1"
    log "ERROR: $1"
}

print_warning() {
    echo -e "${YELLOW}[SYSTEM]${NC} $1"
    log "WARNING: $1"
}

# Liste des paquets système requis
SYSTEM_PACKAGES=(
    # Outils de base
    "git"                    # Déjà installé normalement, mais on vérifie
    "curl"                   # Pour les téléchargements
    "wget"                   # Alternative à curl
    "unzip"                  # Décompression archives
    "build-essential"        # Compilateur C/C++ pour certaines dépendances Python
    
    # Python et outils de développement
    "python3"                # Langage principal
    "python3-pip"            # Gestionnaire de packages Python
    "python3-venv"           # Environnements virtuels Python
    "python3-dev"            # Headers Python pour compilation
    
    # Audio et multimédia
    "alsa-utils"             # Outils ALSA pour l'audio
    "pulseaudio"             # Serveur audio (optionnel mais utile)
    "ffmpeg"                 # Traitement audio/vidéo pour les effets
    "sox"                    # Traitement audio en ligne de commande
    "libsndfile1"            # Bibliothèque pour fichiers audio
    
    # Dépendances SDL2 pour pygame
    "libsdl2-dev"
    "libsdl2-image-dev" 
    "libsdl2-mixer-dev"
    "libsdl2-ttf-dev"

    # Dépendances pour Pillow
    "libjpeg-dev"
    "libfreetype6-dev"
    "liblcms2-dev"
    "libopenjp2-7-dev"
    "libtiff5-dev"
    "tk-dev"
    "libharfbuzz-dev"
    "libfribidi-dev"

    # Systèmes et hardware
    "i2c-tools"              # Outils I2C pour l'OLED
    "python3-smbus"          # Interface Python pour I2C
    "ntpdate"                # Synchronisation de l'heure
    
    # Bibliothèques système pour Python
    "libasound2-dev"         # Headers ALSA pour pygame
    "portaudio19-dev"        # Audio cross-platform
    "libportaudio2"          # Runtime PortAudio
    "libportaudiocpp0"       # C++ bindings PortAudio
    "libfreetype6-dev"       # Pour Pillow/PIL (affichage OLED)
    "libjpeg-dev"            # Support JPEG pour Pillow
    "libpng-dev"             # Support PNG pour Pillow
    "libopenjp2-7-dev"       # Support JPEG2000
    
    # Outils optionnels mais utiles
    "htop"                   # Monitoring système
    "nano"                   # Éditeur de texte simple
    "screen"                 # Sessions persistantes
)

# Vérifier si un paquet est installé
is_package_installed() {
    dpkg -l "$1" 2>/dev/null | grep -q "^ii"
}

# Installer un paquet avec vérification
install_package() {
    local package="$1"
    
    if is_package_installed "$package"; then
        print_status "$package déjà installé"
        return 0
    fi
    
    print_status "Installation de $package..."
    if sudo apt install -y "$package" >/dev/null 2>&1; then
        print_success "$package installé avec succès"
        return 0
    else
        print_error "Échec installation de $package"
        return 1
    fi
}

# Activer I2C si nécessaire
setup_i2c() {
    print_status "Configuration I2C pour l'écran OLED..."
    
    # Vérifier si I2C est déjà activé
    if lsmod | grep -q i2c_bcm2835; then
        print_success "I2C déjà activé"
        return 0
    fi
    
    # Activer I2C via raspi-config de manière non-interactive
    if command -v raspi-config >/dev/null 2>&1; then
        print_status "Activation I2C via raspi-config..."
        sudo raspi-config nonint do_i2c 0  # 0 = enable
        
        # Vérifier que les modules sont chargés
        if ! grep -q "^i2c-dev" /etc/modules; then
            echo "i2c-dev" | sudo tee -a /etc/modules
        fi
        
        print_success "I2C activé (redémarrage requis pour prise en effet)"
    else
        print_warning "raspi-config non disponible, activation manuelle I2C..."
        
        # Activation manuelle via config.txt
        if ! grep -q "^dtparam=i2c_arm=on" /boot/config.txt; then
            echo "dtparam=i2c_arm=on" | sudo tee -a /boot/config.txt
        fi
        
        # Ajouter les modules
        if ! grep -q "^i2c-bcm2835" /etc/modules; then
            echo "i2c-bcm2835" | sudo tee -a /etc/modules
        fi
        
        if ! grep -q "^i2c-dev" /etc/modules; then
            echo "i2c-dev" | sudo tee -a /etc/modules
        fi
        
        print_success "I2C configuré manuellement (redémarrage requis)"
    fi
}

# Configurer l'audio de base
setup_basic_audio() {
    print_status "Configuration audio de base..."
    
    # S'assurer que l'utilisateur est dans le groupe audio
    if ! groups "$USER" | grep -q audio; then
        print_status "Ajout de $USER au groupe audio..."
        sudo usermod -a -G audio "$USER"
        print_success "Utilisateur ajouté au groupe audio"
    else
        print_status "Utilisateur déjà dans le groupe audio"
    fi
    
    # Vérifier la configuration ALSA de base
    if [ ! -f /usr/share/alsa/alsa.conf ]; then
        print_warning "Configuration ALSA non trouvée"
    else
        print_success "Configuration ALSA présente"
    fi
    
    # Créer un fichier asound.conf basique si nécessaire
    if [ ! -f /home/$USER/.asoundrc ]; then
        print_status "Création configuration audio utilisateur..."
        cat > /home/$USER/.asoundrc << 'EOF'
# Configuration ALSA pour TimeVox
pcm.!default {
    type hw
    card 0
    device 0
}

ctl.!default {
    type hw
    card 0
}
EOF
        print_success "Configuration audio utilisateur créée"
    fi
}

# Optimiser les paramètres système pour Raspberry Pi
optimize_system() {
    print_status "Optimisation des paramètres système..."
    
    # Augmenter la limite de mémoire GPU (utile pour l'audio)
    if grep -q "^gpu_mem=" /boot/config.txt; then
        print_status "gpu_mem déjà configuré"
    else
        print_status "Configuration mémoire GPU..."
        echo "gpu_mem=64" | sudo tee -a /boot/config.txt
        print_success "Mémoire GPU configurée à 64MB"
    fi
    
    # Optimiser les paramètres audio
    if [ ! -f /etc/modprobe.d/alsa-base.conf ]; then
        print_status "Création configuration ALSA optimisée..."
        sudo mkdir -p /etc/modprobe.d
        cat | sudo tee /etc/modprobe.d/timevox-audio.conf << 'EOF'
# Configuration audio optimisée pour TimeVox
options snd-usb-audio index=-2
options snd-bcm2835 index=0
EOF
        print_success "Configuration ALSA optimisée créée"
    fi
}

# Fonction principale
main() {
    print_status "=== Installation des dépendances système ==="
    
    # Mettre à jour la cache des paquets (déjà fait dans install.sh mais on s'assure)
    print_status "Mise à jour de la cache des paquets..."
    sudo apt update
    
    # Installer les paquets système
    print_status "Installation des paquets requis..."
    failed_packages=()
    
    for package in "${SYSTEM_PACKAGES[@]}"; do
        if ! install_package "$package"; then
            failed_packages+=("$package")
        fi
    done
    
    # Vérifier les échecs
    if [ ${#failed_packages[@]} -gt 0 ]; then
        print_error "Échec installation de certains paquets:"
        for package in "${failed_packages[@]}"; do
            print_error "  - $package"
        done
        
        # Essayer de continuer quand même
        print_warning "Tentative de continuation malgré les échecs..."
    else
        print_success "Tous les paquets système installés avec succès"
    fi
    
    # Configuration I2C
    setup_i2c
    
    # Configuration audio de base
    setup_basic_audio
    
    # Optimisations système
    optimize_system
    
    # Nettoyage
    print_status "Nettoyage des caches..."
    sudo apt autoremove -y >/dev/null 2>&1
    sudo apt autoclean >/dev/null 2>&1
    print_success "Nettoyage terminé"
    
    print_success "=== Configuration système terminée ==="
    
    # Informations importantes
    echo ""
    print_warning "IMPORTANT: Un redémarrage sera nécessaire pour:"
    print_warning "  - Activation complète d'I2C"
    print_warning "  - Prise en compte des groupes utilisateur"
    print_warning "  - Application des optimisations GPU"
    echo ""
    
    return 0
}

# Exécution si script appelé directement
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi