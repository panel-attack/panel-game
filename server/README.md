# Running a Panel Attack Server

The Panel Attack server runs with LuaJIT and can thus be run on any platform where LuaJIT runs.

[LuaJIT](https://luajit.org/luajit.html) is a Just-In-Time compiler for Lua, based on Lua 5.1.
Running Lua code with the JIT compiler has significant performance gains and it also comes with some extra features.

You may be able to run the server with other Lua versions but it is not recommended.


# Base Installation

The base installation involves the installation of packages to start the server and tools to compile necessary libraries for your system.

As the core packages you need LuaJIT, Lua 5.1 and LuaRocks. LuaRocks is a package manager for Lua that helps with installing necessary libraries. All libraries need Lua5.1 as a dependency for compilation so that they are compatible with LuaJIT.


## Installation with Package Managers (Linux / MacOS)

### apt

```sh
sudo apt-get install luajit lua5.1 luarocks
```

## homebrew

```sh
brew install luajit lua@5.1 luarocks
```

### pacman

```sh
sudo pacman -S luajit lua51 luarocks
```


## Installation on Windows

### LuaJIT

You have to build the binary yourself or find a package manager that does it for you. 
Refer to https://luajit.org/install.html for building yourself.

### Lua 5.1

You can download the source code on the [Lua website](https://www.lua.org/ftp/).  

### LuaRocks

Precompiled binaries are available from http://luarocks.github.io/luarocks/releases/

Alternatively there are install instructions at https://github.com/luarocks/luarocks/wiki/Installation-instructions-for-Windows

From hearsay it is relatively difficult to get LuaRocks to work under Windows and none of the current developers use Windows so you're on your own.

If you only want to run locally for debugging purposes, skip straight to the "Running for development purposes" section near the end.


# Library installation

## Using LuaRocks

LuaRocks will automatically target the most recent version of Lua you have installed. On many systems this will be Lua 5.4.

LuaRocks is particularly stubborn when it comes to reconfiguring it to use 5.1 as its default so all commands will specify the desired Lua version.

### On Linux

LuaRocks install scripts rely on `gcc` so if you do not have that installed for some reason, use your package manager to install it.

#### luasocket

```sh
sudo luarocks install luasocket --lua-version 5.1
```

#### luafilesystem

```sh
sudo luarocks install luafilesystem --lua-version 5.1
```

#### lsqlite3

```sh
sudo luarocks install sqlite3 --lua-version 5.1
sudo luarocks install lsqlite3 --lua-version 5.1
```

#### lua-utf8

``` sh
sudo luarocks install luautf8
```


### On MacOS with homebrew

#### luasocket

```sh
sudo luarocks --lua-dir=/opt/homebrew/opt/lua@5.1 install luasocket
```

#### luafilesystem

```sh
sudo luarocks --lua-dir=/opt/homebrew/opt/lua@5.1 install luafilesystem
```

#### lsqlite3

```sh
sudo luarocks --lua-dir=/opt/homebrew/opt/lua@5.1 install sqlite3
sudo luarocks --lua-dir=/opt/homebrew/opt/lua@5.1 install lsqlite3
```

if that doesn't work you can use 
```sh
sudo luarocks --lua-dir=/opt/homebrew/opt/lua@5.1 install lsqlite3complete
```
and change the require to use lsqlite3complete


#### lua-utf8

```sh
sudo luarocks --lua-dir=/opt/homebrew/opt/lua@5.1 install lua-utf8
```
on some OS's you may need this command instead
```sh
sudo luarocks install luautf8
```

#### Add lua to your path

This step depends more on your shell and environment, but make sure lua's install directory is on your path

macOS fish shell example
```sh
fish_add_path --path /opt/homebrew/lib/lua
```

#### Add luarocks 5.1 to your lua search path

This step depends more on your shell and environment, but make sure luarock's install directory is on your path

macOS fish shell example
```sh
luarocks path --lua-version 5.1
```

Take that output and put it in your config file

```sh
vi ~/.config/fish/config.fish
```

### On Windows

Assuming you got LuaRocks figured out, you should be able to use the documentation to install the libraries in a similar fashion to Linux/MacOS.

If you get it running, please consider making a pull request that adds more detailed instructions for this section.

## Without LuaRocks on Windows

See info in the later section "Running for development purposes on Windows".

# Running the server

## Checkout Repository

Checkout the panel attack repository
```sh
git clone https://github.com/panel-attack/panel-game.git
```

go into that directory

## Running

```sh
luajit serverLauncher.lua
```

### Running for development purposes on Windows

Love, the game framework we use for the client, uses LuaJIT and comes with luasocket and lua-utf8 baked in.  

That means instead of using `luajit` you can start `serverLauncher.lua` with a love 12 exe, provided you have luafilesystem and lsqlite3.

Our repository includes compiled versions of luasocket, luafilesystem and lsqlite3 so that you can develop and test server changes without most of the steps above.

We do strongly recommend testing on a representative linux system or the beta server before deploying to live as running with love means using a different version of LuaJIT and also that you do not run through all code paths the server will run through when loading up these libraries in code used by both server and client.


### Debugging

You should be able to debug the server the same way you debug the game using a `debug` flag. See the launch.json.template for more information.

The server only writes logs once per minute to reduce the amount of I/O so if you're trying to start the server and login, be prepared to initially not see anything beyond the server tests.


## Ranking

If you want to host your own server with ranking, be sure to change your csprng_seed.txt file, or your users' user_ids will be less secure.


## Connecting with the client

If you are running locally you can go into the client's `Options` -> `Debug` -> `Show Debug Servers` to add a menu option for connecting to localhost in the main menu.

If you want to access your server from an IP you need to add your ip to the client's menus.

Change MainMenu.lua, around where it says something like

```Lua
MenuItem.createButtonMenuItem("Beta Server", nil, nil, function() switchToScene(Lobby({serverIp = "betaserver.panelattack.com", serverPort = 59569})) end)
```

to something that makes sense for your server. Replace "Beta Server" the URL and the port number. The port number is optional, by default the game will try to connect to the server's standard port 49569. This can be changed in `server/server_globals.lua` alongside a few other options.