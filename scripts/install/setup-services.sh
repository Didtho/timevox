#!/bin/bash
# setup-services.sh - Installation et configuration des services systemd TimeVox

set -e

# Variables
SCRIPT_NAME="setup-services.sh"
LOG_FILE="/tmp/timevox_install.log"
INSTALL_USER="timevox"
INSTALL_DIR="/home/$INSTALL_USER/timevox"
VENV_DIR="/home/$INSTALL_USER/timevox_env"
SERVICES_SOURCE_DIR="$INSTALL_DIR/configs/services"

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
    echo -e "${BLUE}[SERVICES]${NC} $1"
    log "$1"
}

print_success() {
    echo -e "${GREEN}[SERVICES]${NC} $1"
    log "SUCCESS: $1"
}

print_error() {
    echo -e "${RED}[SERVICES]${NC} $1"
    log "ERROR: $1"
}

print_warning() {
    echo -e "${YELLOW}[SERVICES]${NC} $1"
    log "WARNING: $1"
}

# Vérifier les prérequis pour les services
check_service_prerequisites() {
    print_status "Vérification des prérequis services..."
    
    # Vérifier que l'utilisateur timevox existe
    if id "$INSTALL_USER" >/dev/null 2>&1; then
        print_success "Utilisateur $INSTALL_USER existe"
    else
        print_error "Utilisateur $INSTALL_USER non trouvé"
        return 1
    fi
    
    # Vérifier l'installation TimeVox
    if [ -f "$INSTALL_DIR/timevox/main.py" ]; then
        print_success "Installation TimeVox trouvée"
    else
        print_error "Installation TimeVox non trouvée: $INSTALL_DIR/timevox/main.py"
        return 1
    fi
    
    # Vérifier l'environnement Python
    if [ -f "$VENV_DIR/bin/python3" ]; then
        print_success "Environnement Python trouvé"
    else
        print_error "Environnement Python non trouvé: $VENV_DIR"
        return 1
    fi
    
    # Vérifier les fichiers de service source
    if [ -d "$SERVICES_SOURCE_DIR" ]; then
        print_success "Répertoire services source trouvé"
    else
        print_error "Répertoire services non trouvé: $SERVICES_SOURCE_DIR"
        return 1
    fi
    
    return 0
}

# Installer le service principal TimeVox
install_timevox_service() {
    print_status "Installation du service TimeVox principal..."
    
    local service_file="timevox.service"
    local source_file="$SERVICES_SOURCE_DIR/$service_file"
    local target_file="/etc/systemd/system/$service_file"
    
    # Vérifier que le fichier source existe
    if [ ! -f "$source_file" ]; then
        print_error "Fichier service source non trouvé: $source_file"
        return 1
    fi
    
    # Copier le fichier de service
    print_status "Copie du fichier de service..."
    sudo cp "$source_file" "$target_file"
    
    # Vérifier et ajuster les chemins dans le service
    print_status "Vérification des chemins dans le service..."
    
    # Remplacer les chemins dynamiquement au cas où
    sudo sed -i "s|/home/timevox/timevox|$INSTALL_DIR|g" "$target_file"
    sudo sed -i "s|/home/timevox/timevox_env|$VENV_DIR|g" "$target_file"
    
    # Définir les permissions correctes
    sudo chmod 644 "$target_file"
    
    print_success "Service TimeVox installé: $target_file"
    return 0
}

# Installer le service de bouton d'arrêt
install_shutdown_service() {
    print_status "Installation du service bouton d'arrêt..."
    
    local service_file="timevox-shutdown.service"
    local source_file="$SERVICES_SOURCE_DIR/$service_file"
    local target_file="/etc/systemd/system/$service_file"
    
    # Vérifier que le fichier source existe
    if [ ! -f "$source_file" ]; then
        print_error "Fichier service shutdown non trouvé: $source_file"
        return 1
    fi
    
    # Copier le fichier de service
    print_status "Copie du service shutdown..."
    sudo cp "$source_file" "$target_file"
    
    # Ajuster les chemins
    sudo sed -i "s|/home/pi/timevox|$INSTALL_DIR|g" "$target_file"
    sudo sed -i "s|/home/timevox/timevox|$INSTALL_DIR|g" "$target_file"
    
    # Définir les permissions
    sudo chmod 644 "$target_file"
    
    print_success "Service shutdown installé: $target_file"
    return 0
}

