# display_manager.py
"""
Gestionnaire de l'affichage OLED
"""

from oled_display import afficher as afficher_texte
from config import (
    MSG_TIMEVOX, MSG_CALLING, MSG_SAVING, MSG_CALL_ENDED, MSG_SECONDS,
    TIMEVOX_FONT_SIZE, CALLING_FONT_SIZE, COUNTDOWN_FONT_SIZE,
    SAVING_FONT_SIZE, CALL_ENDED_FONT_SIZE
)


class DisplayManager:
    def __init__(self):
        self.timevox_displayed = False

    def show_timevox(self):
        """Affiche le message TIMEVOX"""
        if not self.timevox_displayed:
            print("Affichage TIMEVOX")
            afficher_texte("", MSG_TIMEVOX, "", taille=TIMEVOX_FONT_SIZE, align="centre")
            self.timevox_displayed = True

    def show_calling_number(self, number):
        """Affiche le numéro en cours de composition"""
        afficher_texte(MSG_CALLING, "", number, taille=CALLING_FONT_SIZE, align="centre")
        self.timevox_displayed = False  # Une fois qu'on compose, ne plus afficher TIMEVOX

    def show_countdown(self, seconds_remaining):
        """Affiche le compte à rebours pendant l'enregistrement"""
        afficher_texte("", str(seconds_remaining), "",  # Enlever MSG_SECONDS
                       taille=COUNTDOWN_FONT_SIZE, align="centre")

    def show_saving(self):
        """Affiche le message de sauvegarde"""
        afficher_texte("", MSG_SAVING, "", taille=SAVING_FONT_SIZE, align="centre")

    def show_call_ended(self):
        """Affiche le message de fin d'appel"""
        afficher_texte("", MSG_CALL_ENDED, "", taille=CALL_ENDED_FONT_SIZE, align="centre")

    def clear_display(self):
        """Efface l'écran OLED"""
        try:
            afficher_texte("", "", "", taille=14, align="centre")
            self.timevox_displayed = False
        except Exception as e:
            print(f"Erreur effacement écran: {e}")

    def reset_timevox_flag(self):
        """Remet à zéro le flag d'affichage TIMEVOX"""
        self.timevox_displayed = False

    def show_initialization(self):
        """Affiche le message d'initialisation au démarrage"""
        print("Affichage message d'initialisation")
        afficher_texte("Initialisation", "TimeVox", "en cours...", taille=14, align="centre")

    def show_shutdown_message(self, message):
        """Affiche un message d'arrêt système"""

        afficher_texte("", message, "", taille=16, align="centre")
        print(f"Message d'arrêt affiché: {message}")
    
    def show_unknown_message(self):
        """Affiche un message de numéro inconnu"""

        afficher_texte("", "Numéro inconnu", "", taille=16, align="centre")
        print(f"Message numéro inconnu")
    
    def show_special_number(self, number):
        """Affiche le numéro spécial composé"""
        from config import MSG_SPECIAL_NUMBER
    
        print(f"Affichage numéro spécial: {number}")
        
        # Utiliser afficher_texte comme les autres méthodes
        afficher_texte(MSG_SPECIAL_NUMBER, number, "", taille=16, align="centre")
        self.timevox_displayed = False

    def show_message(self, line1, line2="", line3="", size=12, align="centre"):
        """Affiche un message personnalisé sur 1 à 3 lignes"""
        print(f"Affichage message: {line1} | {line2} | {line3}")
        
        # Utiliser afficher_texte comme les autres méthodes
        # Pour 3 lignes, utiliser line1, line2, line3
        # Pour 2 lignes, mettre line3 vide
        # Pour 1 ligne, centrer dans line2
        if line3:
            afficher_texte(line1, line2, line3, taille=size, align=align)
        elif line2:
            afficher_texte(line1, line2, "", taille=size, align=align)
        else:
            afficher_texte("", line1, "", taille=size, align=align)