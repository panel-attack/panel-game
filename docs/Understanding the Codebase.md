# Understanding the Panel Attack Codebase (the short version)
This version seeks to be more brief and on-point for people familiar with lua/love and the game itself (as a player).  

The codebase combines code used for the client and the server. Code used by both or that is anticipated to be used by both is located in the `common` folder.  
Files in the common folder should have no references to files in the server/client folders. The only exception to this are tests that may use I/O living in the client to load replays, puzzles and configurations as test data.

The server has a separate documentation so this document mainly deals with the client architecture.

A `Scene` is the overarching concept of a thing that manages what you see on a screen, what you hear on a screen and how you can interact with that screen.  
`Scene`s are managed by a `NavigationStack` via pop, push and pull operations with only the top-most `Scene` being active.

To play games, a `BattleRoom` is created in which a number of `Player`s can modify their settings and eventually all ready up.
Based on the settings of the `BattleRoom` itself, a `ClientMatch` is created which in turn creates `PlayerStack`s based on the settings of the `Player`s, forming a hierarchic architecture in which the components further down the bottom know nothing of the elements above.  
`BattleRoom`, `Player`, `ClientMatch` and `PlayerStack` are the key points with `Player` and `PlayerStack` both having base classes `MatchPartipant` and `ClientStack` that define the interface for `BattleRoom` and `ClientMatch` to use them.  

# Understanding the Panel Attack Codebase (the long version)
This is a subjective and informal take by Endaris.

## Understanding Lua and Love
In general following the sheepolution tutorial up to maybe chapter 12 is a decent idea:

https://sheepolution.com/learn/book/contents

There is also a video format but it is not as good and not maintained so use the text format.  

### Understanding Lua
If you already know some programming, you can skim some parts if you are familiar with the concepts from other languages:
- variables, if you're familiar with a dynamically typed language
- functions, if you're familiar with a language that has first class functions
- if/for, if you're familiar with any scripting or programming language

You definitely want to read up very closely on:
- tables and by extension classes; classes are not a native concept in Lua but it's possible to realize something like classes via tables
- coroutines, not used terribly often in Panel Atack but a concept that feels a bit more Lua specific

#### table
Still read the tutorial, I'll just make some additions that I personally consider interesting to know about.
A table is an array and dictionary at once and is the monolithic data type on which basically all of Lua is built.  
Functions in a "class" in Lua are ultimately just regular fields on a table that happen to contain a function.  
This means that functions can be freely overwritten on individual tables - whether that is a good idea or not is questionable but it is possible and in some cases extraordinarily useful.  
Tables are the primary way in which memory is allocated and the use of tables is to be scrutinized to some degree to keep the garbage collector happy.


### Understanding Love
Love is a game development framework that provides bindings to SDL and various other crossplatform libraries, allowing us to easily deliver the same build for every platform - provided they have the autoupdater installed in case of windows (it contains a love.exe) or love installed separately on any other OS.  

In Panel Attack, there are mainly 3 important things to understand about love:
- the gameloop
- the callbacks
- the modules

#### The Gameloop

The gameloop of love is effectively
```Lua
while true do
  love.run()
end
```

love.run is a function with a standard implementation. Panel Attack overwrites this function with a similar but for diagnosis and garbage collection purposes modified function inside of the file `CustomRun`.  
Studying either that or https://love2d.org/wiki/love.run is a great idea to get a general understanding of how the loop works.  
In the case of Panel Attack, unlike in the default version, the loop is inherently locked to a certain frame rate, ordinarily 60 FPS.  

#### The callbacks

If you looked at the gameloop, you should have noticed the somewhat cryptic seeming part with `love.handlers` and some `a, b, c, d, e, f` variables.  
This is love pumping events to its callbacks.  
Love provides a handful of useful callbacks, mostly related to user interaction such as `love.keypressed`, `love.joystickadded` or `love.resize` but also some related to things happening in the code, most prominently `love.errorhandler`.  
These callbacks are collectively executed at the start of the frame so that all inputs during the last frame are available.  
For Panel Attack, all love callbacks should be implemented in `main.lua`.

