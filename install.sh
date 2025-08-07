#!/bin/bash
# install.sh - Script d'installation principal TimeVox
# Usage: curl -sSL https://raw.githubusercontent.com/Didtho/timevox/main/install.sh | bash

set -e  # Arreter en cas d'erreur

# Variables globales
REPO_URL="https://github.com/Didtho/timevox.git"
INSTALL_USER="timevox"
INSTALL_DIR="/home/$INSTALL_USER/timevox"
VENV_DIR="/home/$INSTALL_USER/timevox_env"
LOG_FILE="/tmp/timevox_install.log"

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Fonction de logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Fonction d'affichage colore
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
    log "INFO: $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    log "SUCCESS: $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    log "WARNING: $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log "ERROR: $1"
}

print_header() {
    echo -e "${CYAN}$1${NC}"
    log "HEADER: $1"
}

# Fonction de verification des prerequis
check_prerequisites() {
    print_header "=== Verification des prerequis ==="
    
    # Verifier le systeme d'exploitation
    if ! grep -q "Raspberry Pi OS" /etc/os-release 2>/dev/null; then
        print_warning "Ce script est optimise pour Raspberry Pi OS"
        print_warning "Continuation sur $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    else
        print_success "Raspberry Pi OS detecte"
    fi
    
    # Verifier l'utilisateur
    if [ "$USER" != "$INSTALL_USER" ]; then
        print_error "Ce script doit etre execute par l'utilisateur '$INSTALL_USER'"
        print_error "Utilisateur actuel: $USER"
        print_error ""
        print_error "Instructions:"
        print_error "1. Creez l'utilisateur timevox lors du flashage avec Raspberry Pi Imager"
        print_error "2. Connectez-vous avec cet utilisateur"
        print_error "3. Relancez ce script"
        exit 1
    fi
    
    print_success "Utilisateur correct: $USER"
    
    # Verifier la connexion internet
    if ping -c 1 github.com >/dev/null 2>&1; then
        print_success "Connexion internet OK"
    else
        print_error "Pas de connexion internet detectee"
        print_error "Verifiez votre configuration reseau/WiFi"
        exit 1
    fi
    
    # Verifier l'espace disque (minimum 2GB)
    available_space=$(df / | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt 2097152 ]; then  # 2GB en KB
        print_warning "Espace disque faible: $(($available_space/1024))MB disponibles"
        print_warning "Recommande: au moins 2GB libres"
    else
        print_success "Espace disque suffisant: $(($available_space/1024/1024))GB disponibles"
    fi
}

# Fonction de nettoyage en cas d'echec
cleanup_on_failure() {
    print_error "Installation echouee, nettoyage en cours..."
    
    # Arreter les services s'ils existent
    sudo systemctl stop timevox timevox-shutdown 2>/dev/null || true
    sudo systemctl disable timevox timevox-shutdown 2>/dev/null || true
    
    # Supprimer les services
    sudo rm -f /etc/systemd/system/timevox*.service
    sudo systemctl daemon-reload
    
    # Supprimer les dossiers d'installation
    rm -rf "$INSTALL_DIR" "$VENV_DIR"
    
    print_error "Nettoyage termine"
    print_error "Consultez le log: $LOG_FILE"
    exit 1
}

# Pieger les erreurs pour nettoyer
trap cleanup_on_failure ERR