# Créer un service de mise à jour automatique (optionnel)
create_updater_service() {
    print_status "Création du service de mise à jour automatique..."
    
    # Service de vérification des mises à jour
    local updater_service="/etc/systemd/system/timevox-updater.service"
    
    sudo tee "$updater_service" << EOF >/dev/null
[Unit]
Description=TimeVox Auto-Update Check Service
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=$INSTALL_USER
Group=$INSTALL_USER
Environment=HOME=/home/$INSTALL_USER
WorkingDirectory=$INSTALL_DIR

# Script de vérification automatique des mises à jour
ExecStart=$VENV_DIR/bin/python3 $INSTALL_DIR/scripts/update/check-updates.py --auto

# Ne pas redémarrer automatiquement (oneshot)
Restart=no

StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    # Timer pour exécution quotidienne
    local updater_timer="/etc/systemd/system/timevox-updater.timer"
    
    sudo tee "$updater_timer" << EOF >/dev/null
[Unit]
Description=TimeVox Auto-Update Check Timer
Requires=timevox-updater.service

[Timer]
# Vérifier les mises à jour une fois par jour à 2h du matin
OnCalendar=daily
Persistent=true
RandomizedDelaySec=1h

[Install]
WantedBy=timers.target
EOF
    
    print_success "Service et timer de mise à jour créés"
    return 0
}

# Créer un service de monitoring TimeVox
create_monitoring_service() {
    print_status "Création du service de monitoring..."
    
    # Script de monitoring
    local monitor_script="/home/$INSTALL_USER/timevox_monitor.py"
    
    cat > "$monitor_script" << EOF
#!/usr/bin/env python3
"""
Service de monitoring TimeVox
Surveille l'état du système et redémarre si nécessaire
"""

import time
import subprocess
import sys
import os
import signal
from datetime import datetime

# Configuration
CHECK_INTERVAL = 30  # secondes
MAX_RESTART_ATTEMPTS = 3
RESTART_COOLDOWN = 300  # 5 minutes

class TimeVoxMonitor:
    def __init__(self):
        self.restart_count = 0
        self.last_restart = 0
        self.running = True
        
        # Gérer les signaux
        signal.signal(signal.SIGTERM, self.signal_handler)
        signal.signal(signal.SIGINT, self.signal_handler)
    
    def signal_handler(self, signum, frame):
        print(f"Signal {signum} reçu, arrêt du monitoring...")
        self.running = False
    
    def log(self, message):
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] {message}")
    
    def is_timevox_running(self):
        """Vérifier si TimeVox est en cours d'exécution"""
        try:
            result = subprocess.run(
                ["systemctl", "is-active", "timevox"],
                capture_output=True, text=True
            )
            return result.stdout.strip() == "active"
        except Exception:
            return False
    
    def restart_timevox(self):
        """Redémarrer TimeVox"""
        current_time = time.time()
        
        # Vérifier le cooldown
        if current_time - self.last_restart < RESTART_COOLDOWN:
            self.log("Redémarrage en cooldown, attente...")
            return False
        
        # Vérifier le nombre de redémarrages
        if self.restart_count >= MAX_RESTART_ATTEMPTS:
            self.log(f"Nombre maximum de redémarrages atteint ({MAX_RESTART_ATTEMPTS})")
            return False
        
        try:
            self.log("Redémarrage de TimeVox...")
            subprocess.run(["sudo", "systemctl", "restart", "timevox"], check=True)
            self.restart_count += 1
            self.last_restart = current_time
            self.log(f"TimeVox redémarré (tentative {self.restart_count})")
            return True
        except subprocess.CalledProcessError as e:
            self.log(f"Échec redémarrage TimeVox: {e}")
            return False
    
    def reset_restart_counter(self):
        """Remettre à zéro le compteur de redémarrages si le service fonctionne"""
        if self.restart_count > 0:
            self.log("TimeVox stable, remise à zéro du compteur")
            self.restart_count = 0
    
    def run(self):
        """Boucle principale de monitoring"""
        self.log("Démarrage du monitoring TimeVox")
        stable_checks = 0
        
        while self.running:
            try:
                if self.is_timevox_running():
                    stable_checks += 1
                    
                    # Remettre à zéro après 10 vérifications stables (5 minutes)
                    if stable_checks >= 10:
                        self.reset_restart_counter()
                        stable_checks = 0
                else:
                    self.log("TimeVox n'est pas actif")
                    stable_checks = 0
                    self.restart_timevox()
                
                time.sleep(CHECK_INTERVAL)
                
            except KeyboardInterrupt:
                break
            except Exception as e:
                self.log(f"Erreur monitoring: {e}")
                time.sleep(CHECK_INTERVAL)
        
        self.log("Arrêt du monitoring TimeVox")

