# Raiders Tracker (WoW 3.3.5a)

**Raiders Tracker (v1.3.0 by Copper)** is an all-in-one raid performance, utility, consumable, fail-analysis, attendance, and death-tracking addon built specifically for **World of Warcraft: Wrath of the Lich King (3.3.5a)**.

Leading a 10-man or 25-man raid takes enough focus without having to dig through raw combat logs mid-run to see who pre-potted, what spellpower and uptime your Demonology Warlock's Demonic Pact gave the raid, whether a tank used a defensive cooldown, which Rogue slacked on Tricks of the Trade, which Hunter missed a Tranquilizing Shot, or what actually killed someone on a wipe. **Raiders Tracker** automatically segments your raid into Trash and Boss pulls, snapshots your roster's buffs, tracks group-only per-zone attendance time, and organizes potions, procs, class utility, raid fails, and detailed death logs into clean, consistently laid-out in-game panels—complete with a 5-tab **Reports Hub** (with synced Session/Segment dropdowns, **Boss Potions**, throttled **Raid Chat** broadcasting with safety confirmations, **Discord Markdown**, and **HTML Export**) plus an advanced **Player Blacklist System** with permanent character ID fingerprinting and secure Base64/XML import & export.

---

## Features for Raid Leaders & Raiders

### 1. Potions, Consumables, Buffs & Procs (`1. Potions and Buffs`)
See exactly who is showing up prepared and maximizing their character on every pull:
- **`Filter: Everything` / `Filter: Consumables Only` Toggle:** Switch instantaneously between viewing all tracked activity or filtering strictly to **Consumables Only** (combat potions/injectors, Flame Cap, Thistle Tea, Dark/Demonic Runes, Healthstones, Mana Gems, Flasks, Elixirs, and Well Fed/Fish Feast)—hiding trinket, ring, enchant, profession proc, and external buff noise during quick pre-pot and food/flask audits.

- **Pre-Pots & Combat Consumables:** Tracks Potion of Speed, Potion of Wild Magic, Indestructible Potion, Haste Potion, Destruction Potion, Insane Strength Potion, Powerful Rejuvenation Potion, Crazy Alchemist's Potion, Endless Healing/Mana Potions, Potion of Nightmares, Heroic Potion, Ironshield Potion, Free Action Potion, Living Action Potion, Mighty Rage Potion, Super Mana/Healing Potions, Runic Mana/Healing Potions & Injectors, Flame Cap, Thistle Tea, Dark Rune, Demonic Rune, Fel/Master Healthstones, and Mana Sapphires/Emeralds.

- **Automatic Boss Pull Buff Snapshotting:** The moment a boss is engaged, the addon scans the raid and snapshots persistent Flasks (Frost Wyrm, Endless Rage, Stoneblood, Pure Mojo, Lesser Flask of Toughness, Flask of the North SP/AP/STR, Distilled Wisdom), Battle & Guardian Elixirs, and Well Fed food buffs (including Fish Feasts).

- **5-Second Pre-Pull Capture:** Any potions, buffs, Demonic Pact procs, or utility spells used within **5 seconds before boss engage** are automatically migrated out of the `TRASH` segment and credited directly to the Boss encounter segment.

- **External Buffs Received (with Caster Attribution):** Displays who received Bloodlust, Heroism, Power Infusion, Hysteria, Tricks of the Trade (+15% Dmg), Innervate, Focus Magic, Pain Suppression, Guardian Spirit, Hand of Sacrifice, Hand of Protection, Hand of Salvation, Hand of Freedom, Divine Sacrifice, Divine Guardian, Aura Mastery, and Fear Ward—along with the class-colored name of the player who cast it on them.

- **Trinket, Ring, Profession & Enchant Procs:** Tracks procs from ICC Ashen Band rings, Engineering/Tailoring tinkers (Hyperspeed Accelerators, Flexweave Underlay, Lightweave/Swordguard/Darkglow Embroidery), weapon enchants (Berserking, Black Magic, Blade Ward, Blood Draining, Mongoose, Executioner), and Normal/Heroic WotLK raid trinkets—including all 6 distinct **Deathbringer's Will (N/HC)** transformation buffs, DFO, Phylactery, CTS, STS, Twilight Scales, Whispering Fanged Skull, Tiny Abomination, Death's Choice/Verdict, Satrina's/Juggernaut's Vitality, Talisman of Resurgence, Comet's Trail, Greatness, Mjolnir Runestone, Grim Toll, Flare of the Heavens, Pandora's Plea, Eye of the Broodmother, Muradin's Spyglass, Purified Lunar Dust, Althor's Abacus, Trauma, and Needle-Encrusted Scorpion.


### 2. Raid Utility, Cooldowns, Demonic Pact & Interrupts (`2. Raid Utility`)
Verify whether your raiders are using their class toolkit to help the group survive mechanics and maximize raid DPS:
- **Demonology Warlock Demonic Pact Analytics (Owner Only + Avg SP, Uptime & Possible Procs):**
  - Automatically maps raid and party pets to their owning Warlock (updating live on `UNIT_PET`, with duplicate pet-name protection) so **Demonic Pact** procs are attributed strictly to the Warlock whose pet triggered the raid buff—never locked in across fights or confused when a Warlock dual-specs mid-raid (`PLAYER_TALENT_UPDATE` / `ACTIVE_TALENT_GROUP_CHANGED`).
  - Captures each proc's exact spellpower on 3.3.5a via direct Demo Warlock calculation + hidden `RT_DP` raid addon sync, with tooltip scanning and live `GetSpellBonusDamage` stat-delta fallbacks (accounting for overridden Totem of Wrath and Flametongue Totem buffs).
  - Filters out passive talent IDs, non-player pet/guardian destinations, and non-refresh aura re-evaluations (Shaman totem pulses, range re-entry) using an 18s per-Warlock ICD and live buff `expirationTime` verification.
  - Displays every proc's spellpower on one clean line followed by a dedicated summary line showing **Average SP**, **Merged-Interval Uptime %**, and **Actual / Possible Procs** (based on the 20s ICD) in both the **Raid Utility** tab and **Reports Hub** exports:
    ```text
    Copperslave (WARLOCK):
    - Demonic Pact (5): 560, 700, 400, 450, 780
      (Avg: 578 SP | Uptime: 94% | 5/7 possible procs)
    ```

- **Full 10-Class Utility Coverage:** Tracks tank and personal defensive cooldowns (Shield Wall, Last Stand, Enraged Regeneration, Icebound Fortitude, Vampiric Blood, Unbreakable Armor, Bone Shield, Anti-Magic Shell/Zone, Divine Protection, Divine Shield, Barkskin, Survival Instincts, Frenzied Regeneration, Dispersion, Fade, Ice Block, Deterrence, Feign Death, Cloak of Shadows, Feint, Evasion, Shamanistic Rage), raid cooldowns (Divine Sacrifice, Divine Guardian, Aura Mastery, Tranquility, Divine Hymn, Hymn of Hope, Mana Tide Totem), interrupts (Kick, Pummel, Shield Bash, Mind Freeze, Strangulate, Wind Shear, Counterspell, Spell Lock), dispels/cleanses, taunts, and threat drops.

- **Targeted Utility Attribution:** When a raider casts an external spell on another member—such as **Rebirth**, **Soulstone Resurrection**, **Raise Ally**, **Tricks of the Trade**, **Misdirection**, **Innervate**, **Hand of Protection/Salvation/Freedom/Sacrifice**, **Lay on Hands**, **Sacred Shield**, **Pain Suppression**, **Guardian Spirit**, **Power Infusion**, **Hysteria**, **Fear Ward**, **Focus Magic**, **Vigilance**, **Intervene**, **Master's Call**, **Roar of Sacrifice**, **Slow Fall**, **Power Word: Shield**, or dispels/cleanses—the log shows the exact class-colored target they cast it on.

- **Engineering Explosives & Utility:** Tracks Global Thermal Sapper Charges, Saronite Bombs, Frag Belt, and Nitro Boosts.


