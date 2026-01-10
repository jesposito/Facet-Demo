# Facet-Demo

Public demo instance of [Facet](https://github.com/jesposito/Facet) - a self-hosted portfolio platform.

**Live Demo:** https://facet-demo.theansible.co

## Login Credentials

```
Email: demo@example.com
Password: demo123
```

## Features

- Full Facet functionality for testing
- Data resets daily at midnight UTC
- No password reset (to prevent lockouts)
- Pre-populated with sample portfolio data

## How It Works

This repo automatically tracks upstream Facet releases and rebuilds with demo-specific customizations:

1. **Upstream Sync**: Watches `jesposito/Facet` for new releases
2. **Auto-Build**: Triggers Docker build with demo patches applied
3. **Daily Reset**: Cron job restores sample data every 24 hours

## Differences from Main Facet

| Feature | Facet | Facet-Demo |
|---------|-------|------------|
| Demo mode toggle | Yes | No (always demo data) |
| Password reset | Yes | Disabled |
| Data persistence | Permanent | Resets daily |
| Login | User-configured | Fixed demo credentials |

## Running Locally

```bash
docker pull ghcr.io/jesposito/facet-demo:latest
docker run -d -p 8080:8080 ghcr.io/jesposito/facet-demo:latest
```

## Unraid Installation

### Option 1: Manual Template Install

1. SSH into your Unraid server or use the terminal
2. Download the template:
   ```bash
   wget -O /boot/config/plugins/dockerMan/templates-user/facet-demo.xml \
     https://raw.githubusercontent.com/jesposito/Facet-Demo/main/unraid/facet-demo-template.xml
   ```
3. Go to Docker tab and click "Add Container"
4. Select "facet-demo" from the Template dropdown
5. Configure and apply

### Option 2: Docker Run

```bash
docker run -d \
  --name facet-demo \
  -p 8081:8080 \
  -v /mnt/user/appdata/facet-demo:/data \
  -v /mnt/user/appdata/facet-demo/uploads:/uploads \
  -e APP_URL=https://facet-demo.yourdomain.com \
  ghcr.io/jesposito/facet-demo:latest
```

### Daily Reset

Data automatically resets at midnight UTC - no configuration needed. The reset is built into the container.
