-- Options.lua: the page under Options > AddOns.

local _, ns = ...
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
    button:SetSize(width, 22)
    button:SetText(text)
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
    { "enabled", "Enable filtering" },
    { "hideBubbles", "Hide their chat bubbles (open world)" },
    { "declineGuild", "Auto-decline guild invites" },
    { "declineGroup", "Auto-decline group invites" },
    { "declineDuel", "Auto-decline duels" },
    { "declineTrade", "Ask before trades" },
    { "instantDecline", "Decline group invites and duels instantly" },
    { "acceptShares", "Accept shared lists" },
    { "groupWarn", "Warn when a muted player is in my group" },
    { "whisperWarn", "Warn if I whisper/invite a muted player" },
}

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
    local description = CreateLabel(
        panel,
        "GameFontHighlightSmall",
        "Hides chat from players in the guilds on your list. A guild is matched on its whole name, never on a "
            .. "part of it. Only affects your screen and doesn't use your ignore list. Chat doesn't show a player's "
            .. "guild, so players are added automatically when you target them, mouse over them, see their "
            .. "nameplate, group with them, or find them with /who (the Scan button)."
    )
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    description:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    local stats = CreateLabel(panel, "GameFontHighlight")
    stats:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -10)

    local checks, lastRow = CreateChecks(panel, stats)

    local guildText =
        CreateListEditor(panel, lastRow, "Muted guilds (exact name, upper or lower case doesn't matter):", {
            {
                "Add guild",
                90,
                ns.AddGuilds,
                "Mutes the guild with exactly this name. A guild whose name only contains it is not muted.",
                "Add several at once with commas: First Guild, Second Guild",
            },
            { "Remove guild", 110, ns.RemoveGuilds },
        })

    local scanButton = CreateButton(panel, "Scan /who", 200, ns.WhoScan)
    scanButton:SetPoint("TOPLEFT", guildText, "BOTTOMLEFT", 0, -6)
    local shareButton = CreateButton(panel, "Share lists...", 120, ns.PromptShare)
    shareButton:SetPoint("LEFT", scanButton, "RIGHT", 12, 0)
    AddTooltip(
        shareButton,
        "Share lists",
        "Send your guild names and filtered words to another MuteGuilds user, or to your whole group.",
        "They see what's in it and choose to add it to theirs, replace theirs, or cancel. Players are never shared.",
        "Shares are only accepted from your group, your guild, or your friends list."
    )
    local debugButton = CreateButton(panel, "Debug", 130, ns.CycleDebugMode)
    debugButton:SetPoint("LEFT", shareButton, "RIGHT", 12, 0)
    AddTooltip(
        debugButton,
        "Debug mode",
        "Dry run: nothing is hidden or declined. Each hit is reported with what would have happened and why.",
        "Live: everything works as normal, and each hit is reported as it happens.",
        "Click to switch between off, dry run and live."
    )

    local wordText =
        CreateListEditor(panel, scanButton, "Hide messages from anyone containing all of these words (any order):", {
            {
                "Add word",
                90,
                ns.AddWords,
                'A message is hidden if it contains every word you enter, in any order. "inv layer" hides '
                    .. '"invite to that layer pls". Parts also match inside longer words.',
                "Put it in quotes to match only that exact phrase.",
                'Add several at once with commas: inv layer, "that layer"',
            },
            { "Remove word", 110, ns.RemoveWords },
        })

    local nameText = CreateListEditor(panel, wordText, "Player (First Last):", {
        {
            "Mute",
            70,
            ns.AddPlayers,
            "Add this player to your mute list by hand. They stay muted even if they change guilds.",
            "Several at once with commas: Tiny Yackle, Bacon Eggz",
        },
        {
            "Never mute",
            100,
            ns.AllowPlayers,
            "This player is never muted, even in a muted guild. Click again with the same name to undo.",
        },
        { "Unmute", 80, ns.RemovePlayers },
        {
            "Name contains",
            110,
            ns.ToggleNameWords,
            "Hides chat from any player whose character name contains this text (at least 3 letters). "
                .. "Click again with the same text to remove it.",
        },
    })

    local count = CreateLabel(panel, "GameFontNormal")
    count:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -10)
    local viewButton = CreateButton(panel, "View list", 90, ns.ToggleListWindow)
    viewButton:SetPoint("LEFT", count, "RIGHT", 12, 0)
    local clearButton = CreateButton(panel, "Unmute all players...", 150, ns.ConfirmClearPlayers)
    clearButton:SetPoint("LEFT", viewButton, "RIGHT", 24, 0) -- a gap so it isn't hit by accident
    local logButton = CreateButton(panel, "Muted messages...", 150, ns.ToggleLogWindow)
    logButton:SetPoint("TOPLEFT", count, "BOTTOMLEFT", 0, -12)
    AddTooltip(
        logButton,
        "Muted messages",
        "See the messages MuteGuilds hid in the last 15 minutes. Click one to report it or never mute the sender."
    )
    local importButton = CreateButton(panel, "Import ignore list...", 170, ns.StartIgnoreImport)
    importButton:SetPoint("LEFT", logButton, "RIGHT", 8, 0)
    AddTooltip(
        importButton,
        "Import ignore list",
        "Adds everyone on your WoW ignore list to your mute list, so they stay muted whatever guild they're in. "
            .. "You can also clear them from the ignore list to free up slots."
    )

    function panel:UpdateStats()
        local muted = ns.FormatNum(ns.CountMuted())
        stats:SetText(
            ("Hidden |cffffd100%s|r messages (%s this session)  -  |cffffd100%s|r players muted"):format(
                ns.FormatNum(ns.db.hiddenTotal),
                ns.FormatNum(ns.sessionHidden),
                muted
            )
        )
        count:SetText("Muted players: " .. muted)
    end

    function panel:UpdateScanButton()
        local nextStep, total = ns.ScanProgress()
        local left = ns.ScanCooldownLeft()
        scanButton:SetEnabled(total > 0 and left <= 0)
        if total == 0 then
            scanButton:SetText("Scan /who (no guilds)")
        elseif left > 0 then
            scanButton:SetText(("Next scan %d/%d in %ds"):format(nextStep, total, math.ceil(left)))
        else
            scanButton:SetText(("Scan /who (%d/%d)"):format(nextStep, total))
        end
    end

    function panel:Refresh()
        for _, check in ipairs(checks) do
            check:SetChecked(ns.db[check.setting])
        end
        guildText:SetText("Current list: |cffffffff" .. ns.GuildList() .. "|r")
        wordText:SetText("Filtered words: |cffffffff" .. ns.WordList() .. "|r")
        nameText:SetText("Names containing: |cffffffff" .. ns.NameWordList() .. "|r")
        debugButton:SetText("Debug: " .. ns.db.debugMode)
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
        Print("the options page didn't load. Look for a MuteGuilds error printed at login.")
    elseif not InCombatLockdown() then
        Settings.OpenToCategory(category:GetID())
    elseif not combatWaiter:IsEventRegistered("PLAYER_REGEN_ENABLED") then
        combatWaiter:RegisterEvent("PLAYER_REGEN_ENABLED")
        Print("the options can't open during combat. They'll open as soon as combat ends.")
    end
end
