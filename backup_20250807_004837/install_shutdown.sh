#!/bin/bash
# Script d'installation du bouton d'arrêt TimeVox

echo "=== Installation du bouton d'arrêt TimeVox ==="

# Vérifier les permissions root
if [ "$EUID" -ne 0 ]; then
    echo "Ce script doit être exécuté en tant que root (sudo)"
    exit 1
fi

# Chemin du projet (détection automatique de l'utilisateur)
PROJECT_DIR="/home/$(logname)/timevox"

# Créer le répertoire s'il n'existe pas
mkdir -p "$PROJECT_DIR"

# Copier le script Python
cp shutdown_button.py "$PROJECT_DIR/" 2>/dev/null || echo "shutdown_button.py déjà en place"
chmod +x "$PROJECT_DIR/shutdown_button.py"
chown $(logname):$(logname) "$PROJECT_DIR/shutdown_button.py" 2>/dev/null || echo "Permissions déjà correctes"

# Copier le fichier service
cp timevox-shutdown.service /etc/systemd/system/

# Recharger systemd et activer le service
systemctl daemon-reload
systemctl enable timevox-shutdown.service

# Démarrer le service
systemctl start timevox-shutdown.service

# Vérifier le statut
echo ""
echo "=== Statut du service ==="
systemctl status timevox-shutdown.service --no-pager

echo ""
echo "=== Installation terminée ==="
echo "Le bouton d'arrêt est maintenant actif sur GPIO 26"
echo "LED indicatrice sur GPIO 16"
echo "Maintenez le bouton pendant 3 secondes pour arrêter le système"
echo ""
echo "Commandes utiles :"
echo "  - Voir les logs : sudo journalctl -u timevox-shutdown.service -f"
echo "  - Arrêter le service : sudo systemctl stop timevox-shutdown.service"
echo "  - Redémarrer le service : sudo systemctl restart timevox-shutdown.service"