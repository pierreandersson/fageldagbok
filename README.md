# Fageldagbok

En personlig fageldagbok som visar observationer rapporterade via [Artportalen](https://www.artportalen.se/). iOS-app i SwiftUI med PHP/SQLite-backend som synkar data fran SOS API (Species Observation System).

## Arkitektur

```
iOS-app (SwiftUI)  -->  Backend (PHP + SQLite)  -->  SOS API (Artportalen)
                          pierrea.se/krysslista
```

**iOS-appen** visar data fran backenden och cachar lokalt for snabb uppstart.
**Backenden** lagrar alla observationer i SQLite och synkar mot SOS API vid varje refresh samt via cron.

## Funktioner

- **Dagbok** - Observationer grupperade per dag och lokal, med filtrering pa lan och omrade
- **Arter** - Artlista och livslista (forsta observation per art)
- **Karta** - Alla lokaler pa karta med observation/artantal
- **Statistik** - Diagram: arter per ar, observationer per manad, toplistor

## Teknik

| Lager | Stack |
|-------|-------|
| iOS | SwiftUI, Swift Concurrency, MapKit, Charts |
| Backend | PHP, SQLite (WAL), cURL |
| Auth | OAuth 2.0 + PKCE via SLU/Artdatabanken |
| Deploy | GitHub Actions, SFTP |
| Sync | Cron (2x dagligen) + app-triggrad synk |

## Backend API

Basurl: `https://pierrea.se/krysslista/api.php`

| Endpoint | Beskrivning |
|----------|-------------|
| `?q=summary` | Totalt antal obs, arter, lokaler, arsintervall |
| `?q=observations` | Paginerade observationer med filter (year, county, species, area) |
| `?q=species` | Artlista med antal observationer |
| `?q=lifelist` | Livslista: unika arter, forsta obs-datum och plats |
| `?q=localities` | Lokaler med koordinater och antal |
| `?q=stats` | Per ar, per manad, toplistor |
| `?q=areas` | Geografiska omradespresets (Takern, Oland) |
| `?q=live` | Dagens observationer direkt fran SOS API |
| `?q=sync` | Synka alla obs fran SOS API till databasen |
| `?q=auth-status` | Token-status |

## Projektstruktur

```
Fageldagbok/                  # iOS-app (Xcode)
  Models/                     # BirdObservation, Species, Summary
  Services/                   # APIClient, LocalStore
  ViewModels/                 # BirdViewModel
  Views/                      # DagbokView, ArterView, KartaView, StatistikView

krysslista/                   # PHP-backend
  api.php                     # REST API
  seed-from-api.php           # Bulk-import fran SOS API
  auth-start.php              # OAuth-start
  auth-callback.php           # OAuth-callback
  token-helpers.php           # Token-hantering
  config.php                  # Konfiguration (gitignored)
  fageldagbok.db              # SQLite-databas (gitignored)

.github/workflows/
  deploy.yml                  # Deploy backend via SFTP vid push
  sync.yml                    # Cron-synk kl 06:00 och 21:00
```

## Setup

### Backend

1. Skapa `config.php` med OAuth-uppgifter, SOS API-nyckel och sync-nyckel
2. Kor `auth-start.php` i webblasaren for att autentisera mot Artportalen
3. Kor `seed-from-api.php` for initial databasimport

### iOS

1. Kopiera `Secrets.example.swift` till `Secrets.swift` och fyll i sync-nyckeln
2. Oppna `Fageldagbok.xcodeproj` i Xcode
3. Bygg och kor pa simulator eller enhet

### GitHub Secrets

| Secret | Anvandning |
|--------|-----------|
| `FTP_USER` | SFTP-anvandarnamn for deploy |
| `FTP_HOST` | SFTP-host |
| `FTP_PASS` | SFTP-losenord |
| `SYNC_KEY` | Nyckel for sync-endpoint |
