-- Windows.lua: the muted-players list window and the muted-messages log window.
-- Both are built on first use.

local _, ns = ...
local IsSecret, Print = ns.IsSecret, ns.Print

local ROW_HEIGHT = 16

---------------------------------------------------------------------------
-- Shared pieces
---------------------------------------------------------------------------

-- A movable dialog that Escape closes.
local function CreateWindow(globalName, width, height)
    local window = CreateFrame("Frame", globalName, UIParent, "BasicFrameTemplateWithInset")
    window:SetSize(width, height)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:SetClampedToScreen(true)
    tinsert(UISpecialFrames, globalName)
    window.title = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    window.title:SetPoint("TOP", 0, -6)
    window:Hide()
    return window
end

-- Scrolling for a window that shows a fixed number of rows out of a longer
-- list. render(offset) fills the rows starting after that many entries.
local function CreateScroller(window, top, bottom, rowCount, render)
    local scroller = { offset = 0 }

    local bar = CreateFrame("Slider", nil, window)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(14)
    bar:SetPoint("TOPRIGHT", -14, -top)
    bar:SetPoint("BOTTOMRIGHT", -14, bottom)
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(0, 0, 0, 0.35)
    local thumb = bar:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
    thumb:SetSize(18, 24)
    bar:SetThumbTexture(thumb)
    bar:SetMinMaxValues(0, 0)
    bar:SetValueStep(1)
    bar:SetObeyStepOnDrag(true)
    bar:SetValue(0)
    bar:SetScript("OnValueChanged", function(_, value)
        scroller.offset = math.floor(value + 0.5)
        render(scroller.offset)
    end)

    window:EnableMouseWheel(true)
    window:SetScript("OnMouseWheel", function(_, delta)
        bar:SetValue(bar:GetValue() - delta * 3)
    end)

    -- Call when the list changed: total is its new length.
    function scroller:Update(total)
        local maxOffset = math.max(0, total - rowCount)
        bar:SetMinMaxValues(0, maxOffset)
        bar:SetShown(maxOffset > 0)
        self.offset = math.min(self.offset, maxOffset)
        bar:SetValue(self.offset)
        render(self.offset)
    end

    function scroller:ToTop()
        self.offset = 0
    end

    return scroller
end

local function Toggle(window)
    window:SetShown(not window:IsShown())
end

---------------------------------------------------------------------------
-- Muted-players list
---------------------------------------------------------------------------
local LIST_ROWS, LIST_TOP = 24, 60
local listWindow

