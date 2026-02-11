local cfg = require("config").defaults

local state = {
  status = "idle", -- idle|headstart|hunt|ended
  gameRunning = false,
  seekersFrozen = false,
  headStartRemaining = 0,
  roundRemaining = 0,
  hider = nil,
  hiders = {},
  roundHiders = {},
  hiderVehicle = nil,
  hiderConfig = nil,
  forceAttempts = 0,
  hiderTagged = false,
  taggedHider = nil,
  hiderTaggedAtTick = 0,
  hiderStationarySeconds = 0,
  hiderMoving = false,
  players = {},
  settings = {
    hideNameTags = cfg.hideNameTags,
    hardFreeze = cfg.hardFreeze,
    autoNextRound = cfg.autoNextRound,
    autoNextDelay = cfg.autoNextDelay,
    tagGraceSeconds = cfg.tagGraceSeconds,
    hiderIdleExplodeSeconds = cfg.hiderIdleExplodeSeconds,
    catchDistance = cfg.catchDistance
  },
  stats = {},
  winner = nil,
  reason = nil,
  startedAtTick = 0
}

local tick = 0
local BUILD = "2026-02-11-hardfreeze-toggle-hotfix14"

local function getEligiblePlayers()
  local out = {}
  for id, name in pairs(MP.GetPlayers()) do
    if MP.IsPlayerConnected(id) and MP.GetPlayerVehicles(id) then
      out[#out + 1] = { id = id, name = name }
    end
  end
  return out
end

local function ensureStats(playerName)
  if not state.stats[playerName] then
    state.stats[playerName] = {
      hiderWins = 0,
      seekerWins = 0,
      tags = 0,
      rounds = 0
    }
  end
  return state.stats[playerName]
end

local function clearRoundState()
  state.players = {}
  state.hider = nil
  state.hiders = {}
  state.roundHiders = {}
  state.hiderVehicle = nil
  state.hiderConfig = nil
  state.forceAttempts = 0
  state.hiderTagged = false
  state.taggedHider = nil
  state.hiderTaggedAtTick = 0
  state.hiderStationarySeconds = 0
  state.hiderMoving = false
  state.winner = nil
  state.reason = nil
  state.startedAtTick = 0
  state.status = "idle"
  state.gameRunning = false
  state.seekersFrozen = false
  state.headStartRemaining = 0
  state.roundRemaining = 0
end

local function isHiderName(name)
  return state.hiders and state.hiders[name] == true
end

local function buildPlayerState()
  state.players = {}
  for _, p in ipairs(getEligiblePlayers()) do
    local hider = isHiderName(p.name)
    state.players[p.name] = {
      id = p.id,
      role = hider and "hider" or "seeker",
      frozen = not hider,
      connected = true
    }
  end
end

local function triggerStateAll()
  MP.TriggerClientEventJson(-1, "carhunt_updateGameState", state)
end

local function maybeDiffAndBroadcast()
  triggerStateAll()
end

local function forceHiderVehicle(name)
  if not name then return end
  MP.TriggerClientEvent(-1, "carhunt_forceHiderVehicle", name, state.hiderVehicle or cfg.hiderVehicle, state.hiderConfig or cfg.hiderConfig)
end

local function chooseHiders()
  local players = getEligiblePlayers()
  if #players < 2 then return nil end

  local targetCount = math.max(1, math.min(cfg.hiderCount or 1, #players - 1))
  local selected = {}
  local selectedSet = {}

  for _, forced in ipairs(cfg.forcedHiders or {}) do
    if #selected >= targetCount then break end
    for _, p in ipairs(players) do
      if p.name == forced and not selectedSet[p.name] then
        table.insert(selected, p.name)
        selectedSet[p.name] = true
      end
    end
  end

  while #selected < targetCount do
    local pick = players[math.random(1, #players)].name
    if not selectedSet[pick] then
      table.insert(selected, pick)
      selectedSet[pick] = true
    end
  end

  return selected
end

local function startRound(duration)
  if state.gameRunning then
    MP.SendChatMessage(-1, "CarHunt: round already running.")
    return
  end

  local hiderList = chooseHiders()
  if not hiderList or #hiderList == 0 then
    MP.SendChatMessage(-1, "CarHunt: need at least 2 players with vehicles.")
    return
  end

  clearRoundState()
  state.hider = hiderList[1]
  state.hiders = {}
  state.roundHiders = {}
  for _, h in ipairs(hiderList) do
    state.hiders[h] = true
    table.insert(state.roundHiders, h)
  end
  state.status = "headstart"
  state.gameRunning = true
  state.seekersFrozen = true
  state.headStartRemaining = cfg.headStart
  state.roundRemaining = duration or cfg.roundDuration
  state.startedAtTick = tick
  state.hiderVehicle = cfg.hiderVehicle
  state.hiderConfig = cfg.hiderConfig
  state.settings.hideNameTags = cfg.hideNameTags
  state.settings.hardFreeze = cfg.hardFreeze
  state.settings.autoNextRound = cfg.autoNextRound
  state.settings.autoNextDelay = cfg.autoNextDelay
  state.settings.tagGraceSeconds = cfg.tagGraceSeconds
  state.settings.hiderIdleExplodeSeconds = cfg.hiderIdleExplodeSeconds
  state.settings.catchDistance = cfg.catchDistance
  state.forceAttempts = 0
  state.hiderTagged = false
  state.taggedHider = nil
  state.hiderTaggedAtTick = 0
  state.hiderStationarySeconds = 0
  state.hiderMoving = false
  buildPlayerState()
  for _, hiderName in ipairs(hiderList) do
    forceHiderVehicle(hiderName)
  end

  MP.SendChatMessage(-1, string.format("CarHunt starting. Hiders: %s. Seekers frozen for %ds.", table.concat(hiderList, ", "), state.headStartRemaining))
  triggerStateAll()
end

local function endRound(winner, reason)
  if not state.gameRunning then return end
  state.status = "ended"
  state.gameRunning = false
  state.seekersFrozen = false
  state.winner = winner
  state.reason = reason
  for _, p in pairs(state.players) do p.frozen = false end
  triggerStateAll()
  MP.TriggerClientEvent(-1, "carhunt_resetState", "nil")

  if winner == "hider" then
    MP.SendChatMessage(-1, "CarHunt: Hider(s) win! Survived until timer end.")
  elseif winner == "seekers" then
    MP.SendChatMessage(-1, "CarHunt: Seekers win! All hiders eliminated.")
  else
    MP.SendChatMessage(-1, "CarHunt: round ended.")
  end

  local elapsed = math.max(0, tick - (state.startedAtTick or tick))
  local mins = math.floor(elapsed / 60)
  local secs = elapsed % 60

  for playerName, player in pairs(state.players) do
    if player.role == "hider" or player.role == "seeker" then
      local s = ensureStats(playerName)
      s.rounds = s.rounds + 1
      if winner == "hider" and player.role == "hider" then s.hiderWins = s.hiderWins + 1 end
      if winner == "seekers" and player.role == "seeker" then s.seekerWins = s.seekerWins + 1 end
    end
  end
  local winnerLabel = (winner == "hider" and "HIDER") or (winner == "seekers" and "SEEKERS") or "NONE"
  local reasonMap = {
    timeout = "Timer expired",
    hider_immobilized = "Hider immobilized",
    hider_disconnected = "Hider disconnected",
    manual = "Stopped manually",
    contact = "Contact tag"
  }
  local reasonLabel = reasonMap[reason or ""] or tostring(reason or "unknown")
  local hiderList = state.roundHiders or {}
  local alive, out = {}, {}
  for _, h in ipairs(hiderList) do
    local role = state.players[h] and state.players[h].role or "unknown"
    if role == "hider" then table.insert(alive, h) else table.insert(out, h) end
  end

  MP.SendChatMessage(-1, string.format("CarHunt Summary: Winner=%s | Reason=%s | Duration=%02d:%02d | Hiders=%s | Alive=%s | Out=%s",
    winnerLabel,
    reasonLabel,
    mins,
    secs,
    (#hiderList > 0 and table.concat(hiderList, ", ") or "n/a"),
    (#alive > 0 and table.concat(alive, ", ") or "none"),
    (#out > 0 and table.concat(out, ", ") or "none")
  ))
end

local function stopRound()
  endRound("none", "manual")
  clearRoundState()
  triggerStateAll()
end

local function resetRound()
  clearRoundState()
  MP.TriggerClientEvent(-1, "carhunt_resetState", "nil")
  triggerStateAll()
  MP.SendChatMessage(-1, "CarHunt: reset complete.")
end

local function parseNumber(value)
  local n = tonumber(value)
  return n and math.floor(n) or nil
end

local function markHiderTagged(hiderName, seekerName)
  if state.hiderTagged then return end
  state.hiderTagged = true
  state.taggedHider = hiderName
  state.hiderTaggedAtTick = tick
  state.hiderStationarySeconds = 0
  if seekerName then
    local s = ensureStats(seekerName)
    s.tags = s.tags + 1
  end
  MP.SendChatMessage(-1, "CarHunt: " .. tostring(hiderName) .. " tagged! Keep moving or explode in " .. tostring(cfg.hiderIdleExplodeSeconds or 10) .. "s.")
end

function onContact(localPlayerID, data)
  if not state.gameRunning or state.status ~= "hunt" then return end
  local remotePlayerID = tonumber(data)
  if not remotePlayerID then return end

  local localName = MP.GetPlayerName(localPlayerID)
  local remoteName = MP.GetPlayerName(remotePlayerID)
  if not localName or not remoteName then return end

  local localRole = state.players[localName] and state.players[localName].role
  local remoteRole = state.players[remoteName] and state.players[remoteName].role

  if not localRole or not remoteRole then return end

  if localRole == "seeker" and remoteRole == "hider" then
    markHiderTagged(remoteName, localName)
  elseif localRole == "hider" and remoteRole == "seeker" then
    markHiderTagged(localName, remoteName)
  end
end

function requestState(localPlayerID)
  MP.TriggerClientEventJson(localPlayerID, "carhunt_updateGameState", state)
end

function onHiderMotion(localPlayerID, data)
  if not state.gameRunning or state.status ~= "hunt" or not state.hiderTagged then return end
  local name = MP.GetPlayerName(localPlayerID)
  if name ~= state.taggedHider then return end
  state.hiderMoving = tostring(data) == "1"
end

function onProximityTag(localPlayerID, data)
  if not state.gameRunning or state.status ~= "hunt" then return end
  local seekerName = MP.GetPlayerName(localPlayerID)
  local player = state.players[seekerName or ""]
  if not seekerName or not player or player.role ~= "seeker" then return end

  local targetHider = tostring(data or "")
  if targetHider == "" then return end
  if not state.players[targetHider] or state.players[targetHider].role ~= "hider" then return end

  markHiderTagged(targetHider, seekerName)
end

function onSecond()
  tick = tick + 1
  if not state.gameRunning then
    if state.status == "ended" and cfg.autoNextRound and tick >= cfg.autoNextDelay then
      tick = 0
      startRound(cfg.roundDuration)
    end
    return
  end

  if state.status == "headstart" then
    if state.forceAttempts < 4 and state.hiders then
      for hiderName, enabled in pairs(state.hiders) do
        if enabled then forceHiderVehicle(hiderName) end
      end
      state.forceAttempts = state.forceAttempts + 1
    end

    state.headStartRemaining = math.max(0, state.headStartRemaining - 1)
    if state.headStartRemaining == 0 then
      state.status = "hunt"
      state.seekersFrozen = false
      for _, p in pairs(state.players) do p.frozen = false end
      MP.TriggerClientEvent(-1, "carhunt_setFreeze", "0")
      MP.SendChatMessage(-1, "CarHunt: Hunt started!")
    end
  elseif state.status == "hunt" then
    state.roundRemaining = math.max(0, state.roundRemaining - 1)

    if state.hiderTagged then
      local grace = cfg.tagGraceSeconds or 3
      if (tick - (state.hiderTaggedAtTick or tick)) >= grace then
        if state.hiderMoving then
          state.hiderStationarySeconds = 0
        else
          state.hiderStationarySeconds = (state.hiderStationarySeconds or 0) + 1
        end

        if state.hiderStationarySeconds >= (cfg.hiderIdleExplodeSeconds or 10) then
          local eliminated = state.taggedHider
          MP.SendChatMessage(-1, "CarHunt: " .. tostring(eliminated) .. " immobilized for " .. tostring(cfg.hiderIdleExplodeSeconds or 10) .. "s. BOOM!")
          MP.TriggerClientEvent(-1, "carhunt_explodeHider", eliminated)
          state.hiders[eliminated] = nil
          if state.players[eliminated] then state.players[eliminated].role = "out" end

          local anyHidersLeft = false
          for _, p in pairs(state.players) do
            if p.role == "hider" then anyHidersLeft = true break end
          end

          state.hiderTagged = false
          state.taggedHider = nil
          state.hiderStationarySeconds = 0
          state.hiderMoving = false

          if not anyHidersLeft then
            endRound("seekers", "hider_immobilized")
            return
          else
            MP.SendChatMessage(-1, "CarHunt: Remaining hiders still in play.")
          end
        end
      end
    end

    if state.roundRemaining == 0 then
      endRound("hider", "timeout")
    end
  end

  maybeDiffAndBroadcast()
end

local function ensurePlayerState(playerName, playerID)
  if not state.players[playerName] then
    state.players[playerName] = { id = playerID, role = "seeker", frozen = false, connected = true }
  else
    state.players[playerName].id = playerID
    state.players[playerName].connected = true
  end
end

function onPlayerJoin(playerID)
  local name = MP.GetPlayerName(playerID)
  if not name then return end

  if state.gameRunning and (state.status == "headstart" or state.status == "hunt") then
    state.players[name] = { id = playerID, role = "spectator", frozen = false, connected = true, joinLocked = true }
    MP.SendChatMessage(playerID, "CarHunt: join-lock active, you'll join next round.")
  else
    ensurePlayerState(name, playerID)
  end

  requestState(playerID)
end

function onPlayerDisconnect(playerID)
  local name = MP.GetPlayerName(playerID)
  if not name or not state.players[name] then return end
  state.players[name].connected = false

  if state.gameRunning and state.players[name] and state.players[name].role == "hider" then
    state.players[name].role = "out"
    state.hiders[name] = nil

    local anyHidersLeft = false
    for _, p in pairs(state.players) do
      if p.role == "hider" then anyHidersLeft = true break end
    end

    if not anyHidersLeft then
      endRound("seekers", "hider_disconnected")
    end
  end
end

local function cmdSet(senderID, key, value)
  if key == "headstart" then
    local n = parseNumber(value)
    if not n then MP.SendChatMessage(senderID, "Usage: /carhunt set headstart <seconds>") return end
    cfg.headStart = math.max(0, n)
    MP.SendChatMessage(senderID, "CarHunt: headstart set to " .. cfg.headStart)
  elseif key == "vehicle" then
    if not value or value == "" then MP.SendChatMessage(senderID, "Usage: /carhunt set vehicle <vehicleId>") return end
    cfg.hiderVehicle = value
    cfg.hiderConfig = nil -- vehicle-only mode
    MP.SendChatMessage(senderID, "CarHunt: default hider vehicle set to " .. cfg.hiderVehicle .. " (applies to future rounds)")
  elseif key == "idleexplode" then
    local n = parseNumber(value)
    if not n then MP.SendChatMessage(senderID, "Usage: /carhunt set idleexplode <seconds>") return end
    cfg.hiderIdleExplodeSeconds = math.max(1, n)
    MP.SendChatMessage(senderID, "CarHunt: idle explode set to " .. cfg.hiderIdleExplodeSeconds .. "s")
  elseif key == "taggrace" then
    local n = parseNumber(value)
    if not n then MP.SendChatMessage(senderID, "Usage: /carhunt set taggrace <seconds>") return end
    cfg.tagGraceSeconds = math.max(0, n)
    MP.SendChatMessage(senderID, "CarHunt: tag grace set to " .. cfg.tagGraceSeconds .. "s")
  elseif key == "autoround" then
    local v = tostring(value or "")
    cfg.autoNextRound = (v == "on" or v == "true" or v == "1")
    MP.SendChatMessage(senderID, "CarHunt: autoround " .. (cfg.autoNextRound and "ON" or "OFF"))
  elseif key == "autodelay" then
    local n = parseNumber(value)
    if not n then MP.SendChatMessage(senderID, "Usage: /carhunt set autodelay <seconds>") return end
    cfg.autoNextDelay = math.max(1, n)
    MP.SendChatMessage(senderID, "CarHunt: auto delay set to " .. cfg.autoNextDelay .. "s")
  elseif key == "catchdistance" then
    local n = parseNumber(value)
    if not n then MP.SendChatMessage(senderID, "Usage: /carhunt set catchdistance <meters>") return end
    cfg.catchDistance = math.max(1, n)
    MP.SendChatMessage(senderID, "CarHunt: catch distance set to " .. cfg.catchDistance .. "m")
  elseif key == "hardfreeze" then
    cfg.hardFreeze = not cfg.hardFreeze
    MP.SendChatMessage(senderID, "CarHunt: hardfreeze " .. (cfg.hardFreeze and "ON" or "OFF"))
  elseif key == "hiders" then
    local n = parseNumber(value)
    if not n then MP.SendChatMessage(senderID, "Usage: /carhunt set hiders <count>") return end
    cfg.hiderCount = math.max(1, n)
    MP.SendChatMessage(senderID, "CarHunt: hider count set to " .. cfg.hiderCount)
  elseif key == "hider" then
    if not value or value == "" then
      MP.SendChatMessage(senderID, "Usage: /carhunt set hider <name1,name2,... | clear>")
      return
    end
    if value == "clear" then
      cfg.forcedHiders = {}
      MP.SendChatMessage(senderID, "CarHunt: forced hiders cleared")
      return
    end

    local list = {}
    for name in string.gmatch(value, "[^,]+") do
      local trimmed = string.gsub(name, "^%s*(.-)%s*$", "%1")
      if trimmed ~= "" then table.insert(list, trimmed) end
    end
    cfg.forcedHiders = list
    MP.SendChatMessage(senderID, "CarHunt: forced hiders set to " .. table.concat(cfg.forcedHiders, ", "))
  else
    MP.SendChatMessage(senderID, "CarHunt: unknown set key.")
  end
end

local function showScoreboard(target)
  MP.SendChatMessage(target, "CarHunt scoreboard:")
  local count = 0
  for playerName, s in pairs(state.stats) do
    count = count + 1
    MP.SendChatMessage(target, string.format("%s | rounds:%d hiderWins:%d seekerWins:%d tags:%d", playerName, s.rounds or 0, s.hiderWins or 0, s.seekerWins or 0, s.tags or 0))
  end
  if count == 0 then
    MP.SendChatMessage(target, "(no rounds played yet)")
  end
end

local function showStatus(target)
  MP.SendChatMessage(target, string.format("CarHunt status: %s | running=%s | hider=%s", tostring(state.status), tostring(state.gameRunning), tostring(state.hider or "n/a")))
  MP.SendChatMessage(target, string.format("headstart=%ds round=%ds tagged=%s idle=%ds", tonumber(state.headStartRemaining or 0), tonumber(state.roundRemaining or 0), tostring(state.hiderTagged), tonumber(state.hiderStationarySeconds or 0)))
  MP.SendChatMessage(target, string.format("vehicle=%s hiderCount=%d forcedHiders=%s", tostring(cfg.hiderVehicle), tonumber(cfg.hiderCount or 1), (#(cfg.forcedHiders or {}) > 0 and table.concat(cfg.forcedHiders, ",") or "none")))
  MP.SendChatMessage(target, string.format("idleexplode=%ds taggrace=%ds hideNameTags=%s hardFreeze=%s catchDistance=%sm autoround=%s autodelay=%ds", tonumber(cfg.hiderIdleExplodeSeconds or 10), tonumber(cfg.tagGraceSeconds or 3), tostring(cfg.hideNameTags), tostring(cfg.hardFreeze), tonumber(cfg.catchDistance or 12), tostring(cfg.autoNextRound), tonumber(cfg.autoNextDelay or 10)))
end

local function showHelp(target)
  MP.SendChatMessage(target, "CarHunt commands:")
  MP.SendChatMessage(target, "/carhunt start [minutes]")
  MP.SendChatMessage(target, "/carhunt stop")
  MP.SendChatMessage(target, "/carhunt reset")
  MP.SendChatMessage(target, "/carhunt toggle")
  MP.SendChatMessage(target, "/carhunt status")
  MP.SendChatMessage(target, "/carhunt scoreboard")
  MP.SendChatMessage(target, "/carhunt set headstart <seconds>")
  MP.SendChatMessage(target, "/carhunt set vehicle <vehicleId>")
  MP.SendChatMessage(target, "/carhunt set hiders <count>")
  MP.SendChatMessage(target, "/carhunt set hider <name1,name2,...|clear>")
  MP.SendChatMessage(target, "/carhunt set idleexplode <seconds>")
  MP.SendChatMessage(target, "/carhunt set taggrace <seconds>")
  MP.SendChatMessage(target, "/carhunt set catchdistance <meters>")
  MP.SendChatMessage(target, "/carhunt set hardfreeze toggle")
  MP.SendChatMessage(target, "/carhunt set autoround <on|off>")
  MP.SendChatMessage(target, "/carhunt set autodelay <seconds>")
end

function onChatMessage(senderID, senderName, message)
  local cmd = message:match("^>/carhunt%s*(.*)$") or message:match("^/carhunt%s*(.*)$")
  if not cmd then return end

  local parts = {}
  for part in cmd:gmatch("%S+") do parts[#parts + 1] = part end
  local action = parts[1]

  if action == "help" or not action then
    showHelp(senderID)
  elseif action == "start" then
    local mins = parseNumber(parts[2])
    startRound(mins and mins * 60 or cfg.roundDuration)
  elseif action == "stop" then
    stopRound()
  elseif action == "reset" then
    resetRound()
  elseif action == "set" then
    local key = parts[2]
    local value = cmd:match("^set%s+%S+%s+(.+)$")
    cmdSet(senderID, key, value)
  elseif action == "toggle" then
    cfg.hideNameTags = not cfg.hideNameTags
    state.settings.hideNameTags = cfg.hideNameTags
    MP.SendChatMessage(-1, "CarHunt: nametags " .. (cfg.hideNameTags and "OFF" or "ON"))
    triggerStateAll()
  elseif action == "scoreboard" then
    showScoreboard(senderID)
  elseif action == "status" then
    showStatus(senderID)
  else
    showHelp(senderID)
  end

  return 1
end

math.randomseed(os.time())
clearRoundState()

MP.RegisterEvent("carhunt_onContact", "onContact")
MP.RegisterEvent("carhunt_requestState", "requestState")
MP.RegisterEvent("carhunt_hiderMotion", "onHiderMotion")
MP.RegisterEvent("carhunt_proximityTag", "onProximityTag")
MP.RegisterEvent("onChatMessage", "onChatMessage")
MP.RegisterEvent("onPlayerJoin", "onPlayerJoin")
MP.RegisterEvent("onPlayerDisconnect", "onPlayerDisconnect")
MP.RegisterEvent("second", "onSecond")
MP.CancelEventTimer("second")
MP.CreateEventTimer("second", 1000)

print("[CarHunt] registering events (" .. BUILD .. ")")
