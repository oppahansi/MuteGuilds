-- Commands.lua: the /muteguilds (or /mg) slash command.

local _, ns = ...
local L = ns.L
local Print = ns.Print

-- The commands and their keywords are the same in every language; only the
-- explanations around them are translated.
local HELP = {
    L["/mg (opens the options) | on | off | list | log | scan | tally | import | clear"],
    L["/mg guild add|remove Exact Guild Name"],
    L["/mg add|remove|allow|check Player Name    (allow again to undo)"],
    L["/mg word add|remove text  |  name add|remove text"],
    "/mg invites|guildinvites|groupinvites|duels|trades|instant|bubbles|groupwarn|whisperwarn|shares on|off",
    "/mg share [Name|guild]",
    L["/mg debug off|dry|live    (dry: report only, hide nothing; live: hide and report)"],
    L["Separate several names or words with commas: /mg add Name1, Name2"],
}

-- "<command> on|off" switches these settings.
local TOGGLES = {
    guildinvites = { "declineGuild" },
    groupinvites = { "declineGroup" },
    invites = { "declineGuild", "declineGroup" },
    duels = { "declineDuel" },
    trades = { "declineTrade" },
    instant = { "instantDecline" },
    bubbles = { "hideBubbles" },
    groupwarn = { "groupWarn" },
    whisperwarn = { "whisperWarn" },
    invitewarn = { "whisperWarn" },
    shares = { "acceptShares" },
}

-- "<command> add|remove <text>" edits these lists; without a valid
-- sub-command the list is printed.
local LISTS = {
    guild = { add = ns.AddGuilds, remove = ns.RemoveGuilds, show = ns.GuildList, label = L["guild list"] },
    word = { add = ns.AddWords, remove = ns.RemoveWords, show = ns.WordList, label = L["filtered words"] },
    name = { add = ns.AddNameWords, remove = ns.RemoveNameWords, show = ns.NameWordList, label = L["name list"] },
}

-- "<command> <text>" commands that need the text.
local WITH_TEXT = {
    add = ns.AddPlayers,
    remove = ns.RemovePlayers,
    allow = ns.AllowPlayers,
    check = ns.CheckPlayer,
}

local function PrintTally()
    Print(
        L["hidden %s messages (%s this session) from %s muted players."]:format(
            ns.FormatNum(ns.db.hiddenTotal),
            ns.FormatNum(ns.sessionHidden),
            ns.FormatNum(ns.CountMuted())
        )
    )
end

local function PrintHelp()
    Print(
        L["filtering %s, %d players muted, debug mode %s."]:format(
            ns.OnOff(ns.db.enabled),
            ns.CountMuted(),
            ns.DebugModeText()
        )
    )
    for _, line in ipairs(HELP) do
        Print(line)
    end
end

-- Commands that take no text, or handle their own.
local SIMPLE = {
    [""] = ns.OpenOptions,
    config = ns.OpenOptions,
    options = ns.OpenOptions,
    on = function()
        ns.SetOption("enabled", true)
    end,
    off = function()
        ns.SetOption("enabled", false)
    end,
    list = ns.ToggleListWindow,
    log = ns.ToggleLogWindow,
    scan = ns.WhoScan,
    tally = PrintTally,
    stats = PrintTally,
    import = ns.StartIgnoreImport,
    clear = ns.ConfirmClearPlayers,
    share = ns.SendShare,
    debug = function(rest)
        ns.SetDebugMode(rest:lower())
    end,
}

local function EditList(list, rest)
    local action, text = rest:match("^(%S*)%s*(.-)$")
    action = action:lower()
    local edit = (action == "add" or action == "remove") and list[action]
    if edit and text ~= "" then
        edit(text)
    else
        Print(("%s: %s"):format(list.label, list.show()))
    end
end

local function HandleCommand(input)
    local command, rest = input:match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()

    local toggles, onOff = TOGGLES[command], rest:lower()
    if toggles and (onOff == "on" or onOff == "off") then
        for _, setting in ipairs(toggles) do
            ns.SetOption(setting, onOff == "on")
        end
    elseif LISTS[command] then
        EditList(LISTS[command], rest)
    elseif WITH_TEXT[command] and rest ~= "" then
        WITH_TEXT[command](rest)
    elseif SIMPLE[command] then
        SIMPLE[command](rest)
    else
        PrintHelp()
    end
end

SLASH_MUTEGUILDS1 = "/muteguilds"
SLASH_MUTEGUILDS2 = "/mg"
SlashCmdList.MUTEGUILDS = function(input)
    if ns.db then
        ns.Try(HandleCommand, input or "")
    end
end
