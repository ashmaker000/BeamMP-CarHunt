# BeamMP CarHunt

A server-authoritative BeamMP hide-and-seek mode with support for **single or multiple hiders**.
<img width="2560" height="1440" alt="screenshot_2026-02-11_14-10-49" src="https://github.com/user-attachments/assets/e153bd53-95cf-42d0-bd3a-78c7935cf007" />

---

## Overview

In CarHunt:
- One or more players are chosen as **Hiders**
- Everyone else becomes **Hunters**
- Hunters are frozen during a configurable headstart
- Hunters must tag hiders
- Tagged hiders must keep moving or explode after a configurable idle timer

Round outcomes:
- **Hiders win** if time expires and at least one hider is still alive
- **Hunters win** when all hiders are eliminated

---

## Features

- Server-authoritative round state and timing
- Multi-hider support (`hiderCount`)
- Forced hider list support (`forcedHiders`)
- Forced default hider vehicle
- Headstart freeze for hunters
- Configurable **hard freeze** toggle
- Grace period before idle explosion starts (`tagGraceSeconds`)
- Idle explosion timer (`hiderIdleExplodeSeconds`)
- Contact + proximity tag detection
- Mid-round join lock (spectator until next round)
- Hider reset/home bypass protections
- Runtime admin commands
- Status + scoreboard output
- Round-end summary with full hider breakdown

### Installation

1. **Download the release**

   * Go to the **Releases** page.
   * Download the latest `.zip` file.

2. **Extract the files**

   * Unzip the download.
   * You will get two folders:

     * `Client`
     * `Server`

3. **Install the client files**

   * Open the extracted **Client** folder.
   * Inside it is a `.zip` file.
   * Upload that `.zip` into your server’s **client mods folder**.

4. **Install the server files**

   * Open the extracted **Server** folder.
   * Inside is a folder for the game mode (e.g. `CarHunt`, `Tag`, `PropHunt` etc.).
   * On your server, open the main **server folder**.
   * Create a folder for that game mode (for example: `CarHunt`, `Tag`, `PropHunt`).
   * Copy **all files** from the extracted game mode folder into the matching folder you just created on the server.

5. **Restart the server**

   * Restart your BeamMP server.
   * The game mode should now be active.

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
