# luxzenburg

Persoonlijk essay-archief van Erik van Luxzenburg.

- **luxzenburg.nl** — Nederlandstalige essays
- **luxzenburg.org** — Engelstalige essays

Beide sites worden gegenereerd door [Hugo](https://gohugo.io/) uit dezelfde
broncode in deze repository. Geen analytics, geen cookies, geen JavaScript.

Broncode: <https://codeberg.org/eluxzen/luxzenburg>

## Schrijven

Essays leven onder `content/nl/essays/` en `content/en/essays/`. Eén markdown
bestand per essay. De aanbevolen schrijfomgeving is **Obsidian**: open de map
`luxzenburg/` als vault, en je kunt direct schrijven met live preview,
backlinks, en tags. De `.obsidian/` map in deze repo bevat een minimale
gedeelde configuratie.

Een nieuw essay aanmaken kan ook met Hugo:

```bash
hugo new content/nl/essays/2026-04-08-mijn-titel.md
```

Front matter (YAML bovenin) voorbeeld:

```yaml
---
title: "Titel van het essay"
date: 2026-04-08
draft: false
tags: ["systeem-denken", "werk"]
summary: "Een zin of twee voor het overzicht en RSS."
---
```

Zet `draft: true` zolang het stuk niet klaar is — Hugo bouwt drafts standaard
niet mee.

## Lokaal previewen

Eenmalig Hugo installeren (KDE neon / Ubuntu):

```bash
sudo apt install hugo
# of, voor de nieuwste versie:
# download de extended .deb van https://github.com/gohugoio/hugo/releases
```

Daarna in deze map:

```bash
hugo server -D
```

Open <http://localhost:1313/> voor de Nederlandse site of
<http://localhost:1313/en/> voor de Engelse. Wijzigingen verschijnen direct.

## Bouwen voor productie

```bash
hugo --minify
```

Output verschijnt in `public/`. Op de VPS gebeurt dit automatisch via een
git-pull hook — zie `DEPLOY.md` in de hoofdrepo (`luxzen.eu`) voor de
volledige deploy-procedure.

## Structuur

```
luxzenburg/
├── hugo.toml              # site configuratie (NL + EN)
├── content/
│   ├── nl/                # Nederlandstalige content
│   │   ├── _index.md      # homepage
│   │   ├── over.md
│   │   └── essays/
│   └── en/                # Engelstalige content
│       ├── _index.md
│       ├── about.md
│       └── essays/
├── layouts/               # custom templates (geen extern thema)
│   ├── _default/
│   ├── partials/
│   └── index.html
├── assets/css/main.css    # ~250 regels Tufte-achtige CSS
├── static/img/            # afbeeldingen
└── .obsidian/             # gedeelde Obsidian configuratie
```
