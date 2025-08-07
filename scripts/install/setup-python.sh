#!/bin/bash
# setup-python.sh - Configuration de l'environnement Python pour TimeVox

set -e

# Variables
SCRIPT_NAME="setup-python.sh"
LOG_FILE="/tmp/timevox_install.log"
INSTALL_USER="timevox"
INSTALL_DIR="/home/$INSTALL_USER/timevox"
VENV_DIR="/home/$INSTALL_USER/timevox_env"
REQUIREMENTS_FILE="$INSTALL_DIR/timevox/requirements.txt"

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
    echo -e "${BLUE}[PYTHON]${NC} $1"
    log "$1"
}

print_success() {
    echo -e "${GREEN}[PYTHON]${NC} $1"
    log "SUCCESS: $1"
}

print_error() {
    echo -e "${RED}[PYTHON]${NC} $1"
    log "ERROR: $1"
}

print_warning() {
    echo -e "${YELLOW}[PYTHON]${NC} $1"
    log "WARNING: $1"
}

# Vérifier la version de Python
check_python_version() {
    print_status "Vérification de la version Python..."
    
    if ! command -v python3 >/dev/null 2>&1; then
        print_error "Python3 non trouvé"
        return 1
    fi
    
    # Récupérer la version Python
    python_version=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    python_full_version=$(python3 --version)
    
    print_success "Python détecté: $python_full_version"
    
    # Vérifier version minimale (3.7+)
    if python3 -c "import sys; sys.exit(0 if sys.version_info >= (3,7) else 1)"; then
        print_success "Version Python compatible (≥ 3.7)"
    else
        print_error "Version Python trop ancienne. Requis: Python 3.7+"
        print_error "Trouvé: $python_full_version"
        return 1
    fi
    
    return 0
}

# Créer l'environnement virtuel
create_virtual_environment() {
    print_status "Création de l'environnement virtuel..."
    
    # Installer les dépendances système AVANT de créer le venv
    print_status "Installation des paquets système nécessaires (pygame, pillow, luma...)"
    sudo apt-get update
    sudo apt-get install -y \
        libsdl2-dev \
        libsdl2-image-dev \
        libsdl2-mixer-dev \
        libsdl2-ttf-dev \
        libportmidi-dev \
        libporttime-dev \
        libjpeg-dev \
        libfreetype6-dev \
        python3-dev \
        libopenjp2-7 \
        zlib1g-dev \
        libtiff5 \
        libatlas-base-dev
	
    if [ $? -eq 0 ]; then
        print_success "Dépendances système installées"
    else
        print_error "Échec installation des paquets système"
        return 1
    fi
	
    # Supprimer l'ancien environnement s'il existe
    if [ -d "$VENV_DIR" ]; then
        print_warning "Environnement virtuel existant détecté"
        print_status "Suppression de l'ancien environnement..."
        rm -rf "$VENV_DIR"
    fi
    
    # Créer le nouvel environnement
    print_status "Création nouvel environnement: $VENV_DIR"
    if python3 -m venv "$VENV_DIR"; then
        print_success "Environnement virtuel créé"
    else
        print_error "Échec création environnement virtuel"
        return 1
    fi
    
    # Vérifier que l'environnement fonctionne
    if [ -f "$VENV_DIR/bin/activate" ]; then
        print_success "Environnement virtuel opérationnel"
        
        # Tester l'activation
        source "$VENV_DIR/bin/activate"
        if [ "$VIRTUAL_ENV" = "$VENV_DIR" ]; then
            print_success "Activation de l'environnement réussie"
        else
            print_error "Problème d'activation de l'environnement"
            return 1
        fi
    else
        print_error "Environnement virtuel défaillant"
        return 1
    fi
    
    return 0
}

# Mettre à jour pip et setuptools
upgrade_pip() {
    print_status "Mise à jour de pip et setuptools..."
    
    source "$VENV_DIR/bin/activate"
    
    # Mettre à jour pip
    if pip install --upgrade pip >/dev/null 2>&1; then
        print_success "pip mis à jour"
    else
        print_warning "Échec mise à jour pip (continuation possible)"
    fi
    
    # Mettre à jour setuptools et wheel
    if pip install --upgrade setuptools wheel >/dev/null 2>&1; then
        print_success "setuptools et wheel mis à jour"
    else
        print_warning "Échec mise à jour setuptools/wheel (continuation possible)"
    fi
    
    # Afficher la version de pip
    pip_version=$(pip --version)
    print_status "Version pip: $pip_version"
}

