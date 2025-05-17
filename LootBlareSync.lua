local previousRaidMembers = {}
local PREFIX = "LootBlareKBSync"

---------------------------------------------------------------------
--                            UTILITY
---------------------------------------------------------------------

local function OnLeaveGroup()
    LootBlare.msplus = {}
    LootBlare:ResetMSPlusTable()
     DEFAULT_CHAT_FRAME:AddMessage("[LootBlare DEBUG] OnLeaveGroup: Cleared msplus table.", 1, 0, 0)
end

local function GetRaidMemberNames()
    local names = {}
    for i = 1, GetNumRaidMembers() do
        local name = GetRaidRosterInfo(i)
        if name then
            names[name] = true
        end
    end
    return names
end

function LootBlare:IsSenderMasterLooter(sender)
  local lootMethod, masterLooterPartyID = GetLootMethod()
  if lootMethod == "master" and masterLooterPartyID then
    if masterLooterPartyID == 0 then
      return sender == UnitName("player")
    else
      local senderUID = "party" .. masterLooterPartyID
      local masterLooterName = UnitName(senderUID)
      return masterLooterName == sender
    end
  end
  return false
end

function LootBlare:ResetMSPlusTable(defaultPoints)
    defaultPoints = defaultPoints or 0
    -- Clear the current table
    LootBlare.msplus = {}

    local numRaidMembers = GetNumRaidMembers()

    if numRaidMembers == 0 then
        -- Clear scroll frame as well
        if LootBlare.ClearRows then
            LootBlare:ClearRows()
        end
        if LootBlare.UpdateScrollFrame then
            LootBlare:UpdateScrollFrame()
        end
         DEFAULT_CHAT_FRAME:AddMessage("[LootBlare DEBUG] ResetMSPlusTable: No raid members, msplus cleared.", 1, 0, 0)
        return
    end

    for i = 1, numRaidMembers do
        local name = GetRaidRosterInfo(i)
        if name then
            table.insert(LootBlare.msplus, { name = name, points = defaultPoints })
            DEFAULT_CHAT_FRAME:AddMessage(string.format("[LootBlare DEBUG] ResetMSPlusTable: Added %s with %d points.", name, defaultPoints), 0, 1, 0)
        end
    end

    -- Update scroll frame
    LootBlare:UpdateScrollFrame()
end

local function UpdateMSPlusTable()
    if not LootBlare.msplus then
        LootBlare.msplus = {}
        DEFAULT_CHAT_FRAME:AddMessage("[LootBlare DEBUG] UpdateMSPlusTable: msplus table was nil, reinitialized.", 1, 0, 0)
    end

    -- Convert existing list to a lookup for faster access
    local nameToEntry = {}
    for _, entry in ipairs(LootBlare.msplus) do
        nameToEntry[entry.name] = entry
    end

    local numRaidMembers = GetNumRaidMembers()
    if numRaidMembers == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("[LootBlare DEBUG] UpdateMSPlusTable: No raid members to update.", 1, 0, 0)
        return
    end

    for i = 1, numRaidMembers do
        local name = GetRaidRosterInfo(i)
        if name then
            if not nameToEntry[name] then
                -- Add new member with default points
                table.insert(LootBlare.msplus, { name = name, points = 0 })
                DEFAULT_CHAT_FRAME:AddMessage(string.format("[LootBlare DEBUG] UpdateMSPlusTable: Added new raid member %s with 0 points.", name), 0, 1, 0)
            end
             DEFAULT_CHAT_FRAME:AddMessage(string.format("[LootBlare DEBUG] UpdateMSPlusTable: Member %s already exists, points = %d.", name, nameToEntry[name].points), 0, 0.5, 1)
            -- If name exists, no overwrite — just keep their current points
            -- (You can optionally refresh name casing or other values here if needed)
        end
    end
    LootBlare:UpdateScrollFrame()
end


---------------------------------------------------------------------
--                    Synchronization - Outbound
---------------------------------------------------------------------

