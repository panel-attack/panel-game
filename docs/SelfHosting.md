# Self-Hosting a Panel Attack Server

Guide for running your own server on a Hetzner VPS, completely separate from panelattack.com and betaserver.panelattack.com.

**Why separate?** Player accounts, rankings, replays, and the database all live on the VPS — nothing is shared with production. The client stores credentials per server IP, so players get a fresh account on your server automatically.

## What's Already Blocked in This Branch

Two production connections have been cut in `bramp/multi-player`:

| File | Change |
|---|---|
| `client/src/scenes/MainMenu.lua:85` | "2 vs Online" now defaults to `localhost` instead of `panelattack.com` |
| `main.lua:298` | Crash reporter disabled — errors no longer sent to production |

Once you have your Hetzner IP, update `MainMenu.lua:85` from `"localhost"` to your server IP (and keep it out of git with `git update-index --assume-unchanged`).

---

## 1. Provision a Hetzner VPS (~5 min)

1. Create an account at [hetzner.com/cloud](https://hetzner.com/cloud)
2. New Project → **Add Server**:
   - **Location:** Ashburn, VA (US East) or Hillsboro, OR (US West)
   - **Image:** Ubuntu 24.04
   - **Type:** CX22 (2 vCPU, 4 GB RAM, ~$4.20/mo)
   - **SSH Key:** paste your public key (`cat ~/.ssh/id_ed25519.pub`)
   - **Firewall:** create one, add rule — TCP inbound port `49569`
3. Click Create, note the IP address

---

## 2. Run the Setup Script

Copy the script below, save it as `setup_server.sh`, upload and run it on the VPS:

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

> **Do not commit this change.** Your server IP doesn't belong in the public repo.
> Keep it as a local-only edit with:
> ```sh
> git update-index --assume-unchanged client/src/scenes/MainMenu.lua
> ```
> To start tracking it again: `git update-index --no-assume-unchanged client/src/scenes/MainMenu.lua`

---

## 4. Verify It's Working

```sh
ssh root@YOUR_SERVER_IP
systemctl status panel-attack      # should show: active (running)
journalctl -u panel-attack -f      # should show server tests passing, then quiet
```

Then in the game client: Main Menu → **My Server** → should reach the lobby.

---

## Ongoing Maintenance

**Deploy a code update:**
```sh
ssh root@YOUR_SERVER_IP
cd /opt/panel-attack && git pull
systemctl restart panel-attack
```

**View live logs:**
```sh
journalctl -u panel-attack -f
```

**Change server config** (port, engine version, etc.): edit `server/server_globals.lua` on the VPS, then `systemctl restart panel-attack`.

---

## Notes

- Server data (SQLite DB, players, replays) lives in `/opt/panel-attack/` — delete this directory to reset everything
- Client stores per-server credentials in `servers/{SERVER_IP}/user_id.txt` locally — each server gets independent accounts
- The `lsqlite3`, `socket`, and `lfs` `.so` files in the repo are pre-compiled for dev machines; the luarocks install above provides fresh builds for the VPS
- If you want ranked play, generate a new `csprng_seed.txt` on the server (the default one is shared via the public repo)

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
