-- Options.lua: the page under Options > AddOns.

local _, ns = ...
local L = ns.L
local Print = ns.Print

local COLUMN_2 = 300 -- x offset of the second checkbox column
local panel, category

---------------------------------------------------------------------------
-- Widgets
---------------------------------------------------------------------------
local function AddTooltip(widget, title, ...)
    local lines = { ... }
    widget:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title)
        for _, line in ipairs(lines) do
            GameTooltip:AddLine(line, 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", GameTooltip_Hide)
end

local function CreateLabel(parent, font, text)
    local label = parent:CreateFontString(nil, "ARTWORK", font)
    label:SetJustifyH("LEFT")
    if text then
        label:SetText(text)
    end
    return label
end

-- A checkbox bound to one saved setting.
local function CreateCheck(parent, setting, text)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check.setting = setting
    local label = check.Text or check.text
    label:SetText(text)
    check:SetScript("OnClick", function(self)
        ns.SetOption(setting, self:GetChecked())
    end)
    return check
end

local function CreateButton(parent, text, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetText(text)
    -- width is the least it gets: a longer (translated) label widens it.
    button:SetSize(math.max(width, button:GetTextWidth() + 20), 22)
    button:SetScript("OnClick", onClick)
    return button
end

local function CreateInput(parent)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(180, 20)
    box:SetAutoFocus(false)
    box:SetScript("OnEscapePressed", box.ClearFocus)
    return box
end

-- Runs action with the box's text, then empties the box.
local function Submit(box, action)
    return function()
        action(strtrim(box:GetText() or ""))
        box:SetText("")
        box:ClearFocus()
    end
end

-- A labelled input with a row of buttons; Enter runs the first button.
-- buttons: list of { text, width, action, tooltip... }
-- Returns the text line under the input, which shows the current list.
local function CreateListEditor(parent, anchor, title, buttons)
    local label = CreateLabel(parent, "GameFontNormal", title)
    label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10)
    local box = CreateInput(parent)
    box:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 6, -4)
    box:SetScript("OnEnterPressed", Submit(box, buttons[1][3]))

    local previous = box
    for _, spec in ipairs(buttons) do
        local button = CreateButton(parent, spec[1], spec[2], Submit(box, spec[3]))
        button:SetPoint("LEFT", previous, "RIGHT", previous == box and 8 or 6, 0)
        if spec[4] then
            AddTooltip(button, spec[1], unpack(spec, 4))
        end
        previous = button
    end

    local current = CreateLabel(parent, "GameFontHighlightSmall")
    current:SetPoint("TOPLEFT", box, "BOTTOMLEFT", -6, -5)
    current:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    return current
end

---------------------------------------------------------------------------
-- The panel
---------------------------------------------------------------------------
local CHECKS = { -- setting, text; two per row
    { "enabled", L["Enable filtering"] },
    { "hideBubbles", L["Hide their chat bubbles (open world)"] },
    { "declineGuild", L["Auto-decline guild invites"] },
    { "declineGroup", L["Auto-decline group invites"] },
    { "declineDuel", L["Auto-decline duels"] },
    { "declineTrade", L["Ask before trades"] },
    { "instantDecline", L["Decline group invites and duels instantly"] },
    { "acceptShares", L["Accept shared lists"] },
    { "groupWarn", L["Warn when a muted player is in my group"] },
    { "whisperWarn", L["Warn if I whisper/invite a muted player"] },
}

-- The debug mode as the Debug button shows it.
local DEBUG_LABEL = { off = L["off"], dry = L["dry run"], live = L["live"] }

local function CreateChecks(parent, anchor)
    local checks, rowStart = {}, nil
    for i, spec in ipairs(CHECKS) do
        local check = CreateCheck(parent, spec[1], spec[2])
        if i == 1 then
            check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -2, -6)
            rowStart = check
        elseif i % 2 == 0 then
            check:SetPoint("TOPLEFT", rowStart, "TOPLEFT", COLUMN_2, 0)
        else
            check:SetPoint("TOPLEFT", rowStart, "BOTTOMLEFT", 0, 0)
            rowStart = check
        end
        checks[i] = check
    end
    return checks, rowStart
