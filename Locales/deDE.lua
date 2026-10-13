-- Locales/deDE.lua: German texts. See Locales/enUS.lua for how keys work.
-- Slash commands and their keywords (on, off, add, remove...) stay English.
-- A translated text needs the same %s and %d as its key, in the same order.

local _, ns = ...
if GetLocale() ~= "deDE" then
    return
end
local L = ns.L

---------------------------------------------------------------------------
-- Longer texts
---------------------------------------------------------------------------
L.OPTIONS_DESCRIPTION = "Blendet den Chat von Spielern aus, die in einer Gilde auf deiner Liste sind. Eine Gilde zählt "
    .. "nur, wenn ihr ganzer Name übereinstimmt, nie bei einem Teil davon. Wirkt nur auf deinem Bildschirm und nutzt "
    .. "nicht deine Ignorierliste. Der Chat zeigt nicht, in welcher Gilde ein Spieler ist. Spieler werden deshalb "
    .. "automatisch erfasst, wenn du sie anvisierst, mit der Maus über sie fährst, ihre Namensplakette siehst, mit "
    .. "ihnen in einer Gruppe bist oder sie mit /who findest (der Scan-Button)."

L.TIP_NAME_CONTAINS = "Blendet den Chat aller Spieler aus, deren Charaktername diesen Text enthält (mindestens 3 "
    .. "Buchstaben). Erneut mit demselben Text klicken, um ihn zu entfernen."

L.TIP_IMPORT = "Fügt alle Spieler deiner WoW-Ignorierliste deiner Stummliste hinzu. Sie bleiben stummgeschaltet, "
    .. "egal in welcher Gilde sie sind. Du kannst sie dabei auch von der Ignorierliste entfernen, um Plätze "
    .. "freizugeben."

L.POPUP_CLEAR = "Die Stummschaltung aller %s Spieler auf deiner Stummliste aufheben?\n\n"
    .. "Das lässt sich nicht rückgängig machen (du müsstest erneut scannen). Deine Gildenliste bleibt erhalten."

L.POPUP_IMPORT = "Die %s Spieler deiner Ignorierliste zu deiner MuteGuilds-Liste hinzufügen?\n\n"
    .. "Sie bleiben stummgeschaltet, egal in welcher Gilde sie sind. Entfernst du sie von der Ignorierliste, "
    .. "werden dort Plätze frei."

L.POPUP_SHARE_SEND = "Deine Gildennamen teilen mit:\n"
    .. "(Name eines Spielers, oder leer lassen, um mit deiner Gruppe zu teilen)"

---------------------------------------------------------------------------
-- Core.lua
---------------------------------------------------------------------------
L["ON"] = "AN"
L["OFF"] = "AUS"
L["|cffff4444error:|r %s"] = "|cffff4444Fehler:|r %s"
L["added manually"] = "manuell hinzugefügt"
L["from ignore list"] = "von der Ignorierliste"
L["unguilded"] = "ohne Gilde"
L["added %s <%s> to the mute list."] = "%s <%s> zur Stummliste hinzugefügt."
L["removed %s from the mute list, now %s."] = "%s von der Stummliste entfernt, jetzt %s."

---------------------------------------------------------------------------
-- Debug.lua
---------------------------------------------------------------------------
L["debug mode %s"] = "Debug-Modus %s"
L["debug modes: off, dry (report only, hide nothing), live (hide and report). Now: %s"] =
    "Debug-Modi: off, dry (nur melden, nichts ausblenden), live (ausblenden und melden). Aktuell: %s"
L["|cffffd100DRY RUN|r: nothing is hidden or declined, hits are only reported"] =
    "|cffffd100PROBELAUF|r: nichts wird ausgeblendet oder abgelehnt, Treffer werden nur gemeldet"
L["|cff00ff00LIVE|r: everything works as normal, and each hit is reported"] =
    "|cff00ff00LIVE|r: alles funktioniert wie gewohnt, und jeder Treffer wird gemeldet"

