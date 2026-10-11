-- Lists.lua: the actions behind the slash command and the options panel:
-- switching settings, and editing the guild, word, name and player lists.

local _, ns = ...
local L = ns.L
local IsSecret, Print = ns.IsSecret, ns.Print

local MIN_NAME_WORD = 3 -- stops "a" from muting half the server

-- Runs fn for each comma-separated entry of text. Commas inside quotes stay
-- part of the entry, so a quoted word-filter phrase can contain one.
local function EachEntry(text, fn)
    local entry, inQuote = {}, false
    local function Flush()
        local value = strtrim(table.concat(entry))
        entry = {}
        if value ~= "" then
            fn(value)
        end
    end
    for i = 1, #text do
        local c = text:sub(i, i)
        if c == '"' then
            inQuote = not inQuote
        end
        if c == "," and not inQuote then
            Flush()
        else
            entry[#entry + 1] = c
        end
    end
    Flush()
end

-- Lists are shown alphabetically; the saved order doesn't matter.
local function Sorted(list)
    if #list == 0 then
        return L["(none)"]
    end
    local copy = {}
    for i, v in ipairs(list) do
        copy[i] = v
    end
    table.sort(copy)
    return table.concat(copy, ", ")
end

local function IndexOf(list, value)
    for i, v in ipairs(list) do
        if v == value then
            return i
        end
    end
end

local function Quoted(text)
    return text:sub(1, 1) == '"' and text or ('"' .. text .. '"')
end

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------
local function OnEnabledChanged(on)
    ns.DataChanged(false)
    if not on then
        ns.RestoreBubbles()
        ns.CancelPurges()
    end
end

-- label: printed with ON/OFF when the setting changes. apply: runs after it.
local SETTINGS = {
    enabled = { label = L["filtering"], apply = OnEnabledChanged },
    declineGuild = { label = L["auto-decline invites from muted guilds"] },
    declineGroup = { label = L["auto-decline group invites from muted players"], apply = ns.RecheckDeclines },
    declineDuel = { label = L["auto-decline duels from muted players"], apply = ns.RecheckDeclines },
    declineTrade = { label = L["ask before trading with muted players"] },
    instantDecline = { label = L["decline group invites and duels instantly"], apply = ns.RecheckDeclines },
    whisperWarn = { label = L["warning when you whisper or invite a muted player"] },
    acceptShares = { label = L["accepting shared lists from other players"] },
    groupWarn = {
        label = L["warning when a muted player is in your group"],
        apply = function(on)
            if on then
                pcall(ns.CheckGroupForMuted)
            end
        end,
    },
    hideBubbles = {
        label = L["hiding chat bubbles from muted players"],
        apply = function(on)
            if not on then
                ns.RestoreBubbles()
            end
        end,
    },
}

function ns.SetOption(name, on)
    local setting = SETTINGS[name]
    on = on and true or false
    ns.db[name] = on
    if setting.apply then
        setting.apply(on)
    end
    Print(setting.label .. " " .. ns.OnOff(on))
    ns.RefreshViews()
end

---------------------------------------------------------------------------
-- Guilds (whole names, compared without regard to case)
---------------------------------------------------------------------------
function ns.GuildNames()
    local names = {}
    for _, name in pairs(ns.db.guilds) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

function ns.GuildList()
    local names = ns.GuildNames()
    return #names > 0 and table.concat(names, ", ") or L["(none)"]
end

-- Returns true if the guild was added. quiet: no chat output (shared lists).
function ns.AddGuild(name, quiet)
    local key = ns.GuildKey(name)
    if not key then
        return false
    end
    if ns.IsOwnGuild(name) then
        if not quiet then
            Print(L["you can't mute the guild you are in."])
        end
        return false
    end
    if ns.db.guilds[key] then
        if not quiet then
            Print(L['"%s" is already on the guild list.']:format(ns.db.guilds[key]))
        end
        return false
    end
    name = strtrim((name:gsub('"', ""))):gsub("%s+", " ")
    ns.db.guilds[key] = name
    ns.scanQueries = nil
    ns.DataChanged(true)
    if not quiet then
        local text = L['now muting the guild "%s" (the whole name has to match). Guild list: %s']
        Print(text:format(name, ns.GuildList()))
    end
    return true
end

function ns.RemoveGuild(name)
    local key = ns.GuildKey(name)
    local saved = key and ns.db.guilds[key]
    if not saved then
        Print(L['"%s" isn\'t on the guild list. Guild list: %s']:format(name, ns.GuildList()))
        return
    end
    ns.db.guilds[key] = nil
    ns.scanQueries = nil
    ns.DataChanged(true)
    local unmuted = ns.UnmuteOrphans()
    Print(L['removed "%s" (%d players unmuted). Guild list: %s']:format(saved, unmuted, ns.GuildList()))
end

---------------------------------------------------------------------------
-- Word filter
---------------------------------------------------------------------------

-- One cleanup for adding and removing: lowercase, single spaces, and no
-- spaces just inside quotes.
local function CleanWord(text)
    local word = strtrim(text):lower():gsub("%s+", " ")
    local inner = word:match('^"(.*)"$')
    return inner and ('"' .. strtrim(inner) .. '"') or word
end

-- Why an entry can't be used, or nil if it is fine.
local function WordProblem(word)
    local exact = word:match('^"(.+)"$')
    if #(exact or word) < 3 then
        return L["filter entries need at least 3 characters."]
    end
    if not exact then
        for part in word:gmatch("%S+") do
            if #part < 2 then
                local text = L['"%s" is too short to filter on; single letters would hide almost everything.']
                return text:format(part)
            end
        end
    end
end

function ns.WordList()
    return Sorted(ns.db.words)
end

function ns.AddWord(text, quiet)
    local word = CleanWord(text)
    local problem = WordProblem(word)
    if not problem and IndexOf(ns.db.words, word) then
        problem = L["%s is already filtered."]:format(Quoted(word))
    end
    if problem then
        if not quiet then
            Print(problem)
        end
        return false
    end
    table.insert(ns.db.words, word)
    ns.DataChanged(false)
    if not quiet then
        local exact = word:match('^"(.+)"$')
        if exact then
            Print(L['hiding messages containing the exact phrase "%s".']:format(exact))
        elseif word:find(" ", 1, true) then
            Print(L["hiding messages that contain all of: %s (any order)."]:format((word:gsub(" ", ", "))))
        else
            Print(L['hiding messages containing "%s".']:format(word))
        end
        Print(L["filtered words: %s"]:format(ns.WordList()))
    end
    return true
end

function ns.RemoveWord(text)
    local word = CleanWord(text)
    -- The entry as typed first; otherwise its quoted or unquoted twin.
    local twin = word:match('^"(.*)"$') or ('"' .. word .. '"')
    local index = IndexOf(ns.db.words, word) or IndexOf(ns.db.words, twin)
    if not index then
        Print(L["%s isn't filtered. Filtered words: %s"]:format(Quoted(word), ns.WordList()))
        return
    end
    local removed = table.remove(ns.db.words, index)
    ns.ForgetWordParts()
    ns.DataChanged(false)
    Print(L["stopped filtering %s. Filtered words: %s"]:format(Quoted(removed), ns.WordList()))
end

---------------------------------------------------------------------------
-- Name keywords: mute any player whose character name contains the text.
---------------------------------------------------------------------------
local function CleanNameWord(text)
    return strtrim((text:lower():gsub('[%*%%"]', "")))
end

function ns.NameWordList()
    return Sorted(ns.db.nameWords)
end

function ns.AddNameWord(text)
    local word = CleanNameWord(text)
    if #word < MIN_NAME_WORD then
        Print(L["name keywords need at least %d letters."]:format(MIN_NAME_WORD))
    elseif IndexOf(ns.db.nameWords, word) then
        Print(L['"%s" is already on the name list.']:format(word))
    else
        table.insert(ns.db.nameWords, word)
        ns.DataChanged(true)
        local template = L['hiding chat from players whose name contains "%s". Name list: %s']
        Print(template:format(word, ns.NameWordList()))
    end
end

function ns.RemoveNameWord(text)
    local word = CleanNameWord(text)
    local index = IndexOf(ns.db.nameWords, word)
    if not index then
        Print(L['"%s" isn\'t on the name list. Name list: %s']:format(word, ns.NameWordList()))
        return
    end
    table.remove(ns.db.nameWords, index)
    ns.DataChanged(true)
    Print(L['removed "%s". Name list: %s']:format(word, ns.NameWordList()))
end

-- Options panel button: adds the text, or removes it if it's already listed.
function ns.ToggleNameWord(text)
    if IndexOf(ns.db.nameWords, CleanNameWord(text)) then
        ns.RemoveNameWord(text)
    else
        ns.AddNameWord(text)
    end
end

---------------------------------------------------------------------------
-- Players
---------------------------------------------------------------------------
function ns.AddPlayer(name)
    local db = ns.db
    name = ns.TypedName(name)
    local key = ns.ResolveKey(name)
    if not key then
        return
    end
    if key == ns.playerKey then
        Print(L["you can't mute yourself."])
        return
    end
    -- Muting by hand ends "unmute while grouped" for them.
    local hadPass = db.passes[key] ~= nil
    db.passes[key] = nil
    if db.players[key] == nil then
        db.allow[key] = nil
        db.manual[key] = true
        ns.Block(nil, name, ns.MANUAL_TAG)
        Print(L["muted %s."]:format(name))
    elseif hadPass then
        db.manual[key] = true
        ns.PurgeHistory(key)
        Print(L["%s is muted again (ended unmute while grouped)."]:format(name))
    elseif db.manual[key] then
        Print(L["%s is already muted."]:format(name))
    else
        -- Found automatically before: pin them so a guild change doesn't unmute them.
        db.manual[key] = true
        Print(L["%s will now stay muted even if they change guilds."]:format(name))
    end
    ns.DataChanged(true)
end

function ns.RemovePlayer(name)
    name = ns.TypedName(name)
    local key = ns.ResolveKey(name)
    if key and ns.db.players[key] then
        ns.Unblock(nil, name, true)
        Print(L["unmuted %s."]:format(name))
    else
        Print(L["%s isn't on the mute list."]:format(name))
    end
end

-- One-way "never mute", for buttons: clicking twice never takes it away again.
function ns.NeverMute(key, display)
    local db = ns.db
    if not key then
        return
    end
    db.allow[key] = true
    db.players[key], db.manual[key], db.passes[key], db.former[key] = nil, nil, nil, nil
    for guid, k in pairs(db.guids) do
        if k == key then
            db.guids[guid] = nil
        end
    end
    ns.DataChanged(true)
    Print(L["%s will never be muted."]:format(tostring(display or key)))
end

-- Never-mute list from typed input: toggles the player on or off it.
function ns.AllowPlayer(name)
    name = ns.TypedName(name)
    local key = ns.ResolveKey(name)
    if not key then
        return
    end
    if ns.db.allow[key] then
        ns.db.allow[key] = nil
        ns.DataChanged(true)
        Print(L["%s can be muted again."]:format(name))
    else
        ns.NeverMute(key, name)
    end
end

function ns.CheckPlayer(name)
    name = ns.TypedName(name)
    local key = ns.ResolveKey(name)
    local guild = key and ns.db.players[key]
    if guild then
        Print(L["%s is muted <%s>."]:format(name, ns.TagText(guild)))
    else
        Print(L["%s isn't on the mute list."]:format(name))
    end
end

function ns.ClearPlayers()
    local db = ns.db
    wipe(db.guids)
    wipe(db.players)
    wipe(db.manual)
    wipe(db.former)
    ns.DataChanged(true)
    Print(L["cleared all muted players."])
end

StaticPopupDialogs["MUTEGUILDS_CLEAR"] = {
    text = L.POPUP_CLEAR,
    button1 = YES,
    button2 = NO,
    OnAccept = ns.ClearPlayers,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function ns.ConfirmClearPlayers()
    StaticPopup_Show("MUTEGUILDS_CLEAR", ns.FormatNum(ns.CountMuted()))
end

---------------------------------------------------------------------------
-- Ignore-list import: move players from WoW's ignore list (which has a small
-- cap) onto the mute list, optionally freeing up the ignore slots.
---------------------------------------------------------------------------
local function IgnoredNames()
    local names = {}
    for i = 1, C_FriendList.GetNumIgnores() do
        local name = C_FriendList.GetIgnoreName(i)
        if type(name) == "string" and not IsSecret(name) and name ~= "" and name ~= UNKNOWNOBJECT then
            names[#names + 1] = name
        end
    end
    return names
end

local function ImportIgnores(clearIgnoreList)
    local db = ns.db
    local added, already, skipped, removed = 0, 0, 0, 0
    for _, name in ipairs(IgnoredNames()) do
        local key = ns.ResolveKey(name)
        if key and db.allow[key] then
            skipped = skipped + 1 -- never-mute list: left alone, and left ignored
        elseif key and key ~= ns.playerKey then
            if db.players[key] == nil then
                db.manual[key] = true
                ns.Block(nil, name, ns.IGNORE_TAG)
                added = added + 1
            else
                db.manual[key] = true -- keep them muted whatever guild they join
                already = already + 1
            end
            if clearIgnoreList and pcall(C_FriendList.DelIgnore, name) then
                removed = removed + 1
            end
        end
    end
    ns.DataChanged(true)
    if clearIgnoreList then
        local text = L["imported %d players from your ignore list (%d were already muted), removed %d from it."]
        Print(text:format(added, already, removed))
    else
        local text = L["imported %d players from your ignore list (%d were already muted). It is unchanged."]
        Print(text:format(added, already))
    end
    if skipped > 0 then
        Print(L["skipped %d on your never-mute list (left on your ignore list)."]:format(skipped))
    end
end

StaticPopupDialogs["MUTEGUILDS_IMPORT"] = {
    text = L.POPUP_IMPORT,
    button1 = L["Import"],
    button2 = CANCEL,
    button3 = L["Import + clear ignore list"],
    OnAccept = function()
        ImportIgnores(false)
    end,
    OnAlt = function()
        ImportIgnores(true)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function ns.StartIgnoreImport()
    local count = #IgnoredNames()
    if count == 0 then
        Print(L["your ignore list is empty, nothing to import."])
    else
        StaticPopup_Show("MUTEGUILDS_IMPORT", tostring(count))
    end
end

---------------------------------------------------------------------------
-- Typed input: "a, b, c" applies the action to each entry.
---------------------------------------------------------------------------
local function ForEachEntry(action)
    return function(text)
        EachEntry(text or "", action)
        ns.RefreshViews()
    end
end

ns.AddGuilds, ns.RemoveGuilds = ForEachEntry(ns.AddGuild), ForEachEntry(ns.RemoveGuild)
ns.AddWords, ns.RemoveWords = ForEachEntry(ns.AddWord), ForEachEntry(ns.RemoveWord)
ns.AddNameWords, ns.RemoveNameWords = ForEachEntry(ns.AddNameWord), ForEachEntry(ns.RemoveNameWord)
ns.ToggleNameWords = ForEachEntry(ns.ToggleNameWord)
ns.AddPlayers, ns.RemovePlayers = ForEachEntry(ns.AddPlayer), ForEachEntry(ns.RemovePlayer)
ns.AllowPlayers = ForEachEntry(ns.AllowPlayer)
