-- Share.lua: send your guild names and filtered words to another MuteGuilds
-- user. Players are never shared, and nothing changes on the receiving side
-- until they accept.
--
-- Wire format, one addon message per piece:  <id>:<piece>/<pieces>:<payload part>
-- Payload:  v1;g:<guild name>;w:<word entry>;f:<guild name>;...   (values percent-escaped)
-- f: marks a guild whose family is muted too. It comes in addition to the
-- guild's g: item, and versions that don't know it skip it.

local _, ns = ...
local L = ns.L
local IsSecret, Print = ns.IsSecret, ns.Print

local PREFIX = "MuteGuilds"
local MAX_ITEMS = 100 -- per list
local CHUNK = 220 -- characters of payload per addon message
local MAX_PIECES = 20 -- what a receiver accepts
local MAX_BYTES = MAX_PIECES * CHUNK
local THROTTLED = { [3] = true, [8] = true } -- SendAddonMessage results: retry later

C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)

---------------------------------------------------------------------------
-- Payload
---------------------------------------------------------------------------
local function Escape(value)
    return (value:gsub("[%%;|]", function(c)
        return ("%%%02X"):format(c:byte())
    end))
end

local function Unescape(value)
    return (value:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end))
end

-- Returns payload, guilds included, words included, entries that didn't fit.
local function BuildPayload()
    local items, size = { "v1" }, 2
    local function AddAll(kind, list)
        local count = 0
        for i, value in ipairs(list) do
            local item = kind .. ":" .. Escape(value)
            if i <= MAX_ITEMS and size + 1 + #item <= MAX_BYTES then
                items[#items + 1] = item
                size = size + 1 + #item
                count = count + 1
            end
        end
        return count
    end
    local guilds = ns.GuildNames()
    local sentGuilds = AddAll("g", guilds)
    local sentWords = AddAll("w", ns.db.words)
    local left = (#guilds - sentGuilds) + (#ns.db.words - sentWords)
    local families = {}
    for i = 1, sentGuilds do
        if ns.db.families[ns.GuildKey(guilds[i])] then
            families[#families + 1] = guilds[i]
        end
    end
    AddAll("f", families)
    return table.concat(items, ";"), sentGuilds, sentWords, left
end

-- Returns guilds, words, family guilds, or nil for an unknown format.
local function ParsePayload(payload)
    local lists = { g = {}, w = {}, f = {} }
    local version
    for item in (payload .. ";"):gmatch("([^;]*);") do
        if not version then
            version = item
            if version ~= "v1" then
                return nil
            end
        else
            local kind, value = item:match("^([gwf]):(.+)$")
            value = value and Unescape(value)
            local list = lists[kind]
            -- No color, link or texture codes from other players.
            if value and not value:find("|", 1, true) and #list < MAX_ITEMS then
                list[#list + 1] = value
            end
        end
    end
    return lists.g, lists.w, lists.f
end

---------------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------------

-- "" -> your group, "guild" -> your guild, anything else -> that player.
-- Returns channel, whisper target, description. Without a usable destination
-- the channel is nil and the description says why.
local function Destination(target)
    if target == "" then
        if IsInRaid() then
            return "RAID", nil, L["your group"]
        elseif IsInGroup() then
            return "PARTY", nil, L["your group"]
        end
        return nil, nil, L["join a group to share with it, or type a name: /mg share Name"]
    elseif target:lower() == "guild" then
        if not IsInGuild() then
            return nil, nil, L["you're not in a guild."]
        end
        return "GUILD", nil, L["your guild"]
    end
    return "WHISPER", target, target
end

function ns.SendShare(target)
    target = strtrim(target or "")
    local channel, whisperTarget, who = Destination(target)
    if not channel then
        Print(who)
        return
    end
    local payload, sentGuilds, sentWords, left = BuildPayload()
    if sentGuilds + sentWords == 0 then
        Print(L["your guild list and word filter are both empty, nothing to share."])
        return
    end
    local id = tostring(math.random(10000, 99999))
    local total = math.ceil(#payload / CHUNK)
    local piece, retries = 1, 0

    -- One piece at a time, retrying briefly if the game says to slow down.
    local function SendNext()
        local part = payload:sub((piece - 1) * CHUNK + 1, piece * CHUNK)
        local message = ("%s:%d/%d:%s"):format(id, piece, total, part)
        local ok, result = pcall(C_ChatInfo.SendAddonMessage, PREFIX, message, channel, whisperTarget)
        if ok and THROTTLED[result] then
            retries = retries + 1
            if retries > 5 then
                Print(L["sharing failed: the game is limiting addon messages right now. Try again in a minute."])
                return
            end
            C_Timer.After(1, SendNext)
            return
        elseif not ok or (result ~= true and result ~= 0 and result ~= nil) then
            Print(L["sharing failed (the game refused the message, code %s)."]:format(tostring(result)))
            return
        end
        if piece < total then
            piece, retries = piece + 1, 0
            C_Timer.After(0.2, SendNext)
            return
        end
        local text = L["shared %d guild names and %d filtered words with %s. They'll be asked before anything changes."]
        Print(text:format(sentGuilds, sentWords, who))
        if left > 0 then
            Print(L["(%d more entries didn't fit in one share.)"]:format(left))
        end
        if channel == "WHISPER" then
            Print(L["(shares sent by whisper only arrive if you're on their friends list or in their group.)"])
        end
    end
    SendNext()
end

StaticPopupDialogs["MUTEGUILDS_SHARE_SEND"] = {
    text = L.POPUP_SHARE_SEND,
    button1 = L["Share"],
    button2 = CANCEL,
    hasEditBox = 1,
    OnAccept = function(self)
        ns.SendShare((self.editBox or self.EditBox):GetText())
    end,
    EditBoxOnEnterPressed = function(self)
        ns.SendShare(self:GetText())
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function ns.PromptShare()
    StaticPopup_Show("MUTEGUILDS_SHARE_SEND")
end

---------------------------------------------------------------------------
-- Receiving
---------------------------------------------------------------------------
local MAX_PENDING = 5 -- unfinished shares kept at once
local PENDING_FOR = 30 -- seconds an unfinished share is kept
local SENDER_GAP = 300 -- seconds between offers from one sender
local GLOBAL_GAP = 60 -- seconds between any two offers
local incoming = {} -- "sender|id" -> { parts, total, got, t }
local lastOfferFrom = {} -- sender key -> time their last offer was shown
local lastOfferAt = -GLOBAL_GAP

-- Adds shared entries quietly. Returns how many guilds and words were new.
local function Merge(guilds, words, families)
    local addedGuilds, addedWords = 0, 0
    for _, guild in ipairs(guilds) do
        if ns.AddGuild(guild, true) then
            addedGuilds = addedGuilds + 1
        end
    end
    -- Only for guilds that were in the share itself (and so in its preview).
    local shared = {}
    for _, guild in ipairs(guilds) do
        shared[ns.GuildKey(guild) or ""] = true
    end
    for _, guild in ipairs(families) do
        if shared[ns.GuildKey(guild) or ""] then
            ns.MuteFamily(guild, true)
        end
    end
    for _, word in ipairs(words) do
        if ns.AddWord(word, true) then
            addedWords = addedWords + 1
        end
    end
    ns.DataChanged(true)
    return addedGuilds, addedWords
end

local function Replace(guilds, words, families)
    wipe(ns.db.guilds)
    wipe(ns.db.families)
    wipe(ns.db.words)
    ns.ForgetWordParts()
    local addedGuilds, addedWords = Merge(guilds, words, families)
    ns.UnmuteOrphans()
    return addedGuilds, addedWords
end

local function Summary(list)
    if #list == 0 then
        return L["(none)"]
    end
    local text = table.concat(list, ", ", 1, math.min(5, #list))
    if #list > 5 then
        text = text .. L[" and %d more"]:format(#list - 5)
    end
    return text
end

StaticPopupDialogs["MUTEGUILDS_SHARE"] = {
    text = L["%s wants to share their MuteGuilds lists with you.\n\n%s\n\nNothing changes unless you choose below."],
    button1 = L["Add to mine"],
    button2 = CANCEL,
    button3 = L["Replace mine"],
    OnAccept = function(_, data)
        local guilds, words = Merge(data.guilds, data.words, data.families)
        Print(L["added %d guild names and %d filtered words from %s."]:format(guilds, words, data.from))
    end,
    OnAlt = function(_, data)
        local guilds, words = Replace(data.guilds, data.words, data.families)
        local text = L["replaced your lists with %s's: %d guild names, %d filtered words."]
        Print(text:format(data.from, guilds, words))
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Shares are only accepted from people you already know: your group, your
-- guild, or your friends list. Strangers can't send you popups.
local function TrustedSender(sender, channel)
    if channel == "PARTY" or channel == "RAID" or channel == "INSTANCE_CHAT" or channel == "GUILD" then
        return true
    end
    if channel ~= "WHISPER" then
        return false
    end
    local short = sender:match("^[^%-]+") or sender
    if UnitInParty(short) or UnitInRaid(short) then
        return true
    end
    return (C_FriendList.GetFriendInfo(sender) or C_FriendList.GetFriendInfo(short)) and true or false
end

-- Collects the pieces of one share. Returns the full payload once complete.
local function Collect(sender, id, piece, total, part)
    local slot = sender .. "|" .. id
    local entry = incoming[slot]
    if not entry then
        local pendingCount = 0
        for key, other in pairs(incoming) do
            if GetTime() - other.t > PENDING_FOR then
                incoming[key] = nil
            else
                pendingCount = pendingCount + 1
            end
        end
        if pendingCount >= MAX_PENDING then
            return nil -- flood: drop new ones
        end
        entry = { parts = {}, total = total, got = 0, t = GetTime() }
        incoming[slot] = entry
    end
    if total ~= entry.total or entry.parts[piece] then
        return nil
    end
    entry.parts[piece] = part
    entry.got = entry.got + 1
    if entry.got < entry.total then
        return nil
    end
    incoming[slot] = nil
    return table.concat(entry.parts, "", 1, entry.total)
end

local function OnShareMessage(text, channel, sender)
    if not ns.db.acceptShares or type(text) ~= "string" or type(sender) ~= "string" then
        return
    end
    if IsSecret(text) or IsSecret(sender) then
        return
    end
    local key = ns.Normalize(sender)
    -- Not our own broadcast, never from muted players, only from people you know.
    if key == ns.playerKey or ns.MutedGuildForName(sender) or not TrustedSender(sender, channel) then
        return
    end
    local id, piece, total, part = text:match("^(%d+):(%d+)/(%d+):(.*)$")
    piece, total = tonumber(piece), tonumber(total)
    if not id or total < 1 or total > MAX_PIECES or piece < 1 or piece > total then
        return
    end
    local payload = Collect(sender, id, piece, total, part)
    if not payload then
        return
    end
    local guilds, words, families = ParsePayload(payload)
    if not guilds or #guilds + #words == 0 then
        return
    end
    local now = GetTime()
    if now - (lastOfferFrom[key] or -SENDER_GAP) < SENDER_GAP or now - lastOfferAt < GLOBAL_GAP then
        return
    end
    if StaticPopup_Visible("MUTEGUILDS_SHARE") then
        return
    end
    -- The preview marks the guilds that come with their family.
    local isFamily, shown = {}, {}
    for _, guild in ipairs(families) do
        isFamily[ns.GuildKey(guild) or ""] = true
    end
    for i, guild in ipairs(guilds) do
        shown[i] = isFamily[ns.GuildKey(guild) or ""] and L["%s (family)"]:format(guild) or guild
    end
    local preview =
        L["Guild names (%d): %s\nFiltered words (%d): %s"]:format(#guilds, Summary(shown), #words, Summary(words))
    local data = { from = sender, guilds = guilds, words = words, families = families }
    if StaticPopup_Show("MUTEGUILDS_SHARE", sender, preview, data) then
        lastOfferFrom[key], lastOfferAt = now, now -- the limits count only offers that were shown
    else
        local notice = L["%s shared their lists, but the window couldn't open right now. Ask them to send it again."]
        ns.PrintThrottled("sharefail:" .. key, notice:format(sender))
    end
end

-- CHAT_MSG_ADDON
function ns.OnAddonMessage(prefix, text, channel, sender)
    if prefix == PREFIX then
        pcall(OnShareMessage, text, channel, sender)
    end
end
