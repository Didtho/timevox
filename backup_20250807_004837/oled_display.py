# oled_display.py
from luma.core.interface.serial import i2c
from luma.oled.device import sh1106
from luma.core.render import canvas
from PIL import ImageFont
from PIL import Image

serial = i2c(port=1, address=0x3C)
device = sh1106(serial, width=128, height=64)

def afficher(l1="", l2="", l3="", taille=12, align="gauche"):
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", taille)
    except:
        font = ImageFont.load_default()

    lignes = [l1, l2, l3]
    with canvas(device) as draw:
        for i, texte in enumerate(lignes):
            bbox = draw.textbbox((0, 0), texte, font=font)
            largeur_texte = bbox[2] - bbox[0]

            if align == "centre":
                x = (device.width - largeur_texte) // 2
            elif align == "droite":
                x = device.width - largeur_texte
            else:  # alignement a gauche par defaut
                x = 0

            y = i * (taille + 4)
            draw.text((x, y), texte, font=font, fill=255)

        
def afficher_image(path):
    try:
        img = Image.open(path).convert("1")

        # Redimensionnement proportionnel pour tenir dans 128x64
        img.thumbnail((128, 64), Image.ANTIALIAS)

        # Creer une image vide 128x64
        bg = Image.new("1", (128, 64), "black")

        # Calculer les positions pour centrer
        x = (128 - img.width) // 2
        y = (64 - img.height) // 2

        # Coller l'image redimensionnee au centre
        bg.paste(img, (x, y))

        # Afficher
        device.display(bg)

    except Exception as e:
        afficher("Erreur image", str(e))
