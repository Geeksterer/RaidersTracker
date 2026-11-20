-- Raiders Tracker Addon (RT)
-- Created for World of Warcraft Legacy 3.3.5a
-- Refactored & Enhanced by Copper

local ADDON_NAME = "Raiders Tracker"
local AUTHOR = "Copper"
local GITHUB_URL = "https://github.com/Geeksterer/RaidersTracker/"

local RTExt = {}
RTExt.MIN_BOSS_PULL_DURATION = 35
RTExt.DEMONIC_PACT_BUFF_IDS = {
    [48090] = true, -- Demonic Pact (3.3.5a 45s raid buff)
    [53646] = true, -- Demonic Pact (alternate 3.3.5a raid buff ID)
}
RTExt.DEMONIC_PACT_PASSIVE_IDS = {
    [47236] = true, -- Demonic Pact Talent Rank 1
    [47237] = true, -- Demonic Pact Talent Rank 2
    [47238] = true, -- Demonic Pact Talent Rank 3
    [47239] = true, -- Demonic Pact Talent Rank 4
    [47240] = true, -- Demonic Pact Talent Rank 5
}
RTExt.DEMONIC_PACT_ICD = 18.0
RTExt.POTIONS_SUMMARY_EXTRA = {
    ["Flame Cap"] = true,
    ["Thistle Tea"] = true,
    ["Dark Rune"] = true,
    ["Demonic Rune"] = true,
}
RTExt.petGUIDToOwner = {}
RTExt.petUnitToOwner = {}
RTExt.petNameToOwner = {}
RTExt.playerGUIDToUnit = {}
RTExt.playerNameToUnit = {}
RTExt.recentDemonicPact = {}
RTExt.lastDemonicPactConfirmedAt = {}
RTExt.lastDemonicPactExpiry = {}
RTExt.pendingDemonicPacts = {}
RTExt.DEMONIC_PACT_ADDON_PREFIX = "RT_DP"
RTExt.OVERRIDDEN_SP_TOTEMS = {
    [57722] = 280, -- Totem of Wrath (Rank 4)
    [57721] = 140, -- Totem of Wrath (Rank 3)
    [57720] = 120, -- Totem of Wrath (Rank 2)
    [30708] = 100, -- Totem of Wrath (Rank 1)
    [58656] = 144, -- Flametongue Totem (Rank 8)
    [58652] = 122, -- Flametongue Totem (Rank 7)
    [58649] = 101, -- Flametongue Totem (Rank 6)
}
RTExt.lastPlayerSP = 0
RTExt.prevPlayerSP = 0
RTExt.prevPlayerSPTime = 0
RTExt.lastPlayerHasDP = false
RTExt.lastPlayerTotemSP = 0
RTExt.preDPTransitionSP = nil
RTExt.preDPTransitionTime = 0
RTExt.playerSelfDPContribution = 0
RTExt.activeObservedDP = 0
RTExt.spPollAccum = 0

local function GetAddonVersion()
    return GetAddOnMetadata("RaidersTracker", "Version") or ""
end

function RTExt.GetVersionTag()
    local ver = GetAddonVersion()
    if ver ~= "" then
        return " v" .. ver
    end
    return ""
end

local function GetFooterText()
    return ADDON_NAME .. RTExt.GetVersionTag() .. " by " .. AUTHOR
end

-------------------------------------------------------------------------------
-- Database & Default Configuration
-------------------------------------------------------------------------------
local defaultDB = {
    enabled = true,
    minimapPos = 45,
    savedSessions = {},
    liveSession = { name = "Live Current Session", segments = {}, players = {}, playerIDs = {}, zoneTimes = {} },
    blacklist = {} -- [charID] = { names = {["Name"] = true}, class = string, reason = string, timestamp = string }
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

local function MergeSegmentDataInto(targetSeg, sourceSeg)
    if not targetSeg or not sourceSeg then return end
    targetSeg.players = targetSeg.players or {}
    for pName, pClass in pairs(sourceSeg.players or {}) do
        targetSeg.players[pName] = pClass
    end
    targetSeg.playerIDs = targetSeg.playerIDs or {}
    for pName, cID in pairs(sourceSeg.playerIDs or {}) do
        targetSeg.playerIDs[pName] = cID
    end
    targetSeg.potionsAndBuffs = targetSeg.potionsAndBuffs or {}
    for pName, entries in pairs(sourceSeg.potionsAndBuffs or {}) do
        targetSeg.potionsAndBuffs[pName] = targetSeg.potionsAndBuffs[pName] or {}
        for bName, count in pairs(entries) do
            targetSeg.potionsAndBuffs[pName][bName] = (targetSeg.potionsAndBuffs[pName][bName] or 0) + count
        end
    end
    targetSeg.raidUtility = targetSeg.raidUtility or {}
    for pName, entries in pairs(sourceSeg.raidUtility or {}) do
        targetSeg.raidUtility[pName] = targetSeg.raidUtility[pName] or {}
        for uName, count in pairs(entries) do
            targetSeg.raidUtility[pName][uName] = (targetSeg.raidUtility[pName][uName] or 0) + count
        end
    end
    targetSeg.demonicPactValues = targetSeg.demonicPactValues or {}
    for pName, dpList in pairs(sourceSeg.demonicPactValues or {}) do
        if type(dpList) == "table" and #dpList > 0 then
            targetSeg.demonicPactValues[pName] = targetSeg.demonicPactValues[pName] or {}
            for _, spVal in ipairs(dpList) do
                table.insert(targetSeg.demonicPactValues[pName], spVal)
            end
        end
    end
    targetSeg.deaths = targetSeg.deaths or {}
    for pName, dList in pairs(sourceSeg.deaths or {}) do
        if type(dList) == "table" and #dList > 0 then
            targetSeg.deaths[pName] = targetSeg.deaths[pName] or {}
            for _, dEntry in ipairs(dList) do
                table.insert(targetSeg.deaths[pName], dEntry)
            end
        end
    end
    targetSeg.enrages = targetSeg.enrages or {}
    for mName, count in pairs(sourceSeg.enrages or {}) do
        targetSeg.enrages[mName] = (targetSeg.enrages[mName] or 0) + count
    end
    targetSeg.tanks = targetSeg.tanks or {}
    for tName, isTank in pairs(sourceSeg.tanks or {}) do
        if isTank then targetSeg.tanks[tName] = true end
    end
    if targetSeg.lkFuryDuration and targetSeg.lkFuryDuration > 0 then
        targetSeg.duration = targetSeg.lkFuryDuration
    elseif sourceSeg.lkFuryDuration and sourceSeg.lkFuryDuration > 0 then
        targetSeg.lkFuryDuration = sourceSeg.lkFuryDuration
        targetSeg.duration = sourceSeg.lkFuryDuration
    elseif sourceSeg.duration and sourceSeg.duration > 0 then
        targetSeg.duration = math.max(targetSeg.duration or 0, sourceSeg.duration)
    end
end

local function RepairSplitLichKingSegments(session)
    if not session or not session.segments or #session.segments < 2 then return end
    local segs = session.segments
    local i = 1
    while i < #segs do
        local s1, s2 = segs[i], segs[i + 1]
        if s1 and s2 and s1.bossName == "The Lich King" and s2.bossName == "The Lich King" then
            local s1IsVic = (s1.name and s1.name:find("Victory") ~= nil)
            local s2IsVic = (s2.name and s2.name:find("Victory") ~= nil)
            local s1IsWipe = (s1.name and s1.name:find("Wipe") ~= nil)
            local s2IsWipe = (s2.name and s2.name:find("Wipe") ~= nil)
            if s1IsWipe and s2IsVic then
                MergeSegmentDataInto(s2, s1)
                table.remove(segs, i)
            elseif s1IsVic and s2IsWipe then
                MergeSegmentDataInto(s1, s2)
                table.remove(segs, i + 1)
            else
                i = i + 1
            end
        else
            i = i + 1
        end
    end
end

local function InitializeDB()
    for k, v in pairs(defaultDB) do
        if RaidersTrackerDB[k] == nil then
            if k == "liveSession" then
                RaidersTrackerDB.liveSession = { name = "Live Current Session", segments = {}, players = {}, playerIDs = {}, zoneTimes = {} }
            elseif k == "blacklist" then
                RaidersTrackerDB.blacklist = {}
            else
                RaidersTrackerDB[k] = DeepCopyTable(v)
            end
        end
    end
    RaidersTrackerDB.blacklist = RaidersTrackerDB.blacklist or {}
    RaidersTrackerDB.lastCharacter = nil
    currentSession = RaidersTrackerDB.liveSession
    currentSession.players = currentSession.players or {}
    currentSession.playerIDs = currentSession.playerIDs or {}
    currentSession.zoneTimes = currentSession.zoneTimes or {}
    if #currentSession.segments > 0 then
        for _, seg in ipairs(currentSession.segments) do
            seg.deaths = seg.deaths or {}
            seg.players = seg.players or {}
            seg.playerIDs = seg.playerIDs or {}
            seg.potionsAndBuffs = seg.potionsAndBuffs or {}
            seg.raidUtility = seg.raidUtility or {}
            seg.demonicPactValues = seg.demonicPactValues or {}
            seg.enrages = seg.enrages or {}
            seg.tanks = seg.tanks or {}
            for pName, cID in pairs(seg.playerIDs) do
                currentSession.playerIDs[pName] = currentSession.playerIDs[pName] or cID
            end
        end
        RepairSplitLichKingSegments(currentSession)
        currentSegment = currentSession.segments[1]
    end
    for _, savedSess in ipairs(RaidersTrackerDB.savedSessions or {}) do
        savedSess.players = savedSess.players or {}
        savedSess.playerIDs = savedSess.playerIDs or {}
        savedSess.zoneTimes = savedSess.zoneTimes or {}
        for _, seg in ipairs(savedSess.segments or {}) do
            seg.deaths = seg.deaths or {}
            seg.players = seg.players or {}
            seg.playerIDs = seg.playerIDs or {}
            seg.potionsAndBuffs = seg.potionsAndBuffs or {}
            seg.raidUtility = seg.raidUtility or {}
            seg.demonicPactValues = seg.demonicPactValues or {}
            seg.enrages = seg.enrages or {}
            seg.tanks = seg.tanks or {}
            for pName, cID in pairs(seg.playerIDs) do
                savedSess.playerIDs[pName] = savedSess.playerIDs[pName] or cID
            end
        end
        RepairSplitLichKingSegments(savedSess)
    end
end

local function AnnounceLocalChat(msg)
    if msg and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00[Raiders Tracker]|r " .. msg)
    end
end

local function StripColorCodes(str)
    if not str then return "" end
    return str:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end

local function SanitizeForChat(str)
    if not str then return "" end
    local clean = StripColorCodes(tostring(str))
    clean = clean:gsub("|T.-|t", ""):gsub("%s*|%s*", " / "):gsub("[\r\n]", " ")
    return clean
end

-------------------------------------------------------------------------------
-- Anti-Spam Raid Chat Output Queue (~0.20s per line)
-------------------------------------------------------------------------------
local chatQueue = {}
local chatQueueFrame = CreateFrame("Frame")
local chatQueueElapsed = 0

local function SendSingleOutboundLine(line)
    if not line or line == "" then return end
    line = SanitizeForChat(line)
    if line == "" then return end
    if #line > 255 then line = line:sub(1, 255) end
    if GetNumRaidMembers() > 0 then
        SendChatMessage(line, "RAID")
    elseif GetNumPartyMembers() > 0 then
        SendChatMessage(line, "PARTY")
    elseif DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(line)
    end
end

local function OnChatQueueUpdate(self, elapsed)
    chatQueueElapsed = chatQueueElapsed + elapsed
    if chatQueueElapsed >= 0.20 then
        chatQueueElapsed = 0
        local nextLine = table.remove(chatQueue, 1)
        if nextLine then SendSingleOutboundLine(nextLine) end
        if #chatQueue == 0 then self:SetScript("OnUpdate", nil) end
    end
end

local function EnqueueRaidChatLines(rawLines)
    if not rawLines or #rawLines == 0 then return end
    for _, raw in ipairs(rawLines) do
        local clean = SanitizeForChat(raw):gsub("^%s+$", "")
        if clean ~= "" then
            while #clean > 255 do
                local splitPos = clean:sub(1, 250):match("^.*()%s") or 250
                if splitPos < 40 then splitPos = 250 end
                table.insert(chatQueue, clean:sub(1, splitPos))
                clean = clean:sub(splitPos + 1):gsub("^%s+", "")
            end
            if clean ~= "" then table.insert(chatQueue, clean) end
        end
    end
    if #chatQueue > 0 and not chatQueueFrame:GetScript("OnUpdate") then
        local firstLine = table.remove(chatQueue, 1)
        SendSingleOutboundLine(firstLine)
        if #chatQueue > 0 then
            chatQueueElapsed = 0
            chatQueueFrame:SetScript("OnUpdate", OnChatQueueUpdate)
        end
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

local function GetRaidDifficultySuffix()
    local inInstance, instanceType = IsInInstance()
    local _, instType, difficultyIndex, difficultyName, maxPlayers, dynamicDifficulty = GetInstanceInfo()
    local instDiff = GetInstanceDifficulty and GetInstanceDifficulty() or nil
    local raidDiff = GetRaidDifficulty and GetRaidDifficulty() or nil
    local dungDiff = GetDungeonDifficulty and GetDungeonDifficulty() or nil
    local diffText = difficultyName or ""

    if inInstance and (instType == "raid" or instanceType == "raid") then
        local is25 = (maxPlayers == 25) or (difficultyIndex == 2) or (difficultyIndex == 4)
            or (instDiff == 2) or (instDiff == 4) or (raidDiff == 2) or (raidDiff == 4)
            or (diffText:find("25") ~= nil)
        local isHeroic = (dynamicDifficulty == 1) or (difficultyIndex == 3) or (difficultyIndex == 4)
            or (instDiff == 3) or (instDiff == 4) or (raidDiff == 3) or (raidDiff == 4)
            or (diffText:find("Heroic") ~= nil)
        if is25 then return isHeroic and "25HC" or "25N" else return isHeroic and "10HC" or "10N" end
    elseif inInstance and (instType == "party" or instanceType == "party") then
        local isHeroicParty = (difficultyIndex == 2) or (instDiff == 2) or (dungDiff == 2) or (diffText:find("Heroic") ~= nil)
        return isHeroicParty and "5HC" or "5N"
    end

    local numRaid = GetNumRaidMembers()
    local numParty = GetNumPartyMembers()
    if numRaid == 0 and numParty > 0 then
        return (dungDiff == 2) and "5HC" or "5N"
    end
    if raidDiff == 4 then return "25HC"
    elseif raidDiff == 3 then return "10HC"
    elseif raidDiff == 2 then return "25N"
    else return "10N" end
end

local groupMembers = {}
local groupClasses = {}
local groupGUIDs = {}
local groupGUIDToName = {}
local nameToCharID = {}
local guidToCharID = {}
local charIDToName = {}

local function IsPlayerGUID(guid)
    if not guid or type(guid) ~= "string" then return true end
    if guid:sub(1, 3):upper() == "0XF" then return false end
    return true
end

local function ExtractCharacterID(guid)
    if not guid or type(guid) ~= "string" then return nil end
    if guid:find("^NAME:") then return nil end
    if guid:match("^%d+$") then return guid end
    if guid:sub(1, 3):upper() == "0XF" then return nil end
    local clean = guid:gsub("^0[xX]", "")
    if #clean >= 12 then
        local idHex = clean:sub(-8)
        local num = tonumber(idHex, 16)
        if num and num > 0 then return tostring(num) end
    end
    local numDec = tonumber(clean, 16)
    if numDec and numDec > 0 then return tostring(numDec) end
    return nil
end

local function CachePlayerCharID(name, guid, targetSegment)
    if not name or name == "" or name == UNKNOWN then return nil end
    if guid and not IsPlayerGUID(guid) then return nil end
    local charID = (guid and guidToCharID[guid]) or ExtractCharacterID(guid) or nameToCharID[name]
    if not charID then return nil end
    nameToCharID[name] = charID
    charIDToName[charID] = name
    groupGUIDs[charID] = name
    groupGUIDToName[charID] = name
    if guid and type(guid) == "string" and guid ~= charID then
        guidToCharID[guid] = charID
        groupGUIDs[guid] = name
        groupGUIDToName[guid] = name
    end
    if currentSession then
        currentSession.playerIDs = currentSession.playerIDs or {}
        currentSession.playerIDs[name] = charID
    end
    local seg = targetSegment or (currentSession and currentSession.segments and currentSession.segments[1])
    if seg then
        seg.playerIDs = seg.playerIDs or {}
        seg.playerIDs[name] = charID
    end
    return charID
end

local function UpdateGroupCache()
    table.wipe(groupMembers)
    table.wipe(groupGUIDs)
    table.wipe(groupGUIDToName)
    table.wipe(RTExt.petGUIDToOwner)
    table.wipe(RTExt.petUnitToOwner)
    table.wipe(RTExt.petNameToOwner)
    table.wipe(RTExt.playerGUIDToUnit)
    table.wipe(RTExt.playerNameToUnit)
    local function CacheUnit(unit, petUnit)
        local name = UnitName(unit)
        if name and name ~= UNKNOWN then
            groupMembers[name] = true
            RTExt.playerNameToUnit[name] = unit
            local uGUID = UnitGUID(unit)
            if uGUID then
                RTExt.playerGUIDToUnit[uGUID] = unit
                CachePlayerCharID(name, uGUID)
            elseif nameToCharID[name] then
                local cID = nameToCharID[name]
                charIDToName[cID] = name
                groupGUIDs[cID] = name
                groupGUIDToName[cID] = name
            end
            local _, engClass = UnitClass(unit)
            if engClass then groupClasses[name] = engClass end
            if petUnit and UnitExists(petUnit) then
                local petGUID = UnitGUID(petUnit)
                local petName = UnitName(petUnit)
                local ownerInfo = {
                    name = name,
                    guid = uGUID,
                    class = engClass or groupClasses[name],
                    unit = unit,
                    petUnit = petUnit,
                }
                RTExt.petUnitToOwner[petUnit] = ownerInfo
                if petGUID then
                    RTExt.petGUIDToOwner[petGUID] = ownerInfo
                end
                if petName and petName ~= UNKNOWN then
                    if RTExt.petNameToOwner[petName] == nil then
                        RTExt.petNameToOwner[petName] = ownerInfo
                    elseif RTExt.petNameToOwner[petName] ~= false and RTExt.petNameToOwner[petName].name ~= ownerInfo.name then
                        RTExt.petNameToOwner[petName] = false
                    end
                end
            end
        end
    end
    CacheUnit("player", "pet")
    local numRaid = GetNumRaidMembers()
    if numRaid > 0 then
        for i = 1, numRaid do CacheUnit("raid" .. i, "raidpet" .. i) end
    else
        local numParty = GetNumPartyMembers()
        for i = 1, numParty do CacheUnit("party" .. i, "partypet" .. i) end
    end
end

local function IsGroupMember(name, guid)
    if not name or not IsPlayerGUID(guid) then return false end
    if groupMembers[name] then
        if guid then CachePlayerCharID(name, guid) end
        return true
    end
    local charID = ExtractCharacterID(guid)
    if charID and (groupGUIDs[charID] or charIDToName[charID]) then
        groupMembers[name] = true
        CachePlayerCharID(name, guid)
        return true
    end
    if guid and groupGUIDs[guid] then
        groupMembers[name] = true
        CachePlayerCharID(name, guid)
        return true
    end
    if UnitInRaid(name) or UnitInParty(name) or name == UnitName("player") then
        UpdateGroupCache()
        if groupMembers[name] and guid then CachePlayerCharID(name, guid) end
        return groupMembers[name] == true
    end
    return false
end

local function GetSafePlayerClass(unitName, guid)
    if unitName and groupClasses[unitName] then return groupClasses[unitName] end
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
            if UnitExists(unit) and not UnitIsDeadOrGhost(unit) and UnitAffectingCombat(unit) then return true end
        end
    else
        if not UnitIsDeadOrGhost("player") and UnitAffectingCombat("player") then return true end
        local numParty = GetNumPartyMembers()
        for i = 1, numParty do
            local unit = "party" .. i
            if UnitExists(unit) and not UnitIsDeadOrGhost(unit) and UnitAffectingCombat(unit) then return true end
        end
    end
    return false
end

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
    ["WARRIOR"] = "C79C6E", ["PALADIN"] = "F58CBA", ["HUNTER"] = "ABD473",
    ["ROGUE"] = "FFF569", ["PRIEST"] = "FFFFFF", ["DEATHKNIGHT"] = "C41F3B",
    ["SHAMAN"] = "0070DE", ["MAGE"] = "69CCF0", ["WARLOCK"] = "9482C9", ["DRUID"] = "FF7D0A",
}

local function ColorizeText(text, hexColor)
    return string.format("|cff%s%s|r", hexColor or "FFFFFF", text or "")
end

local function GetPlayerClassColor(className)
    if not className then return "FFFFFF" end
    return CLASS_COLORS[string.upper(className)] or "FFFFFF"
end

-------------------------------------------------------------------------------
-- Blacklist & Character ID History Engine
-------------------------------------------------------------------------------
local sessionWarnedIDs = {}

local function CheckGroupBlacklist()
    if not RaidersTrackerDB or not RaidersTrackerDB.blacklist then return end
    UpdateGroupCache()
    for idKey, name in pairs(groupGUIDToName) do
        local blKey = RaidersTrackerDB.blacklist[idKey] and idKey or (name and RaidersTrackerDB.blacklist["NAME:" .. name] and ("NAME:" .. name)) or nil
        if blKey then
            local entry = RaidersTrackerDB.blacklist[blKey]
            local charID = ExtractCharacterID(idKey) or nameToCharID[name]
            if charID and blKey ~= charID then
                RaidersTrackerDB.blacklist[charID] = RaidersTrackerDB.blacklist[charID] or entry
                if RaidersTrackerDB.blacklist[charID] ~= entry then
                    RaidersTrackerDB.blacklist[charID].names = RaidersTrackerDB.blacklist[charID].names or {}
                    for n in pairs(entry.names or {}) do RaidersTrackerDB.blacklist[charID].names[n] = true end
                end
                RaidersTrackerDB.blacklist[blKey] = nil
                entry = RaidersTrackerDB.blacklist[charID]
                blKey = charID
            end
            if name and name ~= "" then
                entry.names = entry.names or {}
                entry.names[name] = true
            end
            if not sessionWarnedIDs[blKey] then
                sessionWarnedIDs[blKey] = true
                local nameList = {}
                for n in pairs(entry.names or {}) do table.insert(nameList, n) end
                table.sort(nameList)
                local namesStr = table.concat(nameList, ", ")
                local classStr = entry.class and (" (" .. entry.class .. ")") or ""
                local warnMsg = string.format("[Raiders Tracker] WARNING: Blacklisted player joined group! [ID: %s] Names: %s%s - Reason: %s", blKey, namesStr, classStr, entry.reason or "Unknown")
                if DEFAULT_CHAT_FRAME then
                    DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00" .. warnMsg .. "|r")
                end
            end
        end
    end
end


-------------------------------------------------------------------------------
-- Blacklist Base64 / Secure XML Import & Export Engine
-------------------------------------------------------------------------------
RTExt.BASE64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
RTExt.BASE64_DECODE_MAP = {}
for i = 1, #RTExt.BASE64_CHARS do
    RTExt.BASE64_DECODE_MAP[RTExt.BASE64_CHARS:sub(i, i)] = i - 1
end

RTExt.VALID_BLACKLIST_CLASSES = {
    ["WARRIOR"] = true, ["PALADIN"] = true, ["HUNTER"] = true,
    ["ROGUE"] = true, ["PRIEST"] = true, ["DEATHKNIGHT"] = true,
    ["SHAMAN"] = true, ["MAGE"] = true, ["WARLOCK"] = true,
    ["DRUID"] = true, ["UNKNOWN"] = true,
}

RTExt.MAX_IMPORT_B64_LEN = 262144
RTExt.MAX_IMPORT_ENTRIES = 2000
RTExt.MAX_IMPORT_NAMES_PER_ENTRY = 50

