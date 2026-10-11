std = "lua51"
max_line_length = false
exclude_files = { "reference/" }
-- Method definitions and script handlers often don't use self.
self = false

-- Globals the addon defines or writes to. Add every new intentional global here.
globals = {
    "MuteGuildsDB",
    "SLASH_MUTEGUILDS1",
    "SLASH_MUTEGUILDS2",
    "SlashCmdList",
    "StaticPopupDialogs",
    "UISpecialFrames",
}

-- Client API the addon reads. Extend as new API is used.
read_globals = {
    -- Lua additions and utilities
    "issecretvalue",
    "hooksecurefunc",
    "strtrim",
    "wipe",
    "tinsert",
    "date",
    "time",
    "Enum",
    "BreakUpLargeNumbers",
    "GetLocale",
    -- frames and UI
    "CreateFrame",
    "UIParent",
    "GameTooltip",
    "GameTooltip_Hide",
    "DEFAULT_CHAT_FRAME",
    "CHAT_FRAMES",
    "ChatFrameUtil",
    "ChatFrame_AddMessageEventFilter",
    "ChatEdit_UpdateHeader",
    "ChatHistory_GetChatType",
    "FCF_Close",
    "Settings",
    "Menu",
    "TooltipDataProcessor",
    "StaticPopup_Show",
    "StaticPopup_Hide",
    "StaticPopup_Visible",
    "StaticPopupSpecial_Show",
    "StaticPopupSpecial_Hide",
    "LFGInvitePopup",
    "LFGInvitePopup_Update",
    "GuildInviteFrame",
    "GuildInviteFrameDeclineButton",
    "ReportFrame",
    "ReportInfo",
    "PlayerLocation",
    -- localized strings
    "YES",
    "NO",
    "CANCEL",
    "CLOSE",
    "INVITATION",
    "UNKNOWNOBJECT",
    -- namespaces
    "C_Timer",
    "C_FriendList",
    "C_PartyInfo",
    "C_ChatInfo",
    "C_ChatBubbles",
    "C_GuildInfo",
    "C_ReportSystem",
    -- units and players
    "UnitGUID",
    "UnitExists",
    "UnitIsPlayer",
    "UnitIsUnit",
    "UnitLevel",
    "UnitInParty",
    "UnitInRaid",
    "GetUnitName",
    "GetGuildInfo",
    "GetNormalizedRealmName",
    "GetMaxPlayerLevel",
    "GetTime",
    "InCombatLockdown",
    "IsInGroup",
    "IsInRaid",
    "IsInGuild",
    "GetNumGroupMembers",
    -- requests
    "DeclineGroup",
    "AcceptGroup",
    "DeclineGuild",
    "CancelDuel",
    "CancelTrade",
}