#### The modules

While love has a lot of functionality like a physics system, only some of that is used in Panel Attack.  
Love modules are loaded in `conf.lua` and only loaded modules are usable.  
Panel Attack uses most of the more standard modules. Most of these modules are quite basic with the exception of the `graphics` module which offers way more functionality than Panel Attack currently uses.  
Overall it is relatively easy to guess what a love function does if you see it in context and many of them are also wrapped inside of our own functions so that it's often not that necessary to add new calls yourself.

## Game start

Distribution and development setup differs a bit.  
In distribution Panel Attack uses an updater that fetches updates from panelattack.com and then reinitializes itself by mounting the actual game in its place. The game may then try to require the updater on its own that offers functions to check for updates or restart with a different release stream.  
The exact startup mechanism differs a bit based on the system due to specific issues, see https://github.com/love2d/love/issues/2122.

You can find the current updater at https://github.com/panel-attack/panel-updater with its own documentation.

For developing or troubleshooting updater related things, copy the updater's `updater` directory into this directory and pass `updaterTest` as an extra argument to love.

## Broad Client Structure 

Panel Attack has many files, maybe too many and not all of them are in an intuitive place.  
At the core of Panel Attack lives the `Game` class defined in `Game.lua`.  
`Game` is practically the big global game object that has everything, is accessible from everywhere and handles the actual game loop + drawing.  
In the most recent version, Panel Attack uses a scene system governed by the `NavigationStack`.
This `NavigationStack` holds onto a table of scenes with the latest scene being the active one.
It provides various functions to alter that table to navigate between the scenes and add new ones.
A scene must be able to deal with user inputs and control audio and visuals and can have any level of complexity.  
In the current version of Panel Attack, the title screen is a single scene and so is the entire options menu (including sub menus). Character selection is also a single scene and so is ingame.  

Scenes can broadly be divided in 3 types of scenes:
- menu and configuration
- game setup
- ingame

### Menu and configuration
Menu and configuration obviously includes the main menu, options, setting your name, inputs and the replay browser.  
There is no real trick to these, it's either navigation or changing client settings.

### Game Setup
Game setup includes every menu that prepares a game and has players select their preferred settings before starting the game. So anything that lets you select speed, difficulty, level or character belongs to this.  
What is important to know is that all scenes belonging to these work with a `BattleRoom`.  

#### BattleRoom
The `BattleRoom` is the unified representation of game setup and the life cycle of a set of `ClientMatch`es. A `BattleRoom` may have one or more `MatchParticipant`s, it will always hold the constraints of the game mode the game is being set up for in its `mode` field and it generally governs everything about the experience of setting up and coordinating switches between setup scene and game scene to run a sequence of matches.  
If online, the BattleRoom attaches each player to the `NetClient` which handles sending and receiving of network messages to update `MatchParticipant` settings and is also responsible for starting the game once everyone is ready.  

##### ChallengeMode
`ChallengeMode` inherits `BattleRoom` in order to control the life cycle of a set for its own purposes.  

#### MatchParticipant
The `MatchParticipant` represents the abstract concept of a participant in a `BattleRoom` that has a range of settings and can create a `PlayerStack` or `ChallengeModePlayerStack` with those settings.  
Alongside these settings the `MatchParticipant` also tracks data such as their win count.  
The `MatchParticipant` implements the outlines of an observer pattern to allow other objects to subscribe to updates on the settings of the `MatchParticipant`. 

##### Player
A `Player` is the specialization of `MatchParticipant` that represents (human) players with the full set of settings to create an actual `PlayerStack` that wraps a instance of the engine.  
They support a lot more settings and can be flagged as `isLocal = false` to mark them as remote players that get updated via the `NetClient`. Respectively, local players will send changes of their settings to the server by having the network components subscribe to the `Player`'s settings, keeping the `Player` decoupled from all network activity.

