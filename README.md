# ask-devenv

Local development environment for the Ask AI assistant ecosystem.

`setup.sh` clones the required repos, generates SSL certificates, and patches `/etc/hosts`. Then `docker compose up` starts everything.

| Service | URL |
|---|---|
| ask-frontend | https://ask.local |
| ask-backend | https://api.ask.local |
| Qdrant dashboard | http://localhost:6333/dashboard |

## Prerequisites

- Docker + Docker Compose v2
- [step-cli](https://smallstep.com/docs/step-cli/installation) (`brew install step` on macOS)
- SSH access to Weezevent GitHub org

## Getting started

```bash
# 1. Create your .env
cp .env.example .env
# Edit .env — fill in ACCOUNTS_CLIENT_SECRET, GIGZ_* creds, etc.

# 2. Run setup (clones repos, generates certs, patches /etc/hosts)
./commands/setup.sh

# 3. Start the stack
docker compose up -d
```

## Repo layout after setup

```
ask-devenv/
├── commands/
│   ├── setup.sh          ← one-shot bootstrap
│   └── lib/utils.sh
├── nginx/
│   ├── nginx.conf
│   └── ssl/
│       ├── generate-certs.sh
│       └── certs/        ← generated, gitignored
├── projects/             ← cloned by setup.sh, gitignored
│   ├── backend/ask-backend/
│   └── frontend/ask-frontend/
├── docker-compose.yml
├── docker-compose.backend.yml
├── docker-compose.frontend.yml
└── .env                  ← created from .env.example, gitignored
```

## Architecture

```
Browser
  │
  │  https://ask.local          https://api.ask.local
  ▼                             ▼
┌─────────────────────────────────────────────────────┐
│  nginx (TLS termination — step-cli certs)           │
│    ask.local       → frontend:3000  (Vite HMR)      │
│    api.ask.local   → ask:8000       (uvicorn reload) │
└─────────────────────────────────────────────────────┘
         │                    │
         ▼                    ▼
    ask-frontend         ask-backend
                              │
                    ┌─────────┼──────────────┐
                    ▼         ▼              ▼
                 qdrant  AWS Bedrock     Gigz APIs
               (local)  (remote)        (staging)
```

Keycloak (`accounts.weezevent.com/realms/accounts-dev`) is remote — no local instance needed.

Hot-reload is enabled on both services:
- **ask-backend**: uvicorn `--reload`, source bind-mounted from `projects/backend/ask-backend/ask`
- **ask-frontend**: Vite dev server with HMR, source bind-mounted from `projects/frontend/ask-frontend`

## Common commands

| Task | Command |
|---|---|
| Start stack | `docker compose up -d` |
| Stop stack | `docker compose down` |
| Follow backend logs | `docker compose logs -f ask` |
| Rebuild backend | `docker compose up -d --build ask` |
| Run backend tests | `docker compose run --rm ask-pytest` |
| Python shell (backend) | `docker compose run --rm ask-debug` |
| Wipe Qdrant data | `docker compose down -v` |
| Sync repos to latest | `git -C projects/backend/ask-backend pull && git -C projects/frontend/ask-frontend pull` |

## Environment variables

See [`.env.example`](.env.example) for the full list. Minimum required:

| Variable | Description |
|---|---|
| `ACCOUNTS_CLIENT_SECRET` | Keycloak confidential client secret for `ask_backend_local` |
| `GIGZ_LOGS_TOKEN` | Bearer token for gigz-logs staging API |
| `GIGZ_FOREST_USER` / `GIGZ_FOREST_PASSWORD` | Basic auth for gigz-forest staging API |

AWS credentials are optional if `~/.aws/credentials` is configured with a valid profile.

## Troubleshooting

**Certificate not trusted in browser**  
Re-run `./nginx/ssl/generate-certs.sh` and answer Y to install the CA, then restart your browser.  
Firefox users: import `nginx/ssl/certs/ca.crt` manually at `about:preferences#privacy` → Certificates → Authorities.

**`ask.local` / `api.ask.local` not resolving**  
Check `/etc/hosts` has both entries. Re-run `./commands/setup.sh` if needed.

**Port 443/80 already in use**  
Stop any local nginx/apache running on those ports.

**ask-backend can't reach Qdrant**  
`QDRANT_HOST=qdrant` is set by the compose file — don't override it in `.env`.
