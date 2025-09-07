#!/bin/bash
# setup-annonces-usb.sh - Installation automatique des fichiers audio TimeVox

set -e

# Variables
SCRIPT_NAME="setup-annonces-usb.sh"
LOG_FILE="/tmp/timevox_install.log"
INSTALL_USER="timevox"
USB_MOUNT_POINT="/media/timevox/usb"

# URLs GitHub pour les fichiers audio
GITHUB_BASE_URL="https://raw.githubusercontent.com/Didtho/timevox/main"
GITHUB_ANNONCES_SPECIAUX_URL="$GITHUB_BASE_URL/annonces_speciaux"
GITHUB_ANNONCE_URL="$GITHUB_BASE_URL/annonce"

# Fichiers spéciaux à télécharger
SPECIAL_FILES=("12.mp3" "13.mp3" "14.mp3" "17.mp3" "18.mp3")
DEFAULT_ANNOUNCE_FILE="annonce_defaut.mp3"

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
    echo -e "${BLUE}[AUDIO-SETUP]${NC} $1"
    log "$1"
}

print_success() {
    echo -e "${GREEN}[AUDIO-SETUP]${NC} $1"
    log "SUCCESS: $1"
}

print_error() {
    echo -e "${RED}[AUDIO-SETUP]${NC} $1"
    log "ERROR: $1"
}

print_warning() {
    echo -e "${YELLOW}[AUDIO-SETUP]${NC} $1"
    log "WARNING: $1"
}

# Vérifier la connectivité internet
check_internet() {
    print_status "Vérification de la connexion internet..."
    
    if ping -c 1 github.com >/dev/null 2>&1; then
        print_success "Connexion internet disponible"
        return 0
    else
        print_warning "Pas de connexion internet - téléchargement impossible"
        return 1
    fi
}

# Télécharger un fichier depuis GitHub
download_file() {
    local url="$1"
    local destination="$2"
    local filename=$(basename "$destination")
    
    print_status "Téléchargement de $filename..."
    
    # Vérifier si le fichier existe déjà
    if [ -f "$destination" ]; then
        print_status "$filename existe déjà - ignoré"
        return 0
    fi
    
    # Créer le répertoire de destination s'il n'existe pas
    mkdir -p "$(dirname "$destination")"
    
    # Télécharger avec curl
    if curl -L -s -f "$url" -o "$destination" --max-time 30; then
        print_success "$filename téléchargé avec succès"
        
        # Vérifier que le fichier n'est pas vide
        if [ -s "$destination" ]; then
            # Ajuster les permissions
            chown "$INSTALL_USER:$INSTALL_USER" "$destination" 2>/dev/null || true
            chmod 644 "$destination"
            return 0
        else
            print_error "$filename téléchargé mais vide"
            rm -f "$destination"
            return 1
        fi
    else
        print_error "Échec téléchargement de $filename"
        rm -f "$destination" 2>/dev/null || true
        return 1
    fi
}

