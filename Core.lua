-- MuteGuilds: hides chat from players who are in one of the guilds on your list.
-- A guild is matched on its whole name (case-insensitive), never on a part of it.
-- Purely client-side: nothing is added to the ignore list, senders aren't notified.
--
-- Core.lua: shared helpers, name handling, saved data and the mute list itself.

local _, ns = ...

ns.PREFIX = "|cff66ccffMuteGuilds:|r "
ns.MANUAL_TAG = "added manually"
ns.IGNORE_TAG = "from ignore list"
ns.gen = 0 -- bumped on any change that can alter a filter decision

-- Values from the client can be "secret": comparing or indexing with one errors.
local IsSecret = issecretvalue or function()
    return false
end
ns.IsSecret = IsSecret

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(ns.PREFIX .. msg)
end
ns.Print = Print

function ns.ReportError(err)
    Print("|cffff4444error:|r " .. tostring(err))
end

-- Runs fn and prints the error instead of failing silently.
function ns.Try(fn, ...)
    return xpcall(fn, ns.ReportError, ...)
end

-- At most one line per id per minute, so someone spamming duels or invites
-- can't flood your chat through the addon.
local lastNotice = {}
function ns.PrintThrottled(id, msg)
    local now = GetTime()
    if lastNotice[id] and now - lastNotice[id] < 60 then
        return
    end
    lastNotice[id] = now
    Print(msg)
end

function ns.OnOff(v)
    return v and "|cff00ff00ON|r" or "|cffff0000OFF|r"
end

function ns.FormatNum(n)
    return BreakUpLargeNumbers(n)
end

