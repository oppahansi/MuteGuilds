-- Bubbles.lua: hides chat bubbles of muted players.
-- The game draws bubbles separately from the chat window. After a muted
-- player's say/yell/party/raid message, look for a bubble with that exact text
-- and make it invisible. Bubbles inside dungeons and raids are locked away from
-- addons, so this only works in the open world.

local _, ns = ...
local IsSecret = ns.IsSecret

ns.BUBBLE_EVENTS = {
    CHAT_MSG_SAY = true,
    CHAT_MSG_YELL = true,
    CHAT_MSG_PARTY = true,
    CHAT_MSG_PARTY_LEADER = true,
    CHAT_MSG_RAID = true,
    CHAT_MSG_RAID_LEADER = true,
}

local MUTED_FOR, ALLOWED_FOR, WATCH_FOR = 5, 10, 1.5 -- seconds
local mutedTexts = {} -- text -> time it stops being hidden
local allowedTexts = {} -- text an unmuted player just said -> time; never hidden
local hiddenHolders = {} -- bubble frames made invisible
local watchUntil, lastPrune = 0, 0

local watcher = CreateFrame("Frame")
watcher:Hide()

local function BubbleHolder(bubble)
    local holder = bubble:GetChildren()
    if holder and holder.String then
        return holder
    end
    if bubble.String then
        return bubble
    end
end

-- Drop expired texts, at most once a second.
local function Prune(now)
    if now - lastPrune < 1 then
        return
    end
    lastPrune = now
    for text, t in pairs(mutedTexts) do
        if t < now then
            mutedTexts[text] = nil
        end
    end
    for text, t in pairs(allowedTexts) do
        if t < now then
            allowedTexts[text] = nil
        end
    end
end

local function ScanBubbles()
    local now = GetTime()
    Prune(now)
    for _, bubble in pairs(C_ChatBubbles.GetAllChatBubbles(false)) do
        local holder = BubbleHolder(bubble)
        if holder then
            local text = holder.String:GetText()
            local usable = text and not IsSecret(text)
            local mutedUntil = usable and mutedTexts[text]
            local allowedUntil = usable and allowedTexts[text]
            -- Same text from a muted and an unmuted player: leave it visible.
            if mutedUntil and mutedUntil >= now and not (allowedUntil and allowedUntil >= now) then
                if not hiddenHolders[holder] then
                    holder:SetAlpha(0)
                    hiddenHolders[holder] = true
                end
            elseif hiddenHolders[holder] then
                holder:SetAlpha(1) -- bubble reused for someone else
                hiddenHolders[holder] = nil
            end
        end
    end
end

local sinceScan = 0
watcher:SetScript("OnUpdate", function(self, elapsed)
    sinceScan = sinceScan + elapsed
    if sinceScan < 0.1 then
        return -- 10 checks a second at most
    end
    sinceScan = 0
    pcall(ScanBubbles)
    if GetTime() > watchUntil then
        self:Hide()
    end
end)

-- Called for every bubble-type message. Bubbles get reused, so messages from
-- unmuted players are watched too, to restore a bubble hidden earlier.
local function Watch(text, muted)
    local now = GetTime()
    Prune(now)
    local usable = type(text) == "string" and not IsSecret(text)
    if usable and muted then
        mutedTexts[text] = now + MUTED_FOR
        -- An unmuted player said this first: keep their bubble safe for as long.
        local allowedUntil = allowedTexts[text]
        if allowedUntil and allowedUntil >= now and allowedUntil < now + MUTED_FOR then
            allowedTexts[text] = now + MUTED_FOR
        end
    elseif usable then
        allowedTexts[text] = now + ALLOWED_FOR
        muted = mutedTexts[text] ~= nil -- scan now to put a matching bubble back
    end
    if muted or next(hiddenHolders) then
        watchUntil = now + WATCH_FOR
        watcher:Show()
    end
end

-- Handler for the events in ns.BUBBLE_EVENTS. This runs from the event, not
-- from the chat filter, so bubbles are hidden even when no chat tab shows that
-- kind of chat.
function ns.OnBubbleMessage(msg, author, _, _, _, flag, _, _, _, _, _, guid)
    local db = ns.db
    if not db.enabled or not db.hideBubbles or ns.IsDryRun() then
        return
    end
    if IsSecret(author) or IsSecret(guid) then
        return
    end
    if IsSecret(flag) or type(flag) ~= "string" then
        flag = nil
    end
    Watch(msg, (ns.Evaluate(author, guid, flag)))
end

-- Put back every bubble that was hidden (filtering or the option turned off).
function ns.RestoreBubbles()
    for holder in pairs(hiddenHolders) do
        pcall(holder.SetAlpha, holder, 1)
    end
    wipe(hiddenHolders)
    wipe(mutedTexts)
    wipe(allowedTexts)
    watcher:Hide()
end
