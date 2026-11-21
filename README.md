# Panel Attack Development

## Development Setup

### Installing love

Panel Attack uses CI builds of love 12.0 to run.  
Love 12 is still in development. You can find love 12.0 CI builds in the [love repository](https://github.com/love2d/love/actions/workflows/main.yml).  
Simply pick the newest workflow run, scroll down and select the artifact suitable for your machine.

### Setting up the Panel Attack repository

Clone a copy of the repository  
```
git clone https://github.com/panel-attack/panel-game.git
```  
We recommend using [GitHub Desktop](https://desktop.github.com) as it manages login for you and makes working with git easier.
  
We recommend developing and running the game using [Visual Studio Code](https://code.visualstudio.com/) or [VSCodium](https://vscodium.com/).  
You can setup either with a debugger and more [following this tutorial](https://sheepolution.com/learn/book/bonus/vscode).

Alternatively, you can edit with your own favorite text editor and run love from the command line

```
cd panel-game
love ./
```

or via drag and drop with the repository folder (not recommended).


## Repository

The beta branch is where we do all main development. Please don't use any other branches as a base for development unless advised by a maintainer.

All pull requests require a review by a maintainer.  
Feature and bug commits are done by maintainers using squash merges.  
Merges are done by the maintainers as merge commits.  

Please check the [contribution guidelines](CONTRIBUTING.md) for further information.

## Releases and servers

Releases and the live servers are documented in the [panel-game-server](https://github.com/panel-attack/panel-game-server) repository, which is private to maintainers.

## Useful Lua Programming Tips

Love Tutorial  
https://sheepolution.com/learn/book/contents

Lua Manual  
https://www.lua.org/manual/5.1/index.html
