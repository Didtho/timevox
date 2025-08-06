# dialer_manager.py
"""
Gestionnaire du cadran téléphonique
Version avec gestion flexible des numéros : service (courts) et principal (longueur configurable)
"""

import time
from datetime import datetime, timedelta
from config import REST_TIME, MIN_IMPULSE_TIME, TIMEOUT_RESET, SERVICE_NUMBERS, is_service_number
from display_manager import DisplayManager

class DialerManager:
    def __init__(self, gpio_manager, display_manager, usb_manager):
        self.gpio_manager = gpio_manager
        self.display_manager = display_manager
        self.usb_manager = usb_manager  # Référence au gestionnaire USB pour les paramètres
        
        # État de composition
        self.count = 0
        self.printed = True
        self.pressed = False
        self.rest_start = datetime.now()
        self.last_impulse_time = time.time()
        self.first_impulse_time = None
        self.composed_number = ""
        self.last_digit_time = time.time()
        
        # Obtenir les paramètres du numéro principal
        self.numero_principal = self.usb_manager.get_numero_principal()
        self.longueur_numero_principal = self.usb_manager.get_longueur_numero_principal()
        
        self.menu_mode = False  # Nouveau flag pour mode menu
        
        print(f"DialerManager initialisé:")
        print(f"  - Numéro principal: {self.numero_principal} ({self.longueur_numero_principal} chiffres)")
        print(f"  - Numéros de service: {list(SERVICE_NUMBERS.keys())}")
    
    def reset_dialing(self, clear_display=True):
        """Remet à zéro la composition en cours"""
        self.composed_number = ""
        self.count = 0
        self.printed = True
        self.pressed = False
        self.last_digit_time = time.time()
        if clear_display:
            self.display_manager.clear_display()
            self.display_manager.reset_timevox_flag()
        print("Composition remise à zéro")
    
    def clear_dialing_state(self):
        """Nettoie seulement l'état de composition sans toucher à l'affichage"""
        self.composed_number = ""
        self.count = 0
        self.printed = True
        self.pressed = False
        self.last_digit_time = time.time()
    
    def check_service_number_match(self, current_number):
        """
        Vérifie si le numéro actuel correspond à un numéro de service complet
        Retourne le numéro de service si match, None sinon
        """
        for service_num, info in SERVICE_NUMBERS.items():
            if len(current_number) == info['length'] and current_number == service_num:
                print(f"✅ Numéro de service reconnu: {service_num} ({info['description']})")
                return service_num
        return None
    
    def check_main_number_match(self, current_number):
        """
        Vérifie si le numéro actuel correspond au numéro principal complet
        Retourne le numéro principal si match, None sinon
        """
        if (len(current_number) == self.longueur_numero_principal and 
            current_number == self.numero_principal):
            print(f"✅ Numéro principal reconnu: {self.numero_principal}")
            return self.numero_principal
        return None
    
    def is_number_too_long(self, current_number):
        """
        Vérifie si le numéro composé est devenu trop long
        Retourne True s'il dépasse toutes les longueurs possibles
        """
        current_length = len(current_number)
        
        # Vérifier contre les numéros de service
        max_service_length = max([info['length'] for info in SERVICE_NUMBERS.values()])
        
        # Si on dépasse à la fois la longueur max des services ET du numéro principal
        if (current_length > max_service_length and 
            current_length > self.longueur_numero_principal):
            return True
        
        return False
    
    def get_expected_lengths_for_current_number(self, current_number):
        """
        Retourne les longueurs encore possibles pour le numéro en cours de composition
        """
        current_length = len(current_number)
        possible_lengths = []
        
        # Vérifier les numéros de service
        for service_num, info in SERVICE_NUMBERS.items():
            service_length = info['length']
            if (service_length >= current_length and 
                service_num.startswith(current_number)):
                possible_lengths.append(service_length)
        
        # Vérifier le numéro principal
        if (self.longueur_numero_principal >= current_length and 
            self.numero_principal.startswith(current_number)):
            possible_lengths.append(self.longueur_numero_principal)
        
        return sorted(list(set(possible_lengths)))
    
    def process_dialing(self):
        """
        Traite les impulsions du cadran avec logique flexible
        En mode normal: retourne le numéro composé complet si un numéro cible est atteint
        En mode menu: retourne chaque chiffre dès qu'il est composé
        """
        current_time = time.time()
        
        # Traitement des impulsions du cadran (code existant inchangé)
        if (self.gpio_manager.is_phone_off_hook() and 
            self.gpio_manager.is_button_pressed()):
            
            if not self.pressed and current_time - self.last_impulse_time > MIN_IMPULSE_TIME:
                self.count += 1
                self.pressed = True
                self.printed = False
                self.last_impulse_time = current_time
                if self.count == 1:
                    self.first_impulse_time = current_time
        else:
            if self.pressed:
                self.rest_start = datetime.now()
            self.pressed = False

        # Traitement des chiffres composés
        if (datetime.now() - self.rest_start > timedelta(seconds=REST_TIME) and 
            not self.printed):
            
            if self.count == 1 and (time.time() - self.first_impulse_time) < 0.15:
                self.count = 0
            else:
                digit = self.count % 10
                
                # === NOUVEAU CODE POUR MODE MENU ===
                if self.menu_mode:
                    # Mode menu: retourner immédiatement le chiffre
                    print(f"Mode menu - Chiffre détecté: {digit}")
                    self.count = 0
                    self.printed = True
                    return str(digit)
                
                # === CODE EXISTANT POUR MODE NORMAL ===
                self.composed_number += str(digit)
                self.last_digit_time = time.time()
                print(f"Numéro composé: {self.composed_number}")
                self.display_manager.show_calling_number(self.composed_number)
                
                # Logique existante pour vérifier les numéros complets...
                service_match = self.check_service_number_match(self.composed_number)
                if service_match:
                    completed_number = service_match
                    self.reset_dialing()
                    return completed_number
                
                main_match = self.check_main_number_match(self.composed_number)
                if main_match:
                    completed_number = main_match
                    self.reset_dialing()
                    return completed_number
                
                if self.is_number_too_long(self.composed_number):
                    print(f"❌ Numéro trop long: {self.composed_number}")
                    self.display_manager.show_unknown_message()
                    time.sleep(3)
                    self.reset_dialing()
                    return None
                
                possible_lengths = self.get_expected_lengths_for_current_number(self.composed_number)
                if possible_lengths:
                    print(f"📞 Composition en cours - longueurs possibles: {possible_lengths}")
                else:
                    print(f"❌ Aucune correspondance possible pour: {self.composed_number}")
                    self.display_manager.show_unknown_message()
                    time.sleep(3)
                    self.reset_dialing()
                    return None
                
                self.count = 0
            self.printed = True

        # Timeout - reset si pas d'activité (code existant)
        if (self.composed_number and 
            (time.time() - self.last_digit_time) > TIMEOUT_RESET):
            print(f"⏰ Timeout - Reset: {self.composed_number}")
            self.reset_dialing()

        return None
    
    def get_composed_number(self):
        """Retourne le numéro actuellement composé"""
        return self.composed_number
    
    def is_composing(self):
        """Retourne True si un numéro est en cours de composition"""
        return bool(self.composed_number)
    
    def refresh_config(self):
        """Met à jour les paramètres depuis le gestionnaire USB (utile pour rechargement à chaud)"""
        old_numero = self.numero_principal
        old_longueur = self.longueur_numero_principal
        
        self.numero_principal = self.usb_manager.get_numero_principal()
        self.longueur_numero_principal = self.usb_manager.get_longueur_numero_principal()
        
        if old_numero != self.numero_principal or old_longueur != self.longueur_numero_principal:
            print(f"🔄 Configuration mise à jour:")
            print(f"   Ancien: {old_numero} ({old_longueur} chiffres)")
            print(f"   Nouveau: {self.numero_principal} ({self.longueur_numero_principal} chiffres)")
    
    def get_status_info(self):
        """Retourne des informations sur l'état du gestionnaire de cadran"""
        return {
            "composed_number": self.composed_number,
            "is_composing": self.is_composing(),
            "numero_principal": self.numero_principal,
            "longueur_numero_principal": self.longueur_numero_principal,
            "service_numbers": SERVICE_NUMBERS.copy(),
            "possible_lengths": self.get_expected_lengths_for_current_number(self.composed_number) if self.composed_number else []
        }

    def set_menu_mode(self, enabled=True):
        """Active/désactive le mode menu pour retourner les chiffres individuels"""
        self.menu_mode = enabled
        if enabled:
            print("🎛️ Mode menu activé - retour chiffres individuels")
        else:
            print("📞 Mode normal activé - retour numéros complets")

    def wait_for_menu_digit(self, timeout_seconds=15):
        """
        Attend un chiffre en mode menu en utilisant process_dialing()
        """
        print(f"🎛️ Attente chiffre menu pendant {timeout_seconds}s...")
        
        # Activer le mode menu
        self.set_menu_mode(True)
        
        # Reset de l'état
        self.reset_dialing(clear_display=False)
        
        start_time = time.time()
        
        try:
            while time.time() - start_time < timeout_seconds:
                if not self.gpio_manager.is_phone_off_hook():
                    print("📞 Téléphone raccroché")
                    return None
                
                # Utiliser la vraie logique qui fonctionne
                result = self.process_dialing()
                if result is not None:
                    print(f"✅ Chiffre reçu en mode menu: {result}")
                    return result
                
                time.sleep(0.01)  # Petite pause
            
            print("⏰ Timeout menu")
            return None
            
        finally:
            # Toujours remettre en mode normal
            self.set_menu_mode(False)