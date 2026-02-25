# 🍔 FastFoodie

A complete food ordering system for restaurants and cafes. QR code-based ordering with admin dashboard and customer web app.

## Features

- **Customer Web App** — Mobile-first ordering via QR code scan
- **Admin Dashboard** — Menu management, order tracking, kitchen board, staff management
- **Kitchen Display** — Real-time order board with fullscreen focus mode
- **QR Code Ordering** — Static (per table) or Dynamic (staff-generated) modes
- **Payment Flows** — Pay First, Pay Later, or Pay at Counter
- **Session Management** — Anonymous customer sessions, no registration needed
- **Store Branding** — Configurable name, logo, operating hours

## Quick Start (Clean Ubuntu Server)

```bash
curl -fsSL https://raw.githubusercontent.com/popo1222/fastfoodie/main/setup.sh | sudo bash
```

The script will:
1. Install Docker & Caddy
2. Ask for your admin and webapp domain names
3. Pull images, start containers, seed database
4. Configure SSL certificates automatically

**That's it.** Open your admin domain and login with `admin@demo.com` / `admin123`.

## Manual Setup

### Prerequisites
- Docker & Docker Compose
- Two domains pointing to your server (for auto SSL)

### Steps

```bash
# 1. Create project directory
mkdir -p /opt/fastfoodie && cd /opt/fastfoodie

# 2. Download files
curl -fsSL https://raw.githubusercontent.com/popo1222/fastfoodie/main/docker-compose.yml -o docker-compose.yml
curl -fsSL https://raw.githubusercontent.com/popo1222/fastfoodie/main/.env.example -o .env

# 3. Configure environment
nano .env
# Set JWT_SECRET (generate: openssl rand -base64 48)
# Set CORS_ORIGINS to your domains

# 4. Start
docker compose pull
docker compose up -d

# 5. Seed database (first time)
docker compose exec api npx tsx prisma/seed.ts
```

## Architecture

```
Internet
   │
   ├── admin.example.com ──→ Admin Panel (Nginx + React)
   │                              └── /api/ ──→ API
   │
   └── order.example.com ──→ Customer Webapp (Nginx + React)
                                  └── /api/ ──→ API
                                                 │
                                              SQLite DB
```

| Service | Image | Port |
|---|---|---|
| API | `ghcr.io/popo1222/fastfoodie-api` | 3000 (internal) |
| Admin | `ghcr.io/popo1222/fastfoodie-admin` | 8080 |
| Webapp | `ghcr.io/popo1222/fastfoodie-webapp` | 8081 |

## Default Login

| Email | Password | Role |
|---|---|---|
| admin@demo.com | admin123 | Admin |
| kitchen@demo.com | kitchen123 | Kitchen Staff |

⚠️ **Change passwords after first login!**

## Updates

```bash
cd /opt/fastfoodie
docker compose pull
docker compose up -d
```

## Backup & Restore

```bash
# Backup
docker compose exec api cp prisma/dev.db /tmp/backup.db
docker compose cp api:/tmp/backup.db ./backup-$(date +%Y%m%d).db

# Restore
docker compose cp ./backup.db api:/tmp/restore.db
docker compose exec api cp /tmp/restore.db prisma/dev.db
docker compose restart api
```

## Configuration

After first login, go to **Settings** and configure:

1. **Store name & logo**
2. **Payment mode** — Pay First / Pay Later / Pay at Counter
3. **QR mode** — Static (fixed per table) or Dynamic (staff-generated)
4. **Webapp URL** — Set to your customer-facing domain (e.g. `https://order.myrestaurant.com`)
5. **Table numbers** — Configure your table layout
6. **Operating hours**

Then go to **Sessions** to print QR codes for your tables.

## License

MIT
