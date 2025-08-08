# phone_controller.py
"""
Contrôleur principal du téléphone TimeVox
Version avec durée d'enregistrement, volume audio et longueur du numéro principal configurables
Version avec menu paramètres étendu et gestion des mises à jour
"""

import time
from gpio_manager import GPIOManager
from usb_manager import USBManager
from audio_manager import AudioManager
from recording_manager import RecordingManager
from display_manager import DisplayManager
from dialer_manager import DialerManager
from rtc_manager import RTCManager 
from config import TARGET_NUMBERS, SERVICE_NUMBERS
import subprocess
from datetime import datetime
from params_menu_manager import ParamsMenuManager  # Nouveau nom
from update_manager import UpdateManager


class PhoneController:
    def __init__(self):
        print("Initialisation TimeVox...")
        
        # Initialisation du gestionnaire RTC en premier
        print("Initialisation du gestionnaire RTC...")
        self.rtc_manager = RTCManager()
        
        # Vérification de l'heure au démarrage
        status_info = self.rtc_manager.get_status_info()
        print(f"État RTC: Disponible={status_info['rtc_available']}, "
              f"Heure valide={status_info['time_valid']}")
        
        if not status_info['time_valid']:
            print("ATTENTION: L'heure système semble incorrecte!")
            print("Tentative de synchronisation réseau...")
            self.rtc_manager.sync_time_if_network_available()
        
        # Initialisation des gestionnaires de base
        self.gpio_manager = GPIOManager()
        self.display_manager = DisplayManager()
        
        # Passer le RTC au USBManager
        self.usb_manager = USBManager(self.rtc_manager)
        
        # Afficher le message d'initialisation
        self.display_manager.show_initialization()

        # Configuration du bouton d'arrêt
        self.shutdown_button_gpio = 26
        self.shutdown_led_gpio = 16
        self.shutdown_button_pressed_time = None
        self.shutdown_in_progress = False
        
        # Configurer les GPIO du bouton d'arrêt
        self.setup_shutdown_button()

        # Initialiser AudioManager avec usb_manager pour la gestion du volume
        self.audio_manager = AudioManager(self.gpio_manager, self.usb_manager)
        
        # Initialiser RecordingManager avec usb_manager
        self.recording_manager = RecordingManager(
            self.gpio_manager, 
            self.audio_manager, 
            self.display_manager,
            self.usb_manager  # Passer le gestionnaire USB
        )
        
        # IMPORTANT: Initialiser le DialerManager AVANT ParamsMenuManager
        self.dialer_manager = DialerManager(
            self.gpio_manager, 
            self.display_manager,
            self.usb_manager  # Passer le gestionnaire USB au lieu de la liste
        )
        
        # MAINTENANT initialiser ParamsMenuManager (nouveau nom) après que dialer_manager existe
        self.params_menu_manager = ParamsMenuManager(
            self.display_manager,
            self.dialer_manager,
            self.usb_manager,
            self.audio_manager,
            self.gpio_manager
        )
        
        # Initialiser le gestionnaire de mises à jour
        self.update_manager = UpdateManager(self.usb_manager)
        
        # Affichage des informations de configuration
        config_info = self.usb_manager.get_config_info()
        print(f"=== CONFIGURATION TIMETVOX ===")
        print(f"Numéro principal: {config_info['numero_principal']} ({config_info['longueur_numero_principal']} chiffres)")
        print(f"Numéros de service: {list(SERVICE_NUMBERS.keys())}")  # Maintenant juste ["0000"]
        print(f"Durée d'enregistrement: {config_info['duree_enregistrement']}s")
        print(f"Volume audio: {config_info['volume_audio']}%")

        # Affichage des paramètres de filtre
        try:
            from audio_effects import AudioEffects
            audio_effects = AudioEffects(self.usb_manager)
            filter_config = audio_effects.get_filter_config()
            print(f"Filtre vintage: {'✅ Activé' if filter_config['enabled'] else '❌ Désactivé'}")
            if filter_config['enabled']:
                print(f"  - Type: {filter_config['type']}")
                print(f"  - Intensité: {filter_config['intensity']}")
                print(f"  - Conserver original: {'Oui' if filter_config['keep_original'] else 'Non'}")
        except:
            print(f"Filtre vintage: ❓ Non configuré")

        # Affichage version actuelle
        try:
            current_version = self.update_manager.get_current_version()
            print(f"Version TimeVox: {current_version}")
        except:
            print(f"Version TimeVox: Inconnue")

        print(f"Clé USB: {'✅ Détectée' if config_info['usb_available'] else '❌ Non détectée'}")
        print(f"RTC: {'✅ Opérationnel' if config_info.get('rtc_available', False) else '❌ Non disponible'}")
        print(f"Heure: {config_info.get('current_time', 'N/A')}")
        print(f"===============================")
        
        print("Initialisation terminée. Attente stabilisation...")
        time.sleep(5)
        
        # Vérifier les mises à jour au démarrage
        self.check_updates_at_startup()
        
        # Effacer le message d'initialisation
        self.display_manager.clear_display()
        
        print("Prêt à détecter un numéro fait au cadran.")
    
    def check_updates_at_startup(self):
        """Vérifie s'il y a une mise à jour disponible au démarrage"""
        try:
            print("🔄 Vérification des mises à jour au démarrage...")
            if self.update_manager.check_update_at_startup():
                print("📢 Mise à jour disponible - affichage sur OLED")
                from oled_display import afficher
                afficher("", "MAJ disponible", "", taille=14, align="centre")
                time.sleep(3)
            else:
                print("✅ Aucune mise à jour disponible")
        except Exception as e:
            print(f"Erreur vérification MAJ au démarrage: {e}")
    
    def handle_numero_principal(self):
        """Traite l'appel au numéro principal (annonce + enregistrement)"""
        print("🎵 Activation du son...")
        self.gpio_manager.enable_sound()
        time.sleep(0.5)  # Laisser le temps au son de s'activer

        # Lecture du fichier de recherche de correspondant
        search_path = self.audio_manager.get_search_correspondant_path()
        if search_path:
            print("📢 Fichier search_correspondant trouvé, lecture en cours...")
            if not self.audio_manager.play_audio(search_path):
                print("❌ Échec lecture search_correspondant")
                self.gpio_manager.disable_sound()
                return

        # Lecture de l'annonce principale
        announce_path = self.usb_manager.get_announce_path()
        print(f"DEBUG: announce_path retourné = {announce_path}")
        if announce_path:
            print(f"📢 Lecture annonce principale: {announce_path}")
            if not self.audio_manager.play_audio(announce_path):
                print("❌ Échec lecture annonce principale")
                self.gpio_manager.disable_sound()
                return
        else:
            print("❌ Annonce non disponible - clé USB non détectée")
            self.gpio_manager.disable_sound()
            return

        print("🔇 Coupure du son...")
        self.gpio_manager.disable_sound()

        # Vérification que le téléphone est toujours décroché
        if self.gpio_manager.is_phone_off_hook():
            # Génération du nom de fichier d'enregistrement
            nom_fichier = self.usb_manager.generate_message_filename()
            if nom_fichier:
                # Utiliser la durée configurée depuis la clé USB
                duree_config = self.usb_manager.get_duree_enregistrement()
                print(f"🎙️ Début enregistrement: {nom_fichier} (durée: {duree_config}s)")
                self.recording_manager.record_message(
                    duration=duree_config, 
                    output_file=nom_fichier
                )
            else:
                print("❌ Impossible d'enregistrer - clé USB non disponible")
        else:
            print("📞 Téléphone raccroché - pas d'enregistrement")
    
    def handle_number_0000(self):
        """Traite l'appel au numéro 0000 (accès paramètres)"""
        self.gpio_manager.disable_sound()
        print("🔧 Accès paramètres (0000)")
        
        # Nouveau menu de paramètres unifié
        self.params_menu_manager.start_params_menu()
    
    def handle_phone_hangup(self):
        """Traite le raccrochage du téléphone"""
        # Arrêt de la composition
        if self.dialer_manager.is_composing():
            print("📞 Raccrochage pendant composition - reset")
            self.dialer_manager.reset_dialing(clear_display=True)

        # Arrêt de l'enregistrement
        if self.recording_manager.recording_active:
            if self.recording_manager.recording_started:
                print("🎙️ Raccrochage pendant enregistrement")
                self.display_manager.show_saving()
                self.recording_manager.stop_recording()
            else:
                print("📞 Raccrochage avant début enregistrement")
                self.recording_manager.recording_active = False

        # Arrêt de la musique si en cours
        self.audio_manager.stop_audio()
        self.gpio_manager.disable_sound()
        
        # Effacer l'écran
        self.display_manager.clear_display()
        
    def setup_shutdown_button(self):
        """Configure le bouton d'arrêt et la LED power"""
        # Utiliser le GPIO manager existant
        self.gpio_manager.setup_input_pin(self.shutdown_button_gpio)
        self.gpio_manager.setup_output_pin(self.shutdown_led_gpio)
        self.gpio_manager.gpio_write(self.shutdown_led_gpio, True)  # LED power allumée
        print(f"🔘 Bouton d'arrêt configuré sur GPIO {self.shutdown_button_gpio}")
        print(f"💡 LED power allumée sur GPIO {self.shutdown_led_gpio}")
        
    def check_shutdown_button(self):
        """Vérifie l'état du bouton d'arrêt"""
        if self.shutdown_in_progress:
            return
            
        button_pressed = not self.gpio_manager.gpio_read(self.shutdown_button_gpio)
        
        if button_pressed:
            if self.shutdown_button_pressed_time is None:
                # Début de l'appui
                self.shutdown_button_pressed_time = time.time()
                self.display_manager.show_shutdown_message("Arret en cours...")
                print("🔘 Bouton d'arrêt pressé - décompte démarré")
                
            # Vérifier durée d'appui
            press_duration = time.time() - self.shutdown_button_pressed_time
            
            # Faire clignoter la LED pendant l'appui
            if int(press_duration * 4) % 2 == 0:  # 2 Hz
                self.gpio_manager.gpio_write(self.shutdown_led_gpio, True)
            else:
                self.gpio_manager.gpio_write(self.shutdown_led_gpio, False)
                
            # Arrêt après 3 secondes
            if press_duration >= 3:
                self.initiate_shutdown()
                
        else:
            if self.shutdown_button_pressed_time is not None:
                # Bouton relâché avant 3 secondes
                self.shutdown_button_pressed_time = None
                self.gpio_manager.gpio_write(self.shutdown_led_gpio, True)  # LED fixe
                self.display_manager.clear_display()
                print("🔘 Bouton d'arrêt relâché - annulation")

    def initiate_shutdown(self):
        """Lance la procédure d'arrêt"""
        if self.shutdown_in_progress:
            return
            
        self.shutdown_in_progress = True
        print("=== ARRÊT SYSTÈME DEMANDÉ ===")
        
        # Messages successifs sur l'écran
        self.display_manager.show_shutdown_message("Fermeture...")
        time.sleep(1)
        
        self.display_manager.show_shutdown_message("Sauvegarde...")
        time.sleep(1)
        
        self.display_manager.show_shutdown_message("Au revoir!")
        time.sleep(1)
        
        # Éteindre la LED juste avant l'arrêt
        self.gpio_manager.gpio_write(self.shutdown_led_gpio, False)
        
        # Nettoyer et arrêter
        self.cleanup()
        
        # Arrêt système
        subprocess.run(["sudo", "shutdown", "-h", "now"])
    
    def run(self):
        """Boucle principale du contrôleur"""
        try:
            while True:
                # Vérifier le bouton d'arrêt EN PREMIER
                self.check_shutdown_button()
                
                # Si arrêt en cours, sortir de la boucle
                if self.shutdown_in_progress:
                    break
                
                phone_off_hook = self.gpio_manager.is_phone_off_hook()
                
                if not phone_off_hook:
                    # Téléphone raccroché
                    self.handle_phone_hangup()
                else:
                    # Téléphone décroché
                    if (not self.dialer_manager.is_composing() and 
                        not self.recording_manager.recording_active):
                        # Afficher TIMEVOX si aucune activité
                        self.display_manager.show_timevox()
                    
                    # Traitement du cadran avec la nouvelle logique
                    completed_number = self.dialer_manager.process_dialing()
                    if completed_number:
                        # Maintenir l'affichage du numéro pendant le traitement
                        self.display_manager.show_calling_number(completed_number)
                        
                        # Traitement selon le type de numéro reconnu
                        numero_principal = self.usb_manager.get_numero_principal()
                        
                        if completed_number == numero_principal:
                            print(f"📞 Appel numéro principal: {completed_number}")
                            self.handle_numero_principal()
                        elif completed_number == "0000":
                            print(f"🔧 Appel paramètres: {completed_number}")
                            self.handle_number_0000()
                        else:
                            print(f"❓ Numéro non géré: {completed_number}")
                        
                        # Effacer seulement après traitement complet
                        self.display_manager.clear_display()

                time.sleep(0.005)  # Petite pause pour éviter la surcharge CPU
                
        except KeyboardInterrupt:
            print("\n⛔ Arrêt demandé par l'utilisateur")
        finally:
            self.cleanup()
    
    def cleanup(self):
        """Nettoyage des ressources"""
        print("🧹 Nettoyage des ressources...")
        
        # Éteindre la LED power
        try:
            self.gpio_manager.gpio_write(self.shutdown_led_gpio, False)
        except:
            pass
            
        # Effacer l'écran
        self.display_manager.clear_display()
        
        # Nettoyage GPIO original
        self.gpio_manager.cleanup()
        
        print("👋 TimeVox arrêté.")