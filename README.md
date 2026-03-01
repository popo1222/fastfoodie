# 🍔 FastFoodie

A complete food ordering system for restaurants and cafes. QR code-based ordering with POS, admin dashboard, kitchen display, and customer web app.

## Features

- **POS System** — Touch-friendly table-centric operations hub for dine-in and takeaway
- **Customer Web App** — Mobile-first ordering via QR code scan
- **Admin Dashboard** — Menu management, order tracking, staff management, reports
- **Kitchen Display** — Real-time order board with fullscreen focus mode
- **QR Code Ordering** — Static (per table) or Dynamic (staff-generated) modes
- **Payment Flows** — Pay First, Pay Later, or Pay at Counter
- **Reports & Analytics** — Daily closing, sales by item/category/hour/table, charts
- **Tax / SST Support** — Configurable tax rate, exclusive/inclusive modes
- **Session Management** — Anonymous customer sessions, no registration needed
- **Store Branding** — Configurable name, logo, operating hours
- **Remote Updates** — Update from admin panel, auto-rollback on failure

## What You Need

### Required

| Item | Cost | Recommendation |
|---|---|---|
| **VPS Server** | ~RM20-60/month | See server sizing guide below |
| **2 Domains** | ~RM30-50/year | One for admin (e.g. `admin.kedai.com`), one for customer app (e.g. `order.kedai.com`). Can be subdomains of the same domain. |

### Optional

| Item | Cost | Purpose |
|---|---|---|
| **S3-compatible storage** | ~RM5-15/month | For menu item images. Without S3, menu items show without photos — everything else works fine. |

### What Works WITHOUT S3
- ✅ POS ordering (no images needed — staff knows the menu)
- ✅ Store logo (stored locally on server)
- ✅ Customer QR ordering (items show without photos)
- ✅ Kitchen display, reports, payments — everything

### What Needs S3
- 📸 Menu item photos in admin dashboard and customer app

> **Recommendation:** Start without S3. Add it later when the client wants menu photos.

### Server Sizing Guide

| Client Size | Tables | Spec | Monthly Cost |
|---|---|---|---|
| Small stall | 1-5 | 1 vCPU, 1GB RAM | ~RM20/month |
| Café | 5-15 | 2 vCPU, 2GB RAM | ~RM40/month |
| Restaurant | 15+ | 2 vCPU, 4GB RAM | ~RM60/month |

> Admin and Webapp are just Nginx serving static files (~5MB each). The API runs as a single Node.js process (~80-150MB). SQLite is embedded. The whole stack uses ~300-400MB under normal load.

---

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
- Ubuntu 22.04+ (or any Linux with Docker support)
- Docker & Docker Compose v2
- Two domains pointing to your server IP (for auto SSL)
- Minimum: 1 vCPU, 1GB RAM, 10GB disk (see sizing guide above)

### Steps

```bash
# 1. Create project directory
mkdir -p /opt/fastfoodie && cd /opt/fastfoodie

# 2. Download files
curl -fsSL https://raw.githubusercontent.com/popo1222/fastfoodie/main/docker-compose.yml -o docker-compose.yml
curl -fsSL https://raw.githubusercontent.com/popo1222/fastfoodie/main/.env.example -o .env
curl -fsSL https://raw.githubusercontent.com/popo1222/fastfoodie/main/update.sh -o update.sh
curl -fsSL https://raw.githubusercontent.com/popo1222/fastfoodie/main/watcher.sh -o watcher.sh
chmod +x update.sh watcher.sh
mkdir -p triggers

# 3. Configure environment
nano .env
# - Set JWT_SECRET (generate: openssl rand -base64 48)
# - Set CORS_ORIGINS to your actual domains

# 4. Start services
docker compose pull
docker compose up -d

# 5. Seed database (first time only)
docker compose exec api npx tsx prisma/seed.ts

# 6. Set up reverse proxy (Caddy example)
# See "Reverse Proxy" section below
```

## Architecture

```
Internet
   │
   ├── admin.example.com ──→ Caddy ──→ Admin Panel (:8080)
   │                                       └── /api/ ──→ API (:3000)
   │
   └── order.example.com ──→ Caddy ──→ Customer Webapp (:8081)
                                           └── /api/ ──→ API (:3000)
                                                            │
                                                         SQLite DB
                                                         (WAL mode)
```

| Service | Image | Internal Port | Exposed Port |
|---|---|---|---|
| API | `ghcr.io/popo1222/fastfoodie-api` | 3000 | — (internal only) |
| Admin | `ghcr.io/popo1222/fastfoodie-admin` | 80 | 8080 |
| Webapp | `ghcr.io/popo1222/fastfoodie-webapp` | 80 | 8081 |

## Reverse Proxy (SSL)

### Option A: Caddy (Recommended — auto SSL)

```
# /etc/caddy/Caddyfile

admin.myrestaurant.com {
    reverse_proxy localhost:8080
}

order.myrestaurant.com {
    reverse_proxy localhost:8081
}
```

```bash
sudo systemctl restart caddy
```

Caddy automatically provisions Let's Encrypt SSL certificates. Make sure DNS A records for both domains point to your server IP **before** starting Caddy.

### Option B: Nginx + Certbot