##### ChallengeModePlayer
A `ChallengeModePlayer` is the specialization of `MatchParticipant` that represents the opposing player in a `ChallengeMode` to create a `ChallengeModePlayerStack` that is driven solely with an `AttackEngine` and a `Health` engine.  
As they are mainly managed by the `ChallengeMode` itself they only implement the bare minimum to interface with `BattleRoom` and `ClientMatch`.

### Ingame
All actual ingame happening are operated on a `ClientMatch` that runs a certain number of `ClientStack`s belonging to `MatchParticipant`s.  
`PlayerStack`, `ChallengeModePlayerStack` and `ClientMatch` are oblivious to the existence of `BattleRoom` and for every single game a new `ClientMatch` and new `ClientStack`s are being created - the `ClientMatch` based on the game mode and the `ClientStack`s based on the settings of the `MatchParticipant`s.

## The engine

The engine is located in the `common/engine` directory.
While currently only in use by the client, the goal is for the engine to become an independently versioned component that can be used by client and server alike, in the latter case for example to validate scores for online leaderboards.
The bulk of the game physics lives inside the `Stack` class which is defined in `Stack.lua` and derives from the conceptual minimum `BaseStack` a table needs to implement to be run by a `Match`.  

The client wraps engine classes like `Stack` and `Match` with its own `PlayerStack` and `ClientMatch` classes and registers callbacks to a set of predefined signals to add graphics and sound functionality to the raw physics as well as the actual input mechanism.

The goal is for the engine to be entirely pure and not using love so that the server can run the engine as well, e.g. for validating online Time Attack scores for a leaderboard.
At the time of writing, the remaining dependencies on love are related to the PRNG and the timer only.

### Stack.lua
`Stack.lua` contains the code for construction of `Stack`s, running them, performing rollback, creating new rows, various puzzle stuff and most of the physics that is not directly related to the behaviour of an individual `Panel`.  

### Panel.lua
The behaviour of individual `Panel`s is recorded in `Panel.lua`. Each panel on its own represents somewhat of a finite state machine that changes state based on its own state and the state of the panel below.  
However, the only state transformations for panels governed in this are those that happen passively and without player interaction.  
Via player interaction there are 2 more transformations possible that are handled on the `Stack` level instead of the `Panel` level:
- getting swapped (this is in `Stack.lua` again)
- getting matched

### checkMatches.lua
This file contains the entire routine for checking if there are any matches on the board.  
As a natural extension of that, it is also responsible for transforming garbage panels into regular panels and fetch new colors for that purpose from the `PanelGenerator`.  
Effectively it is just a small collection of `Stack` functions, isolated for better orientation within the repository.

### PanelGenerator.lua
In this file lives the Panel Generator which provides functions to generate panels for a certain seed via a pseudo random number generator and assign possible metal placements for these panels.

### client/src/PlayerStack.lua
The client-side wrapper for the engine `Stack`.

### client/src/network/PlayerStack.lua
This small bit covers input-related functions of PlayerStack that have input activity such as taunt or sending inputs that - in case of online play - are also forwarded to an opponent.  
Ideally the input and network parts should get separated at some point.

### GarbageQueue.lua
The garbage queue defines the how garbage is treated when being sent from a stack as well as when being sent to a stack.  
Garbage queues act as the primary mechanism for Stacks to indirectly interact with other Stacks by having the governing Match transfer garbage from one Stack's outgoing garbage queue to another Stack's incoming garbage queue.

There is a dedicated document for explaining the workings of the garbage queue in the engine folder.

### client/src/graphics/Telegraph.lua
The telegraph is the visual representation of a Stack's outgoing garbage queue. It is only present if the Stack also has a target for its garbage.

### SimulatedStack.lua
A fake stack based on `BaseStack` that can sport an AttackEngine and/or a HealthEngine to mimic a player without actually dealing with any of the complexity a fully fledged CPU player would require.  
Includes graphics functions.