-- Every chat window, including whisper pop-out tabs.
function ns.ChatFrames()
    local list = {}
    for _, name in ipairs(CHAT_FRAMES) do
        local frame = _G[name]
        if type(frame) == "table" then
            list[#list + 1] = frame
        end
    end
    return list
end

---------------------------------------------------------------------------
-- Guild names
---------------------------------------------------------------------------

-- The form guild names are compared in: trimmed, single spaces, lowercase.
local function GuildKey(name)
    if type(name) ~= "string" then
        return nil
    end
    local key = strtrim((name:gsub('"', ""))):gsub("%s+", " "):lower()
    return key ~= "" and key or nil
end
ns.GuildKey = GuildKey

-- Is this the guild you are in? Your own guild can't be muted.
function ns.IsOwnGuild(guild)
    local own = GetGuildInfo("player")
    if IsSecret(own) or IsSecret(guild) then
        return false
    end
    local key = GuildKey(guild)
    return key ~= nil and key == GuildKey(own)
end

-- True only when the whole guild name is on the list. Never true for your own
-- guild, even if its name is on the list from before you joined it.
function ns.IsMutedGuild(guild)
    if not ns.db or IsSecret(guild) then
        return false
    end
    local key = GuildKey(guild)
    return key ~= nil and ns.db.guilds[key] ~= nil and not ns.IsOwnGuild(guild)
end

---------------------------------------------------------------------------
-- Player names
-- List keys are "name-realm" in lowercase, the realm written the way chat
-- links write it (no spaces or hyphens).
---------------------------------------------------------------------------
local realmCache
local function OwnRealm()
    if not realmCache then
        local realm = GetNormalizedRealmName()
        if realm and realm ~= "" then
            realmCache = realm
        end
    end
    return realmCache
end

local function Normalize(name)
    if type(name) ~= "string" or name == "" then
        return nil
    end
    local dash = name:find("-", 1, true)
    if not dash then
        local realm = OwnRealm()
        if realm then
            name = name .. "-" .. realm
        end
    elseif name:find("[%s%-]", dash + 1) then
        -- Typed "Name-Aerie Peak": chat writes "AeriePeak".
        name = name:sub(1, dash) .. name:sub(dash + 1):gsub("[%s%-]", "")
    end
    return name:lower()
end
ns.Normalize = Normalize

-- Character names can have two parts ("Bacon Eggz"). UnitName and UnitFullName
-- return the second part in the realm slot; GetUnitName joins it the way chat
-- shows it.
function ns.UnitNameString(unit)
    local ok, full = pcall(GetUnitName, unit, true)
    if not ok or IsSecret(full) or type(full) ~= "string" or full == "" then
        return nil
    end
    local first, realm = full:match("^([^%-]+)%-(.+)$")
    -- Name data not loaded yet: not a real player name.
    if (first or full) == UNKNOWNOBJECT then
        return nil
    end
    if first then
        full = first .. "-" .. (realm:gsub("[%s%-]", ""))
    end
    return full
end

-- A name the user typed. "Tiny-Yackle" usually means first name plus surname
-- here, not a realm: the part after the dash is a realm only when it is yours
-- or one already seen on a saved two-part name.
local knownRealms
function ns.TypedName(name)
    name = (strtrim(name or ""):gsub("%s+", " "))
    if name:find(" ", 1, true) then
        return name
    end
    local first, last = name:match("^([^%-]+)%-([^%-]+)$")
    local own = OwnRealm()
    if not first or not own then
        return name
    end
    if not knownRealms then
        knownRealms = { [own:lower()] = true }
        for key in pairs(ns.db.players) do
            local realm = key:find(" ", 1, true) and key:match("%-([^%-]+)$")
            if realm then
                knownRealms[realm] = true
            end
        end
    end
    if knownRealms[(last:lower():gsub("[%s%-]", ""))] then
        return name
    end
    return first .. " " .. last
end

-- List key for a name from chat, an event or the user.
local function ResolveKey(name)
    local key = Normalize(name)
    local db = ns.db
    if not key or db.players[key] ~= nil or db.allow[key] then
        return key
    end
    -- "Bacon-Eggz" (first and last name joined by a dash) -> "bacon eggz-realm"
    local first, last = name:match("^%s*([^%s%-]+)%-([^%s%-]+)%s*$")
    if first then
        local alt = Normalize(first .. " " .. last)
        if alt and (db.players[alt] ~= nil or db.allow[alt]) then
            return alt
        end
    end
    return key
end
ns.ResolveKey = ResolveKey

---------------------------------------------------------------------------
-- The mute list
---------------------------------------------------------------------------

-- Windows and panels register a refresh function here and are told when the
-- data they show has changed.
local views = {}
function ns.RegisterView(refresh)
    views[#views + 1] = refresh
end

function ns.RefreshViews()
    for _, refresh in ipairs(views) do
        pcall(refresh)
    end
end

-- Everything that changes saved data reports here: cached filter decisions
-- are dropped, and open windows refresh once on the next frame.
local refreshQueued = false
local function DataChanged(listChanged)
    ns.gen = ns.gen + 1
    if listChanged and not refreshQueued then
        refreshQueued = true
        C_Timer.After(0, function()
            refreshQueued = false
            ns.RefreshViews()
        end)
    end
end
ns.DataChanged = DataChanged

function ns.CountMuted()
    local n = 0
    for _ in pairs(ns.db.players) do
        n = n + 1
    end
    return n
end

-- On the list, not on the never-mute list, and not unmuted while grouped.
function ns.IsMuted(key)
    local db = ns.db
    return key ~= nil and db.players[key] ~= nil and not db.allow[key] and not db.passes[key]
end

-- Muted guild (or tag) and list key for a name, or nil.
function ns.MutedGuildForName(name)
    local key = ResolveKey(name)
    if ns.IsMuted(key) then
        return ns.db.players[key], key
    end
end

-- Highest level seen on a muted guild's member; the /who scan stops there.
function ns.NoteLevel(level)
    level = tonumber(level)
    if not level or level < 1 or level > 200 then
        return
    end
    if level > (ns.db.maxSeenLevel or 0) then
        ns.db.maxSeenLevel = level
        ns.scanQueries = nil
    end
end

function ns.Block(guid, name, guild)
    local db = ns.db
    local key = ResolveKey(name)
    if not key or db.allow[key] then
        return
    end
    if key == ns.playerKey or (guid and guid == ns.playerGUID) then
        return -- never yourself
    end
    local isNew, listChanged = false, false
    local current = db.players[key]
    db.former[key] = nil -- muted again: the "was in a muted guild" note is over
    if current == nil then
        db.players[key] = guild
        isNew, listChanged = true, true
    elseif current ~= guild and not db.manual[key] then
        db.players[key] = guild -- moved to another muted guild: keep it current
        listChanged = true
    end
    if guid and db.guids[guid] ~= key then
        db.guids[guid] = key
        isNew = true
    end
    if isNew or listChanged then
        DataChanged(listChanged)
    end
    -- Identified while their group invite was still open (Requests.lua).
    if ns.OnPlayerMuted then
        ns.OnPlayerMuted(key, name, guild)
    end
    if isNew then
        ns.Debug("added %s <%s> to the mute list.", tostring(name), tostring(guild))
        ns.PurgeHistory(key)
    end
end

-- force: the user asked for it (unmute, never mute). Without it the player is
-- being removed because they were seen outside the muted guild, and a note of
-- that guild is kept for their tooltip.
function ns.Unblock(guid, name, force)
    local db = ns.db
    local key = ResolveKey(name)
    if key and db.manual[key] and not force then
        return -- added by hand; keep
    end
    local changed, listChanged = false, false
    if guid and db.guids[guid] ~= nil then
        db.guids[guid] = nil
        changed = true
    end
    if key and db.players[key] ~= nil then
        local guild = db.players[key]
        db.former[key] = (not force and ns.IsMutedGuild(guild)) and guild or nil
        db.players[key] = nil
        listChanged = true
        for g, k in pairs(db.guids) do
            if k == key then
                db.guids[g] = nil
            end
        end
    end
    if key then
        db.manual[key] = nil
    end
    if changed or listChanged then
        DataChanged(listChanged)
    end
end

-- Unmute a whole set of keys at once (one sweep of the GUID table).
function ns.UnblockMany(keys)
    local db = ns.db
    local n = 0
    for key in pairs(keys) do
        if db.players[key] ~= nil then
            db.players[key] = nil
            n = n + 1
        end
        db.manual[key] = nil
    end
    if n > 0 then
        for g, k in pairs(db.guids) do
            if keys[k] then
                db.guids[g] = nil
            end
        end
        DataChanged(true)
    end
    return n
end

-- Seen in a guild that isn't muted (or in none): no longer a member.
function ns.UnblockFormer(name, newGuild)
    local db = ns.db
    local key = ResolveKey(name)
    if not key or not db.players[key] or db.manual[key] then
        return
    end
    ns.Unblock(nil, name)
    local now = (newGuild and newGuild ~= "") and ("<" .. newGuild .. ">") or "unguilded"
    ns.Debug("removed %s from the mute list, now %s.", name, now)
end

-- Unmute players who were only muted for a guild that is no longer listed.
-- Players added by hand stay.
function ns.UnmuteOrphans()
    local db = ns.db
    local drop = {}
    for key, guild in pairs(db.players) do
        if not db.manual[key] and not ns.IsMutedGuild(guild) then
            drop[key] = true
        end
    end
    -- Notes about former members of a guild that is no longer listed.
    for key, guild in pairs(db.former) do
        if not db.guilds[GuildKey(guild) or ""] then
            db.former[key] = nil
        end
    end
    return ns.UnblockMany(drop)
end

-- The muted guild this player was last seen leaving, or nil.
function ns.FormerGuild(key)
    local db = ns.db
    local guild = key and db.former[key]
    if guild and db.players[key] == nil and db.guilds[GuildKey(guild) or ""] then
        return guild
    end
end

-- The game now reports a different name for a known character (a rename):
-- move their entry to the new key.
function ns.Rekey(old, new)
    local db = ns.db
    if not old or not new or old == new then
        return
    end
    if db.players[old] ~= nil then
        if db.players[new] == nil then
            db.players[new] = db.players[old]
        end
        db.players[old] = nil
    end
    if db.manual[old] then
        db.manual[new], db.manual[old] = true, nil
    end
    for g, k in pairs(db.guids) do
        if k == old then
            db.guids[g] = new
        end
    end
    DataChanged(true)
end

---------------------------------------------------------------------------
-- Saved data
---------------------------------------------------------------------------
local TABLES =
    { "guilds", "players", "guids", "manual", "allow", "words", "nameWords", "passes", "groupWarned", "former" }
local FLAGS = {
    enabled = true,
    declineGuild = true,
    declineGroup = true,
    declineDuel = true,
    declineTrade = true,
    instantDecline = false,
    groupWarn = true,
    whisperWarn = true,
    hideBubbles = true,
    acceptShares = true,
}

local function StringList(list)
    local out, seen = {}, {}
    for _, v in pairs(list) do
        if type(v) == "string" and v ~= "" and not seen[v] then
            seen[v] = true
            out[#out + 1] = v
        end
    end
    return out
end

-- Fills in defaults and drops anything that isn't the right kind of value, so
-- a damaged or hand-edited settings file can't break the addon.
function ns.InitDB()
    if type(MuteGuildsDB) ~= "table" then
        MuteGuildsDB = {}
    end
    local db = MuteGuildsDB
    ns.db = db
    for _, k in ipairs(TABLES) do
        if type(db[k]) ~= "table" then
            db[k] = {}
        end
    end
    for k, default in pairs(FLAGS) do
        if type(db[k]) ~= "boolean" then
            db[k] = default
        end
    end
    if type(db.hiddenTotal) ~= "number" then
        db.hiddenTotal = 0
    end
    if not ns.DEBUG_MODES[db.debugMode] then
        db.debugMode = "off"
    end
    if type(db.maxSeenLevel) ~= "number" or db.maxSeenLevel < 1 or db.maxSeenLevel > 200 then
        db.maxSeenLevel = nil
    end

    -- guilds: lowercase name -> name as the user wrote it
    local guilds = {}
    for k, v in pairs(db.guilds) do
        local key = GuildKey(k)
        if key then
            guilds[key] = type(v) == "string" and v or k
        end
    end
    db.guilds = guilds

    for k, v in pairs(db.players) do
        if type(k) ~= "string" or type(v) ~= "string" then
            db.players[k] = nil
        end
    end
    for k, v in pairs(db.former) do
        if type(k) ~= "string" or type(v) ~= "string" then
            db.former[k] = nil
        end
    end
    for g, k in pairs(db.guids) do
        if type(g) ~= "string" or type(k) ~= "string" or db.players[k] == nil then
            db.guids[g] = nil
        end
    end
    for k in pairs(db.manual) do
        if db.players[k] == nil then
            db.manual[k] = nil
        end
    end
    for k in pairs(db.allow) do
        if type(k) ~= "string" then
            db.allow[k] = nil
        end
    end
    for k, v in pairs(db.passes) do
        if type(k) ~= "string" or type(v) ~= "table" then
            db.passes[k] = nil
        end
    end
    for k, v in pairs(db.groupWarned) do
        if type(k) ~= "string" or v ~= true then
            db.groupWarned[k] = nil
        end
    end
    db.words = StringList(db.words)
    db.nameWords = StringList(db.nameWords)
    DataChanged(false)
end
