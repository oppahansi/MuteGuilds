-- Learn.lua: finds out which guild players are in.
-- Chat events don't carry the sender's guild, so guilds are learned from the
-- players the game shows you (target, mouseover, nameplates, group) and from
-- /who results.

local _, ns = ...
local IsSecret = ns.IsSecret

---------------------------------------------------------------------------
-- Units
---------------------------------------------------------------------------
local nameChecked = {} -- guid -> true once its saved key was compared with the game's name

local function ScanUnit(unit)
    if not UnitExists(unit) or not UnitIsPlayer(unit) or UnitIsUnit(unit, "player") then
        return
    end
    local guid = UnitGUID(unit)
    local guild = GetGuildInfo(unit)
    if IsSecret(guid) or IsSecret(guild) then
        return
    end
    local db = ns.db
    -- Already muted, name already checked this session, still in the same
    -- guild: nothing new to learn (nameplates and mouseover fire constantly).
    local known = guid and db.guids[guid]
    if known and nameChecked[guid] and guild and db.players[known] == guild and not ns.IsInvitePending(known) then
        ns.NoteLevel(UnitLevel(unit))
        return
    end
    local name = ns.UnitNameString(unit)
    if not name then
        return -- name not loaded yet
    end
    if known then
        ns.Rekey(known, ns.Normalize(name)) -- renamed since they were saved
        nameChecked[guid] = true
    end

    if ns.IsMutedGuild(guild) then
        ns.NoteLevel(UnitLevel(unit))
        ns.Block(guid, name, guild)
        if guid and db.guids[guid] then
            nameChecked[guid] = true
        end
    elseif guild then
        ns.Unblock(guid, name) -- they're in a different guild now
    end
    -- A blank guild isn't proof they left: guild info can still be loading.
end

function ns.ScanUnit(unit)
    pcall(ScanUnit, unit)
end

-- List key for a unit, or nil.
function ns.UnitKey(unit)
    local guid = UnitGUID(unit)
    local key = guid and not IsSecret(guid) and ns.db.guids[guid]
    return key or ns.Normalize(ns.UnitNameString(unit))
end

function ns.ScanGroup()
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            ns.ScanUnit("raid" .. i)
        end
    else
        for i = 1, 4 do
            ns.ScanUnit("party" .. i)
        end
    end
end

-- Keys of everyone currently in your group (not you) -> their unit.
function ns.GroupKeys()
    local present = {}
    if not IsInGroup() then
        return present
    end
    local prefix, count = "party", 4
    if IsInRaid() then
        prefix, count = "raid", GetNumGroupMembers()
    end
    for i = 1, count do
        local unit = prefix .. i
        if UnitExists(unit) and UnitIsPlayer(unit) and not UnitIsUnit(unit, "player") then
            local key = ns.UnitKey(unit)
            if key then
                present[key] = unit
            end
        end
    end
    return present
end

---------------------------------------------------------------------------
-- /who
---------------------------------------------------------------------------

-- Results shown in the Who window.
function ns.ScanWhoList()
    for i = 1, C_FriendList.GetNumWhoResults() do
        local info = C_FriendList.GetWhoInfo(i)
        if info and ns.IsMutedGuild(info.fullGuildName) then
            ns.NoteLevel(info.level)
            ns.Block(nil, info.fullName, info.fullGuildName)
        elseif info and info.fullName then
            ns.UnblockFormer(info.fullName, info.fullGuildName)
        end
    end
end

-- A small /who result is printed as a line instead of opening the Who window:
--   [Name]: Level 20 Human Warrior <Guild Name> - Zone
-- Takes the line from its player link on. Returns true if it had that shape.
local function ParseWhoBody(body)
    local name, rest = body:match("^|Hplayer:([^:|]+)|h%[[^%]]*%]|h: (.*)$")
    if not name then
        return false
    end
    local guild = rest:match("<([^<>]+)>")
    if ns.IsMutedGuild(guild) then
        ns.NoteLevel(rest:match("(%d+)"))
        ns.Block(nil, name, guild)
    else
        ns.UnblockFormer(name, guild) -- /who shows a different guild, or none
    end
    return true
end

---------------------------------------------------------------------------
-- Lines added to the chat windows
-- On this client a /who result line is written straight to the chat window,
-- with no CHAT_MSG_SYSTEM event, so the windows themselves are watched.
---------------------------------------------------------------------------

-- Runs for every line added to a chat window, so ordinary lines are rejected fast.
local function OnChatLine(msg)
    if type(msg) ~= "string" or IsSecret(msg) then
        return
    end
    ns.CheckWhoThrottle(msg)
    -- Everything else of interest starts with a player link, maybe after a
    -- color code and/or a timestamp ("07:15 ", "[7:15 PM] "). Guild, party and
    -- channel lines start with a channel link, so they are rejected here.
    local at = msg:find("|H", 1, true)
    if not at or msg:find("|Hplayer:", at, true) ~= at then
        return
    end
    if at > 1 then
        local before = msg:sub(1, at - 1):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        if #before > 16 or not before:find("^[%d:%.%s%[%]APMapm]*$") then
            return
        end
    end
    local body = msg:sub(at)
    -- /who and invite lines use a bare link (|Hplayer:Name|h). Links on real
    -- chat lines carry ":lineID:CHANNEL" and never match, so a player can't get
    -- someone muted by typing text that looks like a /who result.
    if not body:find("^|Hplayer:[^:|]+|h") then
        return
    end
    local ok, isWho = pcall(ParseWhoBody, body)
    if not (ok and isWho) then
        ns.Try(ns.OnGuildInviteLine, body)
    end
end

-- A /who result that does arrive as a system message.
function ns.OnSystemMessage(msg)
    if type(msg) ~= "string" or IsSecret(msg) then
        return
    end
    pcall(ParseWhoBody, (msg:gsub("^|c%x%x%x%x%x%x%x%x", "")))
end

local hookedFrames = {}
function ns.HookChatFrames()
    for _, frame in ipairs(ns.ChatFrames()) do
        if not hookedFrames[frame] and frame.AddMessage then
            hookedFrames[frame] = true
            hooksecurefunc(frame, "AddMessage", function(_, msg)
                OnChatLine(msg)
            end)
        end
    end
end
