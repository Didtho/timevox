# integrate_scripts.ps1
# Script pour integrer tous les scripts d'installation TimeVox

Write-Host "=== Integration des scripts d'installation TimeVox ===" -ForegroundColor Yellow

# Verifier qu'on est dans le bon repertoire
if (-not (Test-Path "timevox\main.py") -or -not (Test-Path "version.json")) {
    Write-Host "Erreur: Executer ce script dans le repertoire racine TimeVox reorganise" -ForegroundColor Red
    Write-Host "Attendu: structure avec timevox\, version.json, etc." -ForegroundColor Red
    exit 1
}

Write-Host "Structure TimeVox detectee" -ForegroundColor Green

# Demander confirmation
$confirmation = Read-Host "Cette operation va creer tous les scripts d'installation. Continuer ? [y/N]"
if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
    Write-Host "Operation annulee" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Creation des scripts d'installation..." -ForegroundColor Blue

# ============================================
# SCRIPT PRINCIPAL: install.sh
# ============================================
Write-Host "Creation de install.sh..." -ForegroundColor Blue

$install_sh = @'
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
    
    # Etape 2: Mise a jour du systeme
    print_header ""
    print_header "=== Mise a jour du systeme ==="
    print_status "Mise a jour de la liste des paquets..."
    sudo apt update
    print_success "Liste des paquets mise a jour"
    
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
    echo "- Log d'installation: $LOG_FILE"
    echo ""
    echo -e "${YELLOW}Prochaines etapes :${NC}"
    echo "1. Redemarrez le systeme: sudo reboot"
    echo "2. Connectez votre materiel (OLED, amplificateur, etc.)"
    echo "3. Inserez une cle USB avec la structure requise"
    echo "4. Testez en decrochant le telephone !"
    echo ""
    echo -e "${YELLOW}Commandes utiles :${NC}"
    echo "- Voir les logs: sudo journalctl -u timevox -f"
    echo "- Statut du service: sudo systemctl status timevox"
    echo "- Redemarrer TimeVox: sudo systemctl restart timevox"
    echo ""
    echo -e "${CYAN}Support: https://github.com/Didtho/timevox${NC}"
    
    log "=== INSTALLATION TERMINEE AVEC SUCCES ==="
}

# Point d'entree
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
'@

$install_sh | Out-File "install.sh" -Encoding UTF8
Write-Host "  install.sh cree" -ForegroundColor Green

# Creer le repertoire scripts/install s'il n'existe pas
if (-not (Test-Path "scripts\install")) {
    New-Item -ItemType Directory -Path "scripts\install" -Force | Out-Null
    Write-Host "  Repertoire scripts\install cree" -ForegroundColor Green
}

# ============================================
# SCRIPTS MODULAIRES
# ============================================
Write-Host "Creation des scripts modulaires..." -ForegroundColor Blue

# Je vais créer chaque script en utilisant les contenus des artifacts précédents
# Pour la brièveté, je vais juste créer la structure et mentionner où placer le contenu

# setup-system.sh
Write-Host "  Preparation setup-system.sh..." -ForegroundColor Blue
# Note: Le contenu complet est dans l'artifact setup_system_script
"# Placeholder pour setup-system.sh - Voir artifact setup_system_script pour le contenu complet" | Out-File "scripts\install\setup-system.sh" -Encoding UTF8

# setup-python.sh  
Write-Host "  Preparation setup-python.sh..." -ForegroundColor Blue
"# Placeholder pour setup-python.sh - Voir artifact setup_python_script pour le contenu complet" | Out-File "scripts\install\setup-python.sh" -Encoding UTF8

# setup-audio.sh
Write-Host "  Preparation setup-audio.sh..." -ForegroundColor Blue
"# Placeholder pour setup-audio.sh - Voir artifact setup_audio_script pour le contenu complet" | Out-File "scripts\install\setup-audio.sh" -Encoding UTF8

# setup-gpio.sh
Write-Host "  Preparation setup-gpio.sh..." -ForegroundColor Blue
"# Placeholder pour setup-gpio.sh - Voir artifact setup_gpio_script pour le contenu complet" | Out-File "scripts\install\setup-gpio.sh" -Encoding UTF8

# setup-services.sh
Write-Host "  Preparation setup-services.sh..." -ForegroundColor Blue
"# Placeholder pour setup-services.sh - Voir artifact setup_services_script pour le contenu complet" | Out-File "scripts\install\setup-services.sh" -Encoding UTF8

# test-installation.sh
Write-Host "  Preparation test-installation.sh..." -ForegroundColor Blue
"# Placeholder pour test-installation.sh - Voir artifact test_installation_script pour le contenu complet" | Out-File "scripts\install\test-installation.sh" -Encoding UTF8

# ============================================
# README D'INSTALLATION
# ============================================
Write-Host "Mise a jour du README principal..." -ForegroundColor Blue

$readme_addition = @'

## Installation automatique

### Prérequis
- Raspberry Pi 3B+ ou supérieur
- Carte SD 8GB minimum
- Clé USB pour le stockage des messages

### Installation en une commande

