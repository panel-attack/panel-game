#!/bin/bash
set -e

REPO_URL="https://github.com/briankeegan/panel-game.git"
BRANCH="bramp/multi-player"
INSTALL_DIR="/opt/panel-attack"
SERVICE_USER="panelattack"

echo "==> Installing system packages"
apt-get update -qq
apt-get install -y luajit lua5.1 luarocks git build-essential libsqlite3-dev

echo "==> Installing Lua libraries"
luarocks install luasocket     --lua-version 5.1
luarocks install luafilesystem --lua-version 5.1
luarocks install sqlite3       --lua-version 5.1
luarocks install lsqlite3      --lua-version 5.1
luarocks install luautf8       --lua-version 5.1

echo "==> Cloning repo (branch: $BRANCH)"
git clone --branch "$BRANCH" "$REPO_URL" "$INSTALL_DIR"

echo "==> Creating service user"
useradd --system --no-create-home --shell /usr/sbin/nologin "$SERVICE_USER" 2>/dev/null || true
chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"

echo "==> Writing start wrapper"
cat > /usr/local/bin/panel-attack-server <<'WRAPPER'
#!/bin/bash
eval "$(luarocks path --lua-version 5.1)"
exec /usr/bin/luajit serverLauncher.lua "$@"
WRAPPER
chmod +x /usr/local/bin/panel-attack-server

echo "==> Writing systemd service"
cat > /etc/systemd/system/panel-attack.service <<EOF
[Unit]
Description=Panel Attack Game Server
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/local/bin/panel-attack-server
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable panel-attack
systemctl start panel-attack

echo ""
echo "==> Done! Server running on port 49569"
echo "    Status:  systemctl status panel-attack"
echo "    Logs:    journalctl -u panel-attack -f"
echo "    Update:  cd $INSTALL_DIR && git pull && systemctl restart panel-attack"
