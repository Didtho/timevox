# update_manager.py
"""
Gestionnaire des mises à jour TimeVox
Vérifie, télécharge et installe les mises à jour depuis GitHub
"""

import json
import os
import requests
import subprocess
import tempfile
import shutil
import time
from datetime import datetime
from config import BASE_DIR


class UpdateManager:
    def __init__(self, usb_manager=None):
        self.usb_manager = usb_manager
        self.github_api_url = "https://api.github.com/repos/Didtho/timevox/releases/latest"
        self.github_repo_url = "https://github.com/Didtho/timevox"
        self.version_file = os.path.join(BASE_DIR, "version.json")
        self.current_version = self.get_current_version()
        
    def get_current_version(self):
        """Récupère la version actuelle depuis version.json"""
        try:
            if os.path.exists(self.version_file):
                with open(self.version_file, 'r', encoding='utf-8') as f:
                    version_data = json.load(f)
                    return version_data.get("version", "1.0.0")
            else:
                # Si pas de fichier version, on considère que c'est la v1.0.0
                self.create_version_file("1.0.0")
                return "1.0.0"
        except Exception as e:
            print(f"Erreur lecture version actuelle: {e}")
            return "1.0.0"
    
    def create_version_file(self, version):
        """Crée un fichier version.json"""
        try:
            version_data = {
                "version": version,
                "last_update": datetime.now().isoformat(),
                "install_date": datetime.now().isoformat()
            }
            with open(self.version_file, 'w', encoding='utf-8') as f:
                json.dump(version_data, f, indent=2, ensure_ascii=False)
            print(f"Fichier version créé: {version}")
        except Exception as e:
            print(f"Erreur création fichier version: {e}")
    
    def check_internet_connection(self):
        """Vérifie la connexion internet"""
        try:
            response = requests.get("https://github.com", timeout=5)
            return response.status_code == 200
        except:
            return False
    
    def get_latest_version_info(self):
        """Récupère les informations de la dernière version sur GitHub"""
        try:
            if not self.check_internet_connection():
                return None
            
            response = requests.get(self.github_api_url, timeout=10)
            if response.status_code == 200:
                release_data = response.json()
                return {
                    "version": release_data.get("tag_name", "").lstrip('v'),
                    "download_url": release_data.get("zipball_url"),
                    "published_at": release_data.get("published_at"),
                    "body": release_data.get("body", "")
                }
        except Exception as e:
            print(f"Erreur récupération version distante: {e}")
        
        return None
    
    def is_update_available(self):
        """Vérifie si une mise à jour est disponible"""
        latest_info = self.get_latest_version_info()
        if not latest_info:
            return False, None
        
        latest_version = latest_info["version"]
        current_version = self.current_version
        
        # Comparaison simple des versions (format x.y.z)
        try:
            def version_tuple(v):
                return tuple(map(int, v.split('.')))
            
            is_newer = version_tuple(latest_version) > version_tuple(current_version)
            return is_newer, latest_info
        except Exception as e:
            print(f"Erreur comparaison versions: {e}")
            return False, None
    
    def get_version_info(self):
        """Retourne les informations de version pour l'affichage"""
        info = {
            "current_version": self.current_version,
            "latest_version": None,
            "update_available": False,
            "internet_available": self.check_internet_connection()
        }
        
        if info["internet_available"]:
            latest_info = self.get_latest_version_info()
            if latest_info:
                info["latest_version"] = latest_info["version"]
                info["update_available"] = info["latest_version"] != info["current_version"]
                
                # Vérification plus précise
                try:
                    def version_tuple(v):
                        return tuple(map(int, v.split('.')))
                    info["update_available"] = version_tuple(info["latest_version"]) > version_tuple(info["current_version"])
                except:
                    pass
        
        return info
    
    def download_update(self, download_url):
        """Télécharge la mise à jour dans un dossier temporaire"""
        try:
            print("Téléchargement de la mise à jour...")
            
            # Créer un dossier temporaire
            temp_dir = tempfile.mkdtemp(prefix="timevox_update_")
            zip_path = os.path.join(temp_dir, "timevox_update.zip")
            
            # Télécharger le fichier
            response = requests.get(download_url, stream=True, timeout=60)
            response.raise_for_status()
            
            with open(zip_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    f.write(chunk)
            
            # Décompresser
            extract_dir = os.path.join(temp_dir, "extracted")
            subprocess.run(["unzip", "-q", zip_path, "-d", extract_dir], check=True)
            
            # Trouver le dossier principal (GitHub crée un dossier avec le nom du repo + hash)
            extracted_contents = os.listdir(extract_dir)
            if len(extracted_contents) == 1:
                main_folder = os.path.join(extract_dir, extracted_contents[0])
                if os.path.isdir(main_folder):
                    print(f"Mise à jour téléchargée dans: {main_folder}")
                    return main_folder
            
            raise Exception("Structure d'archive inattendue")
            
        except Exception as e:
            print(f"Erreur téléchargement: {e}")
            return None
    
    def backup_current_config(self):
        """Sauvegarde la configuration actuelle"""
        try:
            if not self.usb_manager or not self.usb_manager.is_usb_available():
                print("Clé USB non disponible pour la sauvegarde")
                return None
            
            config_path = os.path.join(self.usb_manager.usb_path, "Parametres", "config.json")
            if not os.path.exists(config_path):
                print("Pas de configuration à sauvegarder")
                return {}
            
            with open(config_path, 'r', encoding='utf-8') as f:
                return json.load(f)
                
        except Exception as e:
            print(f"Erreur sauvegarde config: {e}")
            return {}
    
    def merge_configs(self, old_config, new_config_template):
        """
        Fusionne l'ancienne config utilisateur avec le nouveau template
        GARDE toutes les valeurs utilisateur existantes
        AJOUTE seulement les nouveaux paramètres du template
        """
        try:
            # Partir de l'ancienne config utilisateur comme base
            merged_config = old_config.copy()
            
            # Ajouter SEULEMENT les nouveaux paramètres qui n'existent pas
            for key, value in new_config_template.items():
                if key not in merged_config:
                    merged_config[key] = value
                    print(f"Nouveau paramètre ajouté: {key} = {value}")
            
            print("Configuration fusionnée avec succès - paramètres utilisateur conservés")
            return merged_config
            
        except Exception as e:
            print(f"Erreur fusion config: {e}")
            # En cas d'erreur, garder la config utilisateur
            return old_config
    
    def install_update(self):
        """Installe la mise à jour complète"""
        try:
            print("=== DÉBUT INSTALLATION MISE À JOUR ===")
            
            # 1. Vérifier qu'une MAJ est disponible
            is_available, latest_info = self.is_update_available()
            if not is_available:
                print("Aucune mise à jour disponible")
                return False
            
            # 2. Sauvegarder la config actuelle
            old_config = self.backup_current_config()
            
            # 3. Télécharger la MAJ
            download_url = latest_info["download_url"]
            update_path = self.download_update(download_url)
            if not update_path:
                return False
            
            # 4. Arrêter les services
            print("Arrêt des services TimeVox...")
            subprocess.run(["sudo", "systemctl", "stop", "timevox", "timevox-shutdown"], 
                          capture_output=True)
            
            # 5. Installer les nouveaux fichiers
            print("Installation des nouveaux fichiers...")
            
            # Copier les fichiers Python du dossier timevox/
            source_timevox = os.path.join(update_path, "timevox")
            if os.path.exists(source_timevox):
                for item in os.listdir(source_timevox):
                    if item.endswith('.py'):
                        src = os.path.join(source_timevox, item)
                        dst = os.path.join(BASE_DIR, item)
                        shutil.copy2(src, dst)
                        print(f"Mis à jour: {item}")
            
            # Copier version.json
            source_version = os.path.join(update_path, "version.json")
            if os.path.exists(source_version):
                shutil.copy2(source_version, self.version_file)
                print("Mis à jour: version.json")
            
            # 6. Mettre à jour le fichier version avec la nouvelle version
            new_version = latest_info["version"]
            self.create_version_file(new_version)
            
            # 7. Fusionner les configs si nécessaire
            if self.usb_manager and self.usb_manager.is_usb_available():
                print("Fusion de la configuration...")
                
                # Charger le template de config depuis la MAJ
                source_config = os.path.join(update_path, "config.json")
                new_config_template = {}
                
                if os.path.exists(source_config):
                    try:
                        with open(source_config, 'r', encoding='utf-8') as f:
                            new_config_template = json.load(f)
                        print(f"Template de config chargé depuis GitHub: {len(new_config_template)} paramètres")
                    except Exception as e:
                        print(f"Erreur lecture template config: {e}")
                
                # Si on a un template ET une config utilisateur
                if new_config_template and old_config:
                    # Fusionner intelligemment
                    merged_config = self.merge_configs(old_config, new_config_template)
                    
                    # Sauvegarder la config fusionnée
                    user_config_path = os.path.join(self.usb_manager.usb_path, "Parametres", "config.json")
                    os.makedirs(os.path.dirname(user_config_path), exist_ok=True)
                    
                    with open(user_config_path, 'w', encoding='utf-8') as f:
                        json.dump(merged_config, f, indent=2, ensure_ascii=False)
                    
                    print("Configuration fusionnée et sauvegardée sur clé USB")
                    
                elif new_config_template and not old_config:
                    # Pas de config utilisateur, utiliser le template
                    user_config_path = os.path.join(self.usb_manager.usb_path, "Parametres", "config.json")
                    os.makedirs(os.path.dirname(user_config_path), exist_ok=True)
                    
                    with open(user_config_path, 'w', encoding='utf-8') as f:
                        json.dump(new_config_template, f, indent=2, ensure_ascii=False)
                    
                    print("Template de configuration installé sur clé USB")
                else:
                    print("Aucune fusion de config nécessaire")
            else:
                print("Clé USB non disponible - fusion config ignorée")
            
            # 8. Nettoyer les fichiers temporaires
            try:
                shutil.rmtree(os.path.dirname(update_path))
            except:
                pass
            
            # 9. Redémarrer les services
            print("Redémarrage des services...")
            subprocess.run(["sudo", "systemctl", "start", "timevox", "timevox-shutdown"], 
                          capture_output=True)
            
            # 10. Logger la mise à jour
            if self.usb_manager:
                self.usb_manager.save_event_log(
                    "UPDATE_SUCCESS", 
                    f"Mise à jour vers {new_version} installée avec succès"
                )
            
            print(f"✅ Mise à jour vers {new_version} installée avec succès!")
            return True
            
        except Exception as e:
            print(f"❌ Erreur lors de l'installation: {e}")
            
            # Tenter de redémarrer les services en cas d'échec
            try:
                subprocess.run(["sudo", "systemctl", "start", "timevox", "timevox-shutdown"], 
                              capture_output=True)
            except:
                pass
                
            if self.usb_manager:
                self.usb_manager.save_event_log("UPDATE_FAILED", f"Erreur installation: {str(e)}")
            
            return False
    
    def check_update_at_startup(self):
        """Vérifie s'il y a une MAJ au démarrage (pour affichage OLED)"""
        try:
            if not self.check_internet_connection():
                return False
            
            is_available, _ = self.is_update_available()
            return is_available
            
        except Exception as e:
            print(f"Erreur vérification MAJ au démarrage: {e}")
            return False