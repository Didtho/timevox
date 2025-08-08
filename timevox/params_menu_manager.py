# params_menu_manager.py
"""
Gestionnaire du menu de paramètres TimeVox
Accessible via le numéro 0000 (paramètres)
Gère : Diagnostics, Filtres, Système (mises à jour)
"""

import time
import json
import os
from config import AVAILABLE_FILTERS, MSG_FILTER_CONFIG, MSG_FILTER_TYPE, MSG_FILTER_INTENSITY
from audio_effects import AudioEffects
from update_manager import UpdateManager


class ParamsMenuManager:
    def __init__(self, display_manager, dialer_manager, usb_manager, audio_manager, gpio_manager):
        self.display_manager = display_manager
        self.dialer_manager = dialer_manager
        self.usb_manager = usb_manager
        self.audio_manager = audio_manager
        self.gpio_manager = gpio_manager
        self.audio_effects = AudioEffects(usb_manager)
        self.update_manager = UpdateManager(usb_manager)
        
        # État du menu
        self.menu_active = False
        self.current_menu = "main"  # main, diagnostic, filters, system
        self.current_step = 0
        
        # État filtres (conservé de l'ancien code)
        self.selected_filter = "radio_50s"
        self.selected_intensity = 0.7
        
    def start_params_menu(self):
        """Démarre le menu de paramètres principal"""
        print("🎛️ Démarrage menu Paramètres")
        self.menu_active = True
        self.current_menu = "main"
        self.current_step = 0
        
        # Affichage initial
        self.display_manager.clear_display()
        self.display_main_menu()
        
        return self.run_menu_loop()
    
    def display_main_menu(self):
        """Affiche le menu principal des paramètres"""
        from oled_display import afficher
        
        afficher("Paramètres", "1=Diagnostic", "2=Filtres 3=Système", taille=11, align="centre")
    
    def display_diagnostic_menu(self):
        """Affiche les diagnostics système"""
        try:
            from oled_display import afficher
            
            # Récupérer les infos système
            if hasattr(self.usb_manager, 'rtc_manager') and self.usb_manager.rtc_manager:
                rtc_manager = self.usb_manager.rtc_manager
                status_info = rtc_manager.get_status_info()
                
                # Affichage séquentiel des informations
                afficher("Diagnostics", "TimeVox", "", taille=14, align="centre")
                time.sleep(2)
                
                # État du RTC
                rtc_status = "OK" if status_info['rtc_available'] else "NON"
                afficher("Module RTC:", rtc_status, "", taille=12, align="centre")
                time.sleep(2)
                
                # Validité de l'heure
                time_status = "OK" if status_info['time_valid'] else "ERREUR"
                afficher("Heure:", time_status, "", taille=12, align="centre")
                time.sleep(2)
                
                # Afficher l'heure actuelle
                current_time = rtc_manager.get_current_datetime()
                date_str = current_time.strftime("%d/%m/%Y")
                time_str = current_time.strftime("%H:%M:%S")
                afficher(date_str, time_str, "", taille=11, align="centre")
                time.sleep(3)
            
            # État de la clé USB
            usb_status = "OK" if self.usb_manager.is_usb_available() else "NON"
            afficher("Clé USB:", usb_status, "", taille=12, align="centre")
            time.sleep(2)
            
            # Afficher le volume configuré
            volume = self.usb_manager.get_volume_audio()
            afficher("Volume:", f"{volume}%", "", taille=12, align="centre")
            time.sleep(2)
            
            # Afficher les infos sur les numéros
            numero_principal = self.usb_manager.get_numero_principal()
            longueur = self.usb_manager.get_longueur_numero_principal()
            afficher("Numero princ.:", numero_principal, f"({longueur} chiffres)", taille=10, align="centre")
            time.sleep(3)
            
        except Exception as e:
            print(f"Erreur diagnostics: {e}")
    
    def display_filters_menu(self):
        """Gère le menu des filtres vintage (code existant adapté)"""
        from oled_display import afficher
        
        # Charger la config actuelle
        config = self.audio_effects.get_filter_config()
        self.selected_filter = config.get("type", "radio_50s")
        self.selected_intensity = config.get("intensity", 0.7)
        
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
    
    def display_system_menu(self):
        """Affiche le menu système (mises à jour)"""
        from oled_display import afficher
        
        if self.current_step == 0:
            # Menu système principal
            afficher("Système", "1=Version", "2=Verif 3=Install", taille=11, align="centre")
            
        elif self.current_step == 1:
            # Affichage des versions
            version_info = self.update_manager.get_version_info()
            
            if not version_info["internet_available"]:
                afficher("Pas d'internet", "", "", taille=12, align="centre")
                time.sleep(2)
                return
            
            current_ver = version_info["current_version"]
            latest_ver = version_info["latest_version"] or "Inconnue"
            
            afficher(
                f"Actuelle: v{current_ver}",
                f"Dispo: v{latest_ver}",
                "",
                taille=11, align="centre"
            )
            time.sleep(4)
            
        elif self.current_step == 2:
            # Vérification mise à jour
            afficher("Verification...", "", "", taille=12, align="centre")
            time.sleep(1)
            
            version_info = self.update_manager.get_version_info()
            
            if not version_info["internet_available"]:
                afficher("Pas d'internet", "", "", taille=12, align="centre")
                time.sleep(2)
                return
            
            if version_info["update_available"]:
                current_ver = version_info["current_version"]
                latest_ver = version_info["latest_version"]
                
                afficher(
                    f"Actuelle: v{current_ver}",
                    f"Dispo: v{latest_ver}",
                    "0=install,autre=ann",
                    taille=10, align="centre"
                )
            else:
                afficher("Aucune MAJ", "disponible", "", taille=12, align="centre")
                time.sleep(2)
                
        elif self.current_step == 3:
            # Installation de la mise à jour
            afficher("Installation...", "Ne pas eteindre", "", taille=11, align="centre")
            
            # Lancer l'installation en arrière-plan
            success = self.update_manager.install_update()
            
            if success:
                afficher("Installation", "reussie!", "Redemarrage...", taille=11, align="centre")
                time.sleep(3)
                # Le système va redémarrer via systemctl restart
            else:
                afficher("Erreur MAJ", "", "", taille=12, align="centre")
                time.sleep(2)
    
    def run_menu_loop(self):
        """Boucle principale du menu"""
        print("🎛️ Démarrage boucle menu paramètres")
        
        while self.menu_active:
            # Vérifier si téléphone raccroché
            if self.gpio_manager.is_phone_on_hook():
                print("📞 Raccrochage - sortie menu paramètres")
                self.menu_active = False
                break
            
            # Attendre un chiffre avec la méthode éprouvée
            print(f"En attente d'un chiffre pour le menu {self.current_menu}, étape {self.current_step}...")
            digit = self.dialer_manager.wait_for_menu_digit(timeout_seconds=30)
            
            if digit is None:
                print("⏰ Timeout ou raccrochage menu paramètres")
                self.menu_active = False
                break
            
            print(f"Menu paramètres - Menu {self.current_menu}, Étape {self.current_step}, Chiffre reçu: {digit}")
            self.handle_menu_input(digit)
        
        # Nettoyage
        self.display_manager.clear_display()
        return True
    
    def handle_menu_input(self, digit):
        """Traite les entrées du menu selon l'état actuel"""
        print(f"Menu paramètres - Menu {self.current_menu}, Étape {self.current_step}, Input: {digit}")
        
        if self.current_menu == "main":
            # Menu principal
            if digit == "1":
                self.current_menu = "diagnostic"
                self.display_diagnostic_menu()
                # Sortir automatiquement après l'affichage
                time.sleep(1)
                self.menu_active = False
                
            elif digit == "2":
                self.current_menu = "filters"
                self.current_step = 0
                self.display_filters_menu()
                
            elif digit == "3":
                self.current_menu = "system"
                self.current_step = 0
                self.display_system_menu()
            else:
                # Chiffre non reconnu, rester sur le menu principal
                self.display_main_menu()
                
        elif self.current_menu == "filters":
            self.handle_filters_input(digit)
            
        elif self.current_menu == "system":
            self.handle_system_input(digit)
    
    def handle_filters_input(self, digit):
        """Gère les entrées du menu filtres (code existant adapté)"""
        if self.current_step == 0:
            # Sélection du type de filtre
            filter_mapping = {
                "0": "aucun",
                "1": "radio_50s", 
                "2": "telephone",
                "3": "gramophone"
            }
            
            if digit in filter_mapping:
                self.selected_filter = filter_mapping[digit]
                print(f"Filtre sélectionné: {self.selected_filter}")
                self.current_step = 1
                self.display_filters_menu()
            elif digit == "9":  # Passer à l'étape suivante
                self.current_step = 1
                self.display_filters_menu()
                
        elif self.current_step == 1:
            # Ajustement de l'intensité
            intensity_mapping = {
                "0": 0.0, "1": 0.1, "2": 0.2, "3": 0.3, "4": 0.4,
                "5": 0.5, "6": 0.6, "7": 0.7, "8": 0.8, "9": 0.9,
            }
            
            if digit in intensity_mapping:
                self.selected_intensity = intensity_mapping[digit]
                print(f"Intensité sélectionnée: {self.selected_intensity}")
                self.current_step = 2
                self.display_filters_menu()
                
        elif self.current_step == 2:
            # Récapitulatif - passage à la sauvegarde
            if digit == "0":
                self.save_filter_config()
                self.menu_active = False
            else:
                # Annuler - retour au menu principal
                print("🔄 Annulation filtres - retour au menu principal")
                self.current_menu = "main"
                self.current_step = 0
                self.display_main_menu()
    
    def handle_system_input(self, digit):
        """Gère les entrées du menu système"""
        if self.current_step == 0:
            # Menu système principal
            if digit == "1":
                self.current_step = 1
                self.display_system_menu()
            elif digit == "2":
                self.current_step = 2
                self.display_system_menu()
            elif digit == "3":
                # Vérifier qu'une MAJ est disponible avant d'installer
                version_info = self.update_manager.get_version_info()
                if version_info["internet_available"] and version_info["update_available"]:
                    self.current_step = 3
                    self.display_system_menu()
                    self.menu_active = False  # Sortir après installation
                else:
                    from oled_display import afficher
                    if not version_info["internet_available"]:
                        afficher("Pas d'internet", "", "", taille=12, align="centre")
                    else:
                        afficher("Aucune MAJ", "disponible", "", taille=12, align="centre")
                    time.sleep(2)
                    self.display_system_menu()
            else:
                # Retour menu principal
                self.current_menu = "main"
                self.current_step = 0
                self.display_main_menu()
                
        elif self.current_step == 2:
            # Menu vérification MAJ
            if digit == "0":
                # Installer la MAJ
                version_info = self.update_manager.get_version_info()
                if version_info["internet_available"] and version_info["update_available"]:
                    self.current_step = 3
                    self.display_system_menu()
                    self.menu_active = False
                else:
                    from oled_display import afficher
                    afficher("Aucune MAJ", "disponible", "", taille=12, align="centre")
                    time.sleep(2)
                    self.menu_active = False
            else:
                # Annuler
                self.current_menu = "main"
                self.current_step = 0
                self.display_main_menu()
        else:
            # Autres étapes, retour au menu principal
            self.current_menu = "main"
            self.current_step = 0
            self.display_main_menu()
    
    def save_filter_config(self):
        """Sauvegarde la configuration des filtres (code existant)"""
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