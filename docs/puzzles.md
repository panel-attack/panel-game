# Custom Puzzles

This guide will teach you how to make custom puzzle files for Panel Attack.

## File Setup

Puzzle files should be named something like `WhateverName.json` and placed into your puzzles folder.
ie. `%appdata%\Panel Attack\puzzles`

Each puzzle file can contain as many puzzle sets as you like. Each set within a file can contain any number of individual puzzles.

## File Format

The contents of each puzzle file should be formatted something like this:

```jsonc
{
  "Version": 3,
  "Puzzle Sets": [
    {
      "Set Name": "Name of Puzzle Set",
      "Puzzles": [
        {
          "Puzzle Type": "chain",
          "StartTiming": "countdown",
          "Moves": 0,
          "Stack":
            "040000
             111440",
          "CursorStartLeft":
          {
            "Row": 2,
            "Column": 2
          }
        },
        {
          "Puzzle Type": "clear",
          "Moves": 0,
          "Stack":
           "
          [====]
          [====]
          [====]
          [====]
          [====]
          [====]
          [====]
          [====]
          020000
          122[=]
          245156
		      325363",
          "StartTiming": "firstSwap",
          "Stop": 60,
          "Shake": 0
        },
      ]
    },
  ]
}
```

## Version Information

Version 3 is the current version it allows "Puzzle Sets" to have recursive "Puzzle Sets" for organization purposes.

## Field Descriptions

### Puzzle Set Fields
- **"Puzzle Sets"** - contains a list of all the puzzle sets
- **"Set Name"** - is the name of the set
- **"Description"** - is a description of the set that will be shown in game menus
- **"Puzzles"** - is the list of all the puzzles

### Puzzle Fields

#### Puzzle Type
**"Puzzle Type"** should be one of the following:
- **"moves"** - all panels need to be cleared in the set number of moves
- **"chain"** - all panels need to be cleared once the first chain ends, and there must be a chain
- **"clear"** - all garbage on the field needs to be cleared before health runs out

#### Other Fields
- **"Moves"** - the number of moves allowed to complete the puzzle
  - Set to 0 for unlimited moves (no move limit)
  - **Important**: "moves" type puzzles must have a value greater than 0
- **"Stack"** - the starting arrangement of the panels, see below

#### Start Timing
**"StartTiming"** specifies when the simulation of the Stack starts:
- **"firstSwap"** - Game physics are on hold until the first swap. The player can move normally.
- **"firstInput"** - All game physics are on hold until the first player input.
- **"countdown"** - The game starts after a 3 second countdown
- **"immediately"** - Full simulation starts with no delay

If no start timing is given, a suitable start timing is selected based on puzzle type:
- "clear" and "chain" puzzles will use "firstInput" if a cursor start position is given and "firstSwap" if not
- "moves" puzzles will start immediately

#### Optional Fields
- **"Stop"** - specifies how many frames of stop time are initially granted to the player
- **"Shake"** - specifies how many frames of shake time are initially granted to the player
- **"CursorStartLeft"** - specifies where the left part of the cursor should start the puzzle
  - Format: `{ "Row": 1, "Column": 1 }`
  - Valid ranges: Row must be 1-12, Column must be 1-5
- **"Solution"** - a compressed input string representing the solution to the puzzle
  - Format: String of encoded inputs (swap directions and timing)
  - Used by the game to verify solutions or provide hints
  - The best way to add this is to solve your puzzle in game, and it will be added to the puzzle.
- **"Help Description"** - optional text that explains the puzzle pattern or provides hints to the player
  - Format: String describing the puzzle mechanic or strategy
  - Displayed when the player requests help for the puzzle

#### Panel Buffers
**"PanelBuffer"** specifies the panels that should appear if the player is raising the stack.

If not specified these will be unmatchable grey panels. Outside of clear puzzles, raising is currently disabled.

**"GarbagePanelBuffer"** specifies the panel that should appear from cleared garbage.

For each cleared row of garbage, the first 6 colors are taken from the string and assigned to the positions in the row accordingly.

If a piece of garbage did not fill out an entire row only the colors in the spots with garbage will appear, e.g.:

```
[==]00
919999
91[==]
919999
```

If the garbagePanelBuffer is "123456123456", the bottom garbage will transform into 3456 and the top garbage will transform into 1234.

Afterwards the garbagePanelBuffer will be empty. An empty buffer means that only grey unmatchable panels will appear from garbage.

## JSON Formatting Notes

**Note:** carriage returns and spaces in your file are very helpful for readability, but are not necessary.

Be sure to use the correct delimiters in the right places, i.e:
- curly braces `{}` to start and end the file and around individual puzzles and puzzle sets,
- square brackets `[]` around the list of puzzle sets and each list of puzzles,
- quotes `""` around set names and panel maps
- commas between elements

Try and use a JSON validator if Panel Attack cannot read your puzzle file!

## Stack Layout

### Number Mapping

Panel Attack reads the numbers that represent what each panel's color should be from right to left, filling the play field with panels starting at the bottom right corner, from right to left, bottom to top.

Additionally there exists a special notation for representing connected garbage blocks.

This allows us to lay out our text representation of the puzzle how it would look in the game, like this:

```
[=====
=====]
001200
002100
002100
```

Carriage returns are allowed in the middle of the panel maps for each individual puzzle.

### Panel Colors

- **0** = empty
- **1** = red
- **2** = green
- **3** = light blue
- **4** = yellow
- **5** = purple
- **6** = dark blue
- **7** = orange (not really used in the game so far, but it exists)
- **8** = exclamation block `[!]`
- **9** = block with no color (dark grey, doesn't match with anything)

### Garbage Block Notation

- **[** = top left corner of a combo / chain garbage block
- **]** = bottom right corner of a combo / chain garbage block
- **{** = left end of a shock garbage block
- **}** = right end of a shock garbage block
- **=** = filler space to determine the size of the garbage block indicated by the surrounding `[]{}`

## More Examples

For additional examples, check out the [default puzzles included with the game](https://github.com/panel-attack/panel-game/blob/beta/client/assets/default_data/puzzles/) on GitHub. This file contains a variety of puzzle types and demonstrates many of the features described in this guide.
