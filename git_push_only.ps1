# Script Git uniquement - Push de la structure reorganisee vers GitHub

Write-Host "=== TimeVox - Push vers GitHub ===" -ForegroundColor Yellow

# Verifier qu'on a la nouvelle structure
if (-not (Test-Path "timevox\main.py")) {
    Write-Host "Erreur: Structure reorganisee non trouvee" -ForegroundColor Red
    Write-Host "Attendu: timevox\main.py" -ForegroundColor Red
    Write-Host "Assurez-vous d'etre dans le dossier avec la nouvelle structure" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path "version.json")) {
    Write-Host "Erreur: version.json non trouve" -ForegroundColor Red
    Write-Host "La reorganisation semble incomplete" -ForegroundColor Red
    exit 1
}

Write-Host "Structure reorganisee detectee" -ForegroundColor Green

# Afficher un apercu de ce qui va etre envoye
Write-Host ""
Write-Host "Contenu qui sera envoye vers GitHub :" -ForegroundColor Blue
Write-Host "  timevox\          ($(((Get-ChildItem timevox -File).Count)) fichiers)" -ForegroundColor White
Write-Host "  scripts\          ($(((Get-ChildItem scripts -File -Recurse).Count)) fichiers)" -ForegroundColor White
Write-Host "  configs\          ($(((Get-ChildItem configs -File -Recurse).Count)) fichiers)" -ForegroundColor White
Write-Host "  sounds\           ($(((Get-ChildItem sounds -File -Recurse).Count)) fichiers)" -ForegroundColor White
Write-Host "  version.json" -ForegroundColor White
if (Test-Path ".gitignore") { Write-Host "  .gitignore" -ForegroundColor White }

Write-Host ""

# Demander confirmation
$confirmation = Read-Host "Cette operation va REMPLACER tout le contenu de votre GitHub. Continuer ? [y/N]"
if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
    Write-Host "Operation annulee" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Debut de l'operation Git..." -ForegroundColor Blue

# ====== ETAPE 1 : INITIALISATION GIT ======
Write-Host "Initialisation Git..." -ForegroundColor Blue

# Supprimer .git existant si present
if (Test-Path ".git") {
    Remove-Item ".git" -Recurse -Force
    Write-Host "  Ancien .git supprime" -ForegroundColor Green
}

git init | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Erreur lors de l'initialisation Git" -ForegroundColor Red
    exit 1
}

git remote add origin https://github.com/Didtho/timevox.git
Write-Host "Repository Git initialise" -ForegroundColor Green

# ====== ETAPE 2 : CONFIGURATION GIT (si necessaire) ======
Write-Host "Verification configuration Git..." -ForegroundColor Blue

$gitUser = git config --global user.name
$gitEmail = git config --global user.email

if (-not $gitUser -or -not $gitEmail) {
    Write-Host "Configuration Git manquante" -ForegroundColor Yellow
    
    if (-not $gitUser) {
        $userName = Read-Host "Entrez votre nom Git"
        git config --global user.name "$userName"
    }
    
    if (-not $gitEmail) {
        $userEmail = Read-Host "Entrez votre email Git"
        git config --global user.email "$userEmail"
    }
    
    Write-Host "Configuration Git mise a jour" -ForegroundColor Green
} else {
    Write-Host "Configuration Git OK ($gitUser <$gitEmail>)" -ForegroundColor Green
}

# ====== ETAPE 3 : AJOUT DES FICHIERS ======
Write-Host "Ajout des fichiers..." -ForegroundColor Blue

git add .
if ($LASTEXITCODE -ne 0) {
    Write-Host "Erreur lors de l'ajout des fichiers" -ForegroundColor Red
    exit 1
}

# Afficher ce qui sera committe
$statusOutput = git status --porcelain
$fileCount = ($statusOutput | Measure-Object).Count
Write-Host "$fileCount fichiers ajoutes" -ForegroundColor Green

# ====== ETAPE 4 : COMMIT ======
Write-Host "Creation du commit..." -ForegroundColor Blue

git commit -m "Restructuration repository v1.0 - Preparation installation automatique" | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Erreur lors du commit" -ForegroundColor Red
    exit 1
}

git branch -M main
Write-Host "Commit cree sur la branche main" -ForegroundColor Green

# ====== ETAPE 5 : PUSH VERS GITHUB ======
Write-Host "Push vers GitHub..." -ForegroundColor Blue
Write-Host "Remplacement du contenu GitHub en cours..." -ForegroundColor Yellow

git push -u origin main --force
if ($LASTEXITCODE -eq 0) {
    Write-Host "Push reussi !" -ForegroundColor Green
} else {
    Write-Host "Erreur lors du push" -ForegroundColor Red
    Write-Host ""
    Write-Host "Causes possibles :" -ForegroundColor Yellow
    Write-Host "  - Probleme de connexion internet" -ForegroundColor White
    Write-Host "  - Credentials GitHub incorrects" -ForegroundColor White
    Write-Host "  - Repository GitHub inexistant ou inaccessible" -ForegroundColor White
    Write-Host ""
    Write-Host "Solutions :" -ForegroundColor Yellow
    Write-Host "  1. Verifiez https://github.com/Didtho/timevox" -ForegroundColor White
    Write-Host "  2. Configurez vos credentials : git config --global credential.helper manager" -ForegroundColor White
    Write-Host "  3. Relancez le script" -ForegroundColor White
    exit 1
}

# ====== RESUME FINAL ======
Write-Host ""
Write-Host "PUSH TERMINE AVEC SUCCES !" -ForegroundColor Green
Write-Host ""
Write-Host "Resume :" -ForegroundColor Yellow
Write-Host "  Repository Git initialise localement" -ForegroundColor White
Write-Host "  $fileCount fichiers commites" -ForegroundColor White
Write-Host "  Contenu pousse vers GitHub (ancien contenu remplace)" -ForegroundColor White
Write-Host ""
Write-Host "Votre repository GitHub :" -ForegroundColor Cyan
Write-Host "    https://github.com/Didtho/timevox" -ForegroundColor White
Write-Host ""
Write-Host "Pour mettre a jour le Raspberry Pi :" -ForegroundColor Yellow
Write-Host "    ssh pi@votre-raspberry" -ForegroundColor White
Write-Host "    sudo systemctl stop timevox timevox-shutdown" -ForegroundColor White
Write-Host "    mv timevox timevox_old" -ForegroundColor White
Write-Host "    git clone https://github.com/Didtho/timevox.git" -ForegroundColor White
Write-Host "    cd timevox/timevox && python3 main.py" -ForegroundColor White
Write-Host ""
Write-Host "Pret pour l'Etape 2 : Creation des scripts d'installation automatique !" -ForegroundColor Green