#!/bin/bash
# test-installation.sh - Tests de validation complète de l'installation TimeVox

set -e

# Variables
SCRIPT_NAME="test-installation.sh"
LOG_FILE="/tmp/timevox_install.log"
INSTALL_USER="timevox"
INSTALL_DIR="/home/$INSTALL_USER/timevox"
VENV_DIR="/home/$INSTALL_USER/timevox_env"
TEST_REPORT="/tmp/timevox_test_report.txt"

# Compteurs de tests
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
WARNING_TESTS=0

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Fonction de logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [$SCRIPT_NAME] $1" | tee -a "$LOG_FILE"
}

print_test_header() {
    echo -e "${CYAN}=== $1 ===${NC}"
    echo "=== $1 ===" >> "$TEST_REPORT"
    log "TEST SECTION: $1"
}

print_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
    echo "[TEST] $1" >> "$TEST_REPORT"
    log "TEST: $1"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    echo "[PASS] $1" >> "$TEST_REPORT"
    log "PASS: $1"
    PASSED_TESTS=$((PASSED_TESTS + 1))
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    echo "[FAIL] $1" >> "$TEST_REPORT"
    log "FAIL: $1"
    FAILED_TESTS=$((FAILED_TESTS + 1))
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    echo "[WARN] $1" >> "$TEST_REPORT"
    log "WARN: $1"
    WARNING_TESTS=$((WARNING_TESTS + 1))
}

# Initialiser le rapport de test
init_test_report() {
    echo "TimeVox Installation Test Report" > "$TEST_REPORT"
    echo "Generated: $(date)" >> "$TEST_REPORT"
    echo "User: $INSTALL_USER" >> "$TEST_REPORT"
    echo "Installation Directory: $INSTALL_DIR" >> "$TEST_REPORT"
    echo "" >> "$TEST_REPORT"
}

# Test 1: Vérification de l'utilisateur et des permissions
test_user_permissions() {
    print_test_header "Test utilisateur et permissions"
    
    # Test utilisateur timevox
    print_test "Vérification utilisateur timevox"
    if id "$INSTALL_USER" >/dev/null 2>&1; then
        print_pass "Utilisateur $INSTALL_USER existe"
    else
        print_fail "Utilisateur $INSTALL_USER non trouvé"
        return 1
    fi
    
    # Test groupes requis
    required_groups=("gpio" "audio" "i2c")
    for group in "${required_groups[@]}"; do
        print_test "Vérification groupe $group"
        if groups "$INSTALL_USER" | grep -q "$group"; then
            print_pass "Utilisateur dans le groupe $group"
        else
            print_fail "Utilisateur pas dans le groupe $group"
        fi
    done
    
    # Test permissions répertoires
    print_test "Permissions répertoire d'installation"
    if [ -d "$INSTALL_DIR" ] && [ -r "$INSTALL_DIR" ] && [ -x "$INSTALL_DIR" ]; then
        print_pass "Répertoire d'installation accessible"
    else
        print_fail "Problème d'accès au répertoire d'installation"
    fi
    
    return 0
}

# Test 2: Installation des fichiers
test_file_installation() {
    print_test_header "Test installation des fichiers"
    
    # Fichiers Python essentiels
    essential_files=(
        "$INSTALL_DIR/timevox/main.py"
        "$INSTALL_DIR/timevox/phone_controller.py"
        "$INSTALL_DIR/timevox/audio_manager.py"
        "$INSTALL_DIR/timevox/gpio_manager.py"
        "$INSTALL_DIR/timevox/config.py"
        "$INSTALL_DIR/version.json"
    )
    
    for file in "${essential_files[@]}"; do
        print_test "Vérification fichier $(basename "$file")"
        if [ -f "$file" ] && [ -r "$file" ]; then
            print_pass "Fichier présent et lisible: $(basename "$file")"
        else
            print_fail "Fichier manquant ou inaccessible: $file"
        fi
    done
    
    # Scripts d'installation
    print_test "Scripts d'installation présents"
    if [ -d "$INSTALL_DIR/scripts/install" ] && [ "$(ls -A "$INSTALL_DIR/scripts/install")" ]; then
        print_pass "Scripts d'installation présents"
    else
        print_warning "Scripts d'installation manquants"
    fi
    
    # Configuration
    print_test "Fichiers de configuration"
    if [ -d "$INSTALL_DIR/configs" ] && [ "$(ls -A "$INSTALL_DIR/configs")" ]; then
        print_pass "Fichiers de configuration présents"
    else
        print_warning "Fichiers de configuration manquants"
    fi
    
    return 0
}

