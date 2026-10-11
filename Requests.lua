-- Requests.lua: guild invites, group invites, duels and trades from muted players.

local _, ns = ...
local L = ns.L
local IsSecret, Print = ns.IsSecret, ns.Print

---------------------------------------------------------------------------
-- Human-speed declines
-- An instant decline every time is a pattern someone could look for. Group
-- invites and duels are hidden right away, then declined after a random 2-8
-- seconds, like a person clicking Decline. "Decline instantly" turns it off.
---------------------------------------------------------------------------
local jobs = {} -- kind -> the decline waiting to run

-- valid(): still decline? restore(): give the request back if not.
local function DeclineLater(kind, decline, valid, restore)
    jobs[kind] = nil
    if ns.db.instantDecline then
        decline()
        return
    end
    local job = { decline = decline, valid = valid, restore = restore }
    jobs[kind] = job
    C_Timer.After(math.random(2000, 8000) / 1000, function()
        if jobs[kind] ~= job then
            return -- cancelled, or replaced by a newer request
        end
        jobs[kind] = nil
        if job.valid() then
            pcall(job.decline)
        else
            pcall(job.restore)
        end
    end)
end

-- A setting changed while waiting: give the request back if it shouldn't be
-- declined anymore, or decline it now if "instantly" was just turned on.
function ns.RecheckDeclines()
    for kind, job in pairs(jobs) do
        if not job.valid() then
            jobs[kind] = nil
            pcall(job.restore)
        elseif ns.db.instantDecline then
            jobs[kind] = nil
            pcall(job.decline)
        end
    end
end

---------------------------------------------------------------------------
-- Group invites
-- The invite doesn't say which guild the inviter is in. If they're already on
-- the mute list it is declined; otherwise they're remembered, and if they get
-- identified while the invite is still open (mouseover, target, /who), it is
-- declined at that point.
---------------------------------------------------------------------------
local IDENTIFY_WINDOW = 60 -- seconds an unidentified inviter is remembered
local open = {} -- the invite on screen: key, args, text
local unidentified, unidentifiedAt -- key of an inviter not on the list (yet)

local function PartyInvitePopup()
    local a, b = StaticPopup_Visible("PARTY_INVITE")
    return (type(b) == "table" and b) or (type(a) == "table" and a) or (type(a) == "string" and _G[a]) or nil
end

-- Blizzard's invite window declines the invite when it is hidden, unless it
-- was accepted. Mark it accepted first so that hiding it doesn't decline on
-- the spot: the decline is sent by us after the pause.
local function HideGroupInvite()
    local frame = PartyInvitePopup()
    if frame then
        frame.inviteAccepted = true
        -- Keep Blizzard's own wording in case the invite is given back.
        local fontString = frame.text or frame.Text
        local ok, text = pcall(function()
            return fontString:GetText()
        end)
        if not open.text and ok and type(text) == "string" and not IsSecret(text) and text ~= "" then
            open.text = text
        end
    end
    StaticPopup_Hide("PARTY_INVITE")
    if frame then
        frame.inviteAccepted = nil
    end
    -- Role-check invites use a different window.
    if LFGInvitePopup and LFGInvitePopup:IsShown() then
        pcall(StaticPopupSpecial_Hide, LFGInvitePopup)
    end
end

local function RestoreGroupInvite(name)
    local args = open.args or {}
    local isTank, isHealer, isDamage = args[2], args[3], args[4]
    if (isTank or isHealer or isDamage) and LFGInvitePopup then
        StaticPopupSpecial_Show(LFGInvitePopup)
        LFGInvitePopup_Update(name, isTank, isHealer, isDamage, args[6], args[8])
        return
    end
    StaticPopup_Show("PARTY_INVITE", open.text or INVITATION:format(name))
end

-- key: who the open invite is from. listKey: their entry on the mute list.
local function DeclineGroupInvite(name, guild, key, listKey)
    unidentified = nil
    guild = tostring(ns.TagText(guild))
    ns.Debug(L["%s a group invite from %s <%s>."], ns.Did(L["declining"], L["would decline"]), name, guild)
    if ns.IsDryRun() then
        return
    end
    HideGroupInvite()
    -- The game can open its window just after the event: hide it again.
    C_Timer.After(0.2, function()
        if jobs.group then
            pcall(HideGroupInvite)
        end
    end)
    DeclineLater("group", function()
        DeclineGroup()
        HideGroupInvite()
        ns.PrintThrottled("group:" .. name, L["declined a group invite from %s <%s>."]:format(name, guild))
    end, function() -- still the same invite, still muted, option still on
        return ns.db.declineGroup and key ~= nil and open.key == key and ns.IsMuted(listKey)
    end, function()
        if open.key == key then
            RestoreGroupInvite(name)
        end
    end)
end

-- PARTY_INVITE_REQUEST: inviter, isTank, isHealer, isDamage, isNativeRealm,
-- allowMultipleRoles, inviterGUID, questSessionActive
function ns.OnPartyInviteRequest(inviter, ...)
    jobs.group = nil -- a new invite: any older wait is stale
    local usable = type(inviter) == "string" and not IsSecret(inviter)
    local key = usable and ns.ResolveKey(inviter) or nil
    open.key, open.text, open.args = key, nil, { inviter, ... }
    if not usable or not ns.db.declineGroup then
        return
    end
    local db = ns.db
    local listKey = db.players[key] ~= nil and key or nil
    local guid = select(6, ...)
    if not listKey and guid and not IsSecret(guid) then
        listKey = db.guids[guid]
    end
    if not listKey then
        unidentified, unidentifiedAt = key, GetTime()
    elseif ns.IsMuted(listKey) then
        DeclineGroupInvite(inviter, db.players[listKey], key, listKey)
    end
    -- Otherwise never muted, or unmuted while grouped: the invite goes through.
end

-- The invite is gone: you answered it, they cancelled it, or you joined a group.
function ns.OnPartyInviteClosed()
    unidentified = nil
    open.key = nil
    jobs.group = nil
end

function ns.IsInvitePending(key)
    return unidentified ~= nil and unidentified == key
end

-- Called by ns.Block whenever a player is confirmed to be in a muted guild.
function ns.OnPlayerMuted(key, name, guild)
    if
        unidentified == key
        and open.key == key
        and ns.db.declineGroup
        and GetTime() - unidentifiedAt < IDENTIFY_WINDOW
    then
        DeclineGroupInvite(name, guild, key, key)
    end
end

---------------------------------------------------------------------------
-- Guild invites
---------------------------------------------------------------------------
local lastGuildDecline, lastGuildEvent = 0, 0

local function GuildInviteVisible()
    if GuildInviteFrame and GuildInviteFrame:IsShown() then
        return true
    end
    return StaticPopup_Visible("GUILD_INVITE") and true or false
end

local function DeclineGuildInvite()
    -- Press the invite window's own Decline button when it exists, so the game
    -- does exactly what a manual click does; otherwise call the API.
    local button = GuildInviteFrameDeclineButton
    if button and button:IsVisible() then
        button:Click()
    else
        -- Which of the two this client has is not confirmed yet.
        local decline = DeclineGuild or C_GuildInfo.DeclineGuild
        decline()
    end
    StaticPopup_Hide("GUILD_INVITE")
    if GuildInviteFrame and GuildInviteFrame:IsShown() then
        GuildInviteFrame:Hide()
    end
end

local function HandleGuildInvite(inviter, guildName)
    if not ns.db.declineGuild or not ns.IsMutedGuild(guildName) then
        return
    end
    ns.Debug(L["%s a guild invite from <%s>."], ns.Did(L["declining"], L["would decline"]), guildName)
    if ns.IsDryRun() then
        return
    end
    DeclineGuildInvite()
    -- The invite window can open a moment after the event: check again shortly.
    C_Timer.After(0.2, function()
        if GuildInviteVisible() then
            ns.Try(DeclineGuildInvite)
        end
    end)
    if type(inviter) == "string" and not IsSecret(inviter) then
        ns.Block(nil, inviter, guildName)
    end
    ns.PrintThrottled("guild:" .. guildName, L["declined a guild invite from <%s>."]:format(guildName))
    lastGuildDecline = GetTime()
end

function ns.OnGuildInviteRequest(inviter, guildName)
    lastGuildEvent = GetTime()
    HandleGuildInvite(inviter, guildName)
end

-- Backup trigger: the "[Name] invites you to join Guild." line printed to
-- chat. Only acted on while an invite window is open and the event did not
-- already handle it. The caller has checked the line starts with a bare
-- player link, which player chat can't produce.
function ns.OnGuildInviteLine(body)
    if not ns.db.declineGuild then
        return
    end
    local now = GetTime()
    if now - lastGuildDecline < 2 or now - lastGuildEvent < 3 or not GuildInviteVisible() then
        return
    end
    local name, rest = body:match("^|Hplayer:([^:|]+)|h%[[^%]]*%]|h (.*)$")
    -- English wording only: in other languages the guild name can't be read
    -- from the line, and guessing is worse than leaving the invite alone. The
    -- GUILD_INVITE_REQUEST event above works in every language.
    local guild = name and rest:gsub("|r$", ""):match("join (.-)%.?$")
    if guild then
        HandleGuildInvite(name, guild)
    end
