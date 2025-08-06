#!/bin/bash
# setup-audio.sh - Configuration audio complète pour TimeVox

set -e

# Variables
SCRIPT_NAME="setup-audio.sh"
LOG_FILE="/tmp/timevox_install.log"
INSTALL_USER="timevox"
AUDIO_CONFIG_DIR="/home/$INSTALL_USER/.config/timevox"

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
    echo -e "${BLUE}[AUDIO]${NC} $1"
    log "$1"
}

print_success() {
    echo -e "${GREEN}[AUDIO]${NC} $1"
    log "SUCCESS: $1"
}

print_error() {
    echo -e "${RED}[AUDIO]${NC} $1"
    log "ERROR: $1"
}

print_warning() {
    echo -e "${YELLOW}[AUDIO]${NC} $1"
    log "WARNING: $1"
}

# Détecter les cartes audio disponibles
detect_audio_devices() {
    print_status "Détection des périphériques audio..."
    
    # Lister les cartes audio
    if command -v aplay >/dev/null 2>&1; then
        print_status "Cartes audio détectées:"
        aplay -l | while IFS= read -r line; do
            if [[ "$line" =~ ^card ]]; then
                print_status "  $line"
            fi
        done
        
        # Compter les cartes
        card_count=$(aplay -l 2>/dev/null | grep -c "^card" || echo "0")
        if [ "$card_count" -gt 0 ]; then
            print_success "$card_count carte(s) audio détectée(s)"
        else
            print_warning "Aucune carte audio détectée"
        fi
    else
        print_error "aplay non disponible"
        return 1
    fi
    
    # Détecter spécifiquement le MAX98357A ou autres DAC I2S
    if aplay -l | grep -q -i "bcm2835\|MAX98357A\|HiFiBerry"; then
        print_success "DAC audio compatible détecté"
    else
        print_warning "Aucun DAC I2S spécialisé détecté"
        print_warning "Utilisation de la sortie audio intégrée"
    fi
    
    return 0
}

# Configurer l'audio I2S pour MAX98357A
setup_i2s_audio() {
    print_status "Configuration audio I2S..."
    
    # Vérifier si I2S est déjà configuré
    if grep -q "dtoverlay=hifiberry-dac" /boot/config.txt || \
       grep -q "dtoverlay=i2s-mmap" /boot/config.txt; then
        print_status "Configuration I2S déjà présente"
    else
        print_status "Ajout configuration I2S dans /boot/config.txt..."
        
        # Sauvegarder config.txt original
        sudo cp /boot/config.txt /boot/config.txt.backup.timevox
        
        # Ajouter configuration I2S
        cat | sudo tee -a /boot/config.txt << 'EOF'

# Configuration audio I2S pour TimeVox (MAX98357A)
dtparam=i2s=on
dtoverlay=hifiberry-dac
dtoverlay=i2s-mmap
EOF
        
        print_success "Configuration I2S ajoutée (redémarrage requis)"
    fi
    
    # Désactiver l'audio analogique pour éviter les conflits
    if ! grep -q "dtparam=audio=off" /boot/config.txt; then
        print_status "Désactivation audio analogique..."
        echo "dtparam=audio=off" | sudo tee -a /boot/config.txt
        print_success "Audio analogique désactivé"
    fi
}

# Créer configuration ALSA optimisée
create_alsa_config() {
    print_status "Création configuration ALSA..."
    
    # Créer le répertoire de configuration
    mkdir -p "$AUDIO_CONFIG_DIR"
    
    # Configuration ALSA pour l'utilisateur timevox
    cat > "/home/$INSTALL_USER/.asoundrc" << 'EOF'
# Configuration ALSA TimeVox
# Priorité au périphérique I2S (MAX98357A)

pcm.!default {
    type hw
    card 0
    device 0
}

ctl.!default {
    type hw
    card 0
}

# Configuration spécifique pour TimeVox
pcm.timevox {
    type hw
    card 0
    device 0
    rate 22050
    channels 2
}

# Mixer pour contrôle du volume
pcm.timevox_mixer {
    type softvol
    slave.pcm "timevox"
    control {
        name "TimeVox Volume"
        card 0
    }
    min_dB -51.0
    max_dB 0.0
}
EOF
    
    print_success "Configuration ALSA utilisateur créée"
    
    # Configuration système si nécessaire
    if [ ! -f /etc/asound.conf ]; then
        print_status "Création configuration ALSA système..."
        
        sudo tee /etc/asound.conf << 'EOF' >/dev/null
# Configuration ALSA système pour TimeVox
defaults.pcm.card 0
defaults.pcm.device 0
defaults.ctl.card 0
EOF
        
        print_success "Configuration ALSA système créée"
    fi
}

# Configurer les modules audio
setup_audio_modules() {
    print_status "Configuration des modules audio..."
    
    # Créer configuration des modules
    sudo tee /etc/modprobe.d/timevox-audio.conf << 'EOF' >/dev/null
# Configuration audio TimeVox

# Forcer l'ordre des cartes audio
options snd-usb-audio index=-2
options snd-bcm2835 index=0

# Optimisations pour le streaming audio
options snd-hrtimer-dac index=0

# Paramètres de performance
options snd-pcm-oss adsp_map=2

# Désactiver l'audio analogique
blacklist snd_bcm2835_analog
EOF
    
    print_success "Configuration modules audio créée"
    
    # Forcer le rechargement des modules
    print_status "Rechargement modules audio..."
    sudo modprobe -r snd_bcm2835 2>/dev/null || true
    sudo modprobe snd_bcm2835 2>/dev/null || true
    print_success "Modules audio rechargés"
}

# Tester la configuration audio
test_audio_config() {
    print_status "Test de la configuration audio..."
    
    # Test 1: Vérifier que les périphériques sont visibles
    if aplay -l >/dev/null 2>&1; then
        print_success "Périphériques audio accessibles"
    else
        print_error "Impossible d'accéder aux périphériques audio"
        return 1
    fi
    
    # Test 2: Tester la lecture avec un signal de test court
    print_status "Test de lecture audio..."
    if command -v speaker-test >/dev/null 2>&1; then
        # Test très court et silencieux
        if timeout 2 speaker-test -t sine -f 440 -l 1 -s 1 >/dev/null 2>&1; then
            print_success "Test de lecture réussi"
        else
            print_warning "Test de lecture échoué (périphérique peut-être déconnecté)"
        fi
    else
        print_warning "speaker-test non disponible, test ignoré"
    fi
    
    # Test 3: Vérifier les permissions
    if [ -r /dev/snd/controlC0 ]; then
        print_success "Permissions audio OK"
    else
        print_warning "Problème de permissions audio"
    fi
    
    return 0
}

# Optimiser la configuration pour pygame
setup_pygame_audio() {
    print_status "Optimisation audio pour pygame..."
    
    # Créer script de configuration pygame
    cat > "$AUDIO_CONFIG_DIR/pygame_audio.py" << 'EOF'
#!/usr/bin/env python3
"""
Configuration audio optimisée pour pygame TimeVox
"""

import os
import pygame

# Variables d'environnement pour pygame
def setup_pygame_audio():
    """Configure l'environnement pour pygame audio"""
    
    # Forcer l'utilisation d'ALSA
    os.environ['SDL_AUDIODRIVER'] = 'alsa'
    
    # Définir le périphérique par défaut
    os.environ['ALSA_DEVICE'] = 'hw:0,0'
    
    # Optimisations buffer
    os.environ['SDL_AUDIO_FREQUENCY'] = '22050'
    os.environ['SDL_AUDIO_FORMAT'] = '16'
    os.environ['SDL_AUDIO_CHANNELS'] = '2'
    os.environ['SDL_AUDIO_SAMPLES'] = '512'
    
    print("Configuration pygame audio appliquée")

if __name__ == "__main__":
    setup_pygame_audio()
    
    # Test pygame
    try:
        pygame.mixer.pre_init(
            frequency=22050,
            size=-16,
            channels=2,
            buffer=512
        )
        pygame.mixer.init()
        print("Test pygame mixer: SUCCESS")
        pygame.mixer.quit()
    except Exception as e:
        print(f"Test pygame mixer: FAILED - {e}")
EOF
    
    chmod +x "$AUDIO_CONFIG_DIR/pygame_audio.py"
    print_success "Configuration pygame créée"
    
    # Tester pygame si possible
    if [ -f "/home/$INSTALL_USER/timevox_env/bin/python3" ]; then
        print_status "Test pygame mixer..."
        if /home/$INSTALL_USER/timevox_env/bin/python3 "$AUDIO_CONFIG_DIR/pygame_audio.py"; then
            print_success "Test pygame réussi"
        else
            print_warning "Test pygame échoué (normal si matériel déconnecté)"
        fi
    fi
}

# Détecter et configurer les microphones USB
setup_usb_microphones() {
    print_status "Configuration microphones USB..."
    
    # Détecter les microphones USB
    usb_mics=$(arecord -l 2>/dev/null | grep -c "USB" || echo "0")
    
    if [ "$usb_mics" -gt 0 ]; then
        print_success "$usb_mics microphone(s) USB détecté(s)"
        
        # Lister les microphones
        print_status "Microphones disponibles:"
        arecord -l | grep "USB" | while IFS= read -r line; do
            print_status "  $line"
        done
        
        # Créer configuration d'enregistrement
        cat >> "/home/$INSTALL_USER/.asoundrc" << 'EOF'

# Configuration enregistrement USB
pcm.usb_mic {
    type hw
    card 1
    device 0
}

pcm.timevox_record {
    type plug
    slave.pcm "usb_mic"
    slave.rate 22050
    slave.channels 1
}
EOF
        
        print_success "Configuration microphone USB ajoutée"
    else
        print_warning "Aucun microphone USB détecté"
        print_warning "Connectez un microphone USB pour l'enregistrement"
    fi
}