# Fonction principale d'installation
main() {
    print_header "========================================"
    print_header "    Installation TimeVox v1.0"
    print_header "========================================"
    print_header ""
    
    # Initialiser le log
    log "=== DEBUT INSTALLATION TIMEVOX ==="
    log "Utilisateur: $USER"
    log "Repertoire d'installation: $INSTALL_DIR"
    log "Environnement Python: $VENV_DIR"
    
    # Etape 1: Verification des prerequis
    check_prerequisites
    
    # Etape 2: Mise a jour du systeme et configuration
    print_header ""
    print_header "=== Mise a jour du systeme ==="
    print_status "Mise a jour de la liste des paquets..."
    sudo apt update
    print_success "Liste des paquets mise a jour"

    # Configuration du fichier config.txt
    print_status "Configuration des interfaces materielles..."
    
    # Detecter le bon chemin du fichier config.txt selon la version de Raspberry Pi OS
    if [ -f "/boot/firmware/config.txt" ]; then
        CONFIG_FILE="/boot/firmware/config.txt"
        print_status "Utilisation de /boot/firmware/config.txt (Raspberry Pi OS recent)"
    elif [ -f "/boot/config.txt" ]; then
        CONFIG_FILE="/boot/config.txt"
        print_status "Utilisation de /boot/config.txt (Raspberry Pi OS ancien)"
    else
        print_error "Fichier config.txt non trouve"
        exit 1
    fi

    print_status "Mise a jour de $CONFIG_FILE..."
    
    # Sauvegarder le fichier original
    sudo cp "$CONFIG_FILE" "${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Fonction pour ajouter ou modifier une ligne dans config.txt
    update_config_line() {
        local line="$1"
        local file="$2"
        local key=$(echo "$line" | cut -d'=' -f1)
        
        if sudo grep -q "^${key}=" "$file"; then
            # La ligne existe, la remplacer
            sudo sed -i "s/^${key}=.*/${line}/" "$file"
            print_status "Mis a jour: $line"
        elif sudo grep -q "^#${key}=" "$file"; then
            # La ligne existe mais est commentee, la remplacer
            sudo sed -i "s/^#${key}=.*/${line}/" "$file"
            print_status "Active: $line"
        else
            # La ligne n'existe pas, l'ajouter
            echo "$line" | sudo tee -a "$file" >/dev/null
            print_status "Ajoute: $line"
        fi
    }
    
    # Fonction pour ajouter une ligne dtoverlay uniquement si elle n'existe pas
    add_overlay_if_missing() {
        local overlay="$1"
        local file="$2"
        
        if ! sudo grep -q "^${overlay}" "$file" && ! sudo grep -q "^#${overlay}" "$file"; then
            echo "$overlay" | sudo tee -a "$file" >/dev/null
            print_status "Ajoute: $overlay"
        else
            # Si elle existe mais est commentee, l'activer
            if sudo grep -q "^#${overlay}" "$file"; then
                sudo sed -i "s/^#${overlay}/${overlay}/" "$file"
                print_status "Active: $overlay"
            else
                print_status "Deja present: $overlay"
            fi
        fi
    }
    
    # Appliquer les configurations necessaires pour TimeVox
    update_config_line "dtparam=i2c_arm=on" "$CONFIG_FILE"
    update_config_line "dtparam=i2s=on" "$CONFIG_FILE"
    update_config_line "dtparam=spi=on" "$CONFIG_FILE"
    update_config_line "dtparam=audio=off" "$CONFIG_FILE"  # Desactiver l'audio HDMI/Jack
    
    # Ajouter les overlays s'ils n'existent pas
    add_overlay_if_missing "dtoverlay=hifiberry-dac" "$CONFIG_FILE"
    add_overlay_if_missing "dtoverlay=i2c-rtc,ds3231" "$CONFIG_FILE"
    
    print_success "Configuration materielle mise a jour dans $CONFIG_FILE"
    
    # Activer i2c via raspi-config de maniere non-interactive
    print_status "Activation de l'interface I2C..."
    sudo raspi-config nonint do_i2c 0  # 0 = enable, 1 = disable
    if [ $? -eq 0 ]; then
        print_success "Interface I2C activee"
    else
        print_warning "Echec activation I2C automatique, activation manuelle..."
        # Methode alternative: modifier directement le fichier de config
        sudo sed -i 's/^#dtparam=i2c_arm=on/dtparam=i2c_arm=on/' "$CONFIG_FILE"
        # Ajouter le module au demarrage
        echo 'i2c-dev' | sudo tee -a /etc/modules
    fi
    
    # Activer SPI si necessaire
    print_status "Activation de l'interface SPI..."
    sudo raspi-config nonint do_spi 0
    if [ $? -eq 0 ]; then
        print_success "Interface SPI activee"
    else
        print_warning "Echec activation SPI automatique"
    fi
    
    # Verifier que les modules sont bien charges
    if ! lsmod | grep -q "i2c_dev"; then
        print_status "Chargement du module i2c-dev..."
        sudo modprobe i2c-dev || print_warning "Impossible de charger i2c-dev maintenant (sera actif apres redemarrage)"
    fi
 
    # Vérifier et installer Git si nécessaire
    if ! command -v git >/dev/null 2>&1; then
        print_status "Installation de Git (requis pour le téléchargement)..."
        sudo apt install -y git
        print_success "Git installé"
    else
        print_success "Git déjà disponible"
    fi
	
    # Etape 3: Telechargement du code source
    print_header ""
    print_header "=== Telechargement TimeVox ==="
    
    # Supprimer l'installation existante si elle existe
    if [ -d "$INSTALL_DIR" ]; then
        print_warning "Installation existante detectee, sauvegarde..."
        mv "$INSTALL_DIR" "${INSTALL_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
    fi
    
    print_status "Clonage depuis GitHub..."
    git clone "$REPO_URL" "$INSTALL_DIR"
    print_success "Code source telecharge dans $INSTALL_DIR"
    
    # Etape 4: Execution des scripts d'installation modulaires
    print_header ""
    print_header "=== Installation des composants ==="
    
    cd "$INSTALL_DIR"
    
    # Rendre les scripts executables
    chmod +x scripts/install/*.sh
    
    # Executer chaque script modulaire
    print_status "Installation des dependances systeme..."
    if ./scripts/install/setup-system.sh; then
        print_success "Dependances systeme installees"
    else
        print_error "Echec installation dependances systeme"
        exit 1
    fi
    
    print_status "Configuration de l'environnement Python..."
    if ./scripts/install/setup-python.sh; then
        print_success "Environnement Python configure"
    else
        print_error "Echec configuration Python"
        exit 1
    fi
    
    print_status "Configuration audio..."
    if ./scripts/install/setup-audio.sh; then
        print_success "Audio configure"
    else
        print_error "Echec configuration audio"
        exit 1
    fi
    
    print_status "Configuration des permissions GPIO..."
    if ./scripts/install/setup-gpio.sh; then
        print_success "Permissions GPIO configurees"
    else
        print_error "Echec configuration GPIO"
        exit 1
    fi
    
    # NOUVEAU: Configuration du montage automatique USB
    print_status "Configuration du montage automatique USB..."
    if ./scripts/install/setup-usb.sh; then
        print_success "Montage automatique USB configure"
    else
        print_error "Echec configuration USB"
        exit 1
    fi
    
    print_status "Installation des services systeme..."
    if ./scripts/install/setup-services.sh; then
        print_success "Services systeme installes"
    else
        print_error "Echec installation services"
        exit 1
    fi
    
    # Etape 5: Tests post-installation
    print_header ""
    print_header "=== Tests de validation ==="
    
    if ./scripts/install/test-installation.sh; then
        print_success "Tous les tests sont passes"
    else
        print_warning "Certains tests ont echoue - voir les details ci-dessus"
        print_warning "L'installation peut fonctionner malgre ces avertissements"
    fi
    
    # Etape 6: Finalisation
    print_header ""
    print_header "=== Finalisation ==="
    
    # Demarrer les services
    print_status "Activation des services TimeVox..."
    sudo systemctl enable timevox timevox-shutdown
    
    print_success "Installation terminee avec succes !"
    print_header ""
    print_header "========================================"
    print_header "    TimeVox est pret !"
    print_header "========================================"
    print_header ""
    
    # Informations finales
    echo -e "${GREEN}Installation reussie !${NC}"
    echo ""
    echo -e "${YELLOW}Informations importantes :${NC}"
    echo "- Repertoire d'installation: $INSTALL_DIR"
    echo "- Services installes: timevox, timevox-shutdown"
    echo "- Point de montage USB automatique: /media/timevox/usb"
    echo "- Log d'installation: $LOG_FILE"
    echo ""
    echo -e "${YELLOW}Configuration automatique USB :${NC}"
    echo "- Les clés USB seront automatiquement montées sur /media/timevox/usb"
    echo "- Structure TimeVox créée automatiquement si nécessaire"
    echo "- Support: FAT32, NTFS, exFAT, ext4"
    echo ""
    echo -e "${YELLOW}Prochaines etapes :${NC}"
    echo "1. Redemarrez le systeme: sudo reboot"
    echo "2. Connectez votre materiel (OLED, amplificateur, etc.)"
    echo "3. Inserez une cle USB avec la structure requise"
    echo "4. Testez en decrochant le telephone !"
    echo ""
    echo -e "${YELLOW}Commandes utiles :${NC}"
    echo "- Voir les logs: sudo journalctl -u timevox -f"
    echo "- Voir les logs USB: sudo tail -f /var/log/timevox-usb.log"
    echo "- Statut du service: sudo systemctl status timevox"
    echo "- Redemarrer TimeVox: sudo systemctl restart timevox"
    echo "- Test USB: $INSTALL_DIR/scripts/install/setup-usb.sh status"
    echo ""
    echo -e "${CYAN}Support: https://github.com/Didtho/timevox${NC}"
    
    log "=== INSTALLATION TERMINEE AVEC SUCCES ==="
}

# Point d'entree
main "$@"