---------------------------------------------------------------------------
-- Filter.lua
-- Debug lines put the verb first, as a label: "Ausgeblendet: ...".
---------------------------------------------------------------------------
L["%s a %s message from %s (%s): %s"] = "%s: %s-Nachricht von %s (%s): %s"
L["hid"] = "Ausgeblendet"
L["would hide"] = "Würde ausblenden"
L["(unreadable text)"] = "(nicht lesbarer Text)"
L["muted player <%s>"] = "stummgeschalteter Spieler <%s>"
L["name keyword"] = "Namensfilter"

---------------------------------------------------------------------------
-- Requests.lua
---------------------------------------------------------------------------
L["declining"] = "Lehne ab"
L["would decline"] = "Würde ablehnen"
L["asking"] = "Frage nach"
L["would ask"] = "Würde nachfragen"
L["%s a group invite from %s <%s>."] = "%s: Gruppeneinladung von %s <%s>."
L["%s a guild invite from <%s>."] = "%s: Gildeneinladung von <%s>."
L["%s a duel from %s <%s>."] = "%s: Duell von %s <%s>."
L["%s before trading with %s <%s>."] = "%s: vor dem Handel mit %s <%s>."
L["declined a group invite from %s <%s>."] = "Gruppeneinladung von %s <%s> abgelehnt."
L["declined a guild invite from <%s>."] = "Gildeneinladung von <%s> abgelehnt."
L["declined a duel from %s <%s>."] = "Duell von %s <%s> abgelehnt."
L["Trade with %s <%s>?\n\nThey're on your MuteGuilds list."] =
    "Mit %s <%s> handeln?\n\nDer Spieler steht auf deiner MuteGuilds-Liste."
L["Allow trade"] = "Handel erlauben"
L["Decline"] = "Ablehnen"
L["trading with %s allowed for the next 10 minutes. They stay muted."] =
    "Handel mit %s für die nächsten 10 Minuten erlaubt. Der Spieler bleibt stummgeschaltet."
L["cancelled the trade with %s <%s>."] = "Handel mit %s <%s> abgebrochen."

---------------------------------------------------------------------------
-- Social.lua
---------------------------------------------------------------------------
L["muted again (left the group): %s."] = "Wieder stummgeschaltet (Gruppe verlassen): %s."
L["muted again (didn't join): %s."] = "Wieder stummgeschaltet (nicht beigetreten): %s."
L["unmuted while you're grouped: %s. They're muted again when the group ends."] =
    "Stummschaltung für die Dauer der Gruppe aufgehoben: %s. Danach gilt sie wieder."
L["|cffff5555muted in your group:|r %s. Their chat is hidden."] =
    "|cffff5555Stummgeschaltet in deiner Gruppe:|r %s. Ihr Chat ist ausgeblendet."
L["Muted players in your group:\n\n%s\n\nYou won't see their party chat."] =
    "Stummgeschaltete Spieler in deiner Gruppe:\n\n%s\n\nDu siehst ihren Gruppenchat nicht."
L["Unmute while grouped"] = "Für Gruppe aufheben"
L["Keep muted"] = "Stumm lassen"
L["Unmute forever"] = "Für immer aufheben"
L["they've already left your group."] = "Sie haben deine Gruppe bereits verlassen."
L["cancelled the invite to %s."] = "Einladung an %s abgebrochen."
L["%s is on your MuteGuilds list <%s>.\n\nIf they join, you won't see their party chat."] =
    "%s steht auf deiner MuteGuilds-Liste <%s>.\n\nBei einem Beitritt siehst du den Gruppenchat des Spielers nicht."
L["Cancel invite"] = "Einladung abbrechen"
L["invited %s, who's |cffff5555muted|r <%s>. You won't see their party chat."] =
    "%s eingeladen, |cffff5555stummgeschaltet|r <%s>. Du siehst den Gruppenchat des Spielers nicht."
L["%s is |cffff5555muted|r <%s>. You won't see their replies."] =
    "%s ist |cffff5555stummgeschaltet|r <%s>. Du siehst die Antworten nicht."
L["MuteGuilds: never muted"] = "MuteGuilds: nie stummgeschaltet"
L["MuteGuilds: unmuted while grouped"] = "MuteGuilds: für die Gruppe nicht stummgeschaltet"
L["Muted by MuteGuilds <%s>"] = "Stummgeschaltet durch MuteGuilds <%s>"
L["MuteGuilds: was in a muted guild before <%s>"] = "MuteGuilds: war früher in einer stummgeschalteten Gilde <%s>"

---------------------------------------------------------------------------
-- Scan.lua
---------------------------------------------------------------------------
L["the guild list is empty, nothing to scan."] = "Die Gildenliste ist leer, es gibt nichts zu scannen."
L["next scan ready in %d s."] = "Nächster Scan in %d s möglich."
L["scan %d/%d: /who %s"] = "Scan %d/%d: /who %s"
L["the server wanted a longer pause; that search will run again on your next scan."] =
    "Der Server verlangt eine längere Pause; diese Suche wird beim nächsten Scan wiederholt."

---------------------------------------------------------------------------
-- Lists.lua
---------------------------------------------------------------------------
L["(none)"] = "(keine)"
L["filtering"] = "Filterung"
L["auto-decline invites from muted guilds"] = "Einladungen stummgeschalteter Gilden automatisch ablehnen:"
L["auto-decline group invites from muted players"] =
    "Gruppeneinladungen stummgeschalteter Spieler automatisch ablehnen:"
L["auto-decline duels from muted players"] = "Duelle stummgeschalteter Spieler automatisch ablehnen:"
L["ask before trading with muted players"] = "Vor dem Handel mit stummgeschalteten Spielern nachfragen:"
L["decline group invites and duels instantly"] = "Gruppeneinladungen und Duelle sofort ablehnen:"
L["warning when you whisper or invite a muted player"] =
    "Warnung beim Anflüstern oder Einladen stummgeschalteter Spieler:"
L["accepting shared guild lists from other players"] = "Geteilte Gildenlisten anderer Spieler annehmen:"
L["warning when a muted player is in your group"] = "Warnung bei stummgeschalteten Spielern in deiner Gruppe:"
L["hiding chat bubbles from muted players"] = "Sprechblasen stummgeschalteter Spieler ausblenden:"
L["you can't mute the guild you are in."] = "Du kannst deine eigene Gilde nicht stummschalten."
L['"%s" is already on the guild list.'] = '"%s" steht bereits auf der Gildenliste.'
L["%s (family)"] = "%s (Familie)"
L['"%s" is muted as part of the "%s" family. Remove that entry, or run: /mg guild family %s'] =
    '"%s" ist als Teil der Familie "%s" stummgeschaltet. Entferne diesen Eintrag oder nutze: /mg guild family %s'
L['the "%s" guild family is already muted.'] = 'Die Gildenfamilie "%s" ist bereits stummgeschaltet.'
L['now muting the "%s" guild family: that name alone or followed by a number (1, 2, I, II ...). Guild list: %s'] =
    'Die Gildenfamilie "%s" ist jetzt stummgeschaltet: dieser Name allein oder gefolgt von einer Nummer (1, 2, I, II ...). Gildenliste: %s'
L['only "%s" itself is muted now, not its family (%d players unmuted). Guild list: %s'] =
    'Jetzt ist nur noch "%s" selbst stummgeschaltet, nicht die Familie (Stummschaltung von %d Spielern aufgehoben). Gildenliste: %s'
L['now muting the guild "%s" (the whole name has to match). Guild list: %s'] =
    'Die Gilde "%s" ist jetzt stummgeschaltet (der ganze Name muss übereinstimmen). Gildenliste: %s'
L['"%s" isn\'t on the guild list. Guild list: %s'] = '"%s" steht nicht auf der Gildenliste. Gildenliste: %s'
L['removed the "%s" guild family (%d players unmuted). Guild list: %s'] =
    'Die Gildenfamilie "%s" wurde entfernt (Stummschaltung von %d Spielern aufgehoben). Gildenliste: %s'
L['removed "%s" (%d players unmuted). Guild list: %s'] =
    '"%s" entfernt (Stummschaltung von %d Spielern aufgehoben). Gildenliste: %s'
L["name keywords need at least %d letters."] = "Namensfilter brauchen mindestens %d Buchstaben."
L['"%s" is already on the name list.'] = '"%s" steht bereits auf der Namensliste.'
L['hiding chat from players whose name contains "%s". Name list: %s'] =
    'Der Chat von Spielern, deren Name "%s" enthält, wird ausgeblendet. Namensliste: %s'
L['"%s" isn\'t on the name list. Name list: %s'] = '"%s" steht nicht auf der Namensliste. Namensliste: %s'
L['removed "%s". Name list: %s'] = '"%s" entfernt. Namensliste: %s'
L["you can't mute yourself."] = "Du kannst dich nicht selbst stummschalten."
L["muted %s."] = "%s stummgeschaltet."
L["%s is muted again (ended unmute while grouped)."] =
    "%s ist wieder stummgeschaltet (Ausnahme für die Gruppe beendet)."
L["%s is already muted."] = "%s ist bereits stummgeschaltet."
L["%s will now stay muted even if they change guilds."] =
    "%s bleibt jetzt auch bei einem Gildenwechsel stummgeschaltet."
L["unmuted %s."] = "Stummschaltung von %s aufgehoben."
L["%s isn't on the mute list."] = "%s steht nicht auf der Stummliste."
L["%s will never be muted."] = "%s wird nie stummgeschaltet."
L["%s can be muted again."] = "%s kann wieder stummgeschaltet werden."
L["%s is muted <%s>."] = "%s ist stummgeschaltet <%s>."
L["cleared all muted players."] = "Alle stummgeschalteten Spieler entfernt."
L["imported %d players from your ignore list (%d were already muted), removed %d from it."] =
    "%d Spieler von deiner Ignorierliste importiert (%d waren bereits stummgeschaltet), %d dort entfernt."
L["imported %d players from your ignore list (%d were already muted). It is unchanged."] =
    "%d Spieler von deiner Ignorierliste importiert (%d waren bereits stummgeschaltet). Sie bleibt unverändert."
L["skipped %d on your never-mute list (left on your ignore list)."] =
    "%d Spieler übersprungen, die nie stummgeschaltet werden (bleiben auf deiner Ignorierliste)."
L["Import"] = "Importieren"
L["Import + clear ignore list"] = "Importieren + Liste leeren"
L["your ignore list is empty, nothing to import."] = "Deine Ignorierliste ist leer, es gibt nichts zu importieren."

---------------------------------------------------------------------------
-- Share.lua
---------------------------------------------------------------------------
L["your group"] = "deiner Gruppe"
L["your guild"] = "deiner Gilde"
L["join a group to share with it, or type a name: /mg share Name"] =
    "Tritt einer Gruppe bei, um mit ihr zu teilen, oder gib einen Namen an: /mg share Name"
L["you're not in a guild."] = "Du bist in keiner Gilde."
L["your guild list is empty, nothing to share."] = "Deine Gildenliste ist leer, es gibt nichts zu teilen."
L["sharing failed: the game is limiting addon messages right now. Try again in a minute."] =
    "Teilen fehlgeschlagen: Das Spiel begrenzt gerade Addon-Nachrichten. Versuch es in einer Minute erneut."
L["sharing failed (the game refused the message, code %s)."] =
    "Teilen fehlgeschlagen (das Spiel hat die Nachricht abgelehnt, Code %s)."
L["shared %d guild names with %s. They'll be asked before anything changes."] =
    "%d Gildennamen geteilt mit %s. Vor jeder Änderung wird dort nachgefragt."
L["(%d more guilds didn't fit in one share.)"] = "(%d weitere Gilden passten nicht in eine Sendung.)"
L["(shares sent by whisper only arrive if you're on their friends list or in their group.)"] =
    "(Per Flüstern geteilte Listen kommen nur an, wenn du auf der Freundesliste oder in der Gruppe des Spielers bist.)"
L["Share"] = "Teilen"
L[" and %d more"] = " und %d weitere"
L["%s wants to share their guild list with you.\n\n%s\n\nNothing changes unless you choose below."] =
    "%s möchte eine Gildenliste mit dir teilen.\n\n%s\n\nEs ändert sich nichts, solange du unten nichts auswählst."
