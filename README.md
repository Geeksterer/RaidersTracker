# Raiders Tracker (WoW 3.3.5a)

**Raiders Tracker** (v1.2.2 by Copper) is an all-in-one raid performance, utility, consumable, fail-analysis, and death-tracking addon built specifically for **World of Warcraft: Wrath of the Lich King (3.3.5a)**.

Leading a 10-man or 25-man raid takes enough focus without having to dig through raw combat logs mid-run to see who pre-potted, whether a tank used a defensive cooldown, which Rogue slacked on Tricks of the Trade, which Hunter missed a Tranquilizing Shot, or what actually killed someone on a wipe. **Raiders Tracker** automatically segments your raid into Trash and Boss pulls, snapshots your roster's buffs, and organizes potions, procs, class utility, raid fails, and detailed death logs into clean in-game panels—complete with a 4-panel **Report Segment Hub** featuring throttled **Raid Chat** broadcasting, **Discord Markdown**, and **HTML Export**.

---

## Features for Raid Leaders & Raiders

### 1. Potions, Consumables, Buffs & Procs (`1. Potions and Buffs`)
See exactly who is showing up prepared and maximizing their character on every pull:
- **Pre-Pots & Combat Consumables:** Tracks Potion of Speed, Potion of Wild Magic, Indestructible Potion, Haste Potion, Destruction Potion, Insane Strength Potion, Powerful Rejuvenation Potion, Flame Cap, Thistle Tea, Runic Mana/Healing Potions & Injectors, Fel/Master Healthstones, and Mana Sapphires/Emeralds.
- **Automatic Boss Pull Buff Snapshotting:** The moment a boss is engaged, the addon scans the raid and snapshots persistent Flasks (Frost Wyrm, Endless Rage, Stoneblood, Pure Mojo, Lesser Flask of Toughness, Flask of the North SP/AP/STR, Distilled Wisdom), Battle & Guardian Elixirs, and Well Fed food buffs (including Fish Feasts).
- **5-Second Pre-Pull Capture:** Any potions, buffs, or utility spells used within **5 seconds before boss engage** are automatically migrated out of the `TRASH` segment and credited directly to the Boss encounter segment.
- **External Buffs Received (with Caster Attribution):** Displays who received Bloodlust, Heroism, Power Infusion, Hysteria, Tricks of the Trade (+15% Dmg), Innervate, Focus Magic, Pain Suppression, Guardian Spirit, Hand of Sacrifice, Hand of Protection, Hand of Salvation, Hand of Freedom, Divine Sacrifice, Divine Guardian, Aura Mastery, and Fear Ward—along with the class-colored name of the player who cast it on them.
- **Trinket, Ring, Profession & Enchant Procs:** Tracks procs from ICC Ashen Band rings, Engineering/Tailoring tinkers (Hyperspeed Accelerators, Flexweave Underlay, Lightweave/Swordguard/Darkglow Embroidery), weapon enchants (Berserking, Black Magic, Blade Ward, Blood Draining, Mongoose, Executioner), and Normal/Heroic WotLK raid trinkets—including all 6 distinct **Deathbringer's Will (N/HC)** transformation buffs, DFO, Phylactery, CTS, STS, Twilight Scales, Whispering Fanged Skull, Tiny Abomination, Death's Choice/Verdict, Satrina's/Juggernaut's Vitality, Talisman of Resurgence, Comet's Trail, Greatness, Mjolnir Runestone, Grim Toll, Flare of the Heavens, Pandora's Plea, Eye of the Broodmother, Muradin's Spyglass, Purified Lunar Dust, Althor's Abacus, Trauma, and Needle-Encrusted Scorpion.

### 2. Raid Utility, Cooldowns & Interrupts (`2. Raid Utility`)
Verify whether your raiders are using their class toolkit to help the group survive mechanics:
- **Full 10-Class Utility Coverage:** Tracks tank and personal defensive cooldowns (Shield Wall, Last Stand, Enraged Regeneration, Icebound Fortitude, Vampiric Blood, Unbreakable Armor, Bone Shield, Anti-Magic Shell/Zone, Divine Protection, Divine Shield, Barkskin, Survival Instincts, Frenzied Regeneration, Dispersion, Fade, Ice Block, Deterrence, Feign Death, Cloak of Shadows, Feint, Evasion, Shamanistic Rage), raid cooldowns (Divine Sacrifice, Divine Guardian, Aura Mastery, Tranquility, Divine Hymn, Hymn of Hope, Mana Tide Totem), interrupts (Kick, Pummel, Shield Bash, Mind Freeze, Strangulate, Wind Shear, Counterspell, Spell Lock), dispels/cleanses, taunts, and threat drops.
- **Targeted Utility Attribution:** When a raider casts an external spell on another member—such as **Rebirth**, **Soulstone Resurrection**, **Raise Ally**, **Tricks of the Trade**, **Misdirection**, **Innervate**, **Hand of Protection/Salvation/Freedom/Sacrifice**, **Lay on Hands**, **Sacred Shield**, **Pain Suppression**, **Guardian Spirit**, **Power Infusion**, **Hysteria**, **Fear Ward**, **Focus Magic**, **Vigilance**, **Intervene**, **Master's Call**, **Roar of Sacrifice**, **Slow Fall**, **Power Word: Shield**, or dispels/cleanses—the log shows the exact class-colored target they cast it on.
- **Engineering Explosives & Utility:** Tracks Global Thermal Sapper Charges, Saronite Bombs, Frag Belt, and Nitro Boosts.

