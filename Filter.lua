-- Filter.lua: decides whether a chat message is hidden, installs the chat
-- filter, and keeps the in-memory log of what was hidden.

local _, ns = ...
local L = ns.L
local IsSecret = ns.IsSecret

local CHAT_EVENTS = {
    "CHAT_MSG_SAY",
    "CHAT_MSG_YELL",
    "CHAT_MSG_EMOTE",
    "CHAT_MSG_TEXT_EMOTE",
    "CHAT_MSG_WHISPER",
    "CHAT_MSG_CHANNEL",
    "CHAT_MSG_GUILD",
    "CHAT_MSG_OFFICER",
    "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID",
    "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_INSTANCE_CHAT",
    "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_AFK",
    "CHAT_MSG_DND",
    "CHAT_MSG_COMMUNITIES_CHANNEL",
}

-- Set of the events above: chat that comes from other players.
ns.INCOMING_EVENTS = {}
for _, event in ipairs(CHAT_EVENTS) do
    ns.INCOMING_EVENTS[event] = true
end

-- Messages from Blizzard staff are never hidden by the name filter.
local STAFF_FLAGS = { GM = true, DEV = true }

ns.sessionHidden = 0

---------------------------------------------------------------------------
-- Muted-messages log: the last 50 hidden messages from the last 15 minutes.
-- Memory only: never saved, cleared by /reload or logout.
---------------------------------------------------------------------------
local LOG_MAX, LOG_AGE = 50, 15 * 60
local mutedLog, logHead = {}, 0

local function LogMuted(event, msg, author, lineID, guid)
    if type(msg) ~= "string" or type(author) ~= "string" then
        return
    end
    logHead = logHead % LOG_MAX + 1
    -- A new table each time, so an open window keeps its message.
    mutedLog[logHead] = {
        t = GetTime(),
        clock = date("%H:%M"),
        event = event,
        text = msg,
        author = author,
        lineID = (type(lineID) == "number" and lineID > 0) and lineID or nil,
        guid = guid,
    }
end

-- Newest first, dropping anything older than LOG_AGE.
function ns.LogEntries()
    local list, now = {}, GetTime()
    for i, entry in pairs(mutedLog) do
        if now - entry.t <= LOG_AGE then
            list[#list + 1] = entry
        else
            mutedLog[i] = nil
        end
    end
    table.sort(list, function(a, b)
        return a.t > b.t
    end)
    return list
end

function ns.ClearLog()
    wipe(mutedLog)
    logHead = 0
end

---------------------------------------------------------------------------
-- The decision
---------------------------------------------------------------------------

-- You, staff and the never-mute list are exempt from the name filter.
local function FilterExempt(key, guid, flag)
    if flag and STAFF_FLAGS[flag] then
        return true
    end
    if guid and guid == ns.playerGUID then
        return true
    end
    return key ~= nil and (key == ns.playerKey or ns.db.allow[key] == true)
end

-- Name keywords: hide chat from any player whose character name contains one.
local function NameWordBlocked(author)
    local list = ns.db.nameWords
    if #list == 0 or type(author) ~= "string" then
        return false
    end
    local name = author:match("^[^%-]+")
    if not name then
        return false
    end
    name = name:lower()
    for i = 1, #list do
        if name:find(list[i], 1, true) then
            return true
        end
    end
    return false
end

-- Returns why the message is hidden, or false.
local function Decide(author, guid, flag)
    local db = ns.db
    local key = ns.Normalize(author)
    local guidKey = guid and db.guids[guid]
    if (key and db.passes[key]) or (guidKey and db.passes[guidKey]) then
        return false -- unmuted while grouped
    end
    if guid ~= ns.playerGUID and guidKey and db.players[guidKey] ~= nil and not db.allow[guidKey] then
        return L["muted player <%s>"]:format(ns.TagText(db.players[guidKey]))
    end
    if key and key ~= ns.playerKey and db.players[key] ~= nil and not db.allow[key] then
        return L["muted player <%s>"]:format(ns.TagText(db.players[key]))
    end
    if FilterExempt(key, guid, flag) then
        return false
    end
    return NameWordBlocked(author) and L["name keyword"]
end

-- Should this message be hidden? Returns the reason (or false), and whether
-- the answer is reliable. An error counts as "don't hide" and as unreliable,
-- so the result isn't cached.
function ns.Evaluate(author, guid, flag)
    local ok, reason = pcall(Decide, author, guid, flag)
    return ok and reason or false, ok
end

---------------------------------------------------------------------------
-- The chat filter
---------------------------------------------------------------------------

-- The game runs the filter once per chat window that shows a message. The
-- decision depends only on these inputs plus ns.gen, so the last one is
-- remembered and the second, third... window reuses it.
local cache = { valid = false }
local lastHiddenLine, lastHiddenEvent

-- A message was matched. Handled once per line, not once per chat window:
-- reported in the debug modes, and counted and logged unless this is a dry run.
local function OnHit(reason, event, msg, author, lineID, guid)
    local usable = lineID ~= nil and not IsSecret(lineID)
    if usable and lineID == lastHiddenLine and event == lastHiddenEvent then
        return
    end
    lastHiddenLine, lastHiddenEvent = usable and lineID or nil, usable and event or nil
    local msgUsable = not IsSecret(msg)
    ns.Debug(
        L["%s a %s message from %s (%s): %s"],
        ns.Did(L["hid"], L["would hide"]),
        event:gsub("^CHAT_MSG_", ""):lower(),
        author,
        reason,
        msgUsable and msg or L["(unreadable text)"]
    )
    if ns.IsDryRun() then
        return
    end
    ns.sessionHidden = ns.sessionHidden + 1
    ns.db.hiddenTotal = ns.db.hiddenTotal + 1
    if msgUsable then
        pcall(LogMuted, event, msg, author, usable and lineID or nil, guid)
    end
    if ns.RefreshStats then
        ns.RefreshStats()
    end
end

-- Filter arguments after the event: msg, author, then flag in position 6,
-- lineID in 11 and guid in 12.
local function Filter(_, event, msg, author, _, _, _, flag, _, _, _, _, lineID, guid)
    local db = ns.db
    if not db or not db.enabled then
        return false
    end
    if IsSecret(author) or IsSecret(guid) then
        return false
    end
    if IsSecret(flag) or type(flag) ~= "string" then
        flag = nil
    end

    local hit
    local msgUsable = not IsSecret(msg)
    if
        msgUsable
        and cache.valid
        and cache.gen == ns.gen
        and cache.event == event
        and cache.msg == msg
        and cache.author == author
        and cache.guid == guid
        and cache.flag == flag
    then
        hit = cache.hit
    else
        local reliable
        hit, reliable = ns.Evaluate(author, guid, flag)
        cache.valid = reliable and msgUsable
        cache.gen, cache.event, cache.flag = ns.gen, event, flag
        cache.msg, cache.author, cache.guid, cache.hit = msg, author, guid, hit
    end

    if hit then
        OnHit(hit, event, msg, author, lineID, guid)
        return not ns.IsDryRun()
    end
    return false
end

-- Which of the two names this client has is not confirmed yet; the reference
-- addon checks both.
local AddFilter = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
for _, event in ipairs(CHAT_EVENTS) do
    AddFilter(event, Filter)
end
