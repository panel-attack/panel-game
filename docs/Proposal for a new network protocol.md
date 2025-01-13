# Proposal for a new network protocol

This is mostly about the subprotocol used in json messages ("J") for setting up matches, login, taunt and spectating and to some extent player inputs ("I", "U").  

## Why the current protocol should go

The current protocol is dated and confusing in some ways.  
It makes some strong assumptions about how matches are setup, effectively impeding the creation of a variety of online functions by being convoluted and so rigid that almost any change in the protocol immediately breaks version compatibility between stable and beta.  
I'll try to illustrate the problems a bit further while mentioning which boxes a new network protocol should tick in order to do well enough for the long haul.  

### Strong assumptions about player count

In the current network protocol, every match is a two-player match.  
This is immediately obvious by the choice of field names such as "player_settings" and "opponent_settings", as well as implicit assumptions that any incoming menu state or input can only be from one sender, the opponent.  

A new network protocol should make no assumptions about an exact player count.  
A new network protocol should clearly state the source of player settings or inputs, ideally via their public player id so that clients do not have to juggle the server's number assignments with its own display order.

### Different names for the same things

In the current protocol, the same data or subsets of that data are sent under different names.  
Namely, generic `menu_state`, menu state without being declared as such, `a_menu_state` or `b_menu_state` when used for a certain player, `player_settings` or `opponent_settings` as a subset of a player's menu state at game start.  

A new protocol should aim to clearly separate player settings and their cursor activity.  
A new protocol should have only one header for each group of settings and each group of settings should always cover the complete set of its values.  

### Imprecise level information 

Level data is currently encapsulated inside the level number.  
This shuts down any possible customization to play online without altering the standard levels.  
Additionally it means there way to play online using classic mode difficulties.  

A new protocol should send the complete frame data for the player stack based on their selection to create forward compatibility for customizations. The level should still be sent for display purposes unless the level data comes from classic mode.

### Replay information is not represented in a sensible hierarchy

Aside from also being guilty of player count issues, replay data presents player related data on the same hierarchy as player-specific data.  
Specifically, data like `seed`, `countdown` and `ranked` is recorded on the same level as player replay data, levels and characters.

A new protocol should aim to clearly separate player-related data and general game data not specific to the player.  
Specifically, general game data could be recorded on the same level as the game mode ("vs", "time" etc).  
Personal comment: We could still assign this data in the previous hierarchy for saving replays to maintain compatibility. But I think it would be better to overhaul that alongside it, introduce an official v2 and have a legacy replay loader in a separate file.

### There is only vs right?

Any online gameplay is implicitly assumed to be vs.  

In a new network protocol, server rooms should have a field that holds the game mode information and send it to new spectators.  
A new network protocol should implement a change request for the game mode that is granted upon agreement of both players.  
This way, rooms could be default vs but subject to change *or* upon accepting a challenge, players have to agree on a game mode on room creation.


## What the new protocol should enable long-term

Here I'm going to name a couple of concrete changes, also in client design, that should impact how we design the new network protocol.  
Additionally I'll name some issues that are currently blocked by the network protocol or would require the current network protocol to change or extend. Ideally we can cover as many of these in advance to greatly reduce the amount of future breaking changes beyond this one.

### Extending online to outside the lobby

Regardless of the exact client-side implementation, players having a way to be online without being in lobby has to be one of the core goals of a new network protocol.  
With players being online in 1p modes or possibly by default, it does no longer make sense to send player settings on login as they will constantly changed.  
Player settings should only be sent when a challenge is issued to another player or when the server requests those settings to satisfy a spectate request.  

To sum up:  
Players should be able to log in only with their name + id.  
Players should be able to inform the client about what they are currently doing ingame.  
Name changes should be verifiable against the server directly rather than on login only.

### Offer 1p modes as parallel play

https://github.com/panel-attack/panel-game/issues/231  

Accomodating different game modes in server rooms allows the game mode to be selected.  
Any remaining items would be relatively trivial to implement.

### Time Attack vs

https://github.com/panel-attack/panel-game/issues/146  

Accurate level data being sent enables classic mode selection on the client.  
Accomodating different game modes in server rooms allows the game mode to be selected.  
Any remaining items would be relatively trivial to implement once those two are cleared via a new network protocol.

### More than 2 players vs

https://github.com/panel-attack/panel-game/issues/59  

Still not trivial but an extendable network protocol that already accomodates n players with inputs and states being identifiable by public player id would still cover a substantial amount of work for this feature.