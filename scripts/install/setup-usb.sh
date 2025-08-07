#!/bin/bash
# scripts/install/setup-usb.sh - Configuration du montage automatique USB pour TimeVox
# Ce script fait partie des scripts d'installation modulaires

set -e

# Variables
USB_MOUNT_POINT="/media/timevox/usb"
UDEV_RULES_FILE="/etc/udev/rules.d/99-timevox-usb.rules"
LOG_FILE="/var/log/timevox-usb.log"

# Couleurs pour l'affichage
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Fonction principale de configuration (appelée lors de l'installation)
main() {
    print_status "Configuration du montage automatique USB..."
    
    # 1. Installer les dépendances USB
    install_usb_dependencies
    
    # 2. Créer le point de montage
    create_mount_point
    
    # 3. Créer les règles udev
    create_udev_rules
    
    # 4. Créer les scripts de montage
    create_mount_scripts
    
    # 5. Créer les services systemd
    create_systemd_services
    
    # 6. Activer et recharger
    enable_and_reload
    
    print_success "Configuration USB automatique terminée"
}

install_usb_dependencies() {
    print_status "Installation des dépendances USB..."
    sudo apt update
    sudo apt install -y udev udisks2 ntfs-3g exfat-fuse
    print_success "Dépendances USB installées"
}

create_mount_point() {
    print_status "Création du point de montage..."
    sudo mkdir -p "$USB_MOUNT_POINT"
    sudo chown timevox:timevox "$USB_MOUNT_POINT"
    sudo chmod 755 "$USB_MOUNT_POINT"
    print_success "Point de montage créé: $USB_MOUNT_POINT"
}

create_udev_rules() {
    print_status "Création des règles udev..."
    
    sudo tee "$UDEV_RULES_FILE" > /dev/null << 'EOF'
# TimeVox USB Auto-mount Rules
# Déclenchement sur insertion/retrait de périphériques de stockage USB

# Règle pour détecter l'insertion d'une clé USB
ACTION=="add", SUBSYSTEM=="block", KERNEL=="sd[a-z][0-9]", ENV{ID_FS_USAGE}=="filesystem", ENV{ID_BUS}=="usb", TAG+="systemd", ENV{SYSTEMD_WANTS}="timevox-usb-handler@%k.service"

# Règle pour détecter le retrait d'une clé USB  
ACTION=="remove", SUBSYSTEM=="block", KERNEL=="sd[a-z][0-9]", ENV{ID_BUS}=="usb", RUN+="/usr/local/bin/timevox-usb-unmount.sh"
EOF

    print_success "Règles udev créées dans $UDEV_RULES_FILE"
}

create_mount_scripts() {
    print_status "Création des scripts de montage..."
    
    # Script principal de montage
    sudo tee /usr/local/bin/timevox-usb-mount.sh > /dev/null << 'EOF'
#!/bin/bash
# Script de montage USB pour TimeVox

DEVICE="/dev/$1"
MOUNT_POINT="/media/timevox/usb"
LOG_FILE="/var/log/timevox-usb.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

log_message "=== Tentative de montage USB: $DEVICE ==="

# Vérifier que le périphérique existe
if [ ! -b "$DEVICE" ]; then
    log_message "ERREUR: Périphérique $DEVICE non trouvé"
    exit 1
fi

# Attendre que le périphérique soit stable
sleep 2

# Détecter le système de fichiers
FS_TYPE=$(blkid -o value -s TYPE "$DEVICE" 2>/dev/null || echo "unknown")
log_message "Système de fichiers détecté: $FS_TYPE"

# Créer le point de montage s'il n'existe pas
mkdir -p "$MOUNT_POINT"

# Démonter s'il y a déjà quelque chose de monté
if mountpoint -q "$MOUNT_POINT"; then
    log_message "Démontage de l'ancien périphérique..."
    umount "$MOUNT_POINT" 2>/dev/null || true
    sleep 1
fi

# Options de montage selon le système de fichiers
case "$FS_TYPE" in
    "vfat"|"fat32"|"fat16")
        MOUNT_OPTIONS="rw,uid=1000,gid=1000,umask=0022,sync,flush"
        ;;
    "ntfs")
        MOUNT_OPTIONS="rw,uid=1000,gid=1000,umask=0022"
        ;;
    "exfat")
        MOUNT_OPTIONS="rw,uid=1000,gid=1000,umask=0022"
        ;;
    "ext4"|"ext3"|"ext2")
        MOUNT_OPTIONS="rw,defaults"
        ;;
    *)
        log_message "ATTENTION: Système de fichiers $FS_TYPE non testé, tentative avec options par défaut"
        MOUNT_OPTIONS="rw,defaults"
        ;;
