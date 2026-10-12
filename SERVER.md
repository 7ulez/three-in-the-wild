# Server auf Unraid (24/7) mit Cloudflare Tunnel

Ergebnis: Deine Freunde öffnen `https://spiel.DEINE-DOMAIN` im Browser, geben das Passwort ein und spielen - ohne Installation, ohne Tailscale.

## 1. Cloudflare Tunnel anlegen
1. Cloudflare Dashboard > Zero Trust > Networks > Tunnels > "Create a tunnel" > Typ "Cloudflared".
2. Name z. B. `wild`. Den angezeigten **Token** kopieren (langer Text nach `--token`). Den Connector-Schritt nicht auf dem PC ausführen, das macht gleich der Container.
3. Unter "Public Hostnames" zwei Einträge anlegen:
   - `spiel.DEINE-DOMAIN` -> Typ **HTTP**, URL `game:24681`
   - `ws.DEINE-DOMAIN`    -> Typ **HTTP**, URL `game:24680`
   (WebSockets sind bei Cloudflare standardmäßig an.)

## 2. Auf dem Unraid-Server starten
1. Diesen Ordner (`camping_survival`) nach `/mnt/user/appdata/three-in-the-wild` kopieren.
2. `docker-compose.yml` öffnen und eintragen: `PASSWORT`, `DEINE-DOMAIN` (bei WS_URL), `TUNNEL-TOKEN`.
3. Unraid-Terminal:
   ```
   cd /mnt/user/appdata/three-in-the-wild
   docker compose up -d --build
   ```
   (Alternativ das Plugin "Docker Compose Manager" aus den Community Apps nutzen und den Inhalt der compose-Datei dort einfügen.)
4. Der erste Start lädt Godot herunter und dauert ein paar Minuten. Logs: `docker compose logs -f game` - dort steht "Server startet ...".

## 3. Spielen
`https://spiel.DEINE-DOMAIN` öffnen > Name/Figur wählen > Passwort > "Beitreten". Bis zu 4 Spieler (Platz 4 = Gast).

## Hinweise
- Die Welt läuft auf dem Server weiter, solange der Container läuft (Tageszeit, aufgestellte Zelte/Gegenstände). Ein Neustart setzt sie zurück, gespeichert wird nichts.
- Nicht synchronisiert (wie bisher): herumliegende Gegenstände, Feuer-/Topf-Zustand, Fische, Tiere, Fallen.
- Update des Spiels: neue Dateien in den Ordner kopieren, dann `docker compose up -d --build`.
- Auch PC-Spieler können über die Adresse beitreten: Host-IP `wss://ws.DEINE-DOMAIN` eintragen.
- Ohne Cloudflare im LAN: Ports 24680/24681 in der compose-Datei veröffentlichen (`ports:`) und `http://UNRAID-IP:24681` öffnen.

## Variante mit GitHub (automatisch bauen)
- Der Workflow `.github/workflows/docker.yml` baut bei jedem Upload auf `main` das Image `ghcr.io/7ulez/three-in-the-wild:latest`.
- Einmalig auf GitHub: Profil > Packages > das Paket öffnen > Package settings > Sichtbarkeit auf **Public** (im Image stehen keine Geheimnisse, das Passwort kommt erst auf dem Server dazu). Sonst muss Unraid sich bei ghcr.io anmelden.
- Auf Unraid dann `docker-compose.unraid.yml` statt `docker-compose.yml` verwenden. Update: `docker compose pull && docker compose up -d`.
