# Panel Attack — Claude Code Guide

## What This Is

Panel Attack is a Tetris-like multiplayer puzzle game. The codebase has two main parts:
- **Client** — LÖVE2D (Lua) game engine, lives in `client/`
- **Server** — Pure LuaJIT TCP server, entry point is `serverLauncher.lua`

Shared game logic lives in `common/`. Tests live alongside their modules in `*/tests/`.

## This Branch: `bramp/multi-player`

Active development branch for team multiplayer. **This branch never connects to production.**
- `client/src/scenes/MainMenu.lua:85` — defaults to `localhost` (not `panelattack.com`)
- `main.lua:298` — crash reporter disabled
- See `docs/MULTIPLAYER_DESIGN.md` for the multiplayer design spec

## Running Locally (macOS)

### Dependencies
Install once:
```sh
brew install luajit lua5.1 luarocks sqlite3
luarocks install --local luasocket --lua-version 5.1
luarocks install --local luafilesystem --lua-version 5.1
luarocks install --local luautf8 --lua-version 5.1
luarocks install --local lsqlite3 --lua-version 5.1
luarocks install --local lsqlite3complete --lua-version 5.1  # macOS fallback for lsqlite3
```

Also needs **love 12** (not love 11) for the client. Add it to PATH in `~/.zshrc`.

### Scripts
```sh
zsh run_server.sh   # start local server (localhost:49569) — also runs ALL server tests on startup
zsh run_client.sh   # start game client
zsh run_tests.sh    # run full test suite including client tests (requires love, not luajit)
```

Run server first, then client. Client connects to localhost automatically on this branch.

### How tests work

**Server tests** (`LoginTests`, `LeaderboardTests`, `RoomTests`, `TeamRoomTests`, `ServerTests`):
- Run via `zsh run_server.sh` — `serverLauncher.lua` runs all server tests automatically on startup before entering the main loop
- Do NOT run these through love — `lfs` and `lsqlite3` are not available in the love environment
- Do NOT run individual test files directly with `luajit server/tests/Foo.lua` — they depend on globals set up by `serverLauncher.lua`

**Client/common tests** (`PuzzleTests`, `NetworkProtocolTests`, etc.):
- Run via `zsh run_tests.sh` — uses love to run `testLauncher.lua`
- These cannot run via luajit — they depend on love APIs

**First time:** Set a player name in-game (Main Menu → Set Name) before connecting.

### Common Issues
- `love: command not found` — love not in PATH, add to `~/.zshrc`
- `slice is not valid mach-o file` — bundled `.so` files are Linux-compiled; install the luarocks equivalents above
- `symbol not found: _sqlite3_enable_load_extension` — macOS sqlite3 is stripped; `lsqlite3complete` handles this (already wired into `server/PADatabase.lua`)
- `luarocks path` issues — scripts use `eval "$(luarocks path --local --lua-version 5.1)"` to set correct paths

## Architecture

```
serverLauncher.lua          # server entry point
client/src/
  scenes/MainMenu.lua       # server list (add custom servers to debugMenuItems)
  network/NetClient.lua     # client networking
  network/LoginRoutine.lua  # login handshake
server/
  server.lua                # main server loop, connection handling
  server_globals.lua        # config (port, engine version)
  PADatabase.lua            # SQLite wrapper
  Room.lua                  # match rooms
  Leaderboard.lua           # ELO rankings
common/
  engine/consts.lua         # shared constants (SERVER_LOCATION etc.)
  network/NetworkProtocol.lua # message format (TCP, JSON, version "006")
  lib/                      # bundled Lua libs (socket, utf8, etc.)
```

## Network Protocol
- Raw TCP on port `49569`
- Messages: single-char prefix + JSON body + `←J←` terminator
- Handshake version: `006` (`common/network/NetworkProtocol.lua`)
- Per-server player accounts stored client-side in `servers/{SERVER_IP}/user_id.txt`

## Logs

**Client:** terminal + saved to `logs/client.log`
- Read: `tail -f logs/client.log` or `cat logs/client.log`
- Always use `zsh run_client.sh` — never run love directly or hardcode the love path

**Local server:** terminal + saved to `logs/server.log`
- Read: `tail -f logs/server.log` or `cat logs/server.log`
- If port 49569 is already in use, `run_server.sh` kills the previous instance automatically before starting

**Remote server (Vultr — 104.156.250.136):**
```sh
ssh root@104.156.250.136
journalctl -u panel-attack -f      # live tail
journalctl -u panel-attack         # full history
```

`logs/` is gitignored.

## Key Conventions
- Lua 5.1 / LuaJIT throughout (no Lua 5.4 features)
- Server runs headless via `luajit`; client runs via `love`
- Tests are wired into `testLauncher.lua` and also run on server startup
- No environment variables for config — everything in `server/server_globals.lua`
- Data files (`PADatabase.sqlite3`, `players.txt`, etc.) are gitignored — auto-created on first run

## Self-Hosting
See `docs/SelfHosting.md` for full Hetzner VPS setup guide.