esac

# Tentative de montage
log_message "Montage avec options: $MOUNT_OPTIONS"
if mount -t "$FS_TYPE" -o "$MOUNT_OPTIONS" "$DEVICE" "$MOUNT_POINT" 2>/dev/null; then
    log_message "SUCCESS: Périphérique monté sur $MOUNT_POINT"
    
    # Ajuster les permissions
    chown -R timevox:timevox "$MOUNT_POINT" 2>/dev/null || true
    
    # Vérifier la structure TimeVox
    if [ -d "$MOUNT_POINT/Annonce" ] && [ -d "$MOUNT_POINT/Messages" ]; then
        log_message "SUCCESS: Structure TimeVox détectée"
    else
        log_message "INFO: Structure TimeVox non détectée, création en cours..."
        
        # Créer la structure de base
        mkdir -p "$MOUNT_POINT/Annonce"
        mkdir -p "$MOUNT_POINT/Messages"
        mkdir -p "$MOUNT_POINT/Parametres"
        mkdir -p "$MOUNT_POINT/Logs"
        
        # Créer un fichier README
        cat > "$MOUNT_POINT/README.txt" << 'EOREADME'
TimeVox - Structure de la clé USB
==================================

Cette clé USB a été automatiquement configurée pour TimeVox.

Dossiers:
- Annonce/    : Placez ici vos fichiers MP3 d'annonce
- Messages/   : Les messages enregistrés seront stockés ici (organisés par date)
- Parametres/ : Contient le fichier config.json pour la configuration
- Logs/       : Logs du système TimeVox

Configuration:
Modifiez le fichier Parametres/config.json pour ajuster:
- Le numéro principal à composer
- La durée d'enregistrement
- Le volume audio
- Les effets vintage

Pour plus d'informations: https://github.com/Didtho/timevox
EOREADME
        
        # Créer un config.json par défaut s'il n'existe pas
        if [ ! -f "$MOUNT_POINT/Parametres/config.json" ]; then
            cat > "$MOUNT_POINT/Parametres/config.json" << 'EOCONFIG'
{
  "numero_principal": "1972",
  "longueur_numero_principal": 4,
  "duree_enregistrement": 30,
  "volume_audio": 2,
  "filtre_vintage": true,
  "type_filtre": "radio_50s",
  "intensite_filtre": 0.7,
  "conserver_original": true,
  "description": "Configuration TimeVox - Modifiez selon vos besoins",
  "numero_description": "Numéro à composer pour déclencher l'annonce et l'enregistrement",
  "volume_description": "Volume en pourcentage (0-100). 2% évite la saturation.",
  "filtre_description": "Effets vintage pour un son radio années 50"
}
EOCONFIG
        fi
        
        # Ajuster les permissions finales
        chown -R timevox:timevox "$MOUNT_POINT" 2>/dev/null || true
        chmod -R 755 "$MOUNT_POINT" 2>/dev/null || true
        
        log_message "SUCCESS: Structure TimeVox créée"
    fi
    
    # Notifier TimeVox si le service est actif
    if systemctl is-active --quiet timevox 2>/dev/null; then
        log_message "INFO: Notification du service TimeVox"
        systemctl reload timevox 2>/dev/null || true
    fi
    
    log_message "SUCCESS: Clé USB TimeVox prête à l'utilisation"
    
