-- Debug.lua: the debug modes, for testing the addon and your lists.
--   off   normal operation, no debug output
--   dry   dry run: nothing is hidden or declined; every hit is reported with
--         what would have happened and why
--   live  normal operation, and every hit is reported as it happens

local _, ns = ...
local L = ns.L

ns.DEBUG_MODES = { off = true, dry = true, live = true }

local DESCRIPTION = {
    off = "|cffff0000" .. L["OFF"] .. "|r",
    dry = L["|cffffd100DRY RUN|r: nothing is hidden or declined, hits are only reported"],
    live = L["|cff00ff00LIVE|r: everything works as normal, and each hit is reported"],
}

-- True while nothing may actually be hidden, removed or declined.
function ns.IsDryRun()
    return ns.db.debugMode == "dry"
end

-- Prints a line in the debug modes. In a dry run "hid" reads "would hide".
function ns.Debug(text, ...)
    if ns.db.debugMode == "off" then
        return
    end
    if select("#", ...) > 0 then
        text = text:format(...)
    end
    ns.Print("|cffffd100[debug]|r " .. text)
end

-- The verb for something that happens for real only outside a dry run:
-- ns.Did(L["hid"], L["would hide"]).
function ns.Did(done, wouldDo)
    return ns.IsDryRun() and wouldDo or done
end

function ns.DebugModeText()
    return DESCRIPTION[ns.db.debugMode]
end

function ns.SetDebugMode(mode)
    if not ns.DEBUG_MODES[mode] then
        local text = L["debug modes: off, dry (report only, hide nothing), live (hide and report). Now: %s"]
        ns.Print(text:format(ns.DebugModeText()))
        return
    end
    ns.db.debugMode = mode
    ns.DataChanged(false)
    if mode == "dry" then
        -- Give back what is currently hidden; nothing new gets hidden.
        ns.RestoreBubbles()
        ns.CancelPurges()
    end
    ns.Print(L["debug mode %s"]:format(ns.DebugModeText()))
    ns.RefreshViews()
end

-- Options panel button: off -> dry -> live -> off.
local NEXT_MODE = { off = "dry", dry = "live", live = "off" }
function ns.CycleDebugMode()
    ns.SetDebugMode(NEXT_MODE[ns.db.debugMode])
end