L["Add to mine"] = "Hinzufügen"
L["Replace mine"] = "Meine ersetzen"
L["added %d guild names from %s."] = "%d Gildennamen von %s hinzugefügt."
L["replaced your guild list with %s's: %d guild names."] =
    "Deine Gildenliste wurde durch die von %s ersetzt: %d Gildennamen."
L["Guild names (%d): %s"] = "Gildennamen (%d): %s"
L["%s shared their guild list, but the window couldn't open right now. Ask them to send it again."] =
    "%s hat eine Gildenliste geteilt, aber das Fenster konnte gerade nicht geöffnet werden. Bitte um erneutes Senden."

---------------------------------------------------------------------------
-- Windows.lua
---------------------------------------------------------------------------
L["never muted"] = "nie stumm"
L["Search name or guild"] = "Name oder Gilde suchen"
L["MuteGuilds: muted players (%s)"] = "MuteGuilds: stummgeschaltete Spieler (%s)"
L["%s found"] = "%s gefunden"
L["No matches."] = "Keine Treffer."
L["No players muted yet."] = "Noch keine Spieler stummgeschaltet."
L["Sort: Guild"] = "Sortierung: Gilde"
L["Sort: Name"] = "Sortierung: Name"
L["Say"] = "Sagen"
L["Yell"] = "Schreien"
L["Emote"] = "Emote"
L["Whisper"] = "Flüstern"
L["Channel"] = "Kanal"
L["Guild"] = "Gilde"
L["Officer"] = "Offizier"
L["Party"] = "Gruppe"
L["Raid"] = "Schlachtzug"
L["Raid Warning"] = "Schlachtzugswarnung"
L["Instance"] = "Instanz"
L["Auto-reply"] = "Auto-Antwort"
L["Chat"] = "Chat"
L["You can still report the player from their right-click menu."] =
    "Du kannst den Spieler weiterhin über sein Rechtsklick-Menü melden."
L["this message can't be reported from here."] = "Diese Nachricht kann von hier aus nicht gemeldet werden."
L["this message can't be reported anymore (it may be too old)."] =
    "Diese Nachricht kann nicht mehr gemeldet werden (sie ist vielleicht zu alt)."
L["couldn't open the report window: %s"] = "Das Meldefenster konnte nicht geöffnet werden: %s"
L["%s said:\n\n%s"] = "%s schrieb:\n\n%s"
L["Report..."] = "Melden..."
L["Never mute"] = "Nie stumm"
L["Click to report or never mute"] = "Klicken zum Melden oder um nie stummzuschalten"
L["MuteGuilds: muted messages"] = "MuteGuilds: ausgeblendete Nachrichten"
L["Last 15 minutes, cleared on /reload. Click a message to report it or never mute the sender."] =
    "Letzte 15 Minuten, bei /reload geleert. Klick: Nachricht melden oder Absender nie stummschalten."
L["No muted messages in the last 15 minutes."] = "Keine ausgeblendeten Nachrichten in den letzten 15 Minuten."
L["Clear log"] = "Protokoll leeren"

---------------------------------------------------------------------------
-- Options.lua
---------------------------------------------------------------------------
L["Enable filtering"] = "Filter aktivieren"
L["Hide their chat bubbles (open world)"] = "Sprechblasen ausblenden (offene Welt)"
L["Auto-decline guild invites"] = "Gildeneinladungen automatisch ablehnen"
L["Auto-decline group invites"] = "Gruppeneinladungen automatisch ablehnen"
L["Auto-decline duels"] = "Duelle automatisch ablehnen"
L["Ask before trades"] = "Vor dem Handeln nachfragen"
L["Decline group invites and duels instantly"] = "Gruppeneinladungen/Duelle sofort ablehnen"
L["Accept shared guild lists"] = "Geteilte Gildenlisten annehmen"
L["Warn when a muted player is in my group"] = "Warnung: stummer Spieler in der Gruppe"
L["Warn if I whisper/invite a muted player"] = "Warnung beim Anflüstern/Einladen"
L["Muted guilds (exact name, upper or lower case doesn't matter):"] =
    "Stummgeschaltete Gilden (exakter Name, Groß- und Kleinschreibung egal):"
L["Add guild"] = "Gilde hinzufügen"
L["Remove guild"] = "Gilde entfernen"
L["Takes the guild off the list and unmutes its players."] =
    "Nimmt die Gilde von der Liste und hebt die Stummschaltung ihrer Spieler auf."
L["A guild shown as (family) is removed together with its numbered guilds."] =
    "Eine Gilde mit dem Zusatz (Familie) wird zusammen mit ihren nummerierten Gilden entfernt."
L["To keep the guild and unmute only its numbered guilds, use the Family on/off button instead."] =
    "Soll die Gilde bleiben und nur die Stummschaltung ihrer nummerierten Gilden enden, nutze stattdessen den Button Familie an/aus."
L["Family on/off"] = "Familie an/aus"
L["Also mutes this guild's numbered guilds: the same name followed by 1, 2, 3 ... or I, II, III ..."] =
    "Schaltet auch die nummerierten Gilden dieser Gilde stumm: derselbe Name, gefolgt von 1, 2, 3 ... oder I, II, III ..."
L["The guild is added if it isn't listed yet. Click again with the same name to mute only that guild."] =
    "Die Gilde wird hinzugefügt, falls sie noch nicht auf der Liste steht. Erneut mit demselben Namen klicken, um nur diese Gilde stummzuschalten."
L["Mutes the guild with exactly this name. A guild whose name only contains it is not muted."] =
    "Schaltet die Gilde mit genau diesem Namen stumm. Eine Gilde, deren Name ihn nur enthält, bleibt unberührt."
L["Add several at once with commas: First Guild, Second Guild"] =
    "Mehrere auf einmal mit Kommas: Erste Gilde, Zweite Gilde"
L["Scan /who"] = "/who-Scan"
L["Scan /who (%d/%d)"] = "/who-Scan (%d/%d)"
L["Scan /who (no guilds)"] = "/who-Scan (keine Gilden)"
L["Next scan %d/%d in %ds"] = "Nächster Scan %d/%d in %ds"
L["Share guild list..."] = "Gildenliste teilen..."
L["Share guild list"] = "Gildenliste teilen"
L["Send your guild names to another MuteGuilds user, or to your whole group."] =
    "Sende deine Gildennamen an einen anderen MuteGuilds-Nutzer oder an deine ganze Gruppe."
L["They see what's in it and choose to add it to theirs, replace theirs, or cancel. Players are never shared."] =
    "Der Empfänger sieht den Inhalt und kann ihn hinzufügen, seine Liste ersetzen oder abbrechen. Spieler werden nie geteilt."
L["Shares are only accepted from your group, your guild, or your friends list."] =
    "Geteilte Gildenlisten werden nur von deiner Gruppe, deiner Gilde oder deiner Freundesliste angenommen."
L["Debug: %s"] = "Debug: %s"
L["off"] = "aus"
L["dry run"] = "Probelauf"
L["live"] = "live"
L["Debug mode"] = "Debug-Modus"
L["Dry run: nothing is hidden or declined. Each hit is reported with what would have happened and why."] =
    "Probelauf: Nichts wird ausgeblendet oder abgelehnt. Jeder Treffer wird gemeldet, mit dem, was passiert wäre, und dem Grund."
L["Live: everything works as normal, and each hit is reported as it happens."] =
    "Live: Alles funktioniert wie gewohnt, und jeder Treffer wird sofort gemeldet."
L["Click to switch between off, dry run and live."] = "Klicken, um zwischen aus, Probelauf und live zu wechseln."
L["Player (First Last):"] = "Spieler (Vorname Nachname):"
L["Mute"] = "Stumm"
L["Unmute"] = "Aufheben"
L["Name contains"] = "Name enthält"
L["Add this player to your mute list by hand. They stay muted even if they change guilds."] =
    "Fügt diesen Spieler von Hand deiner Stummliste hinzu. Er bleibt auch bei einem Gildenwechsel stummgeschaltet."
