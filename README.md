# BeamMP CarHunt

A server-authoritative BeamMP hide-and-seek mode with support for **single or multiple hiders**.
<img width="2560" height="1440" alt="screenshot_2026-02-11_14-10-49" src="https://github.com/user-attachments/assets/e153bd53-95cf-42d0-bd3a-78c7935cf007" />

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

## Installation

1. Place the `BeamMP-CarHunt.zip` in your Clients folder and create a folder called `CarHunt` and add `main.lua` into your new folder.
2. Start a round by using `/carhunt start` in the chat box.
3. After a few seconds the round will start and a person will be selected.
4. `Hunters` will be frozen for 45 seconds while the `Hiders` get a headstart.

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
- `/carhunt set explode <seconds>`
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

## Notes

- Vehicle forcing is best-effort and depends on BeamMP client behavior/load timing.
- Role labels and nametag behavior are client-side visual systems.
- If behavior seems stale, verify a fresh client ZIP was deployed correctly.

---
