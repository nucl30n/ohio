-- ServerScriptService/Modules/banApi.lua

local Util = {}

Util.Hero = (function(hour)
    return {
        ["6h"] = 6 * hour,
        ["2d"] = 48 * hour,
        ["1w"] = (7 * 24) * hour,
        ["2w"] = (14 * 24) * hour
    }
end)(3600)

Util.Admin = (function(Hero, month)
    local t = {}
    for k, v in pairs(Hero) do t[k] = v end
    t["perm"] = -1
    t["3m"] = 3 * month
    t["6m"] = 6 * month
    return t
end)(Util.Hero, 30 * 24 * 3600)

function Util.getStr(group)
    local t = {}
    for k in pairs(Util[group]) do
        table.insert(t, k)
    end
    table.sort(t)
    return "Duration must be one of: " .. table.concat(t, ", ")
end

function Util.getBanCmd(executor, target, dval, reason)
    return {
        UserIds = { target.UserId },
        ApplyToUniverse = true,
        Duration = dval,
        DisplayReason = reason,
        PrivateReason = "[Cmdr] Issued by " .. executor,
        ExcludeAltAccounts = false
    }
end

function Util.getFinalMsg(target, reason, duration)
    return target.Name .. " banned (" .. duration .. "): " .. reason
end

function Util.getKickMsg(reason, duration)
    return "You have been banned for " .. duration .. ": " .. reason
end

function Util.getCmdDefs(group)
    if not Util[group] then
        error("Invalid group: " .. tostring(group))
    else
        return {
            Name = "ban",
            Aliases = {},
            Description = "Ban API command",
            Group = group,
            Args = {
                { Type = "player", Name = "target",   Description = "Player to ban" },
                { Type = "string", Name = "reason",   Description = "Reason for ban" },
                { Type = "string", Name = "duration", Description = getStr(group) }
            }
        }
    end
end

function Util.runBanCommand(group)
    return function(context, target, reason, duration)
        duration = duration:lower()
        local Players = game:GetService("Players")
        if not Players.BanAsync then return "BanAsync not available" end
        if not Util[group][duration] then
            return "Invalid duration: " .. Util.getStr(group)
        end

        Players:BanAsync(Util.getBanCmd(
            context.Executor.Name,
            target,
            Util[group][duration],
            reason
        ))

        if target and target:IsDescendantOf(Players) then
            target:Kick(Util.getKickMsg(reason, duration))
        end

        return Util.getFinalMsg(target, reason, duration)
    end
end

return Util
