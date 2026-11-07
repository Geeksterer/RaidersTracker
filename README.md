# Raiders Tracker (WoW 3.3.5a)

**Raiders Tracker** (v1.1.3 by Copper) is an all-in-one raid performance, utility, consumable, and death-tracking addon built specifically for **World of Warcraft: Wrath of the Lich King (3.3.5a)**.

Leading a 10-man or 25-man raid takes enough focus without having to dig through raw combat logs mid-run to see who pre-potted, whether a tank used a defensive cooldown, who cast Tricks of the Trade, or what actually killed someone on a wipe. **Raiders Tracker** automatically segments your raid into Trash and Boss pulls, snapshots your roster's buffs, and organizes potions, procs, class utility, and detailed death logs into clean in-game panels—complete with a one-click **Discord Markdown** report generator.

---

## Features for Raid Leaders & Raiders

### 1. Potions, Consumables, Buffs & Procs (`1. Potions and Buffs`)
See exactly who is showing up prepared and maximizing their character on every pull:
* **Pre-Pots & Combat Consumables:** Tracks Potion of Speed, Potion of Wild Magic, Indestructible Potion, Haste Potion, Destruction Potion, Insane Strength Potion, Powerful Rejuvenation Potion, Flame Cap, Thistle Tea, Runic Mana/Healing Potions & Injectors, Fel/Master Healthstones, and Mana Sapphires/Emeralds.
* **Automatic Boss Pull Buff Snapshotting:** The moment a boss is engaged, the addon scans the raid and snapshots persistent Flasks (Frost Wyrm, Endless Rage, Stoneblood, Pure Mojo, Lesser Flask of Toughness, Flask of the North SP/AP/STR, Distilled Wisdom), Battle & Guardian Elixirs, and Well Fed food buffs (including Fish Feasts).
* **5-Second Pre-Pull Capture:** Any potions, buffs, or utility spells used within **5 seconds before boss engage** are automatically migrated out of the `TRASH` segment and credited directly to the Boss encounter segment.
* **External Buffs Received (with Caster Attribution):** Displays who received Bloodlust, Heroism, Power Infusion, Hysteria, Tricks of the Trade (+15% Dmg), Innervate, Focus Magic, Pain Suppression, Guardian Spirit, Hand of Sacrifice, Hand of Protection, Hand of Salvation, Hand of Freedom, Divine Sacrifice, Divine Guardian, Aura Mastery, and Fear Ward—along with the class-colored name of the player who cast it on them.
* **Trinket, Ring, Profession & Enchant Procs:** Tracks procs from ICC Ashen Band rings, Engineering/Tailoring tinkers (Hyperspeed Accelerators, Flexweave Underlay, Lightweave/Swordguard/Darkglow Embroidery), weapon enchants (Berserking, Black Magic, Blade Ward, Blood Draining, Mongoose, Executioner), and Normal/Heroic WotLK raid trinkets (DBW, DFO, Phylactery, CTS, STS, Twilight Scales, Whispering Fanged Skull, Tiny Abomination, Death's Choice/Verdict, Satrina's/Juggernaut's Vitality, Talisman of Resurgence, Comet's Trail, Greatness, Mjolnir Runestone, Grim Toll, Flare of the Heavens, Pandora's Plea, Eye of the Broodmother, Muradin's Spyglass, Purified Lunar Dust, Althor's Abacus, Trauma, and Needle-Encrusted Scorpion).

### 2. Raid Utility, Cooldowns & Interrupts (`2. Raid Utility`)
Verify whether your raiders are using their class toolkit to help the group survive mechanics:
* **Full 10-Class Utility Coverage:** Tracks tank and personal defensive cooldowns (Shield Wall, Last Stand, Enraged Regeneration, Icebound Fortitude, Vampiric Blood, Unbreakable Armor, Bone Shield, Anti-Magic Shell/Zone, Divine Protection, Divine Shield, Barkskin, Survival Instincts, Frenzied Regeneration, Dispersion, Ice Block, Deterrence, Cloak of Shadows, Feint, Evasion), raid cooldowns (Divine Sacrifice, Divine Guardian, Aura Mastery, Tranquility, Divine Hymn, Hymn of Hope, Mana Tide Totem), interrupts (Kick, Pummel, Shield Bash, Mind Freeze, Strangulate, Wind Shear, Counterspell, Spell Lock), dispels/cleanses, taunts, and threat drops.
* **Targeted Utility Attribution:** When a raider casts an external spell on another member—such as **Rebirth**, **Soulstone Resurrection**, **Raise Ally**, **Tricks of the Trade**, **Misdirection**, **Innervate**, **Hand of Protection/Salvation/Freedom/Sacrifice**, **Lay on Hands**, **Sacred Shield**, **Pain Suppression**, **Guardian Spirit**, **Power Infusion**, **Hysteria**, **Fear Ward**, **Focus Magic**, **Vigilance**, **Intervene**, **Master's Call**, **Roar of Sacrifice**, **Slow Fall**, **Power Word: Shield**, or dispels/cleanses—the log shows the exact class-colored target they cast it on.
* **Engineering Explosives & Utility:** Tracks Global Thermal Sapper Charges, Saronite Bombs, Frag Belt, and Nitro Boosts.

### 3. Raid Deaths & Detailed Death Logs (`Deaths` & `Death Log`)
Stop guessing what caused a wipe or why a player died:
* **Session or Segment Death Rankings:** View a ranked list of player deaths sorted from highest to lowest across either **All Session Segments** or the **Selected Segment** (automatically ignoring Hunter Feign Death).
* **Granular Per-Player Death Log:** Click **Death Log** next to any player's name to see the exact timestamp, segment name, killer (mob or environment), ability name, fatal damage amount, and overkill damage for every death.

### 4. Automatic WotLK Boss Detection & Difficulty Tracking
* **All WotLK Raids Supported:** Built-in boss engage and victory detection (via Boss Yells/Emotes and Combat Log verification) for **Icecrown Citadel (ICC)**, **The Ruby Sanctum (RS)**, **Trial of the Crusader / ToGC** (including multi-boss Northrend Beasts and all 28 Horde/Alliance Faction Champions), **Ulduar**, **Naxxramas**, **Vault of Archavon (VoA)**, **The Eye of Eternity**, **The Obsidian Sanctuary**, and **Onyxia's Lair**.
* **Dynamic Difficulty & Attempt Labels:** Automatically detects **10N, 10HC, 25N, 25HC, 5N, and 5HC** difficulties in real time, numbers each pull (`[Attempt 1]`), and updates the segment with the final outcome and fight duration (`[Victory - 4m 12s]` or `[Wipe 1 - 2m 45s]`).
* **False-Pull Protection:** Boss pulls or resets that end in under 15 seconds or before combat starts are automatically purged to keep your segment dropdown clean.

### 5. Instant Discord Reports, Session Archiving & Roster Tools
* **One-Click Segment Reports (`Report Seg`):** Generates a full summary of the selected segment organized into four sections: **1. Characters Present**, **2. Deaths & Death Log**, **3. Potions & Buffs**, and **4. Raid Utility**.
* **Discord Markdown Toggle:** Check the **Discord Markdown Format** box in the report window, press `Ctrl+C`, and paste a clean, pre-formatted report directly into your guild's Discord channel.
* **Session Saving & Alt Login Detection:** Save your **Live Current Session** into timestamped **Saved Sessions** at any time. If you log onto an alt while data from your previous character is still in the live session, a popup automatically asks if you want to save that session and start fresh.
* **Session Characters & Quick Whisper (`Characters`):** View an alphabetical, class-colored list of every player recorded in the active session with a one-click **Whisper** button beside each name.

---

## Installation Instructions

### 1. Download the Addon
You can download **Raiders Tracker** in one of two ways from this GitHub repository:

* **Option A — From the Releases Section (Recommended):**
  1. Look for the **Releases** section on the right-hand sidebar of this GitHub page.
  2. Click on the latest release and download the attached `.zip` file.
* **Option B — Using the Green Code Button:**
  1. Click the green **`<> Code`** button near the top-right of this page.
  2. Select **Download ZIP** from the dropdown menu.

### 2. Install in Your WoW AddOns Folder
1. Open the downloaded `.zip` file and extract the addon folder.
2. Make sure the folder is named **`RadiersTracker`** / **`RaidersTracker`** (if you downloaded via the green **Code** button, GitHub appends `-main` or `-master` to the folder name—remove `-main` or `-master` before placing it in your AddOns folder).
3. Move the folder into your World of Warcraft 3.3.5a `AddOns` directory:
   ```text
   World of Warcraft\Interface\AddOns\RadiersTracker
   ```
   *(Make sure the `.toc` and `.lua` files are directly inside that folder and not nested inside a second subfolder.)*
4. Launch **World of Warcraft**, click the **AddOns** button in the bottom-left corner of the character selection screen, verify that **Raiders Tracker** is checked, and enable **Load out of date AddOns**.

---

## Commands & In-Game Controls

* **Minimap Button:**
  * **Left-Click:** Toggle the Main Tracker window.
  * **Right-Click:** Toggle the Config window (enable/disable recording, reset panel positions, or delete all saved sessions).
  * **Left-Click + Drag:** Move the minimap icon around the edge of your minimap.
* **Chat Slash Commands:**
  * **`/rt`** or **`/raiderstracker`** — Toggle the Main Tracker window.
  * **`/rt reset`** — Reset all Raiders Tracker windows back to the center of your screen.

---

## Bug Reports & Feature Ideas

**Raiders Tracker** is actively maintained for the 3.3.5a raiding community, and feedback from Raid Leaders, officers, and raiders is always welcome!

* **Found a Bug?** If an encounter transition, consumable, proc, or death log entry doesn't record as expected—or if you run into a Lua error—please open an issue in the **[Issues](../../issues)** tab at the top of this page. Let us know what raid/difficulty you were in and what happened.
* **Have an Idea to Improve the Addon?** If there is a specific spell, trinket proc, consumable, or raid-leading feature you'd like to see added in a future update, submit a feature request in the **[Issues](../../issues)** tab!