local function SendSRSyncMessage()
    if LootBlare:IsSenderMasterLooter(UnitName("player")) == false then return end
    --DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] Sending sr sync message", 1, 0, 0)
    if not LootBlare.rollBonuses then
        DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] No rollBonuses to sync", 1, 0, 0)
        return
    end

    -- Send START sync message
    SendAddonMessage(PREFIX, "START_SR_DATA", "RAID")
    local maxLength = 220 -- Safety buffer for prefix, names, etc.
    local batchStr = ""
    
    for player, items in pairs(LootBlare.rollBonuses) do
        for itemID, bonus in pairs(items) do
            local entry = player .. ":" .. itemID .. ":" .. bonus
            if batchStr == "" then
                batchStr = entry
            else
                batchStr = batchStr .. ";" .. entry
            end

            -- Check if adding more would exceed safe limit
            if string.len(PREFIX .. "SR_DATA " .. batchStr) >= maxLength then
                SendAddonMessage(PREFIX, "SR_DATA " .. batchStr, "RAID")
                batchStr = ""
            end
        end
    end

    -- Send remaining batch
    if batchStr ~= "" then
        SendAddonMessage(PREFIX, "SR_DATA " .. batchStr, "RAID")
    end

    -- End signal
    SendAddonMessage(PREFIX, "END_SR_DATA", "RAID")
end

local function SendMSSyncMessage()
    if LootBlare:IsSenderMasterLooter(UnitName("player")) == false then return end
    --DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] Sending ms sync message", 1, 0, 0)
    if not LootBlare.msplus then
        DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] No ms+1 to sync", 1, 0, 0)
        return
    end

    -- Send START sync message
    SendAddonMessage(PREFIX, "START_MS_DATA", "RAID")
    local maxLength = 220 -- Safety buffer for prefix, names, etc.
    local batchStr = ""
    
    for i, member in pairs(LootBlare.msplus) do   
            local entry = member.name .. ":" .. member.points 
            if batchStr == "" then
                batchStr = entry
            else
                batchStr = batchStr .. ";" .. entry
            end

            -- Check if adding more would exceed safe limit
            if string.len(PREFIX .. "MS_DATA " .. batchStr) >= maxLength then
                SendAddonMessage(PREFIX, "MS_DATA " .. batchStr, "RAID")
                batchStr = ""
            end
    end

    -- Send remaining batch
    if batchStr ~= "" then
        SendAddonMessage(PREFIX, "MS_DATA " .. batchStr, "RAID")
    end

    -- End signal
    SendAddonMessage(PREFIX, "END_MS_DATA", "RAID")
end

-- Sync with entire raid group
function LootBlare:SyncRaid()
    if LootBlare:IsSenderMasterLooter(UnitName("player")) == false then return end
    --DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] ML Syncing with raid.")
    local currentRaidMembers = GetRaidMemberNames()
    for name in pairs(currentRaidMembers) do
        if name ~= UnitName("player") then
            SendSRSyncMessage()
            SendMSSyncMessage()
        end
    end
    SendAddonMessage(PREFIX, "ML "..UnitName("player"), "RAID")
    previousRaidMembers = currentRaidMembers
end

local function OnRaidUpdate()
    local someoneJoinedOrLeft = false
    local currentRaidMembers = GetRaidMemberNames()

    -- Check for new members
    for name in pairs(currentRaidMembers) do
        if not previousRaidMembers[name] then
            --DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] Raid member joined: " .. name, 0, 1, 0)
            SendSRSyncMessage()
            SendMSSyncMessage()
            someoneJoinedOrLeft = true
        end
    end

    -- Check for members who left
    for name in pairs(previousRaidMembers) do
        if not currentRaidMembers[name] then
            --DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] Raid member left: " .. name, 1, 0, 0)
            someoneJoinedOrLeft = true
        end
    end

    -- Update the stored list
    if someoneJoinedOrLeft then
        previousRaidMembers = currentRaidMembers
    end
end

local function RequestSync()
    if LootBlare:IsSenderMasterLooter(UnitName("player")) then 
        LootBlare.masterLooter = UnitName("player")
        return
    end
    SendAddonMessage(PREFIX, "REQ_SYNC", "RAID")
    DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] Sending a Sync Request.", 1, 1, 0)
end


local function TryRequestSync()
    if GetNumRaidMembers() > 0 then
        RequestSync()
        return true
    end
    return false
end

local delayFrame = CreateFrame("Frame")
delayFrame:SetScript("OnUpdate", function()
    if TryRequestSync() then
        delayFrame:SetScript("OnUpdate", nil)
    end
end)

---------------------------------------------------------------------
--                      Synchronization Inbound
---------------------------------------------------------------------

local function HandleInboundSync(msg, author)
        --DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] Message Received "..msg, 0, 1, 0)
    if string.find(msg, "^START_SR_DATA") then
        -- Note for myself so I dont forget, if the Sync stops working check this in the morning
        if LootBlare:IsSenderMasterLooter(author) and UnitName("player") == author then return end
        LootBlare.rollBonuses = {}
        DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] Full sync started by " .. author .. ", cleared all bonuses", 1, 1, 0)   
    elseif string.find(msg, "^SR_DATA ") then
        if LootBlare:IsSenderMasterLooter(author) and UnitName("player") == author then return end
        local dataPart = string.sub(msg, string.len("SR_DATA ") + 1)

        -- Split by ;
        local pos = 1
        while true do
            local sepStart, sepEnd = string.find(dataPart, ";", pos)
            local entry
            if sepStart then
                entry = string.sub(dataPart, pos, sepStart - 1)
                pos = sepEnd + 1
            else
                entry = string.sub(dataPart, pos)
                pos = nil
            end

            -- Parse entry: player:itemID:bonus
            local _, _, player, itemID, bonus = string.find(entry, "^([^:]+):([^:]+):([^:]+)$")
            if player and itemID and bonus then
                LootBlare.rollBonuses[player] = LootBlare.rollBonuses[player] or {}
                LootBlare.rollBonuses[player][itemID] = tonumber(bonus)
                --DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] Synced: " .. player .. " | ItemID: " .. itemID .. " | Bonus: " .. bonus, 0, 1, 0)
            end

            if not pos then break end
        end
    elseif string.find(msg, "^END_SR_DATA") then
        if LootBlare:IsSenderMasterLooter(author) and UnitName("player") == author then return end
        --DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] Sync finished from " .. author, 0, 1, 0)
    elseif string.find(msg, "^START_MS_DATA") then
        if LootBlare:IsSenderMasterLooter(author) and UnitName("player") == author then return end
        LootBlare.msplus = {}    
    elseif string.find(msg, "^MS_DATA ") then
        if LootBlare:IsSenderMasterLooter(author) and UnitName("player") == author then return end
        local dataPart = string.sub(msg, string.len("MS_DATA ") + 1)
        -- Split by ;
        local pos = 1
        while true do
            local sepStart, sepEnd = string.find(dataPart, ";", pos)
            local entry
            if sepStart then
                entry = string.sub(dataPart, pos, sepStart - 1)
                pos = sepEnd + 1
            else
                entry = string.sub(dataPart, pos)
                pos = nil
            end

            -- Parse entry: player:itemID:bonus
            local _, _, player, bonus = string.find(entry, "^([^:]+):([^:]+)$")
            if player and bonus then
                 -- Find existing entry and update points, or insert new
                local found = false
                for _, member in ipairs(LootBlare.msplus) do
                    if member.name == player then
                        member.points = points
                        found = true
                        break
                    end
                end
                if not found then
                    table.insert(LootBlare.msplus, { name = player, points = points })
                end
                DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] Synced: " .. player .. " | ItemID: " .. itemID .. " | Bonus: " .. bonus, 0, 1, 0)
            end

            if not pos then break end
        end
    elseif string.find(msg, "^END_MS_DATA") then
        if LootBlare:IsSenderMasterLooter(author) and UnitName("player") == author then return end
        UpdateMSPlusTable()
        --DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] Sync finished from " .. author, 0, 1, 0)
    elseif string.find(msg, "^REQ_SYNC") then
        LootBlare.SyncRaid()
    elseif string.find(msg, "^ML") then
        LootBlare.masterLooter = string.sub(msg, string.len("ML ") + 1)

    else
        -- Unknown sync message
        DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] Unknown sync message: " .. msg, 1, 1, 0)
    end
end

-- Add this function to update the master looter and detect "returning" players
local function DetectReturns()
    if LootBlare:IsSenderMasterLooter(UnitName("player")) == false then return end
    --DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] ML detecting Returns.")
    local currentRaidMembers = {}
    for i = 1, GetNumRaidMembers() do
        local name, _, _, _, _, _, _, online = GetRaidRosterInfo(i)
        if name and online then
            currentRaidMembers[name] = true
            -- Detect if player was not present before
            if not previousRaidMembers[name] and name ~= UnitName("player") then
                --DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] Detected returning player: " .. name, 0, 1, 0)
                LootBlare:SyncRaid()
            end
        end
    end

    -- Update previousRaidMembers for next check
    previousRaidMembers = currentRaidMembers
end


-- Frame to handle RAID_ROSTER_UPDATE and CHAT_MSG_WHISPER
local frame = CreateFrame("Frame")
frame:RegisterEvent("RAID_ROSTER_UPDATE")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" then
        delayFrame:Show()
    elseif event == "RAID_ROSTER_UPDATE" then
        DetectReturns()
        OnRaidUpdate()
        if LootBlare:IsSenderMasterLooter(UnitName("player")) == true then UpdateMSPlusTable() end 
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, msg, channel, sender = arg1, arg2, arg3, arg4
        if prefix == PREFIX then
            HandleInboundSync(msg, sender)
        end
    end
end)