# Installer les dépendances Python depuis requirements.txt
install_python_dependencies() {
    print_status "Installation des dépendances Python..."
    
    # Vérifier que le fichier requirements.txt existe
    if [ ! -f "$REQUIREMENTS_FILE" ]; then
        print_error "Fichier requirements.txt non trouvé: $REQUIREMENTS_FILE"
        return 1
    fi
    
    print_status "Fichier requirements trouvé: $REQUIREMENTS_FILE"
    
    # Afficher le contenu du fichier requirements
    print_status "Dépendances à installer:"
    while IFS= read -r line; do
        # Ignorer les lignes vides et commentaires
        if [[ "$line" =~ ^[[:space:]]*$ ]] || [[ "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        print_status "  - $line"
    done < "$REQUIREMENTS_FILE"
    
    source "$VENV_DIR/bin/activate"
    
    # Installer les dépendances avec timeout et retry
    print_status "Installation en cours (cela peut prendre plusieurs minutes)..."
    
    # Variables pour retry
    max_attempts=3
    attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        print_status "Tentative $attempt/$max_attempts..."
        
        if timeout 600 pip install -r "$REQUIREMENTS_FILE" --no-cache-dir; then
            print_success "Toutes les dépendances installées avec succès"
            break
        else
            exit_code=$?
            if [ $exit_code -eq 124 ]; then
                print_error "Timeout lors de l'installation (tentative $attempt)"
            else
                print_error "Échec installation (tentative $attempt, code: $exit_code)"
            fi
            
            if [ $attempt -eq $max_attempts ]; then
                print_error "Échec définitif après $max_attempts tentatives"
                return 1
            fi
            
            attempt=$((attempt + 1))
            print_warning "Nouvelle tentative dans 5 secondes..."
            sleep 5
        fi
    done
    
    return 0
}

# Installation manuelle des dépendances critiques une par une
install_critical_dependencies() {
    print_status "Installation manuelle des dépendances critiques..."
    
    source "$VENV_DIR/bin/activate"
    
    # Liste des dépendances critiques dans l'ordre d'installation
    critical_deps=(
        "setuptools>=45.0"
        "wheel"
        "Pillow>=9.5.0"          # Pour l'OLED (dépend des libs système)
        "RPi.GPIO==0.7.1"        # GPIO Raspberry Pi
        "smbus2==0.4.2"          # I2C pour OLED
        "luma.core==2.4.2"       # Base pour OLED
        "luma.oled==3.12.0"      # Driver OLED
        "pygame==2.1.0"          # Audio
        "pydub==0.25.1"          # Traitement audio
    )
    
    failed_deps=()
    
    for dep in "${critical_deps[@]}"; do
        print_status "Installation de $dep..."
        
        if timeout 120 pip install "$dep" --no-cache-dir >/dev/null 2>&1; then
            print_success "$dep installé"
        else
            print_error "Échec installation de $dep"
            failed_deps+=("$dep")
        fi
    done
    
    # Rapport des échecs
    if [ ${#failed_deps[@]} -gt 0 ]; then
        print_error "Dépendances échouées:"
        for dep in "${failed_deps[@]}"; do
            print_error "  - $dep"
        done
        print_warning "Ces échecs peuvent empêcher TimeVox de fonctionner"
        return 1
    else
        print_success "Toutes les dépendances critiques installées"
        return 0
    fi
}

# Tester l'importation des modules Python
test_python_imports() {
    print_status "Test d'importation des modules Python..."
    
    source "$VENV_DIR/bin/activate"
    
    # Liste des modules à tester
    modules_to_test=(
        "RPi.GPIO"
        "pygame"
        "pydub"
        "PIL"
        "luma.oled.device"
        "luma.core.render"
        "smbus2"
    )
    
    failed_imports=()
    
    for module in "${modules_to_test[@]}"; do
        print_status "Test import: $module"
        
        if python3 -c "import $module" 2>/dev/null; then
            print_success "$module importé avec succès"
        else
            print_error "Échec import: $module"
            failed_imports+=("$module")
        fi
    done
    
    # Rapport final
    if [ ${#failed_imports[@]} -gt 0 ]; then
        print_error "Modules non importables:"
        for module in "${failed_imports[@]}"; do
            print_error "  - $module"
        done
        print_warning "Vérifiez les logs ci-dessus pour les détails"
        return 1
    else
        print_success "Tous les modules Python importés avec succès"
        return 0
    fi
}

# Créer un script d'activation rapide
create_activation_script() {
    print_status "Création du script d'activation..."
    
    activation_script="/home/$INSTALL_USER/activate_timevox.sh"
    
    cat > "$activation_script" << EOF
#!/bin/bash
# Script d'activation de l'environnement TimeVox
# Usage: source ~/activate_timevox.sh

if [ -f "$VENV_DIR/bin/activate" ]; then
    source "$VENV_DIR/bin/activate"
    echo "Environnement TimeVox activé"
    echo "Python: \$(which python3)"
    echo "Pip: \$(which pip)"
    cd "$INSTALL_DIR"
else
    echo "Erreur: Environnement virtuel non trouvé"
    echo "Chemin attendu: $VENV_DIR/bin/activate"
fi
EOF
    
    chmod +x "$activation_script"
    chown "$INSTALL_USER:$INSTALL_USER" "$activation_script"
    
    print_success "Script d'activation créé: $activation_script"
}

# Fonction principale
main() {
    print_status "=== Configuration de l'environnement Python ==="
    
    # Vérifications préalables
    if ! check_python_version; then
        return 1
    fi
    
    # Création de l'environnement virtuel
    if ! create_virtual_environment; then
        return 1
    fi
    
    # Mise à jour de pip
    upgrade_pip
    
    # Installation des dépendances
    print_status "Tentative d'installation depuis requirements.txt..."
    if install_python_dependencies; then
        print_success "Installation requirements.txt réussie"
    else
        print_warning "Échec installation requirements.txt"
        print_status "Tentative d'installation manuelle des dépendances critiques..."
        
        if install_critical_dependencies; then
            print_success "Installation manuelle réussie"
        else
            print_error "Échec installation manuelle"
            return 1
        fi
    fi
    
    # Tests d'importation
    if test_python_imports; then
        print_success "Tous les tests d'importation réussis"
    else
        print_warning "Certains modules ne s'importent pas correctement"
        print_warning "TimeVox pourrait ne pas fonctionner complètement"
    fi
    
    # Créer le script d'activation
    create_activation_script
    
    # Résumé final
    print_success "=== Configuration Python terminée ==="
    echo ""
    print_status "Environnement virtuel: $VENV_DIR"
    print_status "Script d'activation: /home/$INSTALL_USER/activate_timevox.sh"
    print_status "Pour activer manuellement: source $VENV_DIR/bin/activate"
    echo ""
    
    return 0
}

# Exécution si script appelé directement
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi