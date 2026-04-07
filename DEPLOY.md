# Deploy luxzenburg.nl & luxzenburg.org op de Yourhosting VPS

Deze handleiding is geschreven voor de bestaande VPS waarop al
`luxzen.eu` (Ghost) draait via Docker Compose. We voegen daar twee
statische sites aan toe — `luxzenburg.nl` (NL) en `luxzenburg.org` (EN) —
beide gegenereerd door Hugo uit één Codeberg-repository.

Volg de stappen in volgorde. Alles is omkeerbaar tot aan stap 6 (DNS).

---

## 0. Vooraf

Wat je nodig hebt:

- SSH-toegang tot de VPS
- Toegang tot het Yourhosting controlepaneel (voor DNS van `luxzenburg.nl`
  en `luxzenburg.org`)
- Een Codeberg-account (`eluxzen` is al aangemaakt)
- Lokaal Hugo geïnstalleerd op je Framework laptop (zie README in
  `luxzenburg/`)

> Tip: dit hele plan kun je ook aan **Claude Code op de VPS zelf** geven.
> Installeer daar `claude` en plak deze DEPLOY.md als eerste prompt.

---

## 1. Codeberg repo aanmaken en eerste push

Maak op <https://codeberg.org/repo/create> een nieuwe **lege** repository:

- Eigenaar: `eluxzen`
- Naam: `luxzenburg`
- Zichtbaarheid: naar smaak (publiek past bij de filosofie, maar privé mag)
- **Niet** initialiseren met README/license — die staan al in deze repo

Op je laptop, vanuit deze `luxzen.eu` werkmap:

```bash
# We knippen luxzenburg/ los uit de monorepo en maken er een eigen repo van.
cd /tmp
cp -r ~/path/to/luxzen.eu/luxzenburg luxzenburg-new
cd luxzenburg-new
git init -b main
git add .
git commit -m "Initial Hugo skeleton: NL + EN essays, custom Tufte-style theme"
git remote add origin git@codeberg.org:eluxzen/luxzenburg.git
git push -u origin main
```

> Als je SSH bij Codeberg nog niet geconfigureerd hebt: voeg je publieke
> SSH-key toe op <https://codeberg.org/user/settings/keys>.

Vanaf nu is `luxzenburg/` in deze `luxzen.eu` repo overbodig — je kunt 'm
in een vervolg-commit verwijderen, óf laten staan als referentie. Mijn
voorkeur: verwijderen zodra de Codeberg-repo werkt, om geen twee waarheden
te hebben.

---

## 2. Hugo lokaal installeren (KDE neon)

```bash
sudo apt update
sudo apt install hugo
hugo version
```

Als de Ubuntu-versie te oud blijkt (Hugo evolueert snel), download de
nieuwste **extended** `.deb` van
<https://github.com/gohugoio/hugo/releases> en installeer met
`sudo dpkg -i hugo_extended_*.deb`.

Lokaal previewen vanuit de Codeberg-clone:

```bash
git clone git@codeberg.org:eluxzen/luxzenburg.git
cd luxzenburg
hugo server -D
```

Open <http://localhost:1313/>. Wijzigingen in `content/` zijn live.

---

## 3. DNS instellen bij Yourhosting

Voor **beide** domeinen, in het Yourhosting DNS-paneel:

| Type  | Naam   | Waarde                  |
|-------|--------|-------------------------|
| A     | `@`    | `<IP van je VPS>`       |
| A     | `www`  | `<IP van je VPS>`       |

(Als je IPv6 hebt: voeg ook AAAA-records toe.)

Wacht tot DNS propagatie klaar is. Check met:

```bash
dig +short luxzenburg.nl
dig +short luxzenburg.org
```

Beide moeten je VPS-IP teruggeven voor je verder gaat.

---

## 4. VPS voorbereiden

SSH naar de VPS. Maak doelmappen voor de gebouwde sites:

```bash
sudo mkdir -p /var/www/luxzenburg-nl
sudo mkdir -p /var/www/luxzenburg-en
sudo mkdir -p /var/www/certbot   # voor Let's Encrypt http-01 challenge
sudo mkdir -p /srv/luxzenburg    # hier komt de git checkout

sudo chown -R $USER:$USER /srv/luxzenburg /var/www/luxzenburg-nl /var/www/luxzenburg-en
```

Installeer Hugo op de VPS (zelfde aanpak als op je laptop):

```bash
sudo apt install hugo
```

Clone de Codeberg repo (gebruik HTTPS als de VPS geen SSH-key bij Codeberg
heeft, of voeg een deploy key toe):

```bash
cd /srv
git clone https://codeberg.org/eluxzen/luxzenburg.git luxzenburg
cd luxzenburg
```

Eerste handmatige build, voor beide talen:

```bash
hugo --minify --destination /var/www/luxzenburg-nl --baseURL https://luxzenburg.nl/ --lang nl
hugo --minify --destination /var/www/luxzenburg-en --baseURL https://luxzenburg.org/ --lang en
```

> Nuance: Hugo's multilingual setup bouwt standaard beide talen in één
> output-tree (`public/` en `public/en/`). Voor onze split-domain opzet
> bouwen we elke taal apart met `--lang` zodat elke output-map zijn eigen
> root heeft. Werkt prima.

---

## 5. docker-compose.yml aanpassen — nginx mounts

In `docker-compose.yml` van je `luxzen.eu` repo, voeg aan de `nginx`
service deze volume-mounts toe:

```yaml
  nginx:
    image: nginx:latest
    container_name: ghost_nginx
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d
      - /etc/letsencrypt:/etc/letsencrypt
      - /var/www/luxzenburg-nl:/var/www/luxzenburg-nl:ro   # ← nieuw
      - /var/www/luxzenburg-en:/var/www/luxzenburg-en:ro   # ← nieuw
      - /var/www/certbot:/var/www/certbot                  # ← nieuw
    depends_on:
      - ghost
```

Pull deze repo op je VPS (of kopieer de wijziging handmatig) en herstart
alleen nginx:

```bash
cd /pad/naar/luxzen.eu
git pull
docker compose up -d nginx
```

De nginx container draait nu met de twee nieuwe vhosts uit
`nginx/conf.d/luxzenburg.nl.conf` en `luxzenburg.org.conf`. Hij zal
**klagen over ontbrekende SSL-certificaten** — dat lossen we nu op.

---

## 6. Let's Encrypt certificaten

Eenmalig, vanaf de VPS host (niet uit de container):

```bash
sudo apt install certbot

sudo certbot certonly --webroot \
  -w /var/www/certbot \
  -d luxzenburg.nl -d www.luxzenburg.nl \
  --email jouw@email.nl --agree-tos --no-eff-email

sudo certbot certonly --webroot \
  -w /var/www/certbot \
  -d luxzenburg.org -d www.luxzenburg.org \
  --email jouw@email.nl --agree-tos --no-eff-email
```

> Als certbot faalt omdat poort 80 al door de nginx-container in gebruik
> is: dat is normaal — daarom gebruiken we `--webroot` in plaats van
> `--standalone`. De http-01 challenge wordt door nginx zelf geserveerd
> via `/.well-known/acme-challenge/` (zie de vhost configs).

Herstart nginx zodat de nieuwe certs worden ingelezen:

```bash
docker compose restart nginx
```

Test:

```bash
curl -I https://luxzenburg.nl
curl -I https://luxzenburg.org
```

Beide moeten `200 OK` teruggeven.

Auto-renewal: certbot installeert standaard een systemd timer. Voeg een
deploy-hook toe zodat nginx na renewal opnieuw laadt:

```bash
sudo mkdir -p /etc/letsencrypt/renewal-hooks/deploy
echo '#!/bin/sh
docker compose -f /pad/naar/luxzen.eu/docker-compose.yml restart nginx
' | sudo tee /etc/letsencrypt/renewal-hooks/deploy/restart-nginx.sh
sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/restart-nginx.sh
```

---

## 7. Auto-deploy hook (git pull → hugo build)

Doel: elke `git push` naar de Codeberg main-branch verschijnt binnen een
paar minuten op de live site, zonder dat jij iets op de VPS hoeft te doen.

Voor de eenvoud beginnen we met een **systemd timer** die elke 3 minuten
checkt of er nieuwe commits zijn. Geen webhooks, geen CI, niks om kapot te
gaan.

`/etc/systemd/system/luxzenburg-deploy.service`:

```ini
[Unit]
Description=Pull luxzenburg from Codeberg and rebuild Hugo sites
After=network-online.target

[Service]
Type=oneshot
User=erik
WorkingDirectory=/srv/luxzenburg
ExecStart=/usr/bin/git pull --ff-only
ExecStart=/usr/bin/hugo --minify --destination /var/www/luxzenburg-nl --baseURL https://luxzenburg.nl/ --lang nl
ExecStart=/usr/bin/hugo --minify --destination /var/www/luxzenburg-en --baseURL https://luxzenburg.org/ --lang en
```

`/etc/systemd/system/luxzenburg-deploy.timer`:

```ini
[Unit]
Description=Check Codeberg for luxzenburg updates every 3 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=3min
Unit=luxzenburg-deploy.service

[Install]
WantedBy=timers.target
```

Activeren:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now luxzenburg-deploy.timer
sudo systemctl list-timers | grep luxzenburg
```

Logs bekijken:

```bash
journalctl -u luxzenburg-deploy.service -f
```

> Liever een echte webhook-deploy met Codeberg → VPS push? Dat kan later
> met Forgejo Actions / Woodpecker CI of een kleine `webhook` daemon op
> de VPS. Voor nu is 3 minuten latency vrijwel altijd ruim voldoende voor
> een essay-blog.

---

## 8. Eerste echte test

Op je laptop, vanuit de Codeberg-clone:

```bash
# Maak een nieuwe essay
hugo new content/nl/essays/2026-04-08-test.md
$EDITOR content/nl/essays/2026-04-08-test.md   # zet draft: false

git add .
git commit -m "Add test essay"
git push
```

Wacht tot de timer afloopt (max 3 minuten) en open
<https://luxzenburg.nl/essays/test/>. Check ook
<https://luxzenburg.nl/essays/index.xml> voor de RSS-feed.

---

## 9. Wat hierna nog kan (optioneel, niet nu)

- **Modernisering luxzen.eu compose**: `mysql:5.7` → `mysql:8.0`,
  versies pinnen, secrets naar `.env`. Aparte taak — pak ik op zodra je
  een backup hebt gemaakt van de Ghost content + database.
- **Watchtower** toevoegen voor automatische container-updates.
- **Backups** van `/srv/luxzenburg` (al in git, dus al veilig) en van
  `/var/www/luxzenburg-{nl,en}` (afgeleid, dus niet nodig om te backuppen
  — kan altijd opnieuw gebouwd worden).
- **Webfont** ET Book of Source Serif lokaal serveren uit `static/fonts/`
  voor identieke typografie op elk apparaat.
- **Decap CMS** of **TinaCMS** als je ooit vanaf je telefoon wilt
  schrijven zonder Obsidian of git.

---

## Rollback

Als er iets misgaat met de nieuwe sites, raakt `luxzen.eu` zelf niets —
de Ghost setup is volledig ongemoeid. Om tijdelijk de luxzenburg vhosts
uit te schakelen:

```bash
cd /pad/naar/luxzen.eu
mv nginx/conf.d/luxzenburg.nl.conf nginx/conf.d/luxzenburg.nl.conf.disabled
mv nginx/conf.d/luxzenburg.org.conf nginx/conf.d/luxzenburg.org.conf.disabled
docker compose restart nginx
```

Klaar.
