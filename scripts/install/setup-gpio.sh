#!/bin/bash
# setup-gpio.sh - Configuration GPIO et permissions hardware pour TimeVox

set -e

# Variables
SCRIPT_NAME="setup-gpio.sh"
LOG_FILE="/tmp/timevox_install.log"
INSTALL_USER="timevox"
UDEV_RULES_FILE="/etc/udev/rules.d/99-timevox-gpio.rules"

# GPIO utilisés par TimeVox (depuis config.py)
BUTTON_GPIO=17    # Cadran téléphonique
HOOK_GPIO=27      # Détection combiné
SOUND_GPIO=25     # MAX98357A SD pin
SHUTDOWN_GPIO=26  # Bouton d'arrêt
LED_GPIO=16       # LED power

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
    echo -e "${BLUE}[GPIO]${NC} $1"
    log "$1"
}

print_success() {
    echo -e "${GREEN}[GPIO]${NC} $1"
    log "SUCCESS: $1"
}

print_error() {
    echo -e "${RED}[GPIO]${NC} $1"
    log "ERROR: $1"
}

print_warning() {
    echo -e "${YELLOW}[GPIO]${NC} $1"
    log "WARNING: $1"
}

# Vérifier l'accès aux GPIO
check_gpio_access() {
    print_status "Vérification de l'accès GPIO..."
    
    # Vérifier que /dev/gpiomem existe
    if [ -e /dev/gpiomem ]; then
        print_success "/dev/gpiomem présent"
    else
        print_error "/dev/gpiomem non trouvé"
        return 1
    fi
    
    # Vérifier les permissions de base
    if [ -r /dev/gpiomem ]; then
        print_success "Permissions de lecture GPIO OK"
    else
        print_warning "Problème de permissions GPIO"
    fi
    
    # Vérifier que l'utilisateur peut accéder aux GPIO
    if groups "$INSTALL_USER" | grep -q gpio; then
        print_success "Utilisateur $INSTALL_USER dans le groupe gpio"
    else
        print_warning "Utilisateur $INSTALL_USER pas dans le groupe gpio"
    fi
    
    return 0
}

# Ajouter l'utilisateur aux groupes nécessaires
setup_user_groups() {
    print_status "Configuration des groupes utilisateur..."
    
    # Groupes requis pour TimeVox
    required_groups=(
        "gpio"        # Accès GPIO
        "audio"       # Accès audio
        "i2c"         # Accès I2C pour OLED
        "spi"         # Accès SPI (au cas où)
        "dialout"     # Accès série (optionnel)
    )
    
    for group in "${required_groups[@]}"; do
        # Vérifier si le groupe existe
        if getent group "$group" >/dev/null 2>&1; then
            # Vérifier si l'utilisateur est déjà dans le groupe
            if groups "$INSTALL_USER" | grep -q "$group"; then
                print_status "$INSTALL_USER déjà dans le groupe $group"
            else
                print_status "Ajout de $INSTALL_USER au groupe $group..."
                if sudo usermod -a -G "$group" "$INSTALL_USER"; then
                    print_success "Utilisateur ajouté au groupe $group"
                else
                    print_error "Échec ajout au groupe $group"
                fi
            fi
        else
            print_warning "Groupe $group non trouvé (ignoré)"
        fi
    done
}