if __name__ == "__main__":
    monitor = TimeVoxMonitor()
    monitor.run()
EOF
    
    chmod +x "$monitor_script"
    chown "$INSTALL_USER:$INSTALL_USER" "$monitor_script"
    
    # Service de monitoring
    local monitor_service="/etc/systemd/system/timevox-monitor.service"
    
    sudo tee "$monitor_service" << EOF >/dev/null
[Unit]
Description=TimeVox Monitoring Service
After=timevox.service
Wants=timevox.service

[Service]
Type=simple
User=$INSTALL_USER
Group=$INSTALL_USER
Environment=HOME=/home/$INSTALL_USER
WorkingDirectory=/home/$INSTALL_USER

ExecStart=/usr/bin/python3 $monitor_script

Restart=always
RestartSec=10

StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    print_success "Service de monitoring créé"
    return 0
}

# Configurer les services systemd
configure_systemd_services() {
    print_status "Configuration des services systemd..."
    
    # Recharger la configuration systemd
    print_status "Rechargement de la configuration systemd..."
    sudo systemctl daemon-reload
    
    # Liste des services TimeVox
    services_to_configure=(
        "timevox.service"
        "timevox-shutdown.service"
        "timevox-updater.service"
        "timevox-monitor.service"
    )
    
    # Configurer chaque service
    for service in "${services_to_configure[@]}"; do
        if [ -f "/etc/systemd/system/$service" ]; then
            print_status "Configuration de $service..."
            
            # Activer le service pour démarrage automatique
            if sudo systemctl enable "$service" >/dev/null 2>&1; then
                print_success "$service activé pour démarrage automatique"
            else
                print_warning "Échec activation $service"
            fi
        else
            print_warning "Service $service non trouvé, ignoré"
        fi
    done
    
    # Activer le timer de mise à jour
    if [ -f "/etc/systemd/system/timevox-updater.timer" ]; then
        print_status "Activation du timer de mise à jour..."
        sudo systemctl enable timevox-updater.timer >/dev/null 2>&1
        print_success "Timer de mise à jour activé"
    fi
}

# Tester les services
test_services() {
    print_status "Test des services TimeVox..."
    
    services_to_test=(
        "timevox"
        "timevox-shutdown"
    )
    
    for service in "${services_to_test[@]}"; do
        print_status "Test de $service..."
        
        # Vérifier que le service peut se charger
        if sudo systemctl status "$service" >/dev/null 2>&1; then
            print_success "$service: configuration valide"
        else
            # Essayer de voir l'erreur
            error_output=$(sudo systemctl status "$service" 2>&1 | head -5)
            print_warning "$service: problème de configuration"
            print_warning "Détails: $error_output"
        fi
    done
}