### 3. Raid Deaths & Detailed Death Logs (`Deaths` & `Death Log`)
Stop guessing what caused a wipe or why a player died:
- **Session or Segment Death Rankings:** View a ranked list of player deaths sorted from highest to lowest across either **All Session Segments** or the **Selected Segment** (automatically ignoring Hunter Feign Death).
- **Combat-Elapsed Pull Timestamps & Overkill Tracking:** Click **Death Log** next to any player's name to see the exact combat-elapsed pull time (e.g., `+00:48 into pull`) alongside wall-clock time, segment name, killer (mob or environment), ability name, fatal damage amount, and overkill damage.
- **Smart Lich King RP Filtering:** Automatically recognizes The Lich King's 10% **Fury of Frostmourne** scripted raid wipe so mandatory RP deaths are never flagged as player mistakes in suspicious death or raid fail reports.

### 4. Multi-Panel Reporting Hub & Anti-Spam Raid Chat Queue (`Report Seg`)
Click **`Report Seg`** to open the 4-view Reporting Hub. Every view includes a read-only preview box and a **`Send to Raid`** button powered by an anti-spam message queue (`~0.20s` per line, auto-stripping color codes and wrapping lines over 255 characters so you never get disconnected for chat flooding):

1. **`1. Report ALL Data` Panel:**
   - Generates the complete segment breakdown (**1. Characters Present**, **2. Deaths & Death Log**, **3. Potions & Buffs**, and **4. Raid Utility**).
   - Switch between **Plain Text**, **Discord Markdown**, and **Export as HTML** (self-contained `#141419` dark-theme HTML with inline CSS class colors, `<h1>` headers, and nested `<ul>`/`<li>` lists) for instant copy-pasting, or click **Send to Raid**.
   - **Live HTML Output Sample:** <https://sites.google.com/view/raiders-tracker-by-copper/raiders-tracker-output>
2. **`2. Character Data` Panel:**
   - Select any raider from the segment via a custom zero-taint dropdown and toggle between two modes:
     - **`Character Buffs & Utility`:** Lists every potion, buff, proc, and utility spell used by that player (automatically condensing high-target spam like Discipline Priest `Power Word: Shield` into a clean summary line, e.g., `Power Word: Shield: 79 casts (across 24 targets)`).
     - **`Character Fails`:** Pinpoints that specific player's mistakes in the pull—missing Flask/Elixir, missing Well Fed food buff, combat potion count (`0` or `1`), missed class duties, tank cooldown failures, zero total utility, and any personal defensive cooldowns left unused when they died.
3. **`3. Report Raid Fails` Panel:**
   - Consolidates everyone's mistakes across the entire segment into three detailed sections:
     - **Section A — Early & Suspicious Deaths:** Lists deaths chronologically with pull-elapsed timestamps (`+MM:SS into pull`), killing mob, ability, damage + overkill, and any personal defensive cooldowns the player died without using (automatically excluding `Fury of Frostmourne` RP deaths).
     - **Section B — Consumable Slackers:** Flags raiders missing a Flask/Elixir, missing a Well Fed food buff, or using fewer than 2 combat potions (`0` or `1` potion used).
     - **Section C — Critical Class Duty & Tank Cooldown Fails:**
       - **Rogues (`Tricks of the Trade`):** Calculates the maximum possible casts from the fight duration (`seg.duration` / 30s CD) and flags Rogues who under-cast Tricks.
       - **Hunters (`Misdirection` & `Tranquilizing Shot`):** Flags Hunters with low/zero `Misdirection` casts and tracks hostile Enrage/Frenzy effects (Shambling Horrors, Saviana Ragefire, Icehowl, Gluth, etc.) to flag Hunters with `0` `Tranquilizing Shot` casts when mobs enraged.
       - **Tanks (Defensive Cooldowns):** Automatically identifies tanks (via `Frost Presence`, `Righteous Fury`, or `Dire Bear Form` on pull/mid-fight, taunts, tank ring/trinket procs, or receiving Tricks/Misdirection) and flags any tank who used `0` major tank cooldowns.
       - **Zero Total Utility:** Flags any raider present in the encounter who recorded `0` total utility spell casts.
