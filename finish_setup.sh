#!/bin/bash
set -e

git clone --branch bramp/multi-player https://github.com/briankeegan/panel-game.git /opt/panel-attack

useradd --system --no-create-home --shell /usr/sbin/nologin panelattack 2>/dev/null || true
chown -R panelattack:panelattack /opt/panel-attack

cat > /usr/local/bin/panel-attack-server << 'WRAPPER'
#!/bin/bash
eval "$(luarocks path --lua-version 5.1)"
exec /usr/bin/luajit serverLauncher.lua "$@"
WRAPPER

chmod +x /usr/local/bin/panel-attack-server

cat > /etc/systemd/system/panel-attack.service << 'EOF'
[Unit]
Description=Panel Attack Game Server
After=network.target

[Service]
Type=simple
User=panelattack
WorkingDirectory=/opt/panel-attack
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
echo "==> Done! Check: systemctl status panel-attack"