### Match.lua
A match creates and runs the stacks, holding and applying the concrete game settings that aren't on `Stack`.  
As the controlling entity, the match is supposed to control all behaviours that involve more than one stack, such as determining whether a stack needs to save rollback copies or determining a winner.  
There are still some interactions inside of `Stack` that I would rather see on `Match`, such as determining if shock panels should be in the game via a different avenue than levelData itself.
The match will continue running stacks until either only one is left or until or done, depending on the given conditions for winning the match (see section below about GameModes).

### client/src/ClientMatch.lua
The client-side wrapper for the engine `Match`, providing graphics and sfx related functions on top of the raw physics work done by match.
Some parts of rendering are instead taken care of by the scene running the Match and in the future it should ideally be most or all of it.

### GameModes.lua

This effectively holds presets for existing game modes in the game.  
In addition to game mode defining settings, they also contain which scene to use for setup and game.
In the current iteration GameModes are thought to be mainly defined by a set of 5 settings:  

#### Stack Interactions
Defining how the stacks interact with each other.  
The currently possible settings are  

- NONE, if garbage is not sent anywhere, nor is any received
- VERSUS, if garbage is sent to another stack and received from another stack
- SELF, if garbage is sent to yourself
- ATTACK_ENGINE, if garbage is sent by an attack engine

#### Stack Win Conditions
These define a set of zero or more conditions that cause a `Stack` to stop running in a winning state as soon as one is met.  
The currently possible settings are  

- MATCHABLE_PANELS, which can be set to an integer. If that number of matchable panels is left on the board, the stack wins.
- MATCHABLE_GARBAGE_PANELS, same as MATCHABLE_PANELS, except it refers to only unmatched panels making up garbage.
- SCORE, this is not implemented yet but the idea is that once the Stack reaches a certain score it wins, e.g. for 99999 point racing.

#### Stack Over Conditions
These define a set of zero or more conditions that cause a `Stack` to stop running in a losing state as soon as one is met.  
The currently possible settings are  

- HEALTH, which can be set to an integer. If the stack's `health` is equal or smaller, the stack loses.
- SWAPS, which can be set to an integer. If the stack's `swapCount` property equals or exceeds that number, the stack loses.
- CHAIN, which can be set to a boolean. When set to false, the stack loses upon dropping its chain. When set to true, the stack loses upon forming a chain.

#### Match Win Conditions

These define a set of zero or more conditions to determine a winner between multiple Stacks inside a Match.  
All match win conditions are defined through comparative statements between all players in a game.

- HIGHEST means that the stack with the highest number wins and generally higher is better if there are more than 2 players.
- LOWEST means that the stack with the lowest number wins and generally lower is better if there are more than 2 players.

The currently possible settings are  

- GAME_OVER_CLOCK, this is suitable for elimination and VS game modes; not having went game over is considered as infinity
- TIME, this is suitable for non-elimination modes like score races where generally all stacks are expected to survive
- SCORE

Match win conditions are order sensitive and are evaluated until the last one while a tie is present.  
Example:  
In a hypothetical 99999 point race capped to 10 minutes with the match win condition { SCORE, GAME_OVER_CLOCK, TIME }, player 1 and player 2 manage to reach 99999 points before time is up, player 3 self destructs at 72000 points before time is up while player 4 only manages to reach 43000 points when time is up.
First SCORE is evaluated. Player 3 and player 4 are both eliminated as potential winners because player 1 and 2 beat them in points.  
Second GAME_OVER_CLOCK is evaluated. Both player 1 and 2 finished in a winning state so they aren't game over, they are still tied.  
Finally TIME is evaluated, player 2 has a lower clock time than player 1 so they are determined winner.  
In the future each condition should also act as a tiebreaker so that player 3 would be determined to beat player 4 because they win in the score win condition.

Besides the GAME_OVER_CLOCK they're not in use so the existing implementations may actually not work.

#### Match End Conditions

These define a set of conditions that cause the `Match` to conclude the moment one of them is met.