4. **`4. Suspicious Deaths` Panel:**
   - Generates a dedicated chronological death breakdown for raid chat showing pull-elapsed timestamp, clock time, player name + class, killing mob, ability, fatal damage + overkill, and unused personal defensive cooldowns.

### 5. Automatic WotLK Boss Detection, Session Archiving & Roster Tools
- **All WotLK Raids Supported:** Built-in boss engage and victory detection (via Boss Yells/Emotes and Combat Log verification) for **Icecrown Citadel (ICC)** (including Valithria Dreamwalker 100% heal detection and full Lich King 10% Tirion Fordring RP support), **The Ruby Sanctum (RS)** (Halion plus mini-bosses Baltharus, Saviana, and Zarithrian), **Trial of the Crusader / ToGC** (including Northrend Beasts and all 28 Horde/Alliance Faction Champions), **Ulduar**, **Naxxramas**, **Vault of Archavon (VoA)**, **The Eye of Eternity**, **The Obsidian Sanctuary**, and **Onyxia's Lair**.
- **Dynamic Difficulty & Duration Labels:** Automatically detects **10N, 10HC, 25N, 25HC, 5N, and 5HC** difficulties in real time, numbers each pull (`[Attempt 1]`), stores exact fight durations, and updates the segment with the final outcome (`[Victory - 4m 12s]` or `[Wipe 1 - 2m 45s]`).
- **False-Pull Protection:** Non-victory boss pulls or resets that end in under 25 seconds or before combat starts are automatically purged to keep your segment dropdown clean.
- **Group Join Refresh Prompt & Session Archiving:** Joining a new party or raid prompts you to refresh the **Live Current Session** while preserving all of your **Saved Sessions** until you explicitly click **Delete All Sessions** in Config.
- **Session Characters & Quick Whisper (`Characters`):** View an alphabetical, class-colored list of every player recorded in the active session with a one-click **Whisper** button beside each name.

---

## Installation Instructions

### 1. Download the Addon
You can download **Raiders Tracker** in one of two ways from this GitHub repository:

- **Option A — From the Releases Section (Recommended):**
  1. Look for the **Releases** section on the right-hand sidebar of this GitHub page.
  2. Click on the latest release (`v1.2.0`) and download the attached `.zip` file.
- **Option B — Using the Green Code Button:**
  1. Click the green **`<> Code`** button near the top-right of this page.
  2. Select **Download ZIP** from the dropdown menu.

### 2. Install in Your WoW AddOns Folder
1. Open the downloaded `.zip` file and extract the addon folder.
2. Make sure the folder is named **`RaidersTracker`** (if you downloaded via the green **Code** button, GitHub appends `-main` or `-master` to the folder name— there is a folder inside the zip that has the addon name - place that in your AddOns folder).
3. Move the folder into your World of Warcraft 3.3.5a `AddOns` directory:
   ```text
   World of Warcraft\Interface\AddOns\RaidersTracker
   ```
   *(Make sure `RaidersTracker.toc` and `RaidersTracker.lua` are directly inside that folder and not nested inside a second subfolder.)*
4. Launch **World of Warcraft**, click the **AddOns** button in the bottom-left corner of the character selection screen, verify that **Raiders Tracker** is checked, and enable **Load out of date AddOns**.

---

## Commands & In-Game Controls

- **Minimap Button:**
  * **Left-Click:** Toggle the Main Tracker window.
  * **Right-Click:** Toggle the Config window (enable/disable recording, reset panel positions, or delete all saved sessions).
  * **Left-Click + Drag:** Move the minimap icon around the edge of your minimap.
- **Chat Slash Commands:**
  * **`/rt`** or **`/raiderstracker`** — Toggle the Main Tracker window.
  * **`/rt reset`** — Reset all Raiders Tracker windows back to the center of your screen.

---

## Bug Reports & Feature Ideas

**Raiders Tracker** is actively maintained for the 3.3.5a raiding community, and feedback from Raid Leaders, officers, and raiders is always welcome!

- **Found a Bug?** If an encounter transition, consumable, proc, fail check, or death log entry doesn't record as expected—or if you run into a Lua error—please open an issue in the **[Issues](../../issues)** tab at the top of this page. Let us know what raid/difficulty you were in and what happened.
- **Have an Idea to Improve the Addon?** If there is a specific spell, trinket proc, consumable, or raid-leading feature you'd like to see added in a future update, submit a feature request in the **[Issues](../../issues)** tab!
