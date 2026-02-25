#!/bin/bash
set -euo pipefail

# Log everything to a file for debugging
exec > >(tee /var/log/user_data.log) 2>&1
echo "=== user_data.sh started at $(date) ==="

DOMAIN="${domain_name}"
EMAIL="${certbot_email}"

# ──────────────────────────────────────────────────────────────
# 1. System update & upgrade
# ──────────────────────────────────────────────────────────────
export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get upgrade -y
apt-get dist-upgrade -y
apt-get autoremove -y

# ──────────────────────────────────────────────────────────────
# 2. Install Nginx
# ──────────────────────────────────────────────────────────────
apt-get install -y nginx
systemctl enable nginx
systemctl start nginx

# Create a basic landing page
cat > /var/www/html/index.html <<'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>myluxsrv.myddns.me</title>
  <style>
    body { font-family: system-ui, sans-serif; display: flex; justify-content: center;
           align-items: center; min-height: 100vh; margin: 0; background: #0f172a; color: #e2e8f0; }
    .card { text-align: center; padding: 3rem; border-radius: 1rem;
            background: #1e293b; box-shadow: 0 4px 24px rgba(0,0,0,.4); }
    h1 { margin: 0 0 .5rem; font-size: 2rem; color: #38bdf8; }
    p  { margin: 0; color: #94a3b8; }
  </style>
</head>
<body>
  <div class="card">
    <h1>&#x1F680; myluxsrv.myddns.me</h1>
    <p>Server is up and running.</p>
  </div>
</body>
</html>
HTML

# ──────────────────────────────────────────────────────────────
# 3. Configure Nginx server block for the domain
# ──────────────────────────────────────────────────────────────
cat > /etc/nginx/sites-available/"$DOMAIN" <<NGINX
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;

    root /var/www/html;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
NGINX

ln -sf /etc/nginx/sites-available/"$DOMAIN" /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

nginx -t && systemctl reload nginx

# ──────────────────────────────────────────────────────────────
# 4. Install Certbot and request certificate
# ──────────────────────────────────────────────────────────────
apt-get install -y certbot python3-certbot-nginx

# The certificate request will only succeed AFTER you point
# 21x.ddns.net DNS to the Elastic IP. A systemd timer retries
# automatically so the cert is obtained once DNS propagates.

cat > /usr/local/bin/obtain-cert.sh <<'CERTSCRIPT'
#!/bin/bash
set -euo pipefail

DOMAIN="__DOMAIN__"
EMAIL="__EMAIL__"
LOGFILE="/var/log/certbot-obtain.log"

echo "$(date) – Attempting to obtain certificate for $DOMAIN" >> "$LOGFILE"

if certbot certificates 2>/dev/null | grep -q "$DOMAIN"; then
    echo "$(date) – Certificate already exists. Skipping." >> "$LOGFILE"
    exit 0
fi

if certbot --nginx \
    -d "$DOMAIN" \
    --non-interactive \
    --agree-tos \
    --email "$EMAIL" \
    --redirect \
    >> "$LOGFILE" 2>&1; then
    echo "$(date) – Certificate obtained successfully!" >> "$LOGFILE"
    # Disable the retry timer once successful
    systemctl disable --now certbot-obtain.timer 2>/dev/null || true
else
    echo "$(date) – Certificate request failed. Will retry later." >> "$LOGFILE"
    exit 1
fi
CERTSCRIPT

# Replace placeholders
sed -i "s|__DOMAIN__|$DOMAIN|g" /usr/local/bin/obtain-cert.sh
sed -i "s|__EMAIL__|$EMAIL|g"   /usr/local/bin/obtain-cert.sh
chmod +x /usr/local/bin/obtain-cert.sh

# Systemd service for one-shot cert obtainment
cat > /etc/systemd/system/certbot-obtain.service <<'UNIT'
[Unit]
Description=Obtain Let's Encrypt certificate
After=network-online.target nginx.service
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/obtain-cert.sh
UNIT

# Systemd timer – retries every 5 minutes until cert is obtained
cat > /etc/systemd/system/certbot-obtain.timer <<'TIMER'
[Unit]
Description=Retry certificate obtainment every 5 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
Persistent=true

[Install]
WantedBy=timers.target
TIMER

systemctl daemon-reload
systemctl enable --now certbot-obtain.timer

# Also try immediately (will succeed if DNS is already pointing here)
/usr/local/bin/obtain-cert.sh || true

echo "=== user_data.sh finished at $(date) ==="
