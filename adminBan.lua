-- ServerScriptService/CmdrCommands/adminBan.lua

cmdDefs.Run = function(context, target, reason, duration)
    duration = duration:lower()
    local Players = game:GetService("Players")
    if not Players.BanAsync then return "BanAsync not available" end
    if not BanUtils[context.Group][duration] then
        return "Invalid duration: " .. BanUtils.getStr(context.Group)
    else
        Players:BanAsync(BanUtils.getBanCmd(context.Executor.Name, target, BanUtils[context.Group][duration], reason))
    end

    if target and target:IsDescendantOf(Players) then
        target:Kick(BanUtils.getKickMsg(reason, duration))
    end

    return BanUtils.getFinalMsg(target, reason, duration)
end
