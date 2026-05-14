NAME_LENGTH_LIMIT = 16
COMPRESS_REPLAYS_ENABLED = true
COMPRESS_SPECTATOR_REPLAYS_ENABLED = true -- Send current replay inputs over the internet in a compressed format to spectators who join.
ANY_ENGINE_VERSION_ENABLED = false -- The server will accept any engine version. Mainly to be used for debugging.
ENGINE_VERSION = "049"
SERVER_PORT = 49569 -- default: 49569 (gameplay channel: I, G, D, K, E, H)
LOBBY_PORT = 49570 -- lobby channel: J (all JSON) + own H/E. Independent socket.
SERVER_MODE = true -- global to know the server is running the process