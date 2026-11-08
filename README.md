# Open WebUI on Scaleway

Open WebUI at **https://chat.ncg-it.com**: one Scaleway instance running Docker Compose and Caddy (automatic HTTPS).
The language models and the document embeddings come from the **Scaleway Generative APIs** (OpenAI-compatible, hosted in the EU). Region: **nl-ams (Amsterdam)**.

```
Internet ─443─▶ Caddy ─▶ Open WebUI ──▶ api.scaleway.ai (chat + embeddings)
                              │
                     Block volume /mnt/data  (daily snapshot)
```

| Part | Where |
|---|---|
| Infrastructure (IP, security group, instance, data volume, optional DNS) | `terraform/` |
| State bucket (one-off) | `terraform/bootstrap/` |
| App stack | `deploy/docker-compose.yml`, `deploy/Caddyfile` |
| Deploy / backup | `scripts/deploy.sh`, `scripts/snapshot.sh`, `.github/workflows/` |

## One-time setup

### 1. Scaleway credentials (IAM)

In the Scaleway console under **IAM → Applications**, create two applications, each with its own policy scoped to the project:

| Application | Permission sets | Used for |
|---|---|---|
| `open-webui-terraform` | `InstancesFullAccess`, `BlockStorageFullAccess`, `ObjectStorageFullAccess`, `BillingReadOnly`, optional `DomainsDNSFullAccess` | Terraform, snapshots, cost guard |
| `open-webui-genai` | `GenerativeApisModelAccess` | Open WebUI uses it to call the models |

Create an API key for each. The secret keys belong in your local configuration and in GitHub secrets, never in chats or in the repo.

### 2. Run Terraform locally (Terraform ≥ 1.6)

```bash
export SCW_ACCESS_KEY=...  SCW_SECRET_KEY=...  SCW_DEFAULT_PROJECT_ID=...  SCW_DEFAULT_ORGANIZATION_ID=...
export AWS_ACCESS_KEY_ID=$SCW_ACCESS_KEY AWS_SECRET_ACCESS_KEY=$SCW_SECRET_KEY

# Create the state bucket (one-off)
terraform -chdir=terraform/bootstrap init && terraform -chdir=terraform/bootstrap apply

# Infrastructure
cp terraform/terraform.tfvars.example terraform/terraform.tfvars   # add your SSH public key
terraform -chdir=terraform init
terraform -chdir=terraform apply
```

The outputs are `public_ip`, `data_volume_id`, `server_id` and `ssh`.

### 3. DNS

At the DNS provider for `ncg-it.com`, create the record **A `chat` → `<public_ip>`** (TTL 300).
If the zone is hosted at Scaleway, Terraform can do this: set `dns_zone = "ncg-it.com"`.

### 4. Deploy the app

```bash
cp deploy/.env.example deploy/.env      # WEBUI_SECRET_KEY (openssl rand -hex 32), SCW_GENAI_API_KEY, SEARXNG_SECRET, OPEN_TERMINAL_API_KEY, ACME_EMAIL
bash scripts/deploy.sh <public_ip>
```

Then open https://chat.ncg-it.com and create the first account. It automatically becomes admin.
Afterwards set `ENABLE_SIGNUP=false` and deploy again, or disable sign-up in the admin panel under *Settings → General*.

> Note: many Open WebUI settings are "PersistentConfig". The environment variables only apply on first start; after that the admin panel wins.

### 5. GitHub Actions (optional, for automatic deploys)

**Secrets:** `SCW_ACCESS_KEY`, `SCW_SECRET_KEY`, `SCW_DEFAULT_PROJECT_ID`, `SCW_DEFAULT_ORGANIZATION_ID`,
`SSH_PUBLIC_KEY`, `SSH_PRIVATE_KEY` (dedicated deploy key), optional `SSH_KNOWN_HOSTS`, `WEBUI_SECRET_KEY`, `SCW_GENAI_API_KEY`, `SEARXNG_SECRET`, `OPEN_TERMINAL_API_KEY`

**Variables:** `SERVER_HOST` (IP or `chat.ncg-it.com`), `DOMAIN`, `ACME_EMAIL`, `DATA_VOLUME_ID`, `SERVER_ID`, `COST_LIMIT_EUR`, optional `DEFAULT_MODELS`, `WEBUI_NAME` (default `NCG IT Consulting Chat`)

| Workflow | Trigger | What happens |
|---|---|---|
| `terraform.yml` | PR / push touching `terraform/**` | PR: `plan`, main: `apply` |
| `deploy.yml` | push touching `deploy/**`, manual | Update the Compose stack, reload Caddy, health check |
| `bootstrap.yml` | manual, one-off | Create the state bucket |
| `backup.yml` | daily 02:30 UTC | Snapshot of the data volume, the latest 7 are kept |
| `cost-guard.yml` | every 6 h, manual | Cost guard: at `COST_LIMIT_EUR` (excl. VAT) the instance is powered off; run with `action=start` to power it back on |

## Operations

- **Updates:** Dependabot opens PRs for new Open WebUI, SearXNG, Open Terminal and Caddy versions. After merging, the workflow deploys automatically.
- **Logs:** `ssh deploy@chat.ncg-it.com 'cd /opt/open-webui && docker compose logs -f open-webui'`
- **Restore:** turn a snapshot into a volume in the console, stop the instance, swap the volumes (or import into Terraform) and start the instance.
- **Costs:** instance (PLAY2-MICRO), flexible IP, 2 × 20 GB SBS and snapshots come to roughly €15–25/month, plus the token costs of the Generative APIs.

## Web search (SearXNG)

Open WebUI searches through a private **SearXNG** instance in the same Compose stack (`deploy/searxng/settings.yml`).
It is only reachable internally, needs no API key and adds no extra cost.
SearXNG queries several search engines anonymously, without a user account and without tracking cookies.

- In the chat: enable **Web Search** below the input field (globe icon). Can be toggled per chat.
- Settings: *Admin Panel → Settings → Web Search* (engine `searxng`, URL `http://searxng:8080/search?q=<query>`).
- Secret: `SEARXNG_SECRET` (GitHub secret, `openssl rand -hex 32`).

> The environment variables for web search and the default model only apply to a **fresh install**.
> On an existing installation they are set once in the admin panel (or in the `config` table).

## Terminal (Open Terminal)

[Open Terminal](https://github.com/open-webui/open-terminal) runs as its own container in the stack and gives the chat
a sandboxed Linux shell, a file browser and a terminal panel. The model can also use it as a tool to run commands and edit files.

- Image: `ghcr.io/open-webui/open-terminal:<version>-slim` (Python, git, curl, jq; no sudo, no Docker socket).
  Switch to the full image (`<version>`) if you need Node.js, build tools or a browser.
- Not publicly reachable: only Open WebUI talks to it on the internal Docker network. Outbound internet access is allowed.
- Home directory: `/mnt/data/open-terminal` on the data volume (included in snapshots). Limits: 2 GB RAM, 512 processes.
- Secret: `OPEN_TERMINAL_API_KEY` (GitHub secret, `openssl rand -hex 32`). It grants full command and file access inside the container.
- Connect once in *Admin Panel → Settings → Integrations → Open Terminal*: URL `http://open-terminal:8000` plus the API key, then enable it.
  In the chat, select the terminal to get the terminal panel and file browser.