function RTExt.Base64Encode(data)
    if type(data) ~= "string" then return "" end
    local chars = RTExt.BASE64_CHARS
    local out = {}
    local len = #data
    local i = 1
    while i <= len do
        local b1 = string.byte(data, i) or 0
        local b2 = string.byte(data, i + 1)
        local b3 = string.byte(data, i + 2)

        local n1 = math.floor(b1 / 4)
        local n2 = (b1 % 4) * 16 + math.floor((b2 or 0) / 16)
        local n3 = ((b2 or 0) % 16) * 4 + math.floor((b3 or 0) / 64)
        local n4 = (b3 or 0) % 64

        out[#out + 1] = chars:sub(n1 + 1, n1 + 1)
        out[#out + 1] = chars:sub(n2 + 1, n2 + 1)
        if b2 then
            out[#out + 1] = chars:sub(n3 + 1, n3 + 1)
        else
            out[#out + 1] = "="
        end
        if b3 then
            out[#out + 1] = chars:sub(n4 + 1, n4 + 1)
        else
            out[#out + 1] = "="
        end
        i = i + 3
    end
    return table.concat(out)
end

function RTExt.Base64DecodeStrict(raw)
    if type(raw) ~= "string" then
        return nil, "Import data is missing or not text."
    end
    local clean = raw:gsub("[%s]", "")
    local len = #clean
    if len == 0 then
        return nil, "Import data is empty."
    end
    if len > RTExt.MAX_IMPORT_B64_LEN then
        return nil, "Import data exceeds maximum allowed size."
    end
    if (len % 4) ~= 0 then
        return nil, "Corrupt Base64 data (invalid length)."
    end

    local dmap = RTExt.BASE64_DECODE_MAP
    local out = {}
    local i = 1
    while i <= len do
        local c1 = clean:sub(i, i)
        local c2 = clean:sub(i + 1, i + 1)
        local c3 = clean:sub(i + 2, i + 2)
        local c4 = clean:sub(i + 3, i + 3)

        local v1 = dmap[c1]
        local v2 = dmap[c2]
        if not v1 or not v2 then
            return nil, "Corrupt Base64 data (invalid character detected)."
        end

        local pad3 = (c3 == "=")
        local pad4 = (c4 == "=")

        if pad3 and not pad4 then
            return nil, "Corrupt Base64 data (invalid padding)."
        end
        if (pad3 or pad4) and (i + 3 < len) then
            return nil, "Corrupt Base64 data (unexpected padding before end)."
        end

        local v3 = pad3 and 0 or dmap[c3]
        local v4 = pad4 and 0 or dmap[c4]
        if not v3 or not v4 then
            return nil, "Corrupt Base64 data (invalid character detected)."
        end

        if pad3 and (v2 % 16) ~= 0 then
            return nil, "Corrupt Base64 data (invalid trailing bits)."
        end
        if pad4 and not pad3 and (v3 % 4) ~= 0 then
            return nil, "Corrupt Base64 data (invalid trailing bits)."
        end

        local b1 = v1 * 4 + math.floor(v2 / 16)
        local b2 = (v2 % 16) * 16 + math.floor(v3 / 4)
        local b3 = (v3 % 4) * 64 + v4

        out[#out + 1] = string.char(b1)
        if not pad3 then
            out[#out + 1] = string.char(b2)
        end
        if not pad4 then
            out[#out + 1] = string.char(b3)
        end
        i = i + 4
    end

    local decoded = table.concat(out)
    if decoded:find("[%z\1-\8\11\12\14-\31\127]") then
        return nil, "Corrupt data (illegal binary or control characters detected)."
    end
    return decoded, nil
end

function RTExt.SanitizeForXMLField(str)
    if str == nil then return "" end
    local s = StripColorCodes(tostring(str))
    s = s:gsub("|T.-|t", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("|", "")
    s = s:gsub("[<>\\`]", " ")
    s = s:gsub("[%z\1-\31\127]", " ")
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    return s
end

function RTExt.EscapeXML(str)
    local s = RTExt.SanitizeForXMLField(str)
    s = s:gsub("&", "&amp;")
    s = s:gsub("<", "&lt;")
    s = s:gsub(">", "&gt;")
    s = s:gsub('"', "&quot;")
    s = s:gsub("'", "&apos;")
    return s
end

function RTExt.UnescapeXMLStrict(str)
    if type(str) ~= "string" then return nil end
    if str:find("[|<>%z\1-\31\127]") then
        return nil
    end
    local pos = 1
    while true do
        local ampPos = str:find("&", pos, true)
        if not ampPos then break end
        local entity = str:match("^(&[a-zA-Z]+;)", ampPos)
        if entity ~= "&amp;" and entity ~= "&lt;" and entity ~= "&gt;" and entity ~= "&quot;" and entity ~= "&apos;" then
            return nil
        end
        pos = ampPos + #entity
    end
    local out = str
    out = out:gsub("&lt;", "<")
    out = out:gsub("&gt;", ">")
    out = out:gsub("&quot;", '"')
    out = out:gsub("&apos;", "'")
    out = out:gsub("&amp;", "&")
    if out:find("[|%z\1-\31\127]") then
        return nil
    end
    return out
end

function RTExt.IsValidBlacklistCharName(name)
    if type(name) ~= "string" then return false end
    if #name < 2 or #name > 36 then return false end
    if name:find("[|%s<>\"'\\&;%z\1-\31\127]") then return false end
    if not name:match("^[%a\128-\244]+$") then return false end
    return true
end

function RTExt.IsValidBlacklistCharID(id)
    if type(id) ~= "string" or #id == 0 or #id > 44 then return false end
    if id:find("[|%s<>\"'\\&;%z\1-\31\127]") then return false end
    if id:match("^%d+$") then
        return (#id <= 20)
    end
    local fallbackName = id:match("^NAME:(.+)$")
    if fallbackName and RTExt.IsValidBlacklistCharName(fallbackName) then
        return true
    end
    return false
end

function RTExt.IsValidBlacklistReason(reason)
    if type(reason) ~= "string" or #reason == 0 or #reason > 80 then return false end
    if reason:find("[|<>\\`%z\1-\31\127]") then return false end
    return true
end

function RTExt.IsValidBlacklistTimestamp(ts)
    if type(ts) ~= "string" then return false end
    if ts == "" then return true end
    if ts:match("^%d%d%d%d%-%d%d%-%d%d %d%d:%d%d$") then return true end
    if ts:match("^%d%d%d%d%-%d%d%-%d%d$") then return true end
    return false
end

function RTExt.CollectSortedBlacklistItems()
    RaidersTrackerDB.blacklist = RaidersTrackerDB.blacklist or {}
    local list = {}
    for charID, info in pairs(RaidersTrackerDB.blacklist) do
        local nameList = {}
        local seenLower = {}
        if type(info.names) == "table" then
            for n in pairs(info.names) do
                if type(n) == "string" and n ~= "" and not seenLower[n:lower()] then
                    seenLower[n:lower()] = true
                    table.insert(nameList, n)
                end
            end
        elseif type(info.name) == "string" and info.name ~= "" then
            table.insert(nameList, info.name)
        end
        table.sort(nameList)
        local namesStr = (#nameList > 0) and table.concat(nameList, ", ") or "Unknown"
        local rawClass = info.class and string.upper(tostring(info.class)) or "UNKNOWN"
        if not RTExt.VALID_BLACKLIST_CLASSES[rawClass] then rawClass = "UNKNOWN" end
        table.insert(list, {
            id = tostring(charID),
            names = nameList,
            namesStr = namesStr,
            class = rawClass,
            classStr = (rawClass ~= "UNKNOWN") and (" (" .. rawClass .. ")") or "",
            reason = RTExt.SanitizeForXMLField(info.reason or "Unspecified"),
            date = RTExt.SanitizeForXMLField(info.timestamp or "")
        })
    end
    table.sort(list, function(a, b)
        if a.namesStr ~= b.namesStr then return a.namesStr < b.namesStr end
        return a.id < b.id
    end)
    return list
end

function RTExt.ExportBlacklistToBase64XML()
    local items = RTExt.CollectSortedBlacklistItems()
    local xmlLines = {
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<RaidersTrackerBlacklist schema="1">'
    }
    local exportedCount = 0
    for _, item in ipairs(items) do
        local cleanID = RTExt.SanitizeForXMLField(item.id)
        local cleanReason = (item.reason ~= "") and item.reason or "Unspecified"
        if #cleanReason > 80 then cleanReason = cleanReason:sub(1, 80) end
        local cleanDate = RTExt.IsValidBlacklistTimestamp(item.date) and item.date or ""
        local validNames = {}
        for _, n in ipairs(item.names) do
            local cn = RTExt.SanitizeForXMLField(n)
            if RTExt.IsValidBlacklistCharName(cn) then
                table.insert(validNames, cn)
            end
        end
        if RTExt.IsValidBlacklistCharID(cleanID) and #validNames > 0 then
            table.insert(xmlLines, string.format(
                '  <Entry id="%s" class="%s" reason="%s" timestamp="%s">',
                RTExt.EscapeXML(cleanID),
                RTExt.EscapeXML(item.class),
                RTExt.EscapeXML(cleanReason),
                RTExt.EscapeXML(cleanDate)
            ))
            for _, n in ipairs(validNames) do
                table.insert(xmlLines, string.format('    <Name>%s</Name>', RTExt.EscapeXML(n)))
            end
            table.insert(xmlLines, '  </Entry>')
            exportedCount = exportedCount + 1
        end
    end
    table.insert(xmlLines, '</RaidersTrackerBlacklist>')
    local xmlStr = table.concat(xmlLines, "\n")
    return RTExt.Base64Encode(xmlStr), exportedCount
end

function RTExt.BuildBlacklistPlainText()
    local items = RTExt.CollectSortedBlacklistItems()
    local lines = {
        string.format("=== Raiders Tracker%s by %s - Player Blacklist ===", RTExt.GetVersionTag(), AUTHOR),
        string.format("Total Blacklisted: %d", #items),
        ""
    }
    if #items == 0 then
        table.insert(lines, "No players currently blacklisted.")
    else
        for idx, item in ipairs(items) do
            local dateSuffix = (item.date ~= "") and (" (" .. item.date .. ")") or ""
            table.insert(lines, string.format(
                "%d. [ID: %s] Names: %s%s - Reason: %s%s",
                idx, item.id, item.namesStr, item.classStr, item.reason, dateSuffix
            ))
        end
    end
    return table.concat(lines, "\n")
end

function RTExt.ParseStrictXMLAttributes(attrText)
    local attrs = {}
    local allowed = { id = true, class = true, reason = true, timestamp = true }
    local pos = 1
    local len = #attrText
    while pos <= len do
        local _, wsEnd = attrText:find("^%s*", pos)
        pos = (wsEnd or (pos - 1)) + 1
        if pos > len then break end

        local sPos, ePos, key, val = attrText:find('^([a-zA-Z]+)="([^"]*)"', pos)
        if not sPos or not allowed[key] or attrs[key] ~= nil then
            return nil
        end
        local unescaped = RTExt.UnescapeXMLStrict(val)
        if unescaped == nil then
            return nil
        end
        attrs[key] = unescaped
        pos = ePos + 1
        if pos <= len and not attrText:sub(pos, pos):match("%s") then
            return nil
        end
    end
    return attrs
end

function RTExt.ParseAndValidateBlacklistImport(rawBase64)
    local xmlStr, b64Err = RTExt.Base64DecodeStrict(rawBase64)
    if not xmlStr then
        return nil, b64Err
    end

    if xmlStr:find("|", 1, true) then
        return nil, "Invalid data: illegal escape character detected."
    end
    local upperXML = xmlStr:upper()
    if upperXML:find("<!DOCTYPE", 1, true) or upperXML:find("<!ENTITY", 1, true)
        or upperXML:find("<![CDATA[", 1, true) or xmlStr:find("<!--", 1, true) then
        return nil, "Invalid data: forbidden XML construct detected."
    end

    local body = xmlStr:gsub("^%s+", ""):gsub("%s+$", "")
    if body:sub(1, 5) == "<?xml" then
        local _, headerEnd = body:find('^<%?xml version="1%.0" encoding="UTF%-8"%?>[%s]*')
        if not headerEnd then
            return nil, "Invalid XML header: not from Raiders Tracker."
        end
        body = body:sub(headerEnd + 1)
    end
    if body:find("<?", 1, true) then
        return nil, "Invalid data: unexpected XML processing instruction."
    end

    local openStart, openEnd = body:find('^<RaidersTrackerBlacklist%s+schema="1">')
    local closeStart, closeEnd = body:find('</RaidersTrackerBlacklist>$')
    if not openStart or not closeStart or closeEnd ~= #body or openEnd >= closeStart then
        return nil, "Invalid data: not a valid Raiders Tracker blacklist export."
    end

    local innerRoot = body:sub(openEnd + 1, closeStart - 1)
    local entries = {}
    local pos = 1
    local rootLen = #innerRoot

    while pos <= rootLen do
        local _, wsEnd = innerRoot:find("^%s*", pos)
        pos = (wsEnd or (pos - 1)) + 1
        if pos > rootLen then break end

        local tagStart, tagEnd, attrText = innerRoot:find("^<Entry%s+([^<>]+)>", pos)
        if not tagStart then
            return nil, "Invalid XML structure: unexpected tag or text inside blacklist."
        end
        local entryCloseStart, entryCloseEnd = innerRoot:find("</Entry>", tagEnd + 1, true)
        if not entryCloseStart then
            return nil, "Invalid XML structure: unclosed Entry tag."
        end

        local attrs = RTExt.ParseStrictXMLAttributes(attrText)
        if not attrs or not attrs.id or not attrs.class or not attrs.reason or attrs.timestamp == nil then
            return nil, "Invalid Entry attributes: corrupt or unsupported blacklist data."
        end

        local normClass = string.upper(attrs.class)
        if not RTExt.IsValidBlacklistCharID(attrs.id) then
            return nil, "Invalid character ID found in import data."
        end
        if not RTExt.VALID_BLACKLIST_CLASSES[normClass] then
            return nil, "Invalid character class found in import data."
        end
        if not RTExt.IsValidBlacklistReason(attrs.reason) then
            return nil, "Invalid or unsafe reason text found in import data."
        end
        if not RTExt.IsValidBlacklistTimestamp(attrs.timestamp) then
            return nil, "Invalid timestamp format found in import data."
        end

        local entryInner = innerRoot:sub(tagEnd + 1, entryCloseStart - 1)
        local nPos = 1
        local nLen = #entryInner
        local parsedNames = {}
        local seenInEntry = {}

        while nPos <= nLen do
            local _, nWsEnd = entryInner:find("^%s*", nPos)
            nPos = (nWsEnd or (nPos - 1)) + 1
            if nPos > nLen then break end

            local ns, ne, rawName = entryInner:find("^<Name>([^<>]+)</Name>", nPos)
            if not ns then
                return nil, "Invalid XML structure: expected valid Name element inside Entry."
            end
            local cleanName = RTExt.UnescapeXMLStrict(rawName)
            if not cleanName or not RTExt.IsValidBlacklistCharName(cleanName) then
                return nil, "Invalid or unsafe character name found in import data."
            end
            if not seenInEntry[cleanName:lower()] then
                seenInEntry[cleanName:lower()] = true
                table.insert(parsedNames, cleanName)
                if #parsedNames > RTExt.MAX_IMPORT_NAMES_PER_ENTRY then
                    return nil, "Import data exceeds maximum names allowed per entry."
                end
            end
            nPos = ne + 1
        end

        if #parsedNames == 0 then
            return nil, "Invalid Entry: missing character name."
        end

        table.insert(entries, {
            id = attrs.id,
            class = normClass,
            reason = attrs.reason,
            timestamp = (attrs.timestamp ~= "") and attrs.timestamp or date("%Y-%m-%d %H:%M"),
            names = parsedNames
        })
        if #entries > RTExt.MAX_IMPORT_ENTRIES then
            return nil, "Import data exceeds maximum allowed entries."
        end

        pos = entryCloseEnd + 1
    end

    return entries, nil
end

function RTExt.ProcessBlacklistImport(entries, dryRun)
    RaidersTrackerDB.blacklist = RaidersTrackerDB.blacklist or {}
    local targetBL = dryRun and DeepCopyTable(RaidersTrackerDB.blacklist) or RaidersTrackerDB.blacklist

    local function FindKeyByLowerName(lowerName)
        for existingID, existingInfo in pairs(targetBL) do
            if type(existingInfo.names) == "table" then
                for n in pairs(existingInfo.names) do
                    if type(n) == "string" and n:lower() == lowerName then
                        return existingID
                    end
                end
            elseif type(existingInfo.name) == "string" and existingInfo.name:lower() == lowerName then
                return existingID
            end
        end
        return nil
    end

    local function EntryHasLowerName(existingInfo, lowerName)
        if type(existingInfo.names) == "table" then
            for n in pairs(existingInfo.names) do
                if type(n) == "string" and n:lower() == lowerName then
                    return true
                end
            end
        end
        if type(existingInfo.name) == "string" and existingInfo.name:lower() == lowerName then
            return true
        end
        return false
    end

    local importedCount = 0
    local duplicateCount = 0
    local newNamesAddedCount = 0

    for _, imp in ipairs(entries) do
        local impID = imp.id
        local existingKey = nil

        if targetBL[impID] then
            existingKey = impID
        else
            for _, impName in ipairs(imp.names) do
                local matchedKey = FindKeyByLowerName(impName:lower())
                if matchedKey then
                    existingKey = matchedKey
                    break
                end
            end
        end

        if existingKey then
            local existing = targetBL[existingKey]
            if existingKey:find("^NAME:") and impID:match("^%d+$") and not targetBL[impID] then
                targetBL[impID] = existing
                targetBL[existingKey] = nil
                existingKey = impID
            end

            existing.names = existing.names or {}
            if type(existing.name) == "string" and existing.name ~= "" then
                existing.names[existing.name] = true
                existing.name = nil
            end

            for _, impName in ipairs(imp.names) do
                if not EntryHasLowerName(existing, impName:lower()) then
                    existing.names[impName] = true
                    newNamesAddedCount = newNamesAddedCount + 1
                end
            end
            if (not existing.class or existing.class == "" or existing.class == "UNKNOWN") and imp.class ~= "UNKNOWN" then
                existing.class = imp.class
            end
            duplicateCount = duplicateCount + 1
        else
            local namesMap = {}
            for _, impName in ipairs(imp.names) do
                namesMap[impName] = true
            end
            targetBL[impID] = {
                names = namesMap,
                class = (imp.class ~= "UNKNOWN") and imp.class or nil,
                reason = imp.reason,
                timestamp = imp.timestamp
            }
            importedCount = importedCount + 1
        end
    end

    return importedCount, duplicateCount, newNamesAddedCount
end

-------------------------------------------------------------------------------
-- Comprehensive WotLK Raid Boss Database & Speech Recognition Tables
-------------------------------------------------------------------------------
local WOTLK_BOSS_DB = {
    [31125] = { name = "Archavon the Stone Watcher" },
    [33993] = { name = "Emalon the Storm Watcher" },
    [35013] = { name = "Koralon the Flame Watcher" },
    [38433] = { name = "Toravon the Ice Watcher" },
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
    [28859] = { name = "Malygos", scriptedFinish = true },
    [28860] = { name = "Sartharion" },
    [30452] = { name = "Sartharion", isMini = true },
    [30451] = { name = "Sartharion", isMini = true },
    [30449] = { name = "Sartharion", isMini = true },
    [10184] = { name = "Onyxia" },
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
    [34796] = { name = "Northrend Beasts", isSubBoss = true },
    [34799] = { name = "Northrend Beasts", isSubBoss = true },
    [35144] = { name = "Northrend Beasts", isSubBoss = true },
    [34797] = { name = "Northrend Beasts" },
    [34780] = { name = "Lord Jaraxxus" },
    [34497] = { name = "Twin Val'kyr", isGroup = true },
    [34496] = { name = "Twin Val'kyr", isGroup = true },
    [34564] = { name = "Anub'arak" },
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
    [36597] = { name = "The Lich King" },
    [36609] = { name = "The Lich King", isAdd = true },
    [36701] = { name = "The Lich King", isAdd = true },
    [39751] = { name = "Baltharus the Warborn" },
    [39899] = { name = "Baltharus the Warborn", isAdd = true },
    [39747] = { name = "Saviana Ragefire" },
    [39746] = { name = "General Zarithrian" },
    [39863] = { name = "Halion" },
    [40142] = { name = "Halion", isPhase = true }
}

local FACTION_CHAMPION_NPC_IDS = {
    34441, 34444, 34445, 34447, 34448, 34449, 34450, 34451, 34453, 34454,
    34455, 34456, 34458, 34459, 34460, 34461, 34463, 34465, 34466, 34467,
    34468, 34469, 34470, 34471, 34472, 34473, 34474, 34475
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
        if data.isFactionChamp then BOSS_NAME_TO_INFO[data.name].isFactionChamp = true end
        if not data.isPreboss and not data.isSubBoss and not data.isPhase then
            BOSS_NAME_TO_INFO[data.name].npcIDs[npcID] = true
            BOSS_NAME_TO_INFO[data.name].primaryID = npcID
        end
    end
end

local BOSS_ENGAGE_SPEECH = {
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
    ["Archavon the Stone Watcher shatters the rock"] = "Archavon the Stone Watcher",
    ["Emalon the Storm Watcher prepares to strike"] = "Emalon the Storm Watcher",
    ["Koralon the Flame Watcher ignites in a rage"] = "Koralon the Flame Watcher",
    ["Toravon the Ice Watcher freezes the air"] = "Toravon the Ice Watcher",
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
    ["It is my duty to guard these eggs"] = "Sartharion",
    ["My patience has reached its limit"] = "Malygos",
    ["I had hoped to end your lives quickly"] = "Malygos",
    ["How fortuitous. Usually, I must leave my lair"] = "Onyxia",
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
    ["Hailing from the deepest, darkest caverns"] = "Northrend Beasts",
    ["You face Jaraxxus, Eredar Lord"] = "Lord Jaraxxus",
    ["GLORY TO THE ALLIANCE"] = "Faction Champions",
    ["Glory to the Alliance"] = "Faction Champions",
    ["Show them no mercy, Horde champions"] = "Faction Champions",
    ["LOK'TAR OGAR"] = "Faction Champions",
    ["In the name of our dark master"] = "Twin Val'kyr",
    ["This place will serve as your tomb!"] = "Anub'arak",
    ["Ah, the entertainment has arrived"] = "Baltharus the Warborn",
    ["You will sssuffer for this intrusion"] = "Saviana Ragefire",
    ["Alexstrasza has chosen capable allies"] = "General Zarithrian",
    ["Your world totters on the brink of destruction"] = "Halion"
}

local BOSS_DEFEAT_SPEECH = {
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
    ["I am renewed"] = "Valithria Dreamwalker",
    ["Ysera grant me"] = "Valithria Dreamwalker",
    ["foul creatures to rest"] = "Valithria Dreamwalker",
    ["Free... at last"] = "Sindragosa",
    ["Father! Is it... over?"] = "The Lich King",
    ["Archavon the Stone Watcher falls to the ground"] = "Archavon the Stone Watcher",
    ["Emalon the Storm Watcher collapses"] = "Emalon the Storm Watcher",
    ["Koralon the Flame Watcher burns out"] = "Koralon the Flame Watcher",
    ["Toravon the Ice Watcher shatters"] = "Toravon the Ice Watcher",
    ["Ahhh... it is done"] = "Anub'Rekhan",
    ["The master... will avenge me!"] = "Grand Widow Faerlina",
    ["I will serve the master... in death"] = "Noth the Plaguebringer",
    ["An honorable... death"] = "Instructor Razuvious",
    ["I... am... undone"] = "Gothik the Harvester",
    ["What happened to... Patchwerk?"] = "Patchwerk",
    ["Thank... you..."] = "Thaddius",
    ["Do not rejoice! Your victory is a hollow one"] = "Kel'Thuzad",
    ["Such is the price... of failure"] = "Sartharion",
    ["ENOUGH! If you intend to reclaim Azeroth's magic"] = "Malygos",
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
    ["Another will take my place. Your world is doomed"] = "Lord Jaraxxus",
    ["A shallow and tragic victory"] = "Faction Champions",
    ["A superficial victory"] = "Faction Champions",
    ["weaker as a whole from the losses"] = "Faction Champions",
    ["The Scourge cannot be stopped"] = "Twin Val'kyr",
    ["I have failed you, master"] = "Anub'arak",
    ["I... didn't see that... coming"] = "Baltharus the Warborn",
    ["HALION! I"] = "General Zarithrian",
    ["Relish this victory, mortals, for it will be your last"] = "Halion"
}

local LICH_KING_RP_SPEECH = {
    "no questions remain unanswered", "greatest champions", "light, grant me one final blessing",
    "shatter this prison", "no more, arthas", "now i stand, the lion", "they cannot fear"
}

local WOTLK_BOSS_INITIATORS = {
    [69076] = "Lord Marrowgar", [69057] = "Lord Marrowgar", [70867] = "Lady Deathwhisper",
    [69680] = "Icecrown Gunship Battle", [72293] = "Deathbringer Saurfang", [72219] = "Festergut",
    [69674] = "Rotface", [70351] = "Professor Putricide", [71807] = "Blood Prince Council",
    [70877] = "Blood-Queen Lana'thel", [71741] = "Valithria Dreamwalker", [70123] = "Sindragosa",
    [72262] = "The Lich King", [70337] = "The Lich King", [74505] = "Baltharus the Warborn",
    [74509] = "Baltharus the Warborn", [74403] = "Saviana Ragefire", [74452] = "Saviana Ragefire",
    [78722] = "Saviana Ragefire", [74367] = "General Zarithrian", [74384] = "General Zarithrian",
    [74562] = "Halion", [66331] = "Northrend Beasts", [66532] = "Lord Jaraxxus",
    [65875] = "Twin Val'kyr", [65876] = "Twin Val'kyr", [66013] = "Anub'arak",
    [62374] = "Flame Leviathan", [62680] = "Ignis the Furnace Master", [64021] = "Razorscale",
    [62776] = "XT-002 Deconstructor", [61888] = "Assembly of Iron", [63356] = "Kologarn",
    [64386] = "Auriaya", [61968] = "Hodir", [62130] = "Thorim", [62589] = "Freya",
    [63631] = "Mimiron", [62660] = "General Vezax", [64163] = "Yogg-Saron", [64443] = "Algalon the Observer"
}

local ENEMY_ENRAGE_SPELLS = {
    [28371] = "Frenzy", [72143] = "Enrage", [72146] = "Enrage", [78722] = "Enrage",
    [74452] = "Enrage", [66759] = "Frothing Rage", [54427] = "Enrage", [59828] = "Frenzy",
    [28747] = "Frenzy", [54123] = "Frenzy", [48138] = "Frenzy", [63848] = "Frenzy",
}

-------------------------------------------------------------------------------
-- Potions, Consumables, Raid Buffs, Rings, Enchants & Trinkets Database
-------------------------------------------------------------------------------
local POTIONS_AND_BUFFS = {
    [53908] = "Potion of Speed", [53909] = "Potion of Wild Magic", [28494] = "Insane Strength Potion",
    [28507] = "Haste Potion", [28508] = "Destruction Potion", [53762] = "Indestructible Potion",
    [53753] = "Indestructible Potion", [54117] = "Indestructible Potion",
    [53761] = "Powerful Rejuvenation Potion", [28714] = "Flame Cap",
    [9512] = "Thistle Tea", [9513] = "Thistle Tea", [18160] = "Thistle Tea",
    [43186] = "Runic Mana Potion", [53942] = "Runic Mana Injector",
    [43185] = "Runic Healing Potion", [53934] = "Runic Healing Injector",
    [53910] = "Crazy Alchemist's Potion", [53750] = "Endless Healing Potion", [53751] = "Endless Mana Potion",
    [53911] = "Potion of Nightmares", [28506] = "Heroic Potion", [28515] = "Ironshield Potion",
    [6615] = "Free Action Potion", [24364] = "Living Action Potion", [17528] = "Mighty Rage Potion",
    [28499] = "Super Mana Potion", [28495] = "Super Healing Potion",
    [27869] = "Dark Rune", [16666] = "Demonic Rune",
    [47878] = "Fel Healthstone", [47871] = "Fel Healthstone", [47875] = "Fel Healthstone", [27230] = "Master Healthstone",
    [42985] = "Mana Sapphire", [33312] = "Mana Emerald", [42984] = "Mana Sapphire",
    [53755] = "Flask of the Frost Wyrm", [53760] = "Flask of Endless Rage",
    [53758] = "Flask of Stoneblood", [54212] = "Flask of Pure Mojo",
    [53752] = "Lesser Flask of Toughness", [67016] = "Flask of the North (SP)",
    [67017] = "Flask of the North (AP)", [67018] = "Flask of the North (STR)",
    [17627] = "Flask of Distilled Wisdom", [53747] = "Elixir of Spirit",
    [53748] = "Elixir of Mighty Strength", [53746] = "Wrath Elixir",
    [53749] = "Guru's Elixir", [53763] = "Elixir of Protection",
    [53764] = "Elixir of Mighty Mageblood", [60347] = "Elixir of Mighty Thoughts",
    [60346] = "Elixir of Lightning Speed", [60345] = "Elixir of Armor Piercing",
    [60344] = "Elixir of Expertise", [60341] = "Elixir of Deadly Strikes",
    [60340] = "Elixir of Accuracy", [28497] = "Elixir of Mighty Agility",
    [57399] = "Fish Feast (Well Fed)", [57329] = "Well Fed (Crit/Sta)",
    [57325] = "Well Fed (AP/Sta)", [57327] = "Well Fed (SP/Sta)",
    [57332] = "Well Fed (Haste/Sta)", [57334] = "Well Fed (MP5/Sta)",
    [57356] = "Well Fed (Exp/Sta)", [57358] = "Well Fed (ArP/Sta)",
    [57360] = "Well Fed (Hit/Sta)", [57367] = "Well Fed (Agi/Sta)",
    [57371] = "Well Fed (Str/Sta)", [57365] = "Well Fed (Spi/Sta)",
    [54758] = "Hyperspeed Accelerators", [55002] = "Flexweave Underlay",
    [55637] = "Lightweave Embroidery", [55775] = "Swordguard Embroidery",
    [55777] = "Darkglow Embroidery", [59626] = "Black Magic Proc",
    [59620] = "Berserking Proc", [59625] = "Blade Ward Proc",
    [64441] = "Blood Draining Proc", [28093] = "Mongoose Proc",
    [42976] = "Executioner Proc", [72416] = "Ashen Caster Ring Proc",
    [72418] = "Ashen Healer Ring Proc", [72412] = "Ashen Melee Ring Proc",
    [72414] = "Ashen Tank Ring Proc", [71605] = "Phylactery Proc (N)",
    [71636] = "Phylactery Proc (HC)", [71601] = "DFO Proc (N)", [71644] = "DFO Proc (HC)",
    [71484] = "DBW: Strength of the Taunka (+600 Str)",
    [71485] = "DBW: Agility of the Vrykul (+600 Agi)",
    [71486] = "DBW: Power of the Taunka (+1200 AP)",
    [71487] = "DBW: Precision of the Iron Dwarves (+600 ArP)",
    [71491] = "DBW: Aim of the Iron Dwarves (+600 Crit)",
    [71492] = "DBW: Speed of the Vrykul (+600 Haste)",
    [71561] = "DBW HC: Strength of the Taunka (+700 Str)",
    [71556] = "DBW HC: Agility of the Vrykul (+700 Agi)",
    [71558] = "DBW HC: Power of the Taunka (+1400 AP)",
    [71557] = "DBW HC: Precision of the Iron Dwarves (+700 ArP)",
    [71559] = "DBW HC: Aim of the Iron Dwarves (+700 Crit)",
    [71560] = "DBW HC: Speed of the Vrykul (+600 Haste)",
    [71635] = "CTS Organ/Coin Proc (N)", [71646] = "CTS Organ/Coin Proc (HC)",
    [75458] = "STS Proc (N)", [75456] = "STS Proc (HC)",
    [75466] = "Charred Twilight Scale (N)", [75473] = "Charred Twilight Scale (HC)",
    [75490] = "Glowing Twilight Scale (N)", [75495] = "Glowing Twilight Scale (HC)",
    [75477] = "Petrified Twilight Scale (N)", [75481] = "Petrified Twilight Scale (HC)",
    [71401] = "Whispering Fanged Skull (N)", [71541] = "Whispering Fanged Skull (HC)",
    [71633] = "Tiny Abomination Proc", [71403] = "Needle-Encrusted Scorpion",
    [67703] = "Death's Choice/Verdict Str (N)", [67772] = "Death's Choice/Verdict Str (HC)",
    [67708] = "Death's Choice/Verdict Agi (N)", [67773] = "Death's Choice/Verdict Agi (HC)",
    [67695] = "Talisman of Resurgence", [67753] = "Satrina's / Juggernaut Vitality (N)",
    [67751] = "Satrina's / Juggernaut Vitality (HC)", [64772] = "Comet's Trail Proc",
    [60229] = "Greatness Proc (Str)", [60233] = "Greatness Proc (Agi)",
    [60234] = "Greatness Proc (Int)", [60235] = "Greatness Proc (Spi)",
    [65008] = "Mjolnir Runestone Proc", [65019] = "Grim Toll Proc",
    [64713] = "Flare of the Heavens Proc", [64741] = "Pandora's Plea Proc",
    [65006] = "Eye of the Broodmother", [71570] = "Muradin's Spyglass (N)",
    [71572] = "Muradin's Spyglass (HC)", [71584] = "Purified Lunar Dust",
    [71610] = "Althor's Abacus Proc", [71880] = "Trauma Proc",
    [2825] = "Bloodlust", [32182] = "Heroism", [10060] = "Power Infusion",
    [49016] = "Hysteria", [57933] = "Tricks of the Trade (+15% Dmg)",
    [29166] = "Innervate", [54648] = "Focus Magic Proc", [33206] = "Pain Suppression",
    [47788] = "Guardian Spirit", [6940] = "Hand of Sacrifice",
    [10278] = "Hand of Protection", [1022] = "Hand of Protection", [5599] = "Hand of Protection",
    [1038] = "Hand of Salvation", [1044] = "Hand of Freedom",
    [64205] = "Divine Sacrifice", [70940] = "Divine Guardian",
    [31821] = "Aura Mastery", [6346] = "Fear Ward"
}

local ALLOW_REFRESH_BUFFS = {
    [53908] = true, [53909] = true, [28494] = true, [28507] = true, [28508] = true,
    [53762] = true, [53753] = true, [54117] = true, [28714] = true,
    [53911] = true, [28506] = true, [28515] = true, [6615] = true, [24364] = true, [17528] = true,
    [57933] = true, [10060] = true, [49016] = true, [29166] = true,
    [33206] = true, [47788] = true, [6940] = true, [1038] = true, [1044] = true,
    [71484] = true, [71485] = true, [71486] = true, [71487] = true, [71491] = true, [71492] = true,
    [71561] = true, [71556] = true, [71558] = true, [71557] = true, [71559] = true, [71560] = true,
}

local CUSTOM_BUFF_ICD = {
    [59620] = 12.0, [28093] = 10.0, [54648] = 10.0, [71570] = 30.0, [71572] = 30.0, [65006] = 30.0,
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

local TANK_STANCE_BUFFS = {
    [48263] = true, -- Frost Presence
    [25780] = true, -- Righteous Fury
    [9634]  = true, -- Dire Bear Form
}

-------------------------------------------------------------------------------
-- Raid Utility Database & Class Verification
-------------------------------------------------------------------------------
local RAID_UTILITY = {
    [54861] = "Nitro Boosts", [55016] = "Nitro Boosts",
    [56488] = "Global Thermal Sapper Charge", [56350] = "Saronite Bomb", [67890] = "Frag Belt",
    [1966] = "Feint", [6768] = "Feint", [8637] = "Feint", [11303] = "Feint",
    [25302] = "Feint", [27448] = "Feint", [48658] = "Feint", [48659] = "Feint",
    [57934] = "Tricks of the Trade",
    [2983] = "Sprint", [8696] = "Sprint", [11305] = "Sprint",
    [1856] = "Vanish", [1857] = "Vanish", [26889] = "Vanish",
    [31224] = "Cloak of Shadows", [51722] = "Dismantle", [1766] = "Kick", [2094] = "Blind",
    [5277] = "Evasion", [26669] = "Evasion",
    [1022] = "Hand of Protection", [5599] = "Hand of Protection", [10278] = "Hand of Protection",
    [633] = "Lay on Hands", [2800] = "Lay on Hands", [10310] = "Lay on Hands", [27154] = "Lay on Hands", [48788] = "Lay on Hands",
    [1038] = "Hand of Salvation", [1044] = "Hand of Freedom", [6940] = "Hand of Sacrifice",
    [64205] = "Divine Sacrifice", [70940] = "Divine Guardian", [31821] = "Aura Mastery",
    [53601] = "Sacred Shield", [642] = "Divine Shield", [498] = "Divine Protection",
    [10308] = "Hammer of Justice", [853] = "Hammer of Justice", [4987] = "Cleanse",
    [31789] = "Righteous Defense", [62124] = "Hand of Reckoning",
    [20484] = "Rebirth", [20739] = "Rebirth", [20742] = "Rebirth", [20747] = "Rebirth", [20748] = "Rebirth", [26994] = "Rebirth", [48477] = "Rebirth",
    [740] = "Tranquility", [8918] = "Tranquility", [9862] = "Tranquility", [9863] = "Tranquility", [26983] = "Tranquility", [48446] = "Tranquility", [48447] = "Tranquility",
    [29166] = "Innervate", [22812] = "Barkskin", [61336] = "Survival Instincts",
    [22842] = "Frenzied Regeneration", [2782] = "Remove Curse", [2893] = "Abolish Poison",
    [33786] = "Cyclone", [6795] = "Growl", [5209] = "Challenging Roar",
    [20707] = "Soulstone Resurrection", [20762] = "Soulstone Resurrection", [20763] = "Soulstone Resurrection",
    [20764] = "Soulstone Resurrection", [20765] = "Soulstone Resurrection", [27239] = "Soulstone Resurrection", [47883] = "Soulstone Resurrection",
    [47241] = "Metamorphosis", [698] = "Ritual of Summoning",
    [29893] = "Ritual of Souls", [58887] = "Ritual of Souls",
    [48020] = "Demonic Circle: Teleport", [29858] = "Soulshatter", [47847] = "Shadowfury", [19647] = "Spell Lock",
    [42650] = "Army of the Dead", [51052] = "Anti-Magic Zone", [48707] = "Anti-Magic Shell",
    [48792] = "Icebound Fortitude", [55233] = "Vampiric Blood", [51271] = "Unbreakable Armor",
    [49222] = "Bone Shield", [61999] = "Raise Ally", [47568] = "Empower Rune Weapon",
    [49576] = "Death Grip", [47528] = "Mind Freeze", [47476] = "Strangulate",
    [56222] = "Dark Command", [49016] = "Hysteria",
    [17] = "Power Word: Shield", [48065] = "Power Word: Shield", [48066] = "Power Word: Shield",
    [33206] = "Pain Suppression", [47788] = "Guardian Spirit", [10060] = "Power Infusion",
    [64843] = "Divine Hymn", [64901] = "Hymn of Hope", [6346] = "Fear Ward",
    [586] = "Fade", [47585] = "Dispersion", [32375] = "Mass Dispel",
    [988] = "Dispel Magic", [527] = "Dispel Magic",
    [528] = "Cure Disease", [552] = "Abolish Disease", [10955] = "Shackle Undead",
    [32182] = "Heroism", [2825] = "Bloodlust", [16190] = "Mana Tide Totem",
    [8143] = "Tremor Totem", [8177] = "Grounding Totem", [8170] = "Cleansing Totem",
    [2062] = "Earth Elemental Totem", [2894] = "Fire Elemental Totem", [57994] = "Wind Shear",
    [8012] = "Purge", [370] = "Purge", [51886] = "Cleanse Spirit",
    [526] = "Cure Toxins", [51514] = "Hex", [30823] = "Shamanistic Rage",
    [34477] = "Misdirection", [5384] = "Feign Death", [19263] = "Deterrence",
    [19801] = "Tranquilizing Shot", [20736] = "Distracting Shot", [13809] = "Frost Trap",
    [14311] = "Freezing Trap", [60192] = "Freezing Arrow", [53271] = "Master's Call",
    [53480] = "Roar of Sacrifice", [781] = "Disengage",
    [64382] = "Shattering Throw", [871] = "Shield Wall", [12975] = "Last Stand",
    [55694] = "Enraged Regeneration", [3411] = "Intervene", [50720] = "Vigilance",
    [676] = "Disarm", [6552] = "Pummel", [72] = "Shield Bash",
    [23920] = "Spell Reflection", [1161] = "Challenging Shout", [1719] = "Recklessness",
    [66] = "Invisibility", [45438] = "Ice Block", [12051] = "Evocation",
    [2139] = "Counterspell", [30449] = "Spellsteal", [475] = "Remove Curse",
    [54646] = "Focus Magic", [55342] = "Mirror Image", [130] = "Slow Fall"
}

local UTILITY_CLASS_FILTER = {
    ["Death Grip"] = "DEATHKNIGHT", ["Icebound Fortitude"] = "DEATHKNIGHT", ["Vampiric Blood"] = "DEATHKNIGHT",
    ["Anti-Magic Shell"] = "DEATHKNIGHT", ["Anti-Magic Zone"] = "DEATHKNIGHT", ["Army of the Dead"] = "DEATHKNIGHT",
    ["Empower Rune Weapon"] = "DEATHKNIGHT", ["Mind Freeze"] = "DEATHKNIGHT", ["Strangulate"] = "DEATHKNIGHT",
    ["Dark Command"] = "DEATHKNIGHT", ["Hysteria"] = "DEATHKNIGHT", ["Raise Ally"] = "DEATHKNIGHT",
    ["Unbreakable Armor"] = "DEATHKNIGHT", ["Bone Shield"] = "DEATHKNIGHT",
    ["Tricks of the Trade"] = "ROGUE", ["Feint"] = "ROGUE", ["Cloak of Shadows"] = "ROGUE",
    ["Vanish"] = "ROGUE", ["Sprint"] = "ROGUE", ["Evasion"] = "ROGUE",
    ["Kick"] = "ROGUE", ["Dismantle"] = "ROGUE", ["Blind"] = "ROGUE",
    ["Misdirection"] = "HUNTER", ["Feign Death"] = "HUNTER", ["Deterrence"] = "HUNTER",
    ["Disengage"] = "HUNTER", ["Tranquilizing Shot"] = "HUNTER", ["Distracting Shot"] = "HUNTER",
    ["Freezing Arrow"] = "HUNTER", ["Freezing Trap"] = "HUNTER", ["Frost Trap"] = "HUNTER",
    ["Innervate"] = "DRUID", ["Rebirth"] = "DRUID", ["Barkskin"] = "DRUID", ["Tranquility"] = "DRUID",
    ["Heroism"] = "SHAMAN", ["Bloodlust"] = "SHAMAN", ["Wind Shear"] = "SHAMAN",
    ["Mana Tide Totem"] = "SHAMAN", ["Cleanse Spirit"] = "SHAMAN",
}

local EXTERNAL_TARGETED_UTILITY = {
    ["Power Word: Shield"] = true, ["Tricks of the Trade"] = true, ["Misdirection"] = true,
    ["Hand of Protection"] = true, ["Hand of Salvation"] = true, ["Hand of Freedom"] = true,
    ["Hand of Sacrifice"] = true, ["Lay on Hands"] = true, ["Sacred Shield"] = true,
    ["Rebirth"] = true, ["Innervate"] = true, ["Soulstone Resurrection"] = true,
    ["Raise Ally"] = true, ["Hysteria"] = true, ["Pain Suppression"] = true,
    ["Guardian Spirit"] = true, ["Power Infusion"] = true, ["Fear Ward"] = true,
    ["Focus Magic"] = true, ["Vigilance"] = true, ["Intervene"] = true,
    ["Master's Call"] = true, ["Roar of Sacrifice"] = true, ["Cleanse"] = true,
    ["Dispel Magic"] = true, ["Cure Disease"] = true, ["Abolish Disease"] = true,
    ["Abolish Poison"] = true, ["Remove Curse"] = true, ["Cleanse Spirit"] = true,
    ["Cure Toxins"] = true, ["Slow Fall"] = true,
}

local INSTANT_CONSUMABLES = {
    [43186] = true, [53942] = true, [43185] = true, [53934] = true,
    [53910] = true, [53750] = true, [53751] = true,
    [28499] = true, [28495] = true, [27869] = true, [16666] = true,
    [47878] = true, [47871] = true, [47875] = true, [27230] = true,
    [42985] = true, [33312] = true, [42984] = true,
    [9512] = true, [9513] = true, [18160] = true,
}

local PERSONAL_DEFENSIVES_BY_CLASS = {
    ["MAGE"]        = { "Ice Block" },
    ["PALADIN"]     = { "Divine Shield", "Divine Protection" },
    ["ROGUE"]       = { "Cloak of Shadows", "Feint", "Evasion" },
    ["DEATHKNIGHT"] = { "Anti-Magic Shell", "Icebound Fortitude" },
    ["DRUID"]       = { "Barkskin" },
    ["PRIEST"]      = { "Dispersion", "Fade" },
    ["HUNTER"]      = { "Deterrence", "Feign Death" },
    ["SHAMAN"]      = { "Shamanistic Rage" },
    ["WARRIOR"]     = { "Shield Wall", "Last Stand", "Enraged Regeneration" },
    ["WARLOCK"]     = { "Demonic Circle: Teleport" },
}

local MAJOR_TANK_COOLDOWNS = {
    "Icebound Fortitude", "Vampiric Blood", "Unbreakable Armor", "Bone Shield", "Anti-Magic Shell",
    "Divine Protection", "Divine Sacrifice", "Hand of Sacrifice", "Sacred Shield",
    "Shield Wall", "Last Stand",
    "Barkskin", "Survival Instincts", "Frenzied Regeneration"
}

local TANK_TAUNT_NAMES = {
    ["Dark Command"] = true, ["Hand of Reckoning"] = true, ["Righteous Defense"] = true,
    ["Growl"] = true, ["Challenging Shout"] = true, ["Challenging Roar"] = true
}

local TANK_PROC_NAMES = {
    ["Ashen Tank Ring Proc"] = true, ["Petrified Twilight Scale (N)"] = true,
    ["Petrified Twilight Scale (HC)"] = true, ["Satrina's / Juggernaut Vitality (N)"] = true,
    ["Satrina's / Juggernaut Vitality (HC)"] = true
}

local COMBAT_POTION_NAMES = {
    ["Potion of Speed"] = true, ["Potion of Wild Magic"] = true, ["Indestructible Potion"] = true,
    ["Insane Strength Potion"] = true, ["Haste Potion"] = true, ["Destruction Potion"] = true,
    ["Powerful Rejuvenation Potion"] = true, ["Runic Mana Potion"] = true, ["Runic Mana Injector"] = true,
    ["Runic Healing Potion"] = true, ["Runic Healing Injector"] = true,
    ["Crazy Alchemist's Potion"] = true, ["Endless Healing Potion"] = true, ["Endless Mana Potion"] = true,
    ["Potion of Nightmares"] = true, ["Heroic Potion"] = true, ["Ironshield Potion"] = true,
    ["Free Action Potion"] = true, ["Living Action Potion"] = true, ["Mighty Rage Potion"] = true,
    ["Super Mana Potion"] = true, ["Super Healing Potion"] = true
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
local lichKingRPActive = false
local lichKingRPElapsed = 0
RTExt.lichKingFuryTime = nil

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
        duration = nil,
        zone = zone,
        difficulty = diff,
        potionsAndBuffs = {},
        raidUtility = {},
        demonicPactValues = {},
        deaths = {},
        players = {},
        playerIDs = {},
        enrages = {},
        tanks = {}
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
        topSeg.playerIDs = topSeg.playerIDs or {}
        topSeg.demonicPactValues = topSeg.demonicPactValues or {}
        topSeg.enrages = topSeg.enrages or {}
        topSeg.tanks = topSeg.tanks or {}
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
    RaidersTrackerDB.liveSession = { name = "Live Current Session", segments = {}, players = {}, playerIDs = {}, zoneTimes = {} }
    currentSession = RaidersTrackerDB.liveSession
    currentSegment = nil
    inCombatState = false
    hasEnteredBossCombat = false
    lichKingRPActive = false
    lichKingRPElapsed = 0
    RTExt.lichKingFuryTime = nil
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
    table.wipe(RTExt.recentDemonicPact)
    table.wipe(RTExt.lastDemonicPactConfirmedAt)
    table.wipe(RTExt.lastDemonicPactExpiry)
    table.wipe(RTExt.pendingDemonicPacts)
    RTExt.playerSelfDPContribution = 0
    RTExt.activeObservedDP = 0
    RTExt.preDPTransitionSP = nil
    if RTExt.dpWatcherFrame then RTExt.dpWatcherFrame:SetScript("OnUpdate", nil) end
    EnsureTrashSegment()
end

local function SaveCurrentLiveSession(startFreshAfterSave)
    if not currentSession or #currentSession.segments == 0 then return end
    RepairSplitLichKingSegments(currentSession)
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
        players = DeepCopyTable(currentSession.players or {}),
        playerIDs = DeepCopyTable(currentSession.playerIDs or {}),
        zoneTimes = DeepCopyTable(currentSession.zoneTimes or {})
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
    bossSegment.tanks = bossSegment.tanks or {}
    bossSegment.playerIDs = bossSegment.playerIDs or {}
    local function ScanUnit(unit)
        if not UnitExists(unit) then return end
        local name = UnitName(unit)
        if not name or name == UNKNOWN then return end
        local _, engClass = UnitClass(unit)
        local pClass = engClass or GetSafePlayerClass(name)
        bossSegment.players[name] = pClass
        if currentSession then
            currentSession.players = currentSession.players or {}
            currentSession.players[name] = pClass
        end
        CachePlayerCharID(name, UnitGUID(unit), bossSegment)

        for i = 1, 40 do
            local buffName, _, _, _, _, _, _, _, _, _, spellID = UnitBuff(unit, i)
            if not buffName then break end
            if spellID and TANK_STANCE_BUFFS[spellID] then
                bossSegment.tanks[name] = true
            end
            if spellID and SNAPSHOT_PERSISTENT_BUFFS[spellID] and POTIONS_AND_BUFFS[spellID] then
                local label = POTIONS_AND_BUFFS[spellID]
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
RTExt.zoneTimeAccum = 0

function RTExt.GetZoneTimeTotal(entry)
    if type(entry) == "table" then
        return (tonumber(entry.prev) or 0) + (tonumber(entry.curr) or 0)
    end
    return tonumber(entry) or 0
end

function RTExt.CloseActiveZoneStint(entry)
    if type(entry) ~= "table" then return end
    if entry.inGroup then
        if (tonumber(entry.curr) or 0) > 0 then
            entry.prev = tonumber(entry.curr) or 0
            entry.curr = 0
        end
        entry.inGroup = false
    end
    entry.absentSince = nil
end

function RTExt.CloseAllActiveZoneStints(session)
    if not session or type(session.zoneTimes) ~= "table" then return end
    for _, zMap in pairs(session.zoneTimes) do
        if type(zMap) == "table" then
            for zName, entry in pairs(zMap) do
                if type(entry) == "number" then
                    if entry > 0 then
                        zMap[zName] = { prev = entry, curr = 0, inGroup = false }
                    end
                elseif type(entry) == "table" then
                    RTExt.CloseActiveZoneStint(entry)
                end
            end
        end
    end
end

function RTExt.AddZoneTimeSeconds(session, playerName, zoneName, dt)
    if not session or not playerName or not zoneName or zoneName == "" or zoneName == "Unknown" then return end
    session.zoneTimes = session.zoneTimes or {}
    session.zoneTimes[playerName] = session.zoneTimes[playerName] or {}
    local entry = session.zoneTimes[playerName][zoneName]
    if type(entry) == "number" then
        entry = { prev = 0, curr = entry, inGroup = true }
        session.zoneTimes[playerName][zoneName] = entry
    elseif type(entry) ~= "table" then
        entry = { prev = 0, curr = 0, inGroup = true }
        session.zoneTimes[playerName][zoneName] = entry
    end
    entry.inGroup = true
    entry.absentSince = nil
    entry.curr = (tonumber(entry.curr) or 0) + dt
end

function RTExt.UpdateSessionZoneTimes(dt)
    if not RaidersTrackerDB or not RaidersTrackerDB.enabled or not currentSession then return end
    dt = math.min(math.max(dt or 0, 0), 5.0)
    if dt <= 0 then return end

    currentSession.zoneTimes = currentSession.zoneTimes or {}
    currentSession.players = currentSession.players or {}

    local numRaid = GetNumRaidMembers()
    local numParty = GetNumPartyMembers()

    -- Do not track time when solo / not in a raid or party
    if numRaid == 0 and numParty == 0 then
        RTExt.CloseAllActiveZoneStints(currentSession)
        return
    end

    local now = GetTime()
    local presentInGroup = {}

    if numRaid > 0 then
        for i = 1, numRaid do
            local rName, _, _, _, _, rFileName, rZone, rOnline = GetRaidRosterInfo(i)
            if rName and rName ~= UNKNOWN then
                local shortName = rName:match("^([^%-]+)") or rName
                presentInGroup[shortName] = true
                if rFileName and rFileName ~= "" then
                    currentSession.players[shortName] = currentSession.players[shortName] or rFileName
                    groupClasses[shortName] = groupClasses[shortName] or rFileName
                end
                local uGUID = UnitGUID("raid" .. i)
                if uGUID then
                    CachePlayerCharID(shortName, uGUID)
                end
                if rOnline and rZone and rZone ~= "" and rZone ~= "Offline" then
                    RTExt.AddZoneTimeSeconds(currentSession, shortName, rZone, dt)
                end
            end
        end
    else
        local myZone = GetCurrentZoneSafe()
        local myName = UnitName("player")
        if myName and myName ~= UNKNOWN then
            presentInGroup[myName] = true
            local _, myClass = UnitClass("player")
            if myClass then currentSession.players[myName] = currentSession.players[myName] or myClass end
            if myZone ~= "Unknown" then
                RTExt.AddZoneTimeSeconds(currentSession, myName, myZone, dt)
            end
        end
        for i = 1, numParty do
            local unit = "party" .. i
            if UnitExists(unit) then
                local pName = UnitName(unit)
                if pName and pName ~= UNKNOWN then
                    presentInGroup[pName] = true
                    local _, pClass = UnitClass(unit)
                    if pClass then currentSession.players[pName] = currentSession.players[pName] or pClass end
                    local uGUID = UnitGUID(unit)
                    if uGUID then CachePlayerCharID(pName, uGUID) end
                    if UnitIsConnected(unit) and myZone ~= "Unknown" and (UnitIsVisible(unit) or IsInInstance()) then
                        RTExt.AddZoneTimeSeconds(currentSession, pName, myZone, dt)
                    end
                end
            end
        end
    end

    -- Detect individual players who left the group/raid so returning adds previous + current only
    for pName, zMap in pairs(currentSession.zoneTimes) do
        if type(zMap) == "table" and not presentInGroup[pName] then
            for _, entry in pairs(zMap) do
                if type(entry) == "table" and entry.inGroup then
                    if not entry.absentSince then
                        entry.absentSince = now
                    elseif (now - entry.absentSince) >= 5.0 then
                        RTExt.CloseActiveZoneStint(entry)
                    end
                end
            end
        end
    end
end

function RTExt.FormatZoneDuration(seconds)
    local total = math.max(0, math.floor(tonumber(seconds) or 0))
    local hrs = math.floor(total / 3600)
    local mins = math.floor((total % 3600) / 60)
    local secs = total % 60
    if hrs > 0 then
        return string.format("%dh %02dm %02ds", hrs, mins, secs)
    end
    return string.format("%dm %02ds", mins, secs)
end

function RTExt.GetMajorityRaidZone(activeSession)
    local currentZone = GetCurrentZoneSafe()
    if activeSession == currentSession and GetNumRaidMembers() > 0 then
        local counts = {}
        local totalOnline = 0
        for i = 1, GetNumRaidMembers() do
            local rName, _, _, _, _, _, rZone, rOnline = GetRaidRosterInfo(i)
            if rName and rOnline and rZone and rZone ~= "" and rZone ~= "Offline" then
                counts[rZone] = (counts[rZone] or 0) + 1
                totalOnline = totalOnline + 1
            end
        end
        local bestZone, bestCount = nil, 0
        for zName, cnt in pairs(counts) do
            if cnt > bestCount
                or (cnt == bestCount and zName == currentZone)
                or (cnt == bestCount and bestZone ~= currentZone and bestZone and zName < bestZone) then
                bestZone = zName
                bestCount = cnt
            end
        end
        if bestZone then
            return bestZone, bestCount, totalOnline
        end
    end

    if activeSession and type(activeSession.zoneTimes) == "table" then
        local zonePlayerCounts = {}
        local zoneTotalSecs = {}
        for _, zMap in pairs(activeSession.zoneTimes) do
            if type(zMap) == "table" then
                for zName, entry in pairs(zMap) do
                    local secs = RTExt.GetZoneTimeTotal(entry)
                    if zName and zName ~= "" and zName ~= "Unknown" and secs > 0 then
                        zonePlayerCounts[zName] = (zonePlayerCounts[zName] or 0) + 1
                        zoneTotalSecs[zName] = (zoneTotalSecs[zName] or 0) + secs
                    end
                end
            end
        end
        local bestZone, bestPlayers, bestSecs = nil, 0, 0
        for zName, pCnt in pairs(zonePlayerCounts) do
            local zSec = zoneTotalSecs[zName] or 0
            if pCnt > bestPlayers
                or (pCnt == bestPlayers and zSec > bestSecs)
                or (pCnt == bestPlayers and zSec == bestSecs and bestZone and zName < bestZone) then
                bestZone = zName
                bestPlayers = pCnt
                bestSecs = zSec
            end
        end
        if bestZone then
            return bestZone, bestPlayers, 0
        end
    end

    if activeSession and type(activeSession.segments) == "table" then
        local segZoneCounts = {}
        for _, seg in ipairs(activeSession.segments) do
            if seg.zone and seg.zone ~= "" and seg.zone ~= "Unknown" then
                segZoneCounts[seg.zone] = (segZoneCounts[seg.zone] or 0) + 1
            end
        end
        local bestZone, bestCnt = nil, 0
        for zName, cnt in pairs(segZoneCounts) do
            if cnt > bestCnt then bestZone = zName; bestCnt = cnt end
        end
        if bestZone then return bestZone, 0, 0 end
    end

    return currentZone, 0, 0
end

local function StartEncounter(bossID, bossName, overrideData, fromSpeech)
    if inCombatState or not bossName then return end
    if not fromSpeech and not IsRaidInCombat() then return end

    local now = GetTime()
    if defeatedBossLocks[bossName] and (now - defeatedBossLocks[bossName]) < 180.0 then return end
    if bossEndCooldowns[bossName] and (now - bossEndCooldowns[bossName]) < 12.0 then return end

    UpdateGroupCache()

    local info = BOSS_NAME_TO_INFO[bossName]
    activeBossID = bossID or (info and info.primaryID) or nil
    activeBossName = bossName
    activeBossData = overrideData or (activeBossID and WOTLK_BOSS_DB[activeBossID]) or info or {}
    inCombatState = true
    hasEnteredBossCombat = IsRaidInCombat()
    lichKingRPActive = false
    lichKingRPElapsed = 0
    RTExt.lichKingFuryTime = nil
    bossStartTime = now
    outOfCombatAccum = 0
    gracePeriodAccum = 0
    table.wipe(defeatedGroupNPCs)
    table.wipe(RTExt.recentDemonicPact)
    table.wipe(RTExt.lastDemonicPactConfirmedAt)
    table.wipe(RTExt.lastDemonicPactExpiry)

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
            if ev.pCharID then newBossSeg.playerIDs[ev.pName] = ev.pCharID end
            if ev.extraPlayer and ev.extraClass then
                newBossSeg.players[ev.extraPlayer] = ev.extraClass
                if ev.extraCharID then newBossSeg.playerIDs[ev.extraPlayer] = ev.extraCharID end
            end
            if ev.isTankPlayer then
                newBossSeg.tanks[ev.isTankPlayer] = true
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
                if ev.dpValue ~= nil then
                    newBossSeg.demonicPactValues = newBossSeg.demonicPactValues or {}
                    newBossSeg.demonicPactValues[ev.pName] = newBossSeg.demonicPactValues[ev.pName] or {}
                    table.insert(newBossSeg.demonicPactValues[ev.pName], ev.dpValue)
                end
                if prevTrashSeg and prevTrashSeg.raidUtility[ev.pName] and prevTrashSeg.raidUtility[ev.pName][ev.entryName] then
                    prevTrashSeg.raidUtility[ev.pName][ev.entryName] = prevTrashSeg.raidUtility[ev.pName][ev.entryName] - 1
                    if prevTrashSeg.raidUtility[ev.pName][ev.entryName] <= 0 then
                        prevTrashSeg.raidUtility[ev.pName][ev.entryName] = nil
                    end
                    if next(prevTrashSeg.raidUtility[ev.pName]) == nil then
                        prevTrashSeg.raidUtility[ev.pName] = nil
                    end
                end
                if ev.dpValue ~= nil and prevTrashSeg and prevTrashSeg.demonicPactValues and prevTrashSeg.demonicPactValues[ev.pName] then
                    local trashDP = prevTrashSeg.demonicPactValues[ev.pName]
                    for idx = #trashDP, 1, -1 do
                        if trashDP[idx] == ev.dpValue then
                            table.remove(trashDP, idx)
                            break
                        end
                    end
                    if #trashDP == 0 then
                        prevTrashSeg.demonicPactValues[ev.pName] = nil
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
    local finishedBoss = activeBossName or "Boss"

    if not isVictory and finishedBoss == "Faction Champions" then
        local champsKilled = 0
        for _ in pairs(defeatedGroupNPCs) do champsKilled = champsKilled + 1 end
        local diff = GetRaidDifficultySuffix()
        local reqKills = (diff:find("25") ~= nil) and 10 or 6
        if champsKilled >= reqKills or (champsKilled >= 4 and not UnitIsDeadOrGhost("player")) then
            isVictory = true
        end
    end

    if not isVictory and finishedBoss == "The Lich King" and lichKingRPActive and not UnitIsDeadOrGhost("player") then
        isVictory = true
    end

    local usedLKFuryTime = false
    local effectiveEndTime = now
    if isVictory and finishedBoss == "The Lich King" and RTExt.lichKingFuryTime and RTExt.lichKingFuryTime >= bossStartTime then
        effectiveEndTime = RTExt.lichKingFuryTime
        usedLKFuryTime = true
    end

    local duration = math.max(1, math.floor(effectiveEndTime - bossStartTime))
    local mins = math.floor(duration / 60)
    local secs = duration % 60
    local timeStr = string.format("%dm %ds", mins, secs)

    if isVictory then
        bossEndCooldowns[finishedBoss] = now
        defeatedBossLocks[finishedBoss] = now
        if currentSession.segments[1] and currentSession.segments[1].isBoss then
            currentSession.segments[1].duration = duration
            if usedLKFuryTime then
                currentSession.segments[1].lkFuryDuration = duration
            end
            currentSession.segments[1].name = string.format("%s [Victory - %s]", finishedBoss, timeStr)
        end
        RepairSplitLichKingSegments(currentSession)
        AnnounceLocalChat(string.format("VICTORY: %s was killed and it was a victory! (%s)", finishedBoss, timeStr))
    else
        if duration < RTExt.MIN_BOSS_PULL_DURATION or not hasEnteredBossCombat then
            if currentSession.segments[1] and currentSession.segments[1].isBoss then
                table.remove(currentSession.segments, 1)
            end
            if activeBossName and bossAttemptCount[activeBossName] and bossAttemptCount[activeBossName] > 0 then
                bossAttemptCount[activeBossName] = bossAttemptCount[activeBossName] - 1
            end
            AnnounceLocalChat(string.format("Boss combat ended: %s (Attempt < %ds removed)", finishedBoss, RTExt.MIN_BOSS_PULL_DURATION))
        else
            bossEndCooldowns[finishedBoss] = now
            if currentSession.segments[1] and currentSession.segments[1].isBoss then
                currentSession.segments[1].duration = duration
                currentSession.segments[1].name = string.format("%s [Wipe %d - %s]", finishedBoss, currentSession.segments[1].attempt or 1, timeStr)
            end
            RepairSplitLichKingSegments(currentSession)
            AnnounceLocalChat(string.format("Boss combat ended: %s (%s)", finishedBoss, timeStr))
        end
    end

    inCombatState = false
    hasEnteredBossCombat = false
    lichKingRPActive = false
    lichKingRPElapsed = 0
    RTExt.lichKingFuryTime = nil
    activeBossID = nil
    activeBossName = nil
    activeBossData = nil
    outOfCombatAccum = 0
    gracePeriodAccum = 0
    table.wipe(defeatedGroupNPCs)
    table.wipe(recentProcs)
    table.wipe(recentPrePullEvents)
    table.wipe(RTExt.recentDemonicPact)
    table.wipe(RTExt.lastDemonicPactConfirmedAt)
    table.wipe(RTExt.lastDemonicPactExpiry)
    table.wipe(RTExt.pendingDemonicPacts)
    RTExt.playerSelfDPContribution = 0
    RTExt.activeObservedDP = 0
    if RTExt.dpWatcherFrame then RTExt.dpWatcherFrame:SetScript("OnUpdate", nil) end

    EnsureTrashSegment()
    RequestMainViewRefresh()
end

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

    RTExt.zoneTimeAccum = RTExt.zoneTimeAccum + elapsed
    if RTExt.zoneTimeAccum >= 1.0 then
        local dt = RTExt.zoneTimeAccum
        RTExt.zoneTimeAccum = 0
        RTExt.UpdateSessionZoneTimes(dt)
    end

    RTExt.spPollAccum = RTExt.spPollAccum + elapsed
    if RTExt.spPollAccum >= 0.20 then
        RTExt.spPollAccum = 0
        if RTExt.SnapshotPlayerSpellPowerState then
            RTExt.SnapshotPlayerSpellPowerState()
        end
    end

    if not inCombatState then
        outOfCombatAccum = 0
        gracePeriodAccum = 0
        return
    end

    gracePeriodAccum = gracePeriodAccum + elapsed

    if activeBossName == "The Lich King" and lichKingRPActive then
        lichKingRPElapsed = lichKingRPElapsed + elapsed
        if IsRaidInCombat() then
            outOfCombatAccum = 0
            return
        end
        if lichKingRPElapsed < 240.0 then
            return
        end
    end

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

    if gracePeriodAccum < 5.0 then return end

    outOfCombatAccum = outOfCombatAccum + elapsed
    if outOfCombatAccum >= 3.5 then
        outOfCombatAccum = 0
        EndEncounter(false, "Boss Despawned / Wipe / Combat Ended")
    end
end)

-------------------------------------------------------------------------------
-- Segment Analysis Helpers (Duration, Pull Time, Buffs/Utility/Tank/Fails)
-------------------------------------------------------------------------------
local function IsWipeDeath(d, allSegmentDeaths)
    if not d then return false end
    if d.isScriptedRP then return true end
    local ab = StripColorCodes(d.ability or ""):lower()
    if ab:find("fury of frostmourne", 1, true) then
        return true
    end
    local pTime = d.pullTime
    if type(pTime) == "number" and allSegmentDeaths then
        local clusterCount = 0
        for _, other in ipairs(allSegmentDeaths) do
            if other and type(other.pullTime) == "number" then
                if math.abs(other.pullTime - pTime) <= 5.0 then
                    clusterCount = clusterCount + 1
                end
            end
        end
        if clusterCount >= 7 then
            return true
        end
    end
    return false
end

local function GetSegmentDuration(seg)
    if not seg then return 0 end
    if type(seg.duration) == "number" and seg.duration > 0 then
        return seg.duration
    end
    if seg.name then
        local m, s = seg.name:match("(%d+)m%s*(%d+)s")
        if m and s then
            return (tonumber(m) or 0) * 60 + (tonumber(s) or 0)
        end
    end
    if inCombatState and currentSession and currentSession.segments[1] == seg then
        return math.max(1, math.floor(GetTime() - bossStartTime))
    end
    return 0
end

local function FormatDurationShort(sec)
    sec = math.max(0, math.floor(tonumber(sec) or 0))
    return string.format("%dm %ds", math.floor(sec / 60), sec % 60)
end

local function FormatPullTime(pullSec)
    if type(pullSec) ~= "number" then return nil end
    local s = math.max(0, math.floor(pullSec))
    return string.format("+%02d:%02d", math.floor(s / 60), s % 60)
end

local function CollectPresentPlayersInSegment(seg)
    local presentMap = {}
    if not seg then return {}, presentMap end
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
    return presentList, presentMap
end

local function CountPlayerSpellUsage(entryMap, targetSpellName)
    if not entryMap then return 0 end
    local total = 0
    for rawKey, count in pairs(entryMap) do
        local clean = StripColorCodes(rawKey)
        local base = clean:match("^(.-)%s*%[.-%]$") or clean
        if base == targetSpellName then
            total = total + (tonumber(count) or 0)
        end
    end
    return total
end

local function GetPlayerConsumableStatus(seg, pName)
    local buffs = (seg and seg.potionsAndBuffs and seg.potionsAndBuffs[pName]) or {}
    local hasFlaskOrElixir = false
    local hasWellFed = false
    local combatPots = 0

    for rawKey, count in pairs(buffs) do
        local clean = StripColorCodes(rawKey)
        local base = clean:match("^(.-)%s*%[.-%]$") or clean
        if base:find("Flask") or base:find("Elixir") then
            hasFlaskOrElixir = true
        end
        if base:find("Well Fed") or base:find("Fish Feast") then
            hasWellFed = true
        end
        if COMBAT_POTION_NAMES[base] then
            combatPots = combatPots + (tonumber(count) or 0)
        end
    end
    return hasFlaskOrElixir, hasWellFed, combatPots
end

local function GetUnusedPersonalDefensives(seg, pName, pClass)
    local classUpper = string.upper(pClass or GetSafePlayerClass(pName) or "WARRIOR")
    local defList = PERSONAL_DEFENSIVES_BY_CLASS[classUpper] or {}
    local utilMap = (seg and seg.raidUtility and seg.raidUtility[pName]) or {}
    local buffMap = (seg and seg.potionsAndBuffs and seg.potionsAndBuffs[pName]) or {}
    local unused = {}
    for _, spellName in ipairs(defList) do
        local usedCount = CountPlayerSpellUsage(utilMap, spellName) + CountPlayerSpellUsage(buffMap, spellName)
        if usedCount == 0 then
            table.insert(unused, spellName)
        end
    end
    return unused
end

local function DetectSegmentTanks(seg, presentMap)
    local tanks = {}
    if not seg then return tanks end
    for tName, isTank in pairs(seg.tanks or {}) do
        if isTank then tanks[tName] = true end
    end
    for pName, uEntries in pairs(seg.raidUtility or {}) do
        for rawKey, count in pairs(uEntries) do
            if (tonumber(count) or 0) > 0 then
                local clean = StripColorCodes(rawKey)
                local base, target = clean:match("^(.-)%s*%[(.-)%]$")
                base = base or clean
                if TANK_TAUNT_NAMES[base] then
                    tanks[pName] = true
                end
                if (base == "Tricks of the Trade" or base == "Misdirection") and target and target ~= "" then
                    local tClass = presentMap[target] or string.upper(GetSafePlayerClass(target))
                    if tClass == "WARRIOR" or tClass == "PALADIN" or tClass == "DEATHKNIGHT" or tClass == "DRUID" or (seg.tanks and seg.tanks[target]) then
                        tanks[target] = true
                    end
                end
            end
        end
    end
    for pName, bEntries in pairs(seg.potionsAndBuffs or {}) do
        for rawKey, count in pairs(bEntries) do
            if (tonumber(count) or 0) > 0 then
                local clean = StripColorCodes(rawKey)
                local base = clean:match("^(.-)%s*%[.-%]$") or clean
                if TANK_PROC_NAMES[base] then
                    tanks[pName] = true
                elseif base == "Tricks of the Trade (+15% Dmg)" then
                    local pClass = presentMap[pName] or string.upper(GetSafePlayerClass(pName))
                    if pClass == "WARRIOR" or pClass == "PALADIN" or pClass == "DEATHKNIGHT" or pClass == "DRUID" or (seg.tanks and seg.tanks[pName]) then
                        tanks[pName] = true
                    end
                end
            end
        end
    end
    return tanks
end

local function CountMajorTankCooldowns(seg, pName)
    local utilMap = (seg and seg.raidUtility and seg.raidUtility[pName]) or {}
    local buffMap = (seg and seg.potionsAndBuffs and seg.potionsAndBuffs[pName]) or {}
    local total = 0
    local usedDetails = {}
    for _, cdName in ipairs(MAJOR_TANK_COOLDOWNS) do
        local c = CountPlayerSpellUsage(utilMap, cdName)
        if c == 0 and cdName == "Hand of Sacrifice" then
            c = CountPlayerSpellUsage(buffMap, cdName)
        end
        if c > 0 then
            total = total + c
            table.insert(usedDetails, string.format("%s x%d", cdName, c))
        end
    end
    return total, usedDetails
end

local function GetEnrageSummaryString(seg)
    if not seg or not seg.enrages or next(seg.enrages) == nil then
        return nil, 0
    end
    local parts = {}
    local totalEnrages = 0
    local mobs = {}
    for mName in pairs(seg.enrages) do table.insert(mobs, mName) end
    table.sort(mobs)
    for _, mName in ipairs(mobs) do
        local c = seg.enrages[mName] or 0
        if c > 0 then
            totalEnrages = totalEnrages + c
            table.insert(parts, string.format("%s Enraged %d %s", mName, c, (c == 1) and "time" or "times"))
        end
    end
    if #parts == 0 then return nil, 0 end
    return table.concat(parts, ", "), totalEnrages
end

function RTExt.FormatDemonicPactLine(indentPrefix, dpValues, fallbackCount)
    indentPrefix = indentPrefix or ""
    if type(dpValues) == "table" and #dpValues > 0 then
        return string.format("%sDemonic Pact (%d): %s", indentPrefix, #dpValues, table.concat(dpValues, ", "))
    end
    return string.format("%sDemonic Pact (%d)", indentPrefix, tonumber(fallbackCount) or 0)
end

function RTExt.IsPotionSummaryConsumable(rawName)
    if type(rawName) ~= "string" or rawName == "" then return false end
    local clean = StripColorCodes(rawName)
    local base = clean:match("^(.-)%s*%[.-%]$") or clean
    if base:find("Flask") or base:find("Elixir") or base:find("Well Fed") or base:find("Fish Feast") then
        return false
    end
    if COMBAT_POTION_NAMES[base] or RTExt.POTIONS_SUMMARY_EXTRA[base] then
        return true
    end
    if base:find("Potion") ~= nil or base:find("Injector") ~= nil then
        return true
    end
    return false
end

function RTExt.BuildBossPotionsReportText(activeSession)
    local sessionName = (activeSession and activeSession.name) or "Live Current Session"
    local segs = (activeSession and activeSession.segments) or {}

    local totalBossFights = 0
    local victories = 0
    local wipes = 0
    local playerPotions = {}
    local playerTotals = {}
    local playerClasses = {}
    local playerFights = {}
    local grandTotalPotions = 0

    for _, seg in ipairs(segs) do
        if seg and seg.isBoss then
            totalBossFights = totalBossFights + 1
            if seg.name and seg.name:find("Victory") then
                victories = victories + 1
            else
                wipes = wipes + 1
            end

            local presentList, presentMap = CollectPresentPlayersInSegment(seg)
            for _, pName in ipairs(presentList) do
                playerClasses[pName] = presentMap[pName] or playerClasses[pName] or string.upper(GetSafePlayerClass(pName))
                playerFights[pName] = (playerFights[pName] or 0) + 1
                playerTotals[pName] = playerTotals[pName] or 0
                playerPotions[pName] = playerPotions[pName] or {}
            end

            for pName, entries in pairs(seg.potionsAndBuffs or {}) do
                if not playerClasses[pName] then
                    playerClasses[pName] = string.upper((seg.players and seg.players[pName]) or GetSafePlayerClass(pName))
                end
                playerTotals[pName] = playerTotals[pName] or 0
                playerPotions[pName] = playerPotions[pName] or {}
                for rawKey, count in pairs(entries or {}) do
                    local c = tonumber(count) or 0
                    if c > 0 and RTExt.IsPotionSummaryConsumable(rawKey) then
                        local clean = StripColorCodes(rawKey)
                        local base = clean:match("^(.-)%s*%[.-%]$") or clean
                        playerPotions[pName][base] = (playerPotions[pName][base] or 0) + c
                        playerTotals[pName] = playerTotals[pName] + c
                        grandTotalPotions = grandTotalPotions + c
                    end
                end
            end
        end
    end

    local lines = {
        string.format("=== Raiders Tracker%s by %s - Boss Potions Summary ===", RTExt.GetVersionTag(), AUTHOR),
        string.format("Session: %s", sessionName),
        string.format("Total Boss Fights: %d (%d Victories, %d Wipes/Attempts)", totalBossFights, victories, wipes),
    }

    if totalBossFights == 0 then
        table.insert(lines, "")
        table.insert(lines, "No boss fights recorded in this session yet.")
        return table.concat(lines, "\n")
    end

    local sortedPlayers = {}
    for pName in pairs(playerTotals) do
        table.insert(sortedPlayers, {
            name = pName,
            class = playerClasses[pName] or "WARRIOR",
            total = playerTotals[pName] or 0,
            fights = playerFights[pName] or 0,
            items = playerPotions[pName] or {},
        })
    end
    table.sort(sortedPlayers, function(a, b)
        if a.total ~= b.total then return a.total > b.total end
        return a.name < b.name
    end)

    table.insert(lines, string.format("Total Players: %d | Total Potions Used: %d", #sortedPlayers, grandTotalPotions))
    table.insert(lines, "")

    if #sortedPlayers == 0 then
        table.insert(lines, "No players recorded in boss fights yet.")
    else
        for idx, p in ipairs(sortedPlayers) do
            local itemNames = {}
            for itemName in pairs(p.items) do
                table.insert(itemNames, itemName)
            end
            table.sort(itemNames)
            local detailStr = "None"
            if #itemNames > 0 then
                local parts = {}
                for _, itemName in ipairs(itemNames) do
                    table.insert(parts, string.format("%s: %d", itemName, p.items[itemName]))
                end
                detailStr = table.concat(parts, ", ")
            end
            local fightWord = (p.fights == 1) and "fight" or "fights"
            table.insert(lines, string.format(
                "%d. %s (%s) - %d total [%d/%d %s] (%s)",
                idx, p.name, p.class, p.total, p.fights, totalBossFights, fightWord, detailStr
            ))
        end
    end

    return table.concat(lines, "\n")
end

local function BuildCondensedEntryLines(entryMap, indentPrefix, dpValues)
    indentPrefix = indentPrefix or ""
    if not entryMap or next(entryMap) == nil then return {} end
    local grouped = {}
    local groupOrder = {}
    for rawKey, count in pairs(entryMap) do
        local c = tonumber(count) or 0
        if c > 0 then
            local clean = StripColorCodes(rawKey)
            local base, target = clean:match("^(.-)%s*%[(.-)%]$")
            if base and target then
                if not grouped[base] then
                    grouped[base] = { total = 0, targets = {}, targetCount = 0, isTargeted = true }
                    table.insert(groupOrder, base)
                end
                grouped[base].total = grouped[base].total + c
                if not grouped[base].targets[target] then
                    grouped[base].targetCount = grouped[base].targetCount + 1
                end
                grouped[base].targets[target] = (grouped[base].targets[target] or 0) + c
            else
                if not grouped[clean] then
                    grouped[clean] = { total = 0, targets = {}, targetCount = 0, isTargeted = false }
                    table.insert(groupOrder, clean)
                end
                grouped[clean].total = grouped[clean].total + c
            end
        end
    end
    table.sort(groupOrder)
    local out = {}
    for _, base in ipairs(groupOrder) do
        local info = grouped[base]
        if info.isTargeted then
            if base == "Power Word: Shield" or info.targetCount > 3 then
                table.insert(out, string.format("%s%s: %d casts (across %d %s)", indentPrefix, base, info.total, info.targetCount, (info.targetCount == 1) and "target" or "targets"))
            else
                local tNames = {}
                for tName in pairs(info.targets) do table.insert(tNames, tName) end
                table.sort(tNames)
                for _, tName in ipairs(tNames) do
                    table.insert(out, string.format("%s%s [%s]: %d", indentPrefix, base, tName, info.targets[tName]))
                end
            end
        elseif base == "Demonic Pact" and type(dpValues) == "table" and #dpValues > 0 then
            table.insert(out, RTExt.FormatDemonicPactLine(indentPrefix, dpValues, info.total))
        else
            table.insert(out, string.format("%s%s: %d", indentPrefix, base, info.total))
        end
    end
    return out
end

local function BuildStandardRaidHeaderLines(seg)
    local segName = (seg and seg.name) or "TRASH"
    local segDiff = (seg and seg.difficulty) or GetRaidDifficultySuffix()
    return {
        string.format("=== Raiders Tracker%s by %s ===", RTExt.GetVersionTag(), AUTHOR),
        GITHUB_URL,
        string.format("Segment: %s (%s)", segName, segDiff)
    }
end

-------------------------------------------------------------------------------
-- UI Management, Zero-Taint Custom Dropdowns & Render Engines
-------------------------------------------------------------------------------
local MainTrackerFrame = nil
local ConfigFrame = nil
local CharacterFrame = nil
local ReportFrame = nil
local DeathsFrame = nil
local DeathLogFrame = nil
local BlacklistFrame = nil
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
local RefreshBlacklistView = function() end

local function WipeLiveSessionOnly()
    selectedSessionIndex = 0
    selectedSegmentIndex = 1
    segmentPage = 1
    selectedDeathPlayer = nil
    ResetLiveSessionState()
    RefreshMainView()
    RefreshCharactersView()
    RefreshDeathsView()
    RefreshDeathLogView()
    RefreshBlacklistView()
    AnnounceLocalChat("Live Current Session refreshed (Saved Sessions preserved).")
end

local function WipeAllSessionsAndData()
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
    RefreshBlacklistView()
    AnnounceLocalChat("All encounter sessions and recorded data cleared (Blacklist preserved).")
end

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
    if BlacklistFrame then BlacklistFrame:Hide() end
    if RTExt.BlacklistExportFrame then RTExt.BlacklistExportFrame:Hide() end
    if RTExt.BlacklistImportFrame then RTExt.BlacklistImportFrame:Hide() end
    if RTExt.BlacklistTextFrame then RTExt.BlacklistTextFrame:Hide() end
    if RTExt.CharacterExportFrame then RTExt.CharacterExportFrame:Hide() end
    if RTExt.PotionsFrame then RTExt.PotionsFrame:Hide() end
end

local function ResetAllPanelPositions()
    local panels = {
        MainTrackerFrame, ConfigFrame, CharacterFrame, RTExt.CharacterExportFrame,
        ReportFrame, DeathsFrame, DeathLogFrame,
        BlacklistFrame, RTExt.BlacklistExportFrame, RTExt.BlacklistImportFrame, RTExt.BlacklistTextFrame,
        RTExt.PotionsFrame
    }
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
        if existing == frameName then found = true; break end
    end
    if not found then tinsert(UISpecialFrames, frameName) end
end

local function CreateWhiteBorderViewBox(parent, topOffsetY, bottomOffsetY)
    local box = CreateFrame("Frame", nil, parent)
    box:SetPoint("TOPLEFT", parent, "TOPLEFT", 18, topOffsetY or -132)
    box:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -18, bottomOffsetY or 40)
    box:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    box:SetBackdropColor(0.04, 0.04, 0.06, 0.92)
    box:SetBackdropBorderColor(1.0, 1.0, 1.0, 0.95)
    return box
end

local function CreateCustomDropdown(parent, width, height)
    local dropdown = CreateFrame("Button", nil, parent)
    dropdown:SetSize(width, height or 24)
    dropdown:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 1,
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
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    menuFrame:SetBackdropColor(0.05, 0.05, 0.08, 0.98)
    menuFrame:SetBackdropBorderColor(1.0, 1.0, 1.0, 0.95)
    menuFrame:EnableMouse(true)
    menuFrame:Hide()

    table.insert(activeCustomMenus, menuFrame)

    local optionButtons = {}
    local maxRows = 30
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

    dropdown:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0) end)
    dropdown:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.85, 0.85, 0.85, 0.90) end)

    dropdown:SetScript("OnClick", function(self)
        if menuFrame:IsShown() then menuFrame:Hide(); return end
        HideAllCustomDropdownMenus()
        if not self.getItems then return end
        local items = self.getItems() or {}
        for i = 1, maxRows do optionButtons[i]:Hide() end
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

RequestMainViewRefresh = function()
    if not MainTrackerFrame or not MainTrackerFrame:IsShown() then return end
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

StaticPopupDialogs["RT_REFRESH_ON_GROUP_JOIN"] = {
    text = "|cff00FF00" .. ADDON_NAME .. "|r\n\nDo you want to Refresh Raiders Tracker?\n\nClicking Accept will clear the current Live Session (Saved Sessions will be kept).",
    button1 = ACCEPT,
    button2 = CANCEL,
    OnAccept = function() WipeLiveSessionOnly() end,
    OnCancel = function() end,
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
    btnReport:SetSize(90, 24)
    btnReport:SetPoint("LEFT", btnNextPage, "RIGHT", 10, 0)
    btnReport:SetText("Report Seg")
    btnReport:SetScript("OnClick", function() CloseAllPanels(); ReportFrame:Show() end)

    local btnBlacklistHub = CreateFrame("Button", nil, MainTrackerFrame, "UIPanelButtonTemplate")
    btnBlacklistHub:SetSize(85, 24)
    btnBlacklistHub:SetPoint("LEFT", btnReport, "RIGHT", 6, 0)
    btnBlacklistHub:SetText("Blacklist")
    btnBlacklistHub:SetScript("OnClick", function() CloseAllPanels(); BlacklistFrame:Show() end)

    local btnCharacters = CreateFrame("Button", nil, MainTrackerFrame, "UIPanelButtonTemplate")
    btnCharacters:SetSize(100, 22)
    btnCharacters:SetPoint("TOPLEFT", MainTrackerFrame, "TOPLEFT", 18, -103)
    btnCharacters:SetText("Characters")
    btnCharacters:SetScript("OnClick", function() CloseAllPanels(); CharacterFrame:Show() end)

    local btnSaveSession = CreateFrame("Button", nil, MainTrackerFrame, "UIPanelButtonTemplate")
    btnSaveSession:SetSize(100, 22)
    btnSaveSession:SetPoint("LEFT", btnCharacters, "RIGHT", 6, 0)
    btnSaveSession:SetText("Save Session")

    local btnDeleteSeg = CreateFrame("Button", nil, MainTrackerFrame, "UIPanelButtonTemplate")
    btnDeleteSeg:SetSize(90, 22)
    btnDeleteSeg:SetPoint("LEFT", btnSaveSession, "RIGHT", 6, 0)
    btnDeleteSeg:SetText("Delete Seg")

    local btnConfig = CreateFrame("Button", nil, MainTrackerFrame, "UIPanelButtonTemplate")
    btnConfig:SetSize(85, 22)
    btnConfig:SetPoint("LEFT", btnDeleteSeg, "RIGHT", 6, 0)
    btnConfig:SetText("Config")
    btnConfig:SetScript("OnClick", function() CloseAllPanels(); ConfigFrame:Show() end)

    local btnDeaths = CreateFrame("Button", nil, MainTrackerFrame, "UIPanelButtonTemplate")
    btnDeaths:SetSize(85, 22)
    btnDeaths:SetPoint("LEFT", btnConfig, "RIGHT", 6, 0)
    btnDeaths:SetText("Deaths")
    btnDeaths:SetScript("OnClick", function() CloseAllPanels(); DeathsFrame:Show() end)

    local btnPotionsPanel = CreateFrame("Button", nil, MainTrackerFrame, "UIPanelButtonTemplate")
    btnPotionsPanel:SetSize(90, 22)
    btnPotionsPanel:SetPoint("LEFT", btnDeaths, "RIGHT", 6, 0)
    btnPotionsPanel:SetText("Potions")
    btnPotionsPanel:SetScript("OnClick", function() CloseAllPanels(); RTExt.PotionsFrame:Show() end)

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
                            local dpVals = (currentView == "UTILITY" and entry.name == "Demonic Pact" and seg.demonicPactValues) and seg.demonicPactValues[pName] or nil
                            if type(dpVals) == "table" and #dpVals > 0 then
                                fontStrings[lineIndex]:SetText(string.format("   |cff808080-|r Demonic Pact (|cff00FF00%d|r): |cffFFD100%s|r", #dpVals, table.concat(dpVals, ", ")))
                            else
                                fontStrings[lineIndex]:SetText(string.format("   |cff808080-|r %s: |cff00FF00%d|r", entry.name, entry.count))
                            end
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

        for i = lineIndex, 1500 do fontStrings[i]:Hide() end

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
        if segmentPage > 1 then segmentPage = segmentPage - 1; RefreshMainView() end
    end)

    btnNextPage:SetScript("OnClick", function()
        HideAllCustomDropdownMenus()
        local activeSession = GetActiveSession()
        local totalPages = math.ceil(#(activeSession.segments or {}) / 25)
        if segmentPage < totalPages then segmentPage = segmentPage + 1; RefreshMainView() end
    end)

    MainTrackerFrame:SetScript("OnShow", function()
        HideAllCustomDropdownMenus()
        EnsureTrashSegment()
        RefreshMainView()
    end)
end

-------------------------------------------------------------------------------
-- Boss Potions Summary Panel Implementation
-------------------------------------------------------------------------------
function RTExt.CreatePotionsFrame()
    local frame = CreateRUTPanel("RTPotionsFrame", 640, 480, "Boss Fights Potions")
    RTExt.PotionsFrame = frame

    local currentText = ""

    local infoLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -36)
    infoLabel:SetText("All potions, Flame Caps, Thistle Tea & combat consumables across all boss fights (Ctrl+A, Ctrl+C):")

    local viewBox = CreateWhiteBorderViewBox(frame, -58, 46)

    local scrollFrame = CreateFrame("ScrollFrame", "RTPotionsScrollFrame", viewBox, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", viewBox, "TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", viewBox, "BOTTOMRIGHT", -28, 8)

    local editBox = CreateFrame("EditBox", "RTPotionsEditBox", scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    if editBox.SetMaxLetters then editBox:SetMaxLetters(0) end
    if editBox.SetMaxBytes then editBox:SetMaxBytes(0) end
    editBox:SetFontObject(GameFontHighlightSmall)
    editBox:SetWidth(560)
    editBox:SetHeight(330)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        frame:Hide()
    end)
    editBox:SetScript("OnChar", function(self)
        self:SetText(currentText)
    end)
    scrollFrame:SetScrollChild(editBox)

    viewBox:EnableMouse(true)
    viewBox:SetScript("OnMouseDown", function() editBox:SetFocus() end)
    scrollFrame:EnableMouse(true)
    scrollFrame:SetScript("OnMouseDown", function() editBox:SetFocus() end)

    local btnSelectAll = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    btnSelectAll:SetSize(115, 24)
    btnSelectAll:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 14)
    btnSelectAll:SetText("Select All")
    btnSelectAll:SetScript("OnClick", function()
        editBox:SetFocus()
        editBox:HighlightText()
    end)

    local btnBackMain = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    btnBackMain:SetSize(130, 24)
    btnBackMain:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 14)
    btnBackMain:SetText("Cancel/Back")
    btnBackMain:SetScript("OnClick", function()
        CloseAllPanels()
        MainTrackerFrame:Show()
    end)

    frame:SetScript("OnShow", function()
        local activeSession = GetActiveSession()
        currentText = RTExt.BuildBossPotionsReportText(activeSession)
        editBox:SetText(currentText)
        if scrollFrame.UpdateScrollChildRect then scrollFrame:UpdateScrollChildRect() end
        scrollFrame:SetVerticalScroll(0)
        editBox:SetFocus()
        editBox:HighlightText()
    end)
end

-------------------------------------------------------------------------------
-- Blacklist Panel Implementation
-------------------------------------------------------------------------------
local function CreateBlacklistFrame()
    BlacklistFrame = CreateRUTPanel("RTBlacklistFrame", 620, 480, "Player Blacklist")

    local btnExportBL = CreateFrame("Button", nil, BlacklistFrame, "UIPanelButtonTemplate")
    btnExportBL:SetSize(135, 24)
    btnExportBL:SetPoint("TOPLEFT", BlacklistFrame, "TOPLEFT", 18, -36)
    btnExportBL:SetText("Export Blacklist")
    btnExportBL:SetScript("OnClick", function() CloseAllPanels(); RTExt.BlacklistExportFrame:Show() end)

    local btnImportBL = CreateFrame("Button", nil, BlacklistFrame, "UIPanelButtonTemplate")
    btnImportBL:SetSize(135, 24)
    btnImportBL:SetPoint("LEFT", btnExportBL, "RIGHT", 10, 0)
    btnImportBL:SetText("Import Blacklist")
    btnImportBL:SetScript("OnClick", function() CloseAllPanels(); RTExt.BlacklistImportFrame:Show() end)

    local btnCopyTextBL = CreateFrame("Button", nil, BlacklistFrame, "UIPanelButtonTemplate")
    btnCopyTextBL:SetSize(135, 24)
    btnCopyTextBL:SetPoint("LEFT", btnImportBL, "RIGHT", 10, 0)
    btnCopyTextBL:SetText("Copy as Text")
    btnCopyTextBL:SetScript("OnClick", function() CloseAllPanels(); RTExt.BlacklistTextFrame:Show() end)

    local btnBack = CreateFrame("Button", nil, BlacklistFrame, "UIPanelButtonTemplate")
    btnBack:SetSize(130, 24)
    btnBack:SetPoint("BOTTOM", BlacklistFrame, "BOTTOM", 0, 14)
    btnBack:SetText("Back to Tracker")
    btnBack:SetScript("OnClick", function() CloseAllPanels(); MainTrackerFrame:Show() end)

    local viewBox = CreateWhiteBorderViewBox(BlacklistFrame, -68, 46)

    local scrollFrame = CreateFrame("ScrollFrame", "RTBlacklistScrollFrame", viewBox, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", viewBox, "TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", viewBox, "BOTTOMRIGHT", -28, 8)

    local scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetSize(540, 350)
    scrollFrame:SetScrollChild(scrollContent)

    local emptyLabel = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    emptyLabel:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 8, -8)
    emptyLabel:SetText("|cff999999No players currently blacklisted.|r")
    emptyLabel:Hide()

    local rows = {}
    for i = 1, 100 do
        local row = CreateFrame("Frame", nil, scrollContent)
        row:SetSize(540, 42)
        row:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 4, -((i - 1) * 42) - 4)

        local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("TOPLEFT", row, "TOPLEFT", 6, -2)
        text:SetPoint("RIGHT", row, "RIGHT", -90, 0)
        text:SetJustifyH("LEFT")
        text:SetWordWrap(true)

        local btnRemove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        btnRemove:SetSize(75, 22)
        btnRemove:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        btnRemove:SetText("Remove")
        btnRemove:RegisterForClicks("LeftButtonUp")
        btnRemove:SetScript("OnClick", function(self)
            if self.targetID and RaidersTrackerDB.blacklist then
                RaidersTrackerDB.blacklist[self.targetID] = nil
                AnnounceLocalChat("Removed player from blacklist.")
                RefreshBlacklistView()
            end
        end)

        row.text = text
        row.btnRemove = btnRemove
        row:Hide()
        rows[i] = row
    end

    RefreshBlacklistView = function()
        if not BlacklistFrame or not BlacklistFrame:IsShown() then return end
        RaidersTrackerDB.blacklist = RaidersTrackerDB.blacklist or {}

        local list = {}
        for charID, info in pairs(RaidersTrackerDB.blacklist) do
            local nameList = {}
            if info.names then
                for n in pairs(info.names) do table.insert(nameList, n) end
                table.sort(nameList)
            elseif info.name then
                table.insert(nameList, info.name)
            end
            local namesStr = (#nameList > 0) and table.concat(nameList, ", ") or "Unknown"
            local classStr = info.class and (" (" .. info.class .. ")") or ""
            table.insert(list, {
                id = charID,
                namesStr = namesStr,
                classStr = classStr,
                reason = info.reason or "Unspecified",
                date = info.timestamp or ""
            })
        end
        table.sort(list, function(a, b) return a.namesStr < b.namesStr end)

        if #list == 0 then
            for i = 1, 100 do rows[i]:Hide() end
            emptyLabel:Show()
            scrollContent:SetHeight(340)
            return
        end

        emptyLabel:Hide()
        local shownCount = math.min(#list, 100)
        for idx = 1, shownCount do
            local item = list[idx]
            rows[idx].text:SetText(string.format("ID: |cff00FF00[%s]|r Names: |cffFFFF00%s|r%s\nReason: |cffFFD100%s|r (%s)", item.id, item.namesStr, item.classStr, item.reason, item.date))
            rows[idx].btnRemove.targetID = item.id
            if not rows[idx]:IsShown() then rows[idx]:Show() end
        end
        for idx = shownCount + 1, 100 do rows[idx]:Hide() end
        scrollContent:SetHeight(math.max(340, shownCount * 42 + 12))
    end

    BlacklistFrame:SetScript("OnShow", RefreshBlacklistView)
end

function RTExt.CreateBlacklistExportFrame()
    local frame = CreateRUTPanel("RTBlacklistExportFrame", 620, 440, "Export Blacklist")
    RTExt.BlacklistExportFrame = frame

    local currentExportText = ""

    local infoLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -36)
    infoLabel:SetText("Base64 XML backup of your blacklist (Ctrl+A, Ctrl+C to copy):")

    local statusLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -52)

    local viewBox = CreateWhiteBorderViewBox(frame, -72, 46)

    local scrollFrame = CreateFrame("ScrollFrame", "RTBlacklistExportScrollFrame", viewBox, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", viewBox, "TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", viewBox, "BOTTOMRIGHT", -28, 8)

    local editBox = CreateFrame("EditBox", "RTBlacklistExportEditBox", scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    if editBox.SetMaxLetters then editBox:SetMaxLetters(0) end
    if editBox.SetMaxBytes then editBox:SetMaxBytes(0) end
    editBox:SetFontObject(GameFontHighlightSmall)
    editBox:SetWidth(540)
    editBox:SetHeight(280)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        frame:Hide()
    end)
    editBox:SetScript("OnChar", function(self)
        self:SetText(currentExportText)
    end)
    scrollFrame:SetScrollChild(editBox)

    viewBox:EnableMouse(true)
    viewBox:SetScript("OnMouseDown", function() editBox:SetFocus() end)

    local btnSelectAll = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    btnSelectAll:SetSize(115, 24)
    btnSelectAll:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 14)
    btnSelectAll:SetText("Select All")
    btnSelectAll:SetScript("OnClick", function()
        editBox:SetFocus()
        editBox:HighlightText()
    end)

    local btnBackBL = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    btnBackBL:SetSize(135, 24)
    btnBackBL:SetPoint("LEFT", btnSelectAll, "RIGHT", 10, 0)
    btnBackBL:SetText("Back to Blacklist")
    btnBackBL:SetScript("OnClick", function() CloseAllPanels(); BlacklistFrame:Show() end)

    local btnBackTracker = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    btnBackTracker:SetSize(130, 24)
    btnBackTracker:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 14)
    btnBackTracker:SetText("Back to Tracker")
    btnBackTracker:SetScript("OnClick", function() CloseAllPanels(); MainTrackerFrame:Show() end)

    frame:SetScript("OnShow", function()
        local b64, count = RTExt.ExportBlacklistToBase64XML()
        currentExportText = b64 or ""
        if count == 0 then
            statusLabel:SetText("|cffFFFF00Your blacklist is currently empty (0 entries exported).|r")
        else
            statusLabel:SetText(string.format("|cff00FF00Ready to share: %d %s exported (%d Base64 characters).|r", count, (count == 1) and "entry" or "entries", #currentExportText))
        end
        editBox:SetText(currentExportText)
        if scrollFrame.UpdateScrollChildRect then scrollFrame:UpdateScrollChildRect() end
        scrollFrame:SetVerticalScroll(0)
        editBox:SetFocus()
        editBox:HighlightText()
    end)
end

function RTExt.CreateBlacklistImportFrame()
    local frame = CreateRUTPanel("RTBlacklistImportFrame", 620, 460, "Import Blacklist")
    RTExt.BlacklistImportFrame = frame

    local infoLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -36)
    infoLabel:SetText("Paste Base64 blacklist data exported from Raiders Tracker below (Ctrl+V):")

    local statusLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -52)
    statusLabel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, -52)
    statusLabel:SetJustifyH("LEFT")
    statusLabel:SetWordWrap(true)
    statusLabel:SetText("|cffCCCCCCPaste data and click Verify or Import.|r")

    local viewBox = CreateWhiteBorderViewBox(frame, -82, 46)

    local scrollFrame = CreateFrame("ScrollFrame", "RTBlacklistImportScrollFrame", viewBox, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", viewBox, "TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", viewBox, "BOTTOMRIGHT", -28, 8)

    local editBox = CreateFrame("EditBox", "RTBlacklistImportEditBox", scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    if editBox.SetMaxLetters then editBox:SetMaxLetters(0) end
    if editBox.SetMaxBytes then editBox:SetMaxBytes(0) end
    editBox:SetFontObject(GameFontHighlightSmall)
    editBox:SetWidth(540)
    editBox:SetHeight(290)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        frame:Hide()
    end)
    editBox:SetScript("OnTextChanged", function()
        if scrollFrame.UpdateScrollChildRect then scrollFrame:UpdateScrollChildRect() end
    end)
    scrollFrame:SetScrollChild(editBox)

    viewBox:EnableMouse(true)
    viewBox:SetScript("OnMouseDown", function() editBox:SetFocus() end)
    scrollFrame:EnableMouse(true)
    scrollFrame:SetScript("OnMouseDown", function() editBox:SetFocus() end)

    local btnVerify = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    btnVerify:SetSize(100, 24)
    btnVerify:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 14)
    btnVerify:SetText("Verify")

    local btnImport = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    btnImport:SetSize(110, 24)
    btnImport:SetPoint("LEFT", btnVerify, "RIGHT", 8, 0)
    btnImport:SetText("Import")

    local btnClear = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    btnClear:SetSize(80, 24)
    btnClear:SetPoint("LEFT", btnImport, "RIGHT", 8, 0)
    btnClear:SetText("Clear")

    local btnBackBL = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    btnBackBL:SetSize(135, 24)
    btnBackBL:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 14)
    btnBackBL:SetText("Back to Blacklist")
    btnBackBL:SetScript("OnClick", function() CloseAllPanels(); BlacklistFrame:Show() end)

    btnClear:SetScript("OnClick", function()
        editBox:SetText("")
        statusLabel:SetText("|cffCCCCCCCleared. Paste Base64 data and click Verify or Import.|r")
        editBox:SetFocus()
    end)

    btnVerify:SetScript("OnClick", function()
        local raw = editBox:GetText() or ""
        local entries, err = RTExt.ParseAndValidateBlacklistImport(raw)
        if not entries then
            statusLabel:SetText("|cffFFFF00WARNING: " .. tostring(err) .. "|r")
            return
        end
        if #entries == 0 then
            statusLabel:SetText("|cffFFFF00Valid Raiders Tracker format, but contains 0 blacklist entries.|r")
            return
        end
        local impCnt, dupCnt, newNamesCnt = RTExt.ProcessBlacklistImport(entries, true)
        local extraStr = (newNamesCnt > 0) and string.format(", %d new name(s) for existing IDs", newNamesCnt) or ""
        statusLabel:SetText(string.format("|cff00FF00Valid data! Ready to import: %d new, %d duplicates to omit%s.|r", impCnt, dupCnt, extraStr))
    end)

    btnImport:SetScript("OnClick", function()
        local raw = editBox:GetText() or ""
        local entries, err = RTExt.ParseAndValidateBlacklistImport(raw)
        if not entries then
            local warn = "Blacklist Import Failed - " .. tostring(err)
            statusLabel:SetText("|cffFFFF00WARNING: " .. tostring(err) .. "|r")
            if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00[Raiders Tracker] " .. warn .. "|r")
            end
            return
        end
        if #entries == 0 then
            statusLabel:SetText("|cffFFFF00Valid Raiders Tracker format, but 0 entries were present to import.|r")
            return
        end
        local impCnt, dupCnt, newNamesCnt = RTExt.ProcessBlacklistImport(entries, false)
        local extraStr = (newNamesCnt > 0) and string.format(", %d new name(s) added to existing IDs", newNamesCnt) or ""
        local summary = string.format("Import complete: %d imported, %d duplicates omitted%s.", impCnt, dupCnt, extraStr)
        statusLabel:SetText("|cff00FF00" .. summary .. "|r")
        AnnounceLocalChat(summary)
        if BlacklistFrame and BlacklistFrame:IsShown() then
            RefreshBlacklistView()
        end
    end)

    frame:SetScript("OnShow", function()
        editBox:SetText("")
        statusLabel:SetText("|cffCCCCCCPaste Base64 data exported from Raiders Tracker and click Verify or Import.|r")
        if scrollFrame.UpdateScrollChildRect then scrollFrame:UpdateScrollChildRect() end
        scrollFrame:SetVerticalScroll(0)
        editBox:SetFocus()
    end)
end

function RTExt.CreateBlacklistTextFrame()
    local frame = CreateRUTPanel("RTBlacklistTextFrame", 620, 440, "Copy Blacklist as Text")
    RTExt.BlacklistTextFrame = frame

    local currentText = ""

    local infoLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -36)
    infoLabel:SetText("Plain-text blacklist ready to copy (Ctrl+A, Ctrl+C):")

    local viewBox = CreateWhiteBorderViewBox(frame, -58, 46)

    local scrollFrame = CreateFrame("ScrollFrame", "RTBlacklistTextScrollFrame", viewBox, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", viewBox, "TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", viewBox, "BOTTOMRIGHT", -28, 8)

    local editBox = CreateFrame("EditBox", "RTBlacklistTextEditBox", scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    if editBox.SetMaxLetters then editBox:SetMaxLetters(0) end
    if editBox.SetMaxBytes then editBox:SetMaxBytes(0) end
    editBox:SetFontObject(GameFontHighlightSmall)
    editBox:SetWidth(540)
    editBox:SetHeight(290)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        frame:Hide()
    end)
    editBox:SetScript("OnChar", function(self)
        self:SetText(currentText)
    end)
    scrollFrame:SetScrollChild(editBox)

    viewBox:EnableMouse(true)
    viewBox:SetScript("OnMouseDown", function() editBox:SetFocus() end)

    local btnSelectAll = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    btnSelectAll:SetSize(115, 24)
    btnSelectAll:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 14)
    btnSelectAll:SetText("Select All")
    btnSelectAll:SetScript("OnClick", function()
        editBox:SetFocus()
        editBox:HighlightText()
    end)

    local btnBackBL = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    btnBackBL:SetSize(135, 24)
    btnBackBL:SetPoint("LEFT", btnSelectAll, "RIGHT", 10, 0)
    btnBackBL:SetText("Back to Blacklist")
    btnBackBL:SetScript("OnClick", function() CloseAllPanels(); BlacklistFrame:Show() end)

    local btnBackTracker = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    btnBackTracker:SetSize(130, 24)
    btnBackTracker:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 14)
    btnBackTracker:SetText("Back to Tracker")
    btnBackTracker:SetScript("OnClick", function() CloseAllPanels(); MainTrackerFrame:Show() end)

    frame:SetScript("OnShow", function()
        currentText = RTExt.BuildBlacklistPlainText()
        editBox:SetText(currentText)
        if scrollFrame.UpdateScrollChildRect then scrollFrame:UpdateScrollChildRect() end
        scrollFrame:SetVerticalScroll(0)
        editBox:SetFocus()
        editBox:HighlightText()
    end)
end

-------------------------------------------------------------------------------
-- Deaths Panel & Death Log Panel Implementation
-------------------------------------------------------------------------------
local function CollectDeathsForActiveScope()
    local activeSession = GetActiveSession()
    local segments = (activeSession and activeSession.segments) or {}
    local deathsByPlayer = {}
    local playerClasses = {}

    if deathsScopeAllSession then
        for _, seg in ipairs(segments) do
            for pName, pClass in pairs(seg.players or {}) do playerClasses[pName] = pClass end
            for pName, dList in pairs(seg.deaths or {}) do
                if type(dList) == "table" and #dList > 0 then
                    deathsByPlayer[pName] = deathsByPlayer[pName] or {}
                    for _, dEntry in ipairs(dList) do table.insert(deathsByPlayer[pName], dEntry) end
                end
            end
        end
    else
        local seg = segments[selectedSegmentIndex]
        if seg then
            for pName, pClass in pairs(seg.players or {}) do playerClasses[pName] = pClass end
            for pName, dList in pairs(seg.deaths or {}) do
                if type(dList) == "table" and #dList > 0 then
                    deathsByPlayer[pName] = deathsByPlayer[pName] or {}
                    for _, dEntry in ipairs(dList) do table.insert(deathsByPlayer[pName], dEntry) end
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
            if a.count ~= b.count then return a.count > b.count end
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
            rows[idx].text:SetText(string.format("%d. %s  |cffFFFF00(%d %s)|r", idx, ColorizeText(item.name, hexColor), item.count, deathWord))
            rows[idx].btnLog.playerName = item.name
            if not rows[idx]:IsShown() then rows[idx]:Show() end
        end
        for idx = shownCount + 1, 100 do rows[idx]:Hide() end
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

        headerLabel:SetText(string.format("Detailed Death Log for %s  |cffFFFF00(%d Total)|r", ColorizeText(pName, hexColor), #pDeaths))

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
            local pullStr = FormatPullTime(d.pullTime)
            local timeStampDisplay = pullStr and string.format("%s into pull / %s", pullStr, timeStr) or timeStr

            local dmgText = (amount > 0) and string.format("%d dmg", amount) or "Fatal Effect"
            if overkill > 0 then
                dmgText = string.format("%d dmg (%d overkill)", amount, overkill)
            end

            logLines[idx]:SetText(string.format(
                "%d. |cff888888[%s - %s]|r Killed by |cffFFFF00%s|r  |  Ability: |cffFFD100%s|r  |  Damage: |cffFFFF00%s|r",
                idx, timeStampDisplay, segLabel, killer, ability, dmgText
            ))
            logLines[idx]:Show()
        end
        for idx = shownCount + 1, 300 do logLines[idx]:Hide() end
        scrollContent:SetHeight(math.max(340, shownCount * 20 + 16))
    end

    DeathLogFrame:SetScript("OnShow", RefreshDeathLogView)
end

-------------------------------------------------------------------------------
-- Character Panel Implementation (With Multi-Name History & Class Blacklisting)
-------------------------------------------------------------------------------
function RTExt.CountActiveSessionPlayers(activeSession, playerMap)
    if not activeSession or activeSession ~= currentSession then
        return 0
    end
    local activeSet = {}
    local numRaid = GetNumRaidMembers()
    if numRaid > 0 then
        for i = 1, numRaid do
            local rName, _, _, _, _, rFileName, _, rOnline = GetRaidRosterInfo(i)
            if rName and rName ~= UNKNOWN then
                local shortName = rName:match("^([^%-]+)") or rName
                if playerMap and not playerMap[shortName] then
                    playerMap[shortName] = (rFileName and rFileName ~= "") and rFileName or GetSafePlayerClass(shortName)
                end
                if rOnline then
                    activeSet[shortName] = true
                end
            end
        end
    else
        local numParty = GetNumPartyMembers()
        if numParty > 0 then
            local myName = UnitName("player")
            if myName and myName ~= UNKNOWN then
                if playerMap and not playerMap[myName] then
                    playerMap[myName] = GetSafePlayerClass(myName)
                end
                activeSet[myName] = true
            end
            for i = 1, numParty do
                local unit = "party" .. i
                if UnitExists(unit) then
                    local pName = UnitName(unit)
                    if pName and pName ~= UNKNOWN then
                        if playerMap and not playerMap[pName] then
                            playerMap[pName] = GetSafePlayerClass(pName)
                        end
                        if UnitIsConnected(unit) then
                            activeSet[pName] = true
                        end
                    end
                end
            end
        end
    end
    local count = 0
    for _ in pairs(activeSet) do count = count + 1 end
    return count
end

local function CreateCharacterFrame()
    CharacterFrame = CreateRUTPanel("RTCharacterFrame", 580, 440, "Session Characters")

    local playerCountLabel = CharacterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    playerCountLabel:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 18, -34)
    playerCountLabel:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", -18, -34)
    playerCountLabel:SetJustifyH("LEFT")

    local zoneHeaderLabel = CharacterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    zoneHeaderLabel:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 18, -50)
    zoneHeaderLabel:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", -18, -50)
    zoneHeaderLabel:SetJustifyH("LEFT")

    local btnExportChars = CreateFrame("Button", nil, CharacterFrame, "UIPanelButtonTemplate")
    btnExportChars:SetSize(145, 24)
    btnExportChars:SetPoint("BOTTOMLEFT", CharacterFrame, "BOTTOMLEFT", 18, 14)
    btnExportChars:SetText("Export Characters")
    btnExportChars:SetScript("OnClick", function() CloseAllPanels(); RTExt.CharacterExportFrame:Show() end)

    local btnBack = CreateFrame("Button", nil, CharacterFrame, "UIPanelButtonTemplate")
    btnBack:SetSize(130, 24)
    btnBack:SetPoint("BOTTOMRIGHT", CharacterFrame, "BOTTOMRIGHT", -18, 14)
    btnBack:SetText("Back to Tracker")
    btnBack:SetScript("OnClick", function() CloseAllPanels(); MainTrackerFrame:Show() end)

    local viewBox = CreateWhiteBorderViewBox(CharacterFrame, -68, 46)

    local scrollFrame = CreateFrame("ScrollFrame", "RTCharScrollFrame", viewBox, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", viewBox, "TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", viewBox, "BOTTOMRIGHT", -28, 8)

    local scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetSize(500, 340)
    scrollFrame:SetScrollChild(scrollContent)

    local emptyLabel = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    emptyLabel:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 8, -8)
    emptyLabel:SetText("|cff999999No characters recorded in this session yet.|r")
    emptyLabel:Hide()

    local blacklistMenu = CreateFrame("Frame", "RTBlacklistContextMenu", UIParent)
    blacklistMenu:SetSize(160, 150)
    blacklistMenu:SetFrameStrata("FULLSCREEN_DIALOG")
    blacklistMenu:SetFrameLevel(100)
    blacklistMenu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    blacklistMenu:SetBackdropColor(0.06, 0.06, 0.09, 0.98)
    blacklistMenu:SetBackdropBorderColor(1.0, 1.0, 1.0, 0.95)
    blacklistMenu:EnableMouse(true)
    blacklistMenu:Hide()

    table.insert(activeCustomMenus, blacklistMenu)

    local menuButtons = {}
    local reasons = { "leaver", "bad dps", "unskilled", "ninja", "ninja pulls", "low gs", "afk bot", "rude" }
    for i, reason in ipairs(reasons) do
        local mBtn = CreateFrame("Button", nil, blacklistMenu)
        mBtn:SetHeight(18)
        mBtn:SetPoint("TOPLEFT", blacklistMenu, "TOPLEFT", 4, -((i - 1) * 18) - 4)
        mBtn:SetPoint("TOPRIGHT", blacklistMenu, "TOPRIGHT", -4, -((i - 1) * 18) - 4)

        local hl = mBtn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(mBtn)
        hl:SetTexture("Interface\\Buttons\\WHITE8X8")
        hl:SetVertexColor(1.0, 1.0, 1.0, 0.20)

        local txt = mBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        txt:SetPoint("LEFT", mBtn, "LEFT", 4, 0)
        txt:SetText(reason)

        mBtn.reason = reason
        mBtn:SetScript("OnClick", function(self)
            if blacklistMenu.targetName then
                RaidersTrackerDB.blacklist = RaidersTrackerDB.blacklist or {}
                local tName = blacklistMenu.targetName
                local tClass = blacklistMenu.targetClass or "WARRIOR"
                local activeSession = GetActiveSession()
                local resolvedID = ExtractCharacterID(blacklistMenu.targetCharID)
                    or ExtractCharacterID(blacklistMenu.targetGUID)
                    or (activeSession and activeSession.playerIDs and activeSession.playerIDs[tName])
                    or (currentSession and currentSession.playerIDs and currentSession.playerIDs[tName])
                    or nameToCharID[tName]
                    or ExtractCharacterID(UnitGUID(tName))
                local charID = resolvedID or ("NAME:" .. tName)

                if resolvedID and RaidersTrackerDB.blacklist["NAME:" .. tName] then
                    local oldFallback = RaidersTrackerDB.blacklist["NAME:" .. tName]
                    RaidersTrackerDB.blacklist[charID] = RaidersTrackerDB.blacklist[charID] or {
                        names = {},
                        class = tClass,
                        timestamp = oldFallback.timestamp or date("%Y-%m-%d %H:%M")
                    }
                    for n in pairs(oldFallback.names or {}) do
                        RaidersTrackerDB.blacklist[charID].names[n] = true
                    end
                    RaidersTrackerDB.blacklist["NAME:" .. tName] = nil
                end

                RaidersTrackerDB.blacklist[charID] = RaidersTrackerDB.blacklist[charID] or {
                    names = {},
                    class = tClass,
                    timestamp = date("%Y-%m-%d %H:%M")
                }
                RaidersTrackerDB.blacklist[charID].names = RaidersTrackerDB.blacklist[charID].names or {}
                RaidersTrackerDB.blacklist[charID].names[tName] = true
                RaidersTrackerDB.blacklist[charID].reason = self.reason
                RaidersTrackerDB.blacklist[charID].class = tClass
                RaidersTrackerDB.blacklist[charID].timestamp = date("%Y-%m-%d %H:%M")

                AnnounceLocalChat(string.format("Blacklisted %s (ID: %s) for: %s", tName, charID, self.reason))
                if BlacklistFrame and BlacklistFrame:IsShown() then
                    RefreshBlacklistView()
                end
            end
            blacklistMenu:Hide()
        end)
        menuButtons[i] = mBtn
    end
    blacklistMenu:SetHeight(#reasons * 18 + 8)

    local rows = {}
    for i = 1, 100 do
        local row = CreateFrame("Frame", nil, scrollContent)
        row:SetSize(500, 22)
        row:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 4, -((i - 1) * 22) - 4)

        local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("LEFT", row, "LEFT", 6, 0)
        text:SetJustifyH("LEFT")
        text:SetWordWrap(false)

        local btnWhisper = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        btnWhisper:SetSize(65, 20)
        btnWhisper:SetPoint("RIGHT", row, "RIGHT", -6, 0)
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

        local btnBlacklist = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        btnBlacklist:SetSize(75, 20)
        btnBlacklist:SetPoint("RIGHT", btnWhisper, "LEFT", -4, 0)
        btnBlacklist:SetText("Blacklist")
        btnBlacklist:RegisterForClicks("LeftButtonUp")
        btnBlacklist:SetScript("OnClick", function(self)
            if self.playerName then
                blacklistMenu.targetName = self.playerName
                blacklistMenu.targetClass = self.playerClass
                blacklistMenu.targetCharID = self.playerCharID
                blacklistMenu.targetGUID = self.playerGUID
                HideAllCustomDropdownMenus()
                blacklistMenu:ClearAllPoints()
                blacklistMenu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
                blacklistMenu:Show()
            end
        end)

        text:SetPoint("RIGHT", btnBlacklist, "LEFT", -6, 0)

        row.text = text
        row.btnWhisper = btnWhisper
        row.btnBlacklist = btnBlacklist
        row:Hide()
        rows[i] = row
    end

    RefreshCharactersView = function()
        if not CharacterFrame or not CharacterFrame:IsShown() then return end
        UpdateGroupCache()
        local activeSession = GetActiveSession()
        local majZone, majCount, totalOnline = RTExt.GetMajorityRaidZone(activeSession)
        RTExt.activeMajorityRaidZone = majZone

        if totalOnline and totalOnline > 0 then
            zoneHeaderLabel:SetText(string.format("Majority Raid Zone: |cffFFD100%s|r |cff888888(%d/%d online in zone)|r", majZone or "Unknown", majCount or 0, totalOnline))
        else
            zoneHeaderLabel:SetText(string.format("Majority Raid Zone: |cffFFD100%s|r", majZone or "Unknown"))
        end

        local playerMap = {}
        local playerIDMap = {}
        for pName, pClass in pairs((activeSession and activeSession.players) or {}) do
            playerMap[pName] = pClass
        end
        for pName, cID in pairs((activeSession and activeSession.playerIDs) or {}) do
            playerIDMap[pName] = cID
        end
        if activeSession and activeSession.zoneTimes then
            for pName in pairs(activeSession.zoneTimes) do
                if not playerMap[pName] then
                    playerMap[pName] = GetSafePlayerClass(pName)
                end
            end
        end
        for _, seg in ipairs((activeSession and activeSession.segments) or {}) do
            for pName, pClass in pairs(seg.players or {}) do
                playerMap[pName] = pClass
            end
            for pName, cID in pairs(seg.playerIDs or {}) do
                playerIDMap[pName] = playerIDMap[pName] or cID
            end
        end

        local activeCount = RTExt.CountActiveSessionPlayers(activeSession, playerMap)

        local sortedPlayers = {}
        for pName in pairs(playerMap) do table.insert(sortedPlayers, pName) end
        table.sort(sortedPlayers)

        playerCountLabel:SetText(string.format("Players: |cff00FF00Active: %d|r  |  |cffFFFFFFTotal: %d|r", activeCount, #sortedPlayers))

        if #sortedPlayers == 0 then
            for i = 1, 100 do rows[i]:Hide() end
            emptyLabel:Show()
            scrollContent:SetHeight(315)
            return
        end

        emptyLabel:Hide()
        local shownCount = math.min(#sortedPlayers, 100)
        for idx = 1, shownCount do
            local pName = sortedPlayers[idx]
            local pClass = playerMap[pName] or "WARRIOR"
            local hexColor = GetPlayerClassColor(pClass)
            local pCharID = (activeSession and activeSession.playerIDs and activeSession.playerIDs[pName])
                or playerIDMap[pName]
                or nameToCharID[pName]
                or ExtractCharacterID(UnitGUID(pName))
            if pCharID and activeSession then
                activeSession.playerIDs = activeSession.playerIDs or {}
                activeSession.playerIDs[pName] = pCharID
                nameToCharID[pName] = pCharID
            end
            local zoneSecs = 0
            if activeSession and activeSession.zoneTimes and activeSession.zoneTimes[pName] and majZone then
                zoneSecs = RTExt.GetZoneTimeTotal(activeSession.zoneTimes[pName][majZone])
            end
            rows[idx].text:SetText(string.format("%s |cff888888(%s)|r - |cff00FF00%s|r", ColorizeText(pName, hexColor), pClass, RTExt.FormatZoneDuration(zoneSecs)))
            rows[idx].btnWhisper.playerName = pName
            rows[idx].btnBlacklist.playerName = pName
            rows[idx].btnBlacklist.playerClass = pClass
            rows[idx].btnBlacklist.playerCharID = pCharID
            rows[idx].btnBlacklist.playerGUID = pCharID
            if not rows[idx]:IsShown() then rows[idx]:Show() end
        end
        for idx = shownCount + 1, 100 do rows[idx]:Hide() end
        scrollContent:SetHeight(math.max(330, shownCount * 22 + 12))
    end

    CharacterFrame:SetScript("OnShow", RefreshCharactersView)
    CharacterFrame:SetScript("OnHide", function() blacklistMenu:Hide() end)
end

function RTExt.CreateCharacterExportFrame()
    local frame = CreateRUTPanel("RTCharacterExportFrame", 580, 440, "Export Characters")
    RTExt.CharacterExportFrame = frame

    local currentExportText = ""

    local infoLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -36)
    infoLabel:SetText("Copy character names, classes, and raid zone online time (Ctrl+A, Ctrl+C):")

    local viewBox = CreateWhiteBorderViewBox(frame, -58, 46)

    local scrollFrame = CreateFrame("ScrollFrame", "RTCharExportScrollFrame", viewBox, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", viewBox, "TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", viewBox, "BOTTOMRIGHT", -28, 8)

    local editBox = CreateFrame("EditBox", "RTCharExportEditBox", scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    if editBox.SetMaxLetters then editBox:SetMaxLetters(0) end
    if editBox.SetMaxBytes then editBox:SetMaxBytes(0) end
    editBox:SetFontObject(GameFontHighlightSmall)
    editBox:SetWidth(500)
    editBox:SetHeight(290)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        frame:Hide()
    end)
    editBox:SetScript("OnChar", function(self)
        self:SetText(currentExportText)
    end)
    scrollFrame:SetScrollChild(editBox)

    viewBox:EnableMouse(true)
    viewBox:SetScript("OnMouseDown", function() editBox:SetFocus() end)

    local btnSelectAll = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    btnSelectAll:SetSize(110, 24)
    btnSelectAll:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 14)
    btnSelectAll:SetText("Select All")
    btnSelectAll:SetScript("OnClick", function()
        editBox:SetFocus()
        editBox:HighlightText()
    end)

    local btnBackChars = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    btnBackChars:SetSize(145, 24)
    btnBackChars:SetPoint("LEFT", btnSelectAll, "RIGHT", 10, 0)
    btnBackChars:SetText("Back to Characters")
    btnBackChars:SetScript("OnClick", function() CloseAllPanels(); CharacterFrame:Show() end)

    local btnBackTracker = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    btnBackTracker:SetSize(130, 24)
    btnBackTracker:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 14)
    btnBackTracker:SetText("Back to Tracker")
    btnBackTracker:SetScript("OnClick", function() CloseAllPanels(); MainTrackerFrame:Show() end)

    frame:SetScript("OnShow", function()
        local activeSession = GetActiveSession()
        local majZone = RTExt.activeMajorityRaidZone
        if not majZone or majZone == "" then
            majZone = RTExt.GetMajorityRaidZone(activeSession)
            RTExt.activeMajorityRaidZone = majZone
        end

        local playerMap = {}
        for pName, pClass in pairs((activeSession and activeSession.players) or {}) do
            playerMap[pName] = pClass
        end
        if activeSession and activeSession.zoneTimes then
            for pName in pairs(activeSession.zoneTimes) do
                if not playerMap[pName] then
                    playerMap[pName] = GetSafePlayerClass(pName)
                end
            end
        end
        for _, seg in ipairs((activeSession and activeSession.segments) or {}) do
            for pName, pClass in pairs(seg.players or {}) do
                playerMap[pName] = pClass
            end
        end

        local activeCount = RTExt.CountActiveSessionPlayers(activeSession, playerMap)

        local sortedPlayers = {}
        for pName in pairs(playerMap) do table.insert(sortedPlayers, pName) end
        table.sort(sortedPlayers)

        local lines = {
            string.format("=== Raiders Tracker%s by %s - Session Characters ===", RTExt.GetVersionTag(), AUTHOR),
            string.format("Session: %s", (activeSession and activeSession.name) or "Live Current Session"),
            string.format("Raid Zone: %s", majZone or "Unknown"),
            string.format("Players: Active: %d | Total: %d", activeCount, #sortedPlayers),
            ""
        }
        if #sortedPlayers == 0 then
            table.insert(lines, "No characters recorded in this session yet.")
        else
            for _, pName in ipairs(sortedPlayers) do
                local pClass = string.upper(playerMap[pName] or "WARRIOR")
                local zoneSecs = 0
                if activeSession and activeSession.zoneTimes and activeSession.zoneTimes[pName] and majZone then
                    zoneSecs = RTExt.GetZoneTimeTotal(activeSession.zoneTimes[pName][majZone])
                end
                table.insert(lines, string.format("%s (%s) - %s", pName, pClass, RTExt.FormatZoneDuration(zoneSecs)))
            end
        end

        currentExportText = table.concat(lines, "\n")
        editBox:SetText(currentExportText)
        if scrollFrame.UpdateScrollChildRect then scrollFrame:UpdateScrollChildRect() end
        scrollFrame:SetVerticalScroll(0)
        editBox:SetFocus()
        editBox:HighlightText()
    end)
end

-------------------------------------------------------------------------------
-- Multi-Panel Reporting Hub (Flush Left, Clean Fails & Line Limits)
-------------------------------------------------------------------------------
local function CreateReportFrame()
    ReportFrame = CreateRUTPanel("RTReportFrame", 680, 540, "Report Segment Hub")

    local activeReportPanel = "ALL"
    local activeAllFormat = "PLAIN"
    local activeCharSubMode = "BUFFS"
    local activeFailSubMode = "EARLY"
    local failLineLimit = 10
    local selectedReportChar = nil
    local currentPreviewText = ""
    local currentRaidChatLines = {}

    local GenerateReport

    local btnPanelAll = CreateFrame("Button", nil, ReportFrame, "UIPanelButtonTemplate")
    btnPanelAll:SetSize(130, 24)
    btnPanelAll:SetPoint("TOPLEFT", ReportFrame, "TOPLEFT", 18, -34)
    btnPanelAll:SetText("1. ALL Data")

    local btnPanelChar = CreateFrame("Button", nil, ReportFrame, "UIPanelButtonTemplate")
    btnPanelChar:SetSize(130, 24)
    btnPanelChar:SetPoint("LEFT", btnPanelAll, "RIGHT", 6, 0)
    btnPanelChar:SetText("2. Character")

    local btnPanelFails = CreateFrame("Button", nil, ReportFrame, "UIPanelButtonTemplate")
    btnPanelFails:SetSize(130, 24)
    btnPanelFails:SetPoint("LEFT", btnPanelChar, "RIGHT", 6, 0)
    btnPanelFails:SetText("3. Raid Fails")

    local btnPanelDeaths = CreateFrame("Button", nil, ReportFrame, "UIPanelButtonTemplate")
    btnPanelDeaths:SetSize(145, 24)
    btnPanelDeaths:SetPoint("LEFT", btnPanelFails, "RIGHT", 6, 0)
    btnPanelDeaths:SetText("4. Suspicious Deaths")

    local subFrameAll = CreateFrame("Frame", nil, ReportFrame)
    subFrameAll:SetSize(640, 28)
    subFrameAll:SetPoint("TOPLEFT", ReportFrame, "TOPLEFT", 18, -62)

    local chkPlain = CreateFrame("CheckButton", nil, subFrameAll, "UICheckButtonTemplate")
    chkPlain:SetPoint("LEFT", subFrameAll, "LEFT", 0, 0)
    chkPlain.text = chkPlain:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    chkPlain.text:SetPoint("LEFT", chkPlain, "RIGHT", 2, 0)
    chkPlain.text:SetText("Plain Text")
    chkPlain:SetChecked(true)

    local chkDiscord = CreateFrame("CheckButton", nil, subFrameAll, "UICheckButtonTemplate")
    chkDiscord:SetPoint("LEFT", chkPlain.text, "RIGHT", 16, 0)
    chkDiscord.text = chkDiscord:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    chkDiscord.text:SetPoint("LEFT", chkDiscord, "RIGHT", 2, 0)
    chkDiscord.text:SetText("Discord Markdown")

    local chkHTML = CreateFrame("CheckButton", nil, subFrameAll, "UICheckButtonTemplate")
    chkHTML:SetPoint("LEFT", chkDiscord.text, "RIGHT", 16, 0)
    chkHTML.text = chkHTML:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    chkHTML.text:SetPoint("LEFT", chkHTML, "RIGHT", 2, 0)
    chkHTML.text:SetText("Export as HTML")

    local copyHint = subFrameAll:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    copyHint:SetPoint("LEFT", chkHTML.text, "RIGHT", 14, 0)
    copyHint:SetText("|cff888888(Ctrl+A, Ctrl+C to copy)|r")

    local subFrameChar = CreateFrame("Frame", nil, ReportFrame)
    subFrameChar:SetSize(640, 28)
    subFrameChar:SetPoint("TOPLEFT", ReportFrame, "TOPLEFT", 18, -62)
    subFrameChar:Hide()

    local charLabel = subFrameChar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    charLabel:SetPoint("LEFT", subFrameChar, "LEFT", 2, 0)
    charLabel:SetText("Raider:")

    local charDropdown = CreateCustomDropdown(subFrameChar, 160, 24)
    charDropdown:SetPoint("LEFT", charLabel, "RIGHT", 8, 0)

    local btnCharBuffs = CreateFrame("Button", nil, subFrameChar, "UIPanelButtonTemplate")
    btnCharBuffs:SetSize(165, 24)
    btnCharBuffs:SetPoint("LEFT", charDropdown, "RIGHT", 10, 0)
    btnCharBuffs:SetText("Buffs & Utility")

    local btnCharFails = CreateFrame("Button", nil, subFrameChar, "UIPanelButtonTemplate")
    btnCharFails:SetSize(130, 24)
    btnCharFails:SetPoint("LEFT", btnCharBuffs, "RIGHT", 8, 0)
    btnCharFails:SetText("Character Fails")

    local subFrameFails = CreateFrame("Frame", nil, ReportFrame)
    subFrameFails:SetSize(640, 28)
    subFrameFails:SetPoint("TOPLEFT", ReportFrame, "TOPLEFT", 18, -62)
    subFrameFails:Hide()

    local btnFailEarly = CreateFrame("Button", nil, subFrameFails, "UIPanelButtonTemplate")
    btnFailEarly:SetSize(95, 24)
    btnFailEarly:SetPoint("LEFT", subFrameFails, "LEFT", 0, 0)
    btnFailEarly:SetText("1. Early Deaths")

    local btnFailSlack = CreateFrame("Button", nil, subFrameFails, "UIPanelButtonTemplate")
    btnFailSlack:SetSize(100, 24)
    btnFailSlack:SetPoint("LEFT", btnFailEarly, "RIGHT", 4, 0)
    btnFailSlack:SetText("2. Slackers")

    local btnFailCds = CreateFrame("Button", nil, subFrameFails, "UIPanelButtonTemplate")
    btnFailCds:SetSize(95, 24)
    btnFailCds:SetPoint("LEFT", btnFailSlack, "RIGHT", 4, 0)
    btnFailCds:SetText("3. CD Fails")

    local limitDropdown = CreateCustomDropdown(subFrameFails, 100, 24)
    limitDropdown:SetPoint("LEFT", btnFailCds, "RIGHT", 10, 0)

    limitDropdown.getItems = function()
        return {
            { text = "5 lines", checked = (failLineLimit == 5), func = function() failLineLimit = 5; GenerateReport() end },
            { text = "10 lines", checked = (failLineLimit == 10), func = function() failLineLimit = 10; GenerateReport() end },
            { text = "20 lines", checked = (failLineLimit == 20), func = function() failLineLimit = 20; GenerateReport() end },
            { text = "All lines", checked = (failLineLimit == 9999), func = function() failLineLimit = 9999; GenerateReport() end },
        }
    end
    limitDropdown:SetText(failLineLimit == 9999 and "All lines" or (failLineLimit .. " lines"))

    local subFrameInfo = CreateFrame("Frame", nil, ReportFrame)
    subFrameInfo:SetSize(640, 28)
    subFrameInfo:SetPoint("TOPLEFT", ReportFrame, "TOPLEFT", 18, -62)
    subFrameInfo:Hide()

    local infoBannerText = subFrameInfo:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoBannerText:SetPoint("LEFT", subFrameInfo, "LEFT", 4, 0)

    local viewBox = CreateWhiteBorderViewBox(ReportFrame, -94, 46)

    local scrollFrame = CreateFrame("ScrollFrame", "RTReportScrollFrame", viewBox, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", viewBox, "TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", viewBox, "BOTTOMRIGHT", -28, 8)

    local editBox = CreateFrame("EditBox", "RTReportEditBox", scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    if editBox.SetMaxLetters then editBox:SetMaxLetters(0) end
    if editBox.SetMaxBytes then editBox:SetMaxBytes(0) end
    editBox:SetFontObject(GameFontHighlightSmall)
    editBox:SetWidth(600)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        ReportFrame:Hide()
    end)
    editBox:SetScript("OnChar", function(self)
        self:SetText(currentPreviewText)
    end)
    scrollFrame:SetScrollChild(editBox)

    local btnBack = CreateFrame("Button", nil, ReportFrame, "UIPanelButtonTemplate")
    btnBack:SetSize(135, 24)
    btnBack:SetPoint("BOTTOMLEFT", ReportFrame, "BOTTOMLEFT", 18, 14)
    btnBack:SetText("Cancel / Back")
    btnBack:SetScript("OnClick", function() CloseAllPanels(); MainTrackerFrame:Show() end)

    local btnSendRaid = CreateFrame("Button", nil, ReportFrame, "UIPanelButtonTemplate")
    btnSendRaid:SetSize(145, 24)
    btnSendRaid:SetPoint("LEFT", btnBack, "RIGHT", 10, 0)
    btnSendRaid:SetText("Send to Raid")
    btnSendRaid:SetScript("OnClick", function()
        if #currentRaidChatLines > 0 then
            EnqueueRaidChatLines(currentRaidChatLines)
        end
    end)

    local footerText = ReportFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    footerText:SetPoint("BOTTOMRIGHT", ReportFrame, "BOTTOMRIGHT", -20, 18)
    footerText:SetText(GetFooterText())

    local function EscapeHTML(str)
        if not str then return "" end
        return str:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
    end

    local function ConvertWoWColorsToHTML(str)
        if not str then return "" end
        local escaped = EscapeHTML(str)
        escaped = escaped:gsub("|c%x%x(%x%x%x%x%x%x)(.-)|r", '<span style="color: #%1; font-weight: bold;">%2</span>')
        escaped = escaped:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        return escaped
    end

    local function BuildAllDataPlainLines(seg, presentList, presentMap, deathPlayers, totalSegDeaths, potPlayers, utilPlayers)
        local rLines = BuildStandardRaidHeaderLines(seg)
        table.insert(rLines, "")
        table.insert(rLines, string.format("--- 1. Characters Present (%d) ---", #presentList))
        if #presentList == 0 then
            table.insert(rLines, "None")
        else
            for _, pName in ipairs(presentList) do
                table.insert(rLines, string.format("- %s (%s)", pName, presentMap[pName] or "WARRIOR"))
            end
        end
        table.insert(rLines, "")
        table.insert(rLines, string.format("--- 2. Deaths & Death Log (%d Total) ---", totalSegDeaths))
        if #deathPlayers == 0 then
            table.insert(rLines, "None")
        else
            for _, dPlayer in ipairs(deathPlayers) do
                local pName = dPlayer.name
                local pClass = presentMap[pName] or string.upper(GetSafePlayerClass(pName))
                local deathWord = (dPlayer.count == 1) and "Death" or "Deaths"
                table.insert(rLines, string.format("%s (%s) - %d %s", pName, pClass, dPlayer.count, deathWord))
                for idx, d in ipairs(dPlayer.list) do
                    local killer = StripColorCodes(d.killer or "Unknown Mob")
                    local ability = StripColorCodes(d.ability or "Unknown Attack")
                    local amount = tonumber(d.amount) or 0
                    local overkill = tonumber(d.overkill) or 0
                    local timeStr = d.time or ""
                    local pullStr = FormatPullTime(d.pullTime)
                    local stamp = pullStr and string.format("%s into pull / %s", pullStr, timeStr) or timeStr
                    local dmgText = (amount > 0) and string.format("%d dmg", amount) or "Fatal Effect"
                    if overkill > 0 then dmgText = string.format("%d dmg (%d overkill)", amount, overkill) end
                    table.insert(rLines, string.format("- %d. [%s] Killed by %s / Ability: %s / Damage: %s", idx, stamp, killer, ability, dmgText))
                end
            end
        end
        table.insert(rLines, "")
        table.insert(rLines, "--- 3. Potions & Buffs ---")
        if #potPlayers == 0 then
            table.insert(rLines, "None")
        else
            for _, pName in ipairs(potPlayers) do
                local pClass = presentMap[pName] or string.upper(seg.players[pName] or "WARRIOR")
                table.insert(rLines, string.format("%s (%s)", pName, pClass))
                for _, cLine in ipairs(BuildCondensedEntryLines(seg.potionsAndBuffs[pName], "- ")) do
                    table.insert(rLines, cLine)
                end
            end
        end
        table.insert(rLines, "")
        table.insert(rLines, "--- 4. Raid Utility ---")
        if #utilPlayers == 0 then
            table.insert(rLines, "None")
        else
            for _, pName in ipairs(utilPlayers) do
                local pClass = presentMap[pName] or string.upper(seg.players[pName] or "WARRIOR")
                table.insert(rLines, string.format("%s (%s):", pName, pClass))
                local dpVals = seg.demonicPactValues and seg.demonicPactValues[pName] or nil
                for _, cLine in ipairs(BuildCondensedEntryLines(seg.raidUtility[pName], "- ", dpVals)) do
                    table.insert(rLines, cLine)
                end
            end
        end
        return rLines
    end

    local function BuildSingleCharacterFails(seg, pName, pClass, segDur, maxPossible30s, enrageStr, totalEnrages, detectedTanks)
        local fails = {}
        local hasFlask, hasFood, potCount = GetPlayerConsumableStatus(seg, pName)
        if not hasFlask then table.insert(fails, { text = "Missing Flask / Elixir", severity = 3 }) end
        if not hasFood then table.insert(fails, { text = "Missing Well Fed Food Buff", severity = 3 }) end
        if potCount == 0 then
            table.insert(fails, { text = "Combat Potions Used: 0 (No pre-pot or combat potion used)", severity = 4 })
        elseif potCount == 1 then
            table.insert(fails, { text = "Combat Potions Used: 1 (Only 1 potion used)", severity = 2 })
        end

        local utilEntries = (seg.raidUtility and seg.raidUtility[pName]) or {}
        local totalUtilityCasts = 0
        for _, c in pairs(utilEntries) do totalUtilityCasts = totalUtilityCasts + (tonumber(c) or 0) end

        if pClass == "ROGUE" and maxPossible30s > 0 then
            local tricks = CountPlayerSpellUsage(utilEntries, "Tricks of the Trade")
            if tricks < maxPossible30s then
                table.insert(fails, { text = string.format("Class Duty (Tricks of the Trade): Cast %d in %s (%d possible on 30s CD)", tricks, FormatDurationShort(segDur), maxPossible30s), severity = 3 })
            end
        elseif pClass == "HUNTER" then
            local mdCasts = CountPlayerSpellUsage(utilEntries, "Misdirection")
            if maxPossible30s > 0 and mdCasts < math.max(1, math.floor(maxPossible30s / 2)) then
                table.insert(fails, { text = string.format("Class Duty (Misdirection): Cast %d in %s (%d possible on 30s CD)", mdCasts, FormatDurationShort(segDur), maxPossible30s), severity = 3 })
            elseif maxPossible30s == 0 and mdCasts == 0 then
                table.insert(fails, { text = "Class Duty (Misdirection): 0 casts recorded", severity = 3 })
            end
            local tranqCasts = CountPlayerSpellUsage(utilEntries, "Tranquilizing Shot")
            if totalEnrages > 0 and tranqCasts == 0 then
                table.insert(fails, { text = string.format("Class Duty (Tranquilizing Shot): 0 Tranquilizing Shots used (%s)", enrageStr), severity = 5 })
            end
        end

        if detectedTanks[pName] then
            local tankCDCount = CountMajorTankCooldowns(seg, pName)
            if tankCDCount == 0 then
                table.insert(fails, { text = "Tank Cooldown Fail: 0 major tank defensive cooldowns used", severity = 5 })
            end
        end

        if totalUtilityCasts == 0 then
            table.insert(fails, { text = "Zero Total Utility: 0 utility spells cast across the entire segment", severity = 4 })
        end

        local allSegDeaths = {}
        for _, dList in pairs(seg.deaths or {}) do
            for _, d in ipairs(dList or {}) do table.insert(allSegDeaths, d) end
        end

        local rawDeaths = (seg.deaths and seg.deaths[pName]) or {}
        for _, d in ipairs(rawDeaths) do
            if not IsWipeDeath(d, allSegDeaths) then
                local unusedDef = GetUnusedPersonalDefensives(seg, pName, pClass)
                local unusedStr = (#unusedDef > 0) and table.concat(unusedDef, ", ") or "None unused"
                local pullStr = FormatPullTime(d.pullTime)
                local timeLabel = pullStr and string.format("%s into pull (%s)", pullStr, d.time or "") or (d.time or "")
                local killer = StripColorCodes(d.killer or "Unknown Mob")
                local ability = StripColorCodes(d.ability or "Unknown Attack")
                local amount = tonumber(d.amount) or 0
                local overkill = tonumber(d.overkill) or 0
                local dmgText = (amount > 0) and string.format("%d dmg", amount) or "Fatal Effect"
                if overkill > 0 then dmgText = string.format("%d dmg (%d overkill)", amount, overkill) end
                table.insert(fails, { text = string.format("Death [%s]: Killed by %s (%s - %s) / Unused Defensives: %s", timeLabel, killer, ability, dmgText, unusedStr), severity = 5 })
            end
        end
        return fails
    end

    GenerateReport = function()
        HideAllCustomDropdownMenus()
        local activeSession = GetActiveSession()
        local seg = (activeSession and activeSession.segments or {})[selectedSegmentIndex]

        btnPanelAll:UnlockHighlight()
        btnPanelChar:UnlockHighlight()
        btnPanelFails:UnlockHighlight()
        btnPanelDeaths:UnlockHighlight()
        subFrameAll:Hide()
        subFrameChar:Hide()
        subFrameFails:Hide()
        subFrameInfo:Hide()

        if activeReportPanel == "ALL" then
            btnPanelAll:LockHighlight()
            subFrameAll:Show()
        elseif activeReportPanel == "CHAR" then
            btnPanelChar:LockHighlight()
            subFrameChar:Show()
            if activeCharSubMode == "BUFFS" then
                btnCharBuffs:LockHighlight()
                btnCharFails:UnlockHighlight()
            else
                btnCharBuffs:UnlockHighlight()
                btnCharFails:LockHighlight()
            end
        elseif activeReportPanel == "FAILS" then
            btnPanelFails:LockHighlight()
            subFrameFails:Show()
            btnFailEarly:UnlockHighlight()
            btnFailSlack:UnlockHighlight()
            btnFailCds:UnlockHighlight()
            if activeFailSubMode == "EARLY" then btnFailEarly:LockHighlight()
            elseif activeFailSubMode == "SLACKERS" then btnFailSlack:LockHighlight()
            else btnFailCds:LockHighlight() end
            limitDropdown:SetText(failLineLimit == 9999 and "All lines" or (failLineLimit .. " lines"))
        elseif activeReportPanel == "DEATHS" then
            btnPanelDeaths:LockHighlight()
            subFrameInfo:Show()
            infoBannerText:SetText("|cffFFFF00Viewing: Chronological Suspicious Deaths Breakdown & Unused Defensives|r")
        end

        if not seg then
            currentPreviewText = "No Segment Selected"
            currentRaidChatLines = {}
            editBox:SetText(currentPreviewText)
            return
        end

        local presentList, presentMap = CollectPresentPlayersInSegment(seg)
        if not selectedReportChar or not presentMap[selectedReportChar] then
            selectedReportChar = presentList[1]
        end

        charDropdown.getItems = function()
            local items = {}
            for _, pName in ipairs(presentList) do
                local capturedName = pName
                local pClass = presentMap[capturedName] or "WARRIOR"
                table.insert(items, {
                    text = string.format("%s (%s)", capturedName, pClass),
                    checked = (selectedReportChar == capturedName),
                    func = function()
                        selectedReportChar = capturedName
                        GenerateReport()
                    end
                })
            end
            return items
        end
        if selectedReportChar then
            charDropdown:SetText(string.format("%s (%s)", selectedReportChar, presentMap[selectedReportChar] or "WARRIOR"))
        else
            charDropdown:SetText("No Characters")
        end

        local segDur = GetSegmentDuration(seg)
        local maxPossible30s = (segDur > 0) and math.max(1, math.floor(segDur / 30)) or 0
        local enrageStr, totalEnrages = GetEnrageSummaryString(seg)
        local detectedTanks = DetectSegmentTanks(seg, presentMap)

        if activeReportPanel == "ALL" then
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

            local potPlayers = {}
            for pName, entries in pairs(seg.potionsAndBuffs or {}) do
                if next(entries) ~= nil then table.insert(potPlayers, pName) end
            end
            table.sort(potPlayers)

            local utilPlayers = {}
            for pName, entries in pairs(seg.raidUtility or {}) do
                if next(entries) ~= nil then table.insert(utilPlayers, pName) end
            end
            table.sort(utilPlayers)

            currentRaidChatLines = BuildAllDataPlainLines(seg, presentList, presentMap, deathPlayers, totalSegDeaths, potPlayers, utilPlayers)

            local segZone = seg.zone or GetCurrentZoneSafe()
            local segDiff = seg.difficulty or GetRaidDifficultySuffix()
            local segName = seg.name or "TRASH"
            local header = string.format("[%s %s] - %s (Full Segment Report)", segZone, segDiff, segName)

            if activeAllFormat == "HTML" then
                local lines = {
                    "<!DOCTYPE html>", "<html>", "<head>", '  <meta charset="UTF-8">',
                    "  <title>Raiders Tracker by Copper - " .. EscapeHTML(header) .. "</title>",
                    "</head>",
                    '<body style="background-color: #141419; color: #E0E0E0; font-family: Arial, Helvetica, sans-serif; line-height: 1.5; padding: 20px;">',
                    '  <h1 style="color: #00FF00; margin-bottom: 4px;">Raiders Tracker by Copper</h1>',
                    string.format('  <p style="margin-top: 0; margin-bottom: 18px;">%s<a href="%s" target="_blank" style="color: #69CCF0; text-decoration: underline;">%s</a></p>', (GetAddonVersion() ~= "" and ("Version " .. EscapeHTML(GetAddonVersion()) .. " &mdash; ") or ""), GITHUB_URL, GITHUB_URL),
                    string.format('  <h1 style="color: #FFFFFF; border-bottom: 1px solid #444444; padding-bottom: 6px;">%s</h1>', EscapeHTML(header)),
                    string.format('  <h1 style="color: #FFD100; font-size: 1.35em; margin-top: 24px;">1. Characters Present (%d)</h1>', #presentList),
                    "  <ul>"
                }
                if #presentList == 0 then
                    table.insert(lines, "    <li>None</li>")
                else
                    for _, pName in ipairs(presentList) do
                        local pClass = presentMap[pName] or "WARRIOR"
                        local hexColor = GetPlayerClassColor(pClass)
                        table.insert(lines, string.format('    <li><span style="color: #%s; font-weight: bold;">%s</span> (%s)</li>', hexColor, EscapeHTML(pName), EscapeHTML(pClass)))
                    end
                end
                table.insert(lines, "  </ul>")
                table.insert(lines, string.format('  <h1 style="color: #FFD100; font-size: 1.35em; margin-top: 24px;">2. Deaths &amp; Death Log (%d Total)</h1>', totalSegDeaths))
                table.insert(lines, "  <ul>")
                if #deathPlayers == 0 then
                    table.insert(lines, "    <li>None</li>")
                else
                    for _, dPlayer in ipairs(deathPlayers) do
                        local pName = dPlayer.name
                        local pClass = presentMap[pName] or string.upper(GetSafePlayerClass(pName))
                        local hexColor = GetPlayerClassColor(pClass)
                        local deathWord = (dPlayer.count == 1) and "Death" or "Deaths"
                        table.insert(lines, string.format('    <li><span style="color: #%s; font-weight: bold;">%s</span> (%s) &mdash; <span style="color: #FFFF00; font-weight: bold;">%d %s</span>', hexColor, EscapeHTML(pName), EscapeHTML(pClass), dPlayer.count, deathWord))
                        table.insert(lines, "      <ul>")
                        for idx, d in ipairs(dPlayer.list) do
                            local killer = StripColorCodes(d.killer or "Unknown Mob")
                            local ability = StripColorCodes(d.ability or "Unknown Attack")
                            local amount = tonumber(d.amount) or 0
                            local overkill = tonumber(d.overkill) or 0
                            local timeStr = d.time or ""
                            local pullStr = FormatPullTime(d.pullTime)
                            local stamp = pullStr and string.format("%s into pull / %s", pullStr, timeStr) or timeStr
                            local dmgText = (amount > 0) and string.format("%d dmg", amount) or "Fatal Effect"
                            if overkill > 0 then dmgText = string.format("%d dmg (%d overkill)", amount, overkill) end
                            table.insert(lines, string.format(
                                '        <li>%d. [%s] Killed by <span style="color: #FFFF00;">%s</span> | Ability: <span style="color: #FFD100;">%s</span> | Damage: <span style="color: #FFFF00;">%s</span></li>',
                                idx, EscapeHTML(stamp), EscapeHTML(killer), EscapeHTML(ability), EscapeHTML(dmgText)
                            ))
                        end
                        table.insert(lines, "      </ul>")
                        table.insert(lines, "    </li>")
                    end
                end
                table.insert(lines, "  </ul>")
                table.insert(lines, '  <h1 style="color: #FFD100; font-size: 1.35em; margin-top: 24px;">3. Potions &amp; Buffs</h1>')
                table.insert(lines, "  <ul>")
                if #potPlayers == 0 then
                    table.insert(lines, "    <li>None</li>")
                else
                    for _, pName in ipairs(potPlayers) do
                        local pClass = presentMap[pName] or string.upper(seg.players[pName] or "WARRIOR")
                        local hexColor = GetPlayerClassColor(pClass)
                        table.insert(lines, string.format('    <li><span style="color: #%s; font-weight: bold;">%s</span> (%s)', hexColor, EscapeHTML(pName), EscapeHTML(pClass)))
                        table.insert(lines, "      <ul>")
                        local sortedEntries = {}
                        for buffName, count in pairs(seg.potionsAndBuffs[pName]) do
                            table.insert(sortedEntries, { rawName = buffName, cleanName = StripColorCodes(buffName), count = count })
                        end
                        table.sort(sortedEntries, function(a, b) return a.cleanName < b.cleanName end)
                        for _, entry in ipairs(sortedEntries) do
                            table.insert(lines, string.format('        <li>%s: <span style="color: #00FF00; font-weight: bold;">%d</span></li>', ConvertWoWColorsToHTML(entry.rawName), entry.count))
                        end
                        table.insert(lines, "      </ul>")
                        table.insert(lines, "    </li>")
                    end
                end
                table.insert(lines, "  </ul>")
                table.insert(lines, '  <h1 style="color: #FFD100; font-size: 1.35em; margin-top: 24px;">4. Raid Utility</h1>')
                table.insert(lines, "  <ul>")
                if #utilPlayers == 0 then
                    table.insert(lines, "    <li>None</li>")
                else
                    for _, pName in ipairs(utilPlayers) do
                        local pClass = presentMap[pName] or string.upper(seg.players[pName] or "WARRIOR")
                        local hexColor = GetPlayerClassColor(pClass)
                        table.insert(lines, string.format('    <li><span style="color: #%s; font-weight: bold;">%s</span> (%s)', hexColor, EscapeHTML(pName), EscapeHTML(pClass)))
                        table.insert(lines, "      <ul>")
                        local sortedEntries = {}
                        for utilName, count in pairs(seg.raidUtility[pName]) do
                            table.insert(sortedEntries, { rawName = utilName, cleanName = StripColorCodes(utilName), count = count })
                        end
                        table.sort(sortedEntries, function(a, b) return a.cleanName < b.cleanName end)
                        local dpVals = seg.demonicPactValues and seg.demonicPactValues[pName] or nil
                        for _, entry in ipairs(sortedEntries) do
                            if entry.cleanName == "Demonic Pact" and type(dpVals) == "table" and #dpVals > 0 then
                                table.insert(lines, string.format('        <li>Demonic Pact (<span style="color: #00FF00; font-weight: bold;">%d</span>): %s</li>', #dpVals, EscapeHTML(table.concat(dpVals, ", "))))
                            else
                                table.insert(lines, string.format('        <li>%s: <span style="color: #00FF00; font-weight: bold;">%d</span></li>', ConvertWoWColorsToHTML(entry.rawName), entry.count))
                            end
                        end
                        table.insert(lines, "      </ul>")
                        table.insert(lines, "    </li>")
                    end
                end
                table.insert(lines, "  </ul>")
                table.insert(lines, "</body>")
                table.insert(lines, "</html>")
                currentPreviewText = table.concat(lines, "\n")

            elseif activeAllFormat == "DISCORD" then
                local lines = {
                    string.format("=== Raiders Tracker%s by %s ===", RTExt.GetVersionTag(), AUTHOR),
                    GITHUB_URL,
                    string.format("Segment: %s (%s)", segName, segDiff),
                    "",
                    string.format("--- 1. Characters Present (%d) ---", #presentList)
                }
                if #presentList == 0 then
                    table.insert(lines, "None")
                else
                    for _, pName in ipairs(presentList) do
                        table.insert(lines, string.format("- %s (%s)", pName, presentMap[pName] or "WARRIOR"))
                    end
                end
                table.insert(lines, "")
                table.insert(lines, string.format("--- 2. Deaths & Death Log (%d Total) ---", totalSegDeaths))
                if #deathPlayers == 0 then
                    table.insert(lines, "None")
                else
                    for _, dPlayer in ipairs(deathPlayers) do
                        local pName = dPlayer.name
                        local pClass = presentMap[pName] or string.upper(GetSafePlayerClass(pName))
                        local deathWord = (dPlayer.count == 1) and "Death" or "Deaths"
                        table.insert(lines, string.format("%s (%s) - %d %s", pName, pClass, dPlayer.count, deathWord))
                        for idx, d in ipairs(dPlayer.list) do
                            local killer = StripColorCodes(d.killer or "Unknown Mob")
                            local ability = StripColorCodes(d.ability or "Unknown Attack")
                            local amount = tonumber(d.amount) or 0
                            local overkill = tonumber(d.overkill) or 0
                            local timeStr = d.time or ""
                            local pullStr = FormatPullTime(d.pullTime)
                            local stamp = pullStr and string.format("%s into pull / %s", pullStr, timeStr) or timeStr
                            local dmgText = (amount > 0) and string.format("%d dmg", amount) or "Fatal Effect"
                            if overkill > 0 then dmgText = string.format("%d dmg (%d overkill)", amount, overkill) end
                            table.insert(lines, string.format("- %d. [%s] Killed by %s / Ability: %s / Damage: %s", idx, stamp, killer, ability, dmgText))
                        end
                    end
                end
                table.insert(lines, "")
                table.insert(lines, "--- 3. Potions & Buffs ---")
                if #potPlayers == 0 then
                    table.insert(lines, "None")
                else
                    for _, pName in ipairs(potPlayers) do
                        local pClass = presentMap[pName] or string.upper(seg.players[pName] or "WARRIOR")
                        table.insert(lines, string.format("**%s (%s)**", pName, pClass))
                        for _, cLine in ipairs(BuildCondensedEntryLines(seg.potionsAndBuffs[pName], "- ")) do
                            table.insert(lines, cLine)
                        end
                    end
                end
                table.insert(lines, "")
                table.insert(lines, "--- 4. Raid Utility ---")
                if #utilPlayers == 0 then
                    table.insert(lines, "None")
                else
                    for _, pName in ipairs(utilPlayers) do
                        local pClass = presentMap[pName] or string.upper(seg.players[pName] or "WARRIOR")
                        table.insert(lines, string.format("**%s (%s):**", pName, pClass))
                        local dpVals = seg.demonicPactValues and seg.demonicPactValues[pName] or nil
                        for _, cLine in ipairs(BuildCondensedEntryLines(seg.raidUtility[pName], "- ", dpVals)) do
                            table.insert(lines, cLine)
                        end
                    end
                end
                currentPreviewText = table.concat(lines, "\n")
            else
                currentPreviewText = table.concat(currentRaidChatLines, "\n")
            end

        elseif activeReportPanel == "CHAR" then
            local lines = BuildStandardRaidHeaderLines(seg)
            if not selectedReportChar then
                table.insert(lines, "No Character Selected in Segment.")
            else
                local pName = selectedReportChar
                local pClass = presentMap[pName] or string.upper(GetSafePlayerClass(pName))
                if activeCharSubMode == "BUFFS" then
                    table.insert(lines, string.format("--- Character Buffs & Utility: %s (%s) ---", pName, pClass))
                    local potLines = BuildCondensedEntryLines((seg.potionsAndBuffs or {})[pName], "- ")
                    table.insert(lines, "[Potions & Buffs]")
                    if #potLines == 0 then
                        table.insert(lines, "- None recorded")
                    else
                        for _, l in ipairs(potLines) do table.insert(lines, l) end
                    end
                    local dpVals = seg.demonicPactValues and seg.demonicPactValues[pName] or nil
                    local utilLines = BuildCondensedEntryLines((seg.raidUtility or {})[pName], "- ", dpVals)
                    table.insert(lines, "[Raid Utility Used]")
                    if #utilLines == 0 then
                        table.insert(lines, "- None recorded")
                    else
                        for _, l in ipairs(utilLines) do table.insert(lines, l) end
                    end
                else
                    table.insert(lines, string.format("--- Character Fails Report: %s (%s) ---", pName, pClass))
                    local fails = BuildSingleCharacterFails(seg, pName, pClass, segDur, maxPossible30s, enrageStr, totalEnrages, detectedTanks)
                    if #fails == 0 then
                        table.insert(lines, "- No fails recorded for this player.")
                    else
                        for _, f in ipairs(fails) do
                            table.insert(lines, "- " .. f.text)
                        end
                    end
                end
            end
            currentRaidChatLines = lines
            currentPreviewText = table.concat(lines, "\n")

        elseif activeReportPanel == "FAILS" then
            local lines = BuildStandardRaidHeaderLines(seg)
            local allSegDeaths = {}
            for _, dList in pairs(seg.deaths or {}) do
                for _, d in ipairs(dList or {}) do table.insert(allSegDeaths, d) end
            end

            if activeFailSubMode == "EARLY" then
                table.insert(lines, "--- Raid Fails: Early Deaths ---")
                local maxTime = segDur * 0.75
                local earlyDeaths = {}
                for pName, dList in pairs(seg.deaths or {}) do
                    local pClass = presentMap[pName] or string.upper(GetSafePlayerClass(pName))
                    for _, d in ipairs(dList or {}) do
                        local pTime = tonumber(d.pullTime) or 0
                        if not IsWipeDeath(d, allSegDeaths) and (segDur <= 0 or pTime <= maxTime) then
                            table.insert(earlyDeaths, {
                                name = pName,
                                class = pClass,
                                pullTime = pTime,
                                time = d.time or "",
                                killer = StripColorCodes(d.killer or "Unknown Mob"),
                                ability = StripColorCodes(d.ability or "Unknown Attack"),
                                severity = 5
                            })
                        end
                    end
                end
                table.sort(earlyDeaths, function(a, b)
                    if a.pullTime ~= b.pullTime then return a.pullTime < b.pullTime end
                    return a.name < b.name
                end)

                if #earlyDeaths == 0 then
                    table.insert(lines, "None (No early deaths recorded)")
                else
                    local count = math.min(#earlyDeaths, failLineLimit)
                    for idx = 1, count do
                        local d = earlyDeaths[idx]
                        local pullStr = FormatPullTime(d.pullTime)
                        local timeTag = pullStr and string.format("%s into pull", pullStr) or d.time
                        table.insert(lines, string.format("- [%s] %s (%s): Died to %s (%s)", timeTag, d.name, d.class, d.killer, d.ability))
                    end
                end

            elseif activeFailSubMode == "SLACKERS" then
                table.insert(lines, "--- Raid Fails: Consumable Slackers ---")
                local slackers = {}
                for _, pName in ipairs(presentList) do
                    local pClass = presentMap[pName] or "WARRIOR"
                    local hasFlask, hasFood, potCount = GetPlayerConsumableStatus(seg, pName)
                    if not hasFlask or not hasFood or potCount < 2 then
                        local issues = {}
                        local sev = 1
                        if not hasFlask then table.insert(issues, "Missing Flask"); sev = sev + 2 end
                        if not hasFood then table.insert(issues, "Missing Food"); sev = sev + 2 end
                        if potCount == 0 then table.insert(issues, "0 Potions"); sev = sev + 3
                        elseif potCount == 1 then table.insert(issues, "1 Potion"); sev = sev + 1 end
                        table.insert(slackers, {
                            text = string.format("- %s (%s): %s", pName, pClass, table.concat(issues, " / ")),
                            severity = sev
                        })
                    end
                end
                table.sort(slackers, function(a, b) return a.severity > b.severity end)

                if #slackers == 0 then
                    table.insert(lines, "None (All raiders fully consumed)")
                else
                    local count = math.min(#slackers, failLineLimit)
                    for idx = 1, count do
                        table.insert(lines, slackers[idx].text)
                    end
                end

            else
                table.insert(lines, "--- Raid Fails: Critical Cooldown & Duty Fails ---")
                local cdFails = {}
                local durLabel = (segDur > 0) and FormatDurationShort(segDur) or "segment"

                for _, pName in ipairs(presentList) do
                    local pClass = presentMap[pName]
                    local uEntries = (seg.raidUtility and seg.raidUtility[pName]) or {}
                    if pClass == "ROGUE" then
                        local tricks = CountPlayerSpellUsage(uEntries, "Tricks of the Trade")
                        if maxPossible30s > 0 and tricks < maxPossible30s then
                            table.insert(cdFails, { text = string.format("- %s (ROGUE): Cast %d Tricks in %s (%d possible)", pName, tricks, durLabel, maxPossible30s), severity = 3 })
                        elseif maxPossible30s == 0 and tricks == 0 then
                            table.insert(cdFails, { text = string.format("- %s (ROGUE): Cast 0 Tricks", pName), severity = 3 })
                        end
                    elseif pClass == "HUNTER" then
                        local mdCasts = CountPlayerSpellUsage(uEntries, "Misdirection")
                        local tranqCasts = CountPlayerSpellUsage(uEntries, "Tranquilizing Shot")
                        if maxPossible30s > 0 and mdCasts < math.max(1, math.floor(maxPossible30s / 2)) then
                            table.insert(cdFails, { text = string.format("- %s (HUNTER): Cast %d Misdirection in %s", pName, mdCasts, durLabel), severity = 3 })
                        end
                        if totalEnrages > 0 and tranqCasts == 0 then
                            table.insert(cdFails, { text = string.format("- %s (HUNTER): 0 Tranq Shots used (%s)", pName, enrageStr), severity = 5 })
                        end
                    end
                    if detectedTanks[pName] then
                        local tankCDCount = CountMajorTankCooldowns(seg, pName)
                        if tankCDCount == 0 then
                            table.insert(cdFails, { text = string.format("- %s (%s - TANK): Used 0 major tank cooldowns", pName, pClass or "TANK"), severity = 5 })
                        end
                    end
                    local totalU = 0
                    for _, c in pairs(uEntries) do totalU = totalU + (tonumber(c) or 0) end
                    if totalU == 0 then
                        table.insert(cdFails, { text = string.format("- %s (%s): 0 total utility casts", pName, pClass or "RAIDER"), severity = 2 })
                    end
                end

                table.sort(cdFails, function(a, b) return a.severity > b.severity end)

                if #cdFails == 0 then
                    table.insert(lines, "None (No critical cooldown or duty fails recorded)")
                else
                    local count = math.min(#cdFails, failLineLimit)
                    for idx = 1, count do
                        table.insert(lines, cdFails[idx].text)
                    end
                end
            end

            currentRaidChatLines = lines
            currentPreviewText = table.concat(lines, "\n")

        elseif activeReportPanel == "DEATHS" then
            local lines = BuildStandardRaidHeaderLines(seg)
            table.insert(lines, "--- Chronological Suspicious Deaths Breakdown ---")
            local allSegDeaths = {}
            for _, dList in pairs(seg.deaths or {}) do
                for _, d in ipairs(dList or {}) do table.insert(allSegDeaths, d) end
            end

            local allDeaths = {}
            for pName, dList in pairs(seg.deaths or {}) do
                local pClass = presentMap[pName] or string.upper(GetSafePlayerClass(pName))
                for _, d in ipairs(dList or {}) do
                    if not IsWipeDeath(d, allSegDeaths) then
                        table.insert(allDeaths, {
                            name = pName,
                            class = pClass,
                            pullTime = d.pullTime,
                            time = d.time or "",
                            killer = StripColorCodes(d.killer or "Unknown Mob"),
                            ability = StripColorCodes(d.ability or "Unknown Attack"),
                            amount = tonumber(d.amount) or 0,
                            overkill = tonumber(d.overkill) or 0
                        })
                    end
                end
            end
            table.sort(allDeaths, function(a, b)
                if a.pullTime and b.pullTime and a.pullTime ~= b.pullTime then
                    return a.pullTime < b.pullTime
                end
                if a.time ~= b.time then return a.time < b.time end
                return a.name < b.name
            end)

            if #allDeaths == 0 then
                table.insert(lines, "No suspicious player deaths recorded in this segment.")
            else
                for idx, d in ipairs(allDeaths) do
                    local pullStr = FormatPullTime(d.pullTime)
                    local timeTag = pullStr and string.format("%s into pull / %s", pullStr, d.time) or d.time
                    local amt = tonumber(d.amount) or 0
                    local ovk = tonumber(d.overkill) or 0
                    local dmgText = (amt > 0) and string.format("%d dmg", amt) or "Fatal Effect"
                    if ovk > 0 then dmgText = string.format("%d dmg (%d overkill)", amt, ovk) end
                    local unusedDef = GetUnusedPersonalDefensives(seg, d.name, d.class)
                    local unusedStr = (#unusedDef > 0) and table.concat(unusedDef, ", ") or "None unused"
                    table.insert(lines, string.format(
                        "%d. [%s] %s (%s) -> Killed by %s / Ability: %s / Damage: %s / Unused Defensives: %s",
                        idx, timeTag, d.name, d.class, d.killer, d.ability, dmgText, unusedStr
                    ))
                end
            end

            currentRaidChatLines = lines
            currentPreviewText = table.concat(lines, "\n")
        end

        editBox:SetText(currentPreviewText)
        if scrollFrame.UpdateScrollChildRect then
            scrollFrame:UpdateScrollChildRect()
        end
        scrollFrame:SetVerticalScroll(0)
        editBox:ClearFocus()
    end

    btnPanelAll:SetScript("OnClick", function() activeReportPanel = "ALL"; GenerateReport() end)
    btnPanelChar:SetScript("OnClick", function() activeReportPanel = "CHAR"; GenerateReport() end)
    btnPanelFails:SetScript("OnClick", function() activeReportPanel = "FAILS"; GenerateReport() end)
    btnPanelDeaths:SetScript("OnClick", function() activeReportPanel = "DEATHS"; GenerateReport() end)

    btnFailEarly:SetScript("OnClick", function() activeFailSubMode = "EARLY"; GenerateReport() end)
    btnFailSlack:SetScript("OnClick", function() activeFailSubMode = "SLACKERS"; GenerateReport() end)
    btnFailCds:SetScript("OnClick", function() activeFailSubMode = "FAILS"; GenerateReport() end)

    chkPlain:SetScript("OnClick", function()
        activeAllFormat = "PLAIN"
        chkPlain:SetChecked(true); chkDiscord:SetChecked(false); chkHTML:SetChecked(false)
        GenerateReport()
    end)

    chkDiscord:SetScript("OnClick", function()
        activeAllFormat = "DISCORD"
        chkPlain:SetChecked(false); chkDiscord:SetChecked(true); chkHTML:SetChecked(false)
        GenerateReport()
    end)

    chkHTML:SetScript("OnClick", function()
        activeAllFormat = "HTML"
        chkPlain:SetChecked(false); chkDiscord:SetChecked(false); chkHTML:SetChecked(true)
        GenerateReport()
    end)

    btnCharBuffs:SetScript("OnClick", function() activeCharSubMode = "BUFFS"; GenerateReport() end)
    btnCharFails:SetScript("OnClick", function() activeCharSubMode = "FAILS"; GenerateReport() end)

    ReportFrame:SetScript("OnShow", GenerateReport)
end

-------------------------------------------------------------------------------
-- Config Panel Implementation (With Clear Blacklist Button)
-------------------------------------------------------------------------------
local function CreateConfigFrame()
    ConfigFrame = CreateRUTPanel("RTConfigFrame", 420, 340, "Raiders Tracker Config")

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
    btnResetPositions:SetPoint("CENTER", viewBox, "CENTER", 0, 16)
    btnResetPositions:SetText("Reset Panel Positions")
    btnResetPositions:SetScript("OnClick", function() ResetAllPanelPositions() end)

    local btnDeleteAll = CreateFrame("Button", nil, viewBox, "UIPanelButtonTemplate")
    btnDeleteAll:SetSize(200, 26)
    btnDeleteAll:SetPoint("TOP", btnResetPositions, "BOTTOM", 0, -8)
    btnDeleteAll:SetText("Delete All Sessions")

    local btnClearBlacklist = CreateFrame("Button", nil, viewBox, "UIPanelButtonTemplate")
    btnClearBlacklist:SetSize(200, 26)
    btnClearBlacklist:SetPoint("TOP", btnDeleteAll, "BOTTOM", 0, -8)
    btnClearBlacklist:SetText("Clear Blacklist")

    local btnBack = CreateFrame("Button", nil, ConfigFrame, "UIPanelButtonTemplate")
    btnBack:SetSize(130, 24)
    btnBack:SetPoint("BOTTOM", ConfigFrame, "BOTTOM", 0, 14)
    btnBack:SetText("Back to Tracker")
    btnBack:SetScript("OnClick", function() CloseAllPanels(); MainTrackerFrame:Show() end)

    StaticPopupDialogs["RT_DELETE_ALL_SESSIONS"] = {
        text = "Really delete all encounter sessions, recorded deaths, death logs, and character lists? (Your Blacklist will be preserved).",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function() WipeAllSessionsAndData() end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

    StaticPopupDialogs["RT_CLEAR_BLACKLIST"] = {
        text = "Really clear the entire player blacklist? This cannot be undone.",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            RaidersTrackerDB.blacklist = {}
            if BlacklistFrame and BlacklistFrame:IsShown() then
                RefreshBlacklistView()
            end
            AnnounceLocalChat("Player blacklist cleared.")
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

    btnDeleteAll:SetScript("OnClick", function() StaticPopup_Show("RT_DELETE_ALL_SESSIONS") end)
    btnClearBlacklist:SetScript("OnClick", function() StaticPopup_Show("RT_CLEAR_BLACKLIST") end)
end

-------------------------------------------------------------------------------
-- Slash Commands, Load Message & Group Join Refresh Prompt
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
local groupStateInitialized = false
local wasInGroup = false
local loadMsgTimer = CreateFrame("Frame")

local function IsPlayerInGroup()
    return (GetNumRaidMembers() > 0) or (GetNumPartyMembers() > 0)
end

local function CheckGroupJoinPrompt()
    local currentlyInGroup = IsPlayerInGroup()
    if not groupStateInitialized then
        wasInGroup = currentlyInGroup
        groupStateInitialized = true
        CheckGroupBlacklist()
        return
    end
    if currentlyInGroup and not wasInGroup then
        wasInGroup = true
        CheckGroupBlacklist()
        StaticPopup_Show("RT_REFRESH_ON_GROUP_JOIN")
    elseif not currentlyInGroup and wasInGroup then
        wasInGroup = false
    end
end

local function ScheduleLoadMessage(delay)
    local totalElapsed = 0
    loadMsgTimer:SetScript("OnUpdate", function(self, elapsed)
        totalElapsed = totalElapsed + elapsed
        if totalElapsed >= (delay or 2.0) then
            self:SetScript("OnUpdate", nil)
            CheckGroupBlacklist()
            if not hasPrintedLoadMsg then
                hasPrintedLoadMsg = true
                if DEFAULT_CHAT_FRAME then
                    DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00Raiders Tracker" .. RTExt.GetVersionTag() .. " by " .. AUTHOR .. " loaded.|r")
                    DEFAULT_CHAT_FRAME:AddMessage("  - |cffFFFFFFLeft-Click Minimap Icon:|r Opens Main Tracker Panel.")
                    DEFAULT_CHAT_FRAME:AddMessage("  - |cffFFFFFFRight-Click Minimap Icon:|r Opens Config Panel.")
                    DEFAULT_CHAT_FRAME:AddMessage("  - Chat commands: |cff00FF00/rt|r or |cff00FF00/rt reset|r to reset panel positions.")
                end
            end
        end
    end)
end

-------------------------------------------------------------------------------
-- Core Recording Engine (Potions/Buffs, Utility Casts, Tanks & Player Deaths)
-------------------------------------------------------------------------------
local function RecordProc(sourceName, sourceGUID, destName, destGUID, category, spellID, rawSpellName, isInstantCast)
    if not currentSession.segments[1] or currentSession.segments[1].isBoss ~= inCombatState then
        EnsureTrashSegment()
    end

    local targetSegment = currentSession.segments[1]
    if not targetSegment then return end
    targetSegment.tanks = targetSegment.tanks or {}
    targetSegment.playerIDs = targetSegment.playerIDs or {}

    local srcIsMember = IsGroupMember(sourceName, sourceGUID)
    local dstIsMember = IsGroupMember(destName, destGUID)
    local srcClass = GetSafePlayerClass(sourceName, sourceGUID)
    local dstClass = GetSafePlayerClass(destName, destGUID)
    local srcCharID = srcIsMember and CachePlayerCharID(sourceName, sourceGUID, targetSegment) or nil
    local dstCharID = dstIsMember and CachePlayerCharID(destName, destGUID, targetSegment) or nil
    local addedNewSessionPlayer = false
    local markedTankPlayer = nil

    if category == "POTIONS" then
        local pName, pClass, pCharID = nil, nil, nil
        if isInstantCast then
            if not srcIsMember then return end
            pName, pClass, pCharID = sourceName, srcClass, srcCharID
        else
            if not dstIsMember then return end
            pName, pClass, pCharID = destName, dstClass, dstCharID
        end

        targetSegment.players[pName] = pClass
        currentSession.players = currentSession.players or {}
        if not currentSession.players[pName] then addedNewSessionPlayer = true end
        currentSession.players[pName] = pClass

        local baseBuffName = POTIONS_AND_BUFFS[spellID] or rawSpellName or ("Spell #" .. tostring(spellID))
        if TANK_PROC_NAMES[baseBuffName] then
            targetSegment.tanks[pName] = true
            markedTankPlayer = pName
        elseif spellID == 57933 and (pClass == "WARRIOR" or pClass == "PALADIN" or pClass == "DEATHKNIGHT" or pClass == "DRUID") then
            targetSegment.tanks[pName] = true
            markedTankPlayer = pName
        end

        local entryName = baseBuffName
        local extraPlayer, extraClass, extraCharID = nil, nil, nil

        if not isInstantCast and srcIsMember and sourceName ~= pName then
            targetSegment.players[sourceName] = srcClass
            if not currentSession.players[sourceName] then addedNewSessionPlayer = true end
            currentSession.players[sourceName] = srcClass
            extraPlayer, extraClass, extraCharID = sourceName, srcClass, srcCharID
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
                pCharID = pCharID,
                extraPlayer = extraPlayer,
                extraClass = extraClass,
                extraCharID = extraCharID,
                isTankPlayer = markedTankPlayer,
                entryName = entryName,
                ts = GetTime()
            })
        end

    elseif category == "UTILITY" then
        if not srcIsMember then return end
        local baseName = RAID_UTILITY[spellID] or rawSpellName or ("Spell #" .. tostring(spellID))

        local requiredClass = UTILITY_CLASS_FILTER[baseName]
        if requiredClass and srcClass ~= requiredClass then return end

        targetSegment.players[sourceName] = srcClass
        currentSession.players = currentSession.players or {}
        if not currentSession.players[sourceName] then addedNewSessionPlayer = true end
        currentSession.players[sourceName] = srcClass

        if TANK_TAUNT_NAMES[baseName] then
            targetSegment.tanks[sourceName] = true
            markedTankPlayer = sourceName
        end

        local entryName = baseName
        local extraPlayer, extraClass, extraCharID = nil, nil, nil

        if dstIsMember and EXTERNAL_TARGETED_UTILITY[baseName] then
            targetSegment.players[destName] = dstClass
            if not currentSession.players[destName] then addedNewSessionPlayer = true end
            currentSession.players[destName] = dstClass
            extraPlayer, extraClass, extraCharID = destName, dstClass, dstCharID
            local coloredTarget = ColorizeText(destName, GetPlayerClassColor(dstClass))
            entryName = string.format("%s [%s]", baseName, coloredTarget)

            if (baseName == "Tricks of the Trade" or baseName == "Misdirection") and (dstClass == "WARRIOR" or dstClass == "PALADIN" or dstClass == "DEATHKNIGHT" or dstClass == "DRUID") then
                targetSegment.tanks[destName] = true
                markedTankPlayer = destName
            end
        end

        targetSegment.raidUtility[sourceName] = targetSegment.raidUtility[sourceName] or {}
        targetSegment.raidUtility[sourceName][entryName] = (targetSegment.raidUtility[sourceName][entryName] or 0) + 1

        if not inCombatState then
            table.insert(recentPrePullEvents, {
                category = "UTILITY",
                pName = sourceName,
                pClass = srcClass,
                pCharID = srcCharID,
                extraPlayer = extraPlayer,
                extraClass = extraClass,
                extraCharID = extraCharID,
                isTankPlayer = markedTankPlayer,
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
    if recentDeathLock[destName] and (now - recentDeathLock[destName]) < 4.0 then return end
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
    CachePlayerCharID(destName, destGUID, targetSegment)

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

    local isLKRPKill = (activeBossName == "The Lich King" and lichKingRPActive)
        or (ability and ability:lower():find("fury of frostmourne", 1, true) ~= nil)
    if isLKRPKill and (ability == "Fatal Effect" or ability == "Melee") then
        killer = "The Lich King"
        ability = "Fury of Frostmourne"
    end

    table.insert(targetSegment.deaths[destName], {
        time = date("%H:%M:%S"),
        pullTime = inCombatState and math.max(0, math.floor(GetTime() - bossStartTime)) or nil,
        segment = targetSegment.name or "TRASH",
        zone = targetSegment.zone or GetCurrentZoneSafe(),
        difficulty = targetSegment.difficulty or GetRaidDifficultySuffix(),
        killer = killer,
        ability = ability,
        amount = amount,
        overkill = overkill,
        isScriptedRP = isLKRPKill or nil
    })

    if DeathsFrame and DeathsFrame:IsShown() then RefreshDeathsView() end
    if DeathLogFrame and DeathLogFrame:IsShown() then RefreshDeathLogView() end
    RequestMainViewRefresh()
end

-------------------------------------------------------------------------------
-- Demonic Pact Tracking Engine (Demo Warlock Owner Only + 3.3.5a SP Capture)
-------------------------------------------------------------------------------
RTExt.dpScanTooltip = CreateFrame("GameTooltip", "RTDemonicPactScanTooltip", nil, "GameTooltipTemplate")
RTExt.dpScanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

RTExt.dpWatcherFrame = CreateFrame("Frame")

function RTExt.IsDemonicPactRaidBuff(spellID, spellName)
    if type(spellID) == "number" then
        if RTExt.DEMONIC_PACT_PASSIVE_IDS[spellID] then
            return false
        end
        if RTExt.DEMONIC_PACT_BUFF_IDS[spellID] then
            return true
        end
    end
    if type(spellName) == "string" and spellName == "Demonic Pact" then
        return true
    end
    return false
end

function RTExt.IsDemonicPactEvent(subevent, spellID, spellName)
    if subevent ~= "SPELL_AURA_APPLIED" and subevent ~= "SPELL_AURA_REFRESH" then
        return false
    end
    return RTExt.IsDemonicPactRaidBuff(spellID, spellName)
end

function RTExt.GetPlayerBaseSpellPower()
    if not GetSpellBonusDamage then return 0 end
    local minSP = nil
    for school = 2, 7 do
        local sp = GetSpellBonusDamage(school)
        if sp and (not minSP or sp < minSP) then
            minSP = sp
        end
    end
    return minSP or 0
end

function RTExt.GetPlayerDemonicPactPct()
    local _, engClass = UnitClass("player")
    if engClass ~= "WARLOCK" then return 0 end
    if GetNumTalents and GetTalentInfo then
        local numTalents = GetNumTalents(2) or 0
        for i = 1, numTalents do
            local tName, _, _, _, rank = GetTalentInfo(2, i)
            if tName == "Demonic Pact" then
                if rank and rank > 0 then
                    return rank * 0.02
                end
                return 0
            end
        end
    end
    return 0
end

function RTExt.GetPlayerBuffDPAndTotemState()
    local hasDP = false
    local totemSP = 0
    for i = 1, 40 do
        local buffName, _, _, _, _, _, _, _, _, _, bSpellID = UnitBuff("player", i)
        if not buffName then break end
        if RTExt.IsDemonicPactRaidBuff(bSpellID, buffName) then
            hasDP = true
        end
        if bSpellID and RTExt.OVERRIDDEN_SP_TOTEMS[bSpellID] then
            local val = RTExt.OVERRIDDEN_SP_TOTEMS[bSpellID]
            if val > totemSP then totemSP = val end
        end
    end
    return hasDP, totemSP
end

function RTExt.SnapshotPlayerSpellPowerState(forceUpdate)
    if not forceUpdate and #RTExt.pendingDemonicPacts > 0 then
        return
    end
    local curSP = RTExt.GetPlayerBaseSpellPower()
    local hasDP, totemSP = RTExt.GetPlayerBuffDPAndTotemState()
    local now = GetTime()

    if not RTExt.lastPlayerHasDP and hasDP then
        RTExt.preDPTransitionSP = RTExt.lastPlayerSP
        RTExt.preDPTransitionTime = now
    elseif RTExt.lastPlayerSP and RTExt.lastPlayerSP ~= curSP then
        RTExt.prevPlayerSP = RTExt.lastPlayerSP
        RTExt.prevPlayerSPTime = now
    end

    if not hasDP then
        RTExt.playerSelfDPContribution = 0
        RTExt.activeObservedDP = 0
    end

    RTExt.lastPlayerSP = curSP
    RTExt.lastPlayerHasDP = hasDP
    RTExt.lastPlayerTotemSP = totemSP
end

function RTExt.BroadcastDemonicPactSP(ownerName, spValue)
    if not ownerName or not spValue or spValue <= 0 or not SendAddonMessage then return end
    local channel = nil
    if GetNumRaidMembers() > 0 then
        channel = "RAID"
    elseif GetNumPartyMembers() > 0 then
        channel = "PARTY"
    end
    if channel then
        SendAddonMessage(RTExt.DEMONIC_PACT_ADDON_PREFIX, string.format("%s:%d", ownerName, math.floor(spValue + 0.5)), channel)
    end
end

function RTExt.HandleDemonicPactAddonMessage(prefix, msg, dist, sender)
    if prefix ~= RTExt.DEMONIC_PACT_ADDON_PREFIX or type(msg) ~= "string" then return end
    local ownerName, spStr = msg:match("^([^:]+):(%d+)$")
    local spVal = tonumber(spStr)
    if not ownerName or not spVal or spVal <= 0 then return end
    if ownerName == UnitName("player") then return end

    local senderShort = sender and (sender:match("^([^%-]+)") or sender) or nil
    if senderShort and senderShort ~= ownerName then return end

    for _, pending in ipairs(RTExt.pendingDemonicPacts) do
        if pending.ownerName == ownerName then
            pending.syncedSP = spVal
            return
        end
    end

    local seg = currentSession and currentSession.segments and currentSession.segments[1]
    if seg and seg.demonicPactValues and seg.demonicPactValues[ownerName] then
        local dpList = seg.demonicPactValues[ownerName]
        local lastIdx = #dpList
        local confirmedAt = RTExt.lastDemonicPactConfirmedAt[ownerName]
        if lastIdx > 0 and confirmedAt and (GetTime() - confirmedAt) <= 2.0 then
            dpList[lastIdx] = spVal
            RequestMainViewRefresh()
        end
    end
end

function RTExt.OwnerInfoFromCasterUnit(unitCaster)
    if not unitCaster or unitCaster == "" then return nil end
    if RTExt.petUnitToOwner[unitCaster] then
        return RTExt.petUnitToOwner[unitCaster]
    end
    local ownerUnit = nil
    local petUnit = nil
    if unitCaster == "pet" then
        ownerUnit = "player"
        petUnit = "pet"
    elseif unitCaster:match("^raidpet(%d+)$") then
        ownerUnit = "raid" .. unitCaster:match("^raidpet(%d+)$")
        petUnit = unitCaster
    elseif unitCaster:match("^partypet(%d+)$") then
        ownerUnit = "party" .. unitCaster:match("^partypet(%d+)$")
        petUnit = unitCaster
    elseif unitCaster == "player" or unitCaster:match("^raid%d+$") or unitCaster:match("^party%d+$") then
        ownerUnit = unitCaster
    end
    if ownerUnit and UnitExists(ownerUnit) then
        local ownerName = UnitName(ownerUnit)
        local ownerGUID = UnitGUID(ownerUnit)
        local _, engClass = UnitClass(ownerUnit)
        if ownerName and ownerName ~= UNKNOWN then
            return {
                name = ownerName,
                guid = ownerGUID,
                class = engClass or GetSafePlayerClass(ownerName, ownerGUID),
                unit = ownerUnit,
                petUnit = petUnit,
            }
        end
    end
    return nil
end

function RTExt.ExtractSpellPowerFromTooltip()
    local numLines = RTExt.dpScanTooltip:NumLines() or 0
    local fallbackNum = nil
    for lineIdx = 2, numLines do
        local fs = _G["RTDemonicPactScanTooltipTextLeft" .. lineIdx]
        local lineText = fs and fs:GetText()
        if lineText and lineText ~= "" then
            local lower = lineText:lower()
            local isDurationLine = (lower:find("remaining") ~= nil or lower:find("sec") ~= nil or lower:find("min") ~= nil)
                and (lower:find("spell") == nil and lower:find("power") == nil and lower:find("damage") == nil)
            if not isDurationLine then
                local numStr = lineText:match("(%d[%d,]*)")
                if numStr then
                    local val = tonumber((numStr:gsub(",", "")))
                    if val and val > 0 then
                        if lower:find("spell") or lower:find("power") or lower:find("damage") then
                            return val
                        elseif not fallbackNum and lineIdx == 2 then
                            fallbackNum = val
                        end
                    end
                end
            end
        end
    end
    return fallbackNum
end

function RTExt.ReadDemonicPactFromUnit(unit, expectedPetUnit, expectedOwnerUnit, expectedOwnerName, strictCaster)
    if not unit or not UnitExists(unit) then return nil end
    for i = 1, 40 do
        local buffName, _, _, _, _, _, _, unitCaster, _, _, bSpellID = UnitBuff(unit, i)
        if not buffName then break end
        if RTExt.IsDemonicPactRaidBuff(bSpellID, buffName) then
            local casterOwner = unitCaster and RTExt.OwnerInfoFromCasterUnit(unitCaster) or nil
            local casterMatches = false
            if strictCaster then
                casterMatches = (expectedPetUnit and unitCaster == expectedPetUnit)
                    or (expectedOwnerUnit and unitCaster == expectedOwnerUnit)
                    or (casterOwner and expectedOwnerName and casterOwner.name == expectedOwnerName)
            else
                casterMatches = (not casterOwner) or (not expectedOwnerName) or (casterOwner.name == expectedOwnerName)
            end
            if casterMatches then
                RTExt.dpScanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
                RTExt.dpScanTooltip:ClearLines()
                RTExt.dpScanTooltip:SetUnitBuff(unit, i)
                local sp = RTExt.ExtractSpellPowerFromTooltip()
                if sp and sp > 0 then
                    return sp
                end
            end
        end
    end
    return nil
end

function RTExt.CollectUnitsForDemonicPactCheck(pending)
    local unitsToCheck = {}
    local seen = {}
    local function AddUnit(u)
        if u and not seen[u] and UnitExists(u) then
            seen[u] = true
            table.insert(unitsToCheck, u)
        end
    end

    for _, u in ipairs(pending.candidateUnits or {}) do
        AddUnit(u)
    end
    AddUnit(pending.ownerUnit)
    AddUnit("player")

    local numRaid = GetNumRaidMembers()
    if numRaid > 0 then
        for i = 1, numRaid do AddUnit("raid" .. i) end
    else
        for i = 1, GetNumPartyMembers() do AddUnit("party" .. i) end
    end
    return unitsToCheck
end

function RTExt.GetDemonicPactAuraTiming(pending)
    local unitsToCheck = RTExt.CollectUnitsForDemonicPactCheck(pending)
    local function FindTiming(strictCaster)
        for _, u in ipairs(unitsToCheck) do
            for i = 1, 40 do
                local buffName, _, _, _, _, duration, expirationTime, unitCaster, _, _, bSpellID = UnitBuff(u, i)
                if not buffName then break end
                if RTExt.IsDemonicPactRaidBuff(bSpellID, buffName) then
                    local casterOwner = unitCaster and RTExt.OwnerInfoFromCasterUnit(unitCaster) or nil
                    local matches = false
                    if strictCaster then
                        matches = (pending.petUnit and unitCaster == pending.petUnit)
                            or (pending.ownerUnit and unitCaster == pending.ownerUnit)
                            or (casterOwner and pending.ownerName and casterOwner.name == pending.ownerName)
                    else
                        matches = (not casterOwner) or (not pending.ownerName) or (casterOwner.name == pending.ownerName)
                    end
                    if matches then
                        return expirationTime, duration
                    end
                end
            end
        end
        return nil, nil
    end

    local exp, dur = FindTiming(true)
    if exp and exp > 0 then return exp, dur end
    return FindTiming(false)
end

function RTExt.ScanRaidForDemonicPactSP(pending)
    local unitsToCheck = RTExt.CollectUnitsForDemonicPactCheck(pending)

    if pending.petUnit or pending.ownerUnit or pending.ownerName then
        for _, u in ipairs(unitsToCheck) do
            local sp = RTExt.ReadDemonicPactFromUnit(u, pending.petUnit, pending.ownerUnit, pending.ownerName, true)
            if sp and sp > 0 then return sp end
        end
    end

    for _, u in ipairs(unitsToCheck) do
        local sp = RTExt.ReadDemonicPactFromUnit(u, pending.petUnit, pending.ownerUnit, pending.ownerName, false)
        if sp and sp > 0 then return sp end
    end

    return nil
end

function RTExt.ResolveDemonicPactSpellPower(pending)
    -- Priority 1: Exact value synced from the Warlock whose pet procced DP via addon channel
    if pending.syncedSP and pending.syncedSP > 0 then
        RTExt.activeObservedDP = pending.syncedSP
        return pending.syncedSP
    end

    -- Priority 2: Direct calculation ONLY if the local player's own pet procced DP AND player currently has Demonic Pact talented
    if pending.isSelfWarlock and pending.dpPct and pending.dpPct > 0 then
        local pct = pending.dpPct
        local postSP = RTExt.GetPlayerBaseSpellPower()
        if postSP <= 0 then postSP = pending.immediateSP or pending.preSP or 0 end
        if postSP > 0 then
            local spValue = nil
            local preSP = pending.preSP or postSP
            if not pending.hadDPBefore then
                local delta = postSP - preSP
                local expectedFromPre = math.floor(preSP * pct + 0.5)
                if preSP > 0 and expectedFromPre > 0 and delta >= math.floor(expectedFromPre * 0.70) and delta <= math.ceil(expectedFromPre * 1.35) then
                    spValue = expectedFromPre
                    RTExt.playerSelfDPContribution = spValue
                else
                    RTExt.playerSelfDPContribution = 0
                    spValue = math.floor(postSP * pct + 0.5)
                end
            else
                if (RTExt.playerSelfDPContribution or 0) > 0 then
                    local trueBaseSP = postSP / (1 + pct)
                    spValue = math.floor(trueBaseSP * pct + 0.5)
                    RTExt.playerSelfDPContribution = spValue
                else
                    spValue = math.floor(postSP * pct + 0.5)
                end
            end
            if spValue and spValue > 0 then
                RTExt.activeObservedDP = spValue
                RTExt.BroadcastDemonicPactSP(pending.ownerName, spValue)
                return spValue
            end
        end
    end

    -- Priority 3: Tooltip check (supports servers that populate dynamic tooltip values)
    local tooltipSP = RTExt.ScanRaidForDemonicPactSP(pending)
    if tooltipSP and tooltipSP > 0 then
        RTExt.activeObservedDP = tooltipSP
        return tooltipSP
    end

    -- Priority 4: Live GetSpellBonusDamage stat-delta fallback on local player when another Warlock's pet procs DP
    local nowHasDP = RTExt.GetPlayerBuffDPAndTotemState()
    if nowHasDP then
        local postSP = RTExt.GetPlayerBaseSpellPower()
        local preSP = pending.preSP or postSP
        local delta = postSP - preSP
        if not pending.hadDPBefore then
            local effective = delta + (pending.preTotemSP or 0)
            if effective > 0 and effective < 2500 then
                RTExt.activeObservedDP = math.floor(effective + 0.5)
                return RTExt.activeObservedDP
            end
        elseif (RTExt.activeObservedDP or 0) > 0 then
            local candidate = RTExt.activeObservedDP + delta
            if candidate > 0 and candidate < 2500 then
                RTExt.activeObservedDP = math.floor(candidate + 0.5)
                return RTExt.activeObservedDP
            end
        end
    end

    return nil
end

function RTExt.ResolveDemonicPactOwner(sourceName, sourceGUID, destUnit)
    -- Strictly resolve only the Warlock whose pet actually procced Demonic Pact in this event.
    -- Never lock in a Warlock from earlier fights or talent/stat assumptions.
    local ownerInfo = nil
    local sourceIsPetOrNPC = (sourceGUID ~= nil and not IsPlayerGUID(sourceGUID))

    if sourceGUID and RTExt.petGUIDToOwner[sourceGUID] then
        ownerInfo = RTExt.petGUIDToOwner[sourceGUID]
    elseif sourceIsPetOrNPC then
        UpdateGroupCache()
        if RTExt.petGUIDToOwner[sourceGUID] then
            ownerInfo = RTExt.petGUIDToOwner[sourceGUID]
        end
    end

    if not ownerInfo and destUnit and UnitExists(destUnit) then
        for i = 1, 40 do
            local buffName, _, _, _, _, _, _, unitCaster, _, _, bSpellID = UnitBuff(destUnit, i)
            if not buffName then break end
            if RTExt.IsDemonicPactRaidBuff(bSpellID, buffName) and unitCaster then
                local isPetCaster = (unitCaster == "pet" or unitCaster:match("^raidpet%d+$") or unitCaster:match("^partypet%d+$"))
                if isPetCaster or (not sourceIsPetOrNPC) then
                    ownerInfo = RTExt.OwnerInfoFromCasterUnit(unitCaster)
                    if ownerInfo then break end
                end
            end
        end
    end

    if not ownerInfo and sourceIsPetOrNPC and sourceName then
        local mapped = RTExt.petNameToOwner[sourceName]
        if type(mapped) == "table" then
            ownerInfo = mapped
        end
    end

    if not ownerInfo and not sourceIsPetOrNPC and sourceName and IsGroupMember(sourceName, sourceGUID) then
        local srcClass = GetSafePlayerClass(sourceName, sourceGUID)
        if srcClass == "WARLOCK" then
            ownerInfo = {
                name = sourceName,
                guid = sourceGUID,
                class = "WARLOCK",
                unit = RTExt.playerNameToUnit[sourceName],
                petUnit = nil,
            }
        end
    end

    if not ownerInfo or not ownerInfo.name then return nil end
    local ownerClass = ownerInfo.class or GetSafePlayerClass(ownerInfo.name, ownerInfo.guid)
    if ownerClass ~= "WARLOCK" then return nil end
    if not IsGroupMember(ownerInfo.name, ownerInfo.guid) then return nil end
    ownerInfo.class = "WARLOCK"
    return ownerInfo
end

function RTExt.RecordDemonicPactProc(pending, spValue)
    if not pending or not pending.ownerName then return end
    local ownerName = pending.ownerName
    local ownerGUID = pending.ownerGUID
    local ownerClass = "WARLOCK"

    local targetSegment = pending.segment
    if pending.isPrePull and inCombatState and currentSession and currentSession.segments[1] and currentSession.segments[1].isBoss then
        targetSegment = currentSession.segments[1]
        pending.isPrePull = false
    end
    if not targetSegment then
        if not currentSession or not currentSession.segments[1] then
            EnsureTrashSegment()
        end
        targetSegment = currentSession and currentSession.segments[1]
    end
    if not targetSegment then return end

    local ownerCharID = CachePlayerCharID(ownerName, ownerGUID, targetSegment)
    targetSegment.players = targetSegment.players or {}
    targetSegment.players[ownerName] = ownerClass
    currentSession.players = currentSession.players or {}
    local addedNewSessionPlayer = (currentSession.players[ownerName] == nil)
    currentSession.players[ownerName] = ownerClass

    local recordedSP = (spValue and spValue > 0) and math.floor(spValue + 0.5) or "?"

    targetSegment.raidUtility = targetSegment.raidUtility or {}
    targetSegment.raidUtility[ownerName] = targetSegment.raidUtility[ownerName] or {}
    targetSegment.raidUtility[ownerName]["Demonic Pact"] = (targetSegment.raidUtility[ownerName]["Demonic Pact"] or 0) + 1

    targetSegment.demonicPactValues = targetSegment.demonicPactValues or {}
    targetSegment.demonicPactValues[ownerName] = targetSegment.demonicPactValues[ownerName] or {}
    table.insert(targetSegment.demonicPactValues[ownerName], recordedSP)

    if pending.isPrePull and not inCombatState then
        table.insert(recentPrePullEvents, {
            category = "UTILITY",
            pName = ownerName,
            pClass = ownerClass,
            pCharID = ownerCharID,
            entryName = "Demonic Pact",
            dpValue = recordedSP,
            ts = pending.createdAt or GetTime(),
        })
    end

    if addedNewSessionPlayer and CharacterFrame and CharacterFrame:IsShown() then
        RefreshCharactersView()
    end
    RequestMainViewRefresh()
end

function RTExt.OnDemonicPactWatcherUpdate(self, elapsed)
    local list = RTExt.pendingDemonicPacts
    if #list == 0 then
        self:SetScript("OnUpdate", nil)
        return
    end
    local now = GetTime()
    local i = 1
    while i <= #list do
        local pending = list[i]
        if now >= pending.readyAt then
            local ownerName = pending.ownerName
            local curExpiry, curDur = RTExt.GetDemonicPactAuraTiming(pending)
            local lastExpiry = RTExt.lastDemonicPactExpiry[ownerName]

            -- Reject non-refresh aura re-evaluations (Shaman totem pulses, range re-entry, battle-rez)
            local isDuplicateAura = false
            if curExpiry and curExpiry > 0 then
                if lastExpiry and lastExpiry > now and curExpiry <= (lastExpiry + 3.0) then
                    isDuplicateAura = true
                elseif curDur and curDur >= 30 and (curExpiry - now) < (curDur - 8.0) then
                    isDuplicateAura = true
                end
            end

            if isDuplicateAura then
                table.remove(list, i)
            else
                local sp = RTExt.ResolveDemonicPactSpellPower(pending)
                if (sp and sp > 0) or now >= pending.maxWaitAt then
                    table.remove(list, i)
                    RTExt.lastDemonicPactConfirmedAt[ownerName] = now
                    RTExt.recentDemonicPact[ownerName] = now
                    if curExpiry and curExpiry > now then
                        RTExt.lastDemonicPactExpiry[ownerName] = curExpiry
                    else
                        RTExt.lastDemonicPactExpiry[ownerName] = now + 45.0
                    end
                    RTExt.RecordDemonicPactProc(pending, sp)
                else
                    i = i + 1
                end
            end
        else
            i = i + 1
        end
    end
    if #list == 0 then
        self:SetScript("OnUpdate", nil)
        RTExt.SnapshotPlayerSpellPowerState(true)
    end
end

function RTExt.HandleDemonicPactCLEU(subevent, sourceGUID, sourceName, destGUID, destName, spellID, spellName)
    if not RTExt.IsDemonicPactEvent(subevent, spellID, spellName) then return end

    -- Only track raid/party player destinations (ignore temporary pets/guardians like ghouls, Mirror Images, etc.)
    if not destName or not IsGroupMember(destName, destGUID) then return end

    local destUnit = (destGUID and RTExt.playerGUIDToUnit[destGUID]) or (destName and RTExt.playerNameToUnit[destName]) or nil
    local ownerInfo = RTExt.ResolveDemonicPactOwner(sourceName, sourceGUID, destUnit)
    if not ownerInfo then return end

    local ownerName = ownerInfo.name
    local now = GetTime()

    for _, pending in ipairs(RTExt.pendingDemonicPacts) do
        if pending.ownerName == ownerName then
            if destUnit then
                local exists = false
                for _, u in ipairs(pending.candidateUnits) do
                    if u == destUnit then exists = true; break end
                end
                if not exists then table.insert(pending.candidateUnits, destUnit) end
            end
            return
        end
    end

    local lastConfirmed = RTExt.lastDemonicPactConfirmedAt[ownerName]
    local lastExpiry = RTExt.lastDemonicPactExpiry[ownerName]
    if lastConfirmed and (now - lastConfirmed) < RTExt.DEMONIC_PACT_ICD then
        -- While the previous proc's 45s aura is still active (or within 2.5s burst window), suppress duplicates
        if (lastExpiry and lastExpiry > now) or (now - lastConfirmed) < 2.5 then
            return
        end
    end

    if not currentSession.segments[1] or currentSession.segments[1].isBoss ~= inCombatState then
        EnsureTrashSegment()
    end
    local targetSegment = currentSession and currentSession.segments[1]
    if not targetSegment then return end

    local isSelfWarlock = (ownerName == UnitName("player"))
    local dpPct = isSelfWarlock and RTExt.GetPlayerDemonicPactPct() or 0
    local immediateSP = RTExt.GetPlayerBaseSpellPower()
    local preSP = RTExt.lastPlayerSP or immediateSP
    local hadDPBefore = RTExt.lastPlayerHasDP

    if RTExt.preDPTransitionSP and (now - (RTExt.preDPTransitionTime or 0)) <= 0.5 then
        preSP = RTExt.preDPTransitionSP
        hadDPBefore = false
    elseif RTExt.prevPlayerSP and (now - (RTExt.prevPlayerSPTime or 0)) <= 0.25 and immediateSP == RTExt.lastPlayerSP then
        preSP = RTExt.prevPlayerSP
    end

    table.insert(RTExt.pendingDemonicPacts, {
        ownerName = ownerName,
        ownerGUID = ownerInfo.guid,
        ownerClass = "WARLOCK",
        ownerUnit = ownerInfo.unit or RTExt.playerNameToUnit[ownerName],
        petUnit = ownerInfo.petUnit,
        candidateUnits = destUnit and { destUnit } or {},
        segment = targetSegment,
        isPrePull = not inCombatState,
        isSelfWarlock = isSelfWarlock,
        dpPct = dpPct,
        preSP = preSP,
        immediateSP = immediateSP,
        hadDPBefore = hadDPBefore,
        preTotemSP = RTExt.lastPlayerTotemSP or 0,
        syncedSP = nil,
        createdAt = now,
        readyAt = now + (isSelfWarlock and 0.10 or 0.15),
        maxWaitAt = now + 0.45,
    })

    if not RTExt.dpWatcherFrame:GetScript("OnUpdate") then
        RTExt.dpWatcherFrame:SetScript("OnUpdate", RTExt.OnDemonicPactWatcherUpdate)
    end
end

-------------------------------------------------------------------------------
-- Event Dispatcher
-------------------------------------------------------------------------------
local eventHandler = CreateFrame("Frame")

eventHandler:RegisterEvent("ADDON_LOADED")
eventHandler:RegisterEvent("PLAYER_ENTERING_WORLD")
eventHandler:RegisterEvent("PARTY_MEMBERS_CHANGED")
eventHandler:RegisterEvent("RAID_ROSTER_UPDATE")
eventHandler:RegisterEvent("UNIT_PET")
eventHandler:RegisterEvent("UNIT_AURA")
eventHandler:RegisterEvent("UNIT_STATS")
eventHandler:RegisterEvent("CHAT_MSG_ADDON")
eventHandler:RegisterEvent("PLAYER_TALENT_UPDATE")
eventHandler:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
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
            RTExt.CreatePotionsFrame()
            CreateCharacterFrame()
            RTExt.CreateCharacterExportFrame()
            CreateReportFrame()
            CreateConfigFrame()
            CreateDeathsFrame()
            CreateDeathLogFrame()
            CreateBlacklistFrame()
            RTExt.CreateBlacklistExportFrame()
            RTExt.CreateBlacklistImportFrame()
            RTExt.CreateBlacklistTextFrame()
            UpdateGroupCache()
            EnsureTrashSegment()
        end
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        UpdateGroupCache()
        wasInGroup = IsPlayerInGroup()
        groupStateInitialized = true
        RTExt.SnapshotPlayerSpellPowerState(true)
        HandleZoneOrDifficultyUpdate(false)
        CheckGroupBlacklist()
        if not hasPrintedLoadMsg then ScheduleLoadMessage(2.0) end
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

    if event == "UNIT_AURA" or event == "UNIT_STATS" then
        local unit = ...
        if unit == "player" then
            RTExt.SnapshotPlayerSpellPowerState(false)
        end
        return
    end

    if event == "CHAT_MSG_ADDON" then
        local prefix, msg, dist, sender = ...
        RTExt.HandleDemonicPactAddonMessage(prefix, msg, dist, sender)
        return
    end

    if event == "PLAYER_TALENT_UPDATE" or event == "ACTIVE_TALENT_GROUP_CHANGED" then
        RTExt.playerSelfDPContribution = 0
        RTExt.activeObservedDP = 0
        RTExt.preDPTransitionSP = nil
        UpdateGroupCache()
        RTExt.SnapshotPlayerSpellPowerState(true)
        return
    end

    if event == "UNIT_PET" then
        UpdateGroupCache()
        return
    end

    if event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
        UpdateGroupCache()
        if not IsPlayerInGroup() then
            RTExt.CloseAllActiveZoneStints(currentSession)
        end
        CheckGroupJoinPrompt()
        CheckGroupBlacklist()
        HandleZoneOrDifficultyUpdate(false)
        if CharacterFrame and CharacterFrame:IsShown() then
            RefreshCharactersView()
        end
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

    if event == "CHAT_MSG_MONSTER_YELL" or event == "CHAT_MSG_MONSTER_EMOTE" or event == "CHAT_MSG_RAID_BOSS_EMOTE" then
        local msg = ...
        msg = msg or ""
        local lowerMsg = msg:lower()

        if not inCombatState then
            for phrase, bossName in pairs(BOSS_ENGAGE_SPEECH) do
                if lowerMsg:find(phrase:lower(), 1, true) then
                    StartEncounter(nil, bossName, nil, true)
                    break
                end
            end
        else
            if activeBossName == "The Lich King" then
                for _, rpPhrase in ipairs(LICH_KING_RP_SPEECH) do
                    if lowerMsg:find(rpPhrase, 1, true) then
                        if not RTExt.lichKingFuryTime and rpPhrase == "no questions remain unanswered" then
                            RTExt.lichKingFuryTime = GetTime()
                        end
                        lichKingRPActive = true
                        lichKingRPElapsed = 0
                        outOfCombatAccum = 0
                        break
                    end
                end
            end

            for phrase, bossName in pairs(BOSS_DEFEAT_SPEECH) do
                if lowerMsg:find(phrase:lower(), 1, true) and activeBossName == bossName then
                    EndEncounter(true, "Boss Defeat Speech Triggered")
                    break
                end
            end
        end
        return
    end

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subevent, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, arg9, arg10, arg11, arg12, arg13 = ...

        if sourceName and sourceGUID and IsGroupMember(sourceName, sourceGUID) then
            CachePlayerCharID(sourceName, sourceGUID)
        end
        if destName and destGUID and IsGroupMember(destName, destGUID) then
            CachePlayerCharID(destName, destGUID)
        end

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

        if type(spellID) == "number" then
            if inCombatState then
                if activeBossName == "Valithria Dreamwalker" and spellID == 71189 then
                    EndEncounter(true, "Valithria Dreamwalker Healed to 100%")
                    return
                end
                if activeBossName == "The Lich King" then
                    local isFuryOfFrostmourne = (spellID == 72350)
                        or (type(spellName) == "string" and spellName:lower():find("fury of frostmourne", 1, true) ~= nil)
                    if isFuryOfFrostmourne then
                        if not RTExt.lichKingFuryTime then
                            RTExt.lichKingFuryTime = GetTime()
                        end
                        lichKingRPActive = true
                        lichKingRPElapsed = 0
                        outOfCombatAccum = 0
                    elseif spellID == 70063 or spellID == 71769 or spellID == 72398 or spellID == 72429 or spellID == 72423 then
                        lichKingRPActive = true
                        lichKingRPElapsed = 0
                        outOfCombatAccum = 0
                    end
                end
            end

            if ENEMY_ENRAGE_SPELLS[spellID] and (subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REFRESH" or subevent == "SPELL_CAST_SUCCESS") then
                local mobName = (subevent == "SPELL_CAST_SUCCESS") and sourceName or destName
                local mobGUID = (subevent == "SPELL_CAST_SUCCESS") and sourceGUID or destGUID
                if mobName and not IsGroupMember(mobName, mobGUID) then
                    local enrageKey = "ENR_" .. (mobGUID or mobName) .. "_" .. tostring(spellID)
                    local now = GetTime()
                    if not recentProcs[enrageKey] or (now - recentProcs[enrageKey]) > 2.0 then
                        recentProcs[enrageKey] = now
                        local targetSegment = currentSession and currentSession.segments[1]
                        if targetSegment then
                            targetSegment.enrages = targetSegment.enrages or {}
                            targetSegment.enrages[mobName] = (targetSegment.enrages[mobName] or 0) + 1
                        end
                    end
                end
            end

            if TANK_STANCE_BUFFS[spellID] and (subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REFRESH") and destName and IsGroupMember(destName, destGUID) then
                local targetSegment = currentSession and currentSession.segments[1]
                if targetSegment then
                    targetSegment.tanks = targetSegment.tanks or {}
                    targetSegment.tanks[destName] = true
                end
            end
        end

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

        if subevent == "UNIT_DIED" then
            if destName and IsGroupMember(destName, destGUID) then
                RecordPlayerDeath(destName, destGUID)
            end

            if inCombatState then
                local deadID = GetNPCIDFromGUID(destGUID)
                if deadID and WOTLK_BOSS_DB[deadID] and not WOTLK_BOSS_DB[deadID].isAdd then
                    local bInfo = activeBossName and BOSS_NAME_TO_INFO[activeBossName]
                    if bInfo and bInfo.isFactionChamp and WOTLK_BOSS_DB[deadID].isFactionChamp then
                        if destGUID then defeatedGroupNPCs[destGUID] = true else defeatedGroupNPCs[deadID] = true end
                        local killedCount = 0
                        for _ in pairs(defeatedGroupNPCs) do killedCount = killedCount + 1 end
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
                                if not defeatedGroupNPCs[reqID] then allDead = false; break end
                            end
                            if allDead then EndEncounter(true, "Boss Group Defeated") end
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

            if subevent == "SPELL_AURA_REMOVED" and destGUID == UnitGUID("player") and RTExt.IsDemonicPactRaidBuff(spellID, spellName) then
                RTExt.playerSelfDPContribution = 0
                RTExt.activeObservedDP = 0
                if GetNumRaidMembers() == 0 and GetNumPartyMembers() == 0 then
                    local myName = UnitName("player")
                    if myName then
                        RTExt.lastDemonicPactExpiry[myName] = nil
                    end
                end
            end

            if RTExt.IsDemonicPactEvent(subevent, spellID, spellName) then
                RTExt.HandleDemonicPactCLEU(subevent, sourceGUID, sourceName, destGUID, destName, spellID, spellName)
            end
        end
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        EnsureTrashSegment()
    elseif event == "PLAYER_REGEN_ENABLED" then
        table.wipe(recentProcs)
    end
end)
