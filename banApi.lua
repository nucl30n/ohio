-- File: ServerScriptService/Modules/banApi.lua
-- Roblox globals: game, typeof, Enum, task, pcall, error
-- Luau std lib: table.find
-- `BanApi.pollHttpServer` is meant to be invoked on the server in `ServerScriptService`
-- `BanApi.getCmdrDef` is meant to be invoked in `ServerScriptService/CmdrCommands/`

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Groups = {
    Defs = {
        Hero = {
            httpKey = "4b3c5f8d-2e1a-4c0b-9f6d-7e8c9d0e1f2a",
        },
        Admin = {
            httpKey = "1a2b3c4d-5e6f-7a8b-9c0d-e1f2a3b4c5d6",
        }
    },
    Validate = function() end
}

Groups.Validate = function(key)
    for group, def in pairs(Groups.Defs) do
        if def.httpKey == key then
            return group
        end
    end
    return nil
end

local HttpEndpoints = {
    banTargets = "https://api.devv.games/ohio/bantargets",
    confirmBan = "https://api.devv.games/ohio/confirmban"
}

local BanApi = {}

local BanDefs = (function(hour, day)
    return {
        ["6h"] = {
            seconds = 6 * hour,
            executors = { "Hero", "Admin" }
        },
        ["2d"] = {
            seconds = 2 * day,
            executors = { "Hero", "Admin" }
        },
        ["7d"] = {
            seconds = 7 * day,
            executors = { "Hero", "Admin" }
        },
        ["2w"] = {
            seconds = 14 * day,
            executors = { "Hero", "Admin" }
        },
        ["3m"] = {
            seconds = 90 * day,
            executors = { "Admin" }
        },
        ["6m"] = {
            seconds = 180 * day,
            executors = { "Admin" }
        },
        ["perm"] = {
            seconds = -1,
            executors = { "Admin" }
        }
    }
end)(3600, 24 * 3600)

local function getBanDurations(group)
    local t = {}
    for k in pairs(BanDefs) do
        if table.find(BanDefs[k].executors, group) then
            table.insert(t, k)
        end
    end
    return t
end

local function durationStr(group)
    return "Duration must be one of: " .. table.concat(getBanDurations(group), ", ")
end

function BanApi.banUser(group, executor, target, reason, duration)
    duration = duration:lower()
    local def = BanDefs[duration]
    if not Players.BanAsync then
        return false, "Ban API not available"
    elseif not def then
        return false, "Invalid duration: " .. durationStr(group)
    elseif not table.find(def.executors, group) then
        return false, "Group '" .. group .. "' cannot use duration '" .. duration .. "'"
    else
        local userId
        if typeof(target) == "Instance" and target.UserId then
            userId = target.UserId
        else
            userId = tonumber(target)
        end

        if not userId then
            return false, "Target must be a player object or userId"
        end

        Players:BanAsync({
            UserIds = { userId },
            ApplyToUniverse = true,
            Duration = def.seconds,
            DisplayReason = reason,
            PrivateReason = "[API] Issued by " .. executor,
            ExcludeAltAccounts = false
        })

        if typeof(target) == "Instance" and target:IsDescendantOf(Players) then
            target:Kick("You have been banned for " .. duration .. ": " .. reason)
        end

        return true, (typeof(target) == "Instance" and target.Name or tostring(userId))
            .. " banned (" .. duration .. "): " .. reason
    end
end

function BanApi.getCmdrDef(group)
    if not Groups.Defs[group] then
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
                { Type = "string", Name = "duration", Description = durationStr(group) }
            },
            Run = function(context, target, reason, duration)
                local ok, msg = BanApi.banUser(group, context.Executor.Name, target, reason, duration)
                return msg
            end
        }
    end
end

function BanApi.getBanTargets()
    return HttpService:JSONDecode(HttpService:GetAsync(HttpEndpoints.banTargets))
end

local function confirmHttpBan(userId)
    local payload = HttpService:JSONEncode({ userId = userId })
    HttpService:PostAsync(
        HttpEndpoints.confirmBan,
        payload,
        Enum.HttpContentType.ApplicationJson
    )
end

local function executeHttpBan(group, ban)
    local player = Players:GetPlayerByUserId(ban.userId)
    BanApi.banUser(
        group,
        "HttpServer",
        player or ban.userId,
        ban.reason or "",
        (ban.duration or ""):lower()
    )
end

local function processHttpBans()
    local success, result = pcall(BanApi.getBanTargets)
    if success and type(result.bans) == "table" then
        for _, ban in ipairs(result.bans) do
            local group = Groups.Validate(ban.httpKey)
            if group and ban.userId and ban.duration then
                local ok, err = pcall(function()
                    executeHttpBan(group, ban)
                end)
                if ok then
                    pcall(function()
                        confirmHttpBan(ban.userId)
                    end)
                end
            end
        end
    end
end

function BanApi.pollHttpServer()
    task.spawn(function()
        while true do
            processHttpBans()
            task.wait(15)
        end
    end)
end

return BanApi