- STACKS_ACTIVE, which can be set to an integer. The moment the amount of Stack's still playing equals or falls below that number, the game finishes.
A stack is considered active when it has neither met a Stack Win, nor a Stack Over condition.
- TIME_LIMIT, which can be set to an integer. This causes the match to stop simulating Stacks the moment they reach that frame number. Once all have reached it, the match ends.

If you have a TIME_LIMIT you usually want at least STACKS_ACTIVE = 0 as an extra condition, otherwise if everyone loses before the time limit is up you will get a bricked match that never ends.

#### Stack behaviours
Stack possesses certain behaviour flags under its `behaviours` table that can toggle major functions.  
Currently available toggles are  
- passiveRaise, controls if the Stack will passively rise from the bottom
If disabled, the player cannot lose health from being topped out.  
The NEGATIVE_HEALTH condition may still be met by manually raising while topped out.
- allowManualRaise, controls if Raise input can be used to manually raise the stack

At the moment Stack behaviours are only applied by way of setting a puzzle.  
As different puzzle types may have different needs for these (e.g. clear puzzles needing death), this is currently not preset for any GameMode preset and they're always assumed until toggled off by setting a puzzle.

### Summary

As a short version for understanding "roughly" what is going on as part of a single player match:  
Inside of a `BattleRoom`, after the `Player` has readied up a `ClientMatch` is being created and started.  
In the start process, a `PlayerStack` is being constructed via the constructor `PlayerStack = class(... etc)` based on the `Player`'s settings.  
Every frame, `ClientMatch:run()` is called on the game scene which in turn runs the engine match and the `Stack`s.  
Via `inputManager.lua`, there are inputs injected to the `Stack`'s `confirmedInput` via `receiveConfirmedInput`.
`Stack.run` applies the inputs as part of `Stack.simulate` and advances its state by one frame.  
If you read the comments for `Stack.simulate`, you may notice a suspicious absence of phase 1 and 2, mostly because they already got extracted into separate functions.

### Replays and Interoperability

common/data defines some classes and functions that create, represent or modify data that is used to exchange information between server and client.

Currently these are:
GameModes, StackBehaviours, ReplayV3, LevelData, LevelPresets, InputCompression, KeyDataEncoding and TouchDataEncoding and (yet to be moved there) GameModes.

If client or server have domain specific needs that go beyond what these classes provide, they should generally aim to create their own components that do not inherit from these to guarantee that client and server internals can be edited and refactored without impacting networking.
It's a lot of boilerplate but ultimately it guarantees that you don't change something on the client and suddenly have to update the server for a completely unrelated client feature and lets the maintainer sleep at night.

Besides these standard formats that are used in communication, both client and server implement an abstraction layer called ClientMessages or ServerMessages respectively whose sole responsibility it is to convert incoming messages to a format the recipient understands.

The server's ClientMessages respectively convert messages sent via common/network/ClientProtocol while the client's ServerMessages do the same for messages as defined in common/network/ServerProtocol.

Likewise these abstraction layers exist to remove the networking component from client/server internals to allow for easy and relatively worry-free refactoring.


## The user interface

Effectively there are two big new things in the new user interface that comes with the scene refactor:
- everything is navigable with touch (shush replay browser)
- everything is organized within a composite tree of `UIElement`

### Touch

Touch is implemented via the pair of `ui/touchHandler.lua` and `ui/UIElement.lua`.  
UiElements that should support touch are automatically considered touchable by implementing at least one of the functions `onTouch`, `onDrag`, `onHold` and `onRelease`.
All scenes have an `uiRoot` that is traversed by the touch handler through `UIElement:getTouchedElement` and only children of the active scene's uiRoot are active for touch.  

### UIElement composite

For general menu design, UIElements should be used.  
There is a lot to say about UIElements and nothing at the same time because the implementations are...rather individual and sometimes quirky.  
There are some generic UIElements with very basic functionality such as Button, Label, Slider, Stepper.  
There are some UIElements for organizing a layout such as UniSizedContainer or ScrollContainer.  
There are some rather specific UIElements for certain purposes such as LevelSlider, StageCarousel or MultiPlayerSelectionWrapper.  
You may find some of these to be rather unfit for the general purposes their names imply and some are in need of a rewrite.