L["Several at once with commas: Tiny Yackle, Bacon Eggz"] = "Mehrere auf einmal mit Kommas: Tiny Yackle, Bacon Eggz"
L["This player is never muted, even in a muted guild. Click again with the same name to undo."] =
    "Dieser Spieler wird nie stummgeschaltet, auch nicht in einer stummgeschalteten Gilde. Erneut mit demselben Namen klicken, um das rückgängig zu machen."
L["Current list: %s"] = "Aktuelle Liste: %s"
L["Names containing: %s"] = "Namen mit: %s"
L["Muted players: %s"] = "Stumme Spieler: %s"
L["View list"] = "Liste anzeigen"
L["Unmute all players..."] = "Alle aufheben..."
L["Muted messages..."] = "Ausgeblendete Nachrichten..."
L["Muted messages"] = "Ausgeblendete Nachrichten"
L["See the messages MuteGuilds hid in the last 15 minutes. Click one to report it or never mute the sender."] =
    "Zeigt die Nachrichten, die MuteGuilds in den letzten 15 Minuten ausgeblendet hat. Klick auf eine, um sie zu melden oder den Absender nie stummzuschalten."
L["Import ignore list..."] = "Ignorierliste importieren..."
L["Import ignore list"] = "Ignorierliste importieren"
L["Hidden |cffffd100%s|r messages (%s this session)  -  |cffffd100%s|r players muted"] =
    "|cffffd100%s|r Nachrichten ausgeblendet (%s in dieser Sitzung)  -  |cffffd100%s|r Spieler stummgeschaltet"
L["the options page didn't load. Look for a MuteGuilds error printed at login."] =
    "Die Optionsseite wurde nicht geladen. Achte auf eine MuteGuilds-Fehlermeldung beim Einloggen."
L["the options can't open during combat. They'll open as soon as combat ends."] =
    "Die Optionen lassen sich im Kampf nicht öffnen. Sie öffnen sich, sobald der Kampf endet."

---------------------------------------------------------------------------
-- ContextMenu.lua
---------------------------------------------------------------------------
L["Guild name (Ctrl+C to copy):"] = "Gildenname (Strg+C zum Kopieren):"
L["Copy guild name"] = "Gildennamen kopieren"
L["Mute guild <%s>"] = "Gilde stummschalten <%s>"
L["Unmute guild <%s>"] = "Stummschaltung aufheben <%s>"
L["Unmute guild family <%s>"] = "Stummschaltung der Gildenfamilie aufheben <%s>"
L["Mute guild family <%s>"] = "Gildenfamilie stummschalten <%s>"

---------------------------------------------------------------------------
-- Commands.lua
---------------------------------------------------------------------------
L["/mg (opens the options) | on | off | list | log | scan | tally | import | clear"] =
    "/mg (öffnet die Optionen) | on | off | list | log | scan | tally | import | clear"
L["/mg guild add|remove Exact Guild Name"] = "/mg guild add|remove Exakter Gildenname"
L["/mg guild family Guild Name    (also mutes Guild Name 1, 2 ... and I, II ...; again to undo)"] =
    "/mg guild family Gildenname    (auch Gildenname 1, 2 ... und I, II ...; erneut: rückgängig)"
L["/mg add|remove|allow|check Player Name    (allow again to undo)"] =
    "/mg add|remove|allow|check Spielername    (allow erneut: rückgängig)"
L["/mg name add|remove text    (hides chat from players whose name contains it)"] =
    "/mg name add|remove Text    (blendet den Chat von Spielern aus, deren Name ihn enthält)"
L["/mg debug off|dry|live    (dry: report only, hide nothing; live: hide and report)"] =
    "/mg debug off|dry|live    (dry: nur melden, nichts ausblenden; live: ausblenden und melden)"
L["Separate several names with commas: /mg add Name1, Name2"] = "Mehrere Namen mit Kommas trennen: /mg add Name1, Name2"
L["guild list"] = "Gildenliste"
L["name list"] = "Namensliste"
L["hidden %s messages (%s this session) from %s muted players."] =
    "%s Nachrichten ausgeblendet (%s in dieser Sitzung) von %s stummgeschalteten Spielern."
L["filtering %s, %d players muted, debug mode %s."] = "Filterung %s, %d Spieler stummgeschaltet, Debug-Modus %s."
