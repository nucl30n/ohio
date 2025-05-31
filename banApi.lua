-- File: ServerScriptService/Modules/banApi.lua
-- Roblox globals: game, typeof, Enum, task, pcall, error
-- Luau std lib: table.find

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Groups = {
    Defs = {
        Hero = { httpKey = "4b3c5f8d-2e1a-4c0b-9f6d-7e8c9d0e1f2a" },
        Admin = { httpKey = "1a2b3c4d-5e6f-7a8b-9c0d-e1f2a3b4c5d6" },
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
        ["6h"] = { seconds = hour * 6, executors = { "Hero", "Admin" } },
        ["2d"] = { seconds = day * 2, executors = { "Hero", "Admin" } },
        ["7d"] = { seconds = day * 7, executors = { "Hero", "Admin" } },
        ["2w"] = { seconds = day * 14, executors = { "Hero", "Admin" } },
        ["3m"] = { seconds = day * 90, executors = { "Admin" } },
        ["6m"] = { seconds = day * 180, executors = { "Admin" } },
        ["perm"] = { seconds = -1, executors = { "Admin" } },
        ["auto"] = { seconds = 0, executors = { "Hero", "Admin" } }
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
    for _, def in pairs(BanDefs) do
        if def.seconds > 0 and table.find(def.executors, group) then
            table.insert(arr, def.seconds)
        end
    end
    table.sort(arr)
    return arr
end

local function getUserId(target)
    if typeof(target) == "Instance" and target.UserId then
        return target.UserId
    elseif typeof(target) == "number" then
        return target
    elseif typeof(target) == "string" then
        return tonumber(target)
    elseif typeof(target) == "Player" and target.UserId then
        return target.UserId
    else
        return 0
    end
end

local function fetchBanHistory(userId)
    local ok, pages = pcall(function()
        return Players:GetBanHistoryAsync(userId)
    end)
    if not ok or not pages then return ok, {} end

    local history = {}
    local function readPage(page)
        for _, entry in ipairs(page) do
            table.insert(history, entry)
        end
    end

    readPage(pages:GetCurrentPage())
    while not pages.IsFinished do
        local ok2 = pcall(function()
            pages:AdvanceToNextPageAsync()
        end)
        if not ok2 then break end
        readPage(pages:GetCurrentPage())
    end

    return true, history
end

local function calculateAutoBan(userId, group)
    local ok, history = fetchBanHistory(userId)
    local total = 0
    if ok and history then
        for _, entry in ipairs(history) do
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

local function banUser(group, executor, target, reason, duration)
    if not duration or duration == "" then duration = "auto" end
    duration = duration:lower()

    local userId = getUserId(target)
    if not userId then
        return false, "Invalid target: could not determine userId"
    end
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

        local player = Players:GetPlayerByUserId(userId)
        if player then
            player:Kick("You have been banned for " .. duration .. ": " .. reason)
        end

        return true, tostring(userId) .. " banned (" .. duration .. "): " .. reason
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
    banUser(
        group,
        "HttpServer",
        ban.userId,
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
                local ok = pcall(function()
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
    local ok, result = fetchBanHistory(userId)
    if not ok then return "Failed to retrieve ban history: " .. tostring(result) end

    local totalTime, count, perm = 0, 0, false
    local reasonsTbl = {}
    for _, entry in ipairs(result) do
        if entry.Ban then
            count = count + 1
            if entry.Reason and entry.Reason ~= "" then
                table.insert(reasonsTbl, entry.Reason)
            end
            totalTime = totalTime + entry.Duration

            if entry.Duration == -1 then
                perm = true
            end
        end
    end
    local reasons = table.concat(reasonsTbl, ", ")

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
    end
    return message
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
            local ok, msg = banUser(group, context.Executor.Name, target, reason, duration)
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
            local userId = getUserId(target)
            return getSafeOutput(context, getBanSummary(userId))
        end
    }
end

function BanApi.getCmdrDef(command, group)
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
    task.spawn(function()
        while true do
            processHttpBans()
            task.wait(15)
        end
    end)
end

return BanApi