# Télécharger les fichiers spéciaux
download_special_files() {
    print_status "Téléchargement des fichiers numéros spéciaux..."
    
    local target_dir="$USB_MOUNT_POINT/Numeros speciaux"
    local success_count=0
    
    # Créer le répertoire s'il n'existe pas
    mkdir -p "$target_dir"
    
    for file in "${SPECIAL_FILES[@]}"; do
        local url="$GITHUB_ANNONCES_SPECIAUX_URL/$file"
        local destination="$target_dir/$file"
        
        if download_file "$url" "$destination"; then
            success_count=$((success_count + 1))
        fi
    done
    
    print_status "Fichiers spéciaux téléchargés: $success_count/${#SPECIAL_FILES[@]}"
    
    if [ $success_count -eq ${#SPECIAL_FILES[@]} ]; then
        print_success "Tous les fichiers spéciaux téléchargés"
        return 0
    elif [ $success_count -gt 0 ]; then
        print_warning "Téléchargement partiel des fichiers spéciaux"
        return 0
    else
        print_error "Aucun fichier spécial téléchargé"
        return 1
    fi
}

# Télécharger l'annonce par défaut
download_default_announce() {
    print_status "Téléchargement de l'annonce par défaut..."
    
    local target_dir="$USB_MOUNT_POINT/Annonce"
    local url="$GITHUB_ANNONCE_URL/$DEFAULT_ANNOUNCE_FILE"
    local destination="$target_dir/$DEFAULT_ANNOUNCE_FILE"
    
    # Créer le répertoire s'il n'existe pas
    mkdir -p "$target_dir"
    
    if download_file "$url" "$destination"; then
        print_success "Annonce par défaut téléchargée"
        return 0
    else
        print_error "Échec téléchargement annonce par défaut"
        return 1
    fi
}

# Vérifier si la clé USB est disponible et configurée
check_usb_available() {
    print_status "Vérification de la clé USB..."
    
    if [ ! -d "$USB_MOUNT_POINT" ]; then
        print_warning "Point de montage USB inexistant: $USB_MOUNT_POINT"
        return 1
    fi
    
    if ! mountpoint -q "$USB_MOUNT_POINT" 2>/dev/null; then
        print_warning "Aucune clé USB montée sur $USB_MOUNT_POINT"
        return 1
    fi
    
    # Vérifier la structure TimeVox
    if [ ! -d "$USB_MOUNT_POINT/Annonce" ] || [ ! -d "$USB_MOUNT_POINT/Messages" ]; then
        print_warning "Structure TimeVox incomplète sur la clé USB"
        return 1
    fi
    
    print_success "Clé USB TimeVox détectée et disponible"
    return 0
}

# Créer un log spécifique pour les téléchargements
log_download_status() {
    local status="$1"
    local details="$2"
    
    if [ -d "$USB_MOUNT_POINT/Logs" ]; then
        local log_file="$USB_MOUNT_POINT/Logs/audio_downloads.log"
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo "$timestamp - $status - $details" >> "$log_file"
        chown "$INSTALL_USER:$INSTALL_USER" "$log_file" 2>/dev/null || true
    fi
}

# Fonction principale
main() {
    print_status "=== Installation des fichiers audio TimeVox ==="
    
    # Vérifier la connexion internet
    if ! check_internet; then
        log_download_status "SKIP" "Pas de connexion internet lors de l'installation"
        print_warning "Installation continue sans téléchargement des fichiers audio"
        return 0
    fi
    
    # Vérifier la disponibilité de la clé USB
    if ! check_usb_available; then
        log_download_status "SKIP" "Clé USB non disponible lors de l'installation"
        print_warning "Clé USB non détectée - fichiers seront téléchargés au premier démarrage"
        return 0
    fi
    
    print_status "Début du téléchargement des fichiers audio..."
    
    # Télécharger les fichiers spéciaux
    local special_success=false
    if download_special_files; then
        special_success=true
        log_download_status "SUCCESS" "Fichiers spéciaux téléchargés lors de l'installation"
    else
        log_download_status "ERROR" "Échec téléchargement fichiers spéciaux lors de l'installation"
    fi
    
    # Télécharger l'annonce par défaut
    local announce_success=false
    if download_default_announce; then
        announce_success=true
        log_download_status "SUCCESS" "Annonce par défaut téléchargée lors de l'installation"
    else
        log_download_status "ERROR" "Échec téléchargement annonce par défaut lors de l'installation"
    fi
    
    # Rapport final
    if $special_success && $announce_success; then
        print_success "=== Tous les fichiers audio installés avec succès ==="
    elif $special_success || $announce_success; then
        print_warning "=== Installation partielle des fichiers audio ==="
    else
        print_error "=== Échec installation des fichiers audio ==="
        print_status "Les fichiers seront téléchargés automatiquement au démarrage de TimeVox"
    fi
    
    return 0
}

# Point d'entrée
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi