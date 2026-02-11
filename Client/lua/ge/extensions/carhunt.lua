local M = {}
local MPVehicleGE = MPVehicleGE
local MPConfig = MPConfig
local core_input_actionFilter = core_input_actionFilter
local color = color

local ffiFound = false
if ffi and ffi.C then
  ffiFound = true
end
local drawTextAdvanced = ffiFound and ffi.C.BNG_DBG_DRAW_TextAdvanced or nop

local localName = MPConfig and MPConfig.getNickname and MPConfig.getNickname() or nil
local overlayDebugShown = false
local gameState = {
  status = "idle",
  gameRunning = false,
  seekersFrozen = false,
  headStartRemaining = 0,
  roundRemaining = 0,
  hider = nil,
  hiders = {},
  taggedHider = nil,
  hiderVehicle = nil,
  hiderConfig = nil,
  settings = {},
  players = {}
}

local freezeActions = {
  "accelerate", "brake", "throttle", "throttle_axis", "brake_axis",
  "steer", "steer_left", "steer_right", "steering", "steering_axis",
  "handbrake", "parkingbrake", "clutch",
  "shiftUp", "shiftDown", "gearUp", "gearDown", "toggleShifterMode",
  "recover_vehicle", "recover_vehicle_alt", "reset_physics", "reset_all_physics",
  "dropPlayerAtCamera", "dropPlayerAtCameraNoReset", "loadHome", "saveHome"
}
local softFreezeActions = { "accelerate", "brake", "recover_vehicle", "recover_vehicle_alt", "reset_physics", "dropPlayerAtCamera", "dropPlayerAtCameraNoReset" }
local hiderResetActions = { "recover_vehicle", "recover_vehicle_alt", "reset_physics", "reset_all_physics", "dropPlayerAtCamera", "dropPlayerAtCameraNoReset", "loadHome", "saveHome" }
local freezeActive = false
local freezeHardActive = true
local hiderResetLockActive = false

local function setFreeze(state, hard)
  if not core_input_actionFilter then return end
  local useHard = hard and true or false
  if freezeActive == state and freezeHardActive == useHard then return end
  local actions = useHard and freezeActions or softFreezeActions
  core_input_actionFilter.setGroup("carhunt_freeze", actions)
  core_input_actionFilter.addAction(0, "carhunt_freeze", state)
  freezeActive = state
  freezeHardActive = useHard
end

local function setNametagVisibility(show)
  if MPVehicleGE and MPVehicleGE.hideNicknames then
    MPVehicleGE.hideNicknames(not show)
  end
end

local function setHiderResetLock(state)
  if not core_input_actionFilter then return end
  if hiderResetLockActive == state then return end
  core_input_actionFilter.setGroup("carhunt_hider_noreset", hiderResetActions)
  core_input_actionFilter.addAction(0, "carhunt_hider_noreset", state)
  hiderResetLockActive = state
end

local hunterTextColor = color(255, 220, 0, 255)
local hunterBackColor = color(20, 20, 20, 160)
local hiderTextColor = color(255, 80, 80, 255)
local hiderBackColor = color(20, 20, 20, 160)

local forceLocalVehicle
local pendingForce = nil
local lastForceToastAt = 0

local vehTagPos = vec3()
local myVehPos = vec3()
local hiderVehPos = vec3()
local labelDrawErrorShown = false

local function drawRoleTag(vehicle, text, txtColor, backColor)
  vehTagPos:set(be:getObjectOOBBCenterXYZ(vehicle.gameVehicleID))
  local vehicleHeight = 0

  if not vehicle.vehicleHeight or vehicle.vehicleHeight == 0 then
    local objVeh = getObjectByID(vehicle.gameVehicleID)
    if objVeh and objVeh.getInitialHeight then
      vehicleHeight = objVeh:getInitialHeight()
      vehicle.vehicleHeight = vehicleHeight
    end
  else
    vehicleHeight = vehicle.vehicleHeight
  end

  vehTagPos.z = vehTagPos.z + (vehicleHeight * 0.5) + 0.2

  local ok = pcall(function()
    drawTextAdvanced(vehTagPos.x, vehTagPos.y, vehTagPos.z, String(" " .. text .. " "), txtColor, true, false, backColor, false, false)
  end)

  if not ok and not labelDrawErrorShown then
    labelDrawErrorShown = true
    guihooks.message({ txt = "CarHunt: label draw failed (API mismatch)" }, 4, "info")
  end
end

local function getFocusedOwnerName()
  local name = (MPConfig and MPConfig.getNickname and MPConfig.getNickname()) or localName
  local curVehID = be:getPlayerVehicleID(0)
  if curVehID and MPVehicleGE and MPVehicleGE.getVehicleByGameID then
    local curVeh = MPVehicleGE.getVehicleByGameID(curVehID)
    if curVeh and curVeh.ownerName then
      name = curVeh.ownerName
    end
  end
  return name
end

local function isHiderName(name)
  if not name then return false end
  if gameState.hiders and gameState.hiders[name] then return true end
  return gameState.hider == name
end

local function drawRoleLabels()
  if (gameState.status ~= "hunt" and gameState.status ~= "headstart") or not MPVehicleGE then return end

  local focusedOwner = getFocusedOwnerName()
  if not focusedOwner then return end

  local isHider = isHiderName(focusedOwner)

  if not overlayDebugShown then
    overlayDebugShown = true
    guihooks.message({ txt = "CarHunt: role overlay active" }, 4, "info")
  end

  for _, veh in pairs(MPVehicleGE.getVehicles() or {}) do
    if veh.ownerName and veh.ownerName ~= focusedOwner then
      if isHider then
        if isHiderName(veh.ownerName) then
          drawRoleTag(veh, "HIDER", hiderTextColor, hiderBackColor)
        else
          drawRoleTag(veh, "HUNTER", hunterTextColor, hunterBackColor)
        end
      elseif isHiderName(veh.ownerName) then
        drawRoleTag(veh, "HIDER", hiderTextColor, hiderBackColor)
      end
    end
  end
end

local forcedThisRound = false
local explodedThisRound = false
local nextMotionReportAt = 0
local nextProximityCheckAt = 0

local function formatTimer(totalSeconds)
  local secs = math.max(0, math.floor(tonumber(totalSeconds) or 0))
  local minutes = math.floor(secs / 60)
  local rem = secs % 60
  return string.format("%02d:%02d", minutes, rem)
end

local function applyGameState(state)
  gameState = state or gameState
  localName = MPConfig and MPConfig.getNickname and MPConfig.getNickname() or localName

  local isHider = isHiderName(localName)
  local seekersFrozen = gameState.seekersFrozen and not isHider
  local hardFreeze = not (gameState.settings and gameState.settings.hardFreeze == false)
  setFreeze(seekersFrozen, hardFreeze)

  local roundActive = gameState.status == "headstart" or gameState.status == "hunt"
  setHiderResetLock(isHider and roundActive)

  if isHider and gameState.status == "headstart" and not forcedThisRound and gameState.hiderVehicle then
    forceLocalVehicle(gameState.hiderVehicle, gameState.hiderConfig)
    forcedThisRound = true
  elseif gameState.status == "idle" or gameState.status == "ended" then
    forcedThisRound = false
    explodedThisRound = false
    overlayDebugShown = false
  end

  local hideNameTags = gameState.settings and gameState.settings.hideNameTags
  setNametagVisibility(not hideNameTags)

  local timerText = nil
  if gameState.status == "headstart" then
    timerText = string.format("CarHunt: head start %s", formatTimer(gameState.headStartRemaining or 0))
  elseif gameState.status == "hunt" then
    timerText = string.format("CarHunt: hunt live %s", formatTimer(gameState.roundRemaining or 0))
  elseif gameState.status == "ended" then
    timerText = "CarHunt: round ended"
  end
  if timerText then
    guihooks.message({ txt = timerText }, 1.5, "info")
  end
end

local function decodeState(data)
  if type(data) == "table" then return data end
  local ok, parsed = pcall(jsonDecode, data)
  if ok then return parsed end
  return nil
end

function M.updateGameState(data)
  local parsed = decodeState(data)
  if parsed then applyGameState(parsed) end
end

function M.sendContact(remoteVehID, localVehID)
  if not MPVehicleGE then return end
  local serverVehID = MPVehicleGE.getServerVehicleID(remoteVehID)
  local remotePlayerID = tonumber(string.match(serverVehID or "", "(%d+)-%d+"))
  if not remotePlayerID then return end
  if TriggerServerEvent then
    TriggerServerEvent("carhunt_onContact", tostring(remotePlayerID))
  end
end

forceLocalVehicle = function(vehicle, config)
  local ok = false

  if core_vehicles and core_vehicles.replaceVehicle then
    ok = pcall(function()
      core_vehicles.replaceVehicle(vehicle, { config = config })
    end)
  end

  if not ok and core_vehicles and core_vehicles.replaceVehicle then
    ok = pcall(function()
      core_vehicles.replaceVehicle(vehicle)
    end)
  end

  if not ok then
    pendingForce = {
      vehicle = vehicle,
      config = config,
      triesLeft = 8,
      nextTryAt = (os.clock and os.clock() or 0) + 0.5
    }

    local now = os.clock and os.clock() or 0
    if now - lastForceToastAt > 3 then
      guihooks.message({ txt = string.format("CarHunt: could not auto-force yet, retrying %s (%s)", tostring(vehicle), tostring(config)) }, 6, "carhunt.force")
      lastForceToastAt = now
    end
  else
    pendingForce = nil
  end
end

local function onForceHiderVehicle(targetName, vehicle, config)
  if not MPConfig or MPConfig.getNickname() ~= targetName then return end
  forceLocalVehicle(vehicle, config)
end

local function onResetState()
  forcedThisRound = false
  setFreeze(false, false)
  setHiderResetLock(false)
  local hideNameTags = gameState.settings and gameState.settings.hideNameTags
  setNametagVisibility(not hideNameTags)
end

local function onSetFreeze(flag)
  local shouldFreeze = tostring(flag) == "1" or flag == true
  local hardFreeze = not (gameState.settings and gameState.settings.hardFreeze == false)
  setFreeze(shouldFreeze, hardFreeze)
end

local function onExplodeHider(targetName)
  local nick = (MPConfig and MPConfig.getNickname and MPConfig.getNickname()) or localName
  local target = tostring(targetName or "")
  local isMe = (target ~= "" and string.lower(target) == string.lower(tostring(nick or ""))) or (gameState.taggedHider and tostring(gameState.taggedHider) == tostring(nick))
  if not isMe then return end

  local vehID = be:getPlayerVehicleID(0)
  local veh = vehID and getObjectByID(vehID) or nil
  if not veh then return end

  pcall(function()
    veh:queueLuaCommand([[if fire and fire.explodeVehicle then pcall(fire.explodeVehicle) end
      if fire and fire.igniteVehicle then pcall(fire.igniteVehicle) end
      if beamstate and beamstate.breakAllBreakgroups then pcall(beamstate.breakAllBreakgroups) end
      if electrics and electrics.values then electrics.values.ignitionLevel = 0 end]])
  end)

  explodedThisRound = true
  guihooks.message({ txt = "CarHunt: BOOM (hider immobilized)" }, 4, "carhunt.boom")
end

local function requestState()
  if TriggerServerEvent then TriggerServerEvent("carhunt_requestState", "nil") end
end

local function reportHiderMotion(now)
  if not TriggerServerEvent then return end
  if gameState.status ~= "hunt" or not gameState.hiderTagged or localName ~= gameState.taggedHider then return end
  if now < nextMotionReportAt then return end

  local moving = false
  local vehID = be:getPlayerVehicleID(0)
  local veh = vehID and getObjectByID(vehID) or nil
  if veh and veh.getVelocity then
    local vel = veh:getVelocity()
    local speed = vel and vel:length() or 0
    moving = speed > 1.0
  end

  TriggerServerEvent("carhunt_hiderMotion", moving and "1" or "0")
  nextMotionReportAt = now + 1.0
end

local function reportProximityTag(now)
  if not TriggerServerEvent then return end
  if gameState.status ~= "hunt" then return end
  if now < nextProximityCheckAt then return end

  local viewer = getFocusedOwnerName()
  if not viewer or isHiderName(viewer) then
    nextProximityCheckAt = now + 0.5
    return
  end

  local myVehID = be:getPlayerVehicleID(0)
  if not myVehID then
    nextProximityCheckAt = now + 0.5
    return
  end
  myVehPos:set(be:getObjectOOBBCenterXYZ(myVehID))

  local nearestHiderName = nil
  local nearestDistSq = nil

  for _, veh in pairs(MPVehicleGE.getVehicles() or {}) do
    if isHiderName(veh.ownerName) then
      hiderVehPos:set(be:getObjectOOBBCenterXYZ(veh.gameVehicleID))
      local d = myVehPos:squaredDistance(hiderVehPos)
      if not nearestDistSq or d < nearestDistSq then
        nearestDistSq = d
        nearestHiderName = veh.ownerName
      end
    end
  end

  local catchDistance = tonumber(gameState.settings and gameState.settings.catchDistance) or 12
  if nearestHiderName and nearestDistSq and nearestDistSq <= (catchDistance * catchDistance) then
    TriggerServerEvent("carhunt_proximityTag", tostring(nearestHiderName))
  end

  nextProximityCheckAt = now + 0.5
end

local function onUpdate()
  local now = os.clock and os.clock() or 0
  drawRoleLabels()
  reportHiderMotion(now)
  reportProximityTag(now)

  if not explodedThisRound and gameState.status == "hunt" then
    local nick = (MPConfig and MPConfig.getNickname and MPConfig.getNickname()) or localName
    local threshold = tonumber(gameState.settings and gameState.settings.hiderIdleExplodeSeconds) or 10
    if gameState.taggedHider and tostring(gameState.taggedHider) == tostring(nick) and tonumber(gameState.hiderStationarySeconds or 0) >= threshold then
      onExplodeHider(nick)
    end
  end

  if not pendingForce then return end
  if now < (pendingForce.nextTryAt or 0) then return end

  local vehicle = pendingForce.vehicle
  local config = pendingForce.config

  local ok = false
  if core_vehicles and core_vehicles.replaceVehicle then
    ok = pcall(function()
      core_vehicles.replaceVehicle(vehicle, { config = config })
    end)
  end

  if ok then
    pendingForce = nil
    return
  end

  pendingForce.triesLeft = (pendingForce.triesLeft or 0) - 1
  if pendingForce.triesLeft <= 0 then
    pendingForce = nil
    return
  end

  pendingForce.nextTryAt = now + 0.75
end

local function onPreRender()
  drawRoleLabels()
end

local function handleUpdateState(data) M.updateGameState(data) end
local function handleForceHiderVehicle(targetName, vehicle, config) onForceHiderVehicle(targetName, vehicle, config) end
local function handleResetState() onResetState() end
local function handleSetFreeze(flag) onSetFreeze(flag) end
local function handleExplodeHider(targetName) onExplodeHider(targetName) end

local function ensureContactDetectorLoaded(vehID)
  local veh = vehID and getObjectByID(vehID) or nil
  if veh then
    veh:queueLuaCommand('extensions.load("auto/carhuntcontactdetection")')
  end
end

local function onVehicleSpawned(vehID)
  if MPVehicleGE and MPVehicleGE.isOwn and MPVehicleGE.isOwn(vehID) then
    ensureContactDetectorLoaded(vehID)
  end
end

local function onVehicleSwitched(oldID, newID)
  if newID then
    ensureContactDetectorLoaded(newID)
  end
end

local function onInit()
  AddEventHandler("carhunt_updateGameState", handleUpdateState)
  AddEventHandler("carhunt_forceHiderVehicle", handleForceHiderVehicle)
  AddEventHandler("carhunt_resetState", handleResetState)
  AddEventHandler("carhunt_setFreeze", handleSetFreeze)
  AddEventHandler("carhunt_explodeHider", handleExplodeHider)

  AddEventHandler("onPreRender", "carhunt_preRender", onPreRender)
  AddEventHandler("onUpdate", "carhunt_updateTick", onUpdate)

  local currentVeh = be:getPlayerVehicleID(0)
  if currentVeh then ensureContactDetectorLoaded(currentVeh) end

  requestState()
  guihooks.message({ txt = "CarHunt client loaded (multihider hotfix13)" }, 4, "info")
  log("I", "CarHunt", "Client extension initialized (multihider hotfix13)")
end

M.onInit = onInit
M.onPreRender = onPreRender
M.onUpdate = onUpdate
M.onVehicleSpawned = onVehicleSpawned
M.onVehicleSwitched = onVehicleSwitched
return M
