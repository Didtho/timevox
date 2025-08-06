# Scripts d'installation TimeVox

Ce dossier contient tous les scripts pour l'installation automatique de TimeVox.

## Structure

```
scripts/
â”œâ”€â”€ install/                    # Scripts d'installation
â”‚   â”œâ”€â”€ setup-system.sh       # DÃ©pendances systÃ¨me
â”‚   â”œâ”€â”€ setup-python.sh       # Environnement Python
â”‚   â”œâ”€â”€ setup-audio.sh        # Configuration audio
â”‚   â”œâ”€â”€ setup-gpio.sh         # Permissions GPIO
â”‚   â”œâ”€â”€ setup-services.sh     # Services systemd
â”‚   â””â”€â”€ test-installation.sh  # Tests de validation
â”œâ”€â”€ update/                    # Scripts de mise Ã  jour (futur)
â””â”€â”€ maintenance/               # Scripts de maintenance
    â””â”€â”€ shutdown_button.py     # Bouton d'arrÃªt
```

## Installation automatique

```bash
curl -sSL https://raw.githubusercontent.com/Didtho/timevox/main/install.sh | bash
```

## Scripts individuels

Chaque script peut Ãªtre exÃ©cutÃ© individuellement si nÃ©cessaire :

```bash
# AprÃ¨s avoir clonÃ© le repository
cd timevox
chmod +x scripts/install/*.sh

# ExÃ©cuter un script spÃ©cifique
./scripts/install/setup-system.sh
./scripts/install/setup-python.sh
# etc.
```

## Logs et diagnostic

- **Log d'installation** : `/tmp/timevox_install.log`
- **Rapport de tests** : `/tmp/timevox_test_report.txt`
- **Scripts de diagnostic** : `~/timevox_control.sh`, `~/test_gpio_timevox.py`

## DÃ©pannage

En cas de problÃ¨me lors de l'installation :

1. **Consulter les logs** :
   ```bash
   tail -f /tmp/timevox_install.log
   ```

2. **Relancer un script spÃ©cifique** :
   ```bash
   cd /home/timevox/timevox
   ./scripts/install/setup-audio.sh  # Par exemple
   ```

3. **Tests de validation** :
   ```bash
   ./scripts/install/test-installation.sh
   ```

4. **Nettoyage complet** :
   ```bash
   sudo systemctl stop timevox timevox-shutdown
   sudo systemctl disable timevox timevox-shutdown
   sudo rm -f /etc/systemd/system/timevox*.service
   rm -rf /home/timevox/timevox /home/timevox/timevox_env
   ```

GÃ©nÃ©rÃ© automatiquement par integrate_scripts.ps1