### Layout

The standard layouts for Panel Attack are akin to a FlexBox and the goal of layouts is to provide a way to design UI for scenes so that they provide a good experience on desktop while still being a functional compromise in portrait mode dimensions on mobile.

To achieve this, the layout logic is implemented as mostly separated from UIElements themselves and the layout of most UIElements can be changed just by assigning it a different static layout table.

There are some exceptions to this as some UIElements are built with a specific orientation in mind while providing extra functionality.
Examples of this include:

- ScrollContainers  
You can still change the orientation and layout but usually the contents are designed with the dimensions in mind and thus changing layout orientation will look bad
- Horizontally oriented containers that automatically wrap around as their width reduces  
As they already adjust to portrait dimensions on their own, there is no good reason to change the layout

Layout updates always originate from the UIElement at the root and only if it is marked with `controlsWindow = true`.

The biggest design points to note are the following:

1. `x` and `y` are generally managed by the Layout. Placement of children depends on their order within the parent's `children` table.  
There are some exceptions to this, some layouts will not perform any placement so you can still manually place but these Layouts will never be the default for any UIElement so you have to go out of your way to do it.
2. Alignment of children is based on the parent. That means to center a Button within a UIElement, the UIElement needs to be center aligned, not the Button. The previous iteration based alignment on the children so don't trip over this!

#### General layout idea

A general idea for organizing menu layout is the following:

The root level UIElement that controls the window dimensions and reacts to resizes uses an `AdaptiveFlexLayout` that automatically changes its layout between horizontal and vertical orientation based on its dimensions.  
The root level UIElement has two children that use a `VerticalFlexLayout` each.  
The first child is used for navigation and controls, the second displays info / preview information.  
When in portrait dimensions, the root UIElement utilizes a vertical layout so that the display is a little akin to the Nintendo DS with two "screens".

#### Layout mechanism

For future reference and the creation of new layouts, a brief overview on how the Layout/FlexLayout works.

The first core problem of automatic layout with an arbitrary resolution is that you have to know how big your widgets are before you can start placing them.
The second core problem is wrapping. Text and other tailor-made widgets can trade width for height.

To address these problems, the layout logic follows a multi-step process in which each step traverses and works the entire UI tree before going to the next step.

The first core problem has led to the introduction of a bunch more fields and functions to determine size:

- minWidth, minHeight, defaults to 0
- maxWidth, maxHeight, defaults to math.inf
- getPreferredWidth(), getPreferredHeight()
- hFill, vFill

There are some more subtle problems hidden in this but the baseline is that the width of an element does not depend on its height but as per core problem #2 the height may depend on its width.  
That means we first need to find out how wide an element is. 
The only true answer at the start is "we don't know yet" so each UIElement is initialized with a temporary `newWidth` property that is not necessarily the final result but forms a meaningful basis for following calculations.
For any type of container that contains more than one child, the size also depends on the children so `newWidth` is assigned by recursively drilling down to the leaf nodes to set their `newWidth` first and calculating the parent with the children's information as it returns from the recursion until `newWidth` is assigned for the entire tree.

At first each element's `newWidth` defaults to the highest of the following values:
- the UIElement's `minWidth` property
- the preferred width required by the children in accordance with the layout
in a vertical layout it would depend on the `newWidth` of the widest element only but in a horizontal it would be a sum
- the preferred width of the UIElement itself; this defaults to the UIElement's `minWidth` property but in particular wrappable elements like Labels will instead return their width in an unwrapped state.

Now each element has a valid `newWidth` that makes sense but does not have a relation to the window size yet.

The root element also has preliminary `newWidth` and with the delta of that value to the actual window width we can adjust the existing `newWidth` values in a top-down traversal:

If the delta is positive, it is distributed between all children with the `hFill` property that have not reached their `maxWidth` yet.  
If the delta is negative, it is distributed between all children that have a lower `minWidth` than `newWidth`, starting with the widest element. This will typically hit wrappables that return a preferred width much higher than their minimum width. (Note: it should also consider minWidth based on children on top of the property which it does not do right now).

By traversing downwards, the extra width compared to the initial estimate is thus spent where possible and `newWidth` is finalized as `width`.

For height the same steps are essentially repeated. For wrappable elements their width-based minimum height is accessed through a `getMinHeight()` function that is only required by the HorizontalWrapLayout but the exact implementation of this width-to-height mechanism might change later.

To sum up, a valid and desirable estimate is first made for widths, than corrected with the true width using only operations that are known to be valid so the final outcome is guaranteed to be valid and related to the window size.
The same happens for height with special consideration to the width values.

In the following positioning step, each parent assigns `x` and `y` to its children according to its layout. The values are relative to the parent.

As the final step the tree is once more traversed recursively to call optional callbacks on each UIElement to signify that resizing finished.
This is so that layout oriented UIElements that provide navigation options can make adjustments to how inputs affect selection.


#### Drawing

The layout logic assigns `x` and `y` positions that are relative to its parent.

Each element is called via `UIElement.draw` which first calls `drawSelf`, then performs a coordinate translation and finally calls the predefined `UIElement.drawChildren` that just calls `draw` on all visible children.  
This mechanism is mainly intended for the children to be able to be drawn directly using `self.x` and `self.y` without relying on their parent.  
While this is the default, both `draw` and `drawChildren` can be overwritten for any class to have it exert more fine control over how its children are drawn.  
Notably, since all of these functions reside on metatables, they can also be shadowed on a per-instance basis for tailor-made behaviour.


## Localization

We have a cool localization.csv file. In the first column is the codename of a string, then the traductions into the different languages.  
When adding text to the game, we can reference it by `loc(codename)` so that the loc function can automatically fetch the correct string based on the language configuration.  
For text that is properly embedded within the new UI structure, `Label`s are used for display. `Label` have to be initialized with either an `id` or a `text`.
When using an `id` the `loc` function is used to fill the `Label`'s `text` property. Otherwise the text is filled directly and is not being translated.
If there are placeholders in a localized string, the `replacements` field can be passed with the values that should be used as replacements.  
If you add new localization entries please make sure to **always** add them at the bottom. There is a google doc we pull from where non-developers can submit changes / new localizations and it spoils any syncing attempt if we get new entries in the middle of the file.

## Mods and Assets

The default assets can be found in the `client/assets folder`.  
`client/assets/default_data` contains mods that ship with the game while the other directories contain fallbacks for user mods that don't provide certain assets.
Each graphic asset type has its own file for managing the loading process in `client/src/mods`:  
`Character.lua`, `Panels.lua`, `Stages.lua` and `Theme.lua`.
Loading of characters and stages is described in the next section. Panels always get loaded fully due to their small size and only a single theme can be fully loaded at a time.  
For characters, panels and stages, a table with id by index and a table with the actual mod by id is created for global access.  

### Mod loading

PA has a (still experimental) `ModController` component that tries to automatically load balance the loaded mods.  
`ModController:loadModFor` is a function that lazy loads a mod for a certain user (this can be a player or match) and holds a table with mods that have been loaded.  
Additionally each mod also holds by who it is loaded via weak tables.  
The `ModController` tries to unload any mod not associated with a certain user during its updates, keeping asset use low.  
By matches and players asserting proper claims via `loadModFor`, it is ensured that mods are not released while they are still in use.

## Utilities

Panel Attack uses various more or less generic helpers to deal with things.  
These are a bit strewn all over the code base so I'll summarize them here.

### client side

Client side helpers are considered that because they innately rely on love functions and thus aren't usable by non-love components like the server.

#### FileUtils.lua

Provides various helper functions around I/O access using the love.filesystem module.


#### BarGraph.lua

Draws a bar graph used for per frame value display in debug mode with FPS counter activated (see RunTimeGraph.lua)

