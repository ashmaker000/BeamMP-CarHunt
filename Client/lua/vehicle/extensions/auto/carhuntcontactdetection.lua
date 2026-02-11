local M = {}
local core = core

local function makeChecker(vehicle)
  local vehicleID = vehicle:getId()
  local carLength = vehicle:getInitialLength()

  return function()
    if not mapmgr then return end

    for _, remoteID in pairs(mapmgr.objectCollisionIds or {}) do
      if remoteID ~= vehicleID then
        local otherLength = vehicle:getObjectInitialLength(remoteID)
        if otherLength then
          local distance = vehicle:getCenterPosition():distance(vehicle:getObjectCenterPosition(remoteID))
          if distance < ((otherLength + carLength) / 2) * 1.1 then
            vehicle:queueGameEngineLua("if carhunt then carhunt.sendContact(" .. remoteID .. "," .. vehicleID .. ") end")
          end
        end
      end
    end
  end
end

local function onInit()
  local vehicle = obj
  if not vehicle then return end
  core.onFixedUpdate(makeChecker(vehicle))
end

M.onInit = onInit
return M
