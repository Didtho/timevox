#!/usr/bin/env python3
"""
Script de gestion du bouton d'arrêt pour Raspberry Pi
Compatible avec le projet TimeVox
"""

import RPi.GPIO as GPIO
import subprocess
import time
import signal
import sys
import os

# Ajouter le répertoire du projet au path pour importer oled_display
project_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, project_dir)
print(f"Répertoire du projet: {project_dir}")

try:
    from oled_display import afficher as afficher_texte
    OLED_AVAILABLE = True
    print("✅ Module OLED importé avec succès")
except ImportError as e:
    print(f"❌ Module OLED non disponible: {e}")
    OLED_AVAILABLE = False
except Exception as e:
    print(f"❌ Erreur import OLED: {e}")
    OLED_AVAILABLE = False

# Configuration
SHUTDOWN_GPIO = 26  # Pin GPIO pour le bouton d'arrêt (GPIO libre sur TimeVox)
HOLD_TIME = 3       # Durée d'appui nécessaire en secondes

class ShutdownManager:
    def __init__(self):
        self.shutdown_in_progress = False
        self.LED_GPIO = 16
        self.setup_gpio()
        self.setup_signal_handlers()
        self.setup_power_led()
    
    def setup_gpio(self):
        """Configure le GPIO pour le bouton d'arrêt"""
        GPIO.setmode(GPIO.BCM)
        GPIO.setwarnings(False)
        GPIO.setup(SHUTDOWN_GPIO, GPIO.IN, pull_up_down=GPIO.PUD_UP)
        GPIO.setup(self.LED_GPIO, GPIO.OUT)
        print(f"Bouton d'arrêt configuré sur GPIO {SHUTDOWN_GPIO}")
        print(f"LED power configurée sur GPIO {self.LED_GPIO}")
    
    def setup_power_led(self):
        """Allume la LED power au démarrage"""
        try:
            GPIO.output(self.LED_GPIO, GPIO.HIGH)
            print("LED power allumée - système prêt")
        except Exception as e:
            print(f"Erreur LED power: {e}")
    
    def setup_signal_handlers(self):
        """Configure les gestionnaires de signaux pour un arrêt propre"""
        signal.signal(signal.SIGINT, self.signal_handler)
        signal.signal(signal.SIGTERM, self.signal_handler)
    
    def signal_handler(self, signum, frame):
        """Gestionnaire pour les signaux d'arrêt"""
        print(f"\nSignal {signum} reçu, arrêt du service...")
        try:
            # Éteindre la LED si possible
            if hasattr(self, 'LED_GPIO'):
                GPIO.output(self.LED_GPIO, GPIO.LOW)
            # Effacer l'écran
            self.clear_display()
        except:
            pass
        finally:
            try:
                GPIO.cleanup()
            except:
                pass
        sys.exit(0)
    
    def display_shutdown_message(self, message):
        """Affiche un message sur l'écran OLED ou en console"""
        print(f"🖥️  Message d'arrêt: '{message}'")
        if OLED_AVAILABLE:
            try:
                afficher_texte("", message, "", taille=16, align="centre")
                print(f"✅ Message OLED affiché: {message}")
            except Exception as e:
                print(f"❌ Erreur affichage OLED: {e}")
                # Fallback : affichage console uniquement
                print(f"📺 CONSOLE: {message}")
        else:
            print(f"📺 CONSOLE (OLED indisponible): {message}")
    
    def clear_display(self):
        """Efface l'écran OLED"""
        print("🖥️  Effacement écran")
        if OLED_AVAILABLE:
            try:
                afficher_texte("", "", "", taille=14, align="centre")
                print("✅ Écran OLED effacé")
            except Exception as e:
                print(f"❌ Erreur effacement OLED: {e}")
        else:
            print("📺 Écran OLED non disponible")
    
    def is_button_pressed(self):
        """Vérifie si le bouton est pressé (logique inversée avec pull-up)"""
        return not GPIO.input(SHUTDOWN_GPIO)
    
    def blink_led_countdown(self, duration):
        """
        Fait clignoter la LED pendant le décompte
        LED connectée sur GPIO 16
        """
        # Afficher message de décompte sur OLED
        self.display_shutdown_message("Arret en cours...")
        
        try:
            # La LED est déjà allumée, commencer directement le clignotement
            for i in range(duration * 2):  # Clignote 2 fois par seconde
                if not self.is_button_pressed():  # Vérifier si bouton relâché
                    # Remettre la LED en position "power on" si bouton relâché
                    GPIO.output(self.LED_GPIO, GPIO.HIGH)
                    # Effacer le message d'arrêt
                    self.clear_display()
                    print("Bouton relâché - LED power rétablie")
                    return False
                
                # Alterner l'état de la LED
                if i % 2 == 0:
                    GPIO.output(self.LED_GPIO, GPIO.LOW)   # Éteindre
                else:
                    GPIO.output(self.LED_GPIO, GPIO.HIGH)  # Allumer
                
                time.sleep(0.25)
            
            # Laisser la LED allumée à la fin du décompte (avant arrêt)
            GPIO.output(self.LED_GPIO, GPIO.HIGH)
            return True
            
        except Exception as e:
            print(f"Erreur LED sur GPIO {self.LED_GPIO}: {e}")
            # Fallback sans LED si erreur
            start_time = time.time()
            while time.time() - start_time < duration:
                if not self.is_button_pressed():
                    self.clear_display()
                    return False
                time.sleep(0.1)
            return True
    
    def shutdown_system(self):
        """Effectue l'arrêt du système"""
        if self.shutdown_in_progress:
            return
        
        self.shutdown_in_progress = True
        print("ARRÊT DU SYSTÈME EN COURS...")
        
        # GARDER la LED allumée pendant les opérations d'arrêt
        # Elle ne s'éteindra qu'au tout dernier moment
        
        try:
            # Afficher message d'arrêt sur OLED
            self.display_shutdown_message("Fermeture...")
            
            # Envoyer un signal de terminaison aux processus TimeVox
            print("Arrêt des processus TimeVox...")
            subprocess.run(["pkill", "-TERM", "-f", "main_timevox.py"], 
                         capture_output=True, timeout=5)
            time.sleep(1)
            
            # Message intermédiaire
            self.display_shutdown_message("Sauvegarde...")
            
            # Synchroniser les disques
            print("Synchronisation des disques...")
            subprocess.run(["sync"], timeout=10)
            time.sleep(1)
            
            # Message final
            self.display_shutdown_message("Au revoir!")
            time.sleep(1)
            
            # MAINTENANT éteindre la LED juste avant l'arrêt final
            print("Extinction LED - arrêt imminent...")
            try:
                GPIO.output(self.LED_GPIO, GPIO.LOW)
            except:
                pass
            
            # Effacer l'écran avant arrêt complet
            self.clear_display()
            
            # Arrêt système
            print("Arrêt système...")
            subprocess.run(["sudo", "shutdown", "-h", "now"], timeout=5)
            
        except subprocess.TimeoutExpired:
            print("Timeout lors de l'arrêt, forçage...")
            self.display_shutdown_message("Arret force!")
            time.sleep(1)
            # Éteindre LED avant forçage
            try:
                GPIO.output(self.LED_GPIO, GPIO.LOW)
            except:
                pass
            self.clear_display()
            subprocess.run(["sudo", "halt", "-f"])
        except Exception as e:
            print(f"Erreur lors de l'arrêt: {e}")
            self.display_shutdown_message("Erreur arret!")
            time.sleep(1)
            # Éteindre LED avant forçage
            try:
                GPIO.output(self.LED_GPIO, GPIO.LOW)
            except:
                pass
            self.clear_display()
            subprocess.run(["sudo", "halt", "-f"])
    
    def run(self):
        """Boucle principale de surveillance du bouton"""
        print("Service bouton d'arrêt démarré")
        print(f"Maintenez le bouton GPIO {SHUTDOWN_GPIO} pendant {HOLD_TIME}s pour arrêter")
        print(f"LED power sur GPIO {self.LED_GPIO} reste allumée (clignote pendant l'arrêt)")
        
        try:
            while True:
                if self.is_button_pressed():
                    print(f"Bouton pressé, décompte de {HOLD_TIME}s...")
                    print("LED clignote pendant le décompte...")
                    
                    # Vérifier que le bouton reste pressé pendant HOLD_TIME
                    if self.blink_led_countdown(HOLD_TIME):
                        print("Durée d'appui atteinte - Démarrage procédure d'arrêt")
                        print("LED reste allumée pendant l'arrêt des services...")
                        self.shutdown_system()
                        break
                    else:
                        print("Bouton relâché - annulation arrêt")
                
                time.sleep(0.1)  # Vérification toutes les 100ms
                
        except KeyboardInterrupt:
            print("\nArrêt du service bouton d'arrêt")
        finally:
            self.cleanup()
    
    def cleanup(self):
        """Nettoyage des ressources GPIO"""
        print("Nettoyage en cours...")
        try:
            # Effacer l'écran OLED
            self.clear_display()
        except Exception as e:
            print(f"Erreur effacement OLED: {e}")
        
        try:
            # Éteindre la LED si elle existe
            if hasattr(self, 'LED_GPIO'):
                GPIO.output(self.LED_GPIO, GPIO.LOW)
                print("LED éteinte")
        except Exception as e:
            print(f"Erreur LED: {e}")
        
        try:
            # Nettoyage GPIO final
            GPIO.cleanup()
            print("GPIO nettoyés")
        except Exception as e:
            print(f"Erreur nettoyage GPIO: {e}")

def main():
    """Point d'entrée principal"""
    shutdown_manager = ShutdownManager()
    shutdown_manager.run()

if __name__ == "__main__":
    main()