# 📞 TimeVox

> Transformez vos souvenirs en messages vintage

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Python](https://img.shields.io/badge/Python-3.9+-blue.svg)](https://python.org)
[![Raspberry Pi](https://img.shields.io/badge/Raspberry%20Pi-0%202W-red.svg)](https://www.raspberrypi.org/)
[![Status](https://img.shields.io/badge/Status-Active-green.svg)](https://github.com/Didtho/timevox)

**TimeVox** est un téléphone à cadran connecté qui capture les messages de vos invités avec une authenticité rétro. Parfait pour mariages, anniversaires et événements mémorables, il combine nostalgie et technologie moderne pour créer des souvenirs inoubliables.

<div align="center">
  <img src="docs/images/logo.png" alt="TimeVox - Téléphone à Messages Vintage" width="150">
</div>

## ✨ Fonctionnalités

### 🎵 **Effets Vintage Authentiques**
- **Radio années 50** : Compression dynamique et EQ vintage
- **Téléphone ancien** : Simulation ligne téléphonique d'époque  
- **Gramophone** : Craquements et warmth caractéristiques
- **Intensité réglable** de 0 à 100% pour chaque effet

### ⚙️ **Configuration Intuitive**
- **Menu intégré** : Composez `0000` pour accéder aux paramètres
- **Configuration en temps réel** via le cadran téléphonique
- **Diagnostics système** complets avec affichage OLED
- **Pas besoin d'ordinateur** une fois installé

### 🤖 **Basé sur Raspberry Pi 0 2W**
- **Ultra-compact** : 65 × 30 mm seulement
- **WiFi intégré** pour les mises à jour automatiques
- **Consommation minimale** : moins de 1W

### 💾 **Stockage Intelligent**
- **Sauvegarde automatique** sur clé USB
- **Organisation par date** : dossiers automatiques YYYY-MM-DD
- **Horodatage précis** avec module RTC optionnel
- **Format MP3 optimisé** pour la voix (128kbps mono)

### 🔄 **Mises à Jour OTA**
- **Vérification automatique** au démarrage
- **Installation via menu** téléphonique
- **Sauvegarde de configuration** automatique
- **Notifications** sur écran OLED

## 🚀 Installation Express

```bash
curl -sSL https://raw.githubusercontent.com/Didtho/timevox/main/install.sh | bash
```

**C'est tout !** Le script configure automatiquement tout le système en 15 minutes.

## 📋 Matériel Requis

### **Obligatoire** ⭐
| Composant | Description | Prix estimé |
|-----------|-------------|-------------|
| **Téléphone à cadran** | Vintage | ~40€ |
| **Raspberry Pi 0 2W** | Quad-core ARM, WiFi intégré | ~22€ |
| **Carte micro SD** | 16Go classe 10 minimum | ~8€ |
|-----------|-------------|-------------|
| **Module RTC DS3231** | Horodatage précis sans internet | ~5€ |
| **Amplificateur MAX98357A** | Audio I2S haute qualité | ~3€ |
| **Écran OLED 128x64** | Affichage des informations | ~4€ |
| **Micro USB** | Pour l'enregistrement | ~2€ |

## 🔧 Installation Détaillée

### 1️⃣ **Préparation de la carte SD**

1. **Téléchargez** [Raspberry Pi Imager](https://www.raspberrypi.org/software/)
2. **Sélectionnez** :
   - Modèle : `Raspberry Pi 0 2W`
   - OS : `Raspberry Pi OS Lite (32-bit)`
   - Stockage : Votre carte micro SD

3. **Configurez** les paramètres avancés :
   ```
   Nom d'hôte    : timevox
   SSH           : ✅ Activé
   Utilisateur   : timevox
   Mot de passe  : [votre choix]
   WiFi          : ✅ Configuré avec vos identifiants
   Timezone      : Europe/Paris
   ```

4. **Flashez** la carte SD et insérez-la dans le Pi

### 2️⃣ **Premier démarrage**

1. **Connectez** l'alimentation du Raspberry Pi
2. **Attendez** 2-3 minutes le premier boot
3. **Trouvez l'IP** du Pi sur votre réseau :
   - [Advanced IP Scanner](https://www.advanced-ip-scanner.com/fr/) (recommandé)
   - Interface de votre box internet
   - Ou tentez : `ping timevox.local`

### 3️⃣ **Connexion SSH**

**Windows (PuTTY)** :
```bash
# Téléchargez PuTTY depuis https://www.putty.org/
# Host Name: [IP du Pi]  Port: 22  Connection: SSH
```

**macOS/Linux** :
```bash
ssh timevox@[IP_DU_PI]
```

### 4️⃣ **Installation automatique**

```bash
curl -sSL https://raw.githubusercontent.com/Didtho/timevox/main/install.sh | bash
```

Le script va automatiquement :
- ✅ Mettre à jour le système
- 📦 Installer Python 3.9+ et dépendances
- 🎵 Configurer FFmpeg pour l'audio
- ⚙️ Activer I2C, SPI et GPIO
- 🚀 Configurer le service au démarrage

**Durée** : ~15 minutes

### 5️⃣ **Premier test**

1. **Insérez** une clé USB (formatée en FAT32)
2. **Redémarrez** : `sudo reboot`
3. **Testez** :
   - Décrochez → "TimeVox" s'affiche
   - Composez `1972` → Annonce par défaut
   - Enregistrez un message test
   - Vérifiez le fichier sur la clé USB

## 🎛️ Configuration

### **Fichier config.json**

Le système crée automatiquement un fichier `config.json` sur votre clé USB :

```json
{
  "numero_principal": "1972",
  "longueur_numero_principal": 4,
  "duree_enregistrement": 30,
  "volume_audio": 2,
  "filtre_vintage": true,
  "type_filtre": "radio_50s",
  "intensite_filtre": 0.7,
  "conserver_original": true
}
```

### **Configuration via téléphone**

Composez `0000` sur le cadran pour accéder au menu :

- **`0000` → `1`** : Diagnostics système
- **`0000` → `2`** : Configuration des filtres vintage  
- **`0000` → `3`** : Mises à jour système

### **Personnalisation des annonces**

1. Enregistrez vos annonces au format **MP3**
2. Placez-les dans le dossier **`Annonce/`** de la clé USB
3. TimeVox choisira **aléatoirement** parmi les fichiers disponibles

**Exemple d'annonce** :
> "Bonjour, vous êtes bien chez Marie et Pierre. Nous sommes ravis que vous partagiez cette soirée avec nous ! Laissez-nous votre plus beau message après le bip..."

## 🔌 Câblage

### **Module RTC DS3231**
```
RTC → Raspberry Pi
VCC → 3.3V (Pin 1)
GND → GND (Pin 6)
SDA → GPIO 2 (Pin 3)
SCL → GPIO 3 (Pin 5)
```

### **Amplificateur MAX98357A**
```
MAX98357A → Raspberry Pi
VIN → 5V (Pin 2)
GND → GND (Pin 6)
DIN → GPIO 21 (Pin 40)
BCLK → GPIO 18 (Pin 12)
LRC → GPIO 19 (Pin 35)
SD → GPIO 25 (Pin 22)
```

### **Écran OLED 128x64**
```
OLED → Raspberry Pi
VCC → 3.3V (Pin 1)
GND → GND (Pin 6)
SDA → GPIO 2 (Pin 3)
SCL → GPIO 3 (Pin 5)
```

## 📁 Structure des Fichiers

```
USB/
├── Annonce/              # Fichiers MP3 d'annonce
│   ├── annonce1.mp3
│   └── annonce2.mp3
├── Messages/             # Messages enregistrés
│   ├── 2024-03-15/
│   │   ├── message_20240315_143022.mp3
│   │   └── message_20240315_143022_original.mp3
│   └── 2024-03-16/
├── Parametres/
│   └── config.json      # Configuration système
└── Logs/                # Logs de diagnostic
    ├── events_2024-03-15.log
    └── audio_debug.log
```

## 🛠️ Dépannage

### **Pas de connexion SSH**
- ✅ Vérifiez que SSH est activé dans Raspberry Pi Imager
- 🔍 Confirmez l'adresse IP avec Advanced IP Scanner
- 📡 Testez la connectivité : `ping [IP_DU_PI]`

### **Enregistrement muet**
- 🎤 Vérifiez la détection du micro : `arecord -l`
- 🔌 Contrôlez la connexion USB du microphone

### **Mauvais horodatage**
- 🕐 Installez un module RTC DS3231 (recommandé)
- 🌐 Synchronisez via WiFi : `sudo ntpdate -s time.nist.gov`
- ⚙️ Vérifiez la timezone : `timedatectl status`

## 🔄 Mises à Jour

TimeVox vérifie automatiquement les mises à jour au démarrage.

**Installation manuelle** :
1. Composez `0000` → `3` → `2` (vérifier)
2. Si une MAJ est disponible : `0000` → `3` → `3` (installer)
3. Le système redémarre automatiquement

**Via SSH** :
```bash
cd /home/timevox/timevox
git pull origin main
sudo systemctl restart timevox
```

## 🎪 Cas d'Usage

### **Mariage** 💍
- Annonce personnalisée du couple
- Messages des invités pendant le cocktail
- Souvenirs audio organisés par date
- Partage facile avec les familles

### **Anniversaire** 🎂
- Messages surprise d'amis distants
- Témoignages d'enfants et petits-enfants
- Compilation automatique des souvenirs
- Animation vintage originale

### **Événement d'entreprise** 🏢
- Témoignages clients/collaborateurs
- Messages de motivation d'équipe
- Archive des moments forts
- Objet de conversation unique

## 📜 Licence

Ce projet est sous licence **MIT**. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

## 💝 Soutenir le Projet

Si TimeVox vous plaît, vous pouvez soutenir son développement :

[![PayPal](https://img.shields.io/badge/PayPal-Faire%20un%20don-blue.svg)](https://www.paypal.com/donate/?hosted_button_id=63HDAV7NYT3QC&locale.x=fr_FR)

## 📞 Contact & Support

- **🐛 Bugs** : [Issues GitHub](https://github.com/Didtho/timevox/issues)
- **📖 Documentation** : [Wiki GitHub](https://github.com/Didtho/timevox/wiki)
- **💬 Discussions** : [GitHub Discussions](https://github.com/Didtho/timevox/discussions)
- **🌐 Site web** : [timevox.mirimix.fr](https://timevox.mirimix.fr)

## 🙏 Remerciements

- **Raspberry Pi Foundation** pour la plateforme exceptionnelle
- **Communauté open source** pour les bibliothèques utilisées
- **Contributeurs** qui améliorent le projet

---

<div align="center">

**Créé avec ❤️ par [Didtho](https://github.com/Didtho)**

*TimeVox - Quand la nostalgie rencontre l'innovation* 📞✨

</div>