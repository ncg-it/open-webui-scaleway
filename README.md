# Open WebUI auf Scaleway

Open WebUI unter **https://chat.ncg-it.com**: eine Scaleway Instance mit Docker Compose und Caddy (automatisches HTTPS).
Die Sprachmodelle und die Embeddings für Dokumente kommen über die **Scaleway Generative APIs** (OpenAI-kompatibel, Hosting in der EU). Region: **nl-ams (Amsterdam)**.

```
Internet ─443─▶ Caddy ─▶ Open WebUI ──▶ api.scaleway.ai (Chat + Embeddings)
                              │
                     Block Volume /mnt/data  (täglicher Snapshot)
```

| Teil | Wo |
|---|---|
| Infrastruktur (IP, Security Group, Instance, Daten-Volume, optional DNS) | `terraform/` |
| State-Bucket (einmalig) | `terraform/bootstrap/` |
| App-Stack | `deploy/docker-compose.yml`, `deploy/Caddyfile` |
| Deploy / Backup | `scripts/deploy.sh`, `scripts/snapshot.sh`, `.github/workflows/` |

## Einmalige Einrichtung

### 1. Scaleway-Zugangsdaten (IAM)

In der Scaleway-Konsole unter **IAM → Applications** zwei Applications anlegen, jeweils mit eigener Policy, die auf das Projekt beschränkt ist:

| Application | Permission Sets | Wofür |
|---|---|---|
| `open-webui-terraform` | `InstancesFullAccess`, `BlockStorageFullAccess`, `ObjectStorageFullAccess`, `BillingReadOnly`, optional `DomainsDNSFullAccess` | Terraform, Snapshots, Kosten-Stopp |
| `open-webui-genai` | `GenerativeApisModelAccess` | Open WebUI ruft damit die Modelle auf |

Für beide einen API-Key erzeugen. Die Secret Keys gehören in die eigene lokale Konfiguration und in GitHub-Secrets, nicht in Chats oder ins Repo.

### 2. Lokal Terraform ausführen (Terraform ≥ 1.6)

```bash
export SCW_ACCESS_KEY=...  SCW_SECRET_KEY=...  SCW_DEFAULT_PROJECT_ID=...  SCW_DEFAULT_ORGANIZATION_ID=...
export AWS_ACCESS_KEY_ID=$SCW_ACCESS_KEY AWS_SECRET_ACCESS_KEY=$SCW_SECRET_KEY

# State-Bucket anlegen (einmalig)
terraform -chdir=terraform/bootstrap init && terraform -chdir=terraform/bootstrap apply

# Infrastruktur
cp terraform/terraform.tfvars.example terraform/terraform.tfvars   # SSH-Public-Key eintragen
terraform -chdir=terraform init
terraform -chdir=terraform apply
```

Die Outputs sind `public_ip`, `data_volume_id` und `ssh`.

### 3. DNS

Beim DNS-Anbieter von `ncg-it.com` einen Record anlegen: **A `chat` → `<public_ip>`** (TTL 300).
Liegt die Zone bei Scaleway, kann Terraform das übernehmen: `dns_zone = "ncg-it.com"` setzen.

### 4. App deployen

```bash
cp deploy/.env.example deploy/.env      # WEBUI_SECRET_KEY (openssl rand -hex 32), SCW_GENAI_API_KEY, ACME_EMAIL
bash scripts/deploy.sh <public_ip>
```

Danach https://chat.ncg-it.com öffnen und den ersten Account anlegen. Er wird automatisch Admin.
Anschließend `ENABLE_SIGNUP=false` setzen und erneut deployen. Alternativ im Admin-Panel unter *Settings → General* die Registrierung abschalten.

> Hinweis: Viele Open-WebUI-Einstellungen sind „PersistentConfig“. Die Umgebungsvariablen gelten nur beim ersten Start, danach zählt das Admin-Panel.

### 5. GitHub Actions (optional, für automatische Deploys)

**Secrets:** `SCW_ACCESS_KEY`, `SCW_SECRET_KEY`, `SCW_DEFAULT_PROJECT_ID`, `SCW_DEFAULT_ORGANIZATION_ID`,
`SSH_PUBLIC_KEY`, `SSH_PRIVATE_KEY` (eigener Deploy-Key), optional `SSH_KNOWN_HOSTS`, `WEBUI_SECRET_KEY`, `SCW_GENAI_API_KEY`

**Variables:** `SERVER_HOST` (IP oder `chat.ncg-it.com`), `DOMAIN`, `ACME_EMAIL`, `DATA_VOLUME_ID`, `SERVER_ID`, `COST_LIMIT_EUR`


| Workflow | Auslöser | Was passiert |
|---|---|---|
| `terraform.yml` | PR / Push auf `terraform/**` | PR: `plan`, main: `apply` |
| `deploy.yml` | Push auf `deploy/**`, manuell | Compose-Stack aktualisieren und Healthcheck |
| `bootstrap.yml` | manuell, einmalig | State-Bucket anlegen |
| `backup.yml` | täglich 02:30 UTC | Snapshot des Daten-Volumes, die letzten 7 bleiben erhalten |
| `cost-guard.yml` | alle 6 h, manuell | Kosten-Stopp: ab `COST_LIMIT_EUR` (netto) wird die Instance ausgeschaltet; mit `action=start` wieder einschalten |

## Betrieb

- **Updates:** Dependabot erstellt PRs für neue Open-WebUI- und Caddy-Versionen. Nach dem Merge deployt der Workflow automatisch.
- **Logs:** `ssh deploy@chat.ncg-it.com 'cd /opt/open-webui && docker compose logs -f open-webui'`
- **Restore:** Snapshot in der Konsole in ein Volume umwandeln, die Instance stoppen, die Volumes tauschen (oder in Terraform importieren) und die Instance starten.
- **Kosten:** Instance (PLAY2-MICRO), Flexible IP, 2 × 20 GB SBS und Snapshots ergeben grob 15–25 €/Monat. Dazu kommen die Token-Kosten der Generative APIs.