### 3. 5-Tab Reports Hub & Anti-Spam Raid Chat Queue (`Reports`)
Click **`Reports`** on the Main Tracker window to open the expanded `740×560` **Reports Hub**. Synced **Session** and **Segment** dropdowns (with `<` / `>` pagination) sit right at the top so you can audit multiple bosses or saved sessions without ever leaving Reports. Every tab includes a read-only preview box, a one-click **`Select All`** button (`Ctrl+C`), and a **`Send to Raid`** button powered by an anti-spam queue (`~0.20s` per line, auto-stripping color codes and wrapping lines over 255 characters) with two built-in broadcast safeguards:
- **Large-Report Confirmation Popup:** Prompts for confirmation whenever sending a report longer than **25 lines** to Raid/Party chat.
- **`Stop Sending` Emergency Cancel:** While a multi-line report is actively broadcasting, **`Send to Raid`** turns into a red **`Stop Sending`** button to immediately halt the queue.

The Reports Hub organizes every report into five tabs:
1. **`1. ALL Data`:**
   - Generates the complete segment breakdown (**1. Characters Present**, **2. Deaths & Death Log**, **3. Potions & Buffs** or **Consumables Only**, and **4. Raid Utility** including Demonic Pact spellpower histories and summary lines).
   - Switch between **Plain Text**, **Discord Markdown**, and **Export as HTML** (self-contained `#141419` dark-theme HTML with inline CSS class colors, `<h1>` headers, and nested `<ul>`/`<li>` lists), plus toggle **`Filter: Everything` / `Filter: Consumables Only`**.
   - **Live HTML Output Sample:** <https://sites.google.com/view/raiders-tracker-by-copper/raiders-tracker-output>
2. **`2. Character`:**
   - Select any raider from the segment via a custom zero-taint dropdown and toggle between two modes:
     - **`Buffs & Utility`:** Lists every potion, buff, proc, and utility spell used by that player—with a **`Filter: Everything` / `Filter: Consumables Only`** toggle, automatic condensation of high-target spam (e.g., `Power Word: Shield: 79 casts (across 24 targets)`), and Demo Warlock `Demonic Pact` proc lists + Avg SP/Uptime/Possible Procs summary.
     - **`Character Fails`:** Pinpoints that specific player's mistakes in the pull—missing Flask/Elixir, missing Well Fed food buff, combat potion count (`0` or `1`), missed class duties, tank cooldown failures, zero total utility, and any personal defensive cooldowns left unused when they died.
3. **`3. Raid Fails`:**
   - Dedicated sub-tabs with a configurable **`5 / 10 / 20 / All lines`** limit dropdown so raid chat callouts stay concise and highlight the highest-severity issues first:
     - **`1. Early Deaths`:** Lists deaths chronologically occurring in the first 75% of the fight with pull-elapsed timestamps (`+MM:SS into pull`), killing mob, and ability (excluding wipe clusters and `Fury of Frostmourne` RP deaths).
     - **`2. Slackers`:** Ranks raiders by severity for missing a Flask/Elixir, missing a Well Fed food buff, or using fewer than 2 combat potions (`0` or `1` potion used).
     - **`3. CD Fails`:** Ranks critical class duty and tank defensive failures:
       - **Rogues (`Tricks of the Trade`):** Calculates the maximum possible casts from the fight duration (`seg.duration / 30s` CD) and flags Rogues who under-cast Tricks.
       - **Hunters (`Misdirection` & `Tranquilizing Shot`):** Flags Hunters with low/zero `Misdirection` casts and tracks hostile Enrage/Frenzy effects (Shambling Horrors, Saviana Ragefire, Icehowl, Gluth, etc.) to flag Hunters with `0` `Tranquilizing Shot` casts when mobs enraged.
       - **Tanks (Defensive Cooldowns):** Automatically identifies tanks (via `Frost Presence`, `Righteous Fury`, or `Dire Bear Form` on pull/mid-fight, taunts, tank ring/trinket procs, or receiving Tricks/Misdirection) and flags any tank who used `0` major tank cooldowns.
       - **Zero Total Utility:** Flags any raider present in the encounter who recorded `0` total utility spell casts.
4. **`4. Deaths`:**
   - Generates a chronological **Suspicious Deaths** breakdown for copy or raid chat showing pull-elapsed timestamp, clock time, player name + class, killing mob, ability, fatal damage + overkill, and unused personal defensive cooldowns (filtering out wipe clusters and scripted RP deaths).
   - Includes a direct **`Deaths & Death Log`** button to open the interactive ranked death leaderboard and per-player Death Log viewer.
5. **`5. Boss Potions`:**
   - Tallies every player's combat potion usage—including all combat potions/injectors, **Flame Cap**, **Thistle Tea**, **Dark Rune**, and **Demonic Rune**—with a scope toggle between **`Scope: All Boss Fights (Session)`** (all victories and wipes/attempts combined) and **`Scope: Selected Segment`**.
   - Outputs a ranked, copyable, and raid-chat-ready summary showing total fights (victories vs. wipes), total players, grand total potions used, per-player boss fight attendance (`[X/Y fights]`), and itemized consumable breakdowns.


### 4. Raid Deaths & Split-View Death Logs (`Deaths & Death Log`)
Accessed directly from **`Reports` → `4. Deaths` → `Deaths & Death Log`** (with **`Back to Reports`** returning right back to the Reports Hub):
- **Session or Segment Death Rankings:** View a ranked list of player deaths sorted from highest to lowest across either **All Session Segments** or the **Selected Segment** (automatically ignoring Hunter Feign Death).

- **Per-Player Split-View Death Log (`All Segments` / `Current Segment`):** Click **`Death Log`** next to any player's name to inspect their fatal hits—with inline **`All Segments`** and **`Current Segment`** toggle buttons right at the top of the Death Log window so you can switch scope without backing out. Shows exact combat-elapsed pull time (e.g., `+00:48 into pull`), wall-clock time, segment name, killer (mob or environment), ability name, fatal damage amount, and overkill damage.

- **Smart Wipe-Cluster & Lich King RP Filtering:** Automatically filters out both The Lich King's 10% **Fury of Frostmourne** scripted raid wipe and mass wipe clusters (7 or more raiders dying within a 5-second window) so unavoidable wipe deaths are never flagged as individual mistakes in Raid Fails or Suspicious Deaths reports.


### 5. Session Characters, Attendance & Player Blacklist (`Characters` & `Blacklist`)
Track raid attendance and screen problem raiders across name changes:
- **Live Active vs. Total Roster Counts & Sorting (`Characters`):** Displays **`Players: Active: X | Total: Y`** (updating live on roster changes) alongside **`Sort: Name` / `Sort: Time`** and **`Show: All` / `Show: Active Only`** toggles, plus the detected **Majority Raid Zone**.
- **Group-Only Zone Time (Previous + Current Raid Only):** Tracks online zone time strictly while in a raid or party (never when solo). If you or a raider leave a group and rejoin later, your previous raid time in that zone is added to your current raid time without stacking unlimited older sessions.
- **One-Click Roster Actions & Export:** Every player row includes **`Blacklist`** and **`Whisper`** buttons, plus an **`Export Characters`** panel to copy names, classes, active/total counts, and raid zone online time as plain text.
- **Persistent Character ID Fingerprinting (`Blacklist`):** Extracts the unique numeric character ID component from player GUIDs so blacklisted players stay tracked across name changes, recording their full comma-separated alias history (e.g., *Names: Distordark, Kittyscratch*), class, reason, and timestamp.
- **8 Categorized Blacklist Reasons:** Choose from **`leaver`**, **`bad dps`**, **`unskilled`**, **`ninja`**, **`ninja pulls`**, **`low gs`**, **`afk bot`**, or **`rude`**.
- **Real-Time Group Join Warnings:** Automatically scans raid/party rosters against your blacklist and posts an immediate yellow warning alert in chat if a blacklisted player joins.
- **Secure Base64/XML Blacklist Export & Import:**
  - **`Export Blacklist`:** Exports your entire blacklist into a compact Base64-encoded XML string (`schema="1"`) ready to back up or share (`Select All`, `Ctrl+C`).
  - **`Import Blacklist`:** Paste a Raiders Tracker Base64 export string and click **`Verify`** (dry-run preview) or **`Import`**. Strictly validates Base64 encoding, XML schema, IDs, names, classes, reasons, and timestamps, omits duplicates, and merges newly discovered aliases onto existing IDs.
  - **`Copy as Text`:** Generates a clean plain-text copy of your blacklist for Discord or guild notes.


### 6. Automatic WotLK Boss Detection, Navigation & Session Archiving
- **All WotLK Raids Supported:** Built-in boss engage and victory detection (via Boss Yells/Emotes and Combat Log verification) for **Icecrown Citadel (ICC)** (including Valithria Dreamwalker 100% heal detection, full Lich King 10% Tirion Fordring RP support, automatic repair of split Lich King segments, and victory duration pinning to the moment **Fury of Frostmourne** triggers), **The Ruby Sanctum (RS)** (Halion plus mini-bosses Baltharus, Saviana, and Zarithrian), **Trial of the Crusader / ToGC** (including Northrend Beasts and all 28 Horde/Alliance Faction Champions), **Ulduar**, **Naxxramas**, **Vault of Archavon (VoA)**, **The Eye of Eternity**, **The Obsidian Sanctuary**, and **Onyxia's Lair**.

- **Dynamic Difficulty, Duration Labels & Live Footer:** Automatically detects **10N, 10HC, 25N, 25HC, 5N, and 5HC** difficulties in real time, numbers each pull (`[Attempt 1]`), stores exact fight durations, updates segments with the final outcome (`[Victory - 4m 12s]` or `[Wipe 1 - 2m 45s]`), and displays your live **Current Zone**, **Difficulty**, and **Raid/Party Size** in the tracker footer.

- **35-Second False-Pull Protection:** Non-victory boss pulls or resets that end in under **35 seconds** (or before combat starts) are automatically purged—weeding out false pulls and extended Rogue pre-pull combo-point setups to keep your segment history clean.

- **Paginated Segments & Smarter Session Archiving:** Browse long raid nights cleanly with **25 segments per page** (`<` / `>` pagination), archive runs with **`Save Session`** (which snapshots your run and keeps you directly on **`Live Current Session`**), or remove individual pulls with **`Delete Seg`**. Whenever you manually switch to an archived session, the Session dropdown highlights amber with a **`[Saved]`** indicator so you never confuse archived data with live tracking. Joining a new party or raid prompts you to refresh the **Live Current Session** while preserving all **Saved Sessions** and your persistent **Player Blacklist**.

- **Consistent Cross-Panel Layout:** Every panel follows a unified layout—**`Back to ...`** navigation anchored on the bottom-left and primary actions (`Send to Raid`, `Select All`, `Export`, `Import`) aligned on the bottom-right, with **`Escape`** closing any active window.

---

## Installation Instructions

### 1. Download the Addon
You can download **Raiders Tracker** in one of two ways from this GitHub repository:

- **Option A — From the Releases Section (Recommended):**
  1. Look for the **Releases** section on the right-hand sidebar of this GitHub page.
  2. Click on the latest release (`v1.3.0`) and download the attached `.zip` file.
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
  - **`Escape`** — Closes any open Raiders Tracker panel (including Reports Hub, Death Log, and text export/import windows).

---

## Bug Reports & Feature Ideas

**Raiders Tracker** is actively maintained for the 3.3.5a raiding community, and feedback from Raid Leaders, officers, and raiders is always welcome!

- **Found a Bug?** If an encounter transition, consumable, proc, fail check, or death log entry doesn't record as expected—or if you run into a Lua error—please open an issue in the **[Issues](../../issues)** tab at the top of this page. Let us know what raid/difficulty you were in and what happened.

- **Have an Idea to Improve the Addon?** If there is a specific spell, trinket proc, consumable, or raid-leading feature you'd like to see added in a future update, submit a feature request in the **[Issues](../../issues)** tab!
