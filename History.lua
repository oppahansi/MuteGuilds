-- History.lua: removes lines a newly muted player already has in the chat
-- windows. New messages are handled by the chat filter; this is the cleanup of
-- older ones.

local _, ns = ...
local IsSecret = ns.IsSecret

-- True if a stored chat line was sent by one of the players in keys.
-- When the game tells us which event a line came from and who sent it, use
-- that: only incoming chat, matched on the sender (not on any name linked in
-- the line, which would also catch your own whispers to them). Otherwise fall
-- back to the player link in the text.
local function LineIsFrom(keys, msg, typeID, event, args)
    if type(msg) == "table" then
        msg = msg.message
    end
    -- Lines copied into a whisper tab carry no event, only their chat type:
    -- keep the whispers you sent.
    if event == nil and type(typeID) == "number" and not IsSecret(typeID) then
        local ok, chatType = pcall(ChatHistory_GetChatType, typeID)
        if ok and (chatType == "WHISPER_INFORM" or chatType == "BN_WHISPER_INFORM") then
            return false
        end
    end
    if type(event) == "string" and not IsSecret(event) then
        if not ns.INCOMING_EVENTS[event] then
            return false
        end
        if type(args) == "table" and not IsSecret(args) then
            local guid = args[12]
            if type(guid) == "string" and not IsSecret(guid) then
                local key = ns.db.guids[guid]
                if key and keys[key] then
                    return true
                end
            end
            local author = args[2]
            if type(author) == "string" and not IsSecret(author) and author ~= "" then
                local key = ns.Normalize(author)
                return key ~= nil and keys[key] == true
            end
            return false
        end
    end
    if type(msg) ~= "string" or IsSecret(msg) then
        return false
    end
    -- Only links with a line ID (real chat). Bare links are /who results and
    -- system lines, which are kept so a /who you just ran doesn't vanish.
    for target in msg:gmatch("|Hplayer:([^:|]+):") do
        if keys[ns.Normalize(target)] then
            return true
        end
    end
    return false
end

local function PurgeFrame(frame, keys)
    frame:RemoveMessagesByPredicate(function(msg, _, _, _, _, _, typeID, event, args)
        return LineIsFrom(keys, msg, typeID, event, args)
    end)
end

-- Removal is queued instead of done on the spot: nameplates and mouseover can
-- identify many players in a moment in a busy city. Players found within
-- ~0.1 s are combined into one batch, and the batch sweeps one chat window per
-- frame so no single frame does all the work.
local pending, queued = {}, false -- keys waiting for the next batch
local batch, frames, index -- the batch being worked on
local worker = CreateFrame("Frame")
worker:Hide()

-- Recheck each key right before its lines go: the player may have been
-- unmuted, allowed or given a pass since being queued.
local function StillMuted(keys)
    local live = {}
    for key in pairs(keys) do
        if ns.IsMuted(key) then
            live[key] = true
        end
    end
    return live
end

local function Finish()
    batch, frames, index = nil, nil, nil
    worker:Hide()
end

local function Start()
    queued = false
    if batch or not next(pending) then
        return -- the running batch picks the rest up when it ends
    end
    batch, pending = pending, {}
    frames, index = ns.ChatFrames(), 0
    worker:Show()
end

worker:SetScript("OnUpdate", function()
    index = index + 1
    local frame = frames[index]
    local live = frame and ns.db.enabled and StillMuted(batch)
    if not live or not next(live) then
        Finish()
        if ns.db.enabled and next(pending) then
            Start() -- players found while this batch ran
        end
        return
    end
    if frame.RemoveMessagesByPredicate then
        pcall(PurgeFrame, frame, live)
    end
end)

function ns.PurgeHistory(key)
    if not key or not ns.db.enabled or ns.IsDryRun() then
        return
    end
    pending[key] = true
    if not queued then
        queued = true
        C_Timer.After(0.1, Start)
    end
end

-- Filtering turned off: drop queued removals.
function ns.CancelPurges()
    wipe(pending)
    Finish()
end