### [batteries](https://github.com/1bardesign/batteries)

A powerful library seeking to fill in the huge gaps in Lua's own standard library.  
In Panel Attack we used to use the standalone `manual_gc.lua` which offers some functionality for manually collecting garbage on the client.  

### common

This includes some helpers written for Panel Attack but also third party libraries.

#### tableUtils.lua
A collection of functions specifically to work with Lua tables.

#### util.lua
A rather random assortment of utility functions.

#### class.lua
Allows us to pretend that tables are classes.  
Defining a class such as
```Lua
Sample = class(function(self, sampleNumber)
  self.msg = "I'm a sample nr " .. sampleNumber
  -- do something with your args
end)
```
allows us to create a table as specified in the function passed as an argument to class:
```Lua
local samples = {}
for i=1,5 do 
  sample[i] = Sample(i)
end
```
Additionally we can create class functions like this:
`function Sample.someFunction() end`  
Note that class functions innately cannot be local because they are defined on the table and therefore have their scope defined by the table itself.  

Classes support inheritance for their constructor but child classes have no direct access to the functions of their parent classes if they overwrote their functions (e.g. no `super:print()`).

#### queue.lua and by extension server_queue.lua and TimeQueue.lua

A queue is a numerically indexed table that works via the first-in-first-out principle.  
Other than a regularly indexed table it cannot be iterated with ipairs as it does not shift queue entries down by an index after removing an element. This is mainly a performance concern as `table.remove(t, 1)` is quite expensive performancewise on bigger tables.  
On any persistent table within engine that has entries removed from the front, `queue.lua` should be used.  

`server_queue.lua` uses a similar approach albeit under the premise that elements may get removed from anywhere in the queue, not just the front. The name is misleading and mostly owed to the original creation for queueing incoming server messages.

`TimeQueue.lua` does not queue by index but instead by time. Its primary objective is to schedule or delay events pushed to it for later usage. At the moment it is only being used with its delay function for behaviour testing with delayed message processing of the `TcpClient`.

## Libraries

Panel Attack has picked up some libraries for various purposes, below a short summary what each can be used for and is being used for.

### lsqlite

This is currently only used on the server.  
With the lsqlite library we can access a sqlite database to persist and query data relevant to the server.


### dkjson.lua

An external library for serializing lua tables into json-like strings and vice versa. Don't touch this. This supports some cases that don't fulfill the .json spec and "fixing" those cases would break any mods "relying" on these behaviour quirks.

### simplecsv.lua

A csv parser, only used by the server. For the leaderboard if I recall correctly.
Avoid requiring this anywhere else, we'll only want .json or .sqlite as future file formats.

## Server

See README in server folder

## client/src/network

The network folder primarily hosts files that deal with network on the client side.  
This may include network components of classes that are not primarily network oriented.  

### ServerMessages.lua

Provides sanitization in format for messages the server may send to the client.  
Along with ClientProtocol.lua this serves as an extra level of abstraction so that the client internals don't have to match whatever the server sends.

### LoginRoutine.lua

Provides a coroutine wrapper for the login process.

### Request and Response

Generic classes for network requests.  
Get a request message from `ClientProtocol.lua`.  
Send it off with `TcpClient:sendRequest`.  
If the request has an expected response, this will return a Response table that can be polled via `tryGetValue()` until a response was received (or a timeout was met).  
See the comments for `Response:tryGetValue()` to see how to interpret return values.

### TcpClient

Where all the network magic actually happens. Uses luasocket.

### MessageListener

Listen to one specific server message on the TcpClient's incoming message queue.

## common/network

### ClientProtocol.lua

Presents getters for all messages the client may proactively send to the server.  
This is supposed to be the API for the client to communicate with the server with no client dependencies.

### NetworkProtocol

Contract between client and server for message types and protocol version.

### ServerProtocol.lua

Presents getters for all json messages the server may send to the clients.  
This is supposde to be the API for the server to communicate with the client with no server dependencies.