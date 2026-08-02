terraform {
  required_version = ">= 1.5"
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# 1. Write the production .env to the VPS
#    (Uses a remote-exec so credentials never touch git or GitHub Secrets)
# ─────────────────────────────────────────────────────────────────────────────
resource "null_resource" "write_env" {
  connection {
    type     = "ssh"
    host     = var.vps_host
    user     = var.vps_user
    password = var.vps_password
    timeout  = "5m"
  }

  # Create app directory first
  provisioner "remote-exec" {
    inline = [
      "mkdir -p ${var.app_dir}/backend"
    ]
  }

  # Write .env via heredoc — avoids exposing secrets in shell history
  provisioner "remote-exec" {
    inline = [
      <<-EOF
        cat > ${var.app_dir}/backend/.env <<'ENVEOF'
PORT=5000
NODE_ENV=production
DATABASE_URL=${var.database_url}
DB_HOST=${var.db_host}
DB_PORT=5432
DB_NAME=${var.db_name}
DB_USER=${var.db_user}
DB_PASSWORD=${var.db_password}
DB_SSL=true
JWT_SECRET=${var.jwt_secret}
JWT_REFRESH_SECRET=${var.jwt_refresh_secret}
JWT_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=7d
CORS_ORIGIN=${var.cors_origin}
ENVEOF
      EOF
    ]
  }

  triggers = {
    # Re-run if any secret value changes
    db_url     = var.database_url
    jwt        = var.jwt_secret
    cors       = var.cors_origin
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# 2. One-time VPS bootstrap — installs Docker, Nginx, clones repo, starts app
# ─────────────────────────────────────────────────────────────────────────────
resource "null_resource" "bootstrap_vps" {
  depends_on = [null_resource.write_env]

  connection {
    type     = "ssh"
    host     = var.vps_host
    user     = var.vps_user
    password = var.vps_password
    timeout  = "15m"
  }

  provisioner "remote-exec" {
    inline = [
      # ── System update ─────────────────────────────────────────────────────
      "export DEBIAN_FRONTEND=noninteractive",
      "apt-get update -qq",

      # ── Install Docker (idempotent) ───────────────────────────────────────
      "if ! command -v docker &>/dev/null; then",
      "  curl -fsSL https://get.docker.com | sh",
      "  systemctl enable docker",
      "  systemctl start docker",
      "fi",

      # ── Install Docker Compose plugin ────────────────────────────────────
      "if ! docker compose version &>/dev/null 2>&1; then",
      "  apt-get install -y -qq docker-compose-plugin",
      "fi",

      # ── Install Nginx ─────────────────────────────────────────────────────
      "if ! command -v nginx &>/dev/null; then",
      "  apt-get install -y -qq nginx",
      "  systemctl enable nginx",
      "fi",

      # ── Install Git ───────────────────────────────────────────────────────
      "apt-get install -y -qq git curl",

      # ── Clone or update repo ──────────────────────────────────────────────
      "if [ -d ${var.app_dir}/.git ]; then",
      "  cd ${var.app_dir} && git fetch origin main && git reset --hard origin/main",
      "else",
      "  git clone ${var.github_repo} ${var.app_dir}",
      "fi",

      # ── Configure Nginx location blocks ───────────────────────────────────
      "mkdir -p /etc/nginx/snippets",
      "cat > /etc/nginx/snippets/video-platform.conf <<'NGINXEOF'",
      "# ElevateIQ Video Platform Routes",
      "location /video-platform-api/ {",
      "    proxy_pass http://127.0.0.1:5000/;",
      "    proxy_http_version 1.1;",
      "    proxy_set_header Upgrade $http_upgrade;",
      "    proxy_set_header Connection upgrade;",
      "    proxy_set_header Host $host;",
      "    proxy_set_header X-Real-IP $remote_addr;",
      "    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;",
      "    proxy_set_header X-Forwarded-Proto $scheme;",
      "    proxy_read_timeout 86400s;",
      "    proxy_send_timeout 86400s;",
      "    client_max_body_size 500M;",
      "}",
      "location /video-platform/ {",
      "    proxy_pass http://127.0.0.1:8081/;",
      "    proxy_http_version 1.1;",
      "    proxy_set_header Host $host;",
      "    proxy_set_header X-Real-IP $remote_addr;",
      "    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;",
      "    proxy_set_header X-Forwarded-Proto $scheme;",
      "}",
      "NGINXEOF",

      # ── Inject into the existing Nginx HTTPS server block ─────────────────
      "CONF=$(grep -rl 'server_name' /etc/nginx/sites-enabled/ 2>/dev/null | head -1)",
      "if [ -n \"$CONF\" ] && ! grep -q 'video-platform' \"$CONF\" 2>/dev/null; then",
      "  sed -i '/server_name/a\\    include /etc/nginx/snippets/video-platform.conf;' \"$CONF\"",
      "  echo 'Nginx routes injected into: '\"$CONF\"",
      "fi",

      # ── Also add a simple HTTP server block if no config exists yet ───────
      "if [ -z \"$(grep -rl 'server_name' /etc/nginx/sites-enabled/ 2>/dev/null)\" ]; then",
      "  cat > /etc/nginx/sites-available/elevateiq <<'SITEEOF'",
      "server {",
      "    listen 80;",
      "    server_name elevateiq-softtech.com 195.35.21.139;",
      "    include /etc/nginx/snippets/video-platform.conf;",
      "    location / { return 301 /video-platform/; }",
      "}",
      "SITEEOF",
      "  ln -sf /etc/nginx/sites-available/elevateiq /etc/nginx/sites-enabled/elevateiq",
      "fi",

      # ── Test and reload Nginx ─────────────────────────────────────────────
      "nginx -t && systemctl reload nginx",

      # ── Start Docker containers ────────────────────────────────────────────
      "cd ${var.app_dir}",
      "docker compose pull --quiet || true",
      "docker compose up --build -d --remove-orphans",

      # ── Wait and health-check ─────────────────────────────────────────────
      "sleep 25",
      "HEALTH=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:5000/health || echo '000')",
      "echo \"=== Health check: HTTP $HEALTH ===\"",
      "docker compose ps",
    ]
  }

  triggers = {
    # Re-provision if repo URL or app dir changes
    repo    = var.github_repo
    app_dir = var.app_dir
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# 3. Future re-deployments (triggered manually or by changing 'deploy_version')
#    This resource just does git pull + docker compose up
# ─────────────────────────────────────────────────────────────────────────────
variable "deploy_version" {
  description = "Bump this value to force a re-deploy via terraform apply (e.g. git commit SHA)"
  type        = string
  default     = "v1"
}

resource "null_resource" "redeploy" {
  depends_on = [null_resource.bootstrap_vps]

  connection {
    type     = "ssh"
    host     = var.vps_host
    user     = var.vps_user
    password = var.vps_password
    timeout  = "10m"
  }

  provisioner "remote-exec" {
    inline = [
      "cd ${var.app_dir}",
      "git fetch origin main",
      "git reset --hard origin/main",
      "docker compose up --build -d --remove-orphans",
      "sleep 15",
      "curl -sf http://localhost:5000/health && echo '✅ Backend healthy' || echo '⚠️  Health check failed'",
      "docker compose ps",
    ]
  }

  triggers = {
    deploy_version = var.deploy_version
  }
}