# Créer des scripts de diagnostic audio
create_audio_diagnostics() {
    print_status "Création des outils de diagnostic audio..."
    
    # Script de diagnostic complet
    cat > "$AUDIO_CONFIG_DIR/audio_diagnostic.sh" << 'EOF'
#!/bin/bash
# Diagnostic audio TimeVox

echo "=== DIAGNOSTIC AUDIO TIMEVOX ==="
echo ""

echo "1. Cartes audio disponibles:"
aplay -l
echo ""

echo "2. Périphériques d'enregistrement:"
arecord -l
echo ""

echo "3. Modules audio chargés:"
lsmod | grep snd
echo ""

echo "4. Configuration ALSA:"
if [ -f ~/.asoundrc ]; then
    echo "Fichier .asoundrc présent"
else
    echo "Aucun fichier .asoundrc"
fi
echo ""

echo "5. Test périphérique de lecture par défaut:"
aplay -D default /dev/zero &
sleep 1
kill $! 2>/dev/null
echo "Test terminé"
echo ""

echo "6. Groupes utilisateur:"
groups
echo ""

echo "7. Permissions /dev/snd/:"
ls -la /dev/snd/
echo ""
EOF
    
    chmod +x "$AUDIO_CONFIG_DIR/audio_diagnostic.sh"
    print_success "Script de diagnostic créé: $AUDIO_CONFIG_DIR/audio_diagnostic.sh"
    
    # Script de test rapide
    cat > "$AUDIO_CONFIG_DIR/test_audio.sh" << 'EOF'
#!/bin/bash
# Test audio rapide TimeVox

echo "Test audio TimeVox..."

# Test lecture
echo "Test lecture (2 secondes):"
if timeout 2 speaker-test -t sine -f 440 -l 1 >/dev/null 2>&1; then
    echo "  LECTURE: OK"
else
    echo "  LECTURE: ECHEC"
fi

# Test enregistrement
echo "Test enregistrement (2 secondes):"
if timeout 2 arecord -f cd -t raw | head -c 1000 >/dev/null 2>&1; then
    echo "  ENREGISTREMENT: OK"
else
    echo "  ENREGISTREMENT: ECHEC"
fi

echo "Test terminé"
EOF
    
    chmod +x "$AUDIO_CONFIG_DIR/test_audio.sh"
    print_success "Script de test créé: $AUDIO_CONFIG_DIR/test_audio.sh"
}

# Optimiser les performances audio
optimize_audio_performance() {
    print_status "Optimisation des performances audio..."
    
    # Ajuster les paramètres du noyau pour l'audio temps réel
    if [ ! -f /etc/security/limits.d/timevox-audio.conf ]; then
        print_status "Configuration limites système pour audio..."
        
        sudo tee /etc/security/limits.d/timevox-audio.conf << 'EOF' >/dev/null
# Limites pour audio temps réel TimeVox
@audio   -  rtprio      95
@audio   -  memlock     unlimited
timevox  -  rtprio      95
timevox  -  memlock     unlimited
EOF
        
        print_success "Limites système configurées"
    fi
    
    # Paramètres sysctl pour l'audio
    if [ ! -f /etc/sysctl.d/timevox-audio.conf ]; then
        print_status "Configuration sysctl pour audio..."
        
        sudo tee /etc/sysctl.d/timevox-audio.conf << 'EOF' >/dev/null
# Optimisations audio TimeVox
kernel.sched_rt_runtime_us = 950000
vm.swappiness = 10
EOF
        
        print_success "Paramètres sysctl configurés"
    fi
}

# Fonction principale
main() {
    print_status "=== Configuration audio TimeVox ==="
    
    # Créer le répertoire de configuration
    mkdir -p "$AUDIO_CONFIG_DIR"
    
    # Détecter les périphériques audio
    detect_audio_devices
    
    # Configurer I2S pour MAX98357A
    setup_i2s_audio
    
    # Créer la configuration ALSA
    create_alsa_config
    
    # Configurer les modules audio
    setup_audio_modules
    
    # Configurer pygame
    setup_pygame_audio
    
    # Configurer les microphones USB
    setup_usb_microphones
    
    # Optimiser les performances
    optimize_audio_performance
    
    # Créer les outils de diagnostic
    create_audio_diagnostics
    
    # Tests finaux
    test_audio_config
    
    # Définir les permissions
    chown -R "$INSTALL_USER:$INSTALL_USER" "$AUDIO_CONFIG_DIR"
    
    print_success "=== Configuration audio terminée ==="
    echo ""
    print_status "Configuration créée dans: $AUDIO_CONFIG_DIR"
    print_status "Outils de diagnostic disponibles:"
    print_status "  - $AUDIO_CONFIG_DIR/audio_diagnostic.sh"
    print_status "  - $AUDIO_CONFIG_DIR/test_audio.sh"
    echo ""
    print_warning "IMPORTANT: Redémarrage requis pour:"
    print_warning "  - Activation de la configuration I2S"
    print_warning "  - Prise en compte des modules audio"
    print_warning "  - Application des optimisations système"
    echo ""
    
    return 0
}

# Exécution si script appelé directement
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi