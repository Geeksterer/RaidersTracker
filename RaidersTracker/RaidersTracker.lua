-- Raiders Tracker Addon (RT)
-- Created for World of Warcraft Legacy 3.3.5a
-- Refactored & Enhanced by Copper

local ADDON_NAME = "Raiders Tracker"
local AUTHOR = "Copper"

local function GetAddonVersion()
    return GetAddOnMetadata("RaidersTracker", "Version") or "1.1.3"
end

local function GetFooterText()
    return ADDON_NAME .. " v" .. GetAddonVersion() .. " by " .. AUTHOR
end

-------------------------------------------------------------------------------
-- Database & Default Configuration
-------------------------------------------------------------------------------
local defaultDB = {
    enabled = true,
    minimapPos = 45,
    lastCharacter = nil,
    savedSessions = {},
    liveSession = { name = "Live Current Session", segments = {}, players = {} }
}

RaidersTrackerDB = RaidersTrackerDB or {}

local currentSession = nil
local currentSegment = nil
local RefreshMainView = function() end
local RequestMainViewRefresh = function() end

local function DeepCopyTable(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[DeepCopyTable(k)] = DeepCopyTable(v)
    end
    return copy
end

local function InitializeDB()
    for k, v in pairs(defaultDB) do
        if RaidersTrackerDB[k] == nil then
            if k == "liveSession" then
                RaidersTrackerDB.liveSession = { name = "Live Current Session", segments = {}, players = {} }
            else
                RaidersTrackerDB[k] = DeepCopyTable(v)
            end
        end
    end
    currentSession = RaidersTrackerDB.liveSession
    currentSession.players = currentSession.players or {}
    if #currentSession.segments > 0 then
        for _, seg in ipairs(currentSession.segments) do
            seg.deaths = seg.deaths or {}
            seg.players = seg.players or {}
            seg.potionsAndBuffs = seg.potionsAndBuffs or {}
            seg.raidUtility = seg.raidUtility or {}
        end
        currentSegment = currentSession.segments[1]
    end
end

local function AnnounceLocalChat(msg)
    if msg and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00[Raiders Tracker]|r " .. msg)
    end
end

-------------------------------------------------------------------------------
-- Zone Retrieval, Raid Size/Difficulty & Roster Utilities
-------------------------------------------------------------------------------
local function GetCurrentZoneSafe()
    local realZone = GetRealZoneText()
    if realZone and realZone ~= "" then return realZone end

    local zone = GetZoneText()
    if zone and zone ~= "" then return zone end

    local miniZone = GetMinimapZoneText()
    if miniZone and miniZone ~= "" then return miniZone end

    return "Unknown"
end

-- Accurate 3.3.5a Raid & Instance Size/Difficulty Detector
local function GetRaidDifficultySuffix()
    local inInstance, instanceType = IsInInstance()
    local _, instType, difficultyIndex, difficultyName, maxPlayers, dynamicDifficulty, isDynamic = GetInstanceInfo()
    local instDiff = GetInstanceDifficulty and GetInstanceDifficulty() or nil
    local raidDiff = GetRaidDifficulty and GetRaidDifficulty() or nil
    local dungDiff = GetDungeonDifficulty and GetDungeonDifficulty() or nil
    local diffText = difficultyName or ""

    -- 1. Inside a Raid Instance
    if inInstance and (instType == "raid" or instanceType == "raid") then
        local is25 = (maxPlayers == 25)
            or (difficultyIndex == 2) or (difficultyIndex == 4)
            or (instDiff == 2) or (instDiff == 4)
            or (raidDiff == 2) or (raidDiff == 4)
            or (diffText:find("25") ~= nil)

        local isHeroic = (dynamicDifficulty == 1)
            or (difficultyIndex == 3) or (difficultyIndex == 4)
            or (instDiff == 3) or (instDiff == 4)
            or (raidDiff == 3) or (raidDiff == 4)
            or (diffText:find("Heroic") ~= nil)

        if is25 then
            return isHeroic and "25HC" or "25N"
        else
            return isHeroic and "10HC" or "10N"
        end
    elseif inInstance and (instType == "party" or instanceType == "party") then
        local isHeroicParty = (difficultyIndex == 2) or (instDiff == 2) or (dungDiff == 2) or (diffText:find("Heroic") ~= nil)
        return isHeroicParty and "5HC" or "5N"
    end

    -- 2. Outside an Instance (reads active Raid/Dungeon setting)
    local numRaid = GetNumRaidMembers()
    local numParty = GetNumPartyMembers()

    if numRaid == 0 and numParty > 0 then
        return (dungDiff == 2) and "5HC" or "5N"
    end

    if raidDiff == 4 then
        return "25HC"
    elseif raidDiff == 3 then
        return "10HC"
    elseif raidDiff == 2 then
        return "25N"
    else
        return "10N"
    end
end

local groupMembers = {}
local groupClasses = {}
local groupGUIDs = {}

local function IsPlayerGUID(guid)
    if not guid or type(guid) ~= "string" then return true end
    local prefix3 = guid:sub(1, 3):upper()
    if prefix3 == "0XF" then
        return false
    end
    return true
end

local function UpdateGroupCache()
    table.wipe(groupMembers)
    table.wipe(groupGUIDs)

    local pName = UnitName("player")
    if pName and pName ~= UNKNOWN then
        groupMembers[pName] = true
        local pGUID = UnitGUID("player")
        if pGUID then groupGUIDs[pGUID] = pName end
        local _, engClass = UnitClass("player")
        if engClass then groupClasses[pName] = engClass end
    end

    local numRaid = GetNumRaidMembers()
    if numRaid > 0 then
        for i = 1, numRaid do
            local unit = "raid" .. i
            local name = UnitName(unit)
            if name and name ~= UNKNOWN then
                groupMembers[name] = true
                local uGUID = UnitGUID(unit)
                if uGUID then groupGUIDs[uGUID] = name end
                local _, engClass = UnitClass(unit)
                if engClass then groupClasses[name] = engClass end
            end
        end
    else
        local numParty = GetNumPartyMembers()
        if numParty > 0 then
            for i = 1, numParty do
                local unit = "party" .. i
                local name = UnitName(unit)
                if name and name ~= UNKNOWN then
                    groupMembers[name] = true
                    local uGUID = UnitGUID(unit)
                    if uGUID then groupGUIDs[uGUID] = name end
                    local _, engClass = UnitClass(unit)
                    if engClass then groupClasses[name] = engClass end
                end
            end
        end
    end
end

local function IsGroupMember(name, guid)
    if not name then return false end
    if not IsPlayerGUID(guid) then return false end

    if groupMembers[name] then
        return true
    end
    if guid and groupGUIDs[guid] then
        groupMembers[name] = true
        return true
    end
    if UnitInRaid(name) or UnitInParty(name) or name == UnitName("player") then
        UpdateGroupCache()
        return groupMembers[name] == true
    end
    return false
end

local function GetSafePlayerClass(unitName, guid)
    if unitName and groupClasses[unitName] then
        return groupClasses[unitName]
    end

    if guid and type(guid) == "string" and IsPlayerGUID(guid) then
        local ok, _, engClass = pcall(GetPlayerInfoByGUID, guid)
        if ok and engClass and engClass ~= "" then
            if unitName then groupClasses[unitName] = engClass end
            return engClass
        end
    end

    if unitName then
        local _, engClass = UnitClass(unitName)
        if engClass and engClass ~= "" then
            groupClasses[unitName] = engClass
            return engClass
        end
    end

    return "WARRIOR"
end

local function IsRaidInCombat()
    local numRaid = GetNumRaidMembers()
    if numRaid > 0 then
        for i = 1, numRaid do
            local unit = "raid" .. i
            if UnitExists(unit) and not UnitIsDeadOrGhost(unit) and UnitAffectingCombat(unit) then
                return true
            end
        end
    else
        if not UnitIsDeadOrGhost("player") and UnitAffectingCombat("player") then
            return true
        end
        local numParty = GetNumPartyMembers()
        for i = 1, numParty do
            local unit = "party" .. i
            if UnitExists(unit) and not UnitIsDeadOrGhost(unit) and UnitAffectingCombat(unit) then
                return true
            end
        end
    end
    return false
end

-------------------------------------------------------------------------------
-- 3.3.5a Hex GUID Parser
-------------------------------------------------------------------------------
local function GetNPCIDFromGUID(guid)
    if not guid or type(guid) ~= "string" or #guid < 12 then return nil end
    local prefix = guid:sub(1, 5):upper()
    if prefix == "0XF13" or prefix == "0XF15" or prefix == "0XF53" or prefix == "0XF55" then
        return tonumber(guid:sub(7, 12), 16)
    end
    return nil
end

-------------------------------------------------------------------------------
-- Class Colors & Helpers
-------------------------------------------------------------------------------
local CLASS_COLORS = {
    ["WARRIOR"]     = "C79C6E",
    ["PALADIN"]     = "F58CBA",
    ["HUNTER"]      = "ABD473",
    ["ROGUE"]       = "FFF569",
    ["PRIEST"]      = "FFFFFF",
    ["DEATHKNIGHT"] = "C41F3B",
    ["SHAMAN"]      = "0070DE",
    ["MAGE"]        = "69CCF0",
    ["WARLOCK"]     = "9482C9",
    ["DRUID"]       = "FF7D0A",
}

local function ColorizeText(text, hexColor)
    return string.format("|cff%s%s|r", hexColor or "FFFFFF", text or "")
end

local function GetPlayerClassColor(className)
    if not className then return "FFFFFF" end
    return CLASS_COLORS[string.upper(className)] or "FFFFFF"
end

-------------------------------------------------------------------------------
-- Comprehensive WotLK Raid Boss Database & Speech Recognition Tables
-------------------------------------------------------------------------------
local WOTLK_BOSS_DB = {
    -- Vault of Archavon (VoA)
    [31125] = { name = "Archavon the Stone Watcher" },
    [33993] = { name = "Emalon the Storm Watcher" },
    [35013] = { name = "Koralon the Flame Watcher" },
    [38433] = { name = "Toravon the Ice Watcher" },

    -- Naxxramas
    [15956] = { name = "Anub'Rekhan" },
    [15953] = { name = "Grand Widow Faerlina" },
    [15952] = { name = "Maexxna" },
    [15954] = { name = "Noth the Plaguebringer" },
    [15936] = { name = "Heigan the Unclean" },
    [16011] = { name = "Loatheb" },
    [16061] = { name = "Instructor Razuvious" },
    [16060] = { name = "Gothik the Harvester" },
    [16064] = { name = "Four Horsemen", isGroup = true },
    [16065] = { name = "Four Horsemen", isGroup = true },
    [16063] = { name = "Four Horsemen", isGroup = true },
    [30549] = { name = "Four Horsemen", isGroup = true },
    [16028] = { name = "Patchwerk" },
    [15931] = { name = "Grobbulus" },
    [15932] = { name = "Gluth" },
    [15928] = { name = "Thaddius" },
    [15930] = { name = "Thaddius", isSubBoss = true },
    [15929] = { name = "Thaddius", isSubBoss = true },
    [15989] = { name = "Sapphiron" },
    [15990] = { name = "Kel'Thuzad" },

    -- Eye of Eternity & Obsidian Sanctuary & Onyxia
    [28859] = { name = "Malygos", scriptedFinish = true },
    [28860] = { name = "Sartharion" },
    [30452] = { name = "Sartharion", isMini = true },
    [30451] = { name = "Sartharion", isMini = true },
    [30449] = { name = "Sartharion", isMini = true },
    [10184] = { name = "Onyxia" },

    -- Ulduar
    [33113] = { name = "Flame Leviathan" },
    [33118] = { name = "Ignis the Furnace Master" },
    [33186] = { name = "Razorscale" },
    [33293] = { name = "XT-002 Deconstructor" },
    [32867] = { name = "Assembly of Iron", isGroup = true },
    [32927] = { name = "Assembly of Iron", isGroup = true },
    [32857] = { name = "Assembly of Iron", isGroup = true },
    [32930] = { name = "Kologarn" },
    [33515] = { name = "Auriaya" },
    [32845] = { name = "Hodir", scriptedFinish = true },
    [32865] = { name = "Thorim", scriptedFinish = true },
    [32906] = { name = "Freya", scriptedFinish = true },
    [33432] = { name = "Mimiron", scriptedFinish = true },
    [33651] = { name = "Mimiron", isPhase = true, scriptedFinish = true },
    [34105] = { name = "Mimiron", isPhase = true, scriptedFinish = true },
    [33670] = { name = "Mimiron", isPhase = true, scriptedFinish = true },
    [33271] = { name = "General Vezax" },
    [33288] = { name = "Yogg-Saron" },
    [33134] = { name = "Yogg-Saron", isPhase = true },
    [32871] = { name = "Algalon the Observer", scriptedFinish = true },

    -- Trial of the Crusader / ToGC
    [34796] = { name = "Northrend Beasts", isSubBoss = true },
    [34799] = { name = "Northrend Beasts", isSubBoss = true },
    [35144] = { name = "Northrend Beasts", isSubBoss = true },
    [34797] = { name = "Northrend Beasts" },
    [34780] = { name = "Lord Jaraxxus" },
    [34497] = { name = "Twin Val'kyr", isGroup = true },
    [34496] = { name = "Twin Val'kyr", isGroup = true },
    [34564] = { name = "Anub'arak" },

    -- Icecrown Citadel (ICC)
    [36612] = { name = "Lord Marrowgar" },
    [36855] = { name = "Lady Deathwhisper" },
    [37215] = { name = "Icecrown Gunship Battle", scriptedFinish = true },
    [37540] = { name = "Icecrown Gunship Battle", scriptedFinish = true },
    [37200] = { name = "Icecrown Gunship Battle", isGroup = true, scriptedFinish = true },
    [37184] = { name = "Icecrown Gunship Battle", isGroup = true, scriptedFinish = true },
    [37813] = { name = "Deathbringer Saurfang" },
    [36626] = { name = "Festergut" },
    [36627] = { name = "Rotface" },
    [36678] = { name = "Professor Putricide" },
    [37562] = { name = "Professor Putricide", isAdd = true },
    [37697] = { name = "Professor Putricide", isAdd = true },
    [37970] = { name = "Blood Prince Council", isGroup = true },
    [37972] = { name = "Blood Prince Council", isGroup = true },
    [37973] = { name = "Blood Prince Council", isGroup = true },
    [37955] = { name = "Blood-Queen Lana'thel" },
    [36789] = { name = "Valithria Dreamwalker", scriptedFinish = true },
    [36853] = { name = "Sindragosa" },
    [36597] = { name = "The Lich King", scriptedFinish = true },
    [36609] = { name = "The Lich King", isAdd = true },
    [36701] = { name = "The Lich King", isAdd = true },

    -- Ruby Sanctum (RS) - Halion and Independent Mini-Boss Encounters
    [39751] = { name = "Baltharus the Warborn" },
    [39899] = { name = "Baltharus the Warborn", isAdd = true }, -- Baltharus Clone
    [39747] = { name = "Saviana Ragefire" },
    [39746] = { name = "General Zarithrian" },
    [39863] = { name = "Halion" },
    [40142] = { name = "Halion", isPhase = true }
}

local FACTION_CHAMPION_NPC_IDS = {
    34441, 34444, 34445, 34447, 34448, 34449, 34450,
    34451, 34453, 34454, 34455, 34456, 34458, 34459,
    34460, 34461, 34463, 34465, 34466, 34467, 34468,
    34469, 34470, 34471, 34472, 34473, 34474, 34475
}
for _, fcID in ipairs(FACTION_CHAMPION_NPC_IDS) do
    WOTLK_BOSS_DB[fcID] = { name = "Faction Champions", isFactionChamp = true }
end

local BOSS_NAME_TO_INFO = {}
for npcID, data in pairs(WOTLK_BOSS_DB) do
    if not data.isAdd and not data.isMini then
        if not BOSS_NAME_TO_INFO[data.name] then
            BOSS_NAME_TO_INFO[data.name] = {
                primaryID = npcID,
                isGroup = data.isGroup or false,
                isFactionChamp = data.isFactionChamp or false,
                scriptedFinish = data.scriptedFinish or false,
                npcIDs = {}
            }
        end
        if data.isFactionChamp then
            BOSS_NAME_TO_INFO[data.name].isFactionChamp = true
        end
        if not data.isPreboss and not data.isSubBoss and not data.isPhase then
            BOSS_NAME_TO_INFO[data.name].npcIDs[npcID] = true
            BOSS_NAME_TO_INFO[data.name].primaryID = npcID
        end
    end
end

local BOSS_ENGAGE_SPEECH = {
    -- ICC
    ["The Scourge will wash over this world"] = "Lord Marrowgar",
    ["What is this disturbance"] = "Lady Deathwhisper",
    ["Reavers, Sergeants, attack"] = "Icecrown Gunship Battle",
    ["Marines, Sergeants, attack"] = "Icecrown Gunship Battle",
    ["By the might of the Lich King"] = "Deathbringer Saurfang",
    ["Fun time!"] = "Festergut",
    ["Waaaaah!"] = "Rotface",
    ["The slime is flowing again"] = "Professor Putricide",
    ["Naxxramas was but a setback"] = "Blood Prince Council",
    ["unwise... decision"] = "Blood-Queen Lana'thel",
    ["You should have chosen your allies more carefully"] = "Blood-Queen Lana'thel",
    ["Help me! I... I cannot hold them back"] = "Valithria Dreamwalker",
    ["Heroes, lend me your aid"] = "Valithria Dreamwalker",
    ["You are fools to have come to this place"] = "Sindragosa",
    ["I'll keep you alive to witness the end, Fordring"] = "The Lich King",

    -- VoA
    ["Archavon the Stone Watcher shatters the rock"] = "Archavon the Stone Watcher",
    ["Emalon the Storm Watcher prepares to strike"] = "Emalon the Storm Watcher",
    ["Koralon the Flame Watcher ignites in a rage"] = "Koralon the Flame Watcher",
    ["Toravon the Ice Watcher freezes the air"] = "Toravon the Ice Watcher",

    -- Naxx
    ["Ah, welcome to my lair!"] = "Anub'Rekhan",
    ["Just a little taste"] = "Anub'Rekhan",
    ["Kneel before me, worm!"] = "Grand Widow Faerlina",
    ["Slay them in the master's name"] = "Grand Widow Faerlina",
    ["Glory to the Lich King!"] = "Noth the Plaguebringer",
    ["Die, trespasser!"] = "Noth the Plaguebringer",
    ["You are mine now!"] = "Heigan the Unclean",
    ["I see you..."] = "Heigan the Unclean",
    ["Show me what you've got!"] = "Instructor Razuvious",
    ["Foolishly you have sought your own demise!"] = "Gothik the Harvester",
    ["Come out and fight, ye coward!"] = "Four Horsemen",
    ["Patchwerk want to play!"] = "Patchwerk",
    ["Kel'Thuzad make Patchwerk his avatar of war"] = "Patchwerk",
    ["Stalagg crush you!"] = "Thaddius",
    ["Feugen make master happy!"] = "Thaddius",
    ["Eat... your... bones..."] = "Thaddius",
    ["Pray for mercy! The end has come!"] = "Kel'Thuzad",

    -- OS / EoE / Onyxia
    ["It is my duty to guard these eggs"] = "Sartharion",
    ["My patience has reached its limit"] = "Malygos",
    ["I had hoped to end your lives quickly"] = "Malygos",
    ["How fortuitous. Usually, I must leave my lair"] = "Onyxia",

    -- Ulduar
    ["Hostile entities detected"] = "Flame Leviathan",
    ["Insolent whelps! Your flesh will feed the forge!"] = "Ignis the Furnace Master",
    ["Give us a moment to prepare to build the turrets"] = "Razorscale",
    ["New toys? For me?"] = "XT-002 Deconstructor",
    ["So, small ones... you seek to challenge the Iron Council"] = "Assembly of Iron",
    ["You will not defeat the Assembly of Iron"] = "Assembly of Iron",
    ["NONE SHALL PASS!"] = "Kologarn",
    ["Some things are better left secret!"] = "Auriaya",
    ["Interlopers! You dare interfere with my sight?"] = "Thorim",
    ["We haven't much time, friends!"] = "Mimiron",
    ["You will pay for this intrusion!"] = "Hodir",
    ["Conservator, they have"] = "Freya",
    ["Elders, grant me your strength"] = "Freya",
    ["Your destruction will show the helplessness"] = "General Vezax",
    ["The time to strike at the head of the beast"] = "Yogg-Saron",
    ["I am the lucid dream"] = "Yogg-Saron",
    ["See your world through my eyes"] = "Algalon the Observer",

    -- ToC
    ["Hailing from the deepest, darkest caverns"] = "Northrend Beasts",
    ["You face Jaraxxus, Eredar Lord"] = "Lord Jaraxxus",
    ["GLORY TO THE ALLIANCE"] = "Faction Champions",
    ["Glory to the Alliance"] = "Faction Champions",
    ["Show them no mercy, Horde champions"] = "Faction Champions",
    ["LOK'TAR OGAR"] = "Faction Champions",
    ["In the name of our dark master"] = "Twin Val'kyr",
    ["This place will serve as your tomb!"] = "Anub'arak",

    -- Ruby Sanctum (Halion & Mini-Bosses)
    ["Ah, the entertainment has arrived"] = "Baltharus the Warborn",
    ["You will sssuffer for this intrusion"] = "Saviana Ragefire",
    ["Alexstrasza has chosen capable allies"] = "General Zarithrian",
    ["Your world totters on the brink of destruction"] = "Halion"
}

local BOSS_DEFEAT_SPEECH = {
    -- ICC
    ["I see... only darkness"] = "Lord Marrowgar",
    ["All is part of the Master's plan"] = "Lady Deathwhisper",
    ["Don't say I didn't warn ya, scoundrels"] = "Icecrown Gunship Battle",
    ["The Alliance falters. Onward to the Lich King"] = "Icecrown Gunship Battle",
    ["I... am... released"] = "Deathbringer Saurfang",
    ["Da-da... I..."] = "Festergut",
    ["Bad news, daddy"] = "Rotface",
    ["Bad news, everyone... I don't think I'm going to make it"] = "Professor Putricide",
    ["My queen, they... come"] = "Blood Prince Council",
    ["But... we had... such a good arrangement"] = "Blood-Queen Lana'thel",
    ["I am renewed! Ysera grant me"] = "Valithria Dreamwalker",
    ["Free... at last"] = "Sindragosa",
    ["No questions remain unanswered"] = "The Lich King",
    ["Father! Is it... over?"] = "The Lich King",

    -- VoA
    ["Archavon the Stone Watcher falls to the ground"] = "Archavon the Stone Watcher",
    ["Emalon the Storm Watcher collapses"] = "Emalon the Storm Watcher",
    ["Koralon the Flame Watcher burns out"] = "Koralon the Flame Watcher",
    ["Toravon the Ice Watcher shatters"] = "Toravon the Ice Watcher",

    -- Naxx
    ["Ahhh... it is done"] = "Anub'Rekhan",
    ["The master... will avenge me!"] = "Grand Widow Faerlina",
    ["I will serve the master... in death"] = "Noth the Plaguebringer",
    ["An honorable... death"] = "Instructor Razuvious",
    ["I... am... undone"] = "Gothik the Harvester",
    ["What happened to... Patchwerk?"] = "Patchwerk",
    ["Thank... you..."] = "Thaddius",
    ["Do not rejoice! Your victory is a hollow one"] = "Kel'Thuzad",

    -- OS / EoE / Onyxia
    ["Such is the price... of failure"] = "Sartharion",
    ["ENOUGH! If you intend to reclaim Azeroth's magic"] = "Malygos",

    -- Ulduar
    ["Total system failure. Defense protocols breached"] = "Flame Leviathan",
    ["I... have... failed"] = "Ignis the Furnace Master",
    ["You are bad... Toys... Very... Baaaaad"] = "XT-002 Deconstructor",
    ["You have defeated the Iron Council"] = "Assembly of Iron",
    ["Master, they come..."] = "Kologarn",
    ["His hold on me dissipates. I can see clearly once more"] = "Freya",
    ["Stay your arms! I yield!"] = "Thorim",
    ["It would appear that I have made a slight miscalculation"] = "Mimiron",
    ["I... I am released from his grasp... at last"] = "Hodir",
    ["Oh, what horrors await"] = "General Vezax",
    ["Your fate is sealed. The end of days is finally upon you"] = "Yogg-Saron",
    ["I have seen worlds bathed in the Makers' flames"] = "Algalon the Observer",

    -- ToC
    ["Another will take my place. Your world is doomed"] = "Lord Jaraxxus",
    ["A shallow and tragic victory"] = "Faction Champions",
    ["A superficial victory"] = "Faction Champions",
    ["weaker as a whole from the losses"] = "Faction Champions",
    ["The Scourge cannot be stopped"] = "Twin Val'kyr",
    ["I have failed you, master"] = "Anub'arak",

    -- Ruby Sanctum (Halion & Mini-Bosses)
    ["I... didn't see that... coming"] = "Baltharus the Warborn",
    ["HALION! I"] = "General Zarithrian",
    ["Relish this victory, mortals, for it will be your last"] = "Halion"
}

local WOTLK_BOSS_INITIATORS = {
    [69076] = "Lord Marrowgar", [69057] = "Lord Marrowgar",
    [70867] = "Lady Deathwhisper", [69680] = "Icecrown Gunship Battle",
    [72293] = "Deathbringer Saurfang", [72219] = "Festergut", [69674] = "Rotface",
    [70351] = "Professor Putricide", [71807] = "Blood Prince Council", [70877] = "Blood-Queen Lana'thel",
    [71741] = "Valithria Dreamwalker", [70123] = "Sindragosa", [72350] = "The Lich King",
    [74505] = "Baltharus the Warborn", [74509] = "Baltharus the Warborn",
    [74403] = "Saviana Ragefire", [74452] = "Saviana Ragefire", [78722] = "Saviana Ragefire",
    [74367] = "General Zarithrian", [74384] = "General Zarithrian",
    [74562] = "Halion",
    [66331] = "Northrend Beasts", [66532] = "Lord Jaraxxus",
    [65875] = "Twin Val'kyr", [65876] = "Twin Val'kyr", [66013] = "Anub'arak",
    [62374] = "Flame Leviathan", [62680] = "Ignis the Furnace Master", [64021] = "Razorscale",
    [62776] = "XT-002 Deconstructor", [61888] = "Assembly of Iron", [63356] = "Kologarn",
    [64386] = "Auriaya", [61968] = "Hodir", [62130] = "Thorim", [62589] = "Freya",
    [63631] = "Mimiron", [62660] = "General Vezax", [64163] = "Yogg-Saron", [64443] = "Algalon the Observer"
}

-------------------------------------------------------------------------------
-- Potions, Consumables, Raid Buffs, Rings, Enchants & Trinkets Database
-------------------------------------------------------------------------------
local POTIONS_AND_BUFFS = {
    -- Combat Potions & Consumables
    [53908] = "Potion of Speed",
    [53909] = "Potion of Wild Magic",
    [28494] = "Insane Strength Potion",
    [28507] = "Haste Potion",
    [28508] = "Destruction Potion",
    [53762] = "Indestructible Potion",
    [53753] = "Indestructible Potion",
    [54117] = "Indestructible Potion",
    [53761] = "Powerful Rejuvenation Potion",
    [28714] = "Flame Cap",
    [9512]  = "Thistle Tea", [9513] = "Thistle Tea", [18160] = "Thistle Tea",
    [43186] = "Runic Mana Potion", [53942] = "Runic Mana Injector",
    [43185] = "Runic Healing Potion", [53934] = "Runic Healing Injector",
    [47878] = "Fel Healthstone", [47871] = "Fel Healthstone", [47875] = "Fel Healthstone", [27230] = "Master Healthstone",
    [42985] = "Mana Sapphire", [33312] = "Mana Emerald", [42984] = "Mana Sapphire",

    -- Flasks, Elixirs & Well Fed
    [53755] = "Flask of the Frost Wyrm",
    [53760] = "Flask of Endless Rage",
    [53758] = "Flask of Stoneblood",
    [54212] = "Flask of Pure Mojo",
    [53752] = "Lesser Flask of Toughness",
    [67016] = "Flask of the North (SP)",
    [67017] = "Flask of the North (AP)",
    [67018] = "Flask of the North (STR)",
    [17627] = "Flask of Distilled Wisdom",
    [53747] = "Elixir of Spirit",
    [53748] = "Elixir of Mighty Strength",
    [53746] = "Wrath Elixir",
    [53749] = "Guru's Elixir",
    [53763] = "Elixir of Protection",
    [53764] = "Elixir of Mighty Mageblood",
    [60347] = "Elixir of Mighty Thoughts",
    [60346] = "Elixir of Lightning Speed",
    [60345] = "Elixir of Armor Piercing",
    [60344] = "Elixir of Expertise",
    [60341] = "Elixir of Deadly Strikes",
    [60340] = "Elixir of Accuracy",
    [28497] = "Elixir of Mighty Agility",
    [57399] = "Fish Feast (Well Fed)",
    [57329] = "Well Fed (Crit/Sta)",
    [57325] = "Well Fed (AP/Sta)",
    [57327] = "Well Fed (SP/Sta)",
    [57332] = "Well Fed (Haste/Sta)",
    [57334] = "Well Fed (MP5/Sta)",
    [57356] = "Well Fed (Exp/Sta)",
    [57358] = "Well Fed (ArP/Sta)",
    [57360] = "Well Fed (Hit/Sta)",
    [57367] = "Well Fed (Agi/Sta)",
    [57371] = "Well Fed (Str/Sta)",
    [57365] = "Well Fed (Spi/Sta)",

    -- Engineering, Tailoring & Weapon Enchant Procs
    [54758] = "Hyperspeed Accelerators",
    [55002] = "Flexweave Underlay",
    [55637] = "Lightweave Embroidery",
    [55775] = "Swordguard Embroidery",
    [55777] = "Darkglow Embroidery",
    [59626] = "Black Magic Proc",
    [59620] = "Berserking Proc",
    [59625] = "Blade Ward Proc",
    [64441] = "Blood Draining Proc",
    [28093] = "Mongoose Proc",
    [42976] = "Executioner Proc",

    -- Ashen Band ICC Rings
    [72416] = "Ashen Caster Ring Proc",
    [72418] = "Ashen Healer Ring Proc",
    [72412] = "Ashen Melee Ring Proc",
    [72414] = "Ashen Tank Ring Proc",

    -- Major WotLK Trinket Procs
    [71605] = "Phylactery Proc (N)",
    [71636] = "Phylactery Proc (HC)",
    [71601] = "DFO Proc (N)",
    [71644] = "DFO Proc (HC)",

    -- Deathbringer's Will Normal (Item 50362) - All 6 Distinct Buffs
    [71484] = "DBW: Strength of the Taunka (+600 Str)",
    [71485] = "DBW: Agility of the Vrykul (+600 Agi)",
    [71486] = "DBW: Power of the Taunka (+1200 AP)",
    [71487] = "DBW: Precision of the Iron Dwarves (+600 ArP)",
    [71491] = "DBW: Aim of the Iron Dwarves (+600 Crit)",
    [71492] = "DBW: Speed of the Vrykul (+600 Haste)",

    -- Deathbringer's Will Heroic (Item 50363) - All 6 Distinct Buffs
    [71561] = "DBW HC: Strength of the Taunka (+700 Str)",
    [71556] = "DBW HC: Agility of the Vrykul (+700 Agi)",
    [71558] = "DBW HC: Power of the Taunka (+1400 AP)",
    [71557] = "DBW HC: Precision of the Iron Dwarves (+700 ArP)",
    [71559] = "DBW HC: Aim of the Iron Dwarves (+700 Crit)",
    [71560] = "DBW HC: Speed of the Vrykul (+700 Haste)",

    -- Other Raid Trinkets
    [71635] = "CTS Organ/Coin Proc (N)",
    [71646] = "CTS Organ/Coin Proc (HC)",
    [75458] = "STS Proc (N)",
    [75456] = "STS Proc (HC)",
    [75466] = "Charred Twilight Scale (N)",
    [75473] = "Charred Twilight Scale (HC)",
    [75490] = "Glowing Twilight Scale (N)",
    [75495] = "Glowing Twilight Scale (HC)",
    [75477] = "Petrified Twilight Scale (N)",
    [75481] = "Petrified Twilight Scale (HC)",
    [71401] = "Whispering Fanged Skull (N)",
    [71541] = "Whispering Fanged Skull (HC)",
    [71633] = "Tiny Abomination Proc",
    [71403] = "Needle-Encrusted Scorpion",
    [67703] = "Death's Choice/Verdict Str (N)",
    [67772] = "Death's Choice/Verdict Str (HC)",
    [67708] = "Death's Choice/Verdict Agi (N)",
    [67773] = "Death's Choice/Verdict Agi (HC)",
    [67695] = "Talisman of Resurgence",
    [67753] = "Satrina's / Juggernaut Vitality (N)",
    [67751] = "Satrina's / Juggernaut Vitality (HC)",
    [64772] = "Comet's Trail Proc",
    [60229] = "Greatness Proc (Str)",
    [60233] = "Greatness Proc (Agi)",
    [60234] = "Greatness Proc (Int)",
    [60235] = "Greatness Proc (Spi)",
    [65008] = "Mjolnir Runestone Proc",
    [65019] = "Grim Toll Proc",
    [64713] = "Flare of the Heavens Proc",
    [64741] = "Pandora's Plea Proc",
    [65006] = "Eye of the Broodmother",
    [71570] = "Muradin's Spyglass (N)",
    [71572] = "Muradin's Spyglass (HC)",
    [71584] = "Purified Lunar Dust",
    [71610] = "Althor's Abacus Proc",
    [71880] = "Trauma Proc",

    -- Major Combat Raid Buffs & External Buffs Received
    [2825]  = "Bloodlust",
    [32182] = "Heroism",
    [10060] = "Power Infusion",
    [49016] = "Hysteria",
    [57933] = "Tricks of the Trade (+15% Dmg)",
    [29166] = "Innervate",
    [54648] = "Focus Magic Proc",
    [33206] = "Pain Suppression",
    [47788] = "Guardian Spirit",
    [6940]  = "Hand of Sacrifice",
    [10278] = "Hand of Protection", [1022] = "Hand of Protection", [5599] = "Hand of Protection",
    [1038]  = "Hand of Salvation",
    [1044]  = "Hand of Freedom",
    [64205] = "Divine Sacrifice",
    [70940] = "Divine Guardian",
    [31821] = "Aura Mastery",
    [6346]  = "Fear Ward"
}

local ALLOW_REFRESH_BUFFS = {
    [53908] = true, [53909] = true, [28494] = true, [28507] = true, [28508] = true,
    [53762] = true, [53753] = true, [54117] = true, [28714] = true,
    [57933] = true, [10060] = true, [49016] = true, [29166] = true,
    [33206] = true, [47788] = true, [6940]  = true, [1038]  = true, [1044] = true,
    [71484] = true, [71485] = true, [71486] = true, [71487] = true, [71491] = true, [71492] = true,
    [71561] = true, [71556] = true, [71558] = true, [71557] = true, [71559] = true, [71560] = true,
}

-- Per-spell minimum cooldown (in seconds) so single procs never double-count on form/model updates
local CUSTOM_BUFF_ICD = {
    [59620] = 12.0, -- Berserking Proc
    [28093] = 10.0, -- Mongoose Proc
    [54648] = 10.0, -- Focus Magic Proc
    [71570] = 30.0, -- Muradin's Spyglass (N)
    [71572] = 30.0, -- Muradin's Spyglass (HC)
    [65006] = 30.0, -- Eye of the Broodmother
    -- Deathbringer's Will Normal & Heroic (30s buff duration, 105s ICD; 45s guard prevents form-shift double-counting)
    [71484] = 45.0, [71485] = 45.0, [71486] = 45.0, [71487] = 45.0, [71491] = 45.0, [71492] = 45.0,
    [71561] = 45.0, [71556] = 45.0, [71558] = 45.0, [71557] = 45.0, [71559] = 45.0, [71560] = 45.0,
}

local SNAPSHOT_PERSISTENT_BUFFS = {
    [53755] = true, [53760] = true, [53758] = true, [54212] = true, [53752] = true,
    [67016] = true, [67017] = true, [67018] = true, [17627] = true,
    [53747] = true, [53748] = true, [53746] = true, [53749] = true, [53763] = true,
    [53764] = true, [60347] = true, [60346] = true, [60345] = true, [60344] = true,
    [60341] = true, [60340] = true, [28497] = true,
    [57399] = true, [57329] = true, [57325] = true, [57327] = true, [57332] = true,
    [57334] = true, [57356] = true, [57358] = true, [57360] = true, [57367] = true,
    [57371] = true, [57365] = true,
}

-------------------------------------------------------------------------------
-- Raid Utility Database & Class Verification
-------------------------------------------------------------------------------
local RAID_UTILITY = {
    -- Engineering Utility
    [54861] = "Nitro Boosts", [55016] = "Nitro Boosts",
    [56488] = "Global Thermal Sapper Charge",
    [56350] = "Saronite Bomb",
    [67890] = "Frag Belt",

    -- Rogue
    [1966]  = "Feint", [6768] = "Feint", [8637] = "Feint", [11303] = "Feint",
    [25302] = "Feint", [27448] = "Feint", [48658] = "Feint", [48659] = "Feint",
    [57934] = "Tricks of the Trade",
    [2983]  = "Sprint", [8696] = "Sprint", [11305] = "Sprint",
    [1856]  = "Vanish", [1857] = "Vanish", [26889] = "Vanish",
    [31224] = "Cloak of Shadows",
    [51722] = "Dismantle",
    [1766]  = "Kick",
    [2094]  = "Blind",
    [5277]  = "Evasion", [26669] = "Evasion",

    -- Paladin
    [1022]  = "Hand of Protection", [5599] = "Hand of Protection", [10278] = "Hand of Protection",
    [633]   = "Lay on Hands", [2800] = "Lay on Hands", [10310] = "Lay on Hands", [27154] = "Lay on Hands", [48788] = "Lay on Hands",
    [1038]  = "Hand of Salvation",
    [1044]  = "Hand of Freedom",
    [6940]  = "Hand of Sacrifice",
    [64205] = "Divine Sacrifice",
    [70940] = "Divine Guardian",
    [31821] = "Aura Mastery",
    [53601] = "Sacred Shield",
    [642]   = "Divine Shield",
    [498]   = "Divine Protection",
    [10308] = "Hammer of Justice", [853] = "Hammer of Justice",
    [4987]  = "Cleanse",
    [31789] = "Righteous Defense",
    [62124] = "Hand of Reckoning",

    -- Druid
    [20484] = "Rebirth", [20739] = "Rebirth", [20742] = "Rebirth", [20747] = "Rebirth", [20748] = "Rebirth", [26994] = "Rebirth", [48477] = "Rebirth",
    [740]   = "Tranquility", [8918] = "Tranquility", [9862] = "Tranquility", [9863] = "Tranquility", [26983] = "Tranquility", [48446] = "Tranquility", [48447] = "Tranquility",
    [29166] = "Innervate",
    [22812] = "Barkskin",
    [61336] = "Survival Instincts",
    [22842] = "Frenzied Regeneration",
    [2782]  = "Remove Curse",
    [2893]  = "Abolish Poison",
    [33786] = "Cyclone",
    [6795]  = "Growl",
    [5209]  = "Challenging Roar",

    -- Warlock
    [20707] = "Soulstone Resurrection", [20762] = "Soulstone Resurrection", [20763] = "Soulstone Resurrection",
    [20764] = "Soulstone Resurrection", [20765] = "Soulstone Resurrection", [27239] = "Soulstone Resurrection", [47883] = "Soulstone Resurrection",
    [47241] = "Metamorphosis",
    [698]   = "Ritual of Summoning",
    [29893] = "Ritual of Souls", [58887] = "Ritual of Souls",
    [48020] = "Demonic Circle: Teleport",
    [29858] = "Soulshatter",
    [47847] = "Shadowfury",
    [19647] = "Spell Lock",

    -- Death Knight
    [42650] = "Army of the Dead",
    [51052] = "Anti-Magic Zone",
    [48707] = "Anti-Magic Shell",
    [48792] = "Icebound Fortitude",
    [55233] = "Vampiric Blood",
    [51271] = "Unbreakable Armor",
    [49222] = "Bone Shield",
    [61999] = "Raise Ally",
    [47568] = "Empower Rune Weapon",
    [49576] = "Death Grip",
    [47528] = "Mind Freeze",
    [47476] = "Strangulate",
    [56222] = "Dark Command",
    [49016] = "Hysteria",

    -- Priest
    [17]    = "Power Word: Shield", [48065] = "Power Word: Shield", [48066] = "Power Word: Shield",
    [33206] = "Pain Suppression",
    [47788] = "Guardian Spirit",
    [10060] = "Power Infusion",
    [64843] = "Divine Hymn",
    [64901] = "Hymn of Hope",
    [6346]  = "Fear Ward",
    [586]   = "Fade",
    [47585] = "Dispersion",
    [32375] = "Mass Dispel",
    [988]   = "Dispel Magic", [527] = "Dispel Magic",
    [528]   = "Cure Disease", [552] = "Abolish Disease",
    [10955] = "Shackle Undead",

    -- Shaman
    [32182] = "Heroism",
    [2825]  = "Bloodlust",
    [16190] = "Mana Tide Totem",
    [8143]  = "Tremor Totem",
    [8177]  = "Grounding Totem",
    [8170]  = "Cleansing Totem",
    [2062]  = "Earth Elemental Totem",
    [2894]  = "Fire Elemental Totem",
    [57994] = "Wind Shear",
    [8012]  = "Purge", [370] = "Purge",
    [51886] = "Cleanse Spirit",
    [526]   = "Cure Toxins",
    [51514] = "Hex",
    [30823] = "Shamanistic Rage",

    -- Hunter
    [34477] = "Misdirection",
    [5384]  = "Feign Death",
    [19263] = "Deterrence",
    [19801] = "Tranquilizing Shot",
    [20736] = "Distracting Shot",
    [13809] = "Frost Trap",
    [14311] = "Freezing Trap",
    [60192] = "Freezing Arrow",
    [53271] = "Master's Call",
    [53480] = "Roar of Sacrifice",
    [781]   = "Disengage",

    -- Warrior
    [64382] = "Shattering Throw",
    [871]   = "Shield Wall",
    [12975] = "Last Stand",
    [55694] = "Enraged Regeneration",
    [3411]  = "Intervene",
    [50720] = "Vigilance",
    [676]   = "Disarm",
    [6552]  = "Pummel",
    [72]    = "Shield Bash",
    [23920] = "Spell Reflection",
    [1161]  = "Challenging Shout",
    [1719]  = "Recklessness",

    -- Mage
    [66]    = "Invisibility",
    [45438] = "Ice Block",
    [12051] = "Evocation",
    [2139]  = "Counterspell",
    [30449] = "Spellsteal",
    [475]   = "Remove Curse",
    [54646] = "Focus Magic",
    [55342] = "Mirror Image",
    [130]   = "Slow Fall"
}

local UTILITY_CLASS_FILTER = {
    ["Death Grip"] = "DEATHKNIGHT",
    ["Icebound Fortitude"] = "DEATHKNIGHT",
    ["Vampiric Blood"] = "DEATHKNIGHT",
    ["Anti-Magic Shell"] = "DEATHKNIGHT",
    ["Anti-Magic Zone"] = "DEATHKNIGHT",
    ["Army of the Dead"] = "DEATHKNIGHT",
    ["Empower Rune Weapon"] = "DEATHKNIGHT",
    ["Mind Freeze"] = "DEATHKNIGHT",
    ["Strangulate"] = "DEATHKNIGHT",
    ["Dark Command"] = "DEATHKNIGHT",
    ["Hysteria"] = "DEATHKNIGHT",
    ["Raise Ally"] = "DEATHKNIGHT",
    ["Unbreakable Armor"] = "DEATHKNIGHT",
    ["Bone Shield"] = "DEATHKNIGHT",
    ["Tricks of the Trade"] = "ROGUE",
    ["Feint"] = "ROGUE",
    ["Cloak of Shadows"] = "ROGUE",
    ["Vanish"] = "ROGUE",
    ["Sprint"] = "ROGUE",
    ["Evasion"] = "ROGUE",
    ["Kick"] = "ROGUE",
    ["Dismantle"] = "ROGUE",
    ["Blind"] = "ROGUE",
    ["Misdirection"] = "HUNTER",
    ["Feign Death"] = "HUNTER",
    ["Deterrence"] = "HUNTER",
    ["Disengage"] = "HUNTER",
    ["Tranquilizing Shot"] = "HUNTER",
    ["Distracting Shot"] = "HUNTER",
    ["Freezing Arrow"] = "HUNTER",
    ["Freezing Trap"] = "HUNTER",
    ["Frost Trap"] = "HUNTER",
    ["Innervate"] = "DRUID",
    ["Rebirth"] = "DRUID",
    ["Barkskin"] = "DRUID",
    ["Tranquility"] = "DRUID",
    ["Heroism"] = "SHAMAN",
    ["Bloodlust"] = "SHAMAN",
    ["Wind Shear"] = "SHAMAN",
    ["Mana Tide Totem"] = "SHAMAN",
    ["Cleanse Spirit"] = "SHAMAN",
}

local EXTERNAL_TARGETED_UTILITY = {
    ["Power Word: Shield"] = true,
    ["Tricks of the Trade"] = true,
    ["Misdirection"] = true,
    ["Hand of Protection"] = true,
    ["Hand of Salvation"] = true,
    ["Hand of Freedom"] = true,
    ["Hand of Sacrifice"] = true,
    ["Lay on Hands"] = true,
    ["Sacred Shield"] = true,
    ["Rebirth"] = true,
    ["Innervate"] = true,
    ["Soulstone Resurrection"] = true,
    ["Raise Ally"] = true,
    ["Hysteria"] = true,
    ["Pain Suppression"] = true,
    ["Guardian Spirit"] = true,
    ["Power Infusion"] = true,
    ["Fear Ward"] = true,
    ["Focus Magic"] = true,
    ["Vigilance"] = true,
    ["Intervene"] = true,
    ["Master's Call"] = true,
    ["Roar of Sacrifice"] = true,
    ["Cleanse"] = true,
    ["Dispel Magic"] = true,
    ["Cure Disease"] = true,
    ["Abolish Disease"] = true,
    ["Abolish Poison"] = true,
    ["Remove Curse"] = true,
    ["Cleanse Spirit"] = true,
    ["Cure Toxins"] = true,
    ["Slow Fall"] = true,
}

local INSTANT_CONSUMABLES = {
    [43186] = true, [53942] = true,
    [43185] = true, [53934] = true,
    [47878] = true, [47871] = true, [47875] = true, [27230] = true,
    [42985] = true, [33312] = true, [42984] = true,
    [9512]  = true, [9513]  = true, [18160] = true,
}

-------------------------------------------------------------------------------
-- Encounter State Management, Segment Handlers & Session Helpers
-------------------------------------------------------------------------------
local recentProcs = {}
local recentPrePullEvents = {}
local lastDamageTaken = {}
local recentDeathLock = {}
local defeatedGroupNPCs = {}
local bossEndCooldowns = {}
local defeatedBossLocks = {}
local bossStartTime = 0
local bossAttemptCount = {}
local activeBossID = nil
local activeBossName = nil
local activeBossData = nil
local inCombatState = false
local hasEnteredBossCombat = false

local lastKnownZone = nil
local lastKnownDiff = nil
local UpdateFooterLive = function() end

local function GetNewSegment(name, isBoss, bossID, bossName, attempt)
    local zone = GetCurrentZoneSafe()
    local diff = GetRaidDifficultySuffix()
    lastKnownZone = zone
    lastKnownDiff = diff
    return {
        name = name,
        isBoss = isBoss or false,
        bossID = bossID,
        bossName = bossName,
        attempt = attempt or 1,
        zone = zone,
        difficulty = diff,
        potionsAndBuffs = {},
        raidUtility = {},
        deaths = {},
        players = {}
    }
end

local function IsSegmentEmpty(seg)
    if not seg then return true end
    for _, entries in pairs(seg.potionsAndBuffs or {}) do
        if next(entries) ~= nil then return false end
    end
    for _, entries in pairs(seg.raidUtility or {}) do
        if next(entries) ~= nil then return false end
    end
    for _, entries in pairs(seg.deaths or {}) do
        if #entries > 0 then return false end
    end
    return true
end

local function HasLiveSessionData()
    if not currentSession or not currentSession.segments then return false end
    for _, seg in ipairs(currentSession.segments) do
        if not IsSegmentEmpty(seg) then
            return true
        end
    end
    return false
end

local function EnsureTrashSegment()
    if inCombatState or not currentSession then return end

    local currentZone = GetCurrentZoneSafe()
    local currentDiff = GetRaidDifficultySuffix()
    local topSeg = currentSession.segments[1]

    if topSeg and not topSeg.isBoss and IsSegmentEmpty(topSeg) then
        if currentZone ~= "Unknown" and not UnitIsDeadOrGhost("player") then
            topSeg.zone = currentZone
        end
        topSeg.difficulty = currentDiff
        topSeg.deaths = topSeg.deaths or {}
        topSeg.players = topSeg.players or {}
        currentSegment = topSeg
        lastKnownZone = topSeg.zone
        lastKnownDiff = currentDiff
        return
    end

    local zoneChangedWhileAlive = (not UnitIsDeadOrGhost("player")) and (currentZone ~= "Unknown") and (topSeg and topSeg.zone ~= currentZone)
    if not topSeg or topSeg.isBoss or zoneChangedWhileAlive then
        local newTrashSeg = GetNewSegment("TRASH", false, nil, nil, nil)
        table.insert(currentSession.segments, 1, newTrashSeg)
        currentSegment = currentSession.segments[1]
    elseif topSeg and not topSeg.isBoss and topSeg.difficulty ~= currentDiff then
        topSeg.difficulty = currentDiff
        lastKnownDiff = currentDiff
    end
end

local function ResetLiveSessionState()
    RaidersTrackerDB.liveSession = { name = "Live Current Session", segments = {}, players = {} }
    currentSession = RaidersTrackerDB.liveSession
    currentSegment = nil
    inCombatState = false
    hasEnteredBossCombat = false
    activeBossID = nil
    activeBossName = nil
    activeBossData = nil
    table.wipe(bossAttemptCount)
    table.wipe(defeatedBossLocks)
    table.wipe(bossEndCooldowns)
    table.wipe(defeatedGroupNPCs)
    table.wipe(lastDamageTaken)
    table.wipe(recentDeathLock)
    table.wipe(recentProcs)
    table.wipe(recentPrePullEvents)
    EnsureTrashSegment()
end

local function SaveCurrentLiveSession(startFreshAfterSave)
    if not currentSession or #currentSession.segments == 0 then return end

    local cleanedSegments = {}
    for _, seg in ipairs(currentSession.segments) do
        if seg.isBoss or not IsSegmentEmpty(seg) then
            table.insert(cleanedSegments, DeepCopyTable(seg))
        end
    end
    if #cleanedSegments == 0 then
        cleanedSegments = DeepCopyTable(currentSession.segments)
    end

    local stamp = date("%Y-%m-%d %H:%M:%S")
    local savedCopy = {
        name = "Session " .. stamp,
        segments = cleanedSegments,
        players = DeepCopyTable(currentSession.players or {})
    }
    table.insert(RaidersTrackerDB.savedSessions, 1, savedCopy)
    AnnounceLocalChat("Current session saved as: " .. savedCopy.name)

    if startFreshAfterSave then
        ResetLiveSessionState()
        AnnounceLocalChat("Started a fresh Live Current Session.")
    end
end

local function HandleZoneOrDifficultyUpdate(announceDiffChange)
    if not currentSession then return end
    local newZone = GetCurrentZoneSafe()
    local newDiff = GetRaidDifficultySuffix()

    if UnitIsDeadOrGhost("player") and lastKnownZone and lastKnownZone ~= "Unknown" then
        newZone = lastKnownZone
    end

    local zoneChanged = (lastKnownZone ~= newZone)
    local diffChanged = (lastKnownDiff ~= nil and lastKnownDiff ~= newDiff)

    lastKnownZone = newZone
    lastKnownDiff = newDiff

    if inCombatState then
        if currentSession.segments[1] and currentSession.segments[1].isBoss then
            currentSession.segments[1].difficulty = newDiff
            if currentSession.segments[1].zone == "Unknown" and newZone ~= "Unknown" then
                currentSession.segments[1].zone = newZone
            end
        end
    else
        EnsureTrashSegment()
        if currentSession.segments[1] and not currentSession.segments[1].isBoss then
            currentSession.segments[1].difficulty = newDiff
        end
    end

    if diffChanged and announceDiffChange then
        AnnounceLocalChat(string.format("Raid size/difficulty updated to: %s (%s)", newDiff, newZone))
    end

    UpdateFooterLive()
    RequestMainViewRefresh()
end

local function SnapshotRaidActiveBuffs(bossSegment)
    local function ScanUnit(unit)
        if not UnitExists(unit) then return end
        local name = UnitName(unit)
        if not name or name == UNKNOWN then return end
        local _, engClass = UnitClass(unit)
        local pClass = engClass or GetSafePlayerClass(name)

        for i = 1, 40 do
            local buffName, _, _, _, _, _, _, _, _, _, spellID = UnitBuff(unit, i)
            if not buffName then break end
            if spellID and SNAPSHOT_PERSISTENT_BUFFS[spellID] and POTIONS_AND_BUFFS[spellID] then
                local label = POTIONS_AND_BUFFS[spellID]
                bossSegment.players[name] = pClass
                bossSegment.potionsAndBuffs[name] = bossSegment.potionsAndBuffs[name] or {}
                if not bossSegment.potionsAndBuffs[name][label] then
                    bossSegment.potionsAndBuffs[name][label] = 1
                end
            end
        end
    end

    local numRaid = GetNumRaidMembers()
    if numRaid > 0 then
        for i = 1, numRaid do ScanUnit("raid" .. i) end
    else
        ScanUnit("player")
        for i = 1, GetNumPartyMembers() do ScanUnit("party" .. i) end
    end
end

local outOfCombatAccum = 0
local gracePeriodAccum = 0
local diffPollAccum = 0

local function StartEncounter(bossID, bossName, overrideData, fromSpeech)
    if inCombatState or not bossName then return end
    if not fromSpeech and not IsRaidInCombat() then return end

    local now = GetTime()
    if defeatedBossLocks[bossName] and (now - defeatedBossLocks[bossName]) < 180.0 then
        return
    end
    if bossEndCooldowns[bossName] and (now - bossEndCooldowns[bossName]) < 12.0 then
        return
    end

    UpdateGroupCache()

    local info = BOSS_NAME_TO_INFO[bossName]
    activeBossID = bossID or (info and info.primaryID) or nil
    activeBossName = bossName
    activeBossData = overrideData or (activeBossID and WOTLK_BOSS_DB[activeBossID]) or info or {}
    inCombatState = true
    hasEnteredBossCombat = IsRaidInCombat()
    bossStartTime = now
    outOfCombatAccum = 0
    gracePeriodAccum = 0
    table.wipe(defeatedGroupNPCs)

    bossAttemptCount[bossName] = (bossAttemptCount[bossName] or 0) + 1
    local att = bossAttemptCount[bossName]
    local segName = string.format("%s [Attempt %d]", bossName, att)

    local prevTrashSeg = (currentSession.segments[1] and not currentSession.segments[1].isBoss) and currentSession.segments[1] or nil

    local newBossSeg = GetNewSegment(segName, true, activeBossID, bossName, att)
    table.insert(currentSession.segments, 1, newBossSeg)
    currentSegment = currentSession.segments[1]

    SnapshotRaidActiveBuffs(newBossSeg)

    for _, ev in ipairs(recentPrePullEvents) do
        if (now - ev.ts) <= 5.0 then
            newBossSeg.players[ev.pName] = ev.pClass
            if ev.extraPlayer and ev.extraClass then
                newBossSeg.players[ev.extraPlayer] = ev.extraClass
            end

            if ev.category == "POTIONS" then
                newBossSeg.potionsAndBuffs[ev.pName] = newBossSeg.potionsAndBuffs[ev.pName] or {}
                newBossSeg.potionsAndBuffs[ev.pName][ev.entryName] = (newBossSeg.potionsAndBuffs[ev.pName][ev.entryName] or 0) + 1

                if prevTrashSeg and prevTrashSeg.potionsAndBuffs[ev.pName] and prevTrashSeg.potionsAndBuffs[ev.pName][ev.entryName] then
                    prevTrashSeg.potionsAndBuffs[ev.pName][ev.entryName] = prevTrashSeg.potionsAndBuffs[ev.pName][ev.entryName] - 1
                    if prevTrashSeg.potionsAndBuffs[ev.pName][ev.entryName] <= 0 then
                        prevTrashSeg.potionsAndBuffs[ev.pName][ev.entryName] = nil
                    end
                    if next(prevTrashSeg.potionsAndBuffs[ev.pName]) == nil then
                        prevTrashSeg.potionsAndBuffs[ev.pName] = nil
                    end
                end
            elseif ev.category == "UTILITY" then
                newBossSeg.raidUtility[ev.pName] = newBossSeg.raidUtility[ev.pName] or {}
                newBossSeg.raidUtility[ev.pName][ev.entryName] = (newBossSeg.raidUtility[ev.pName][ev.entryName] or 0) + 1

                if prevTrashSeg and prevTrashSeg.raidUtility[ev.pName] and prevTrashSeg.raidUtility[ev.pName][ev.entryName] then
                    prevTrashSeg.raidUtility[ev.pName][ev.entryName] = prevTrashSeg.raidUtility[ev.pName][ev.entryName] - 1
                    if prevTrashSeg.raidUtility[ev.pName][ev.entryName] <= 0 then
                        prevTrashSeg.raidUtility[ev.pName][ev.entryName] = nil
                    end
                    if next(prevTrashSeg.raidUtility[ev.pName]) == nil then
                        prevTrashSeg.raidUtility[ev.pName] = nil
                    end
                end
            end
        end
    end
    table.wipe(recentPrePullEvents)

    if prevTrashSeg and currentSession.segments[2] == prevTrashSeg and IsSegmentEmpty(prevTrashSeg) then
        table.remove(currentSession.segments, 2)
    end

    AnnounceLocalChat(string.format("Encounter Engaged: %s (%s)", bossName, GetRaidDifficultySuffix()))
    RequestMainViewRefresh()
end

local function EndEncounter(isVictory, reason)
    if not inCombatState then return end

    local now = GetTime()
    local duration = math.max(1, math.floor(now - bossStartTime))
    local mins = math.floor(duration / 60)
    local secs = duration % 60
    local timeStr = string.format("%dm %ds", mins, secs)
    local finishedBoss = activeBossName or "Boss"

    if not isVictory and finishedBoss == "Faction Champions" then
        local champsKilled = 0
        for _ in pairs(defeatedGroupNPCs) do
            champsKilled = champsKilled + 1
        end
        local diff = GetRaidDifficultySuffix()
        local reqKills = (diff:find("25") ~= nil) and 10 or 6
        if champsKilled >= reqKills or (champsKilled >= 4 and not UnitIsDeadOrGhost("player")) then
            isVictory = true
        end
    end

    if isVictory then
        bossEndCooldowns[finishedBoss] = now
        defeatedBossLocks[finishedBoss] = now
        if currentSession.segments[1] and currentSession.segments[1].isBoss then
            currentSession.segments[1].name = string.format("%s [Victory - %s]", finishedBoss, timeStr)
        end
        AnnounceLocalChat(string.format("VICTORY: %s was killed and it was a victory! (%s)", finishedBoss, timeStr))
    else
        if duration < 15 or not hasEnteredBossCombat then
            if currentSession.segments[1] and currentSession.segments[1].isBoss then
                table.remove(currentSession.segments, 1)
            end
            if activeBossName and bossAttemptCount[activeBossName] and bossAttemptCount[activeBossName] > 0 then
                bossAttemptCount[activeBossName] = bossAttemptCount[activeBossName] - 1
            end
            AnnounceLocalChat(string.format("Boss combat ended: %s (Reset < 15s purged)", finishedBoss))
        else
            bossEndCooldowns[finishedBoss] = now
            if currentSession.segments[1] and currentSession.segments[1].isBoss then
                currentSession.segments[1].name = string.format("%s [Wipe %d - %s]", finishedBoss, currentSession.segments[1].attempt or 1, timeStr)
            end
            AnnounceLocalChat(string.format("Boss combat ended: %s (%s)", finishedBoss, timeStr))
        end
    end

    inCombatState = false
    hasEnteredBossCombat = false
    activeBossID = nil
    activeBossName = nil
    activeBossData = nil
    outOfCombatAccum = 0
    gracePeriodAccum = 0
    table.wipe(defeatedGroupNPCs)
    table.wipe(recentProcs)
    table.wipe(recentPrePullEvents)

    EnsureTrashSegment()
    RequestMainViewRefresh()
end

-- Continuous Watchdog for Wipe/Despawn Detection AND 1-Second Dynamic Difficulty Polling
local combatWatchdogFrame = CreateFrame("Frame")
combatWatchdogFrame:SetScript("OnUpdate", function(self, elapsed)
    diffPollAccum = diffPollAccum + elapsed
    if diffPollAccum >= 1.0 then
        diffPollAccum = 0
        if currentSession then
            local liveDiff = GetRaidDifficultySuffix()
            if lastKnownDiff ~= liveDiff then
                HandleZoneOrDifficultyUpdate(true)
            end
        end
    end

    if not inCombatState then
        outOfCombatAccum = 0
        gracePeriodAccum = 0
        return
    end

    gracePeriodAccum = gracePeriodAccum + elapsed

    if IsRaidInCombat() then
        hasEnteredBossCombat = true
        outOfCombatAccum = 0
        return
    end

    if not hasEnteredBossCombat then
        if gracePeriodAccum >= 35.0 then
            EndEncounter(false, "Pre-combat RP expired without pull")
        end
        return
    end

    if gracePeriodAccum < 5.0 then
        return
    end

    outOfCombatAccum = outOfCombatAccum + elapsed
    if outOfCombatAccum >= 3.5 then
        outOfCombatAccum = 0
        EndEncounter(false, "Boss Despawned / Wipe / Combat Ended")
    end
end)

-------------------------------------------------------------------------------
-- UI Management, Zero-Taint Custom Dropdowns & Render Engines
-------------------------------------------------------------------------------
local MainTrackerFrame = nil
local ConfigFrame = nil
local CharacterFrame = nil
local ReportFrame = nil
local DeathsFrame = nil
local DeathLogFrame = nil
local MinimapButton = nil
local activeCustomMenus = {}

local currentView = "POTIONS"
local selectedSessionIndex = 0
local selectedSegmentIndex = 1
local segmentPage = 1
local deathsScopeAllSession = true
local selectedDeathPlayer = nil

local RefreshDeathsView = function() end
local RefreshDeathLogView = function() end
local RefreshCharactersView = function() end

local function HideAllCustomDropdownMenus()
    for _, menu in ipairs(activeCustomMenus) do
        menu:Hide()
    end
end

local function GetActiveSession()
    if selectedSessionIndex == 0 or not RaidersTrackerDB.savedSessions[selectedSessionIndex] then
        return currentSession
    end
    return RaidersTrackerDB.savedSessions[selectedSessionIndex]
end

local function CloseAllPanels()
    HideAllCustomDropdownMenus()
    if MainTrackerFrame then MainTrackerFrame:Hide() end
    if ConfigFrame then ConfigFrame:Hide() end
    if CharacterFrame then CharacterFrame:Hide() end
    if ReportFrame then ReportFrame:Hide() end
    if DeathsFrame then DeathsFrame:Hide() end
    if DeathLogFrame then DeathLogFrame:Hide() end
end

local function ResetAllPanelPositions()
    local panels = { MainTrackerFrame, ConfigFrame, CharacterFrame, ReportFrame, DeathsFrame, DeathLogFrame }
    for _, frame in ipairs(panels) do
        if frame then
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
    end
    AnnounceLocalChat("All panel positions have been reset to the center of the screen.")
end

local function RegisterEscapeClose(frameName, frame)
    _G[frameName] = frame
    local found = false
    for _, existing in ipairs(UISpecialFrames) do
        if existing == frameName then
            found = true
            break
        end
    end
    if not found then
        tinsert(UISpecialFrames, frameName)
    end
end

local function CreateWhiteBorderViewBox(parent, topOffsetY, bottomOffsetY)
    local box = CreateFrame("Frame", nil, parent)
    box:SetPoint("TOPLEFT", parent, "TOPLEFT", 18, topOffsetY or -132)
    box:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -18, bottomOffsetY or 40)
    box:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    box:SetBackdropColor(0.04, 0.04, 0.06, 0.92)
    box:SetBackdropBorderColor(1.0, 1.0, 1.0, 0.95)
    return box
end

-- Standalone, Zero-Taint Custom Dropdown Widget
local function CreateCustomDropdown(parent, width, height)
    local dropdown = CreateFrame("Button", nil, parent)
    dropdown:SetSize(width, height or 24)
    dropdown:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    dropdown:SetBackdropColor(0.08, 0.08, 0.11, 0.95)
    dropdown:SetBackdropBorderColor(0.85, 0.85, 0.85, 0.90)

    local label = dropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", dropdown, "LEFT", 8, 0)
    label:SetPoint("RIGHT", dropdown, "RIGHT", -22, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)

    local arrow = dropdown:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    arrow:SetPoint("RIGHT", dropdown, "RIGHT", -6, 0)
    arrow:SetText("|cffFFFFFFv|r")

    local menuFrame = CreateFrame("Frame", nil, dropdown)
    menuFrame:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -2)
    menuFrame:SetWidth(width)
    menuFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    menuFrame:SetFrameLevel(dropdown:GetFrameLevel() + 20)
    menuFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    menuFrame:SetBackdropColor(0.05, 0.05, 0.08, 0.98)
    menuFrame:SetBackdropBorderColor(1.0, 1.0, 1.0, 0.95)
    menuFrame:EnableMouse(true)
    menuFrame:Hide()

    table.insert(activeCustomMenus, menuFrame)

    local optionButtons = {}
    local maxRows = 26

    for i = 1, maxRows do
        local btn = CreateFrame("Button", nil, menuFrame)
        btn:SetHeight(18)
        btn:SetPoint("TOPLEFT", menuFrame, "TOPLEFT", 3, -((i - 1) * 18) - 3)
        btn:SetPoint("TOPRIGHT", menuFrame, "TOPRIGHT", -3, -((i - 1) * 18) - 3)

        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(btn)
        hl:SetTexture("Interface\\Buttons\\WHITE8X8")
        hl:SetVertexColor(1.0, 1.0, 1.0, 0.18)

        local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        txt:SetPoint("LEFT", btn, "LEFT", 5, 0)
        txt:SetPoint("RIGHT", btn, "RIGHT", -5, 0)
        txt:SetJustifyH("LEFT")
        txt:SetWordWrap(false)

        btn.txt = txt
        btn:Hide()
        optionButtons[i] = btn
    end

    function dropdown:SetText(text)
        label:SetText(text or "")
    end

    dropdown:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
    end)
    dropdown:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.85, 0.85, 0.85, 0.90)
    end)

    dropdown:SetScript("OnClick", function(self)
        if menuFrame:IsShown() then
            menuFrame:Hide()
            return
        end
        HideAllCustomDropdownMenus()
        if not self.getItems then return end

        local items = self.getItems() or {}
        for i = 1, maxRows do
            optionButtons[i]:Hide()
        end

        local count = math.min(#items, maxRows)
        if count == 0 then
            optionButtons[1].txt:SetText("|cff888888No entries|r")
            optionButtons[1]:SetScript("OnClick", function() menuFrame:Hide() end)
            optionButtons[1]:Show()
            count = 1
        else
            for i = 1, count do
                local item = items[i]
                local btn = optionButtons[i]
                if item.checked then
                    btn.txt:SetText("|cff00FF00> " .. (item.text or "") .. "|r")
                else
                    btn.txt:SetText("   " .. (item.text or ""))
                end
                btn:SetScript("OnClick", function()
                    menuFrame:Hide()
                    if item.func then item.func() end
                end)
                btn:Show()
            end
        end

        menuFrame:SetHeight(count * 18 + 6)
        menuFrame:Show()
    end)

    return dropdown
end

local function CreateRUTPanel(name, width, height, title)
    local frame = CreateFrame("Frame", name, UIParent)
    frame:SetSize(width, height)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetScript("OnHide", function() HideAllCustomDropdownMenus() end)
    frame:Hide()

    local titleBg = frame:CreateTexture(nil, "ARTWORK")
    titleBg:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    titleBg:SetWidth(math.max(260, width * 0.60))
    titleBg:SetHeight(64)
    titleBg:SetPoint("TOP", frame, "TOP", 0, 12)

    local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOP", titleBg, "TOP", 0, -14)
    titleText:SetText(title or ADDON_NAME)
    frame.titleText = titleText

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    RegisterEscapeClose(name, frame)
    return frame
end

local uiRefreshFrame = CreateFrame("Frame")
local uiRefreshElapsed = 0
local uiRefreshPending = false

-- Only refreshes MainTrackerFrame on background combat log events so button clicks in Deaths/Characters are never interrupted
RequestMainViewRefresh = function()
    if not MainTrackerFrame or not MainTrackerFrame:IsShown() then
        return
    end
    if not uiRefreshPending then
        uiRefreshPending = true
        uiRefreshElapsed = 0
        uiRefreshFrame:SetScript("OnUpdate", function(self, elapsed)
            uiRefreshElapsed = uiRefreshElapsed + elapsed
            if uiRefreshElapsed >= 0.20 then
                self:SetScript("OnUpdate", nil)
                uiRefreshPending = false
                if MainTrackerFrame and MainTrackerFrame:IsShown() then
                    RefreshMainView()
                end
            end
        end)
    end
end

-------------------------------------------------------------------------------
-- New Character Login Prompt Popup Dialog
-------------------------------------------------------------------------------
StaticPopupDialogs["RT_NEW_CHAR_SESSION_PROMPT"] = {
    text = "|cff00FF00" .. ADDON_NAME .. "|r\n\nRecorded data from |cffFFD100%s|r was found in the Live Current Session.\n\nDo you want to save the current live session and start a fresh session for |cff00FF00%s|r?",
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        SaveCurrentLiveSession(true)
        selectedSessionIndex = 0
        selectedSegmentIndex = 1
        segmentPage = 1
        if MainTrackerFrame and MainTrackerFrame:IsShown() then
            RefreshMainView()
        end
    end,
    OnCancel = function()
        AnnounceLocalChat("Continuing in the existing Live Current Session.")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

-------------------------------------------------------------------------------
-- Minimap Icon Construction
-------------------------------------------------------------------------------
local function CreateMinimapButton()
    MinimapButton = CreateFrame("Button", "RTMinimapButton", Minimap)
    MinimapButton:SetSize(33, 33)
    MinimapButton:SetFrameStrata("MEDIUM")

    local icon = MinimapButton:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\Icons\\INV_Alchemy_Elixir_01")
    icon:SetSize(21, 21)
    icon:SetPoint("CENTER")

    local border = MinimapButton:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(56, 56)
    border:SetPoint("TOPLEFT")

    local function UpdatePosition()
        local angle = math.rad(RaidersTrackerDB.minimapPos or 45)
        local x = math.cos(angle) * 80
        local y = math.sin(angle) * 80
        MinimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end

    MinimapButton:RegisterForDrag("LeftButton")
    MinimapButton:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local xpos, ypos = GetCursorPosition()
            local xmin, ymin = Minimap:GetLeft(), Minimap:GetBottom()
            local scale = Minimap:GetEffectiveScale()
            xpos = xpos / scale - xmin - 70
            ypos = ypos / scale - ymin - 70
            RaidersTrackerDB.minimapPos = math.deg(math.atan2(ypos, xpos))
            UpdatePosition()
        end)
    end)
    MinimapButton:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

    MinimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    MinimapButton:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            if MainTrackerFrame:IsShown() then MainTrackerFrame:Hide() else CloseAllPanels(); MainTrackerFrame:Show() end
        elseif button == "RightButton" then
            if ConfigFrame:IsShown() then ConfigFrame:Hide() else CloseAllPanels(); ConfigFrame:Show() end
        end
    end)

    MinimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(ADDON_NAME)
        GameTooltip:AddLine("|cffFFFFFFLeft-Click:|r Toggle Tracker Panel", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cffFFFFFFRight-Click:|r Toggle Config Panel", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    MinimapButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    UpdatePosition()
end

-------------------------------------------------------------------------------
-- Main Tracker Frame Implementation
-------------------------------------------------------------------------------
local function CreateMainTrackerFrame()
    MainTrackerFrame = CreateRUTPanel("RTMainTrackerFrame", 740, 560, ADDON_NAME)

    local btnPotions = CreateFrame("Button", nil, MainTrackerFrame, "UIPanelButtonTemplate")
    btnPotions:SetSize(175, 25)
    btnPotions:SetPoint("TOPLEFT", MainTrackerFrame, "TOPLEFT", 18, -36)
    btnPotions:SetText("1. Potions and Buffs")

    local btnUtility = CreateFrame("Button", nil, MainTrackerFrame, "UIPanelButtonTemplate")
    btnUtility:SetSize(175, 25)
    btnUtility:SetPoint("LEFT", btnPotions, "RIGHT", 10, 0)
    btnUtility:SetText("2. Raid Utility")

    local viewStatusText = MainTrackerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    viewStatusText:SetPoint("LEFT", btnUtility, "RIGHT", 16, 0)
    viewStatusText:SetTextColor(0.85, 0.85, 0.85)

    btnPotions:SetScript("OnClick", function()
        HideAllCustomDropdownMenus()
        currentView = "POTIONS"
        RefreshMainView()
    end)
    btnUtility:SetScript("OnClick", function()
        HideAllCustomDropdownMenus()
        currentView = "UTILITY"
        RefreshMainView()
    end)

    local sessionDropdown = CreateCustomDropdown(MainTrackerFrame, 195, 24)
    sessionDropdown:SetPoint("TOPLEFT", MainTrackerFrame, "TOPLEFT", 18, -70)

    local segmentDropdown = CreateCustomDropdown(MainTrackerFrame, 260, 24)
    segmentDropdown:SetPoint("LEFT", sessionDropdown, "RIGHT", 10, 0)

    sessionDropdown.getItems = function()
        local list = {}
        table.insert(list, {
            text = "Live Current Session",
            checked = (selectedSessionIndex == 0),
            func = function()
                selectedSessionIndex = 0
                selectedSegmentIndex = 1
                segmentPage = 1
                RefreshMainView()
            end
        })
        for idx, sess in ipairs(RaidersTrackerDB.savedSessions) do
            local capturedIdx = idx
            table.insert(list, {
                text = sess.name or ("Saved Session " .. capturedIdx),
                checked = (selectedSessionIndex == capturedIdx),
                func = function()
                    selectedSessionIndex = capturedIdx
                    selectedSegmentIndex = 1
                    segmentPage = 1
                    RefreshMainView()
                end
            })
        end
        return list
    end

    segmentDropdown.getItems = function()
        local list = {}
        local activeSession = GetActiveSession()
        local segs = (activeSession and activeSession.segments) or {}
        local startIndex = (segmentPage - 1) * 25 + 1
        local endIndex = math.min(#segs, segmentPage * 25)

        for i = startIndex, endIndex do
            local capturedIndex = i
            local s = segs[capturedIndex]
            local segLabel = string.format("%s (%s)", s.name or "TRASH", s.difficulty or "")
            table.insert(list, {
                text = segLabel,
                checked = (selectedSegmentIndex == capturedIndex),
                func = function()
                    selectedSegmentIndex = capturedIndex
                    RefreshMainView()
                end
            })
        end
        return list
    end

    local btnPrevPage = CreateFrame("Button", nil, MainTrackerFrame, "UIPanelButtonTemplate")
    btnPrevPage:SetSize(24, 24)
    btnPrevPage:SetPoint("LEFT", segmentDropdown, "RIGHT", 8, 0)
    btnPrevPage:SetText("<")

    local btnNextPage = CreateFrame("Button", nil, MainTrackerFrame, "UIPanelButtonTemplate")
    btnNextPage:SetSize(24, 24)
    btnNextPage:SetPoint("LEFT", btnPrevPage, "RIGHT", 4, 0)
    btnNextPage:SetText(">")

    local btnReport = CreateFrame("Button", nil, MainTrackerFrame, "UIPanelButtonTemplate")
    btnReport:SetSize(105, 24)
    btnReport:SetPoint("LEFT", btnNextPage, "RIGHT", 10, 0)
    btnReport:SetText("Report Seg")
    btnReport:SetScript("OnClick", function() CloseAllPanels(); ReportFrame:Show() end)

    local btnCharacters = CreateFrame("Button", nil, MainTrackerFrame, "UIPanelButtonTemplate")
    btnCharacters:SetSize(110, 22)
    btnCharacters:SetPoint("TOPLEFT", MainTrackerFrame, "TOPLEFT", 18, -103)
    btnCharacters:SetText("Characters")
    btnCharacters:SetScript("OnClick", function() CloseAllPanels(); CharacterFrame:Show() end)

    local btnSaveSession = CreateFrame("Button", nil, MainTrackerFrame, "UIPanelButtonTemplate")
    btnSaveSession:SetSize(110, 22)
    btnSaveSession:SetPoint("LEFT", btnCharacters, "RIGHT", 8, 0)
    btnSaveSession:SetText("Save Session")

    local btnDeleteSeg = CreateFrame("Button", nil, MainTrackerFrame, "UIPanelButtonTemplate")
    btnDeleteSeg:SetSize(100, 22)
    btnDeleteSeg:SetPoint("LEFT", btnSaveSession, "RIGHT", 8, 0)
    btnDeleteSeg:SetText("Delete Seg")

    local btnConfig = CreateFrame("Button", nil, MainTrackerFrame, "UIPanelButtonTemplate")
    btnConfig:SetSize(95, 22)
    btnConfig:SetPoint("LEFT", btnDeleteSeg, "RIGHT", 8, 0)
    btnConfig:SetText("Config")
    btnConfig:SetScript("OnClick", function() CloseAllPanels(); ConfigFrame:Show() end)

    local btnDeaths = CreateFrame("Button", nil, MainTrackerFrame, "UIPanelButtonTemplate")
    btnDeaths:SetSize(95, 22)
    btnDeaths:SetPoint("LEFT", btnConfig, "RIGHT", 8, 0)
    btnDeaths:SetText("Deaths")
    btnDeaths:SetScript("OnClick", function() CloseAllPanels(); DeathsFrame:Show() end)

    local viewBox = CreateWhiteBorderViewBox(MainTrackerFrame, -132, 38)

    local scrollFrame = CreateFrame("ScrollFrame", "RTMainScrollFrame", viewBox, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", viewBox, "TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", viewBox, "BOTTOMRIGHT", -28, 8)

    local scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetSize(650, 380)
    scrollFrame:SetScrollChild(scrollContent)

    local fontStrings = {}
    for i = 1, 1500 do
        local fs = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 8, -((i - 1) * 18) - 4)
        fs:SetJustifyH("LEFT")
        fs:Hide()
        fontStrings[i] = fs
    end

    local leftFooter = MainTrackerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    leftFooter:SetPoint("BOTTOMLEFT", MainTrackerFrame, "BOTTOMLEFT", 20, 15)

    local rightFooter = MainTrackerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rightFooter:SetPoint("BOTTOMRIGHT", MainTrackerFrame, "BOTTOMRIGHT", -20, 15)
    rightFooter:SetText(GetFooterText())

    UpdateFooterLive = function()
        if not leftFooter then return end
        local liveZone = GetCurrentZoneSafe()
        local liveDiff = GetRaidDifficultySuffix()
        local numRaid = GetNumRaidMembers()
        local numParty = GetNumPartyMembers()
        local numGroup = (numRaid > 0) and numRaid or ((numParty > 0) and (numParty + 1) or 1)
        leftFooter:SetText(string.format("Current Zone: |cffFFFFFF%s (%s)|r  |  Raid/Party Size: |cffFFFFFF%d|r", liveZone, liveDiff, numGroup))

        if MainTrackerFrame and MainTrackerFrame:IsShown() then
            local activeSession = GetActiveSession()
            local segments = (activeSession and activeSession.segments) or {}
            local currentSegObj = segments[selectedSegmentIndex]
            if currentSegObj then
                segmentDropdown:SetText(string.format("%s (%s)", currentSegObj.name or "TRASH", currentSegObj.difficulty or liveDiff))
            end
        end
    end

    StaticPopupDialogs["RT_DELETE_SEGMENT"] = {
        text = "Really delete this segment?",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            local session = GetActiveSession()
            if session and session.segments and session.segments[selectedSegmentIndex] then
                table.remove(session.segments, selectedSegmentIndex)
                if session == currentSession and #session.segments == 0 then
                    EnsureTrashSegment()
                end
                selectedSegmentIndex = 1
                RefreshMainView()
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

    btnDeleteSeg:SetScript("OnClick", function()
        HideAllCustomDropdownMenus()
        StaticPopup_Show("RT_DELETE_SEGMENT")
    end)

    btnSaveSession:SetScript("OnClick", function()
        HideAllCustomDropdownMenus()
        SaveCurrentLiveSession(true)
        selectedSessionIndex = 1
        selectedSegmentIndex = 1
        segmentPage = 1
        RefreshMainView()
    end)

    RefreshMainView = function()
        if not MainTrackerFrame or not MainTrackerFrame:IsShown() then return end

        local activeSession = GetActiveSession()
        local segments = (activeSession and activeSession.segments) or {}
        if selectedSegmentIndex > #segments then
            selectedSegmentIndex = math.max(1, #segments)
        end
        local seg = segments[selectedSegmentIndex]

        if currentView == "POTIONS" then
            btnPotions:LockHighlight()
            btnUtility:UnlockHighlight()
            viewStatusText:SetText("|cff00FF00Viewing: Raider Potions, Flasks, Food & Buff Procs|r")
        else
            btnPotions:UnlockHighlight()
            btnUtility:LockHighlight()
            viewStatusText:SetText("|cff00CCFFViewing: Raider Utility Spells & Cooldowns Used|r")
        end

        local lineIndex = 1
        if seg then
            local dataSource = (currentView == "POTIONS") and seg.potionsAndBuffs or seg.raidUtility
            local sortedPlayers = {}
            for pName, entries in pairs(dataSource) do
                if next(entries) ~= nil then
                    table.insert(sortedPlayers, pName)
                end
            end
            table.sort(sortedPlayers)

            if #sortedPlayers == 0 then
                fontStrings[1]:SetText("|cff999999No " .. ((currentView == "POTIONS") and "potions/buffs" or "utility abilities") .. " recorded in this segment yet.|r")
                fontStrings[1]:Show()
                lineIndex = 2
            else
                for _, pName in ipairs(sortedPlayers) do
                    local cClass = seg.players[pName] or GetSafePlayerClass(pName)
                    local hexColor = GetPlayerClassColor(cClass)

                    local sortedEntries = {}
                    local totalActions = 0
                    for buffName, count in pairs(dataSource[pName]) do
                        table.insert(sortedEntries, { name = buffName, count = count })
                        totalActions = totalActions + count
                    end
                    table.sort(sortedEntries, function(a, b) return a.name < b.name end)

                    if lineIndex <= 1500 then
                        fontStrings[lineIndex]:SetText(string.format("%s |cff888888(%d total)|r", ColorizeText(pName, hexColor), totalActions))
                        fontStrings[lineIndex]:Show()
                        lineIndex = lineIndex + 1
                    end

                    for _, entry in ipairs(sortedEntries) do
                        if lineIndex <= 1500 then
                            fontStrings[lineIndex]:SetText(string.format("   |cff808080-|r %s: |cff00FF00%d|r", entry.name, entry.count))
                            fontStrings[lineIndex]:Show()
                            lineIndex = lineIndex + 1
                        end
                    end
                end
            end
        else
            fontStrings[1]:SetText("|cff999999No active segment available.|r")
            fontStrings[1]:Show()
            lineIndex = 2
        end

        for i = lineIndex, 1500 do
            fontStrings[i]:Hide()
        end

        UpdateFooterLive()
        scrollContent:SetHeight(math.max(375, (lineIndex - 1) * 18 + 16))

        local totalPages = math.max(1, math.ceil(#segments / 25))
        if segmentPage > totalPages then segmentPage = totalPages end
        if segmentPage <= 1 then btnPrevPage:Disable() else btnPrevPage:Enable() end
        if segmentPage >= totalPages then btnNextPage:Disable() else btnNextPage:Enable() end

        sessionDropdown:SetText((selectedSessionIndex == 0) and "Live Current Session" or (RaidersTrackerDB.savedSessions[selectedSessionIndex] and RaidersTrackerDB.savedSessions[selectedSessionIndex].name or "Saved Session"))

        local currentSegObj = segments[selectedSegmentIndex]
        if currentSegObj then
            segmentDropdown:SetText(string.format("%s (%s)", currentSegObj.name or "TRASH", currentSegObj.difficulty or GetRaidDifficultySuffix()))
        else
            segmentDropdown:SetText("No Segments")
        end
    end

    btnPrevPage:SetScript("OnClick", function()
        HideAllCustomDropdownMenus()
        if segmentPage > 1 then
            segmentPage = segmentPage - 1
            RefreshMainView()
        end
    end)

    btnNextPage:SetScript("OnClick", function()
        HideAllCustomDropdownMenus()
        local activeSession = GetActiveSession()
        local totalPages = math.ceil(#(activeSession.segments or {}) / 25)
        if segmentPage < totalPages then
            segmentPage = segmentPage + 1
            RefreshMainView()
        end
    end)

    MainTrackerFrame:SetScript("OnShow", function()
        HideAllCustomDropdownMenus()
        EnsureTrashSegment()
        RefreshMainView()
    end)
end

-------------------------------------------------------------------------------
-- Deaths Panel & Death Log Panel Implementation (Instant First-Click Response)
-------------------------------------------------------------------------------
local function CollectDeathsForActiveScope()
    local activeSession = GetActiveSession()
    local segments = (activeSession and activeSession.segments) or {}
    local deathsByPlayer = {}
    local playerClasses = {}

    if deathsScopeAllSession then
        for _, seg in ipairs(segments) do
            for pName, pClass in pairs(seg.players or {}) do
                playerClasses[pName] = pClass
            end
            for pName, dList in pairs(seg.deaths or {}) do
                if type(dList) == "table" and #dList > 0 then
                    deathsByPlayer[pName] = deathsByPlayer[pName] or {}
                    for _, dEntry in ipairs(dList) do
                        table.insert(deathsByPlayer[pName], dEntry)
                    end
                end
            end
        end
    else
        local seg = segments[selectedSegmentIndex]
        if seg then
            for pName, pClass in pairs(seg.players or {}) do
                playerClasses[pName] = pClass
            end
            for pName, dList in pairs(seg.deaths or {}) do
                if type(dList) == "table" and #dList > 0 then
                    deathsByPlayer[pName] = deathsByPlayer[pName] or {}
                    for _, dEntry in ipairs(dList) do
                        table.insert(deathsByPlayer[pName], dEntry)
                    end
                end
            end
        end
    end

    return deathsByPlayer, playerClasses
end

local function CreateDeathsFrame()
    DeathsFrame = CreateRUTPanel("RTDeathsFrame", 520, 460, "Raid Deaths")

    local btnScope = CreateFrame("Button", nil, DeathsFrame, "UIPanelButtonTemplate")
    btnScope:SetSize(230, 22)
    btnScope:SetPoint("TOPLEFT", DeathsFrame, "TOPLEFT", 18, -36)

    local scopeHint = DeathsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    scopeHint:SetPoint("LEFT", btnScope, "RIGHT", 12, 0)
    scopeHint:SetText("|cffCCCCCCSorted by highest deaths|r")

    local btnBack = CreateFrame("Button", nil, DeathsFrame, "UIPanelButtonTemplate")
    btnBack:SetSize(130, 24)
    btnBack:SetPoint("BOTTOM", DeathsFrame, "BOTTOM", 0, 14)
    btnBack:SetText("Back to Tracker")
    btnBack:SetScript("OnClick", function() CloseAllPanels(); MainTrackerFrame:Show() end)

    local viewBox = CreateWhiteBorderViewBox(DeathsFrame, -66, 46)

    local scrollFrame = CreateFrame("ScrollFrame", "RTDeathsScrollFrame", viewBox, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", viewBox, "TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", viewBox, "BOTTOMRIGHT", -28, 8)

    local scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetSize(440, 340)
    scrollFrame:SetScrollChild(scrollContent)

    local emptyLabel = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    emptyLabel:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 8, -8)
    emptyLabel:SetText("|cff999999No player deaths recorded yet.|r")
    emptyLabel:Hide()

    local rows = {}
    for i = 1, 100 do
        local row = CreateFrame("Frame", nil, scrollContent)
        row:SetSize(440, 24)
        row:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 4, -((i - 1) * 24) - 4)

        local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("LEFT", row, "LEFT", 6, 0)

        local btnLog = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        btnLog:SetSize(90, 20)
        btnLog:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        btnLog:SetText("Death Log")
        btnLog:RegisterForClicks("LeftButtonUp")
        btnLog:SetScript("OnClick", function(self)
            if self.playerName then
                selectedDeathPlayer = self.playerName
                CloseAllPanels()
                DeathLogFrame:Show()
            end
        end)

        row.text = text
        row.btnLog = btnLog
        row:Hide()
        rows[i] = row
    end

    btnScope:SetScript("OnClick", function()
        deathsScopeAllSession = not deathsScopeAllSession
        RefreshDeathsView()
    end)

    RefreshDeathsView = function()
        if not DeathsFrame or not DeathsFrame:IsShown() then return end

        btnScope:SetText(deathsScopeAllSession and "Scope: All Session Segments" or "Scope: Selected Segment")

        local deathsByPlayer, playerClasses = CollectDeathsForActiveScope()
        local sortedList = {}

        for pName, dList in pairs(deathsByPlayer) do
            table.insert(sortedList, {
                name = pName,
                count = #dList,
                class = playerClasses[pName] or GetSafePlayerClass(pName)
            })
        end

        table.sort(sortedList, function(a, b)
            if a.count ~= b.count then
                return a.count > b.count
            end
            return a.name < b.name
        end)

        if #sortedList == 0 then
            for i = 1, 100 do rows[i]:Hide() end
            emptyLabel:Show()
            scrollContent:SetHeight(330)
            return
        end

        emptyLabel:Hide()

        local shownCount = math.min(#sortedList, 100)
        for idx = 1, shownCount do
            local item = sortedList[idx]
            local hexColor = GetPlayerClassColor(item.class)
            local deathWord = (item.count == 1) and "Death" or "Deaths"
            rows[idx].text:SetText(string.format("%d. %s  |cffFF4444(%d %s)|r", idx, ColorizeText(item.name, hexColor), item.count, deathWord))
            rows[idx].btnLog.playerName = item.name
            if not rows[idx]:IsShown() then
                rows[idx]:Show()
            end
        end

        for idx = shownCount + 1, 100 do
            rows[idx]:Hide()
        end

        scrollContent:SetHeight(math.max(330, shownCount * 24 + 12))
    end

    DeathsFrame:SetScript("OnShow", RefreshDeathsView)
end

local function CreateDeathLogFrame()
    DeathLogFrame = CreateRUTPanel("RTDeathLogFrame", 680, 480, "Death Log")

    local headerLabel = DeathLogFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerLabel:SetPoint("TOPLEFT", DeathLogFrame, "TOPLEFT", 20, -38)

    local btnBackDeaths = CreateFrame("Button", nil, DeathLogFrame, "UIPanelButtonTemplate")
    btnBackDeaths:SetSize(130, 24)
    btnBackDeaths:SetPoint("BOTTOMLEFT", DeathLogFrame, "BOTTOMLEFT", 18, 14)
    btnBackDeaths:SetText("Back to Deaths")
    btnBackDeaths:SetScript("OnClick", function() CloseAllPanels(); DeathsFrame:Show() end)

    local btnBackTracker = CreateFrame("Button", nil, DeathLogFrame, "UIPanelButtonTemplate")
    btnBackTracker:SetSize(130, 24)
    btnBackTracker:SetPoint("LEFT", btnBackDeaths, "RIGHT", 10, 0)
    btnBackTracker:SetText("Back to Tracker")
    btnBackTracker:SetScript("OnClick", function() CloseAllPanels(); MainTrackerFrame:Show() end)

    local footerText = DeathLogFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    footerText:SetPoint("BOTTOMRIGHT", DeathLogFrame, "BOTTOMRIGHT", -20, 18)
    footerText:SetText(GetFooterText())

    local viewBox = CreateWhiteBorderViewBox(DeathLogFrame, -64, 46)

    local scrollFrame = CreateFrame("ScrollFrame", "RTDeathLogScrollFrame", viewBox, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", viewBox, "TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", viewBox, "BOTTOMRIGHT", -28, 8)

    local scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetSize(600, 350)
    scrollFrame:SetScrollChild(scrollContent)

    local logLines = {}
    for i = 1, 300 do
        local fs = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 8, -((i - 1) * 20) - 6)
        fs:SetJustifyH("LEFT")
        fs:Hide()
        logLines[i] = fs
    end

    RefreshDeathLogView = function()
        if not DeathLogFrame or not DeathLogFrame:IsShown() then return end

        local pName = selectedDeathPlayer or "Unknown"
        local deathsByPlayer, playerClasses = CollectDeathsForActiveScope()
        local pClass = playerClasses[pName] or GetSafePlayerClass(pName)
        local hexColor = GetPlayerClassColor(pClass)
        local pDeaths = deathsByPlayer[pName] or {}

        headerLabel:SetText(string.format("Detailed Death Log for %s  |cffFF4444(%d Total)|r", ColorizeText(pName, hexColor), #pDeaths))

        if #pDeaths == 0 then
            logLines[1]:SetText("|cff999999No deaths recorded for this player in the selected scope.|r")
            logLines[1]:Show()
            for i = 2, 300 do logLines[i]:Hide() end
            scrollContent:SetHeight(340)
            return
        end

        local shownCount = math.min(#pDeaths, 300)
        for idx = 1, shownCount do
            local d = pDeaths[idx]
            local killer = d.killer or "Unknown Mob"
            local ability = d.ability or "Unknown Attack"
            local amount = tonumber(d.amount) or 0
            local overkill = tonumber(d.overkill) or 0
            local segLabel = d.segment or "Segment"
            local timeStr = d.time or ""

            local dmgText = (amount > 0) and string.format("%d dmg", amount) or "Fatal Effect"
            if overkill > 0 then
                dmgText = string.format("%d dmg (%d overkill)", amount, overkill)
            end

            logLines[idx]:SetText(string.format(
                "%d. |cff888888[%s - %s]|r Killed by |cffFF5555%s|r  |  Ability: |cffFFD100%s|r  |  Damage: |cffFF2222%s|r",
                idx, timeStr, segLabel, killer, ability, dmgText
            ))
            logLines[idx]:Show()
        end

        for idx = shownCount + 1, 300 do
            logLines[idx]:Hide()
        end

        scrollContent:SetHeight(math.max(340, shownCount * 20 + 16))
    end

    DeathLogFrame:SetScript("OnShow", RefreshDeathLogView)
end

-------------------------------------------------------------------------------
-- Character Panel Implementation (Instant First-Click Whisper Response)
-------------------------------------------------------------------------------
local function CreateCharacterFrame()
    CharacterFrame = CreateRUTPanel("RTCharacterFrame", 500, 440, "Session Characters")

    local btnBack = CreateFrame("Button", nil, CharacterFrame, "UIPanelButtonTemplate")
    btnBack:SetSize(130, 24)
    btnBack:SetPoint("BOTTOM", CharacterFrame, "BOTTOM", 0, 14)
    btnBack:SetText("Back to Tracker")
    btnBack:SetScript("OnClick", function() CloseAllPanels(); MainTrackerFrame:Show() end)

    local viewBox = CreateWhiteBorderViewBox(CharacterFrame, -42, 46)

    local scrollFrame = CreateFrame("ScrollFrame", "RTCharScrollFrame", viewBox, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", viewBox, "TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", viewBox, "BOTTOMRIGHT", -28, 8)

    local scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetSize(420, 340)
    scrollFrame:SetScrollChild(scrollContent)

    local emptyLabel = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    emptyLabel:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 8, -8)
    emptyLabel:SetText("|cff999999No characters recorded in this session yet.|r")
    emptyLabel:Hide()

    local rows = {}
    for i = 1, 100 do
        local row = CreateFrame("Frame", nil, scrollContent)
        row:SetSize(420, 22)
        row:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 4, -((i - 1) * 22) - 4)

        local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("LEFT", row, "LEFT", 6, 0)

        local btnWhisper = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        btnWhisper:SetSize(65, 20)
        btnWhisper:SetPoint("RIGHT", row, "RIGHT", -10, 0)
        btnWhisper:SetText("Whisper")
        btnWhisper:RegisterForClicks("LeftButtonUp")
        btnWhisper:SetScript("OnClick", function(self)
            if self.playerName then
                if ChatFrame_SendTell then
                    ChatFrame_SendTell(self.playerName)
                else
                    ChatFrame_OpenChat("/w " .. self.playerName .. " ")
                end
            end
        end)

        row.text = text
        row.btnWhisper = btnWhisper
        row:Hide()
        rows[i] = row
    end

    RefreshCharactersView = function()
        if not CharacterFrame or not CharacterFrame:IsShown() then return end

        local activeSession = GetActiveSession()
        local playerMap = {}

        for pName, pClass in pairs((activeSession and activeSession.players) or {}) do
            playerMap[pName] = pClass
        end
        for _, seg in ipairs((activeSession and activeSession.segments) or {}) do
            for pName, pClass in pairs(seg.players or {}) do
                playerMap[pName] = pClass
            end
        end

        local sortedPlayers = {}
        for pName in pairs(playerMap) do table.insert(sortedPlayers, pName) end
        table.sort(sortedPlayers)

        if #sortedPlayers == 0 then
            for i = 1, 100 do rows[i]:Hide() end
            emptyLabel:Show()
            scrollContent:SetHeight(330)
            return
        end

        emptyLabel:Hide()

        local shownCount = math.min(#sortedPlayers, 100)
        for idx = 1, shownCount do
            local pName = sortedPlayers[idx]
            local pClass = playerMap[pName]
            local hexColor = GetPlayerClassColor(pClass)
            rows[idx].text:SetText(string.format("%s |cff888888(%s)|r", ColorizeText(pName, hexColor), pClass))
            rows[idx].btnWhisper.playerName = pName
            if not rows[idx]:IsShown() then
                rows[idx]:Show()
            end
        end

        for idx = shownCount + 1, 100 do
            rows[idx]:Hide()
        end

        scrollContent:SetHeight(math.max(330, shownCount * 22 + 12))
    end

    CharacterFrame:SetScript("OnShow", RefreshCharactersView)
end

-------------------------------------------------------------------------------
-- Comprehensive Report Panel Implementation (Characters, Deaths, Potions & Utility)
-------------------------------------------------------------------------------
local function CreateReportFrame()
    ReportFrame = CreateRUTPanel("RTReportFrame", 620, 500, "Report Segment Data")

    local btnBack = CreateFrame("Button", nil, ReportFrame, "UIPanelButtonTemplate")
    btnBack:SetSize(130, 24)
    btnBack:SetPoint("BOTTOMLEFT", ReportFrame, "BOTTOMLEFT", 18, 14)
    btnBack:SetText("Back to Tracker")
    btnBack:SetScript("OnClick", function() CloseAllPanels(); MainTrackerFrame:Show() end)

    local chkDiscord = CreateFrame("CheckButton", nil, ReportFrame, "UICheckButtonTemplate")
    chkDiscord:SetPoint("TOPLEFT", ReportFrame, "TOPLEFT", 18, -36)
    chkDiscord.text = chkDiscord:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    chkDiscord.text:SetPoint("LEFT", chkDiscord, "RIGHT", 4, 0)
    chkDiscord.text:SetText("Discord Markdown Format (Ctrl+C to copy)")

    local viewBox = CreateWhiteBorderViewBox(ReportFrame, -68, 46)

    local scrollFrame = CreateFrame("ScrollFrame", "RTReportScrollFrame", viewBox, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", viewBox, "TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", viewBox, "BOTTOMRIGHT", -28, 8)

    local editBox = CreateFrame("EditBox", "RTReportEditBox", scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(GameFontHighlightSmall)
    editBox:SetWidth(540)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        ReportFrame:Hide()
    end)
    scrollFrame:SetScrollChild(editBox)

    local footerText = ReportFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    footerText:SetPoint("BOTTOMRIGHT", ReportFrame, "BOTTOMRIGHT", -20, 18)
    footerText:SetText(GetFooterText())

    local function StripColorCodes(str)
        if not str then return "" end
        return str:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    end

    local function GenerateReport()
        local activeSession = GetActiveSession()
        local seg = (activeSession and activeSession.segments or {})[selectedSegmentIndex]
        if not seg then
            editBox:SetText("No Segment Selected")
            return
        end

        local isDiscord = chkDiscord:GetChecked()
        local lines = {}

        table.insert(lines, GetFooterText())
        local header = string.format("[%s %s] - %s (Full Segment Report)", seg.zone or GetCurrentZoneSafe(), seg.difficulty or GetRaidDifficultySuffix(), seg.name or "TRASH")
        table.insert(lines, isDiscord and ("# " .. header) or ("=== " .. header .. " ==="))
        table.insert(lines, "")

        -- 1. Collect All Characters Present in the Segment
        local presentMap = {}
        for pName, pClass in pairs(seg.players or {}) do
            presentMap[pName] = string.upper(pClass)
        end
        for pName in pairs(seg.potionsAndBuffs or {}) do
            if not presentMap[pName] then presentMap[pName] = string.upper(GetSafePlayerClass(pName)) end
        end
        for pName in pairs(seg.raidUtility or {}) do
            if not presentMap[pName] then presentMap[pName] = string.upper(GetSafePlayerClass(pName)) end
        end
        for pName in pairs(seg.deaths or {}) do
            if not presentMap[pName] then presentMap[pName] = string.upper(GetSafePlayerClass(pName)) end
        end

        local presentList = {}
        for pName in pairs(presentMap) do table.insert(presentList, pName) end
        table.sort(presentList)

        table.insert(lines, isDiscord and string.format("## 1. Characters Present (%d)", #presentList) or string.format("--- 1. Characters Present (%d) ---", #presentList))
        if #presentList == 0 then
            table.insert(lines, "  None")
        else
            for _, pName in ipairs(presentList) do
                local pClass = presentMap[pName] or "WARRIOR"
                table.insert(lines, isDiscord and string.format("  * **%s** (%s)", pName, pClass) or string.format("  - %s (%s)", pName, pClass))
            end
        end
        table.insert(lines, "")

        -- 2. Deaths & Detailed Death Log for the Segment
        local deathPlayers = {}
        local totalSegDeaths = 0
        for pName, dList in pairs(seg.deaths or {}) do
            if type(dList) == "table" and #dList > 0 then
                table.insert(deathPlayers, { name = pName, count = #dList, list = dList })
                totalSegDeaths = totalSegDeaths + #dList
            end
        end
        table.sort(deathPlayers, function(a, b)
            if a.count ~= b.count then return a.count > b.count end
            return a.name < b.name
        end)

        table.insert(lines, isDiscord and string.format("## 2. Deaths & Death Log (%d Total)", totalSegDeaths) or string.format("--- 2. Deaths & Death Log (%d Total) ---", totalSegDeaths))
        if #deathPlayers == 0 then
            table.insert(lines, "  None")
        else
            for _, dPlayer in ipairs(deathPlayers) do
                local pName = dPlayer.name
                local pClass = presentMap[pName] or string.upper(GetSafePlayerClass(pName))
                local deathWord = (dPlayer.count == 1) and "Death" or "Deaths"
                table.insert(lines, isDiscord and string.format("**%s (%s) - %d %s**", pName, pClass, dPlayer.count, deathWord) or string.format("%s (%s) - %d %s", pName, pClass, dPlayer.count, deathWord))

                for idx, d in ipairs(dPlayer.list) do
                    local killer = StripColorCodes(d.killer or "Unknown Mob")
                    local ability = StripColorCodes(d.ability or "Unknown Attack")
                    local amount = tonumber(d.amount) or 0
                    local overkill = tonumber(d.overkill) or 0
                    local timeStr = d.time or ""
                    local dmgText = (amount > 0) and string.format("%d dmg", amount) or "Fatal Effect"
                    if overkill > 0 then
                        dmgText = string.format("%d dmg (%d overkill)", amount, overkill)
                    end
                    local logEntry = string.format("[%s] Killed by %s | Ability: %s | Damage: %s", timeStr, killer, ability, dmgText)
                    table.insert(lines, isDiscord and string.format("  * %d. %s", idx, logEntry) or string.format("  - %d. %s", idx, logEntry))
                end
            end
        end
        table.insert(lines, "")

        -- 3. Potions & Buffs for the Segment
        table.insert(lines, isDiscord and "## 3. Potions & Buffs" or "--- 3. Potions & Buffs ---")
        local potPlayers = {}
        for pName, entries in pairs(seg.potionsAndBuffs or {}) do
            if next(entries) ~= nil then table.insert(potPlayers, pName) end
        end
        table.sort(potPlayers)

        if #potPlayers == 0 then
            table.insert(lines, "  None")
        else
            for _, pName in ipairs(potPlayers) do
                local pClass = presentMap[pName] or string.upper(seg.players[pName] or "WARRIOR")
                table.insert(lines, isDiscord and string.format("**%s (%s)**", pName, pClass) or string.format("%s (%s)", pName, pClass))

                local sortedEntries = {}
                for buffName, count in pairs(seg.potionsAndBuffs[pName]) do
                    table.insert(sortedEntries, { name = StripColorCodes(buffName), count = count })
                end
                table.sort(sortedEntries, function(a, b) return a.name < b.name end)

                for _, entry in ipairs(sortedEntries) do
                    table.insert(lines, isDiscord and string.format("  * %s: %d", entry.name, entry.count) or string.format("  - %s: %d", entry.name, entry.count))
                end
            end
        end
        table.insert(lines, "")

        -- 4. Raid Utility for the Segment
        table.insert(lines, isDiscord and "## 4. Raid Utility" or "--- 4. Raid Utility ---")
        local utilPlayers = {}
        for pName, entries in pairs(seg.raidUtility or {}) do
            if next(entries) ~= nil then table.insert(utilPlayers, pName) end
        end
        table.sort(utilPlayers)

        if #utilPlayers == 0 then
            table.insert(lines, "  None")
        else
            for _, pName in ipairs(utilPlayers) do
                local pClass = presentMap[pName] or string.upper(seg.players[pName] or "WARRIOR")
                table.insert(lines, isDiscord and string.format("**%s (%s)**", pName, pClass) or string.format("%s (%s)", pName, pClass))

                local sortedEntries = {}
                for utilName, count in pairs(seg.raidUtility[pName]) do
                    table.insert(sortedEntries, { name = StripColorCodes(utilName), count = count })
                end
                table.sort(sortedEntries, function(a, b) return a.name < b.name end)

                for _, entry in ipairs(sortedEntries) do
                    table.insert(lines, isDiscord and string.format("  * %s: %d", entry.name, entry.count) or string.format("  - %s: %d", entry.name, entry.count))
                end
            end
        end

        editBox:SetText(table.concat(lines, "\n"))
        if scrollFrame.UpdateScrollChildRect then
            scrollFrame:UpdateScrollChildRect()
        end
        scrollFrame:SetVerticalScroll(0)
        editBox:ClearFocus()
    end

    chkDiscord:SetScript("OnClick", GenerateReport)
    ReportFrame:SetScript("OnShow", GenerateReport)
end

-------------------------------------------------------------------------------
-- Config Panel Implementation (With Reset Panel Positions & Complete Wipe)
-------------------------------------------------------------------------------
local function CreateConfigFrame()
    ConfigFrame = CreateRUTPanel("RTConfigFrame", 420, 290, "Raiders Tracker Config")

    local viewBox = CreateWhiteBorderViewBox(ConfigFrame, -42, 46)

    local chkEnable = CreateFrame("CheckButton", nil, viewBox, "UICheckButtonTemplate")
    chkEnable:SetPoint("TOPLEFT", viewBox, "TOPLEFT", 16, -16)
    chkEnable.text = chkEnable:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    chkEnable.text:SetPoint("LEFT", chkEnable, "RIGHT", 6, 0)
    chkEnable.text:SetText("Enable Raiders Tracker Recording")
    chkEnable:SetChecked(RaidersTrackerDB.enabled)

    chkEnable:SetScript("OnClick", function(self)
        RaidersTrackerDB.enabled = self:GetChecked() and true or false
    end)

    local btnResetPositions = CreateFrame("Button", nil, viewBox, "UIPanelButtonTemplate")
    btnResetPositions:SetSize(200, 26)
    btnResetPositions:SetPoint("CENTER", viewBox, "CENTER", 0, -2)
    btnResetPositions:SetText("Reset Panel Positions")
    btnResetPositions:SetScript("OnClick", function()
        ResetAllPanelPositions()
    end)

    local btnDeleteAll = CreateFrame("Button", nil, viewBox, "UIPanelButtonTemplate")
    btnDeleteAll:SetSize(200, 26)
    btnDeleteAll:SetPoint("TOP", btnResetPositions, "BOTTOM", 0, -12)
    btnDeleteAll:SetText("Delete All Sessions")

    local btnBack = CreateFrame("Button", nil, ConfigFrame, "UIPanelButtonTemplate")
    btnBack:SetSize(130, 24)
    btnBack:SetPoint("BOTTOM", ConfigFrame, "BOTTOM", 0, 14)
    btnBack:SetText("Back to Tracker")
    btnBack:SetScript("OnClick", function() CloseAllPanels(); MainTrackerFrame:Show() end)

    StaticPopupDialogs["RT_DELETE_ALL_SESSIONS"] = {
        text = "Really delete all sessions (saved and live), recorded deaths, death logs, and character lists?",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            RaidersTrackerDB.savedSessions = {}
            selectedSessionIndex = 0
            selectedSegmentIndex = 1
            segmentPage = 1
            selectedDeathPlayer = nil
            ResetLiveSessionState()
            RefreshMainView()
            RefreshCharactersView()
            RefreshDeathsView()
            RefreshDeathLogView()
            AnnounceLocalChat("All sessions, deaths, and saved characters cleared.")
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

    btnDeleteAll:SetScript("OnClick", function()
        StaticPopup_Show("RT_DELETE_ALL_SESSIONS")
    end)
end

-------------------------------------------------------------------------------
-- Slash Commands, Load Message & New Character Session Prompt
-------------------------------------------------------------------------------
SLASH_RAIDERSTRACKER1 = "/rt"
SLASH_RAIDERSTRACKER2 = "/raiderstracker"
SlashCmdList["RAIDERSTRACKER"] = function(msg)
    local cmd = (msg or ""):lower():match("^%s*(.-)%s*$")
    if cmd == "reset" then
        ResetAllPanelPositions()
        return
    end
    if MainTrackerFrame then
        if MainTrackerFrame:IsShown() then
            MainTrackerFrame:Hide()
        else
            CloseAllPanels()
            MainTrackerFrame:Show()
        end
    end
end

local hasPrintedLoadMsg = false
local hasCheckedNewCharPrompt = false
local loadMsgTimer = CreateFrame("Frame")

local function CheckNewCharacterSessionPrompt()
    if hasCheckedNewCharPrompt then return end
    local currentPlayer = UnitName("player")
    if not currentPlayer or currentPlayer == UNKNOWN then return end

    hasCheckedNewCharPrompt = true
    local prevChar = RaidersTrackerDB.lastCharacter
    RaidersTrackerDB.lastCharacter = currentPlayer

    if prevChar and prevChar ~= currentPlayer and HasLiveSessionData() then
        StaticPopup_Show("RT_NEW_CHAR_SESSION_PROMPT", prevChar, currentPlayer)
    end
end

local function ScheduleLoadMessage(delay)
    local totalElapsed = 0
    loadMsgTimer:SetScript("OnUpdate", function(self, elapsed)
        totalElapsed = totalElapsed + elapsed
        if totalElapsed >= (delay or 2.0) then
            self:SetScript("OnUpdate", nil)
            if not hasPrintedLoadMsg then
                hasPrintedLoadMsg = true
                local version = GetAddonVersion()
                if DEFAULT_CHAT_FRAME then
                    DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00Raiders Tracker v" .. version .. " by " .. AUTHOR .. " loaded.|r")
                    DEFAULT_CHAT_FRAME:AddMessage("  - |cffFFFFFFLeft-Click Minimap Icon:|r Opens Main Tracker Panel.")
                    DEFAULT_CHAT_FRAME:AddMessage("  - |cffFFFFFFRight-Click Minimap Icon:|r Opens Config Panel.")
                    DEFAULT_CHAT_FRAME:AddMessage("  - Chat commands: |cff00FF00/rt|r or |cff00FF00/rt reset|r to reset panel positions.")
                end
            end
            CheckNewCharacterSessionPrompt()
        end
    end)
end

-------------------------------------------------------------------------------
-- Core Recording Engine (Potions/Buffs, Utility Casts & Player Deaths)
-------------------------------------------------------------------------------
local function RecordProc(sourceName, sourceGUID, destName, destGUID, category, spellID, rawSpellName, isInstantCast)
    if not currentSession.segments[1] or currentSession.segments[1].isBoss ~= inCombatState then
        EnsureTrashSegment()
    end

    local targetSegment = currentSession.segments[1]
    if not targetSegment then return end

    local srcIsMember = IsGroupMember(sourceName, sourceGUID)
    local dstIsMember = IsGroupMember(destName, destGUID)
    local srcClass = GetSafePlayerClass(sourceName, sourceGUID)
    local dstClass = GetSafePlayerClass(destName, destGUID)
    local addedNewSessionPlayer = false

    if category == "POTIONS" then
        local pName = nil
        local pClass = nil

        if isInstantCast then
            if not srcIsMember then return end
            pName = sourceName
            pClass = srcClass
        else
            if not dstIsMember then return end
            pName = destName
            pClass = dstClass
        end

        targetSegment.players[pName] = pClass
        currentSession.players = currentSession.players or {}
        if not currentSession.players[pName] then
            addedNewSessionPlayer = true
        end
        currentSession.players[pName] = pClass

        local baseBuffName = POTIONS_AND_BUFFS[spellID] or rawSpellName or ("Spell #" .. tostring(spellID))
        local entryName = baseBuffName
        local extraPlayer, extraClass = nil, nil

        if not isInstantCast and srcIsMember and sourceName ~= pName then
            targetSegment.players[sourceName] = srcClass
            if not currentSession.players[sourceName] then
                addedNewSessionPlayer = true
            end
            currentSession.players[sourceName] = srcClass
            extraPlayer, extraClass = sourceName, srcClass
            local coloredGiver = ColorizeText(sourceName, GetPlayerClassColor(srcClass))
            entryName = string.format("%s [%s]", baseBuffName, coloredGiver)
        end

        targetSegment.potionsAndBuffs[pName] = targetSegment.potionsAndBuffs[pName] or {}
        targetSegment.potionsAndBuffs[pName][entryName] = (targetSegment.potionsAndBuffs[pName][entryName] or 0) + 1

        if not inCombatState and not SNAPSHOT_PERSISTENT_BUFFS[spellID] then
            table.insert(recentPrePullEvents, {
                category = "POTIONS",
                pName = pName,
                pClass = pClass,
                extraPlayer = extraPlayer,
                extraClass = extraClass,
                entryName = entryName,
                ts = GetTime()
            })
        end

    elseif category == "UTILITY" then
        if not srcIsMember then return end

        local baseName = RAID_UTILITY[spellID] or rawSpellName or ("Spell #" .. tostring(spellID))

        local requiredClass = UTILITY_CLASS_FILTER[baseName]
        if requiredClass and srcClass ~= requiredClass then
            return
        end

        targetSegment.players[sourceName] = srcClass
        currentSession.players = currentSession.players or {}
        if not currentSession.players[sourceName] then
            addedNewSessionPlayer = true
        end
        currentSession.players[sourceName] = srcClass
        local entryName = baseName
        local extraPlayer, extraClass = nil, nil

        if dstIsMember and EXTERNAL_TARGETED_UTILITY[baseName] then
            targetSegment.players[destName] = dstClass
            if not currentSession.players[destName] then
                addedNewSessionPlayer = true
            end
            currentSession.players[destName] = dstClass
            extraPlayer, extraClass = destName, dstClass
            local coloredTarget = ColorizeText(destName, GetPlayerClassColor(dstClass))
            entryName = string.format("%s [%s]", baseName, coloredTarget)
        end

        targetSegment.raidUtility[sourceName] = targetSegment.raidUtility[sourceName] or {}
        targetSegment.raidUtility[sourceName][entryName] = (targetSegment.raidUtility[sourceName][entryName] or 0) + 1

        if not inCombatState then
            table.insert(recentPrePullEvents, {
                category = "UTILITY",
                pName = sourceName,
                pClass = srcClass,
                extraPlayer = extraPlayer,
                extraClass = extraClass,
                entryName = entryName,
                ts = GetTime()
            })
        end
    end

    if addedNewSessionPlayer and CharacterFrame and CharacterFrame:IsShown() then
        RefreshCharactersView()
    end

    RequestMainViewRefresh()
end

local function RecordPlayerDeath(destName, destGUID)
    if not IsGroupMember(destName, destGUID) then return end

    if UnitIsFeignDeath(destName) then return end

    local now = GetTime()
    if recentDeathLock[destName] and (now - recentDeathLock[destName]) < 4.0 then
        return
    end
    recentDeathLock[destName] = now

    if not currentSession.segments[1] or currentSession.segments[1].isBoss ~= inCombatState then
        EnsureTrashSegment()
    end

    local targetSegment = currentSession.segments[1]
    if not targetSegment then return end

    local dstClass = GetSafePlayerClass(destName, destGUID)
    targetSegment.players[destName] = dstClass
    currentSession.players = currentSession.players or {}
    currentSession.players[destName] = dstClass

    targetSegment.deaths = targetSegment.deaths or {}
    targetSegment.deaths[destName] = targetSegment.deaths[destName] or {}

    local lastHit = lastDamageTaken[destName]
    local killer = "Unknown / Mechanics"
    local ability = "Fatal Effect"
    local amount = 0
    local overkill = 0

    if lastHit and (now - (lastHit.timestamp or 0)) <= 10.0 then
        killer = lastHit.attacker or "Environment"
        ability = lastHit.ability or "Melee"
        amount = lastHit.amount or 0
        overkill = lastHit.overkill or 0
    end

    table.insert(targetSegment.deaths[destName], {
        time = date("%H:%M:%S"),
        segment = targetSegment.name or "TRASH",
        zone = targetSegment.zone or GetCurrentZoneSafe(),
        difficulty = targetSegment.difficulty or GetRaidDifficultySuffix(),
        killer = killer,
        ability = ability,
        amount = amount,
        overkill = overkill
    })

    if DeathsFrame and DeathsFrame:IsShown() then
        RefreshDeathsView()
    end
    if DeathLogFrame and DeathLogFrame:IsShown() then
        RefreshDeathLogView()
    end
    RequestMainViewRefresh()
end

-------------------------------------------------------------------------------
-- Event Dispatcher
-------------------------------------------------------------------------------
local eventHandler = CreateFrame("Frame")

eventHandler:RegisterEvent("ADDON_LOADED")
eventHandler:RegisterEvent("PLAYER_ENTERING_WORLD")
eventHandler:RegisterEvent("PARTY_MEMBERS_CHANGED")
eventHandler:RegisterEvent("RAID_ROSTER_UPDATE")
eventHandler:RegisterEvent("PLAYER_DIFFICULTY_CHANGED")
eventHandler:RegisterEvent("UPDATE_INSTANCE_INFO")
eventHandler:RegisterEvent("CHAT_MSG_SYSTEM")
eventHandler:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventHandler:RegisterEvent("ZONE_CHANGED")
eventHandler:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eventHandler:RegisterEvent("PLAYER_REGEN_DISABLED")
eventHandler:RegisterEvent("PLAYER_REGEN_ENABLED")
eventHandler:RegisterEvent("CHAT_MSG_MONSTER_YELL")
eventHandler:RegisterEvent("CHAT_MSG_MONSTER_EMOTE")
eventHandler:RegisterEvent("CHAT_MSG_RAID_BOSS_EMOTE")

eventHandler:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addon = ...
        if addon == "RaidersTracker" then
            InitializeDB()
            CreateMinimapButton()
            CreateMainTrackerFrame()
            CreateCharacterFrame()
            CreateReportFrame()
            CreateConfigFrame()
            CreateDeathsFrame()
            CreateDeathLogFrame()
            UpdateGroupCache()
            EnsureTrashSegment()
        end
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        UpdateGroupCache()
        HandleZoneOrDifficultyUpdate(false)
        if not hasPrintedLoadMsg then
            ScheduleLoadMessage(2.0)
        else
            CheckNewCharacterSessionPrompt()
        end
        return
    end

    if event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" then
        HandleZoneOrDifficultyUpdate(false)
        return
    end

    if event == "PLAYER_DIFFICULTY_CHANGED" or event == "UPDATE_INSTANCE_INFO" then
        UpdateGroupCache()
        HandleZoneOrDifficultyUpdate(true)
        return
    end

    if event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
        UpdateGroupCache()
        HandleZoneOrDifficultyUpdate(false)
        return
    end

    if event == "CHAT_MSG_SYSTEM" then
        local sysMsg = ...
        if sysMsg then
            if sysMsg:find("Reset") or sysMsg:find("reset") then
                table.wipe(defeatedBossLocks)
                table.wipe(bossEndCooldowns)
            end
            if sysMsg:find("Difficulty") or sysMsg:find("difficulty") or sysMsg:find("Player") or sysMsg:find("Heroic") or sysMsg:find("Normal") then
                HandleZoneOrDifficultyUpdate(true)
            end
        end
        return
    end

    if not RaidersTrackerDB.enabled then return end

    -- 1. Boss Speech Recognition Engine
    if event == "CHAT_MSG_MONSTER_YELL" or event == "CHAT_MSG_MONSTER_EMOTE" or event == "CHAT_MSG_RAID_BOSS_EMOTE" then
        local msg = ...
        msg = msg or ""

        if not inCombatState then
            for phrase, bossName in pairs(BOSS_ENGAGE_SPEECH) do
                if msg:find(phrase, 1, true) or msg:find(phrase) then
                    StartEncounter(nil, bossName, nil, true)
                    break
                end
            end
        else
            for phrase, bossName in pairs(BOSS_DEFEAT_SPEECH) do
                if (msg:find(phrase, 1, true) or msg:find(phrase)) and activeBossName == bossName then
                    EndEncounter(true, "Boss Defeat Speech Triggered")
                    break
                end
            end
        end
        return
    end

    -- 2. COMBAT_LOG_EVENT_UNFILTERED Processing
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subevent, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, arg9, arg10, arg11, arg12, arg13 = ...

        -- A. Track Incoming Damage to Raid Members for Detailed Death Logs
        if destName and IsGroupMember(destName, destGUID) then
            if subevent == "SWING_DAMAGE" then
                local amount, overkill = arg9, arg10
                lastDamageTaken[destName] = {
                    attacker = sourceName or "Unknown Mob",
                    ability = "Melee",
                    amount = amount or 0,
                    overkill = (overkill and overkill > 0) and overkill or 0,
                    timestamp = GetTime()
                }
            elseif subevent == "RANGE_DAMAGE" or subevent == "SPELL_DAMAGE" or subevent == "SPELL_PERIODIC_DAMAGE" or subevent == "DAMAGE_SHIELD" or subevent == "DAMAGE_SPLIT" then
                local spellName = arg10
                local amount, overkill = arg12, arg13
                lastDamageTaken[destName] = {
                    attacker = sourceName or "Unknown Mob",
                    ability = spellName or "Spell",
                    amount = amount or 0,
                    overkill = (overkill and overkill > 0) and overkill or 0,
                    timestamp = GetTime()
                }
            elseif subevent == "ENVIRONMENTAL_DAMAGE" then
                local envType = arg9
                local amount, overkill = arg10, arg11
                lastDamageTaken[destName] = {
                    attacker = "Environment",
                    ability = tostring(envType or "Environment"),
                    amount = amount or 0,
                    overkill = (overkill and overkill > 0) and overkill or 0,
                    timestamp = GetTime()
                }
            elseif subevent == "SPELL_INSTAKILL" then
                local spellName = arg10
                lastDamageTaken[destName] = {
                    attacker = sourceName or "Boss Mechanic",
                    ability = (spellName or "Instant Kill"),
                    amount = UnitHealthMax(destName) or 0,
                    overkill = 0,
                    timestamp = GetTime()
                }
            end
        end

        local spellID, spellName = arg9, arg10

        -- B. Secondary Boss Engage Detection (Includes Ruby Sanctum Mini-Bosses Baltharus, Saviana, Zarithrian)
        if not inCombatState and IsRaidInCombat() then
            local srcID = GetNPCIDFromGUID(sourceGUID)
            local dstID = GetNPCIDFromGUID(destGUID)

            if srcID and WOTLK_BOSS_DB[srcID] and not WOTLK_BOSS_DB[srcID].isAdd and not WOTLK_BOSS_DB[srcID].isPreboss and not WOTLK_BOSS_DB[srcID].isMini then
                if IsGroupMember(destName, destGUID) or subevent == "SPELL_CAST_START" or subevent == "SPELL_CAST_SUCCESS" then
                    StartEncounter(srcID, WOTLK_BOSS_DB[srcID].name, WOTLK_BOSS_DB[srcID], false)
                end
            elseif dstID and WOTLK_BOSS_DB[dstID] and not WOTLK_BOSS_DB[dstID].isAdd and not WOTLK_BOSS_DB[dstID].isPreboss and not WOTLK_BOSS_DB[dstID].isMini then
                local isDirectAttack = (subevent == "SWING_DAMAGE" or subevent == "SWING_MISSED" or subevent == "SPELL_DAMAGE" or subevent == "SPELL_PERIODIC_DAMAGE" or subevent == "RANGE_DAMAGE" or subevent == "SPELL_CAST_SUCCESS")
                if isDirectAttack and IsGroupMember(sourceName, sourceGUID) then
                    StartEncounter(dstID, WOTLK_BOSS_DB[dstID].name, WOTLK_BOSS_DB[dstID], false)
                end
            elseif spellID and WOTLK_BOSS_INITIATORS[spellID] then
                StartEncounter(nil, WOTLK_BOSS_INITIATORS[spellID], nil, false)
            end
        end

        -- C. UNIT_DIED Handling (Raid Member Death Log + Boss Victory Verification)
        if subevent == "UNIT_DIED" then
            if destName and IsGroupMember(destName, destGUID) then
                RecordPlayerDeath(destName, destGUID)
            end

            if inCombatState then
                local deadID = GetNPCIDFromGUID(destGUID)
                if deadID and WOTLK_BOSS_DB[deadID] and not WOTLK_BOSS_DB[deadID].isAdd then
                    local bInfo = activeBossName and BOSS_NAME_TO_INFO[activeBossName]
                    if bInfo and bInfo.isFactionChamp and WOTLK_BOSS_DB[deadID].isFactionChamp then
                        if destGUID then
                            defeatedGroupNPCs[destGUID] = true
                        else
                            defeatedGroupNPCs[deadID] = true
                        end
                        local killedCount = 0
                        for _ in pairs(defeatedGroupNPCs) do
                            killedCount = killedCount + 1
                        end
                        local diff = GetRaidDifficultySuffix()
                        local reqKills = (diff:find("25") ~= nil) and 10 or 6
                        if killedCount >= reqKills then
                            EndEncounter(true, "All Faction Champions Defeated")
                        end
                    elseif bInfo and bInfo.npcIDs[deadID] and not bInfo.scriptedFinish then
                        if bInfo.isGroup then
                            defeatedGroupNPCs[deadID] = true
                            local allDead = true
                            for reqID in pairs(bInfo.npcIDs) do
                                if not defeatedGroupNPCs[reqID] then
                                    allDead = false
                                    break
                                end
                            end
                            if allDead then
                                EndEncounter(true, "Boss Group Defeated")
                            end
                        else
                            EndEncounter(true, "Boss NPC Defeated")
                        end
                    elseif activeBossID and deadID == activeBossID and not (activeBossData and (activeBossData.scriptedFinish or activeBossData.isSubBoss)) then
                        EndEncounter(true, "Boss NPC Defeated")
                    end
                end
            end
            return
        end

        -- D. Buffs/Potions Received (View 1) & Raid Utility Used (View 2)
        if type(spellID) == "number" then
            local isAuraApplied = (subevent == "SPELL_AURA_APPLIED" and POTIONS_AND_BUFFS[spellID] ~= nil)
            local isAllowedRefresh = (subevent == "SPELL_AURA_REFRESH" and ALLOW_REFRESH_BUFFS[spellID] == true and POTIONS_AND_BUFFS[spellID] ~= nil)
            local isInstantPot = (subevent == "SPELL_CAST_SUCCESS" and INSTANT_CONSUMABLES[spellID] == true)

            if isAuraApplied or isAllowedRefresh then
                local buffKey = "B_" .. (destGUID or "") .. "_" .. tostring(spellID)
                local now = GetTime()
                local minICD = CUSTOM_BUFF_ICD[spellID] or (isAllowedRefresh and 8.0 or 1.5)
                if not recentProcs[buffKey] or (now - recentProcs[buffKey]) > minICD then
                    recentProcs[buffKey] = now
                    RecordProc(sourceName, sourceGUID, destName, destGUID, "POTIONS", spellID, spellName, false)
                end
            elseif isInstantPot then
                local potKey = "P_" .. (sourceGUID or "") .. "_" .. tostring(spellID)
                local now = GetTime()
                if not recentProcs[potKey] or (now - recentProcs[potKey]) > 1.5 then
                    recentProcs[potKey] = now
                    RecordProc(sourceName, sourceGUID, destName, destGUID, "POTIONS", spellID, spellName, true)
                end
            end

            local isUtilityCast = (subevent == "SPELL_CAST_SUCCESS" and RAID_UTILITY[spellID] ~= nil)
            if isUtilityCast then
                local utilKey = "U_" .. (sourceGUID or "") .. "_" .. (destGUID or "") .. "_" .. tostring(spellID)
                local now = GetTime()
                if not recentProcs[utilKey] or (now - recentProcs[utilKey]) > 0.5 then
                    recentProcs[utilKey] = now
                    RecordProc(sourceName, sourceGUID, destName, destGUID, "UTILITY", spellID, spellName, false)
                end
            end
        end
        return
    end

    -- 3. Combat State Transitions
    if event == "PLAYER_REGEN_DISABLED" then
        EnsureTrashSegment()
    elseif event == "PLAYER_REGEN_ENABLED" then
        table.wipe(recentProcs)
    end
end)