# Test 3: Environnement Python
test_python_environment() {
    print_test_header "Test environnement Python"
    
    # Test environnement virtuel
    print_test "Environnement virtuel Python"
    if [ -f "$VENV_DIR/bin/python3" ] && [ -x "$VENV_DIR/bin/python3" ]; then
        print_pass "Environnement virtuel présent et exécutable"
    else
        print_fail "Environnement virtuel manquant ou défaillant"
        return 1
    fi
    
    # Test version Python
    print_test "Version Python"
    python_version=$("$VENV_DIR/bin/python3" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')" 2>/dev/null)
    if [ $? -eq 0 ]; then
        print_pass "Python version: $python_version"
    else
        print_fail "Impossible de déterminer la version Python"
    fi
    
    # Test modules Python critiques
    critical_modules=(
        "RPi.GPIO"
        "pygame"
        "pydub"
        "PIL"
        "luma.oled.device"
        "smbus2"
    )
    
    for module in "${critical_modules[@]}"; do
        print_test "Module Python: $module"
        if "$VENV_DIR/bin/python3" -c "import $module" 2>/dev/null; then
            print_pass "Module $module importable"
        else
            print_fail "Module $module non importable"
        fi
    done
    
    return 0
}

# Test 4: Configuration système
test_system_configuration() {
    print_test_header "Test configuration système"
    
    # Test I2C
    print_test "Configuration I2C"
    if lsmod | grep -q i2c_bcm2835; then
        print_pass "Module I2C chargé"
    else
        print_warning "Module I2C non chargé (redémarrage requis?)"
    fi
    
    if [ -c /dev/i2c-1 ]; then
        print_pass "Périphérique I2C présent"
    else
        print_warning "Périphérique I2C non trouvé"
    fi
    
    # Test audio
    print_test "Configuration audio"
    if command -v aplay >/dev/null 2>&1; then
        card_count=$(aplay -l 2>/dev/null | grep -c "^card" || echo "0")
        if [ "$card_count" -gt 0 ]; then
            print_pass "Cartes audio détectées: $card_count"
        else
            print_warning "Aucune carte audio détectée"
        fi
    else
        print_fail "Commande aplay non disponible"
    fi
    
    # Test GPIO
    print_test "Accès GPIO"
    if [ -c /dev/gpiomem ]; then
        print_pass "Périphérique GPIO accessible"
    else
        print_fail "Périphérique GPIO non accessible"
    fi
    
    # Test configuration boot
    print_test "Configuration boot (config.txt)"
    boot_configs=("dtparam=i2s=on" "dtparam=i2c_arm=on")
    for config in "${boot_configs[@]}"; do
        if grep -q "$config" /boot/config.txt 2>/dev/null; then
            print_pass "Configuration boot: $config"
        else
            print_warning "Configuration boot manquante: $config"
        fi
    done
    
    return 0
}

# Test 5: Services systemd
test_systemd_services() {
    print_test_header "Test services systemd"
    
    # Services TimeVox
    timevox_services=(
        "timevox.service"
        "timevox-shutdown.service"
    )
    
    for service in "${timevox_services[@]}"; do
        print_test "Service: $service"
        
        # Vérifier que le fichier de service existe
        if [ -f "/etc/systemd/system/$service" ]; then
            print_pass "Fichier service présent: $service"
            
            # Vérifier que le service peut se charger
            if systemctl cat "$service" >/dev/null 2>&1; then
                print_pass "Service valide: $service"
                
                # Vérifier s'il est activé
                if systemctl is-enabled "$service" >/dev/null 2>&1; then
                    print_pass "Service activé: $service"
                else
                    print_warning "Service non activé: $service"
                fi
            else
                print_fail "Service invalide: $service"
            fi
        else
            print_fail "Fichier service manquant: $service"
        fi
    done
    
    return 0
}

# Test 6: Test de démarrage TimeVox (sans hardware)
test_timevox_startup() {
    print_test_header "Test démarrage TimeVox"
    
    print_test "Test d'import des modules TimeVox"
    
    # Tester l'import du module principal
    if cd "$INSTALL_DIR/timevox" && "$VENV_DIR/bin/python3" -c "
import sys
import os
sys.path.insert(0, '.')

try:
    import config
    print('Config OK')
    
    import gpio_manager
    print('GPIO Manager OK')
    
    import audio_manager
    print('Audio Manager importable')
    
    import display_manager  
    print('Display Manager importable')
    
    # Test création des gestionnaires (sans hardware)
    from gpio_manager import GPIOManager
    print('GPIOManager classe OK')
    
except Exception as e:
    print(f'Erreur: {e}')
    sys.exit(1)
" 2>/dev/null; then
        print_pass "Modules TimeVox importables sans erreur"
    else
        print_fail "Erreur d'import des modules TimeVox"
    fi
    
    # Test configuration
    print_test "Test configuration TimeVox"
    if cd "$INSTALL_DIR/timevox" && "$VENV_DIR/bin/python3" -c "
import config
info = config.get_project_info()
print(f'Version: {info.get(\"version\", \"N/A\")}')
print(f'Base dir: {info[\"base_dir\"]}')
" 2>/dev/null; then
        print_pass "Configuration TimeVox valide"
    else
        print_fail "Problème de configuration TimeVox"
    fi
    
    return 0
}

# Test 7: Hardware et périphériques (tests non-destructifs)
test_hardware_detection() {
    print_test_header "Test détection hardware"
    
    # Test OLED I2C
    print_test "Détection OLED I2C"
    if command -v i2cdetect >/dev/null 2>&1; then
        # Scanner I2C de manière non-destructive
        if i2cdetect -y 1 2>/dev/null | grep -q "3c"; then
            print_pass "OLED SH1106 détecté à l'adresse 0x3C"
        else
            print_warning "OLED non détecté (vérifiez les connexions)"
        fi
    else
        print_warning "i2cdetect non disponible"
    fi
    
    # Test microphone USB
    print_test "Détection microphone USB"
    if command -v arecord >/dev/null 2>&1; then
        usb_mics=$(arecord -l 2>/dev/null | grep -c "USB" || echo "0")
        if [ "$usb_mics" -gt 0 ]; then
            print_pass "Microphones USB détectés: $usb_mics"
        else
            print_warning "Aucun microphone USB détecté"
        fi
    else
        print_warning "arecord non disponible"
    fi
    
    # Test RTC (optionnel)
    print_test "Détection module RTC"
    if [ -c /dev/rtc0 ]; then
        print_pass "Module RTC détecté"
    else
        print_warning "Module RTC non détecté (optionnel)"
    fi
    
    return 0
}

# Test 8: Scripts et outils
test_scripts_and_tools() {
    print_test_header "Test scripts et outils"
    
    # Scripts de gestion
    management_scripts=(
        "/home/$INSTALL_USER/timevox_control.sh"
        "/home/$INSTALL_USER/test_gpio_timevox.py"
    )
    
    for script in "${management_scripts[@]}"; do
        print_test "Script: $(basename "$script")"
        if [ -f "$script" ] && [ -x "$script" ]; then
            print_pass "Script présent et exécutable: $(basename "$script")"
        else
            print_warning "Script manquant: $(basename "$script")"
        fi
    done
    
    # Alias bash
    print_test "Alias TimeVox dans .bashrc"
    if grep -q "bashrc_timevox" "/home/$INSTALL_USER/.bashrc" 2>/dev/null; then
        print_pass "Alias TimeVox configurés"
    else
        print_warning "Alias TimeVox non configurés"
    fi
    
    return 0
}

# Test 9: Espace disque et performance
test_system_resources() {
    print_test_header "Test ressources système"
    
    # Espace disque
    print_test "Espace disque disponible"
    available_space=$(df / | awk 'NR==2 {print $4}')
    available_gb=$((available_space / 1024 / 1024))
    if [ "$available_gb" -gt 1 ]; then
        print_pass "Espace disque suffisant: ${available_gb}GB disponibles"
    else
        print_warning "Espace disque faible: ${available_gb}GB disponibles"
    fi
    
    # Mémoire
    print_test "Mémoire système"
    total_mem=$(free -m | awk 'NR==2{print $2}')
    if [ "$total_mem" -gt 400 ]; then
        print_pass "Mémoire suffisante: ${total_mem}MB"
    else
        print_warning "Mémoire limitée: ${total_mem}MB"
    fi
    
    # Temperature (Raspberry Pi)
    print_test "Température CPU"
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        temp_raw=$(cat /sys/class/thermal/thermal_zone0/temp)
        temp_celsius=$((temp_raw / 1000))
        if [ "$temp_celsius" -lt 70 ]; then
            print_pass "Température CPU normale: ${temp_celsius}°C"
        else
            print_warning "Température CPU élevée: ${temp_celsius}°C"
        fi
    else
        print_warning "Impossible de lire la température CPU"
    fi
    
    return 0
}

# Générer le résumé final
generate_final_summary() {
    print_test_header "Résumé final"
    
    echo ""
    echo -e "${CYAN}=== RÉSUMÉ DES TESTS TIMEVOX ===${NC}"
    echo ""
    echo -e "Total des tests: ${BLUE}$TOTAL_TESTS${NC}"
    echo -e "Tests réussis:   ${GREEN}$PASSED_TESTS${NC}"
    echo -e "Tests échoués:   ${RED}$FAILED_TESTS${NC}"
    echo -e "Avertissements:  ${YELLOW}$WARNING_TESTS${NC}"
    echo ""
    
    # Ajouter au rapport
    echo "" >> "$TEST_REPORT"
    echo "=== RÉSUMÉ FINAL ===" >> "$TEST_REPORT"
    echo "Total des tests: $TOTAL_TESTS" >> "$TEST_REPORT"
    echo "Tests réussis: $PASSED_TESTS" >> "$TEST_REPORT"
    echo "Tests échoués: $FAILED_TESTS" >> "$TEST_REPORT"
    echo "Avertissements: $WARNING_TESTS" >> "$TEST_REPORT"
    
    # Déterminer le statut global
    if [ "$FAILED_TESTS" -eq 0 ]; then
        if [ "$WARNING_TESTS" -eq 0 ]; then
            echo -e "${GREEN}🎉 INSTALLATION PARFAITE${NC}"
            echo -e "${GREEN}TimeVox est prêt à fonctionner !${NC}"
            echo "STATUT: INSTALLATION PARFAITE" >> "$TEST_REPORT"
            return 0
        else
            echo -e "${YELLOW}✅ INSTALLATION RÉUSSIE (avec avertissements)${NC}"
            echo -e "${YELLOW}TimeVox devrait fonctionner correctement${NC}"
            echo "STATUT: INSTALLATION RÉUSSIE AVEC AVERTISSEMENTS" >> "$TEST_REPORT"
            return 0
        fi
    else
        echo -e "${RED}❌ INSTALLATION INCOMPLÈTE${NC}"
        echo -e "${RED}Certains problèmes doivent être résolus${NC}"
        echo "STATUT: INSTALLATION INCOMPLÈTE" >> "$TEST_REPORT"
        return 1
    fi
}

# Fonction principale
main() {
    echo -e "${CYAN}======================================${NC}"
    echo -e "${CYAN}    Tests de validation TimeVox${NC}"
    echo -e "${CYAN}======================================${NC}"
    echo ""
    
    # Initialiser le rapport
    init_test_report
    
    # Exécuter tous les tests
    test_user_permissions
    echo ""
    
    test_file_installation  
    echo ""
    
    test_python_environment
    echo ""
    
    test_system_configuration
    echo ""
    
    test_systemd_services
    echo ""
    
    test_timevox_startup
    echo ""
    
    test_hardware_detection
    echo ""
    
    test_scripts_and_tools
    echo ""
    
    test_system_resources
    echo ""
    
    # Résumé final
    generate_final_summary
    
    echo ""
    echo -e "${BLUE}Rapport détaillé sauvegardé: $TEST_REPORT${NC}"
    echo -e "${BLUE}Log d'installation: $LOG_FILE${NC}"
    
    # Recommandations finales
    echo ""
    echo -e "${CYAN}Recommandations:${NC}"
    echo "1. Redémarrez le système pour activer toutes les configurations"
    echo "2. Connectez votre matériel (OLED, amplificateur, microphone)"
    echo "3. Insérez une clé USB avec la structure TimeVox"
    echo "4. Testez avec: ~/timevox_control.sh start"
    echo "5. Consultez les logs avec: ~/timevox_control.sh logs"
    
    if [ "$FAILED_TESTS" -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# Exécution si script appelé directement
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi