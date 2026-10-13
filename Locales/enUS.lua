-- Locales/enUS.lua: the table of texts, ns.L. Loaded first.
-- English is the default. A text without a translation is shown as its key,
-- so most keys are simply the English text: L["muted %s."]. Longer texts have
-- a name in capitals as their key and are written out below.
-- A translation (Locales/deDE.lua) replaces both kinds. Slash commands and
-- their keywords are never translated.

local _, ns = ...

local L = setmetatable({}, {
    __index = function(_, key)
        return key
    end,
})
ns.L = L

L.OPTIONS_DESCRIPTION = "Hides chat from players in the guilds on your list. A guild is matched on its whole name, "
    .. "never on a part of it. Only affects your screen and doesn't use your ignore list. Chat doesn't show a "
    .. "player's guild, so players are added automatically when you target them, mouse over them, see their "
    .. "nameplate, group with them, or find them with /who (the Scan button)."

L.TIP_NAME_CONTAINS = "Hides chat from any player whose character name contains this text (at least 3 letters). "
    .. "Click again with the same text to remove it."

L.TIP_IMPORT = "Adds everyone on your WoW ignore list to your mute list, so they stay muted whatever guild "
    .. "they're in. You can also clear them from the ignore list to free up slots."

L.POPUP_CLEAR = "Unmute all %s players on your mute list?\n\n"
    .. "This can't be undone (you'd need to scan again). Your guild list is kept."

L.POPUP_IMPORT = "Add the %s players on your ignore list to your MuteGuilds list?\n\n"
    .. "They'll stay muted whatever guild they're in. Removing them from the ignore list frees up ignore slots."

L.POPUP_SHARE_SEND = "Share your guild names with:\n" .. "(a player's name, or leave empty to share with your group)"
