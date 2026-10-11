-- Social.lua: what you are told about muted players: the tooltip line, the
-- warnings when you whisper or invite one, and the window for muted players in
-- your group, with its "unmute while grouped" passes.

local _, ns = ...
local L = ns.L
local IsSecret, Print = ns.IsSecret, ns.Print

---------------------------------------------------------------------------
-- Passes ("unmute while grouped")
-- A pass ends when the player leaves your group (or you leave), or if they
-- never join (invite declined or expired). Checked on every roster change, and
-- on a timer so a pass can't outlive its limits when nothing else changes.
---------------------------------------------------------------------------
local JOIN_LIMIT, UNGROUPED_LIMIT = 120, 5 -- seconds a pass waits for them to join
local passTimer = 0

local function UpdatePasses()
    local db = ns.db
    if not next(db.passes) then
        return
    end
    local present, grouped = ns.GroupKeys(), IsInGroup()
    local limit = grouped and JOIN_LIMIT or UNGROUPED_LIMIT
    local left, never, soonest = {}, {}, nil
    for key, pass in pairs(db.passes) do
        local age = time() - (tonumber(pass.t) or 0)
        if present[key] then
            pass.joined = true
        elseif pass.joined or age > limit then
            db.passes[key] = nil
            -- Only announce players who really are muted again.
            if ns.IsMuted(key) then
                local name = type(pass.name) == "string" and pass.name or key
                local list = pass.joined and left or never
                list[#list + 1] = name
            end
        else
            local due = limit + 1 - age
            soonest = math.min(soonest or due, due)
        end
    end
    if #left + #never > 0 then
        ns.DataChanged(true)
    end
    if #left > 0 then
        Print(L["muted again (left the group): %s."]:format(table.concat(left, ", ")))
    end
    if #never > 0 then
        Print(L["muted again (didn't join): %s."]:format(table.concat(never, ", ")))
    end
    if soonest then
        passTimer = passTimer + 1
        local mine = passTimer
        C_Timer.After(math.max(1, soonest), function()
            if passTimer == mine then
                pcall(UpdatePasses)
            end
        end)
    end
end
ns.UpdatePasses = UpdatePasses

-- Only for players who are muted right now.
local function GrantPass(key, joined, name)
    if not ns.IsMuted(key) then
        return false
    end
    ns.db.passes[key] = { joined = joined, t = time(), name = name }
    ns.DataChanged(true)
    pcall(UpdatePasses) -- schedules the checks that end it on time
    return true
end

-- members: list of { key, name }
local function GrantPasses(members, joined)
    local names = {}
    for _, member in ipairs(members) do
        if GrantPass(member.key, joined, member.name) then
            names[#names + 1] = member.name
        end
    end
    if #names > 0 then
        local list = table.concat(names, ", ")
        Print(L["unmuted while you're grouped: %s. They're muted again when the group ends."]:format(list))
    end
end

---------------------------------------------------------------------------
-- Muted players in your group
-- Asked once per player per group. Answers are saved in db.groupWarned so a
-- /reload mid-group doesn't ask again.
---------------------------------------------------------------------------
local warnedInGroup = {} -- key -> true once shown this group
local groupPopup -- members listed in the open group window
local invitePopupKey -- player the open invite window is about
local invitesSent = {} -- lowercase name -> time you invited them

local function NeedsGroupWarning(key)
    return ns.IsMuted(key) and not warnedInGroup[key] and not ns.db.groupWarned[key]
end

local function CheckGroupForMuted()
    local db = ns.db
    if not db.groupWarn then
        return
    end
    if not IsInGroup() then
        wipe(warnedInGroup)
        wipe(db.groupWarned)
        return
    end
    local present = ns.GroupKeys()
    -- The player you invited has joined: the group window takes over.
    if invitePopupKey and present[invitePopupKey] then
        invitePopupKey = nil
        StaticPopup_Hide("MUTEGUILDS_INVITE")
    end
    local found, listed = {}, {}
    for key, unit in pairs(present) do
        if NeedsGroupWarning(key) then
            warnedInGroup[key] = true
            listed[key] = true
            local name = ns.UnitNameString(unit) or key
            found[#found + 1] = { key = key, name = name, guild = ns.TagText(db.players[key]) }
        end
    end
    if #found == 0 then
        return
    end
    -- A window is already open: add the new players to it instead of replacing it.
    if groupPopup and StaticPopup_Visible("MUTEGUILDS_GROUP") then
        for _, member in ipairs(groupPopup) do
            if not listed[member.key] and present[member.key] and ns.IsMuted(member.key) then
                listed[member.key] = true
                found[#found + 1] = member
            end
        end
    end
    table.sort(found, function(a, b)
        return a.name < b.name
    end)
    local lines = {}
    for i, member in ipairs(found) do
        lines[i] = ("%s <%s>"):format(member.name, member.guild)
    end
    groupPopup = found
    if not StaticPopup_Show("MUTEGUILDS_GROUP", table.concat(lines, "\n"), nil, found) then
        groupPopup = nil
        Print(L["|cffff5555muted in your group:|r %s. Their chat is hidden."]:format(table.concat(lines, ", ")))
    end
end
ns.CheckGroupForMuted = CheckGroupForMuted

-- Roster updates arrive in bursts (several per join or leave): handle the
-- burst once, ~0.1 s after it starts. Guild info for new members can arrive a
-- moment late, so look once more two seconds later.
local rosterQueued, recheckQueued = false, false

local function OnRosterSettled()
    rosterQueued = false
    ns.ScanGroup()
    pcall(UpdatePasses)
    pcall(CheckGroupForMuted)
    if not recheckQueued then
        recheckQueued = true
        C_Timer.After(2, function()
            recheckQueued = false
            ns.ScanGroup()
            pcall(CheckGroupForMuted)
        end)
    end
end

function ns.OnRosterChanged()
    if not rosterQueued then
        rosterQueued = true
        C_Timer.After(0.1, OnRosterSettled)
    end
end

-- A real answer in the group window: don't ask about these players again in
-- this group.
local function MarkAnswered(members)
    for _, member in ipairs(members) do
        ns.db.groupWarned[member.key] = true
    end
end

StaticPopupDialogs["MUTEGUILDS_GROUP"] = {
    text = L["Muted players in your group:\n\n%s\n\nYou won't see their party chat."],
    button1 = L["Unmute while grouped"],
    button2 = L["Keep muted"],
    button3 = L["Unmute forever"],
    OnAccept = function(_, members)
        groupPopup = nil
        MarkAnswered(members)
        local present, still = ns.GroupKeys(), {}
        for _, member in ipairs(members) do
            if present[member.key] then
                still[#still + 1] = member
            end
        end
        if #still > 0 then
            GrantPasses(still, true)
        else
            Print(L["they've already left your group."])
        end
    end,
    OnCancel = function(_, members, reason)
        if not members then
            return
        end
        if reason == "clicked" then -- Keep muted / Escape
            groupPopup = nil
            MarkAnswered(members)
        elseif reason == "override" and groupPopup == members then
            -- Closed by something else (like logout): ask again later.
            groupPopup = nil
            for _, member in ipairs(members) do
                warnedInGroup[member.key] = nil
            end
        end
    end,
    OnAlt = function(_, members)
        groupPopup = nil
        MarkAnswered(members)
        for _, member in ipairs(members) do
            ns.NeverMute(member.key, member.name)
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

---------------------------------------------------------------------------
-- Inviting a muted player
-- The game sends an invite the moment you click, so the warning can only come
-- right after. "Cancel invite" withdraws it before they can accept.
---------------------------------------------------------------------------
local function CancelInvite(name)
    pcall(C_PartyInfo.UninviteUnit, name)
    -- While an invite is pending the game holds you in a group of one, and
    -- leaving it cancels the invite for certain. Leaving also withdraws any
    -- other invites you just sent, so only do it when this was the only one.
    local lower, others = name:lower(), false
    for sentTo, t in pairs(invitesSent) do
        if GetTime() - t > JOIN_LIMIT then
            invitesSent[sentTo] = nil
        elseif sentTo ~= lower then
            others = true
        end
    end
    if GetNumGroupMembers() <= 1 and IsInGroup() and not others then
        pcall(C_PartyInfo.LeaveParty)
    end
    invitesSent[lower] = nil
    Print(L["cancelled the invite to %s."]:format(name))
end

StaticPopupDialogs["MUTEGUILDS_INVITE"] = {
    text = L["%s is on your MuteGuilds list <%s>.\n\nIf they join, you won't see their party chat."],
    button1 = L["Unmute while grouped"],
    button2 = L["Keep muted"],
    button3 = L["Cancel invite"],
    OnAccept = function(_, data)
        invitePopupKey = nil
        GrantPasses({ data }, false)
    end,
    OnCancel = function(_, data, reason)
        -- Only a real "Keep muted" (or Escape) counts as an answer, not the
        -- window being replaced or closed by logout.
        if reason ~= "clicked" or not data then
            return
        end
        invitePopupKey = nil
        warnedInGroup[data.key] = true
        ns.db.groupWarned[data.key] = true
    end,
    OnAlt = function(_, data)
        invitePopupKey = nil
        CancelInvite(data.name)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function OnInviteSent(target)
    if type(target) ~= "string" or target == "" or IsSecret(target) then
        return
    end
    invitesSent[target:lower()] = GetTime()
    if not ns.db.whisperWarn then
        return
    end
    local guild, key = ns.MutedGuildForName(target)
    if not guild then
        return
    end
    invitePopupKey = key
    if not StaticPopup_Show("MUTEGUILDS_INVITE", target, guild, { key = key, name = target }) then
        invitePopupKey = nil
        local text = L["invited %s, who's |cffff5555muted|r <%s>. You won't see their party chat."]
        ns.PrintThrottled("invite:" .. key, text:format(target, guild))
    end
end

---------------------------------------------------------------------------
-- Whispering a muted player
-- An addon can't put a confirm step in front of Blizzard's Send, so the
-- warning comes while typing: the chat box header turns red and one line
-- explains that their replies will be hidden.
---------------------------------------------------------------------------
local warnedWhisper = {} -- key -> true once told this session

-- guid: the character ID the game sends with a whisper you sent, if known.
local function WarnWhisper(target, guid)
    local guild, key = ns.MutedGuildForName(target)
    if not guild and guid and not IsSecret(guid) then
        local guidKey = ns.db.guids[guid]
        if ns.IsMuted(guidKey) then
            guild, key = ns.TagText(ns.db.players[guidKey]), guidKey
        end
    end
    if not guild then
        return false
    end
    if not warnedWhisper[key] then
        warnedWhisper[key] = true
        Print(L["%s is |cffff5555muted|r <%s>. You won't see their replies."]:format(target, guild))
    end
    return true
end

local function CheckWhisperBox(editBox)
    if not ns.db.whisperWarn or editBox:GetAttribute("chatType") ~= "WHISPER" then
        return
    end
    local target = editBox:GetAttribute("tellTarget")
    if type(target) ~= "string" or target == "" or IsSecret(target) then
        return
    end
    if WarnWhisper(target) and editBox.header then
        editBox.header:SetTextColor(1, 0.25, 0.25)
    end
end

-- CHAT_MSG_WHISPER_INFORM: the same note right after a whisper is sent, for
-- whispers that didn't go through a chat box header update.
function ns.OnWhisperSent(target, guid)
    if ns.db.whisperWarn and type(target) == "string" and not IsSecret(target) then
        pcall(WarnWhisper, target, guid)
    end
end

local hookedBoxes = {}
function ns.HookEditBoxes()
    for _, frame in ipairs(ns.ChatFrames()) do
        local editBox = frame.editBox
        if editBox and not hookedBoxes[editBox] and type(editBox.UpdateHeader) == "function" then
            hookedBoxes[editBox] = true
            hooksecurefunc(editBox, "UpdateHeader", function(box)
                pcall(CheckWhisperBox, box)
            end)
        end
    end
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------
local function OnTooltipUnit(tooltip)
    if not ns.db or not tooltip.GetUnit then
        return
    end
    local _, unit = tooltip:GetUnit()
    if not unit or IsSecret(unit) or not UnitIsPlayer(unit) then
        return
    end
    ns.ScanUnit(unit) -- learn them now so the very first tooltip is right
    local key = ns.UnitKey(unit)
    local db = ns.db
    if not key then
        return
    end
    if db.allow[key] then
        tooltip:AddLine(L["MuteGuilds: never muted"], 0.4, 1, 0.4)
    elseif db.players[key] and db.passes[key] then
        tooltip:AddLine(L["MuteGuilds: unmuted while grouped"], 1, 0.82, 0)
    elseif db.players[key] then
        tooltip:AddLine(L["Muted by MuteGuilds <%s>"]:format(ns.TagText(db.players[key])), 1, 0.3, 0.3)
    elseif ns.FormerGuild(key) then
        -- No longer in the guild they were muted for, so no longer muted.
        tooltip:AddLine(L["MuteGuilds: was in a muted guild before <%s>"]:format(ns.FormerGuild(key)), 1, 0.6, 0.2)
    end
end

-- Called once at login.
function ns.InstallSocialHooks()
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
        pcall(OnTooltipUnit, tooltip)
    end)
    hooksecurefunc(C_PartyInfo, "InviteUnit", function(name)
        pcall(OnInviteSent, name)
    end)
    ns.HookEditBoxes()
    -- Older chat code updates the header through this global instead of the
    -- edit box method; which one this client uses is not confirmed yet.
    if ChatEdit_UpdateHeader then
        hooksecurefunc("ChatEdit_UpdateHeader", function(box)
            pcall(CheckWhisperBox, box)
        end)
    end
end