else
    log_message "ERREUR: Échec du montage de $DEVICE"
    
    # Tentative de montage sans spécifier le type de système de fichiers
    log_message "INFO: Tentative de montage automatique sans type spécifique"
    if mount -o "$MOUNT_OPTIONS" "$DEVICE" "$MOUNT_POINT" 2>/dev/null; then
        log_message "SUCCESS: Montage automatique réussi"
        chown -R timevox:timevox "$MOUNT_POINT" 2>/dev/null || true
    else
        log_message "ERREUR: Toutes les tentatives de montage ont échoué"
        exit 1
    fi
fi
EOF

    # Script de gestion des événements
    sudo tee /usr/local/bin/timevox-usb-handler.sh > /dev/null << 'EOF'
#!/bin/bash
# Gestionnaire d'événements USB pour TimeVox

DEVICE_NAME="$1"
DEVICE="/dev/$1"
LOG_FILE="/var/log/timevox-usb.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

log_message "=== Événement USB détecté pour: $DEVICE_NAME ==="

# Vérifier que c'est une partition (pas juste le disque)
if [[ "$DEVICE_NAME" =~ [0-9]$ ]]; then
    log_message "INFO: Partition détectée: $DEVICE_NAME"
    
    # Attendre que le périphérique soit stable
    sleep 3
    
    # Vérifier que le périphérique existe toujours
    if [ -b "$DEVICE" ]; then
        log_message "INFO: Démarrage du montage pour $DEVICE_NAME"
        /usr/local/bin/timevox-usb-mount.sh "$DEVICE_NAME"
    else
        log_message "WARNING: Périphérique $DEVICE disparu avant le montage"
    fi
else
    log_message "INFO: Disque entier détecté: $DEVICE_NAME (ignoré, attente des partitions)"
fi
EOF

    # Script de démontage
    sudo tee /usr/local/bin/timevox-usb-unmount.sh > /dev/null << 'EOF'
#!/bin/bash
# Script de démontage USB pour TimeVox

MOUNT_POINT="/media/timevox/usb"
LOG_FILE="/var/log/timevox-usb.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

log_message "=== Démontage USB requis ==="

if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
    log_message "INFO: Démontage de $MOUNT_POINT en cours..."
    
    # Synchroniser avant de démonter
    sync
    
    # Démonter
    if umount "$MOUNT_POINT" 2>/dev/null; then
        log_message "SUCCESS: Périphérique démonté avec succès"
    else
        log_message "WARNING: Démontage forcé nécessaire"
        umount -f "$MOUNT_POINT" 2>/dev/null || true
    fi
    
    # Notifier TimeVox du changement
    if systemctl is-active --quiet timevox 2>/dev/null; then
        log_message "INFO: Notification du service TimeVox"
        systemctl reload timevox 2>/dev/null || true
    fi
else
    log_message "INFO: Aucun périphérique monté sur $MOUNT_POINT"
fi
EOF

    # Rendre les scripts exécutables
    sudo chmod +x /usr/local/bin/timevox-usb-*.sh
    
    # Créer le fichier de log avec les bonnes permissions
    sudo touch "$LOG_FILE"
    sudo chown timevox:timevox "$LOG_FILE"
    sudo chmod 644 "$LOG_FILE"
    
    print_success "Scripts de montage créés et configurés"
}

create_systemd_services() {
    print_status "Création des services systemd..."
    
    # Service de gestion des événements USB
    sudo tee /etc/systemd/system/timevox-usb-handler@.service > /dev/null << 'EOF'
[Unit]
Description=TimeVox USB Handler for %i
After=dev-%i.device

[Service]
Type=oneshot
ExecStart=/usr/local/bin/timevox-usb-handler.sh %i
TimeoutSec=30
User=root
StandardOutput=journal
StandardError=journal
EOF

    print_success "Services systemd créés"
}

enable_and_reload() {
    print_status "Activation et rechargement..."
    
    # Recharger systemd
    sudo systemctl daemon-reload
    
    # Recharger les règles udev
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    
    print_success "Configuration USB rechargée"
}