```nginx
server {
    listen 80;
    server_name admin.myrestaurant.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name admin.myrestaurant.com;

    ssl_certificate /etc/letsencrypt/live/admin.myrestaurant.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/admin.myrestaurant.com/privkey.pem;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# Repeat for order.myrestaurant.com → localhost:8081
```

## Default Login

| Email | Password | Role |
|---|---|---|
| admin@demo.com | admin123 | Admin |
| kitchen@demo.com | kitchen123 | Kitchen Staff |

⚠️ **Change passwords immediately after first login!**

## Configuration (After Login)

Go to **Settings** in the admin panel and configure:

1. **Store Info** — Store name, logo, currency
2. **Tax / SST** — Enable tax, set rate (e.g. 6%), choose exclusive/inclusive mode
3. **Ordering** — Payment mode, QR mode (Static/Dynamic), table numbers
4. **Webapp URL** — Set to your customer domain (e.g. `https://order.myrestaurant.com`)
5. **Operating Hours** — Set for each day of the week
6. **S3 Storage** (optional) — For menu item images; works without S3 too

Then:
- Go to **Menu** to add categories and items
- Go to **POS** to start taking orders
- Print QR codes from **Sessions** page (Dynamic QR mode) or **Menu** page (menu-only QR)

## Updates

### From Admin Panel
Go to **Settings → System** → Click "Check for Updates" → "Update Now"

### Manual
```bash
cd /opt/fastfoodie
docker compose pull
docker compose up -d
```

### Auto-Update Watcher
The setup script installs a cron-based watcher that enables one-click updates from the admin panel. The watcher checks for trigger files every 30 seconds.

## Backup & Restore

### Backup
```bash
cd /opt/fastfoodie

# Backup database
docker compose exec api cp prisma/dev.db /tmp/backup.db
docker compose cp api:/tmp/backup.db ./backup-$(date +%Y%m%d).db

# Backup uploads (logos, images)
docker compose cp api:/app/uploads ./uploads-backup-$(date +%Y%m%d)
```

### Restore
```bash
cd /opt/fastfoodie

# Restore database
docker compose cp ./backup-20260301.db api:/tmp/restore.db
docker compose exec api cp /tmp/restore.db prisma/dev.db
docker compose restart api

# Restore uploads
docker compose cp ./uploads-backup-20260301/. api:/app/uploads/
```

### Automated Backup (Recommended)
Add to crontab for daily backups:
```bash
# Daily backup at 3am, keep last 30 days
0 3 * * * cd /opt/fastfoodie && docker compose exec -T api cp prisma/dev.db /tmp/backup.db && docker compose cp api:/tmp/backup.db /opt/fastfoodie/backups/backup-$(date +\%Y\%m\%d).db && find /opt/fastfoodie/backups -name "*.db" -mtime +30 -delete
```

```bash
mkdir -p /opt/fastfoodie/backups
crontab -e  # paste the line above
```

## Troubleshooting

### Services won't start
```bash
# Check status
docker compose ps

# Check logs
docker compose logs api
docker compose logs admin
docker compose logs webapp
```

### API unhealthy
```bash
# Check if API responds
curl http://localhost:3000/health

# Check API logs
docker compose logs api --tail 50

# Common causes:
# - DATABASE_URL wrong → check .env
# - Port 3000 already in use → check with: lsof -i :3000
# - Missing seed → run: docker compose exec api npx tsx prisma/seed.ts
```

### SSL certificates not working
```bash
# Check DNS points to your server
dig admin.myrestaurant.com

# Check Caddy logs
journalctl -u caddy --no-pager -n 50

# Common causes:
# - DNS not pointing to server yet
# - Ports 80/443 blocked by firewall → ufw allow 80,443
```

### Database locked errors
SQLite uses WAL mode for concurrent reads. If you see "database locked":
```bash
# Restart API to clear locks
docker compose restart api
```

### Reset to factory
```bash
cd /opt/fastfoodie
docker compose down
docker volume rm fastfoodie_api-data fastfoodie_api-uploads
docker compose up -d
sleep 15
docker compose exec api npx tsx prisma/seed.ts
```

## Data Persistence

| Data | Location | Backed by |
|---|---|---|
| Database (SQLite) | `/app/prisma/dev.db` | Docker volume: `api-data` |
| Uploads (logo, images) | `/app/uploads/` | Docker volume: `api-uploads` |
| Environment config | `/opt/fastfoodie/.env` | Host filesystem |
| Docker Compose | `/opt/fastfoodie/docker-compose.yml` | Host filesystem |

⚠️ **Docker volumes survive `docker compose down` but NOT `docker volume rm`.** Always backup before destructive operations.

## Firewall

If using `ufw`:
```bash
sudo ufw allow 80    # HTTP (Caddy needs this for SSL challenge)
sudo ufw allow 443   # HTTPS
sudo ufw allow 22    # SSH (don't lock yourself out!)
```

Do **not** expose ports 8080, 8081, or 3000 directly — let Caddy handle external traffic.

## License

FastFoodie is **free to use** for any business. The software is proprietary — source code is not included or distributed. All rights reserved by ATJY Studio.

- ✅ Free to use for commercial purposes
- ✅ No monthly software fees
- ❌ No redistribution or resale
- ❌ No reverse engineering or modification

## Support

- **GitHub Issues**: https://github.com/popo1222/fastfoodie/issues
- **WhatsApp**: [Contact ATJY Studio]

---

Powered by **ATJY Studio**