# Créer les règles udev pour TimeVox
create_udev_rules() {
    print_status "Création des règles udev TimeVox..."
    
    # Sauvegarder le fichier existant s'il existe
    if [ -f "$UDEV_RULES_FILE" ]; then
        sudo cp "$UDEV_RULES_FILE" "${UDEV_RULES_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        print_status "Sauvegarde des règles udev existantes"
    fi
    
    # Créer les nouvelles règles udev
    sudo tee "$UDEV_RULES_FILE" << 'EOF' >/dev/null
# Règles udev pour TimeVox - Accès hardware
# Créé automatiquement par setup-gpio.sh

# Accès GPIO pour groupe gpio
SUBSYSTEM=="gpio", GROUP="gpio", MODE="0664"
KERNEL=="gpiomem", GROUP="gpio", MODE="0664"

# Accès I2C pour OLED
SUBSYSTEM=="i2c-dev", GROUP="i2c", MODE="0664"
KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0664"

# Accès SPI (optionnel)
SUBSYSTEM=="spidev", GROUP="spi", MODE="0664"

# Accès audio
SUBSYSTEM=="sound", GROUP="audio", MODE="0664"
KERNEL=="controlC[0-9]*", GROUP="audio", MODE="0664"

# Périphériques USB audio
SUBSYSTEM=="usb", ATTR{bInterfaceClass}=="01", GROUP="audio", MODE="0664"

# RTC (si présent)
KERNEL=="rtc0", GROUP="dialout", MODE="0664"

# Accès mémoire (pour certaines opérations GPIO avancées)
KERNEL=="mem", GROUP="gpio", MODE="0640"

EOF
    
    print_success "Règles udev créées: $UDEV_RULES_FILE"
    
    # Recharger les règles udev
    print_status "Rechargement des règles udev..."
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    print_success "Règles udev rechargées"
}

# Tester l'accès aux GPIO utilisés par TimeVox
test_gpio_access() {
    print_status "Test d'accès aux GPIO TimeVox..."
    
    # Liste des GPIO à tester
    gpios_to_test=($BUTTON_GPIO $HOOK_GPIO $SOUND_GPIO $SHUTDOWN_GPIO $LED_GPIO)
    
    for gpio in "${gpios_to_test[@]}"; do
        print_status "Test GPIO $gpio..."
        
        # Tenter d'exporter le GPIO
        if echo "$gpio" | sudo tee /sys/class/gpio/export >/dev/null 2>&1; then
            print_success "GPIO $gpio exporté"
            
            # Vérifier les permissions
            gpio_dir="/sys/class/gpio/gpio$gpio"
            if [ -d "$gpio_dir" ]; then
                # Tester la lecture
                if [ -r "$gpio_dir/value" ]; then
                    print_success "GPIO $gpio lecture OK"
                else
                    print_warning "GPIO $gpio lecture limitée"
                fi
                
                # Tester l'écriture sur direction
                if [ -w "$gpio_dir/direction" ]; then
                    print_success "GPIO $gpio écriture OK"
                else
                    print_warning "GPIO $gpio écriture limitée"
                fi
            fi
            
            # Nettoyer (unexport)
            echo "$gpio" | sudo tee /sys/class/gpio/unexport >/dev/null 2>&1 || true
        else
            # GPIO peut-être déjà utilisé ou réservé
            print_warning "GPIO $gpio non exportable (peut-être déjà utilisé)"
        fi
    done
}

