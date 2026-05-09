# Self-Hosting a Panel Attack Server

Guide for running your own server on a Vultr VPS, completely separate from panelattack.com and betaserver.panelattack.com.

**Why separate?** Player accounts, rankings, replays, and the database all live on the VPS — nothing is shared with production. The client stores credentials per server IP, so players get a fresh account on your server automatically.

## What's Already Blocked in This Branch

Two production connections have been cut in `bramp/multi-player`:

| File | Change |
|---|---|
| `client/src/scenes/MainMenu.lua:85` | "2 vs Online" now defaults to `localhost` instead of `panelattack.com` |
| `main.lua:298` | Crash reporter disabled — errors no longer sent to production |

Once you have your server IP, update `MainMenu.lua:85` from `"localhost"` to your server IP (and keep it out of git with `git update-index --assume-unchanged client/src/scenes/MainMenu.lua`).

---

## 1. Provision a Vultr VPS (~5 min)

1. Sign up at **vultr.com**
2. Deploy → **Cloud Compute**
3. Choose settings:
   - **Location:** New York, Chicago, Atlanta, or Dallas (US East/Central for low latency)
   - **Image:** Ubuntu 24.04 LTS
   - **Plan:** Regular Cloud Compute — **$5/mo** (1 vCPU, 1 GB RAM) or $3.50/mo (512 MB, IPv6 + IPv4)
   - **SSH Keys:** add your public key (`cat ~/.ssh/id_ed25519.pub`)
4. Click Deploy — server is live in ~60 seconds, note the IP

**Firewall:** Go to **Manage → Settings → Firewall** (or Network → Firewall Groups) and allow TCP inbound port `49569`.

---

## 2. Open the Firewall Port

In Vultr dashboard → your instance → **Settings → Firewall** (or go to **Networking → Firewall Groups**):
- Add a rule: Protocol **TCP**, Port **49569**, Source **Any**

Or just do it on the server itself after SSHing in (step 3 handles this via ufw if needed).

## 3. Run the Setup Script

Save the script below as `setup_server.sh`, then upload and run it:

```sh
scp setup_server.sh root@YOUR_SERVER_IP:~/
ssh root@YOUR_SERVER_IP bash setup_server.sh
```

**`setup_server.sh`:**

```bash
#!/bin/bash
set -e

REPO_URL="https://github.com/panel-attack/panel-game.git"
BRANCH="bramp/multi-player"   # change to beta or main as needed
INSTALL_DIR="/opt/panel-attack"
SERVICE_USER="panelattack"

echo "==> Installing system packages"
apt-get update -qq
apt-get install -y luajit lua5.1 luarocks git build-essential libsqlite3-dev

echo "==> Installing Lua libraries (must target 5.1 for LuaJIT compatibility)"
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

echo "==> Writing start wrapper (ensures luarocks paths are available to the service user)"
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
```

---

## 3. Connect the Client to Your Server

Add your server IP to the in-game debug menu in `client/src/scenes/MainMenu.lua` around line 111:

```lua
local debugMenuItems = {
  ui.MenuItem.createButtonMenuItem("Beta Server", nil, false, function() switchToScene(Lobby({serverIp = "betaserver.panelattack.com", serverPort = 59569})) end),
  ui.MenuItem.createButtonMenuItem("My Server", nil, false, function() switchToScene(Lobby({serverIp = "YOUR_SERVER_IP"})) end),
  ui.MenuItem.createButtonMenuItem("Localhost Server", nil, false, function() switchToScene(Lobby({serverIp = "Localhost"})) end)
}
```

Enable the debug menu in-game: **Options → Debug → Show Debug Servers**

> **Do not commit this change.** Keep it local:
> ```sh
> git update-index --assume-unchanged client/src/scenes/MainMenu.lua
> ```

---

## 4. Verify It's Working

```sh
ssh root@YOUR_SERVER_IP
systemctl status panel-attack      # should show: active (running)
journalctl -u panel-attack -f      # should show server tests passing, then quiet
```

Then in the game client: **Options → Debug → Show Debug Servers** → Main Menu → **My Server** → should reach the lobby.

---

## Ongoing Maintenance

```sh
# Deploy a code update
ssh root@YOUR_SERVER_IP
cd /opt/panel-attack && git pull && systemctl restart panel-attack

# View live logs
journalctl -u panel-attack -f

# Change server config (port, engine version, etc.)
# Edit server/server_globals.lua then restart
systemctl restart panel-attack
```

---

## What's Protected by .gitignore

These files are auto-generated at runtime and must never be committed:

| File | Why it's sensitive |
|---|---|
| `csprng_seed.txt` | Security seed for player ID generation — leaking this makes user IDs predictable |
| `PADatabase.sqlite3` | Contains all player records |
| `players.txt` | Player username map |
| `leaderboard.csv` | Rankings and ratings |
| `GameResults.csv` | Full game history |
| `ftp/`, `reports/`, `placement_matches/` | Runtime directories |

Your server IP in `MainMenu.lua` is kept out of git via `git update-index --assume-unchanged` (see Step 3).