end

---------------------------------------------------------------------------
-- Duels
---------------------------------------------------------------------------
local DUEL_POPUPS = { "DUEL_REQUESTED", "DUEL_TO_THE_DEATH_REQUESTED", "DUEL_TO_THE_DEATH_REQUESTED_CONFIRM" }

local function HideDuel()
    for _, which in ipairs(DUEL_POPUPS) do
        StaticPopup_Hide(which)
    end
end

-- event: DUEL_REQUESTED or DUEL_TO_THE_DEATH_REQUESTED, which is also the
-- name of the popup the game shows for it.
function ns.OnDuelRequested(challenger, event)
    if not ns.db.declineDuel or type(challenger) ~= "string" or IsSecret(challenger) then
        return
    end
    local guild = ns.MutedGuildForName(challenger)
    if not guild then
        return
    end
    ns.Debug(L["%s a duel from %s <%s>."], ns.Did(L["declining"], L["would decline"]), challenger, guild)
    if ns.IsDryRun() then
        return
    end
    HideDuel()
    C_Timer.After(0.2, function()
        if jobs.duel then
            pcall(HideDuel)
        end
    end)
    DeclineLater("duel", function()
        CancelDuel()
        HideDuel()
        ns.PrintThrottled("duel:" .. challenger, L["declined a duel from %s <%s>."]:format(challenger, guild))
    end, function()
        return ns.db.declineDuel and ns.MutedGuildForName(challenger) ~= nil
    end, function() -- give the request back (death duels use the name twice)
        if not pcall(StaticPopup_Show, event, challenger, challenger) then
            CancelDuel() -- couldn't show it: don't leave it hidden and unanswered
        end
    end)
end

function ns.OnDuelFinished()
    jobs.duel = nil
end

---------------------------------------------------------------------------
-- Trades
-- Muted players can still sell you enchants or materials, so instead of
-- declining on the spot, ask. "Allow trade" lets this trade and any more with
-- them in the next 10 minutes go ahead.
---------------------------------------------------------------------------
local TRADE_ALLOWED_FOR = 600
local tradeAllowedUntil, tradeAskedAt = {}, {} -- key -> time

local function CancelMutedTrade()
    CancelTrade()
    StaticPopup_Hide("TRADE")
end

StaticPopupDialogs["MUTEGUILDS_TRADE"] = {
    text = L["Trade with %s <%s>?\n\nThey're on your MuteGuilds list."],
    button1 = L["Allow trade"],
    button2 = L["Decline"],
    OnAccept = function(_, data)
        tradeAllowedUntil[data.key] = GetTime() + TRADE_ALLOWED_FOR
        Print(L["trading with %s allowed for the next 10 minutes. They stay muted."]:format(data.name))
    end,
    OnCancel = function(_, data, reason)
        if reason == "override" or not data then
            return -- closed because the trade ended
        end
        CancelMutedTrade()
        Print(L["cancelled the trade with %s <%s>."]:format(data.name, data.guild))
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- name: the player from TRADE_REQUEST, or nil for TRADE_SHOW (the trade
-- partner is then the "NPC" unit).
function ns.OnTrade(name)
    if not ns.db.declineTrade or IsSecret(name) then
        return
    end
    if type(name) ~= "string" then
        name = ns.UnitNameString("NPC")
        if not name then
            return
        end
    end
    local guild, key = ns.MutedGuildForName(name)
    if not guild or (tradeAllowedUntil[key] or 0) > GetTime() then
        return
    end
    -- The request and the trade window both fire: ask once per trade.
    if GetTime() - (tradeAskedAt[key] or 0) < 3 and StaticPopup_Visible("MUTEGUILDS_TRADE") then
        return
    end
    tradeAskedAt[key] = GetTime()
    ns.Debug(L["%s before trading with %s <%s>."], ns.Did(L["asking"], L["would ask"]), name, guild)
    if ns.IsDryRun() then
        return
    end
    local data = { key = key, name = name, guild = guild }
    if not StaticPopup_Show("MUTEGUILDS_TRADE", name, guild, data) then
        CancelMutedTrade() -- no window available: decline
        ns.PrintThrottled("trade:" .. name, L["cancelled the trade with %s <%s>."]:format(name, guild))
    end
end

-- The trade ended on its own (they cancelled, walked away): close the question.
function ns.OnTradeEnded()
    StaticPopup_Hide("MUTEGUILDS_TRADE")
end
