-- ServerScriptService/Modules/banApi.lua

local Util = {}

local banDurations = {
    Hero = {},
    Admin = {},
    getStr = function(group) end
}

banDurations.Hero = (function(hour)
    return {
        ["6h"] = 6 * hour,
        ["2d"] = 48 * hour,
        ["1w"] = (7 * 24) * hour,
        ["2w"] = (14 * 24) * hour
    }
end)(3600)

banDurations.Admin = (function(Hero, month)
    local t = {}
    for k, v in pairs(Hero) do t[k] = v end
    t["perm"] = -1
    t["3m"] = 3 * month
    t["6m"] = 6 * month
    return t
end)(banDurations.Hero, 30 * 24 * 3600)

banDurations.getStr = function(group)
    local t = {}
    if not banDurations[group] then
        error("Invalid group: " .. tostring(group))
    elseif type(banDurations[group]) ~= "table" then
        for k in pairs(banDurations[group]) do
            table.insert(t, k)
        end
    end
    table.sort(t)
    return "Duration must be one of: " .. table.concat(t, ", ")
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
                { Type = "string", Name = "duration", Description = banDurations.getStr(group) }
            },
            Run = function(context, target, reason, duration, group)
                duration = duration:lower()
                local Players = game:GetService("Players")
                if not Players.BanAsync then return "BanAsync not available" end
                if not banDurations[group][duration] then
                    return "Invalid duration: " .. banDurations.getStr(group)
                else
                    Players:BanAsync({
                        UserIds = { target.UserId },
                        ApplyToUniverse = true,
                        Duration = banDurations[group][duration],
                        DisplayReason = reason,
                        PrivateReason = "[Cmdr] Issued by " .. context.Executor.Name,
                        ExcludeAltAccounts = false
                    })

                    if target and target:IsDescendantOf(Players) then
                        target:Kick("You have been banned for " .. duration .. ": " .. reason)
                    end

                    return target.Name .. " banned (" .. duration .. "): " .. reason
                end
            end
        }
    end
end

return Util
