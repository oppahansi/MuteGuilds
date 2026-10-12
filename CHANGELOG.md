# Changelog

## 0.4.0

- **Guild families.** A guild on your list can now also mute its numbered guilds: the same name followed by a number, such as *Olympus 2* or *Olympus II* (1, 2, 3 ... or I, II, III ... up to XXXIX). You no longer have to add each of them by hand.
- The option is set per guild: `/mg guild family Guild Name`, the new **Family** button on the options page, or **Mute guild family** in the right-click menu on a player. Using the command or the button again with the same name turns it off.
- Guilds with the option on are shown as *Name (family)* in the guild list.
- A guild whose name only contains a listed name, such as *Olympus Fans*, is still left alone.
- The `/who` scan and list sharing include guild families.

## 0.3.1

No changes to the addon itself. This is the first version published to CurseForge through the automatic release; everything listed under 0.3.0 is included.

## 0.3.0

First public release.

- **Exact guild matching.** A guild is muted only when its whole name is on your list (upper and lower case don't matter).
- **Chat filtering** for members of listed guilds in say, yell, whispers, channels, guild, party, raid and instance chat, including their chat bubbles in the open world.
- **Auto-decline** of guild invites, group invites and duels from muted players, and a question before you trade with one.
- **Warnings** when you whisper or invite a muted player, or when one is in your group, with the option to unmute them while grouped.
- **`/who` scan** that steps through your listed guilds by level range to find their members.
- **Right-click menu** on a player's unit frame: "Copy guild name" and "Mute guild" (or "Unmute guild").
- **Former members.** A player seen outside the guild they were muted for is unmuted, and their tooltip notes that they were in a muted guild before.
- **Your own guild** can't be muted.
- **Word filter and name filter**, a manual mute list, a never-mute list, and import from the game's ignore list.
- **Muted-messages log** of the last 15 minutes, from which you can report a message.
- **List sharing** with other MuteGuilds users; the receiver is always asked first.
- **Debug modes**: `dry` reports what would be hidden without hiding anything, `live` hides as normal and reports each hit.
- **German localization.** The addon follows the language of your game client.
