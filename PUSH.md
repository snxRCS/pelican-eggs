# Wie du das Repo zu GitHub pusht

## Variante A — mit GitHub CLI (`gh`)

Vorausgesetzt `gh` ist installiert und du bist eingeloggt (`gh auth login`):

```powershell
cd C:\Users\Tobias\Documents\Claude\Projects\Gameserver\pelican-eggs
git init
git add .
git commit -m "Initial commit: TS6-Manager egg"
git branch -M main
gh repo create snxRCS/pelican-eggs --public --source=. --push --description "Pelican Panel eggs by snxRCS"
```

Das erstellt das Repo auf GitHub und pusht in einem Schritt.

## Variante B — klassisch ohne gh

1. Gehe auf <https://github.com/new>
2. **Repository name:** `pelican-eggs`, **Public**, **kein** README/.gitignore/LICENSE dazu (die haben wir schon lokal).
3. Klick **Create repository**.
4. In PowerShell:

```powershell
cd C:\Users\Tobias\Documents\Claude\Projects\Gameserver\pelican-eggs
git init
git add .
git commit -m "Initial commit: TS6-Manager egg"
git branch -M main
git remote add origin https://github.com/snxRCS/pelican-eggs.git
git push -u origin main
```

Beim `git push` fragt Git nach deinem GitHub-Login. Wenn du Zwei-Faktor aktiv hast, brauchst du einen **Personal Access Token** (Settings → Developer settings → Personal access tokens → Tokens (classic) → Generate new token → scope: `repo`). Den Token statt Passwort eingeben.

Alternativ SSH:
```powershell
git remote add origin git@github.com:snxRCS/pelican-eggs.git
```

## Nach dem Push

Die Raw-URL zum direkten Import im Panel wird dann:

```
https://raw.githubusercontent.com/snxRCS/pelican-eggs/main/voice/TS6-Manager-EGG/egg-teamspeak6-manager.json
```

## Spätere Änderungen

```powershell
cd C:\Users\Tobias\Documents\Claude\Projects\Gameserver\pelican-eggs
git add .
git commit -m "kurze Beschreibung"
git push
```
