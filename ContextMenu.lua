-- ContextMenu.lua: adds "Copy guild name" and "Mute guild" to the menu that
-- opens when you right-click a player's unit frame.

local _, ns = ...
local IsSecret = ns.IsSecret

-- The unit menus that can belong to another player.
local MENUS = {
    "MENU_UNIT_PLAYER",
    "MENU_UNIT_ENEMY_PLAYER",
    "MENU_UNIT_PARTY",
    "MENU_UNIT_RAID_PLAYER",
    "MENU_UNIT_TARGET",
    "MENU_UNIT_FOCUS",
}

-- Addons can't write to the clipboard, so the name is shown selected in an
-- edit box, ready for Ctrl+C.
StaticPopupDialogs["MUTEGUILDS_COPY"] = {
    text = "Guild name (Ctrl+C to copy):",
    button1 = CLOSE,
    hasEditBox = 1,
    editBoxWidth = 260,
    OnShow = function(self, guild)
        local editBox = self.editBox or self.EditBox
        editBox:SetText(guild)
        editBox:HighlightText()
        editBox:SetFocus()
    end,
    EditBoxOnEnterPressed = function(self)
        self:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- The guild of the player a unit menu was opened for, or nil.
local function GuildOf(unit)
    if type(unit) ~= "string" or not UnitIsPlayer(unit) or UnitIsUnit(unit, "player") then
        return nil
    end
    local guild = GetGuildInfo(unit)
    if IsSecret(guild) or type(guild) ~= "string" or guild == "" then
        return nil
    end
    return guild
end

local function ToggleGuild(guild, unit)
    if ns.IsMutedGuild(guild) then
        ns.RemoveGuild(guild)
    else
        ns.AddGuild(guild)
        ns.ScanUnit(unit) -- mute this player right away
    end
end

local function AddMenuItems(_, root, context)
    local unit = context and context.unit
    local guild = ns.db and GuildOf(unit)
    if not guild then
        return -- no guild, or the menu isn't for a visible player
    end
    root:CreateDivider()
    root:CreateTitle("MuteGuilds")
    root:CreateButton("Copy guild name", function()
        StaticPopup_Show("MUTEGUILDS_COPY", nil, nil, guild)
    end)
    if ns.IsOwnGuild(guild) then
        return -- your own guild can't be muted
    end
    local action = ns.IsMutedGuild(guild) and "Unmute guild" or "Mute guild"
    root:CreateButton(("%s <%s>"):format(action, guild), function()
        ns.Try(ToggleGuild, guild, unit)
    end)
end

for _, menu in ipairs(MENUS) do
    Menu.ModifyMenu(menu, function(...)
        ns.Try(AddMenuItems, ...)
    end)
end