# Créer les scripts de gestion des services
create_service_management_scripts() {
    print_status "Création des scripts de gestion..."
    
    # Script de contrôle des services
    local control_script="/home/$INSTALL_USER/timevox_control.sh"
    
    cat > "$control_script" << EOF
#!/bin/bash
# Script de contrôle des services TimeVox

case "\$1" in
    start)
        echo "Démarrage des services TimeVox..."
        sudo systemctl start timevox timevox-shutdown
        ;;
    stop)
        echo "Arrêt des services TimeVox..."
        sudo systemctl stop timevox timevox-shutdown timevox-monitor
        ;;
    restart)
        echo "Redémarrage des services TimeVox..."
        sudo systemctl restart timevox timevox-shutdown
        ;;
    status)
        echo "=== Statut des services TimeVox ==="
        sudo systemctl status timevox --no-pager -l
        echo ""
        sudo systemctl status timevox-shutdown --no-pager -l
        ;;
    logs)
        echo "=== Logs TimeVox (Ctrl+C pour quitter) ==="
        sudo journalctl -u timevox -f
        ;;
    enable)
        echo "Activation démarrage automatique..."
        sudo systemctl enable timevox timevox-shutdown timevox-monitor
        ;;
    disable)
        echo "Désactivation démarrage automatique..."
        sudo systemctl disable timevox timevox-shutdown timevox-monitor
        ;;
    *)
        echo "Usage: \$0 {start|stop|restart|status|logs|enable|disable}"
        echo ""
        echo "Commandes disponibles:"
        echo "  start   - Démarrer TimeVox"
        echo "  stop    - Arrêter TimeVox"
        echo "  restart - Redémarrer TimeVox"
        echo "  status  - Voir le statut"
        echo "  logs    - Voir les logs en temps réel"
        echo "  enable  - Activer démarrage automatique"
        echo "  disable - Désactiver démarrage automatique"
        exit 1
        ;;
esac
EOF
    
    chmod +x "$control_script"
    chown "$INSTALL_USER:$INSTALL_USER" "$control_script"
    print_success "Script de contrôle créé: $control_script"
    
    # Créer des alias pratiques
    local bashrc_addition="/home/$INSTALL_USER/.bashrc_timevox"
    
    cat > "$bashrc_addition" << EOF
# Alias TimeVox
alias tvx-start='~/timevox_control.sh start'
alias tvx-stop='~/timevox_control.sh stop'
alias tvx-restart='~/timevox_control.sh restart'
alias tvx-status='~/timevox_control.sh status'
alias tvx-logs='~/timevox_control.sh logs'
EOF
    
    # Ajouter à .bashrc s'il n'y est pas déjà
    if ! grep -q "bashrc_timevox" "/home/$INSTALL_USER/.bashrc"; then
        echo "source ~/.bashrc_timevox" >> "/home/$INSTALL_USER/.bashrc"
        print_success "Alias TimeVox ajoutés à .bashrc"
    fi
    
    chown "$INSTALL_USER:$INSTALL_USER" "$bashrc_addition"
}

# Fonction principale
main() {
    print_status "=== Installation des services TimeVox ==="
    
    # Vérifications préalables
    if ! check_service_prerequisites; then
        return 1
    fi
    
    # Installation des services
    install_timevox_service
    install_shutdown_service
    
    # Services additionnels
    create_updater_service
    create_monitoring_service
    
    # Configuration systemd
    configure_systemd_services
    
    # Tests
    test_services
    
    # Scripts de gestion
    create_service_management_scripts
    
    print_success "=== Installation des services terminée ==="
    echo ""
    print_status "Services installés:"
    print_status "  - timevox.service (service principal)"
    print_status "  - timevox-shutdown.service (bouton d'arrêt)"
    print_status "  - timevox-updater.service + timer (mises à jour)"
    print_status "  - timevox-monitor.service (surveillance)"
    echo ""
    print_status "Scripts de gestion:"
    print_status "  - ~/timevox_control.sh (contrôle services)"
    print_status "  - Alias: tvx-start, tvx-stop, tvx-status, tvx-logs"
    echo ""
    print_warning "Les services sont configurés mais PAS ENCORE DÉMARRÉS"
    print_warning "Utilisez: ~/timevox_control.sh start"
    print_warning "Ou attendez le redémarrage pour démarrage automatique"
    echo ""
    
    return 0
}

# Exécution si script appelé directement
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi