# BeamMP CarHunt

A server-authoritative BeamMP hide-and-seek mode with support for **single or multiple hiders**.

---

## Overview

In CarHunt:
- One or more players are chosen as **Hiders**
- Everyone else becomes **Seekers**
- Seekers are frozen during a configurable headstart
- Seekers must tag hiders
- Tagged hiders must keep moving or explode after a configurable idle timer

Round outcomes:
- **Hiders win** if time expires and at least one hider is still alive
- **Seekers win** when all hiders are eliminated

---

## Features

- Server-authoritative round state and timing
- Multi-hider support (`hiderCount`)
- Forced hider list support (`forcedHiders`)
- Forced default hider vehicle
- Headstart freeze for seekers
- Configurable **hard freeze** toggle
- Grace period before idle explosion starts (`tagGraceSeconds`)
- Idle explosion timer (`hiderIdleExplodeSeconds`)
- Contact + proximity tag detection
- Mid-round join lock (spectator until next round)
- Hider reset/home bypass protections
- Runtime admin commands
- Status + scoreboard output
- Round-end summary with full hider breakdown

---

## Repository Layout

- `Server/CarHunt/main.lua`  
  Main game mode logic (state machine, commands, win conditions, summaries)

- `Server/CarHunt/config.lua`  
  Default settings

- `Client/scripts/carhunt/modScript.lua`  
  Client loader (`load("carhunt")`)

- `Client/lua/ge/extensions/carhunt.lua`  
  Client sync, UI timer, role labels, freeze/reset filters, tag fallback

- `Client/lua/vehicle/extensions/auto/carhuntcontactdetection.lua`  
  Vehicle contact event helper

---

## Installation

## Server

1. Copy `Server/CarHunt` into your BeamMP server Lua mods path.
2. Ensure your server entrypoint loads CarHunt:

```lua
require("CarHunt/main")
```

## Client

Create your client ZIP from the **contents** of `Client/` with these at ZIP root:
- `scripts/`
- `lua/`
- `shaders/` (if used)

⚠️ Do **not** include an extra parent folder in the ZIP.

Upload this ZIP as your BeamMP client mod package.

---

## Commands

### Core
- `/carhunt help`
- `/carhunt start [minutes]`
- `/carhunt stop`
- `/carhunt reset`
- `/carhunt status`
- `/carhunt scoreboard`
- `/carhunt toggle` (toggle global nametag visibility)

### Settings
- `/carhunt set headstart <seconds>`
- `/carhunt set vehicle <vehicleId>`
- `/carhunt set hiders <count>`
- `/carhunt set hider <name1,name2,...|clear>`
- `/carhunt set idleexplode <seconds>`
- `/carhunt set taggrace <seconds>`
- `/carhunt set catchdistance <meters>`
- `/carhunt set hardfreeze toggle`
- `/carhunt set autoround <on|off>`
- `/carhunt set autodelay <seconds>`

### Examples
- `/carhunt start 7`
- `/carhunt set vehicle pigeon`
- `/carhunt set hiders 2`
- `/carhunt set hider ashmaker000,friendname`
- `/carhunt set hider clear`
- `/carhunt set idleexplode 10`
- `/carhunt set hardfreeze toggle`

---

## Configuration (`Server/CarHunt/config.lua`)

- `roundDuration` (seconds)
- `headStart` (seconds)
- `hiderVehicle`
- `hiderConfig` (optional)
- `hiderCount`
- `forcedHiders` (array of player names)
- `hiderIdleExplodeSeconds`
- `tagGraceSeconds`
- `hideNameTags`
- `hardFreeze`
- `catchDistance`
- `autoNextRound`
- `autoNextDelay`

---

## Round Flow

1. Admin runs `/carhunt start`
2. Server selects hiders:
   - forced names first (if valid/online)
   - random fill to match `hiderCount`
3. Seekers are frozen for `headStart`
4. Hunt phase begins
5. Seekers tag hiders (contact/proximity)
6. Tagged hider gets grace period (`tagGraceSeconds`)
7. If tagged hider remains stationary for `hiderIdleExplodeSeconds`, they explode
8. Seekers win when all hiders are out; otherwise hiders win on timeout
9. Server posts end summary with `Hiders`, `Alive`, and `Out`

---

## Notes

- Vehicle forcing is best-effort and depends on BeamMP client behavior/load timing.
- Role labels and nametag behavior are client-side visual systems.
- If behavior seems stale, verify a fresh client ZIP was deployed correctly.

---

## License

Add the license of your choice before public release (MIT is common for mod projects).
