# audio_manager.py
"""
Gestionnaire audio pour la lecture des annonces et des bips
Version portable avec gestion automatique des chemins et volume configurable
Version corrigée avec retry audio pour démarrage système
"""

import pygame
import os
import time
from config import (
    PYGAME_FREQUENCY, PYGAME_SIZE, PYGAME_CHANNELS, PYGAME_BUFFER,
    SEARCH_CORRESPONDANT_FILE, BIP_FILE, ensure_directories
)


class AudioManager:
    def __init__(self, gpio_manager, usb_manager=None):
        self.gpio_manager = gpio_manager
        self.usb_manager = usb_manager
        self.mixer_initialized = False  # FLAG pour savoir si pygame fonctionne
        
        # NOUVEAU: Logger sur USB pour diagnostic
        self.log_to_usb("=== TIMEVOX AUDIO INIT START ===")
        
        # Créer les dossiers nécessaires au démarrage
        ensure_directories()
        self.init_pygame_with_retry()
        self.set_volume_from_config()
        self.check_audio_files()
        
        self.log_to_usb(f"Audio init terminé - pygame OK: {self.mixer_initialized}")

    def get_best_audio_device(self):
        """Détermine le meilleur périphérique audio à utiliser"""
        try:
            import subprocess
            
            # Obtenir la liste des cartes audio
            result = subprocess.run(["aplay", "-l"], capture_output=True, text=True, timeout=3)
            if result.returncode != 0:
                self.log_to_usb("❌ Impossible d'obtenir liste périphériques audio")
                return None
            
            self.log_to_usb(f"Liste périphériques audio:\n{result.stdout}")
            
            # Parser pour trouver le premier périphérique disponible
            lines = result.stdout.split('\n')
            for line in lines:
                if 'card' in line and ':' in line:
                    # Format: "card 0: bcm2835HDMI [bcm2835 HDMI], device 0: bcm2835 HDMI [bcm2835 HDMI]"
                    try:
                        # Extraire le numéro de carte
                        card_part = line.split('card ')[1].split(':')[0].strip()
                        # Chercher le device
                        if 'device' in line:
                            device_part = line.split('device ')[1].split(':')[0].strip()
                            device_name = f"hw:{card_part},{device_part}"
                        else:
                            device_name = f"hw:{card_part},0"
                        
                        self.log_to_usb(f"Périphérique trouvé: {device_name}")
                        
                        # Test rapide du périphérique
                        test_cmd = ["aplay", "-D", device_name, "--dump-hw-params", "/dev/zero"]
                        test_result = subprocess.run(test_cmd, capture_output=True, timeout=2)
                        if test_result.returncode == 0 or "Sample format not available" in test_result.stderr:
                            self.log_to_usb(f"✅ Périphérique {device_name} accessible")
                            return device_name
                        else:
                            self.log_to_usb(f"❌ Périphérique {device_name} non accessible")
                    except Exception as e:
                        self.log_to_usb(f"Erreur parsing ligne: {line} - {e}")
                        continue
            
            # Fallback: essayer les périphériques standards
            standard_devices = ["hw:0,0", "hw:1,0", "default", "pulse"]
            for device in standard_devices:
                self.log_to_usb(f"Test périphérique fallback: {device}")
                test_cmd = ["aplay", "-D", device, "--dump-hw-params", "/dev/zero"]
                test_result = subprocess.run(test_cmd, capture_output=True, timeout=2)
                if test_result.returncode == 0 or "Sample format not available" in test_result.stderr:
                    self.log_to_usb(f"✅ Périphérique fallback {device} OK")
                    return device
                    
            self.log_to_usb("❌ Aucun périphérique audio trouvé")
            return None
            
        except Exception as e:
            self.log_to_usb(f"Erreur détection périphérique audio: {e}")
            return None
        """Afficher le statut audio sur l'écran OLED pour diagnostic"""
        try:
            # Import local pour éviter les dépendances circulaires
            from oled_display import afficher
            afficher("Audio Init", message, "", taille=10, align="centre")
            time.sleep(2)  # Laisser le temps de voir le message
        except Exception as e:
            print(f"Erreur affichage OLED: {e}")
    
    def init_pygame_with_retry(self, max_attempts=20, delay=5):
        """Initialise pygame mixer avec retry pour attendre que l'audio soit prêt"""
        self.log_to_usb("🔊 Début initialisation audio...")
        
        # Déterminer le bon périphérique audio à utiliser
        audio_device = self.get_best_audio_device()
        self.log_to_usb(f"Périphérique audio sélectionné: {audio_device}")
        
        for attempt in range(max_attempts):
            try:
                self.log_to_usb(f"Tentative {attempt + 1}/{max_attempts}")
                print(f"Tentative d'initialisation audio {attempt + 1}/{max_attempts}")
                
                # Nettoyer pygame au cas où
                try:
                    pygame.mixer.quit()
                except:
                    pass
                
                # Vérifier d'abord que le système audio répond
                if attempt > 0:  # Après la première tentative
                    alsa_ready = self.check_alsa_ready()
                    self.log_to_usb(f"ALSA ready: {alsa_ready}")
                    if not alsa_ready:
                        self.log_to_usb(f"ALSA pas prêt, attente {delay}s...")
                        print(f"ALSA pas encore prêt, attente {delay}s...")
                        time.sleep(delay)
                        continue
                
                # NOUVEAU: Définir le périphérique ALSA avant pygame
                if audio_device:
                    os.environ['SDL_AUDIODRIVER'] = 'alsa'
                    os.environ['ALSA_DEVICE'] = audio_device
                    self.log_to_usb(f"Forçage périphérique: {audio_device}")
                
                # Initialiser avec paramètres optimisés
                pygame.mixer.pre_init(
                    frequency=PYGAME_FREQUENCY, 
                    size=PYGAME_SIZE, 
                    channels=PYGAME_CHANNELS, 
                    buffer=PYGAME_BUFFER
                )
                pygame.mixer.init()
                
                # Test que l'initialisation fonctionne vraiment
                pygame.mixer.music.set_volume(0.1)
                
                success_msg = f"✅ Pygame mixer initialisé (tentative {attempt + 1})"
                print(success_msg)
                self.log_to_usb(success_msg)
                #self.show_audio_status_on_display("Audio OK!")
                self.mixer_initialized = True
                return True
                
            except Exception as e:
                error_msg = f"❌ Tentative {attempt + 1} échouée: {e}"
                print(error_msg)
                self.log_to_usb(error_msg)
                
                if attempt < max_attempts - 1:
                    self.log_to_usb(f"Attente {delay}s avant retry...")
                    print(f"Attente {delay} secondes avant retry...")
                    time.sleep(delay)
                else:
                    self.log_to_usb("⚠️ Toutes tentatives échouées, essai basique...")
                    print("⚠️ Toutes les tentatives d'initialisation audio ont échoué")
                    print("Tentative d'initialisation basique...")
                    try:
                        pygame.mixer.init()
                        self.log_to_usb("✅ Init basique réussie")
                        print("✅ Initialisation basique réussie")
                        self.mixer_initialized = True
                        return True
                    except Exception as e2:
                        final_error = f"❌ Init basique échouée: {e2}"
                        print(final_error)
                        self.log_to_usb(final_error)
                        self.mixer_initialized = False
                        return False
        
        self.log_to_usb("❌ Échec complet initialisation audio")
        #self.show_audio_status_on_display("Audio FAIL!")
        return False

    def log_to_usb(self, message):
        """Log des messages de diagnostic sur la clé USB"""
        try:
            if self.usb_manager and self.usb_manager.is_usb_available():
                import datetime
                timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                log_entry = f"{timestamp} - {message}\n"
                
                log_dir = os.path.join(self.usb_manager.usb_path, "Logs")
                if not os.path.exists(log_dir):
                    os.makedirs(log_dir)
                
                log_file = os.path.join(log_dir, "audio_debug.log")
                with open(log_file, 'a', encoding='utf-8') as f:
                    f.write(log_entry)
        except Exception as e:
            print(f"Erreur log USB: {e}")  # Fallback console
    
    def check_alsa_ready(self):
        """Vérifier que ALSA est prêt avant d'initialiser pygame"""
        try:
            import subprocess
            # Test rapide: lister les cartes audio
            result = subprocess.run(
                ["aplay", "-l"], 
                capture_output=True, 
                text=True, 
                timeout=3
            )
            if result.returncode == 0 and "card" in result.stdout:
                self.log_to_usb("✅ ALSA répond - périphériques détectés")
                print("✅ ALSA répond - périphériques audio détectés")
                return True
            else:
                self.log_to_usb(f"❌ ALSA ne répond pas: code {result.returncode}")
                print("❌ ALSA ne répond pas correctement")
                return False
        except Exception as e:
            error_msg = f"❌ Test ALSA échoué: {e}"
            self.log_to_usb(error_msg)
            print(error_msg)
            return False
    
    def init_pygame(self):
        """Version originale gardée pour compatibilité"""
        return self.init_pygame_with_retry()
    
    def set_volume_from_config(self):
        """Configure le volume depuis le fichier config.json de la clé USB"""
        volume_pygame = 0.02  # Valeur par défaut (2%)
        
        if self.usb_manager and self.usb_manager.is_usb_available():
            try:
                config_info = self.usb_manager.get_config_info()
                if 'volume_audio' in config_info:
                    volume_percent = config_info['volume_audio']
                    # Convertir le pourcentage en valeur pygame (0.0 à 1.0)
                    volume_pygame = volume_percent / 100.0
                    # S'assurer que la valeur reste dans les limites
                    volume_pygame = max(0.0, min(1.0, volume_pygame))
                    print(f"Volume configuré depuis USB: {volume_percent}% -> {volume_pygame}")
                else:
                    print("Paramètre 'volume_audio' non trouvé dans config.json - utilisation valeur par défaut (2%)")
            except Exception as e:
                print(f"Erreur lecture volume depuis USB: {e}")
                print("Utilisation du volume par défaut (2%)")
        else:
            print("Clé USB non disponible - utilisation du volume par défaut (2%)")
        
        # Appliquer le volume à pygame avec vérification
        try:
            if self.mixer_initialized:
                pygame.mixer.music.set_volume(volume_pygame)
                print(f"Volume pygame défini à: {volume_pygame} ({volume_pygame * 100:.1f}%)")
            else:
                print(f"⚠️ Pygame non initialisé - volume {volume_pygame * 100:.1f}% sera appliqué plus tard")
        except Exception as e:
            print(f"❌ Erreur définition volume: {e}")
    
    def check_audio_files(self):
        """Vérifie la présence des fichiers audio et affiche des avertissements si nécessaire"""
        if not os.path.exists(SEARCH_CORRESPONDANT_FILE):
            print(f"⚠️  ATTENTION: Fichier manquant - {SEARCH_CORRESPONDANT_FILE}")
            print("   Placez le fichier search_correspondant.mp3 dans le dossier sounds/")
        
        if not os.path.exists(BIP_FILE):
            print(f"⚠️  ATTENTION: Fichier manquant - {BIP_FILE}")
            print("   Placez le fichier bip.mp3 dans le dossier sounds/")
    
    def get_search_correspondant_path(self):
        """Retourne le chemin vers le fichier search_correspondant.mp3"""
        if os.path.exists(SEARCH_CORRESPONDANT_FILE):
            print(f"Fichier search_correspondant trouvé: {SEARCH_CORRESPONDANT_FILE}")
            return SEARCH_CORRESPONDANT_FILE
        else:
            print(f"Fichier search_correspondant.mp3 non trouvé: {SEARCH_CORRESPONDANT_FILE}")
            return None
    
    def get_bip_path(self):
        """Retourne le chemin vers le fichier bip.mp3"""
        if os.path.exists(BIP_FILE):
            print(f"Fichier bip trouvé: {BIP_FILE}")
            return BIP_FILE
        else:
            print(f"Fichier bip.mp3 non trouvé: {BIP_FILE}")
            return None
    
    def update_volume_from_config(self):
        """Met à jour le volume depuis la configuration (utile pour recharger à chaud)"""
        self.set_volume_from_config()
    
    def play_audio(self, path):
        """
        Lit un fichier audio et surveille le raccrochage
        Retourne True si la lecture s'est bien déroulée, False si interrompue
        """
        if not self.mixer_initialized:
            print("❌ Pygame mixer non initialisé - impossible de lire l'audio")
            return False
            
        try:
            print(f"Tentative de lecture: {path}")

            # Vérifier que le fichier existe
            if not os.path.exists(path):
                print(f"Fichier inexistant: {path}")
                return False

            # Vérifier la taille du fichier
            file_size = os.path.getsize(path)
            print(f"Taille du fichier: {file_size} bytes")
            if file_size == 0:
                print("Fichier vide")
                return False

            # Arrêter toute musique en cours
            pygame.mixer.music.stop()
            time.sleep(0.1)

            # Charger et jouer
            pygame.mixer.music.load(path)
            pygame.mixer.music.play()
            print("Lecture démarrée...")

            # Attendre que la lecture commence vraiment
            timeout = 0
            while not pygame.mixer.music.get_busy() and timeout < 50:
                time.sleep(0.1)
                timeout += 1

            if not pygame.mixer.music.get_busy():
                print("Échec démarrage lecture")
                return False

            print("Lecture en cours...")
            while pygame.mixer.music.get_busy():
                if self.gpio_manager.is_phone_on_hook():
                    print("Raccrochage détecté pendant lecture")
                    pygame.mixer.music.stop()
                    return False
                time.sleep(0.1)
            
            print("Lecture terminée.")
            return True
            
        except Exception as e:
            print(f"Erreur lecture audio: {e}")
            print(f"Type erreur: {type(e)}")
            return False
    
    def stop_audio(self):
        """Arrête la lecture audio en cours"""
        if not self.mixer_initialized:
            # Ne pas logger d'erreur si pygame n'est pas initialisé
            return
            
        try:
            if pygame.mixer.music.get_busy():
                pygame.mixer.music.stop()
                print("Musique arrêtée")
        except Exception as e:
            print(f"Erreur arrêt audio: {e}")