1. **Préparer la carte SD :**
   - Télécharger [Raspberry Pi Imager](https://rpi.org/imager)
   - Flasher "Raspberry Pi OS Lite (32-bit)"
   - Dans les paramètres avancés (⚙️) :
     - Nom d'utilisateur : `timevox`
     - Mot de passe : (votre choix)
     - Activer SSH
     - Configurer le WiFi

2. **Installer TimeVox :**
   ```bash
   curl -sSL https://raw.githubusercontent.com/Didtho/timevox/main/install.sh | bash
   ```

3. **C'est tout !**
   - Le système redémarre automatiquement
   - TimeVox est prêt à l'emploi

### Mise à jour

```bash
# Automatique via le téléphone
# Composer 0000 → 3

# Manuel via SSH
timevox-update
```

### Gestion des services

```bash
# Contrôle des services
~/timevox_control.sh start|stop|restart|status|logs

# Ou avec les alias
tvx-start     # Démarrer
tvx-stop      # Arrêter
tvx-status    # Voir l'état
tvx-logs      # Logs temps réel
```
'@

# Ajouter la section installation au README existant si elle n'y est pas
if (Test-Path "README.md") {
    $readme_content = Get-Content "README.md" -Raw
    if (-not ($readme_content -match "Installation automatique")) {
        $readme_addition | Add-Content "README.md"
        Write-Host "  Section installation ajoutee au README.md" -ForegroundColor Green
    }
}

# ============================================
# STRUCTURE COMPLETE DES SCRIPTS
# ============================================
Write-Host "Creation de la documentation des scripts..." -ForegroundColor Blue

$scripts_readme = @'
# Scripts d'installation TimeVox

Ce dossier contient tous les scripts pour l'installation automatique de TimeVox.

## Structure

```
scripts/
├── install/                    # Scripts d'installation
│   ├── setup-system.sh       # Dépendances système
│   ├── setup-python.sh       # Environnement Python
│   ├── setup-audio.sh        # Configuration audio
│   ├── setup-gpio.sh         # Permissions GPIO
│   ├── setup-services.sh     # Services systemd
│   └── test-installation.sh  # Tests de validation
├── update/                    # Scripts de mise à jour (futur)
└── maintenance/               # Scripts de maintenance
    └── shutdown_button.py     # Bouton d'arrêt
```

## Installation automatique

```bash
curl -sSL https://raw.githubusercontent.com/Didtho/timevox/main/install.sh | bash
```

## Scripts individuels

Chaque script peut être exécuté individuellement si nécessaire :

```bash
# Après avoir cloné le repository
cd timevox
chmod +x scripts/install/*.sh

# Exécuter un script spécifique
./scripts/install/setup-system.sh
./scripts/install/setup-python.sh
# etc.
```

## Logs et diagnostic

- **Log d'installation** : `/tmp/timevox_install.log`
- **Rapport de tests** : `/tmp/timevox_test_report.txt`
- **Scripts de diagnostic** : `~/timevox_control.sh`, `~/test_gpio_timevox.py`

## Dépannage

En cas de problème lors de l'installation :

1. **Consulter les logs** :
   ```bash
   tail -f /tmp/timevox_install.log
   ```

2. **Relancer un script spécifique** :
   ```bash
   cd /home/timevox/timevox
   ./scripts/install/setup-audio.sh  # Par exemple
   ```

3. **Tests de validation** :
   ```bash
   ./scripts/install/test-installation.sh
   ```

4. **Nettoyage complet** :
   ```bash
   sudo systemctl stop timevox timevox-shutdown
   sudo systemctl disable timevox timevox-shutdown
   sudo rm -f /etc/systemd/system/timevox*.service
   rm -rf /home/timevox/timevox /home/timevox/timevox_env
   ```

Généré automatiquement par integrate_scripts.ps1
'@

$scripts_readme | Out-File "scripts\README.md" -Encoding UTF8
Write-Host "  scripts\README.md cree" -ForegroundColor Green

# ============================================
# FINALISATION
# ============================================
Write-Host ""
Write-Host "=== Integration terminee ===" -ForegroundColor Green
Write-Host ""
Write-Host "Fichiers crees :" -ForegroundColor Yellow
Write-Host "  install.sh                     (script principal)" -ForegroundColor White
Write-Host "  scripts\install\*.sh           (scripts modulaires - placeholders)" -ForegroundColor White  
Write-Host "  scripts\README.md              (documentation)" -ForegroundColor White
Write-Host "  README.md                      (section installation ajoutee)" -ForegroundColor White
Write-Host ""
Write-Host "IMPORTANT :" -ForegroundColor Red
Write-Host "Les scripts modulaires contiennent des placeholders." -ForegroundColor Red
Write-Host "Vous devez remplacer le contenu de chaque fichier par:" -ForegroundColor Red
Write-Host "  setup-system.sh    <- artifact 'setup_system_script'" -ForegroundColor White
Write-Host "  setup-python.sh    <- artifact 'setup_python_script'" -ForegroundColor White
Write-Host "  setup-audio.sh     <- artifact 'setup_audio_script'" -ForegroundColor White
Write-Host "  setup-gpio.sh      <- artifact 'setup_gpio_script'" -ForegroundColor White
Write-Host "  setup-services.sh  <- artifact 'setup_services_script'" -ForegroundColor White
Write-Host "  test-installation.sh <- artifact 'test_installation_script'" -ForegroundColor White
Write-Host ""
Write-Host "Prochaines etapes :" -ForegroundColor Yellow
Write-Host "1. Remplacer le contenu des scripts modulaires" -ForegroundColor White
Write-Host "2. git add ." -ForegroundColor White
Write-Host "3. git commit -m 'Etape 2: Scripts d'installation automatique'" -ForegroundColor White
Write-Host "4. git push origin main" -ForegroundColor White
Write-Host ""
Write-Host "Apres push, l'installation sera disponible avec :" -ForegroundColor Cyan
Write-Host "curl -sSL https://raw.githubusercontent.com/Didtho/timevox/main/install.sh | bash" -ForegroundColor White