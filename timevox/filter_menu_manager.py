# filter_menu_manager.py
"""
Gestionnaire du menu de configuration des filtres vintage
Accessible via le numéro 0000 (diagnostics/paramètres)
"""

import time
import json
import os
from config import AVAILABLE_FILTERS, MSG_FILTER_CONFIG, MSG_FILTER_TYPE, MSG_FILTER_INTENSITY
from audio_effects import AudioEffects


class FilterMenuManager:
    def __init__(self, display_manager, dialer_manager, usb_manager, audio_manager, gpio_manager):
        self.display_manager = display_manager
        self.dialer_manager = dialer_manager
        self.usb_manager = usb_manager
        self.audio_manager = audio_manager
        self.gpio_manager = gpio_manager
        self.audio_effects = AudioEffects(usb_manager)
        
        # État du menu
        self.menu_active = False
        self.current_step = 0  # 0=type, 1=intensité, 2=récapitulatif, 3=sauvegarde
        self.selected_filter = "radio_50s"
        self.selected_intensity = 0.7
        
    def start_filter_menu(self):
        """Démarre le menu de configuration des filtres"""
        print("🎛️ Démarrage menu configuration filtres")
        self.menu_active = True
        self.current_step = 0
        
        # Charger la config actuelle
        config = self.audio_effects.get_filter_config()
        self.selected_filter = config.get("type", "radio_50s")
        self.selected_intensity = config.get("intensity", 0.7)
        
        # Affichage initial
        self.display_manager.clear_display()
        self.display_step()
        
        return self.run_menu_loop()
    
    def display_step(self):
        """Affiche l'étape actuelle du menu"""
        from oled_display import afficher
        
        if self.current_step == 0:
            # Sélection du type de filtre
            filter_names = {
                "aucun": "Aucun",
                "radio_50s": "Radio 50s",
                "telephone": "Telephone", 
                "gramophone": "Gramophone"
            }
            filter_display = filter_names.get(self.selected_filter, self.selected_filter)
            afficher(
                MSG_FILTER_TYPE,
                filter_display,
                "Cadran: changer",
                taille=12, align="centre"
            )
            
        elif self.current_step == 1:
            # Sélection de l'intensité
            intensity_percent = int(self.selected_intensity * 100)
            afficher(
                MSG_FILTER_INTENSITY,
                f"{intensity_percent}%",
                "Cadran: ajuster",
                taille=12, align="centre"
            )
            
        elif self.current_step == 2:
            # Récapitulatif avant sauvegarde
            filter_names = {
                "aucun": "Aucun",
                "radio_50s": "Radio 50s",
                "telephone": "Telephone", 
                "gramophone": "Gramophone"
            }
            filter_display = filter_names.get(self.selected_filter, self.selected_filter)
            intensity_percent = int(self.selected_intensity * 100)
            
            afficher(
                f"{filter_display}",
                f"Intensite: {intensity_percent}%",
                "0=sauver, autre=ann",
                taille=10, align="centre"
            )
            
        elif self.current_step == 3:
            # Confirmation sauvegarde
            afficher(
                "Sauvegarder?",
                "0=oui, autre=non",
                "",
                taille=12, align="centre"
            )
    
    def run_menu_loop(self):
        """Boucle principale du menu"""
        print("🎛️ Démarrage boucle menu filtres")
        
        while self.menu_active:
            # Vérifier si téléphone raccroché
            if self.gpio_manager.is_phone_on_hook():
                print("📞 Raccrochage - sortie menu filtres")
                self.menu_active = False
                break
            
            # Attendre un chiffre avec la méthode éprouvée
            print(f"En attente d'un chiffre pour l'étape {self.current_step}...")
            digit = self.dialer_manager.wait_for_menu_digit(timeout_seconds=30)
            
            if digit is None:
                print("⏰ Timeout ou raccrochage menu filtres")
                self.menu_active = False
                break
            
            print(f"Menu filtres - Étape {self.current_step}, Chiffre reçu: {digit}")
            self.handle_menu_input(digit)
        
        # Nettoyage
        self.display_manager.clear_display()
        return True
    
    def handle_menu_input(self, number):
        """Traite les entrées du menu selon l'étape actuelle"""
        print(f"Menu filtres - Étape {self.current_step}, Input: {number}")
        
        if self.current_step == 0:
            # Sélection du type de filtre
            self.handle_filter_type_selection(number)
            
        elif self.current_step == 1:
            # Ajustement de l'intensité
            self.handle_intensity_adjustment(number)
            
        elif self.current_step == 2:
            # Récapitulatif - passage à la sauvegarde
            if number == "0":
                self.current_step = 3
                self.display_step()
            else:
                # Annuler - retour au début
                print("🔄 Annulation - retour au début")
                self.current_step = 0
                self.display_step()
                
        elif self.current_step == 3:
            # Sauvegarde
            if number == "0":
                self.save_filter_config()
            self.menu_active = False
    
    def handle_filter_type_selection(self, number):
        """Gère la sélection du type de filtre"""
        filter_mapping = {
            "0": "aucun",
            "1": "radio_50s", 
            "2": "telephone",
            "3": "gramophone"
        }
        
        if number in filter_mapping:
            self.selected_filter = filter_mapping[number]
            print(f"Filtre sélectionné: {self.selected_filter}")
            self.current_step = 1
            self.display_step()
        elif number == "9":  # Passer à l'étape suivante
            self.current_step = 1
            self.display_step()
    
    def handle_intensity_adjustment(self, number):
        """Gère l'ajustement de l'intensité"""
        intensity_mapping = {
            "0": 0.0,   # Pas d'effet
            "1": 0.1,   # Très léger
            "2": 0.2,   # Léger
            "3": 0.3,   # Modéré-
            "4": 0.4,   # Modéré
            "5": 0.5,   # Modéré+
            "6": 0.6,   # Fort-
            "7": 0.7,   # Fort (défaut)
            "8": 0.8,   # Fort+
            "9": 0.9,   # Maximum
        }
        
        if number in intensity_mapping:
            self.selected_intensity = intensity_mapping[number]
            print(f"Intensité sélectionnée: {self.selected_intensity}")
            self.current_step = 2  # Aller au récapitulatif
            self.display_step()
    
    def save_filter_config(self):
        """Sauvegarde la configuration des filtres"""
        print(f"💾 Sauvegarde config filtre: {self.selected_filter}, intensité: {self.selected_intensity}")
        
        from oled_display import afficher
        
        if not self.usb_manager.is_usb_available():
            afficher(
                "Erreur",
                "Cle USB requise",
                "",
                taille=12, align="centre"
            )
            time.sleep(2)
            return False
        
        try:
            # Charger la config existante
            usb_path = self.usb_manager.usb_path
            config_file = os.path.join(usb_path, "Parametres", "config.json")
            
            config_data = {}
            if os.path.exists(config_file):
                with open(config_file, 'r', encoding='utf-8') as f:
                    config_data = json.load(f)
            
            # Ajouter/modifier les paramètres de filtre
            config_data.update({
                "filtre_vintage": self.selected_filter != "aucun",
                "type_filtre": self.selected_filter,
                "intensite_filtre": self.selected_intensity,
                "conserver_original": True
            })
            
            # Sauvegarder
            with open(config_file, 'w', encoding='utf-8') as f:
                json.dump(config_data, f, indent=2, ensure_ascii=False)
            
            # Recharger la config dans le gestionnaire d'effets
            self.audio_effects = AudioEffects(self.usb_manager)
            
            # Afficher confirmation
            afficher(
                "Config",
                "sauvegardee!",
                "",
                taille=12, align="centre"
            )
            time.sleep(2)
            
            print("✅ Configuration filtre sauvegardée")
            return True
            
        except Exception as e:
            print(f"Erreur sauvegarde config: {e}")
            afficher(
                "Erreur",
                "sauvegarde",
                "",
                taille=12, align="centre"
            )
            time.sleep(2)
            return False