end

local function CreatePanel()
    panel = CreateFrame("Frame")
    panel.name = "MuteGuilds"

    local title = CreateLabel(panel, "GameFontNormalLarge", "MuteGuilds")
    title:SetPoint("TOPLEFT", 16, -16)
    local description = CreateLabel(panel, "GameFontHighlightSmall", L.OPTIONS_DESCRIPTION)
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    description:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    local stats = CreateLabel(panel, "GameFontHighlight")
    stats:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -10)

    local checks, lastRow = CreateChecks(panel, stats)

    local guildText =
        CreateListEditor(panel, lastRow, L["Muted guilds (exact name, upper or lower case doesn't matter):"], {
            {
                L["Add guild"],
                90,
                ns.AddGuilds,
                L["Mutes the guild with exactly this name. A guild whose name only contains it is not muted."],
                L["Add several at once with commas: First Guild, Second Guild"],
            },
            { L["Remove guild"], 110, ns.RemoveGuilds },
        })

    local scanButton = CreateButton(panel, L["Scan /who"], 200, ns.WhoScan)
    scanButton:SetPoint("TOPLEFT", guildText, "BOTTOMLEFT", 0, -6)
    local shareButton = CreateButton(panel, L["Share lists..."], 120, ns.PromptShare)
    shareButton:SetPoint("LEFT", scanButton, "RIGHT", 12, 0)
    AddTooltip(
        shareButton,
        L["Share lists"],
        L["Send your guild names and filtered words to another MuteGuilds user, or to your whole group."],
        L["They see what's in it and choose to add it to theirs, replace theirs, or cancel. Players are never shared."],
        L["Shares are only accepted from your group, your guild, or your friends list."]
    )
    local debugButton = CreateButton(panel, "Debug", 130, ns.CycleDebugMode)
    debugButton:SetPoint("LEFT", shareButton, "RIGHT", 12, 0)
    AddTooltip(
        debugButton,
        L["Debug mode"],
        L["Dry run: nothing is hidden or declined. Each hit is reported with what would have happened and why."],
        L["Live: everything works as normal, and each hit is reported as it happens."],
        L["Click to switch between off, dry run and live."]
    )

    local wordText =
        CreateListEditor(panel, scanButton, L["Hide messages from anyone containing all of these words (any order):"], {
            {
                L["Add word"],
                90,
                ns.AddWords,
                L.TIP_ADD_WORD,
                L["Put it in quotes to match only that exact phrase."],
                L['Add several at once with commas: inv layer, "that layer"'],
            },
            { L["Remove word"], 110, ns.RemoveWords },
        })

    local nameText = CreateListEditor(panel, wordText, L["Player (First Last):"], {
        {
            L["Mute"],
            70,
            ns.AddPlayers,
            L["Add this player to your mute list by hand. They stay muted even if they change guilds."],
            L["Several at once with commas: Tiny Yackle, Bacon Eggz"],
        },
        {
            L["Never mute"],
            100,
            ns.AllowPlayers,
            L["This player is never muted, even in a muted guild. Click again with the same name to undo."],
        },
        { L["Unmute"], 80, ns.RemovePlayers },
        {
            L["Name contains"],
            110,
            ns.ToggleNameWords,
            L.TIP_NAME_CONTAINS,
        },
    })

    local count = CreateLabel(panel, "GameFontNormal")
    count:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -10)
    local viewButton = CreateButton(panel, L["View list"], 90, ns.ToggleListWindow)
    viewButton:SetPoint("LEFT", count, "RIGHT", 12, 0)
    local clearButton = CreateButton(panel, L["Unmute all players..."], 150, ns.ConfirmClearPlayers)
    clearButton:SetPoint("LEFT", viewButton, "RIGHT", 24, 0) -- a gap so it isn't hit by accident
    local logButton = CreateButton(panel, L["Muted messages..."], 150, ns.ToggleLogWindow)
    logButton:SetPoint("TOPLEFT", count, "BOTTOMLEFT", 0, -12)
    AddTooltip(
        logButton,
        L["Muted messages"],
        L["See the messages MuteGuilds hid in the last 15 minutes. Click one to report it or never mute the sender."]
    )
    local importButton = CreateButton(panel, L["Import ignore list..."], 170, ns.StartIgnoreImport)
    importButton:SetPoint("LEFT", logButton, "RIGHT", 8, 0)
    AddTooltip(importButton, L["Import ignore list"], L.TIP_IMPORT)

    function panel:UpdateStats()
        local muted = ns.FormatNum(ns.CountMuted())
        stats:SetText(
            L["Hidden |cffffd100%s|r messages (%s this session)  -  |cffffd100%s|r players muted"]:format(
                ns.FormatNum(ns.db.hiddenTotal),
                ns.FormatNum(ns.sessionHidden),
                muted
            )
        )
        count:SetText(L["Muted players: %s"]:format(muted))
    end

    function panel:UpdateScanButton()
        local nextStep, total = ns.ScanProgress()
        local left = ns.ScanCooldownLeft()
        scanButton:SetEnabled(total > 0 and left <= 0)
        if total == 0 then
            scanButton:SetText(L["Scan /who (no guilds)"])
        elseif left > 0 then
            scanButton:SetText(L["Next scan %d/%d in %ds"]:format(nextStep, total, math.ceil(left)))
        else
            scanButton:SetText(L["Scan /who (%d/%d)"]:format(nextStep, total))
        end
    end

    function panel:Refresh()
        for _, check in ipairs(checks) do
            check:SetChecked(ns.db[check.setting])
        end
        guildText:SetText(L["Current list: %s"]:format("|cffffffff" .. ns.GuildList() .. "|r"))
        wordText:SetText(L["Filtered words: %s"]:format("|cffffffff" .. ns.WordList() .. "|r"))
        nameText:SetText(L["Names containing: %s"]:format("|cffffffff" .. ns.NameWordList() .. "|r"))
        debugButton:SetText(L["Debug: %s"]:format(DEBUG_LABEL[ns.db.debugMode]))
        self:UpdateScanButton()
        self:UpdateStats()
    end

    -- Counts the scan cooldown down while the page is open.
    local sinceTick = 0
    panel:SetScript("OnUpdate", function(self, elapsed)
        sinceTick = sinceTick + elapsed
        if sinceTick >= 0.25 then
            sinceTick = 0
            self:UpdateScanButton()
        end
    end)
    panel:SetScript("OnShow", panel.Refresh)

    category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
end
ns.CreateOptionsPanel = CreatePanel

ns.RegisterView(function()
    if panel and panel:IsShown() then
        panel:Refresh()
    end
end)

-- Called by the chat filter for every hidden message.
function ns.RefreshStats()
    if panel and panel:IsShown() then
        panel:UpdateStats()
    end
end

---------------------------------------------------------------------------
-- Opening it
-- The game won't let addons open the Settings window during combat, so wait
-- for combat to end.
---------------------------------------------------------------------------
local combatWaiter = CreateFrame("Frame")
combatWaiter:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    Settings.OpenToCategory(category:GetID())
end)

function ns.OpenOptions()
    if not category then
        Print(L["the options page didn't load. Look for a MuteGuilds error printed at login."])
    elseif not InCombatLockdown() then
        Settings.OpenToCategory(category:GetID())
    elseif not combatWaiter:IsEventRegistered("PLAYER_REGEN_ENABLED") then
        combatWaiter:RegisterEvent("PLAYER_REGEN_ENABLED")
        Print(L["the options can't open during combat. They'll open as soon as combat ends."])
    end
end
