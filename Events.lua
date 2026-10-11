-- Events.lua: start-up and the game events the addon reacts to. Loaded last.
-- Each handler only forwards to the module that owns the behavior.

local ADDON, ns = ...
local IsSecret = ns.IsSecret

local frame = CreateFrame("Frame")
local handlers = {}

-- Whisper pop-out tabs are created later: hook them as they open. A tab the
-- game opened for a new whisper is empty if that whisper was hidden, so it is
-- closed again right after.
local function OnTemporaryWindowOpened(chatType, chatTarget, sourceChatFrame)
    ns.HookChatFrames()
    ns.HookEditBoxes()
    local openedByGame = chatType == "WHISPER" and sourceChatFrame == nil
    if not openedByGame or type(chatTarget) ~= "string" or IsSecret(chatTarget) or not ns.db.enabled then
        return
    end
    C_Timer.After(0, function()
        for _, chatFrame in ipairs(ns.ChatFrames()) do
            if
                chatFrame.isTemporary
                and chatFrame.chatType == "WHISPER"
                and chatFrame.chatTarget == chatTarget
                and chatFrame:GetNumMessages() == 0
            then
                pcall(FCF_Close, chatFrame)
            end
        end
    end)
end

-- A /who result or a stale saved entry must never put you on your own list.
local function RemoveSelf()
    local db = ns.db
    local drop = {}
    if ns.playerKey and db.players[ns.playerKey] ~= nil then
        drop[ns.playerKey] = true
    end
    local ownKey = ns.playerGUID and db.guids[ns.playerGUID]
    if ownKey then
        db.guids[ns.playerGUID] = nil
        drop[ownKey] = true
    end
    ns.UnblockMany(drop)
end

function handlers.ADDON_LOADED(name)
    if name == ADDON then
        frame:UnregisterEvent("ADDON_LOADED")
        ns.InitDB()
    end
end

function handlers.PLAYER_LOGIN()
    ns.playerGUID = UnitGUID("player")
    ns.playerKey = ns.Normalize(ns.UnitNameString("player"))
    RemoveSelf()

    frame:UnregisterEvent("PLAYER_LOGIN")
    for event in pairs(handlers) do
        -- Not every event exists on every client build.
        if event ~= "ADDON_LOADED" and event ~= "PLAYER_LOGIN" then
            pcall(frame.RegisterEvent, frame, event)
        end
    end
    for event in pairs(ns.BUBBLE_EVENTS) do
        frame:RegisterEvent(event)
    end

    ns.ScanGroup()
    ns.HookChatFrames()
    ns.Try(ns.InstallSocialHooks)
    -- You answered an invite yourself: forget it, so nothing declines it later.
    hooksecurefunc("DeclineGroup", ns.OnPartyInviteClosed)
    hooksecurefunc("AcceptGroup", ns.OnPartyInviteClosed)
    hooksecurefunc("FCF_OpenTemporaryWindow", function(...)
        pcall(OnTemporaryWindowOpened, ...)
    end)
    ns.Try(ns.CreateOptionsPanel)

    -- Saved passes and answers: check them once group info has loaded. The
    -- group may have broken up while you were offline.
    C_Timer.After(5, function()
        pcall(ns.UpdatePasses)
        if not IsInGroup() then
            wipe(ns.db.groupWarned)
        end
    end)

    if ns.db.debugMode ~= "off" then
        ns.Print(ns.L["debug mode %s"]:format(ns.DebugModeText()))
    end
end

function handlers.PLAYER_TARGET_CHANGED()
    ns.ScanUnit("target")
end

function handlers.UPDATE_MOUSEOVER_UNIT()
    ns.ScanUnit("mouseover")
end

function handlers.NAME_PLATE_UNIT_ADDED(unit)
    ns.ScanUnit(unit)
end

function handlers.GROUP_ROSTER_UPDATE()
    if IsInGroup() then
        ns.OnPartyInviteClosed()
    end
    ns.OnRosterChanged()
end

function handlers.WHO_LIST_UPDATE()
    pcall(ns.ScanWhoList)
end

function handlers.CHAT_MSG_SYSTEM(msg)
    ns.OnSystemMessage(msg)
end

function handlers.CHAT_MSG_ADDON(...)
    ns.OnAddonMessage(...)
end

-- arg2: who you whispered, arg12: their GUID
function handlers.CHAT_MSG_WHISPER_INFORM(_, target, ...)
    ns.OnWhisperSent(target, (select(10, ...)))
end

function handlers.GUILD_INVITE_REQUEST(inviter, guildName)
    ns.Try(ns.OnGuildInviteRequest, inviter, guildName)
end

function handlers.PARTY_INVITE_REQUEST(...)
    ns.Try(ns.OnPartyInviteRequest, ...)
end

function handlers.PARTY_INVITE_CANCEL()
    ns.OnPartyInviteClosed()
end

function handlers.DUEL_REQUESTED(challenger)
    ns.Try(ns.OnDuelRequested, challenger, "DUEL_REQUESTED")
end

function handlers.DUEL_TO_THE_DEATH_REQUESTED(challenger)
    ns.Try(ns.OnDuelRequested, challenger, "DUEL_TO_THE_DEATH_REQUESTED")
end

function handlers.DUEL_FINISHED()
    ns.OnDuelFinished()
end

function handlers.TRADE_REQUEST(name)
    ns.Try(ns.OnTrade, name)
end

function handlers.TRADE_SHOW()
    ns.Try(ns.OnTrade, nil)
end

function handlers.TRADE_CLOSED()
    ns.OnTradeEnded()
end

function handlers.TRADE_REQUEST_CANCEL()
    ns.OnTradeEnded()
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, ...)
    local handler = handlers[event]
    if handler then
        handler(...)
    elseif ns.BUBBLE_EVENTS[event] then
        pcall(ns.OnBubbleMessage, ...)
    end
end)
