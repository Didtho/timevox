# gpio_manager.py
"""
Gestionnaire des GPIO pour le téléphone TimeVox
"""

import RPi.GPIO as GPIO
from config import BUTTON_GPIO, HOOK_GPIO, SOUND_GPIO


class GPIOManager:
    def __init__(self):
        self.setup_gpio()
    
    def setup_gpio(self):
        """Initialise la configuration des GPIO"""
        GPIO.setmode(GPIO.BCM)
        GPIO.setwarnings(False)
        GPIO.setup(BUTTON_GPIO, GPIO.IN, pull_up_down=GPIO.PUD_UP)
        GPIO.setup(HOOK_GPIO, GPIO.IN, pull_up_down=GPIO.PUD_UP)
        GPIO.setup(SOUND_GPIO, GPIO.OUT)
        GPIO.output(SOUND_GPIO, GPIO.LOW)  # Son coupé par défaut
        print("GPIO initialisés")
    
    def is_button_pressed(self):
        """Retourne True si le bouton du cadran est pressé"""
        return not GPIO.input(BUTTON_GPIO)
    
    def is_phone_off_hook(self):
        """Retourne True si le téléphone est décroché"""
        return GPIO.input(HOOK_GPIO) == GPIO.LOW
    
    def is_phone_on_hook(self):
        """Retourne True si le téléphone est raccroché"""
        return GPIO.input(HOOK_GPIO) == GPIO.HIGH
    
    def enable_sound(self):
        """Active la sortie audio"""
        GPIO.output(SOUND_GPIO, GPIO.HIGH)
    
    def disable_sound(self):
        """Désactive la sortie audio"""
        GPIO.output(SOUND_GPIO, GPIO.LOW)
    
    def cleanup(self):
        """Nettoie les ressources GPIO"""
        GPIO.cleanup()
        print("GPIO nettoyés")
        
    def gpio_read(self, pin):
        """Lit l'état d'un GPIO quelconque"""
        try:
            return GPIO.input(pin)
        except:
            return False
            
    def setup_input_pin(self, pin):
        """Configure un GPIO en entrée avec pull-up"""
        try:
            GPIO.setup(pin, GPIO.IN, pull_up_down=GPIO.PUD_UP)
            return True
        except:
            return False

    def setup_output_pin(self, pin):
        """Configure un GPIO en sortie"""
        try:
            GPIO.setup(pin, GPIO.OUT)
            return True
        except:
            return False

    def gpio_write(self, pin, value):
        """Écrit sur un GPIO"""
        try:
            GPIO.output(pin, value)
        except:
            pass

    def gpio_read(self, pin):
        """Lit l'état d'un GPIO quelconque"""
        try:
            return GPIO.input(pin)
        except:
            return False