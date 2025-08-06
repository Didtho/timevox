# Dans votre dossier C:\Users\Didier\Documents\TimeVox\Timevox_GIT
Write-Host "=== Réorganisation TimeVox ===" -ForegroundColor Yellow

# Vérifier qu'on a les bons fichiers
if (-not (Test-Path "main.py")) {
    Write-Host "Erreur: main.py non trouvé" -ForegroundColor Red
    exit 1
}

Write-Host "Fichiers TimeVox détectés" -ForegroundColor Green

# Créer la sauvegarde
$backup = "backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
Write-Host "Création sauvegarde: $backup" -ForegroundColor Blue
mkdir $backup
Copy-Item * $backup\ -Recurse -Force

# Créer les nouveaux dossiers
Write-Host "Création des dossiers..." -ForegroundColor Blue
mkdir timevox, scripts, configs, sounds -Force
mkdir scripts\maintenance, scripts\install, scripts\update -Force
mkdir configs\services, configs\templates -Force

# Déplacer les fichiers Python
Write-Host "Déplacement fichiers Python..." -ForegroundColor Blue
$pythonFiles = @("main.py", "phone_controller.py", "audio_manager.py", "audio_effects.py", 
                 "recording_manager.py", "dialer_manager.py", "display_manager.py",
                 "gpio_manager.py", "usb_manager.py", "rtc_manager.py", 
                 "filter_menu_manager.py", "oled_display.py", "config.py", "requirements.txt")

foreach ($file in $pythonFiles) {
    if (Test-Path $file) {
        Move-Item $file timevox\ -Force
        Write-Host "  $file -> timevox\" -ForegroundColor Green
    }
}

# Déplacer les services
if (Test-Path "timevox.service") { Move-Item timevox.service configs\services\ -Force }
if (Test-Path "timevox-shutdown.service") { Move-Item timevox-shutdown.service configs\services\ -Force }

# Déplacer les fichiers spéciaux
if (Test-Path "shutdown_button.py") { Move-Item shutdown_button.py scripts\maintenance\ -Force }
if (Test-Path "install_shutdown.sh") { Move-Item install_shutdown.sh scripts\maintenance\ -Force }
if (Test-Path "config.json") { Move-Item config.json configs\templates\config.json.template -Force }

# Créer version.json
@"
{
  "version": "1.0.0",
  "release_date": "2025-01-15",
  "description": "TimeVox - Téléphone à cadran avec messages vocaux",
  "repository": "https://github.com/Didtho/timevox"
}
"@ | Out-File version.json -Encoding UTF8

# Créer timevox\__init__.py
@"
"""
TimeVox - Système de téléphone à cadran avec enregistrement de messages
"""

__version__ = "1.0.0"
__author__ = "Didtho"
__description__ = "Téléphone à cadran avec messages vocaux pour Raspberry Pi"
"@ | Out-File timevox\__init__.py -Encoding UTF8

Write-Host ""
Write-Host "✅ Réorganisation terminée !" -ForegroundColor Green
Write-Host "Sauvegarde dans: $backup" -ForegroundColor Cyan
Write-Host ""
Write-Host "Prochaine étape: Initialiser Git et pousser vers GitHub" -ForegroundColor Yellow