# Fonction de test (pour usage post-installation)
test_usb_detection() {
    print_status "Test de détection USB..."
    
    # Vérifier le point de montage
    if [ -d "$USB_MOUNT_POINT" ]; then
        if mountpoint -q "$USB_MOUNT_POINT"; then
            print_success "Clé USB montée sur $USB_MOUNT_POINT"
            
            # Vérifier la structure
            if [ -d "$USB_MOUNT_POINT/Annonce" ] && [ -d "$USB_MOUNT_POINT/Messages" ]; then
                print_success "Structure TimeVox détectée"
                
                # Compter les fichiers
                announce_count=$(find "$USB_MOUNT_POINT/Annonce" -name "*.mp3" 2>/dev/null | wc -l)
                message_count=$(find "$USB_MOUNT_POINT/Messages" -name "*.mp3" 2>/dev/null | wc -l)
                
                echo "  - Fichiers d'annonce: $announce_count"
                echo "  - Messages enregistrés: $message_count"
            else
                print_warning "Structure TimeVox incomplète"
            fi
        else
            print_warning "Point de montage existe mais aucune clé montée"
        fi
    else
        print_warning "Point de montage n'existe pas encore"
    fi
    
    # Lister les périphériques USB disponibles
    print_status "Périphériques USB détectés:"
    USB_DEVICES=$(lsblk -o NAME,TRAN,TYPE,SIZE,MOUNTPOINT 2>/dev/null | grep usb || echo "Aucun")
    echo "$USB_DEVICES"
}

# Fonction de statut (pour diagnostic)
show_status() {
    print_status "Statut de la configuration USB TimeVox:"
    echo ""
    
    # Point de montage
    echo "Point de montage: $USB_MOUNT_POINT"
    if [ -d "$USB_MOUNT_POINT" ]; then
        if mountpoint -q "$USB_MOUNT_POINT"; then
            print_success "✓ Clé USB montée"
            
            # Informations sur la clé
            FS_INFO=$(df -h "$USB_MOUNT_POINT" 2>/dev/null | tail -1)
            echo "  $FS_INFO"
            
            # Contenu
                        
            if [ -d "$USB_MOUNT_POINT/Messages" ]; then
                MESSAGE_COUNT=$(find "$USB_MOUNT_POINT/Messages" -name "*.mp3" 2>/dev/null | wc -l)
                echo "  Messages enregistrés: $MESSAGE_COUNT"
            fi
        else
            print_warning "✗ Aucune clé USB montée"
        fi
    else
        print_error "✗ Point de montage inexistant"
    fi
    
    echo ""
    
    # Configuration
    if [ -f "$UDEV_RULES_FILE" ]; then
        print_success "✓ Règles udev installées"
    else
        print_error "✗ Règles udev manquantes"
    fi
    
    if [ -f "/usr/local/bin/timevox-usb-mount.sh" ]; then
        print_success "✓ Scripts de montage installés"
    else
        print_error "✗ Scripts de montage manquants"
    fi
    
    # Log récent
    echo ""
    if [ -f "$LOG_FILE" ]; then
        echo "Dernières entrées du log USB:"
        tail -5 "$LOG_FILE" 2>/dev/null || echo "Log vide"
    else
        print_warning "Aucun fichier de log trouvé"
    fi
}

# Point d'entrée du script
# Pendant l'installation, on appelle directement main()
# Pour les autres usages, on peut appeler avec des paramètres
case "${1:-install}" in
    "install"|"")
        # Mode installation (défaut)
        main
        ;;
    "test")
        test_usb_detection
        ;;
    "status")
        show_status
        ;;
    "mount")
        if [ -n "$2" ]; then
            /usr/local/bin/timevox-usb-mount.sh "$2"
        else
            print_error "Usage: $0 mount <device>"
            exit 1
        fi
        ;;
    "unmount")
        /usr/local/bin/timevox-usb-unmount.sh
        ;;
    *)
        echo "Usage: $0 {install|test|status|mount <device>|unmount}"
        echo ""
        echo "Commandes:"
        echo "  install - Configure le montage automatique USB (défaut)"
        echo "  test    - Teste la détection et le montage USB"
        echo "  status  - Affiche le statut de la configuration USB"
        echo "  mount   - Monte manuellement un périphérique"
        echo "  unmount - Démonte la clé USB"
        exit 1
        ;;
esac