-- One line per entry, filtered by the search text: never-muted players first,
-- then the muted ones. Returns lines, muted players in total.
local function BuildListLines(search)
    local db = ns.db
    local filter = search ~= "" and search:lower() or nil
    local lines = {}

    local allowed = {}
    for key in pairs(db.allow) do
        if not filter or key:find(filter, 1, true) then
            allowed[#allowed + 1] = key
        end
    end
    table.sort(allowed)
    for _, key in ipairs(allowed) do
        lines[#lines + 1] = "|cff66ff66never muted|r  " .. key
    end

    local total, muted = 0, {}
    for key, guild in pairs(db.players) do
        total = total + 1
        local guildLower = guild:lower()
        if not filter or key:find(filter, 1, true) or guildLower:find(filter, 1, true) then
            muted[#muted + 1] = { key = key, guild = guild, guildLower = guildLower }
        end
    end
    local byGuild = db.listSort == "guild"
    table.sort(muted, function(a, b)
        if byGuild and a.guildLower ~= b.guildLower then
            return a.guildLower < b.guildLower
        end
        return a.key < b.key
    end)
    for _, entry in ipairs(muted) do
        local guild = "|cff999999<" .. entry.guild .. ">|r"
        lines[#lines + 1] = byGuild and (guild .. "  " .. entry.key) or (entry.key .. "  " .. guild)
    end
    return lines, total
end

local function CreateListWindow()
    local window = CreateWindow("MuteGuildsListWindow", 440, 480)
    local lines = {}

    local search = CreateFrame("EditBox", nil, window, "InputBoxTemplate")
    search:SetSize(200, 20)
    search:SetPoint("TOPLEFT", 22, -32)
    search:SetAutoFocus(false)
    local hint = search:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    hint:SetPoint("LEFT", 4, 0)
    hint:SetText("Search name or guild")
    local found = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    found:SetPoint("LEFT", search, "RIGHT", 10, 0)

    local rows = {}
    for i = 1, LIST_ROWS do
        local row = window:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row:SetPoint("TOPLEFT", 18, -(LIST_TOP + (i - 1) * ROW_HEIGHT))
        row:SetPoint("RIGHT", window, "RIGHT", -34, 0)
        row:SetJustifyH("LEFT")
        row:SetWordWrap(false)
        rows[i] = row
    end

    local scroller = CreateScroller(window, LIST_TOP, 16, LIST_ROWS, function(offset)
        for i = 1, LIST_ROWS do
            rows[i]:SetText(lines[offset + i] or "")
        end
    end)

    function window:Refresh()
        local text = search:GetText() or ""
        local total
        lines, total = BuildListLines(text)
        self.title:SetText(("MuteGuilds: muted players (%s)"):format(ns.FormatNum(total)))
        hint:SetShown(text == "" and not search:HasFocus())
        found:SetText(text ~= "" and ("%s found"):format(ns.FormatNum(#lines)) or "")
        if #lines == 0 then
            lines = { text ~= "" and "|cff999999No matches.|r" or "|cff999999No players muted yet.|r" }
        end
        scroller:Update(#lines)
    end

    local sortButton = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    sortButton:SetSize(110, 22)
    sortButton:SetPoint("TOPRIGHT", -16, -30)
    local function UpdateSortLabel()
        sortButton:SetText(ns.db.listSort == "guild" and "Sort: Guild" or "Sort: Name")
    end
    UpdateSortLabel()
    sortButton:SetScript("OnClick", function()
        ns.db.listSort = ns.db.listSort == "guild" and "name" or "guild"
        UpdateSortLabel()
        scroller:ToTop()
        window:Refresh()
    end)

    search:SetScript("OnTextChanged", function()
        scroller:ToTop()
        window:Refresh()
    end)
    search:SetScript("OnEditFocusGained", function()
        hint:Hide()
    end)
    search:SetScript("OnEditFocusLost", function()
        hint:SetShown((search:GetText() or "") == "")
    end)
    search:SetScript("OnEscapePressed", search.ClearFocus)
    search:SetScript("OnEnterPressed", search.ClearFocus)

    window:SetScript("OnShow", window.Refresh)
    return window
end

function ns.ToggleListWindow()
    listWindow = listWindow or CreateListWindow()
    Toggle(listWindow)
end

---------------------------------------------------------------------------
-- Muted-messages log: see what was hidden, report what deserves it.
---------------------------------------------------------------------------
local LOG_ROWS, LOG_TOP = 22, 56
local logWindow

local CHANNEL_LABEL = {
    CHAT_MSG_SAY = "Say",
    CHAT_MSG_YELL = "Yell",
    CHAT_MSG_EMOTE = "Emote",
    CHAT_MSG_TEXT_EMOTE = "Emote",
    CHAT_MSG_WHISPER = "Whisper",
    CHAT_MSG_CHANNEL = "Channel",
    CHAT_MSG_GUILD = "Guild",
    CHAT_MSG_OFFICER = "Officer",
    CHAT_MSG_PARTY = "Party",
    CHAT_MSG_PARTY_LEADER = "Party",
    CHAT_MSG_RAID = "Raid",
    CHAT_MSG_RAID_LEADER = "Raid",
    CHAT_MSG_RAID_WARNING = "Raid Warning",
    CHAT_MSG_INSTANCE_CHAT = "Instance",
    CHAT_MSG_INSTANCE_CHAT_LEADER = "Instance",
    CHAT_MSG_AFK = "Auto-reply",
    CHAT_MSG_DND = "Auto-reply",
}

local function ShortName(author)
    return author:match("^[^%-]+") or author
end

-- The text as the reader would see it: no colors, link data or textures.
local function PlainText(msg)
    return (msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", ""))
end

local CANT_REPORT = "You can still report the player from their right-click menu."

-- Opens Blizzard's report window for a logged chat line.
local function ReportEntry(entry)
    if not entry.lineID then
        Print("this message can't be reported from here. " .. CANT_REPORT)
        return
    end
    local ok, err = pcall(function()
        local location = PlayerLocation:CreateFromChatLineID(entry.lineID)
        if not C_ReportSystem.CanReportPlayer(location) then
            Print("this message can't be reported anymore (it may be too old). " .. CANT_REPORT)
            return
        end
        local info = ReportInfo:CreateReportInfoFromType(Enum.ReportType.Chat)
        ReportFrame:InitiateReport(info, entry.author, location)
    end)
    if not ok then
        Print("couldn't open the report window: " .. tostring(err))
    end
end

StaticPopupDialogs["MUTEGUILDS_LOGMSG"] = {
    text = "%s said:\n\n%s",
    button1 = "Report...",
    button2 = CLOSE,
    button3 = "Never mute",
    OnAccept = function(_, entry)
        ReportEntry(entry)
    end,
    OnAlt = function(_, entry)
        local key = entry.guid and not IsSecret(entry.guid) and ns.db.guids[entry.guid]
        ns.NeverMute(key or ns.Normalize(entry.author), ShortName(entry.author))
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function OpenLogEntry(entry)
    local text = PlainText(entry.text)
    if #text > 220 then
        text = text:sub(1, 220) .. "..."
    end
    local who = ("%s (%s, %s)"):format(ShortName(entry.author), CHANNEL_LABEL[entry.event] or "Chat", entry.clock)
    StaticPopup_Show("MUTEGUILDS_LOGMSG", who, '"' .. text .. '"', entry)
end

local function CreateLogRow(window, index)
    local row = CreateFrame("Button", nil, window)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 16, -(LOG_TOP + (index - 1) * ROW_HEIGHT))
    row:SetPoint("RIGHT", window, "RIGHT", -34, 0)
    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.08)
    row.label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.label:SetAllPoints()
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)
    row:SetScript("OnClick", function(self)
        OpenLogEntry(self.entry)
    end)
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetText(ShortName(self.entry.author))
        GameTooltip:AddLine(PlainText(self.entry.text), 1, 1, 1, true)
        GameTooltip:AddLine("Click to report or never mute", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    return row
end

local function CreateLogWindow()
    local window = CreateWindow("MuteGuildsLogWindow", 560, 440)
    window.title:SetText("MuteGuilds: muted messages")
    local entries = {}

    local hint = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", 20, -34)
    hint:SetText("Last 15 minutes, cleared on /reload. Click a message to report it or never mute the sender.")
    local empty = window:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    empty:SetPoint("TOP", 0, -(LOG_TOP + 20))
    empty:SetText("No muted messages in the last 15 minutes.")

    local rows = {}
    for i = 1, LOG_ROWS do
        rows[i] = CreateLogRow(window, i)
    end

    local scroller = CreateScroller(window, LOG_TOP, 44, LOG_ROWS, function(offset)
        for i, row in ipairs(rows) do
            local entry = entries[offset + i]
            row.entry = entry
            row:SetShown(entry ~= nil)
            if entry then
                row.label:SetText(
                    ("|cff999999%s [%s]|r |cffffd100%s|r: %s"):format(
                        entry.clock,
                        CHANNEL_LABEL[entry.event] or "Chat",
                        ShortName(entry.author),
                        PlainText(entry.text)
                    )
                )
            end
        end
    end)

    function window:Refresh()
        entries = ns.LogEntries()
        empty:SetShown(#entries == 0)
        scroller:Update(#entries)
    end

    local clear = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    clear:SetSize(100, 22)
    clear:SetPoint("BOTTOMRIGHT", -16, 14)
    clear:SetText("Clear log")
    clear:SetScript("OnClick", function()
        ns.ClearLog()
        window:Refresh()
    end)

    window:SetScript("OnShow", window.Refresh)
    return window
end

function ns.ToggleLogWindow()
    logWindow = logWindow or CreateLogWindow()
    Toggle(logWindow)
end

-- Only the list depends on saved data; the log refreshes when it is opened.
ns.RegisterView(function()
    if listWindow and listWindow:IsShown() then
        listWindow:Refresh()
    end
end)
