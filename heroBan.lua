-- ServerScriptService/CmdrCommands/heroBan.lua

local BanUtils = require(game.ServerScriptService.Modules.BanApi)
local group = "Hero"
local cmdDefs = BanUtils.getCmdDefs(group)

cmdDefs.Run = BanUtils.runBanCommand(group)

return cmdDefs
