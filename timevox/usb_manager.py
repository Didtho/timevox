# usb_manager.py
"""
Gestionnaire de la clé USB pour le stockage des messages et annonces
Version avec gestion de la durée d'enregistrement, volume audio et longueur du numéro principal configurables
"""

import os
import json
import random
from datetime import datetime
from config import USB_MOUNT_PATH, RECORD_DURATION


class USBManager:
    def __init__(self, rtc_manager=None):
        self.rtc_manager = rtc_manager  # Gestionnaire RTC optionnel
        self.usb_path = None
        self.numero_principal = "1234567890"  # Valeur par défaut (10 chiffres)
        self.longueur_numero_principal = 10  # Valeur par défaut
        self.duree_enregistrement = RECORD_DURATION  # Valeur par défaut
        self.volume_audio = 2  # Valeur par défaut en pourcentage (2%)
        self.detect_usb_drive()
        self.load_config()
    
    def detect_usb_drive(self):
        """Détecte la clé USB montée et retourne son chemin"""
        try:
            # Chercher dans les points de montage courants
            mount_points = ["/media/pi", "/mnt", "/media"]

            for mount_base in mount_points:
                if os.path.exists(mount_base):
                    for item in os.listdir(mount_base):
                        usb_path = os.path.join(mount_base, item)
                        if os.path.isdir(usb_path):
                            # Vérifier si c'est notre clé en cherchant les dossiers Annonce et Messages
                            annonce_dir = os.path.join(usb_path, "Annonce")
                            messages_dir = os.path.join(usb_path, "Messages")
                            if os.path.exists(annonce_dir) and os.path.exists(messages_dir):
                                print(f"Clé USB détectée: {usb_path}")
                                self.usb_path = usb_path
                                return usb_path

            # Méthode alternative: lire /proc/mounts
            with open("/proc/mounts", "r") as f:
                for line in f:
                    parts = line.split()
                    if len(parts) >= 3 and "vfat" in parts[2]:  # FAT32
                        mount_point = parts[1]
                        annonce_dir = os.path.join(mount_point, "Annonce")
                        messages_dir = os.path.join(mount_point, "Messages")
                        if os.path.exists(annonce_dir) and os.path.exists(messages_dir):
                            print(f"Clé USB détectée via /proc/mounts: {mount_point}")
                            self.usb_path = mount_point
                            return mount_point

        except Exception as e:
            print(f"Erreur détection clé USB: {e}")

        print("Clé USB non détectée")
        self.usb_path = None
        return None
    
    def validate_numero_principal_config(self, numero, longueur):
        """Valide la cohérence entre le numéro principal et sa longueur déclarée"""
        numero_str = str(numero)
        actual_length = len(numero_str)
        
        # Vérifier que le numéro ne contient que des chiffres
        if not numero_str.isdigit():
            print(f"ERREUR CONFIG: Le numéro principal '{numero}' doit contenir uniquement des chiffres")
            return False
        
        # Vérifier la cohérence de longueur
        if actual_length != longueur:
            print(f"ERREUR CONFIG: Le numéro principal '{numero}' fait {actual_length} chiffres")
            print(f"                mais longueur_numero_principal est configuré à {longueur}")
            print(f"                Ces valeurs doivent être cohérentes!")
            return False
        
        # Vérifier que la longueur est dans une plage raisonnable
        if longueur < 4 or longueur > 15:
            print(f"ERREUR CONFIG: longueur_numero_principal ({longueur}) doit être entre 4 et 15")
            return False
        
        print(f"✅ Configuration numéro principal valide: {numero} ({longueur} chiffres)")
        return True
    
    def load_config(self):
        """Charge la configuration depuis le fichier config.json de la clé USB"""
        if not self.usb_path:
            print("Clé USB non disponible - utilisation des valeurs par défaut")
            return
        
        config_file = os.path.join(self.usb_path, "Parametres", "config.json")
        
        try:
            if os.path.exists(config_file):
                with open(config_file, 'r', encoding='utf-8') as f:
                    config_data = json.load(f)
                    
                # Charger le numéro principal et sa longueur
                numero_config = None
                longueur_config = None
                
                if 'numero_principal' in config_data:
                    numero_config = str(config_data['numero_principal'])
                else:
                    print("Clé 'numero_principal' non trouvée dans config.json")
                
                if 'longueur_numero_principal' in config_data:
                    try:
                        longueur_config = int(config_data['longueur_numero_principal'])
                    except (ValueError, TypeError):
                        print("Valeur longueur_numero_principal invalide (doit être un entier)")
                        longueur_config = None
                else:
                    print("Clé 'longueur_numero_principal' non trouvée dans config.json")
                
                # Valider la cohérence si les deux valeurs sont présentes
                if numero_config is not None and longueur_config is not None:
                    if self.validate_numero_principal_config(numero_config, longueur_config):
                        self.numero_principal = numero_config
                        self.longueur_numero_principal = longueur_config
                        print(f"Configuration numéro principal chargée: {self.numero_principal} ({self.longueur_numero_principal} chiffres)")
                    else:
                        print("Utilisation des valeurs par défaut à cause d'erreurs de configuration")
                elif numero_config is not None:
                    # Seulement le numéro est présent, calculer la longueur automatiquement
                    if numero_config.isdigit():
                        self.numero_principal = numero_config
                        self.longueur_numero_principal = len(numero_config)
                        print(f"Numéro principal chargé: {self.numero_principal}")
                        print(f"Longueur calculée automatiquement: {self.longueur_numero_principal}")
                        print("⚠️  Ajoutez 'longueur_numero_principal' dans config.json pour expliciter cette valeur")
                    else:
                        print(f"Numéro principal invalide: {numero_config}")
                
                # Charger la durée d'enregistrement
                if 'duree_enregistrement' in config_data:
                    self.duree_enregistrement = int(config_data['duree_enregistrement'])
                    print(f"Durée d'enregistrement chargée depuis USB: {self.duree_enregistrement}s")
                else:
                    print("Clé 'duree_enregistrement' non trouvée dans config.json - utilisation valeur par défaut")
                
                # Charger le volume audio
                if 'volume_audio' in config_data:
                    volume_value = config_data['volume_audio']
                    # Valider que c'est un nombre entre 0 et 100
                    if isinstance(volume_value, (int, float)) and 0 <= volume_value <= 100:
                        self.volume_audio = volume_value
                        print(f"Volume audio chargé depuis USB: {self.volume_audio}%")
                    else:
                        print(f"Valeur volume_audio invalide ({volume_value}) - doit être entre 0 et 100%")
                        print("Utilisation de la valeur par défaut (2%)")
                else:
                    print("Clé 'volume_audio' non trouvée dans config.json - utilisation valeur par défaut (2%)")
                    
                # Charger les paramètres de filtre vintage
                if 'filtre_vintage' in config_data:
                    filtre_value = config_data['filtre_vintage']
                    if isinstance(filtre_value, bool):
                        print(f"Filtre vintage chargé depuis USB: {'Activé' if filtre_value else 'Désactivé'}")
                    else:
                        print(f"Valeur filtre_vintage invalide ({filtre_value}) - doit être true/false")
                
                if 'type_filtre' in config_data:
                    type_filtre = config_data['type_filtre']
                    valid_types = ["aucun", "radio_50s", "telephone", "gramophone"]
                    if type_filtre in valid_types:
                        print(f"Type de filtre chargé depuis USB: {type_filtre}")
                    else:
                        print(f"Type de filtre invalide ({type_filtre}) - types valides: {valid_types}")
                
                if 'intensite_filtre' in config_data:
                    intensite_value = config_data['intensite_filtre']
                    if isinstance(intensite_value, (int, float)) and 0.0 <= intensite_value <= 1.0:
                        print(f"Intensité filtre chargée depuis USB: {intensite_value}")
                    else:
                        print(f"Valeur intensite_filtre invalide ({intensite_value}) - doit être entre 0.0 et 1.0")
                
                if 'conserver_original' in config_data:
                    conserver_value = config_data['conserver_original']
                    if isinstance(conserver_value, bool):
                        print(f"Conserver original chargé depuis USB: {'Oui' if conserver_value else 'Non'}")
                    else:
                        print(f"Valeur conserver_original invalide ({conserver_value}) - doit être true/false")
                    
            else:
                print(f"Fichier config.json non trouvé: {config_file}")
                print("Création du dossier Parametres et du fichier config.json par défaut...")
                self.create_default_config()
        except Exception as e:
            print(f"Erreur lecture config.json: {e}")
            print("Utilisation des valeurs par défaut")
    
    def create_default_config(self):
        """Crée un fichier config.json par défaut"""
        if not self.usb_path:
            return
        
        try:
            parametres_dir = os.path.join(self.usb_path, "Parametres")
            if not os.path.exists(parametres_dir):
                os.makedirs(parametres_dir)
                print(f"Dossier Parametres créé: {parametres_dir}")
            
            config_file = os.path.join(parametres_dir, "config.json")
            default_config = {
                "numero_principal": "1234567890",
                "longueur_numero_principal": 10,
                "description": "Numéro pour lancer l'annonce et l'enregistrement de message - longueur configurable",
                "longueur_description": "Longueur du numéro principal (doit correspondre au nombre de chiffres du numero_principal)",
                "duree_enregistrement": 60,
                "volume_audio": 2,
                "volume_description": "Volume audio en pourcentage (0-100). 2% par défaut pour éviter la saturation.",
                "filtre_vintage": False,
                "type_filtre": "radio_50s", 
                "intensite_filtre": 0.7,
                "conserver_original": True,
                "filtre_description": "Configuration des effets vintage",
                "filtre_vintage_description": "Active/désactive les effets vintage (true/false)",
                "type_filtre_description": "Type d'effet: 'aucun', 'radio_50s', 'telephone', 'gramophone'",
                "intensite_filtre_description": "Intensité de l'effet (0.0 à 1.0). 0.7 = fort, 0.5 = modéré, 0.3 = léger",
                "conserver_original_description": "Garde une copie du fichier original sans effet (true/false)"
            }
            
            with open(config_file, 'w', encoding='utf-8') as f:
                json.dump(default_config, f, indent=2, ensure_ascii=False)
                
            print(f"Fichier config.json créé: {config_file}")
        except Exception as e:
            print(f"Erreur création config.json: {e}")
    
    def get_numero_principal(self):
        """Retourne le numéro principal configuré"""
        return self.numero_principal
    
    def get_longueur_numero_principal(self):
        """Retourne la longueur du numéro principal configurée"""
        return self.longueur_numero_principal
    
    def get_duree_enregistrement(self):
        """Retourne la durée d'enregistrement configurée"""
        return self.duree_enregistrement
    
    def get_volume_audio(self):
        """Retourne le volume audio configuré en pourcentage"""
        return self.volume_audio
    
    def get_config_info(self):
        """Retourne un dictionnaire avec toutes les informations de configuration"""
        config_info = {
            "numero_principal": self.numero_principal,
            "longueur_numero_principal": self.longueur_numero_principal,
            "duree_enregistrement": self.duree_enregistrement,
            "volume_audio": self.volume_audio,
            "usb_path": self.usb_path,
            "usb_available": self.is_usb_available()
        }
        
        # Ajouter les paramètres de filtre depuis le fichier config
        if self.usb_path:
            config_file = os.path.join(self.usb_path, "Parametres", "config.json")
            try:
                if os.path.exists(config_file):
                    with open(config_file, 'r', encoding='utf-8') as f:
                        config_data = json.load(f)
                        
                    # Ajouter les paramètres de filtre s'ils existent
                    config_info.update({
                        "filtre_vintage": config_data.get("filtre_vintage", False),
                        "type_filtre": config_data.get("type_filtre", "radio_50s"),
                        "intensite_filtre": config_data.get("intensite_filtre", 0.7),
                        "conserver_original": config_data.get("conserver_original", True)
                    })
            except Exception as e:
                print(f"Erreur lecture config pour get_config_info: {e}")
        
        # Ajouter les informations RTC si disponible
        if self.rtc_manager:
            rtc_status = self.rtc_manager.get_status_info()
            config_info.update({
                "rtc_available": rtc_status['rtc_available'],
                "time_valid": rtc_status['time_valid'],
                "current_time": rtc_status['system_time']
            })
        
        return config_info
    
    def is_usb_available(self):
        """Vérifie si la clé USB est disponible"""
        return self.usb_path is not None
    
    def get_announce_path(self):
        """Retourne le chemin vers un fichier d'annonce choisi au hasard"""
        if not self.usb_path:
            self.detect_usb_drive()
        
        if self.usb_path:
            announce_dir = os.path.join(self.usb_path, "Annonce")
            if os.path.exists(announce_dir):
                # Lister tous les fichiers MP3 dans le dossier Annonce
                mp3_files = []
                print(f"DEBUG: Contenu du dossier {announce_dir}:")
                for file in os.listdir(announce_dir):
                    print(f"  - {file}")
                    if file.lower().endswith('.mp3'):
                        full_path = os.path.join(announce_dir, file)
                        if os.path.isfile(full_path):
                            mp3_files.append(full_path)
                
                print(f"DEBUG: Fichiers MP3 trouvés: {len(mp3_files)}")
                for i, mp3_file in enumerate(mp3_files):
                    print(f"  {i+1}. {mp3_file}")
                
                if mp3_files:
                    # Choisir un fichier au hasard
                    selected_file = random.choice(mp3_files)
                    print(f"Fichier d'annonce sélectionné au hasard: {selected_file}")
                    return selected_file
                else:
                    print(f"Aucun fichier MP3 trouvé dans {announce_dir}")
                    return None
            else:
                print(f"Dossier Annonce non trouvé dans {self.usb_path}")
                return None

        print("Clé USB non détectée - pas d'annonce disponible")
        return None
    
    def generate_message_filename(self, prefix="message", extension=".mp3"):
        """Génère un nom de fichier avec horodatage dans le dossier USB du jour"""
        if not self.usb_path:
            self.detect_usb_drive()
        
        if self.usb_path:
            # Créer le dossier Messages s'il n'existe pas
            messages_base = os.path.join(self.usb_path, "Messages")
            if not os.path.exists(messages_base):
                os.makedirs(messages_base)
                print(f"Dossier Messages créé: {messages_base}")

            # Utiliser le RTC pour obtenir la date/heure si disponible
            if self.rtc_manager:
                current_datetime = self.rtc_manager.get_current_datetime()
                date_du_jour = self.rtc_manager.format_date_for_folder(current_datetime)
                horodatage = self.rtc_manager.format_datetime_for_filename(current_datetime)
                
                # Vérifier la validité de l'heure et logger si nécessaire
                if not self.rtc_manager.check_time_validity():
                    print("ATTENTION: Heure système possiblement incorrecte!")
                    self.save_time_sync_log("ATTENTION: Horodatage potentiellement incorrect lors de la génération du fichier")
            else:
                # Fallback sur datetime standard si pas de RTC
                print("RTC non disponible - utilisation de l'heure système standard")
                current_datetime = datetime.now()
                date_du_jour = current_datetime.strftime("%Y-%m-%d")
                horodatage = current_datetime.strftime("%Y%m%d_%H%M%S")

            # Créer le dossier du jour (AAAA-MM-JJ)
            dossier_jour = os.path.join(messages_base, date_du_jour)

            if not os.path.exists(dossier_jour):
                os.makedirs(dossier_jour)
                print(f"Dossier du jour créé: {dossier_jour}")

            # Générer le nom avec horodatage
            nom_fichier = os.path.join(dossier_jour, f"{prefix}_{horodatage}{extension}")

            print(f"Fichier sera enregistré dans: {nom_fichier}")
            return nom_fichier
        else:
            print("Clé USB non détectée - impossible d'enregistrer")
            return None
    
    def save_time_sync_log(self, sync_info):
        """Sauvegarde un log des synchronisations d'heure et événements temporels sur la clé USB"""
        if not self.usb_path:
            return
        
        try:
            log_dir = os.path.join(self.usb_path, "Logs")
            if not os.path.exists(log_dir):
                os.makedirs(log_dir)
                print(f"Dossier Logs créé: {log_dir}")
            
            log_file = os.path.join(log_dir, "time_sync.log")
            
            # Utiliser le RTC pour l'horodatage du log si disponible
            if self.rtc_manager:
                current_time = self.rtc_manager.get_current_datetime().strftime("%Y-%m-%d %H:%M:%S")
            else:
                current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            
            log_entry = f"{current_time} - {sync_info}\n"
            
            with open(log_file, 'a', encoding='utf-8') as f:
                f.write(log_entry)
            
            print(f"Log sauvegardé: {sync_info}")
                
        except Exception as e:
            print(f"Erreur sauvegarde log: {e}")
    
    def save_event_log(self, event_type, details=""):
        """Sauvegarde un log d'événements générique sur la clé USB"""
        if not self.usb_path:
            return
        
        try:
            log_dir = os.path.join(self.usb_path, "Logs")
            if not os.path.exists(log_dir):
                os.makedirs(log_dir)
            
            # Utiliser le RTC pour l'horodatage si disponible
            if self.rtc_manager:
                current_time = self.rtc_manager.get_current_datetime()
                timestamp = current_time.strftime("%Y-%m-%d %H:%M:%S")
                date_for_file = current_time.strftime("%Y-%m-%d")
            else:
                current_time = datetime.now()
                timestamp = current_time.strftime("%Y-%m-%d %H:%M:%S")
                date_for_file = current_time.strftime("%Y-%m-%d")
            
            # Créer un fichier de log par jour
            log_file = os.path.join(log_dir, f"events_{date_for_file}.log")
            
            log_entry = f"{timestamp} - {event_type}"
            if details:
                log_entry += f" - {details}"
            log_entry += "\n"
            
            with open(log_file, 'a', encoding='utf-8') as f:
                f.write(log_entry)
            
            print(f"Événement loggé: {event_type}")
                
        except Exception as e:
            print(f"Erreur sauvegarde événement: {e}")
    
    def get_rtc_manager(self):
        """Retourne le gestionnaire RTC associé"""
        return self.rtc_manager
    
    def set_rtc_manager(self, rtc_manager):
        """Définit le gestionnaire RTC à utiliser"""
        self.rtc_manager = rtc_manager
        print("Gestionnaire RTC mis à jour dans USBManager")