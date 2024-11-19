# Creating archives for drag+drop import

This file documents the format a mod needs to be shared in in order to work with Panel Attack's drag + drop import.

## Folder structure

Archives always need to replicate the root folder structure of Panel Attack's save directory.  
This structure does not need to be complete but may only contain the folders you want to provide mods for. Other folders are ignored.

## Requirements

All mods need to at least contain a config.json file. Non-theme mods need this config.json to specify their id and in the case of characters and stages, their name, otherwise they cannot be imported.

## Limitations

Attack pattern file import is currently not supported.  
Challenge mode file import is currently not supported.
Puzzle file import is currently not supported

## Examples

### Valid package example

```
├── Mod Package
│   ├── characters
│   │   ├── Pikachu
│   │   |   ├── config.json
│   │   |   ├── more files
│   │   ├── Charizard
│   │   |   ├── config.json
│   │   |   ├── more files
│   ├── stages
│   ├── themes
│   │   ├── PPL
│   │   |   ├── config.json
│   │   |   ├── more files
```

### Invalid package example

```
├── Pikachu
|   ├── config.json
|   ├── more files
```

#### Correct

```
├── Pikachu
│   ├── characters
│   │   ├── Pikachu
│   │   |   ├── config.json
│   │   |   ├── more files
```

also correct

```
├── characters
│   ├── Pikachu
│   |   ├── config.json
│   |   ├── more files
```