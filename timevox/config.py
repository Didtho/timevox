# config.py
"""
Configuration centralisée pour le projet TimeVox
Version avec montage USB automatique
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
    "3615": {"length": 4, "description": "Accès minitel"},
    "0000": {"length": 4, "description": "Diagnostics/paramètres"}
}

# Numéros cibles pour compatibilité (sera enrichi dynamiquement avec le numéro principal)
TARGET_NUMBERS = ["3615", "0000"]

# Chemins de fichiers audio (relatifs au répertoire de l'application)
SOUNDS_DIR = os.path.join(BASE_DIR, "sounds")
SEARCH_CORRESPONDANT_FILE = os.path.join(SOUNDS_DIR, "search_correspondant.mp3")
BIP_FILE = os.path.join(SOUNDS_DIR, "bip.mp3")

# Configuration USB - Point de montage fixe pour le montage automatique
USB_MOUNT_PATH = "/media/timevox/usb"  # Point de montage fixe pour TimeVox
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
MSG_SAVING = "Sauvegarde en cours..."
MSG_CALL_ENDED = "Appel termine"
MSG_SECONDS = "secondes"

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
        "usb_mount_path": USB_MOUNT_PATH
    }

def get_service_numbers():
    """Retourne la liste des numéros de service avec leurs informations"""
    return SERVICE_NUMBERS.copy()

def is_service_number(number):
    """Vérifie si un numéro est un numéro de service"""
    return number in SERVICE_NUMBERS