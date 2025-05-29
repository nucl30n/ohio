-- ServerScriptService/CmdrCommands/adminBan.lua

local BanUtils = require(game.ServerScriptService.Modules.BanApi)
local group = "Admin"
local cmdDefs = BanUtils.getCmdDefs(group)

cmdDefs.Run = BanUtils.runBanCommand(group)

return cmdDefs
