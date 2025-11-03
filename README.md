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
cd Panel-Attack
love ./
```

or via drag and drop with the repository folder (not recommended).


## Repository

The beta branch is where we do all main development. Please don't use any other branches as a base for development unless advised by a maintainer.

All pull requests require a review by a maintainer.  
Feature and bug commits are done by maintainers using squash merges.  
Merges are done by the maintainers as merge commits.  
On merge, changes from pull requests should be documented in the [Upcoming release notes issue](https://github.com/panel-attack/panel-game/issues/382) to facilitate any following releases.

Please check the [contribution guidelines](CONTRIBUTING.md) for further information.

## Release schedule

### Main releases

Panel Attack currently has 2 release streams that see updates at varying rates.

#### beta release

beta releases use the leading beta branch on the repository.

Features are released on beta if there is some confidence that they're mostly working correctly.

Release notes are posted in #panel-attack-updates on the discord when updates go out.

#### stable release

stable release usually use an older commit of the leading beta branch. In some circumstances we will make a release branch to deliver hotfixes but this will always be a temporary branch.

Stable releases take tournament dates into consideration so that any bugs that may still get caught don't interfere with them.  

Release notes are posted in #panel-attack-updates on the discord when updates go out.

## Useful Lua Programming Tips

Love Tutorial  
https://sheepolution.com/learn/book/contents

Lua Manual  
https://www.lua.org/manual/5.1/index.html  


# For Maintainers

## Releasing

To make a release, create a love file by running `./build.sh just-love` in a terminal. Change the name of the love file to the output of a command like this:  
    Stable:  
        `echo "panel-$(date -u "+%Y-%m-%d_%H-%M-%S").love"`  
    Beta:  
        `echo "panel-beta-$(date -u "+%Y-%m-%d_%H-%M-%S").love"`  

Secure copy the file to the server in correct folder on the server.  
    Stable:  
        `scp -i privatekey.pem panel-2022-06-25_03-50-14.love username@panelattack.com:updates/stable`  
    Beta:  
        `scp -i privatekey.pem panel-2022-06-25_03-50-14.love username@panelattack.com:updates/beta`  

Test that the game updates properly.  

Post release notes in #panel-attack-updates on the discord. If you are lucky you can find upcoming patch notes [here](https://github.com/panel-attack/panel-game/issues/382) but it is usually wise to compare the list with recent commits and the previous update notes.