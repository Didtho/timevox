# recording_manager.py
"""
Gestionnaire d'enregistrement des messages vocaux
"""

import subprocess
import threading
import time
import os
import re
from datetime import datetime
from pydub import AudioSegment
from config import RECORD_DURATION, AUDIO_CUT_DURATION
from oled_display import afficher as afficher_texte
from audio_effects import AudioEffects


class RecordingManager:
    def __init__(self, gpio_manager, audio_manager, display_manager, usb_manager=None):
        self.gpio_manager = gpio_manager
        self.audio_manager = audio_manager
        self.display_manager = display_manager
        self.usb_manager = usb_manager  # Nouveau paramètre
        self.audio_effects = AudioEffects(usb_manager)  # Nouveau gestionnaire d'effets
        self.recording_process = None
        self.recording_thread = None
        self.recording_active = False
        self.recording_started = False
        self.detected_micro = None
        self.detect_usb_micro_device()
    
    def detect_usb_micro_device(self):
        """Détection rapide du micro USB"""
        try:
            # Méthode rapide: lire directement /proc/asound/cards
            if os.path.exists("/proc/asound/cards"):
                with open("/proc/asound/cards", "r") as f:
                    content = f.read()
                    for line_num, line in enumerate(content.splitlines()):
                        if "USB" in line or "Microphone" in line or "Audio" in line:
                            # Extraire le numéro de carte
                            if line.strip() and line[0].isdigit():
                                card_num = line.split()[0]
                                device_name = f"plughw:{card_num},0"
                                print(f"Micro USB détecté rapidement: {device_name}")
                                self.detected_micro = device_name
                                return device_name

            # Fallback: méthode originale mais plus rapide
            output = subprocess.check_output(["arecord", "-l"], text=True, timeout=2)
            for line in output.splitlines():
                if "USB" in line or "Microphone" in line:
                    match = re.search(r"card (\d+):", line)
                    if match:
                        card_num = match.group(1)
                        device_name = f"plughw:{card_num},0"
                        print(f"Micro USB détecté: {device_name}")
                        self.detected_micro = device_name
                        return device_name

        except Exception as e:
            print(f"Erreur détection micro: {e}")

        print("Aucun micro USB détecté")
        self.detected_micro = None
        return None
    
    def trim_audio_file(self, input_file):
        """Supprime les premières et dernières secondes d'un fichier audio"""
        if not os.path.exists(input_file):
            print(f"Fichier {input_file} inexistant")
            return False

        # Vérifier que le fichier n'est pas vide
        if os.path.getsize(input_file) == 0:
            print("Fichier vide, pas de coupe possible")
            return False

        try:
            # Charger le MP3
            audio = AudioSegment.from_mp3(input_file)

            # Supprimer la première et dernière seconde
            audio_modifie = audio[AUDIO_CUT_DURATION:-AUDIO_CUT_DURATION]

            # Sauvegarder dans un fichier temporaire
            temp_file = input_file.replace(".mp3", "_temp.mp3")
            audio_modifie.export(temp_file, format="mp3")

            # Remplacer le fichier original par le fichier modifié
            os.replace(temp_file, input_file)

            print(f"Le fichier {input_file} a été modifié (première et dernière secondes supprimées).")
            return True
        except Exception as e:
            print(f"Erreur lors de la coupe du fichier: {e}")
            return False
    
    def display_countdown(self, duration, output_file):
        """Affiche le compteur de temps restant pendant l'enregistrement"""
        for i in range(1, duration + 1):
            if not self.recording_active:  # Arrêt si raccrochage
                break
            temps_restant = duration - i + 1  # Calcul du temps restant
            print(f"{i}s enregistrées...")
            # Afficher le temps restant sur l'écran OLED
            self.display_manager.show_countdown(temps_restant)
            time.sleep(1)

        # Afficher "Appel terminé" si enregistrement complet
        if self.recording_active:
            self.display_manager.show_call_ended()
            time.sleep(2)  # Laisser le message visible 2 secondes
            self.display_manager.clear_display()
    
    def stop_recording(self):
        """Arrête l'enregistrement en cours"""
        if self.recording_process and self.recording_process.poll() is None:
            self.recording_process.terminate()
            self.recording_process.wait()
            self.recording_process = None
        self.recording_active = False
        print("Enregistrement arrêté")
    
    def record_message(self, duration=None, output_file=None):
        """Enregistre un message vocal"""
        if duration is None:
            duration = RECORD_DURATION
        
        # Utiliser le micro pré-détecté
        device = self.detected_micro
        if not device:
            print("Aucun micro disponible.")
            return False

        print(f"Micro prêt: {device}")

        if os.path.exists(output_file):
            os.remove(output_file)

        print("Démarrage de l'enregistrement...")
        self.recording_active = True
        self.recording_started = True

        try:
            # Démarrer ffmpeg
            self.recording_process = subprocess.Popen([
                "ffmpeg", "-f", "alsa", "-ac", "1", "-i", device,
                "-t", str(duration), "-acodec", "libmp3lame",
                "-ab", "128k", "-loglevel", "error", output_file
            ])

            # Attendre que ffmpeg soit vraiment prêt
            print("Attente initialisation enregistrement...")
            timeout = 0
            while not os.path.exists(output_file) and timeout < 100:
                time.sleep(0.1)
                timeout += 1
                if not self.recording_active:
                    break

            if os.path.exists(output_file):
                print("Enregistrement initialisé")

                # Lecture du bip APRÈS que l'enregistrement soit prêt
                bip_path = self.audio_manager.get_bip_path()
                if bip_path:
                    self.gpio_manager.enable_sound()
                    time.sleep(0.1)
                    print("Lecture du bip...")
                    self.audio_manager.play_audio(bip_path)
                    self.gpio_manager.disable_sound()
                else:
                    print("Fichier bip.mp3 non trouvé - pas de bip")

                print("Enregistrement en cours...")
                # Démarrer le compteur
                compteur_thread = threading.Thread(
                    target=self.display_countdown, 
                    args=(duration, output_file)
                )
                compteur_thread.start()
            else:
                print("Échec initialisation enregistrement")
                self.recording_active = False
                return False

            # Attendre la fin du processus ou l'arrêt
            while self.recording_process.poll() is None and self.recording_active:
                # Vérifier l'état du combiné pendant l'enregistrement
                if self.gpio_manager.is_phone_on_hook():
                    print("Raccrochage détecté pendant enregistrement - arrêt")
                    self.display_manager.show_saving()
                    self.recording_active = False
                    break
                time.sleep(0.1)

            if not self.recording_active:
                # Arrêt prématuré - terminer le processus
                self.recording_process.terminate()
                self.recording_process.wait()

        except Exception as e:
            print("Erreur enregistrement :", e)
            self.recording_active = False
            return False

        if 'compteur_thread' in locals():
            compteur_thread.join()

        success = False
        final_file = output_file
        
        if self.recording_active:
            print(f"Fichier enregistré : {output_file}")
            # 1. D'abord couper le début/fin
            if self.trim_audio_file(output_file):
                # 2. Ensuite appliquer les effets vintage si configurés
                print("Application des effets vintage...")
                processed_file = self.audio_effects.process_audio_file(output_file)
                if processed_file:
                    final_file = processed_file
                    print(f"Fichier final avec effets: {final_file}")
                    success = True
                else:
                    print("Erreur application effets - fichier original conservé")
                    success = True  # On considère que c'est un succès même sans effets
            else:
                success = False
        else:
            print("Enregistrement arrêté par raccrochage")
            if os.path.exists(output_file) and os.path.getsize(output_file) > 0:
                print(f"Fichier partiel sauvegardé : {output_file}")
                # Appliquer la coupe ET les effets même sur un fichier partiel
                if self.trim_audio_file(output_file):
                    processed_file = self.audio_effects.process_audio_file(output_file)
                    if processed_file:
                        final_file = processed_file
                        print(f"Fichier partiel avec effets: {final_file}")
                    success = True
            else:
                print("Aucun fichier créé ou fichier vide")
            # Effacer l'écran si arrêt prématuré
            self.display_manager.clear_display()

        self.recording_active = False
        self.recording_started = False
        self.recording_process = None
        
        return success