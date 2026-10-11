# MuteGuilds

A World of Warcraft addon for the WoW Forever client (Interface 16001) that hides chat and invites from players in the guilds on your list.

A guild is muted only when its **whole name** matches an entry on your list (upper and lower case don't matter). A guild whose name merely contains a listed name is left alone.

Everything happens on your own screen. Nothing is added to your ignore list and the other player is not notified.

## Why this addon exists

MuteGuilds is for muting influencer and streamer guilds: any of them, whichever ones you choose. I play the game for the game, and I don't want to deal with the followings that form around streamers in it.

The idea comes from [OlympusMute](https://www.curseforge.com/wow/addons/olympusmute), which was made to mute one streamer's guilds, Asmongold's "Olympus", and ships with that name on its list. MuteGuilds is not aimed at that guild or at any other in particular. It ships with an empty list, and you decide which guilds go on it.

OlympusMute also mutes every guild whose name *contains* a keyword. That addon would not add exact guild-name matching, so MuteGuilds was written to provide it.

MuteGuilds is not a fork. It was rewritten from scratch as a new, multi-file codebase and shares no real code with OlympusMute, though it owes the idea and the feature set to it. Its saved settings and its list-sharing format are its own, so the two addons do not read each other's data.

It also goes further than its inspiration, most visibly with the debug modes described below.

## Features

- **Chat filtering** for players in listed guilds, across say, yell, whispers, channels, guild, party, raid and instance chat. Lines they already had on screen are removed when they are identified.
- **Guild learning.** Chat doesn't say which guild a sender is in, so players are identified when you target them, mouse over them, see their nameplate, group with them, or find them with `/who`.
- **`/who` scan** that steps through your listed guilds by level range, to reach members beyond the 50-result limit.
- **Auto-decline** of guild invites, group invites and duels from muted players. Group invites and duels are declined after a short random pause unless you choose "instantly".
- **Trade prompt** that asks before you trade with a muted player.
- **Warnings** when you whisper or invite a muted player, a tooltip line on muted players, and a window when a muted player is in your group, with the option to unmute them while grouped.
- **Chat bubbles** of muted players are hidden in the open world.
- **Word filter and name filter** for hiding messages by content or by character name, from anyone.
- **Manual lists**: mute a player by hand, or mark a player as never muted.
- **Muted-messages log** of the last 15 minutes, from which you can report a message.
- **Ignore-list import** to move players from the game's ignore list onto your mute list.
- **List sharing** of guild names and filtered words with other MuteGuilds users. The receiver is always asked first.

## Debug modes

For testing your lists, or the addon itself: `/mg debug off|dry|live`, or the Debug button on the options page.

| Mode | What it does |
| --- | --- |
| `off` | Normal operation, no debug output. |
| `dry` | Dry run. Nothing is hidden or declined. Every hit is reported with what would have happened and why. |
| `live` | Normal operation, and every hit is reported as it happens: who was muted and what was hidden or declined. |

## Usage

Open the options with `/mg` (or `/muteguilds`), or under Options > AddOns > MuteGuilds.

| Command | Effect |
| --- | --- |
| `/mg guild add Exact Guild Name` | Mute a guild. `guild remove` takes it off the list. |
| `/mg add Name` / `remove Name` | Mute or unmute a player by hand. |
| `/mg allow Name` | Never mute this player (again to undo). |
| `/mg check Name` | Say whether a player is muted. |
| `/mg word add text` / `name add text` | Add to the word filter or the name filter (`remove` to undo). |
| `/mg scan` | Run the next `/who` search. |
| `/mg list` / `log` | Open the muted-players list or the muted-messages log. |
| `/mg on` / `off` | Turn filtering on or off. |
| `/mg share [Name\|guild]` | Share your lists with a player, your guild, or (no name) your group. |
| `/mg import` | Import your ignore list. |
| `/mg help` | List every command. |

Several entries can be given at once, separated by commas.

## Installation

Copy the `MuteGuilds` folder into `World of Warcraft\_classic_beta_\Interface\AddOns\` and restart the game.

## Development

Plain Lua 5.1, no libraries and no build step. Format with `stylua .` and lint with `luacheck .`. Testing is done in-game.

## License

[MIT](LICENSE)