# Créer script de test GPIO pour TimeVox
create_gpio_test_script() {
    print_status "Création du script de test GPIO..."
    
    test_script="/home/$INSTALL_USER/test_gpio_timevox.py"
    
    cat > "$test_script" << EOF
#!/usr/bin/env python3
"""
Script de test GPIO pour TimeVox
Teste l'accès à tous les GPIO utilisés par TimeVox
"""

import sys
import time

try:
    import RPi.GPIO as GPIO
    print("✓ Module RPi.GPIO importé avec succès")
except ImportError as e:
    print(f"✗ Erreur import RPi.GPIO: {e}")
    sys.exit(1)

# GPIO utilisés par TimeVox
GPIOS_TIMEVOX = {
    'BUTTON_GPIO': $BUTTON_GPIO,    # Cadran téléphonique
    'HOOK_GPIO': $HOOK_GPIO,        # Détection combiné
    'SOUND_GPIO': $SOUND_GPIO,      # MAX98357A SD pin
    'SHUTDOWN_GPIO': $SHUTDOWN_GPIO, # Bouton d'arrêt
    'LED_GPIO': $LED_GPIO           # LED power
}

def test_gpio_setup():
    """Test de configuration GPIO"""
    try:
        GPIO.setmode(GPIO.BCM)
        GPIO.setwarnings(False)
        print("✓ Configuration GPIO BCM OK")
        return True
    except Exception as e:
        print(f"✗ Erreur configuration GPIO: {e}")
        return False

def test_gpio_individual(name, pin, mode):
    """Test d'un GPIO individuel"""
    try:
        GPIO.setup(pin, mode)
        print(f"✓ GPIO {pin} ({name}) configuré en {mode}")
        
        if mode == GPIO.IN:
            # Test lecture
            value = GPIO.input(pin)
            print(f"  Valeur lue: {value}")
        elif mode == GPIO.OUT:
            # Test écriture
            GPIO.output(pin, GPIO.HIGH)
            time.sleep(0.1)
            GPIO.output(pin, GPIO.LOW)
            print(f"  Test écriture OK")
        
        return True
    except Exception as e:
        print(f"✗ Erreur GPIO {pin} ({name}): {e}")
        return False

def main():
    print("=== TEST GPIO TIMEVOX ===")
    print()
    
    # Test configuration de base
    if not test_gpio_setup():
        return False
    
    success_count = 0
    total_tests = len(GPIOS_TIMEVOX)
    
    # Test chaque GPIO
    for name, pin in GPIOS_TIMEVOX.items():
        print(f"Test {name} (GPIO {pin}):")
        
        # Déterminer le mode selon le GPIO
        if 'BUTTON' in name or 'HOOK' in name or 'SHUTDOWN' in name:
            mode = GPIO.IN
        else:
            mode = GPIO.OUT
        
        if test_gpio_individual(name, pin, mode):
            success_count += 1
        print()
    
    # Nettoyage
    try:
        GPIO.cleanup()
        print("✓ Nettoyage GPIO OK")
    except Exception as e:
        print(f"⚠ Avertissement nettoyage: {e}")
    
    # Résultat final
    print(f"=== RÉSULTAT: {success_count}/{total_tests} GPIO OK ===")
    
    if success_count == total_tests:
        print("🎉 Tous les GPIO TimeVox sont accessibles !")
        return True
    else:
        print("⚠ Certains GPIO ne sont pas accessibles")
        print("Vérifiez les permissions et les conflits hardware")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
EOF
    
    chmod +x "$test_script"
    chown "$INSTALL_USER:$INSTALL_USER" "$test_script"
    print_success "Script de test créé: $test_script"
}

# Configurer les paramètres système pour GPIO
optimize_gpio_performance() {
    print_status "Optimisation des performances GPIO..."
    
    # Vérifier et activer les interfaces nécessaires
    interfaces_needed=(
        "i2c"
        "spi"
    )
    
    for interface in "${interfaces_needed[@]}"; do
        if command -v raspi-config >/dev/null 2>&1; then
            print_status "Vérification interface $interface..."
            
            case $interface in
                "i2c")
                    if lsmod | grep -q i2c_bcm2835; then
                        print_success "I2C déjà activé"
                    else
                        print_status "Activation I2C..."
                        sudo raspi-config nonint do_i2c 0
                        print_success "I2C activé"
                    fi
                    ;;
                "spi")
                    if lsmod | grep -q spi_bcm2835; then
                        print_success "SPI déjà activé"
                    else
                        print_status "Activation SPI..."
                        sudo raspi-config nonint do_spi 0
                        print_success "SPI activé"
                    fi
                    ;;
            esac
        else
            print_warning "raspi-config non disponible pour $interface"
        fi
    done
    
    # Paramètres de performance GPIO dans config.txt
    gpio_optimizations=(
        "# Optimisations GPIO TimeVox"
        "gpio=16=op,dh"    # LED power en sortie, niveau haut par défaut
        "gpio=25=op,dl"    # Sound enable en sortie, niveau bas par défaut
    )
    
    print_status "Ajout optimisations GPIO dans /boot/config.txt..."
    for optimization in "${gpio_optimizations[@]}"; do
        if ! grep -q "$optimization" /boot/config.txt; then
            echo "$optimization" | sudo tee -a /boot/config.txt >/dev/null
        fi
    done
    print_success "Optimisations GPIO ajoutées"
}

