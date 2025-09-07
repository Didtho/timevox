# special_audio_manager.py
"""
Gestionnaire des numeros speciaux avec lecture de fichiers MP3
Gere les numeros 12, 13, 14, 17 et 18
"""

import os
import pygame
from config import (
    get_special_audio_file_path, 
    is_special_audio_number,
    MSG_SPECIAL_NUMBER,
    MSG_PLAYING_AUDIO,
    MSG_CALL_ENDED
)

class SpecialAudioManager:
    def __init__(self, gpio_manager, display_manager, usb_manager, audio_manager):
        self.gpio_manager = gpio_manager
        self.display_manager = display_manager
        self.usb_manager = usb_manager
        self.audio_manager = audio_manager
        
        print("SpecialAudioManager initialise")
    
    def handle_special_number(self, number):
        """
        Gere un numero special : affiche le numero, joue le fichier MP3 et raccroche
        Retourne True si le numero a ete traite avec succes, False sinon
        """
        print(f"Traitement numero special: {number}")
        
        # Verifier que c'est bien un numero special
        if not is_special_audio_number(number):
            print(f"{number} n'est pas un numero special audio")
            return False
        
        # Obtenir le chemin du fichier audio
        usb_path = self.usb_manager.get_usb_mount_path()
        audio_file_path = get_special_audio_file_path(number, usb_path)
        
        if not audio_file_path:
            print(f"Fichier audio non trouve pour le numero {number}")
            self.display_error_and_hangup(f"Fichier {number}.mp3", "introuvable")
            return False
        
        print(f"Fichier audio trouve: {audio_file_path}")
        
        # Afficher le numero special sur l'ecran
        # self.display_manager.show_special_number(number)
        
        # Jouer le fichier MP3
        success = self.play_special_audio(audio_file_path, number)
        
        if success:
            print(f"Lecture terminee pour le numero {number}")
            self.display_call_ended()
        else:
            print(f"Erreur lors de la lecture du numero {number}")
            self.display_error_and_hangup("Erreur lecture", f"numero {number}")
        
        return success
    
    def play_special_audio(self, audio_file_path, number):
        """
        Joue le fichier audio special jusqu'a la fin ou jusqu'a ce que le telephone soit raccroche
        Retourne True si la lecture s'est bien deroulee, False en cas d'erreur
        """
        try:
            print(f"Debut lecture: {audio_file_path}")
            
            # Afficher le message de lecture
            self.display_manager.show_message(
                MSG_PLAYING_AUDIO,
                f"- {number} -",
                ""
            )
            
            # Charger et jouer le fichier
            self.gpio_manager.enable_sound()
            self.audio_manager.play_audio(audio_file_path)
            self.gpio_manager.disable_sound()
            
            print(f"Lecture terminee normalement pour {number}")
            return True
            
        except pygame.error as e:
            print(f"Erreur lors de la lecture de {audio_file_path}: {e}")
            return False
        except Exception as e:
            print(f"Erreur inattendue lors de la lecture de {audio_file_path}: {e}")
            return False
    
    def display_error_and_hangup(self, line1, line2):
        """Affiche un message d'erreur puis le message d'appel termine"""
        self.display_manager.show_message(line1, line2, "", size=12)
        pygame.time.wait(2000)  # Attendre 2 secondes
        self.display_call_ended()
    
    def display_call_ended(self):
        """Affiche le message d'appel termine"""
        self.display_manager.show_message(MSG_CALL_ENDED, "", "", size=14)
        pygame.time.wait(2000)  # Attendre 2 secondes avant de nettoyer l'affichage
    
    def check_special_numbers_availability(self):
        """
        Verifie quels numeros speciaux sont disponibles (fichiers presents)
        Retourne un dictionnaire avec le statut de chaque numero
        """
        usb_path = self.usb_manager.get_usb_mount_path()
        special_numbers = ["12", "13", "14", "17", "18"]
        availability = {}
        
        for number in special_numbers:
            audio_file_path = get_special_audio_file_path(number, usb_path)
            availability[number] = {
                "available": audio_file_path is not None,
                "file_path": audio_file_path
            }
            
        print(f"Statut des numeros speciaux: {availability}")
        return availability
    
    def get_status_info(self):
        """Retourne des informations sur l'etat du gestionnaire de numeros speciaux"""
        return {
            "special_numbers": ["12", "13", "14", "17", "18"],
            "availability": self.check_special_numbers_availability(),
            "usb_mount_path": self.usb_manager.get_usb_mount_path()
        }