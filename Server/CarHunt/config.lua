local M = {}

M.defaults = {
  roundDuration = 5 * 60,
  headStart = 45,
  hiderVehicle = "pigeon",
  hiderConfig = "vehicles/pigeon/offroad_4w.pc",
  hiderCount = 1,
  forcedHiders = {},
  catchDistance = 12,
  hiderIdleExplodeSeconds = 10,
  tagGraceSeconds = 3,
  hideNameTags = false,
  hardFreeze = true,
  autoNextRound = false,
  autoNextDelay = 10
}

return M