# Créer documentation GPIO
create_gpio_documentation() {
    print_status "Création de la documentation GPIO..."
    
    doc_file="/home/$INSTALL_USER/GPIO_TimeVox.md"
    
    cat > "$doc_file" << EOF
# GPIO TimeVox - Documentation

## GPIO utilisés par TimeVox

| GPIO | Nom | Direction | Description | Pull |
|------|-----|-----------|-------------|------|
| $BUTTON_GPIO | BUTTON_GPIO | IN | Impulsions cadran téléphonique | PULL_UP |
| $HOOK_GPIO | HOOK_GPIO | IN | Détection combiné décroché/raccroché | PULL_UP |
| $SOUND_GPIO | SOUND_GPIO | OUT | Activation MAX98357A (SD pin) | - |
| $SHUTDOWN_GPIO | SHUTDOWN_GPIO | IN | Bouton d'arrêt système | PULL_UP |
| $LED_GPIO | LED_GPIO | OUT | LED de statut power | - |

## I2C (OLED)
- **SDA**: GPIO 2
- **SCL**: GPIO 3
- **Adresse**: 0x3C (écran SH1106)

## I2S (Audio MAX98357A)
- **BCLK**: GPIO 18
- **LRC**: GPIO 19  
- **DOUT**: GPIO 21
- **SD**: GPIO $SOUND_GPIO (contrôle activation)

## Tests de fonctionnement

### Test manuel GPIO:
\`\`\`bash
# Tester tous les GPIO TimeVox
python3 ~/test_gpio_timevox.py
\`\`\`

### Test I2C OLED:
\`\`\`bash
# Détecter périphériques I2C
i2cdetect -y 1
\`\`\`

### Test audio:
\`\`\`bash
# Test lecture audio
speaker-test -t sine -f 440 -l 1 -s 1
\`\`\`

## Dépannage

### Permissions GPIO:
\`\`\`bash
# Vérifier groupes utilisateur
groups $INSTALL_USER

# Recharger règles udev
sudo udevadm control --reload-rules
sudo udevadm trigger
\`\`\`

### Conflits GPIO:
\`\`\`bash
# Voir GPIO exportés
ls /sys/class/gpio/

# Libérer un GPIO
echo [numéro] | sudo tee /sys/class/gpio/unexport
\`\`\`

Généré automatiquement par setup-gpio.sh
$(date)
EOF
    
    chown "$INSTALL_USER:$INSTALL_USER" "$doc_file"
    print_success "Documentation créée: $doc_file"
}

# Fonction principale
main() {
    print_status "=== Configuration GPIO et permissions TimeVox ==="
    
    # Vérifications de base
    check_gpio_access
    
    # Configuration des groupes utilisateur
    setup_user_groups
    
    # Création des règles udev
    create_udev_rules
    
    # Optimisations GPIO
    optimize_gpio_performance
    
    # Test d'accès GPIO
    test_gpio_access
    
    # Création du script de test
    create_gpio_test_script
    
    # Documentation
    create_gpio_documentation
    
    print_success "=== Configuration GPIO terminée ==="
    echo ""
    print_status "Fichiers créés:"
    print_status "  - Règles udev: $UDEV_RULES_FILE"
    print_status "  - Script test: /home/$INSTALL_USER/test_gpio_timevox.py"
    print_status "  - Documentation: /home/$INSTALL_USER/GPIO_TimeVox.md"
    echo ""
    print_warning "IMPORTANT:"
    print_warning "  - Déconnectez-vous et reconnectez-vous pour les groupes"
    print_warning "  - Redémarrage recommandé pour I2C/SPI"
    print_warning "  - Testez avec: python3 ~/test_gpio_timevox.py"
    echo ""
    
    return 0
}

# Exécution si script appelé directement
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi