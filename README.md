# Raiders Tracker (WoW 3.3.5a)

**Raiders Tracker** (by Copper) is an all-in-one raid performance, utility, consumable, fail-analysis, and death-tracking addon built specifically for **World of Warcraft: Wrath of the Lich King (3.3.5a)**.

Leading a 10-man or 25-man raid takes enough focus without having to dig through raw combat logs mid-run to see who pre-potted, what spellpower your Demonology Warlock's Demonic Pact gave the raid, whether a tank used a defensive cooldown, which Rogue slacked on Tricks of the Trade, which Hunter missed a Tranquilizing Shot, or what actually killed someone on a wipe. **Raiders Tracker** automatically segments your raid into Trash and Boss pulls, snapshots your roster's buffs, tracks per-zone attendance time, and organizes potions, procs, class utility, raid fails, and detailed death logs into clean in-game panels—complete with a dedicated **Boss Fights Potions** copy panel, a 4-panel **Report Segment Hub** featuring throttled **Raid Chat** broadcasting, **Discord Markdown**, and **HTML Export**, plus an advanced **Player Blacklist System** with permanent character ID fingerprinting and secure Base64/XML import & export.

---

## Features for Raid Leaders & Raiders

### 1. Potions, Consumables, Buffs & Procs (`1. Potions and Buffs`)
See exactly who is showing up prepared and maximizing their character on every pull:
- **Pre-Pots & Combat Consumables:** Tracks Potion of Speed, Potion of Wild Magic, Indestructible Potion, Haste Potion, Destruction Potion, Insane Strength Potion, Powerful Rejuvenation Potion, Crazy Alchemist's Potion, Endless Healing/Mana Potions, Potion of Nightmares, Heroic Potion, Ironshield Potion, Free Action Potion, Living Action Potion, Mighty Rage Potion, Super Mana/Healing Potions, Runic Mana/Healing Potions & Injectors, Flame Cap, Thistle Tea, Dark Rune, Demonic Rune, Fel/Master Healthstones, and Mana Sapphires/Emeralds.

- **Automatic Boss Pull Buff Snapshotting:** The moment a boss is engaged, the addon scans the raid and snapshots persistent Flasks (Frost Wyrm, Endless Rage, Stoneblood, Pure Mojo, Lesser Flask of Toughness, Flask of the North SP/AP/STR, Distilled Wisdom), Battle & Guardian Elixirs, and Well Fed food buffs (including Fish Feasts).

- **5-Second Pre-Pull Capture:** Any potions, buffs, Demonic Pact procs, or utility spells used within **5 seconds before boss engage** are automatically migrated out of the `TRASH` segment and credited directly to the Boss encounter segment.

- **External Buffs Received (with Caster Attribution):** Displays who received Bloodlust, Heroism, Power Infusion, Hysteria, Tricks of the Trade (+15% Dmg), Innervate, Focus Magic, Pain Suppression, Guardian Spirit, Hand of Sacrifice, Hand of Protection, Hand of Salvation, Hand of Freedom, Divine Sacrifice, Divine Guardian, Aura Mastery, and Fear Ward—along with the class-colored name of the player who cast it on them.

- **Trinket, Ring, Profession & Enchant Procs:** Tracks procs from ICC Ashen Band rings, Engineering/Tailoring tinkers (Hyperspeed Accelerators, Flexweave Underlay, Lightweave/Swordguard/Darkglow Embroidery), weapon enchants (Berserking, Black Magic, Blade Ward, Blood Draining, Mongoose, Executioner), and Normal/Heroic WotLK raid trinkets—including all 6 distinct **Deathbringer's Will (N/HC)** transformation buffs, DFO, Phylactery, CTS, STS, Twilight Scales, Whispering Fanged Skull, Tiny Abomination, Death's Choice/Verdict, Satrina's/Juggernaut's Vitality, Talisman of Resurgence, Comet's Trail, Greatness, Mjolnir Runestone, Grim Toll, Flare of the Heavens, Pandora's Plea, Eye of the Broodmother, Muradin's Spyglass, Purified Lunar Dust, Althor's Abacus, Trauma, and Needle-Encrusted Scorpion.


### 2. Boss Fights Potions Summary Panel (`POTIONS`)
Click the **`POTIONS`** button on the Main Tracker window to quickly audit raid-wide consumable effort across an entire run:
- **Session-Wide Boss Aggregation:** Tallies every player's combat potion usage—including all combat potions/injectors, **Flame Cap**, **Thistle Tea**, **Dark Rune**, and **Demonic Rune**—across **all boss fights** (both **Victories** and **Wipes/Attempts**) in the selected session.
- **Ranked Copy-Ready Output:** Displays the total number of boss fights (victories vs. wipes), total players, grand total potions used, and a ranked list sorted by highest potion count showing each player's class, total potions used, boss fight attendance (`[X/Y fights]`), and itemized consumable breakdown.
- **Quick Copy & Navigation:** Opens pre-selected in a scrollable text box with a **`Select All`** button (`Ctrl+A`, `Ctrl+C`), closes immediately on pressing **`Escape`**, and includes a **`BACK to MAIN`** button that closes the panel and reopens the Main Tracker window.


### 3. Raid Utility, Cooldowns, Demonic Pact & Interrupts (`2. Raid Utility`)
Verify whether your raiders are using their class toolkit to help the group survive mechanics and maximize raid DPS:
- **Demonology Warlock Demonic Pact Tracking (Owner Only + Spellpower per Proc):** Automatically maps every raid and party pet to its owning Warlock (updating live on `UNIT_PET`) so **Demonic Pact** procs are attributed exclusively to the Demonology Warlock whose pet triggered the buff—never cluttered across the rest of the raid. Deduplicates raid-wide aura applications per Warlock and scans the active buff tooltip to record the exact spellpower granted on every proc on a single clean line in both the **Raid Utility** view and **Report Segment** exports:
  ```text
  Copperslave (WARLOCK):
  - Demonic Pact (5): 560, 700, 400, 450, 780
  ```

- **Full 10-Class Utility Coverage:** Tracks tank and personal defensive cooldowns (Shield Wall, Last Stand, Enraged Regeneration, Icebound Fortitude, Vampiric Blood, Unbreakable Armor, Bone Shield, Anti-Magic Shell/Zone, Divine Protection, Divine Shield, Barkskin, Survival Instincts, Frenzied Regeneration, Dispersion, Fade, Ice Block, Deterrence, Feign Death, Cloak of Shadows, Feint, Evasion, Shamanistic Rage), raid cooldowns (Divine Sacrifice, Divine Guardian, Aura Mastery, Tranquility, Divine Hymn, Hymn of Hope, Mana Tide Totem), interrupts (Kick, Pummel, Shield Bash, Mind Freeze, Strangulate, Wind Shear, Counterspell, Spell Lock), dispels/cleanses, taunts, and threat drops.

- **Targeted Utility Attribution:** When a raider casts an external spell on another member—such as **Rebirth**, **Soulstone Resurrection**, **Raise Ally**, **Tricks of the Trade**, **Misdirection**, **Innervate**, **Hand of Protection/Salvation/Freedom/Sacrifice**, **Lay on Hands**, **Sacred Shield**, **Pain Suppression**, **Guardian Spirit**, **Power Infusion**, **Hysteria**, **Fear Ward**, **Focus Magic**, **Vigilance**, **Intervene**, **Master's Call**, **Roar of Sacrifice**, **Slow Fall**, **Power Word: Shield**, or dispels/cleanses—the log shows the exact class-colored target they cast it on.

- **Engineering Explosives & Utility:** Tracks Global Thermal Sapper Charges, Saronite Bombs, Frag Belt, and Nitro Boosts.


### 4. Raid Deaths & Detailed Death Logs (`Deaths` & `Death Log`)
Stop guessing what caused a wipe or why a player died:
- **Session or Segment Death Rankings:** View a ranked list of player deaths sorted from highest to lowest across either **All Session Segments** or the **Selected Segment** (automatically ignoring Hunter Feign Death).

- **Combat-Elapsed Pull Timestamps & Overkill Tracking:** Click **Death Log** next to any player's name to see the exact combat-elapsed pull time (e.g., `+00:48 into pull`) alongside wall-clock time, segment name, killer (mob or environment), ability name, fatal damage amount, and overkill damage.

- **Smart Wipe-Cluster & Lich King RP Filtering:** Automatically filters out both The Lich King's 10% **Fury of Frostmourne** scripted raid wipe and mass wipe clusters (7 or more raiders dying within a 5-second window) so unavoidable wipe deaths are never flagged as individual mistakes in Raid Fails or Suspicious Deaths reports.


### 5. Player Blacklist, Character ID Fingerprinting & Import/Export (`Blacklist` & `Characters`)
Track, share, and screen problem raiders across name changes:
- **Persistent Character ID Fingerprinting:** Extracts the unique numeric character ID component from player GUIDs. Because this ID stays permanently tied to the character across renames, blacklisting a player tracks them regardless of any future name changes.
- **Multi-Name & Class History:** Records all known names encountered for a given character ID (displaying them as a comma-separated history list, e.g., *Names: Distordark, Kittyscratch*), alongside their character class, category reason, and timestamp.
- **Categorized Blacklist Reasons:** When blacklisting any raider from the **Characters** panel, choose from eight moderation categories: **`leaver`**, **`bad dps`**, **`unskilled`**, **`ninja`**, **`ninja pulls`**, **`low gs`**, **`afk bot`**, or **`rude`**.
- **Real-Time Group Join Warnings:** Whenever you join a party or raid, or when roster changes occur, the addon automatically scans group members against your blacklist and posts an immediate yellow warning alert to your chat frame if a blacklisted player is detected.
- **Secure Base64/XML Blacklist Export & Import:**
  - **`Export Blacklist`:** Exports your entire blacklist into a compact Base64-encoded XML string (`schema="1"`) ready to back up or share with guild officers (`Select All`, `Ctrl+C`).
  - **`Import Blacklist`:** Paste a Raiders Tracker Base64 export string and click **`Verify`** (dry-run preview) or **`Import`**. Strictly validates the Base64 encoding, XML schema, character IDs, names, classes, reasons, and timestamps (blocking corrupt or unsafe input), automatically omits duplicates, and merges newly discovered aliases onto existing character IDs.
  - **`Copy as Text`:** Generates a clean, plain-text copy of your blacklist for Discord or guild notes.
- **Dedicated Blacklist Management Panel:** Review all blacklisted character IDs, alias histories, classes, reasons, and dates from the Main Tracker window, with a one-click **Remove** button on every entry.


### 6. Multi-Panel Reporting Hub & Anti-Spam Raid Chat Queue (`Report Seg`)
Click **`Report Seg`** to open the 4-view Reporting Hub. Every view includes a read-only preview box and a **`Send to Raid`** button powered by an anti-spam message queue (`~0.20s` per line, auto-stripping color codes and wrapping lines over 255 characters so you never get disconnected for chat flooding):

1. **`1. ALL Data` Panel:**
   - Generates the complete segment breakdown (**1. Characters Present**, **2. Deaths & Death Log**, **3. Potions & Buffs**, and **4. Raid Utility**, including single-line **Demonic Pact** spellpower histories).
   - Switch between **Plain Text**, **Discord Markdown**, and **Export as HTML** (self-contained `#141419` dark-theme HTML with inline CSS class colors, `<h1>` headers, and nested `<ul>`/`<li>` lists) for instant copy-pasting, or click **Send to Raid**.
   - **Live HTML Output Sample:** <https://sites.google.com/view/raiders-tracker-by-copper/raiders-tracker-output>
2. **`2. Character` Panel:**
   - Select any raider from the segment via a custom zero-taint dropdown and toggle between two modes:
     - **`Buffs & Utility`:** Lists every potion, buff, proc, and utility spell used by that player (automatically condensing high-target spam like Discipline Priest `Power Word: Shield` into a clean summary line, e.g., `Power Word: Shield: 79 casts (across 24 targets)`, and showing Demo Warlock `Demonic Pact` counts + spellpower values on one line).
     - **`Character Fails`:** Pinpoints that specific player's mistakes in the pull—missing Flask/Elixir, missing Well Fed food buff, combat potion count (`0` or `1`), missed class duties, tank cooldown failures, zero total utility, and any personal defensive cooldowns left unused when they died.
3. **`3. Raid Fails` Panel:**
   - Dedicated sub-tabs with a configurable **`5 / 10 / 20 / All lines`** limit dropdown so raid chat callouts stay concise and highlight the highest-severity issues first:
     - **`1. Early Deaths`:** Lists deaths chronologically occurring in the first 75% of the fight with pull-elapsed timestamps (`+MM:SS into pull`), killing mob, and ability (excluding wipe clusters and `Fury of Frostmourne` RP deaths).
     - **`2. Slackers`:** Ranks raiders by severity for missing a Flask/Elixir, missing a Well Fed food buff, or using fewer than 2 combat potions (`0` or `1` potion used).
     - **`3. CD Fails`:** Ranks critical class duty and tank defensive failures:
       - **Rogues (`Tricks of the Trade`):** Calculates the maximum possible casts from the fight duration (`seg.duration / 30s` CD) and flags Rogues who under-cast Tricks.
       - **Hunters (`Misdirection` & `Tranquilizing Shot`):** Flags Hunters with low/zero `Misdirection` casts and tracks hostile Enrage/Frenzy effects (Shambling Horrors, Saviana Ragefire, Icehowl, Gluth, etc.) to flag Hunters with `0` `Tranquilizing Shot` casts when mobs enraged.
       - **Tanks (Defensive Cooldowns):** Automatically identifies tanks (via `Frost Presence`, `Righteous Fury`, or `Dire Bear Form` on pull/mid-fight, taunts, tank ring/trinket procs, or receiving Tricks/Misdirection) and flags any tank who used `0` major tank cooldowns.
       - **Zero Total Utility:** Flags any raider present in the encounter who recorded `0` total utility spell casts.
4. **`4. Suspicious Deaths` Panel:**
   - Generates a dedicated chronological death breakdown for raid chat showing pull-elapsed timestamp, clock time, player name + class, killing mob, ability, fatal damage + overkill, and unused personal defensive cooldowns (automatically filtering out wipe clusters and scripted RP deaths).


### 7. Automatic WotLK Boss Detection, Attendance Tracking & Session Archiving
- **All WotLK Raids Supported:** Built-in boss engage and victory detection (via Boss Yells/Emotes and Combat Log verification) for **Icecrown Citadel (ICC)** (including Valithria Dreamwalker 100% heal detection, full Lich King 10% Tirion Fordring RP support, automatic repair of split Lich King segments, and victory duration pinning to the moment **Fury of Frostmourne** triggers), **The Ruby Sanctum (RS)** (Halion plus mini-bosses Baltharus, Saviana, and Zarithrian), **Trial of the Crusader / ToGC** (including Northrend Beasts and all 28 Horde/Alliance Faction Champions), **Ulduar**, **Naxxramas**, **Vault of Archavon (VoA)**, **The Eye of Eternity**, **The Obsidian Sanctuary**, and **Onyxia's Lair**.

- **Dynamic Difficulty, Duration Labels & Live Footer:** Automatically detects **10N, 10HC, 25N, 25HC, 5N, and 5HC** difficulties in real time, numbers each pull (`[Attempt 1]`), stores exact fight durations, updates segments with the final outcome (`[Victory - 4m 12s]` or `[Wipe 1 - 2m 45s]`), and displays your live **Current Zone**, **Difficulty**, and **Raid/Party Size** in the tracker footer.

- **35-Second False-Pull Protection:** Non-victory boss pulls or resets that end in under **35 seconds** (or before combat starts) are automatically purged—weeding out false pulls and Rogue pre-pull combo-point setups to keep your segment history clean.

- **Paginated Segments & Session Archiving:** Browse long raid nights cleanly with **25 segments per page** (`<` / `>` pagination), archive runs with **`Save Session`** (which snapshots your Live Session and starts a fresh one), or remove individual pulls with **`Delete Seg`**. Joining a new party or raid prompts you to refresh the **Live Current Session** while preserving all **Saved Sessions** and your persistent **Player Blacklist**.

- **Session Characters, Raid Zone Online Time & Export (`Characters`):** Automatically tracks each raider's online duration per zone and detects the **Majority Raid Zone** for the session. View an alphabetical, class-colored roster showing every player's class and online time in the raid zone with one-click **`Blacklist`** and **`Whisper`** buttons—plus an **`Export Characters`** button to copy the complete attendance list (names, classes, and raid zone time) as plain text.

---

## Installation Instructions

### 1. Download the Addon
You can download **Raiders Tracker** in one of two ways from this GitHub repository:

- **Option A — From the Releases Section (Recommended):**
  1. Look for the **Releases** section on the right-hand sidebar of this GitHub page.
  2. Click on the latest release and download the attached `.zip` file.
- **Option B — Using the Green Code Button:**
  1. Click the green **`<> Code`** button near the top-right of this page.
  2. Select **Download ZIP** from the dropdown menu.

### 2. Install in Your WoW AddOns Folder
1. Open the downloaded `.zip` file and extract the addon folder.
2. Make sure the folder is named **`RaidersTracker`** (if you downloaded via the green **Code** button, GitHub appends `-main` or `-master` to the folder name—extract the inner folder and rename it to `RaidersTracker`).
3. Move the folder into your World of Warcraft 3.3.5a `AddOns` directory:
   ```text
   World of Warcraft\Interface\AddOns\RaidersTracker
   ```
   *(Make sure `RaidersTracker.toc` and `RaidersTracker.lua` are directly inside that folder and not nested inside a second subfolder.)*
4. Launch **World of Warcraft**, click the **AddOns** button in the bottom-left corner of the character selection screen, verify that **Raiders Tracker** is checked, and enable **Load out of date AddOns**.

---

## Commands & In-Game Controls

- **Minimap Button:**
  - **Left-Click:** Toggle the Main Tracker window.
  - **Right-Click:** Toggle the Config window (enable/disable recording, reset panel positions, delete all sessions while preserving the blacklist, or clear the blacklist).
  - **Left-Click + Drag:** Move the minimap icon around the edge of your minimap.
- **Chat Slash Commands:**
  - **`/rt`** or **`/raiderstracker`** — Toggle the Main Tracker window.
  - **`/rt reset`** — Reset all Raiders Tracker windows back to the center of your screen.
- **Keyboard Shortcut:**
  - **`Escape`** — Closes any open Raiders Tracker panel (including text-export, import, report, and potions copy windows).

---

## Bug Reports & Feature Ideas

**Raiders Tracker** is actively maintained for the 3.3.5a raiding community, and feedback from Raid Leaders, officers, and raiders is always welcome!

- **Found a Bug?** If an encounter transition, consumable, proc, fail check, or death log entry doesn't record as expected—or if you run into a Lua error—please open an issue in the **[Issues](../../issues)** tab at the top of this page. Let us know what raid/difficulty you were in and what happened.

- **Have an Idea to Improve the Addon?** If there is a specific spell, trinket proc, consumable, or raid-leading feature you'd like to see added in a future update, submit a feature request in the **[Issues](../../issues)** tab!
