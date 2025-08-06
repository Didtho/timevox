#!/usr/bin/env python3
# main.py
"""
Point d'entrée principal pour le système TimeVox
Téléphone à cadran avec enregistrement de messages
"""

from phone_controller import PhoneController
import os
import warnings

# Supprimer les warnings pygame
os.environ['PYGAME_HIDE_SUPPORT_PROMPT'] = '1'
warnings.filterwarnings("ignore", category=UserWarning, module="pygame")
warnings.filterwarnings("ignore", message=".*neon capable.*")
warnings.filterwarnings("ignore", message=".*pkg_resources.*")

def main():
    """Fonction principale"""
    print("=== TimeVox - Système de téléphone à messages ===")
    print("Démarrage du système...")
    
    # Créer et lancer le contrôleur principal
    controller = PhoneController()
    controller.run()


if __name__ == "__main__":
    main()