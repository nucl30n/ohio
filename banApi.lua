-- File: ServerScriptService/Modules/banApi.lua
-- Roblox globals: game, typeof, Enum, task, pcall, error
-- Luau std lib: table.find

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
        },
        ["auto"] = {
            seconds = 0,
            executors = { "Hero", "Admin" }
        }
    }
end)(3600, 24 * 3600)

local function allowedDurations(group)
    local t = {}
    for k in pairs(BanDefs) do
        if table.find(BanDefs[k].executors, group) then
            table.insert(t, k)
        end
    end
    return t
end

local function durationStr(group)
    return "Duration must be one of: " .. table.concat(allowedDurations(group), ", ")
end

local function getSortedBanDurations(group)
    local arr = {}
    for k, def in pairs(BanDefs) do
        if def.seconds > 0 and table.find(def.executors, group) then
            table.insert(arr, def.seconds)
        end
    end
    table.sort(arr)
    return arr
end

local function calculateAutoBan(userId, group)
    local ok, pages = pcall(function()
        return Players:GetBanHistoryAsync(userId)
    end)
    local total = 0
    if ok and pages then
        for _, entry in ipairs(pages:GetCurrentPage()) do
            if entry.Ban and entry.Duration > 0 then
                total = total + entry.Duration
            end
        end
    end
    local sorted = getSortedBanDurations(group)
    local last = nil
    for _, seconds in ipairs(sorted) do
        last = seconds
        if seconds > total then
            return seconds
        end
    end
    return last
end

local function banUser(group, executor, userId, reason, duration)
    duration = duration:lower()
    local def = BanDefs[duration]
    if not Players.BanAsync then
        return false, "Ban API not available"
    elseif not def then
        return false, "Invalid duration: " .. durationStr(group)
    elseif not table.find(def.executors, group) then
        return false, "Unauthorized"
    else
        local banSeconds = def.seconds
        if banSeconds == 0 then
            banSeconds = calculateAutoBan(userId, group)
        end

        Players:BanAsync({
            UserIds = { userId },
            ApplyToUniverse = true,
            Duration = banSeconds,
            DisplayReason = reason,
            PrivateReason = "[API] Issued by " .. executor,
            ExcludeAltAccounts = false
        })

        if typeof(userId) == "Instance" and userId:IsDescendantOf(Players) then
            userId:Kick("You have been banned for " .. duration .. ": " .. reason)
        end

        return true, (typeof(userId) == "Instance" and userId.Name or tostring(userId))
            .. " banned (" .. duration .. "): " .. reason
    end
end

local function getBanTargets()
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
    banUser(
        group,
        "HttpServer",
        player or ban.userId,
        ban.reason or "",
        (ban.duration or ""):lower()
    )
end

local function processHttpBans()
    local success, result = pcall(getBanTargets)
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

function BanApi.fetchBanHistory(userId)
    local ok, result = pcall(function()
        return Players:GetBanHistoryAsync(userId)
    end)
    return ok, result
end

local function getReadableTime(seconds)
    if seconds < 86400 then
        return string.format("%.1fhr", seconds / 3600)
    elseif seconds < 604800 then
        return string.format("%.1fd", seconds / 86400)
    else
        return string.format("%.1fmo", seconds / 2592000)
    end
end


local function getBanSummary(userId)
    local ok, result = BanApi.fetchBanHistory(userId)
    if not ok then return "Failed to retrieve ban history: " .. tostring(result) end

    local totalTime, count, reasons, perm = 0, 0, "", false
    for _, entry in ipairs(result) do
        if entry.Ban then
            count = count + 1
            reasons = reasons .. entry.Reason
            totalTime = totalTime + entry.Duration

            if entry.Duration == -1 then
                perm = true
            end
        end
    end

    if perm then
        return "perm banned with reasons: " .. reasons
    elseif totalTime == 0 then
        return "no bans found for user"
    else
        return "banned " .. count .. " times, total time: " .. getReadableTime(totalTime)
            .. " reasons: " .. reasons
    end
end

local getSafeOutput = function(context, message)
    if context and context.Executor then
        local executor = context.Executor
        if executor and executor:IsA("Player") then
            return message:sub(1, 1000)
        end
    else
        return message
    end
end

local function banCmdDef(group)
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
            local ok, msg = banUser(group, context.Executor.Name, target.UserId, reason, duration)
            return getSafeOutput(context, msg)
        end
    }
end

local function historyCmdDef(group)
    return {
        Name = "history",
        Aliases = {},
        Description = "Get ban history for a user",
        Group = group,
        Args = {
            { Type = "player", Name = "target", Description = "Player to get history for" }
        },
        Run = function(context, target)
            local userId = target.UserId

            return getSafeOutput(context, getBanSummary(userId))
        end
    }
end

function BanApi.getCmdrDef(command, group)
    -- this is meant to be invoked in `ServerScriptService/CmdrCommands/` in dedicated one-liner files for each group
    if not Groups.Defs[group] then
        error("Invalid group: " .. tostring(group))
    elseif command == "ban" then
        return banCmdDef(group)
    elseif command == "history" then
        return historyCmdDef(group)
    else
        error("Invalid command: " .. tostring(command))
    end
end

function BanApi.pollHttpServer()
    -- this is meant to be invoked on the server in `ServerScriptService`
    task.spawn(function()
        while true do
            processHttpBans()
            task.wait(15)
        end
    end)
end

return BanApi
