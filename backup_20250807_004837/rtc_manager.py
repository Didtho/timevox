# rtc_manager.py
"""
Gestionnaire du module RTC (Real-Time Clock) pour TimeVox
"""

import subprocess
import os
import time
from datetime import datetime


class RTCManager:
    def __init__(self):
        self.rtc_device = "/dev/rtc0"
        self.is_rtc_available = self.check_rtc_availability()
        
        if self.is_rtc_available:
            print("Module RTC détecté et disponible")
            self.sync_system_from_rtc()
        else:
            print("Module RTC non disponible - utilisation de l'heure système")
    
    def check_rtc_availability(self):
        """Vérifie si le module RTC est disponible"""
        try:
            return os.path.exists(self.rtc_device)
        except Exception as e:
            print(f"Erreur vérification RTC: {e}")
            return False
    
    def sync_system_from_rtc(self):
        """Synchronise l'heure système depuis le RTC au démarrage"""
        if not self.is_rtc_available:
            return False
        
        try:
            # Lire l'heure du RTC et l'appliquer au système
            result = subprocess.run(
                ["sudo", "hwclock", "-r", "-f", self.rtc_device], 
                capture_output=True, text=True, timeout=5
            )
            
            if result.returncode == 0:
                print(f"Heure RTC: {result.stdout.strip()}")
                
                # Appliquer l'heure RTC au système
                subprocess.run(
                    ["sudo", "hwclock", "-s", "-f", self.rtc_device], 
                    timeout=5
                )
                print("Heure système synchronisée depuis le RTC")
                return True
            else:
                print(f"Erreur lecture RTC: {result.stderr}")
                return False
                
        except Exception as e:
            print(f"Erreur synchronisation RTC: {e}")
            return False
    
    def sync_rtc_from_system(self):
        """Synchronise le RTC depuis l'heure système (quand WiFi disponible)"""
        if not self.is_rtc_available:
            return False
        
        try:
            # Écrire l'heure système vers le RTC
            subprocess.run(
                ["sudo", "hwclock", "-w", "-f", self.rtc_device], 
                timeout=5
            )
            print("RTC synchronisé depuis l'heure système")
            return True
            
        except Exception as e:
            print(f"Erreur synchronisation vers RTC: {e}")
            return False
    
    def get_current_datetime(self):
        """Retourne la date/heure actuelle (système ou RTC)"""
        return datetime.now()
    
    def format_datetime_for_filename(self, dt=None):
        """Formate une date/heure pour les noms de fichiers"""
        if dt is None:
            dt = self.get_current_datetime()
        return dt.strftime("%Y%m%d_%H%M%S")
    
    def format_date_for_folder(self, dt=None):
        """Formate une date pour les dossiers (YYYY-MM-DD)"""
        if dt is None:
            dt = self.get_current_datetime()
        return dt.strftime("%Y-%m-%d")
    
    def check_time_validity(self):
        """Vérifie si l'heure système semble valide (après 2020)"""
        current_time = datetime.now()
        min_valid_time = datetime(2020, 1, 1)
        
        is_valid = current_time > min_valid_time
        
        if not is_valid:
            print(f"ATTENTION: Heure système invalide: {current_time}")
            print("L'horodatage des messages pourrait être incorrect")
        
        return is_valid
    
    def sync_time_if_network_available(self):
        """Tente de synchroniser l'heure via NTP si réseau disponible"""
        try:
            # Vérifier la connectivité réseau
            result = subprocess.run(
                ["ping", "-c", "1", "-W", "3", "pool.ntp.org"],
                capture_output=True, timeout=5
            )
            
            if result.returncode == 0:
                print("Réseau détecté - tentative synchronisation NTP...")
                
                # Synchroniser via NTP
                ntp_result = subprocess.run(
                    ["sudo", "ntpdate", "-s", "pool.ntp.org"],
                    capture_output=True, timeout=10
                )
                
                if ntp_result.returncode == 0:
                    print("Synchronisation NTP réussie")
                    # Mettre à jour le RTC avec la nouvelle heure
                    if self.is_rtc_available:
                        self.sync_rtc_from_system()
                    return True
                else:
                    print("Échec synchronisation NTP")
                    
        except Exception as e:
            print(f"Erreur synchronisation réseau: {e}")
        
        return False
    
    def get_status_info(self):
        """Retourne des informations sur l'état du RTC"""
        info = {
            "rtc_available": self.is_rtc_available,
            "system_time": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "time_valid": self.check_time_validity()
        }
        
        if self.is_rtc_available:
            try:
                result = subprocess.run(
                    ["sudo", "hwclock", "-r", "-f", self.rtc_device],
                    capture_output=True, text=True, timeout=5
                )
                if result.returncode == 0:
                    info["rtc_time"] = result.stdout.strip()
            except:
                info["rtc_time"] = "Erreur lecture"
        
        return info