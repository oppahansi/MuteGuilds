-- Scan.lua: finds members of the listed guilds with /who.
-- /who returns only the first 50 matches, so one search can't cover a large
-- guild. Each scan runs the next search in a rotation: every listed guild,
-- split into level ranges, reaching members a plain search cuts off.

local _, ns = ...
local L = ns.L
local Print = ns.Print

local COOLDOWN = 5 -- seconds between scans; the server throttles /who
local step = 0 -- position in the rotation
local lastScanAt = -COOLDOWN
local sentAt, stepBeforeSend -- the last search: when it went out, and from which step
local queriesBound -- level bound ns.scanQueries was built for

-- Highest level worth searching: nobody in a listed guild was seen above it.
local function LevelBound()
    local seen = math.max(ns.db.maxSeenLevel or 0, UnitLevel("player") or 1)
    return math.min(GetMaxPlayerLevel(), seen)
end

local function BuildQueries(maxLevel)
    local queries = {}
    local cap = GetMaxPlayerLevel()
    for _, guild in ipairs(ns.GuildNames()) do
        local base = 'g-"' .. guild .. '"'
        queries[#queries + 1] = base
        -- Members above any level seen so far: one search for all of them, so
        -- a full first search can't hide them forever.
        if maxLevel < cap then
            queries[#queries + 1] = ("%s %d-%d"):format(base, maxLevel + 1, cap)
        end
        local low = 1
        while low <= maxLevel - 4 do
            queries[#queries + 1] = ("%s %d-%d"):format(base, low, low + 3)
            low = low + 4
        end
        for level = low, maxLevel do -- most players sit near the cap: one level each
            queries[#queries + 1] = ("%s %d-%d"):format(base, level, level)
        end
    end
    return queries
end

-- The rotation is rebuilt when the guild list changes or a higher level is
-- seen (both clear ns.scanQueries) or the level bound moves.
local function Queries()
    local bound = LevelBound()
    if not ns.scanQueries or queriesBound ~= bound then
        ns.scanQueries, queriesBound = BuildQueries(bound), bound
    end
    return ns.scanQueries
end

function ns.ScanCooldownLeft()
    return COOLDOWN - (GetTime() - lastScanAt)
end

-- Next step number and number of steps, for the scan button.
function ns.ScanProgress()
    local total = #Queries()
    return total > 0 and step % total + 1 or 0, total
end

function ns.WhoScan()
    local queries = Queries()
    if #queries == 0 then
        Print(L["the guild list is empty, nothing to scan."])
        return
    end
    local left = ns.ScanCooldownLeft()
    if left > 0 then
        Print(L["next scan ready in %d s."]:format(math.ceil(left)))
        return
    end
    stepBeforeSend = step
    step = step % #queries + 1
    lastScanAt = GetTime()
    C_FriendList.SendWho(queries[step])
    Print(L["scan %d/%d: /who %s"]:format(step, #queries, queries[step]))
    -- Listen for the server's "too soon" notice only after our own lines.
    sentAt = GetTime()
    ns.RefreshViews()
end

-- "You must wait a moment longer before using /who again": the search didn't
-- run, so step back and let the next scan repeat it. Called for every line
-- added to chat; only looks in the 2 seconds after a scan.
-- The notice is the game's own text, so it is recognised by words from it. The
-- German ones are a guess at its wording: not confirmed yet.
local THROTTLE_COMMANDS = { "/who", "/wer" }
local THROTTLE_WORDS = { "wait", "again", "warte", "erneut", "wieder" }

local function FindAny(text, words)
    for _, word in ipairs(words) do
        if text:find(word, 1, true) then
            return true
        end
    end
    return false
end

function ns.CheckWhoThrottle(msg)
    if not sentAt or GetTime() - sentAt > 2 then
        return
    end
    -- Not our own lines, and not players' chat.
    if msg:sub(1, #ns.PREFIX) == ns.PREFIX or msg:find("|Hplayer:", 1, true) then
        return
    end
    local text = msg:lower()
    if FindAny(text, THROTTLE_COMMANDS) and FindAny(text, THROTTLE_WORDS) then
        step, sentAt = stepBeforeSend, nil
        lastScanAt = GetTime()
        Print(L["the server wanted a longer pause; that search will run again on your next scan."])
        ns.RefreshViews()
    end
end
