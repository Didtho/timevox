# audio_effects.py
"""
Gestionnaire des effets audio vintage pour TimeVox
Applique des filtres "radio années 50" et autres effets vintage
"""

import subprocess
import os
import tempfile
from pydub import AudioSegment
from pydub.effects import normalize, compress_dynamic_range


class AudioEffects:
    def __init__(self, usb_manager=None):
        self.usb_manager = usb_manager
        
        # Paramètres par défaut des effets (plus marqués pour un effet vintage prononcé)
        self.default_effects = {
            "radio_50s": {
                "highpass_freq": 400,      # Plus agressif pour couper les graves
                "lowpass_freq": 2800,      # Plus restrictif pour l'effet radio
                "compression_ratio": 6.0,   # Compression plus forte
                "saturation_level": 0.2,   # Plus de saturation
                "volume_boost": 1.4,       # Plus de boost
                "noise_level": 0.03        # Plus de bruit vintage
            },
            "telephone": {
                "highpass_freq": 350,      # Effet téléphone plus marqué
                "lowpass_freq": 2500,      # Bande passante téléphonique
                "compression_ratio": 8.0,   # Compression très forte
                "saturation_level": 0.15,  # Saturation téléphonique
                "volume_boost": 1.5,       # Boost important
                "noise_level": 0.02        # Bruit de ligne
            },
            "gramophone": {
                "highpass_freq": 100,
                "lowpass_freq": 5000,
                "compression_ratio": 2.0,
                "saturation_level": 0.15,
                "volume_boost": 1.1,
                "noise_level": 0.03
            }
        }
    
    def get_filter_config(self):
        """Récupère la configuration des filtres depuis la clé USB"""
        config = {
            "enabled": False,
            "type": "radio_50s",
            "intensity": 0.7,
            "keep_original": True
        }
        
        if self.usb_manager and self.usb_manager.is_usb_available():
            try:
                usb_config = self.usb_manager.get_config_info()
                if 'filtre_vintage' in usb_config:
                    config["enabled"] = usb_config.get('filtre_vintage', False)
                if 'type_filtre' in usb_config:
                    config["type"] = usb_config.get('type_filtre', 'radio_50s')
                if 'intensite_filtre' in usb_config:
                    config["intensity"] = float(usb_config.get('intensite_filtre', 0.7))
                if 'conserver_original' in usb_config:
                    config["keep_original"] = usb_config.get('conserver_original', True)
                    
                print(f"Configuration filtre chargée: {config}")
            except Exception as e:
                print(f"Erreur lecture config filtre: {e}")
        
        return config
    
    def apply_radio_50s_filter_ffmpeg(self, input_file, output_file, intensity=0.7):
        """
        Applique un filtre radio années 50 avec ffmpeg - Version effet prononcé
        intensity: 0.0 à 1.0 (intensité de l'effet)
        """
        try:
            effect_params = self.default_effects["radio_50s"].copy()
            
            # Ajuster les paramètres selon l'intensité (plus agressif)
            highpass_freq = int(effect_params["highpass_freq"] * (0.7 + intensity * 0.8))  # Plus agressif
            lowpass_freq = int(effect_params["lowpass_freq"] * (1.3 - intensity * 0.7))    # Plus restrictif
            volume_boost = 1.0 + (effect_params["volume_boost"] - 1.0) * intensity
            
            # Filtre plus complexe avec distorsion et EQ vintage
            audio_filter = (
                f"highpass=f={highpass_freq},"                    # Coupe grave aggressive
                f"lowpass=f={lowpass_freq},"                      # Coupe aigu pour effet radio
                f"equalizer=f=800:width_type=h:width=100:g=3,"    # Boost médiums (voix)
                f"equalizer=f=2000:width_type=h:width=200:g=-2,"  # Légère coupe aigu
                f"compand=attacks=0.05:decays=0.2:points=-80/-80|-30/-20|-10/-5|0/-1,"  # Compression forte
                f"volume={volume_boost},"                         # Boost volume
                f"aformat=sample_fmts=s16:sample_rates=22050"
            )
            
            # Commande ffmpeg
            cmd = [
                "ffmpeg", "-y",  # -y pour écraser le fichier de sortie
                "-i", input_file,
                "-af", audio_filter,
                "-acodec", "libmp3lame",
                "-ab", "128k",
                "-loglevel", "error",
                output_file
            ]
            
            print(f"Application filtre radio 50s RENFORCÉ (intensité: {intensity})")
            print(f"Fréquences: {highpass_freq}Hz - {lowpass_freq}Hz")
            print(f"Commande: ffmpeg -y -i input -af \"{audio_filter}\" output")
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
            
            if result.returncode == 0:
                print(f"✅ Filtre appliqué avec succès: {output_file}")
                return True
            else:
                print(f"❌ Erreur ffmpeg: {result.stderr}")
                return False
                
        except subprocess.TimeoutExpired:
            print("❌ Timeout lors de l'application du filtre")
            return False
    def apply_vintage_radio_extreme(self, input_file, output_file, intensity=0.7):
        """
        Version extrême du filtre vintage radio pour un effet très prononcé
        """
        try:
            # Paramètres très agressifs
            highpass_freq = int(500 + intensity * 300)  # 500-800Hz
            lowpass_freq = int(2500 - intensity * 500)  # 2500-2000Hz
            
            # Filtre multi-étapes pour effet radio vintage extrême
            audio_filter = (
                f"highpass=f={highpass_freq},"                      # Coupe grave très agressive
                f"lowpass=f={lowpass_freq},"                        # Coupe aigu très agressive  
                f"equalizer=f=1000:width_type=h:width=500:g=6,"     # Boost médiums très fort
                f"equalizer=f=300:width_type=h:width=100:g=-6,"     # Coupe graves
                f"equalizer=f=4000:width_type=h:width=1000:g=-4,"   # Coupe aigus
                f"compand=attacks=0.02:decays=0.1:points=-80/-80|-20/-10|-5/0|0/5," # Compression extrême
                f"volume=1.6,"                                      # Boost fort
                f"aformat=sample_fmts=s16:sample_rates=22050"
            )
            
            cmd = [
                "ffmpeg", "-y",
                "-i", input_file,
                "-af", audio_filter,
                "-acodec", "libmp3lame",
                "-ab", "128k", 
                "-loglevel", "error",
                output_file
            ]
            
            print(f"🎙️ Application filtre VINTAGE EXTRÊME (intensité: {intensity})")
            print(f"Bande passante ultra-restreinte: {highpass_freq}Hz - {lowpass_freq}Hz")
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
            
            if result.returncode == 0:
                print(f"✅ Filtre extrême appliqué: {output_file}")
                return True
            else:
                print(f"❌ Erreur ffmpeg: {result.stderr}")
                return False
                
        except Exception as e:
            print(f"❌ Erreur filtre extrême: {e}")
            return False
    
    def apply_telephone_filter_pydub(self, input_file, output_file, intensity=0.7):
        """
        Applique un filtre téléphone avec pydub (méthode alternative)
        """
        try:
            print(f"Application filtre téléphone avec pydub (intensité: {intensity})")
            
            # Charger l'audio
            audio = AudioSegment.from_mp3(input_file)
            
            # Appliquer les effets
            if intensity > 0.3:
                # Compression dynamique
                audio = compress_dynamic_range(audio, threshold=-20.0, ratio=3.0, attack=5.0, release=50.0)
            
            if intensity > 0.5:
                # Réduction de la qualité (simulation téléphone)
                audio = audio.set_frame_rate(8000).set_frame_rate(22050)
            
            # Normalisation
            audio = normalize(audio)
            
            # Boost du volume selon l'intensité
            volume_change = int(20 * intensity * 0.3)  # Max +6dB
            if volume_change > 0:
                audio = audio + volume_change
            
            # Exporter
            audio.export(output_file, format="mp3", bitrate="128k")
            print(f"✅ Filtre téléphone appliqué: {output_file}")
            return True
            
        except Exception as e:
            print(f"❌ Erreur filtre pydub: {e}")
            return False
    
    def add_vintage_noise(self, input_file, output_file, noise_level=0.02):
        """
        Ajoute un léger bruit de fond vintage
        """
        try:
            # Générer un bruit rose léger avec ffmpeg
            noise_filter = f"anoisesrc=d=1:c=pink:r=22050:a={noise_level}"
            
            cmd = [
                "ffmpeg", "-y",
                "-i", input_file,
                "-f", "lavfi", "-i", noise_filter,
                "-filter_complex", "[0:a][1:a]amix=inputs=2:duration=first:dropout_transition=0",
                "-acodec", "libmp3lame",
                "-ab", "128k",
                "-loglevel", "error",
                output_file
            ]
            
            result = subprocess.run(cmd, capture_output=True, timeout=30)
            return result.returncode == 0
            
        except Exception as e:
            print(f"Erreur ajout bruit vintage: {e}")
            return False
    
    def process_audio_file(self, input_file):
        """
        Traite un fichier audio avec les effets configurés
        Retourne le chemin du fichier traité, ou None si erreur
        """
        config = self.get_filter_config()
        
        # Si les filtres sont désactivés, retourner le fichier original
        if not config["enabled"]:
            print("Filtres vintage désactivés")
            return input_file
        
        # Vérifier que le fichier d'entrée existe
        if not os.path.exists(input_file):
            print(f"Fichier d'entrée inexistant: {input_file}")
            return None
        
        # Générer le nom du fichier de sortie
        base_name, ext = os.path.splitext(input_file)
        
        if config["keep_original"]:
            # Renommer l'original et créer la version filtrée
            original_file = f"{base_name}_original{ext}"
            filtered_file = input_file  # Le fichier principal devient la version filtrée
            
            try:
                # Sauvegarder l'original
                os.rename(input_file, original_file)
                print(f"Original sauvegardé: {original_file}")
            except Exception as e:
                print(f"Erreur sauvegarde original: {e}")
                return input_file
        else:
            # Écraser le fichier original
            filtered_file = input_file
            original_file = input_file
        
        # Appliquer le filtre selon le type configuré
        filter_type = config["type"]
        intensity = config["intensity"]
        
        print(f"Application du filtre '{filter_type}' avec intensité {intensity}")
        
        success = False
        
        if filter_type == "radio_50s":
            # Choisir entre version normale et extrême selon l'intensité
            if intensity >= 0.8:
                success = self.apply_vintage_radio_extreme(original_file, filtered_file, intensity)
            else:
                success = self.apply_radio_50s_filter_ffmpeg(original_file, filtered_file, intensity)
        elif filter_type == "telephone":
            success = self.apply_telephone_filter_pydub(original_file, filtered_file, intensity)
        elif filter_type == "gramophone":
            # Pour le gramophone, utiliser ffmpeg avec des paramètres spécifiques
            success = self.apply_radio_50s_filter_ffmpeg(original_file, filtered_file, intensity * 0.8)
        else:
            print(f"Type de filtre non reconnu: {filter_type}")
            success = False
        
        if success:
            print(f"✅ Filtre '{filter_type}' appliqué avec succès")
            
            # Vérifier que le fichier de sortie a été créé et n'est pas vide
            if os.path.exists(filtered_file) and os.path.getsize(filtered_file) > 0:
                return filtered_file
            else:
                print("❌ Fichier de sortie vide ou inexistant")
                # Restaurer l'original si nécessaire
                if config["keep_original"] and os.path.exists(original_file):
                    os.rename(original_file, input_file)
                return input_file
        else:
            print(f"❌ Échec application du filtre '{filter_type}'")
            # Restaurer l'original si nécessaire
            if config["keep_original"] and os.path.exists(original_file):
                os.rename(original_file, input_file)
            return input_file
    
    def get_available_filters(self):
        """Retourne la liste des filtres disponibles"""
        return list(self.default_effects.keys())