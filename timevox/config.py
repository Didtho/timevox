# config.py
"""
Configuration centralisée pour le projet TimeVox
Version avec montage USB automatique et numéros spéciaux
"""

import os

# Chemin de base de l'application (dossier contenant ce fichier config.py)
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# Configuration GPIO
BUTTON_GPIO = 17
HOOK_GPIO = 27
SOUND_GPIO = 25  # Max98357A SD pin

# Temporisations et seuils
REST_TIME = 0.3
MIN_IMPULSE_TIME = 0.05
TIMEOUT_RESET = 10

# Numéros de service (fixes, courts) - vérifiés dès qu'on atteint leur longueur exacte
SERVICE_NUMBERS = {
    "0000": {"length": 4, "description": "Paramètres système"},
    "9999": {"length": 4, "description": "Extinction système"},
    "12": {"length": 2, "description": "Numéro spécial 12", "type": "special_audio"},
    "13": {"length": 2, "description": "Numéro spécial 13", "type": "special_audio"},
    "14": {"length": 2, "description": "Numéro spécial 14", "type": "special_audio"},
    "17": {"length": 2, "description": "Numéro spécial 17", "type": "special_audio"},
    "18": {"length": 2, "description": "Numéro spécial 18", "type": "special_audio"}
}

# Numéros cibles pour compatibilité (sera enrichi dynamiquement avec le numéro principal)
TARGET_NUMBERS = ["0000", "9999", "12", "13", "14", "17", "18"]

# Chemins de fichiers audio (relatifs au répertoire de l'application)
SOUNDS_DIR = os.path.join(BASE_DIR, "sounds")
SEARCH_CORRESPONDANT_FILE = os.path.join(SOUNDS_DIR, "search_correspondant.mp3")
BIP_FILE = os.path.join(SOUNDS_DIR, "bip.mp3")

# Configuration USB - Point de montage fixe pour le montage automatique
USB_MOUNT_PATH = "/media/timevox/usb"  # Point de montage fixe pour TimeVox
SPECIAL_NUMBERS_DIR = "Numeros speciaux"  # Dossier sur la clé USB contenant les fichiers MP3 spéciaux
RECORD_DURATION = 60  # secondes (valeur par défaut, peut être surchargée par la config USB)

# Configuration audio
PYGAME_FREQUENCY = 22050
PYGAME_SIZE = -16
PYGAME_CHANNELS = 2
PYGAME_BUFFER = 512

# Configuration enregistrement
FFMPEG_AUDIO_CODEC = "libmp3lame"
FFMPEG_BITRATE = "128k"
AUDIO_CUT_DURATION = 1000  # millisecondes à couper au début et fin

# Configuration affichage
DEFAULT_FONT_SIZE = 12
TIMEVOX_FONT_SIZE = 20
CALLING_FONT_SIZE = 14
COUNTDOWN_FONT_SIZE = 24
SAVING_FONT_SIZE = 11
CALL_ENDED_FONT_SIZE = 20

# Messages d'affichage
MSG_TIMEVOX = "TIMEVOX"
MSG_CALLING = "Vous appelez le"
MSG_SAVING = "Sauvegarde en cours"
MSG_CALL_ENDED = "Appel terminé"
MSG_SECONDS = "secondes"
MSG_SPECIAL_NUMBER = "Numéro spécial"
MSG_PLAYING_AUDIO = "Numéro abrégé"

# Configuration des effets audio
# ==============================

# Configuration des filtres vintage
AVAILABLE_FILTERS = ["aucun", "radio_50s", "telephone", "gramophone"]
DEFAULT_FILTER_TYPE = "radio_50s"
DEFAULT_FILTER_INTENSITY = 0.7
DEFAULT_KEEP_ORIGINAL = True

# Messages d'affichage pour les filtres (ajouter avec les autres MSG_)
MSG_FILTER_CONFIG = "Config filtre"
MSG_FILTER_TYPE = "Type:"
MSG_FILTER_INTENSITY = "Intensite:"
MSG_FILTER_TEST = "Test en cours..."
MSG_FILTER_APPLIED = "Filtre applique"

# Fonction utilitaire pour créer les dossiers nécessaires
def ensure_directories():
    """Crée les dossiers nécessaires s'ils n'existent pas"""
    os.makedirs(SOUNDS_DIR, exist_ok=True)
    print(f"Dossier sounds créé/vérifié: {SOUNDS_DIR}")

def get_project_info():
    """Retourne des informations sur les chemins du projet"""
    return {
        "base_dir": BASE_DIR,
        "sounds_dir": SOUNDS_DIR,
        "search_correspondant": SEARCH_CORRESPONDANT_FILE,
        "bip": BIP_FILE,
        "usb_mount_path": USB_MOUNT_PATH,
        "special_numbers_dir": SPECIAL_NUMBERS_DIR
    }

def get_service_numbers():
    """Retourne la liste des numéros de service avec leurs informations"""
    return SERVICE_NUMBERS.copy()

def is_service_number(number):
    """Vérifie si un numéro est un numéro de service"""
    return number in SERVICE_NUMBERS

def is_special_audio_number(number):
    """Vérifie si un numéro est un numéro spécial audio"""
    return (number in SERVICE_NUMBERS and 
            SERVICE_NUMBERS[number].get("type") == "special_audio")

def get_special_audio_file_path(number, usb_mount_path):
    """Retourne le chemin vers le fichier audio spécial pour un numéro donné"""
    if not is_special_audio_number(number):
        return None
    
    special_dir = os.path.join(usb_mount_path, SPECIAL_NUMBERS_DIR)
    audio_file = os.path.join(special_dir, f"{number}.mp3")
    return audio_file if os.path.exists(audio_file) else None