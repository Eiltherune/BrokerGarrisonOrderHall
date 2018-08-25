local ADDON_NAME, private = ...

local Garrison = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local L = LibStub:GetLibrary("AceLocale-3.0"):GetLocale(ADDON_NAME)

local debugPrint, charInfo, timers = Garrison.debugPrint, Garrison.charInfo, Garrison.timers
local garrisonDb, globalDb, configDb, colors
local AddEmptyRow, AddSeparator, AddRow = Garrison.AddEmptyRow, Garrison.AddSeparator, Garrison.AddRow
local textPlaceholder
local getColoredString, getColoredUnitName, formattedSeconds, getIconString
local pairsByKeys, formatRealmPlayer, tableSize

local _G = getfenv(0)


local function TooltipMission(tooltip, ExpandButton_OnMouseUp)

    local name, row, realmName, realmData, playerName, playerData, missionID, missionData
    local realmNum = 0
    local now = time()
    local tooltipType = Garrison.TYPE_MISSION

    local sortOptions, groupBy = Garrison.getSortOptions(Garrison.TYPE_MISSION, "name")

    for realmName, realmData in pairsByKeys(globalDb.data) do
        realmNum = realmNum + 1

        -- Preview building/player count
        local playerCount = 0
        local missionCountTable = {}

        for playerName, playerData in pairsByKeys(realmData) do
            missionCountTable[playerName] = Garrison:GetMissionCount(playerData.info)

            if (playerData.tooltipEnabled == nil or playerData.tooltipEnabled) and (missionCountTable[playerName].total > 0 or (not configDb.general.mission.hideCharactersWithoutMissions)) then
                playerCount = playerCount + 1
            end
        end

        if playerCount > 0 and not (configDb.general.mission.showOnlyCurrentRealm and realmName ~= charInfo.realmName) then

            row = tooltip:AddHeader()
            tooltip:SetCell(row, 1, ("%s"):format(getColoredString(("%s"):format(realmName), colors.lightGray)), nil, "LEFT", 3)

            AddEmptyRow(tooltip, tooltipType)
            AddSeparator(tooltip)

            local sortedPlayerTable = Garrison.sort(realmData, "order,a", "info.playerName,a")
            for playerName, playerData in sortedPlayerTable do
                --local missionCount = Garrison:GetMissionCount(playerData.info)
                local missionCount = missionCountTable[playerName]

                if playerData.tooltipEnabled == nil or playerData.tooltipEnabled
                        and (missionCount.total > 0 or (not configDb.general.mission.hideCharactersWithoutMissions)) then

                    AddEmptyRow(tooltip, tooltipType)
                    row = AddRow(tooltip)

                    tooltip:SetCell(row, 1, playerData.missionsExpanded and Garrison.ICON_CLOSE or Garrison.ICON_OPEN)
                    tooltip:SetCell(row, 2, ("%s"):format(getColoredUnitName(playerData.info.playerName, playerData.info.playerClass, realmName)))
                    --tooltip:SetCell(row, 3, ("%s %s %s %s"):format(Garrison.ICON_CURRENCY, BreakUpLargeNumbers(playerData.currencyAmount or 0), Garrison.ICON_CURRENCY_APEXIS, BreakUpLargeNumbers(playerData.currencyApexisAmount or 0)))


                    local textInProgress, textComplete, textTotal -- = L["In Progress: %s"], L["Complete: %s"], L["Total: %s"]
                    local colorInProgress, colorComplete

                    colorComplete = (missionCount.complete > 0) and colors.green or colors.white

                    if missionCount.inProgress > 3 then
                        colorInProgress = colors.white
                    elseif missionCount.inProgress >= 1 then
                        colorInProgress = colors.yellow
                    else
                        colorInProgress = colors.red
                    end

                    colorComplete = (missionCount.complete > 0) and colors.green or colors.white

                    textInProgress = (getColoredString(L["In Progress: %s"], colors.lightGray)):format(getColoredString(missionCount.inProgress, colorInProgress))
                    textComplete = (getColoredString(L["Complete: %s"], colors.lightGray)):format(getColoredString(missionCount.complete, colorComplete))
                    textTotal = (getColoredString(L["Total: %s"], colors.lightGray)):format(missionCount.total)


                    tooltip:SetCell(row, 3, ("%s%s%s%s%s"):format(textInProgress, textPlaceholder, textComplete, textPlaceholder, textTotal), nil, "RIGHT", 2)

                    tooltip:SetCellScript(row, 1, "OnMouseUp", ExpandButton_OnMouseUp, { ("%s:%s"):format(realmName, playerName), Garrison.TYPE_MISSION })
                    tooltip:SetCellScript(row, 2, "OnMouseUp", ExpandButton_OnMouseUp, { ("%s:%s"):format(realmName, playerName), Garrison.TYPE_MISSION })

                    AddEmptyRow(tooltip, tooltipType)
                    AddSeparator(tooltip)

                    if playerData.missionsExpanded and missionCount.total > 0 then

                        AddEmptyRow(tooltip, tooltipType, colors.darkGray)

                        if not configDb.general.mission.hideHeader then
                            --row = AddRow(tooltip, colors.darkGray)
                            --tooltip:SetCell(row, 4, getColoredString(L["SHIPYARD"], colors.lightGray), nil, "CENTER", 1)
                            --AddEmptyRow(tooltip, colors.darkGray)
                        end

                        --debugPrint(groupBy)
                        local sortedMissionTable = Garrison.sort(playerData.missions, unpack(sortOptions))
                        local lastGroupValue = nil

                        for missionID, missionData in sortedMissionTable do
                            if (
                                ( missionData.followerTypeID == 1 and configDb.general.mission.showWoD ) or
                                ( missionData.followerTypeID == 2 and configDb.general.mission.showShip ) or
                                ( missionData.followerTypeID == 4 and configDb.general.mission.showLegion ) or
                                ( missionData.followerTypeID == 22 and configDb.general.mission.showBfA ) ) then
                    
                            
                                if groupBy and #groupBy > 0 then
                                    local groupByValue = Garrison.getTableValue(missionData, unpack(groupBy))
                                    if lastGroupValue == nil then
                                        lastGroupValue = groupByValue
                                    else
                                        if lastGroupValue == groupByValue then
                                            -- OK
                                        else
                                            AddEmptyRow(tooltip, tooltipType, colors.darkGray)
                                            AddSeparator(tooltip)
                                            AddEmptyRow(tooltip, tooltipType, colors.darkGray)

                                            lastGroupValue = groupByValue

                                            if not configDb.general.mission.hideHeader then
                                                --row = AddRow(tooltip, colors.darkGray)
                                                --tooltip:SetCell(row, 4, getColoredString(L["SHIPYARD"], colors.lightGray), nil, "CENTER", 1)
                                                --AddEmptyRow(tooltip, colors.darkGray)
                                            end
                                        end
                                    end
                                end


                                --debugPrint(("%s: %s => %s"):format(missionData.name, groupByValue or '-', _G.tostring(isGrouped)))

                                local timeLeft = missionData.duration - (now - missionData.start)

                                row = AddRow(tooltip, colors.darkGray)

                                if configDb.display.showIcon then
                                    tooltip:SetCell(row, 1, getIconString(missionData.typeAtlas, configDb.display.iconSize, true), nil, "LEFT", 1)
                                end

                                local rewardString = ""

                                if configDb.general.mission.showRewards and missionData.rewards ~= nil then
                                    local showReward
                                    for rewardId, rewardData in pairs(missionData.rewards) do
                                        showReward = true

                                        if rewardData.followerXP and not configDb.general.mission.showRewardsXP then
                                            showReward = false
                                        end

                                        if showReward then
                                            if rewardData.icon or rewardData.itemID then
                                                rewardString = rewardString .. " " .. getIconString(rewardData.icon or rewardData.itemID, configDb.display.iconSize, false, false)
                                            end

                                            if configDb.general.mission.showRewardsAmount then
                                                local rewardAmount = rewardData.quantity or rewardData.followerXP

                                                if rewardAmount ~= nil and rewardAmount > 1 then
                                                    if rewardData.currencyID == 0 then -- money
                                                    rewardAmount = math.floor(rewardAmount / 10000)
                                                    end

                                                    rewardString = rewardString .. " " .. getColoredString(("(%s)"):format(rewardAmount), colors.lightGray)
                                                end
                                            end
                                        end
                                    end
                                end

                                tooltip:SetCell(row, 2, missionData.name .. rewardString, nil, "LEFT", 2)

                                if (missionData.start == -1) then
                                    local parsedTime = Garrison:GetParsedStartTime(missionData.timeLeft, missionData.duration)

                                    local formattedTime = ("~%s %s"):format(parsedTime or "~" .. missionData.timeLeft,
                                        getColoredString("(" .. formattedSeconds(missionData.duration) .. ")", colors.lightGray))
                                    tooltip:SetCell(row, 4, formattedTime, nil, "RIGHT", 1)
                                elseif (missionData.start == 0 or timeLeft < 0) then
                                    tooltip:SetCell(row, 4, getColoredString(L["Complete!"], colors.green), nil, "RIGHT", 1)
                                else
                                    local formattedTime = ("%s %s"):format(formattedSeconds(timeLeft),
                                        getColoredString("(" .. formattedSeconds(missionData.duration) .. ")", colors.lightGray))

                                    tooltip:SetCell(row, 4, formattedTime, nil, "RIGHT", 1)
                                end

                                if configDb.general.mission.showFollowers and missionData.followers and #missionData.followers > 0 then
                                    row = AddRow(tooltip, colors.darkGray)
                                    local followerString = ""
                                    for followerNum = 1, #missionData.followers do
                                        local followerData = missionData.followers[followerNum]

                                        followerString = followerString .. ("%s %s  "):format(Garrison.GetTextureForID(followerData.iconId, configDb.display.iconSize - 4), followerData.name)
                                    end

                                    tooltip:SetCell(row, 2, getColoredString(followerString, colors.lightGray), nil, "LEFT", 3)
                                end
                            end
                        end

                        AddEmptyRow(tooltip, tooltipType, colors.darkGray)

                        AddSeparator(tooltip)
                    end
                else
                    debugPrint("Hide " .. playerData.info.playerName)
                end
            end
        else
            debugPrint(("[%s]: No players for realm - hiding"):format(realmName))
        end
        AddEmptyRow(tooltip, tooltipType)
    end
end

local function TooltipBuilding(tooltip, ExpandButton_OnMouseUp)

    local name, row, realmName, realmData, playerName, playerData, missionID, missionData
    local realmNum = 0
    local now = time()

    local tooltipType = Garrison.TYPE_BUILDING

    local sortOptions, groupBy = Garrison.getSortOptions(Garrison.TYPE_BUILDING, "name")

    for realmName, realmData in pairsByKeys(globalDb.data) do
        realmNum = realmNum + 1

        local playerCount = 0

        -- Preview building/player count
        local buildingCountTable = {}

        for playerName, playerData in pairsByKeys(realmData) do
            buildingCountTable[playerName] = Garrison:GetBuildingCount(playerData.info)

            if playerData.tooltipEnabled == nil or playerData.tooltipEnabled and (buildingCountTable[playerName].building.total > 0) then
                playerCount = playerCount + 1
            end
        end

        if playerCount > 0 and not (configDb.general.building.showOnlyCurrentRealm and realmName ~= charInfo.realmName) then

            if realmNum > 1 then
                AddEmptyRow(tooltip, tooltipType)
            end

            row = tooltip:AddHeader()
            tooltip:SetCell(row, 1, ("%s"):format(getColoredString(("%s"):format(realmName), colors.lightGray)), nil, "LEFT", 4)

            AddEmptyRow(tooltip, tooltipType)
            AddSeparator(tooltip)

            local sortedPlayerTable = Garrison.sort(realmData, "order,a", "info.playerName,a")
            for playerName, playerData in sortedPlayerTable do

                --local buildingCount = Garrison:GetBuildingCount(playerData.info)
                local buildingCount = buildingCountTable[playerName]

                local estimatedCacheResourceAmount = ""
                local cacheWarning = false
                local cacheSize = playerData.cacheSize or 500
                local tmpResources = Garrison.getResourceFromTimestamp(cacheSize, playerData.garrisonCacheLastLooted, now)
                if tmpResources ~= nil and tmpResources >= 5 then
                    local resourceColor = colors.lightGray
                    if tmpResources >= (cacheSize * 0.8) then
                        resourceColor = colors.red
                        cacheWarning = true
                    end
                    estimatedCacheResourceAmount = getColoredString((" (%s)"):format(math.min(cacheSize, tmpResources)), resourceColor)
                end

                local availableBonusRollQuests = ""
                if playerData.info.bonusEnabled then
                    local tmpBonusRollQ = playerData.trackWeekly["BONUS_ROLL_QUESTS"]
                    local tmpAvailableBonusRollQ = Garrison.bonusRollMaxNumQuests

                    if tmpBonusRollQ ~= nil and tmpBonusRollQ > 0 then
                        tmpAvailableBonusRollQ = tmpAvailableBonusRollQ - tmpBonusRollQ
                    end

                    if tmpAvailableBonusRollQ > 0 then
                        availableBonusRollQuests = getColoredString((" (%s)"):format(tmpAvailableBonusRollQ), colors.lightGray)
                    end
                end


                if playerData.tooltipEnabled == nil or playerData.tooltipEnabled and (buildingCount.building.total > 0 or cacheWarning) then
                    playerCount = playerCount + 1

                    AddEmptyRow(tooltip, tooltipType)
                    row = AddRow(tooltip)

                    local invasionAvailable = ""

                    if playerData.invasion and playerData.invasion.available then
                        invasionAvailable = Garrison.ICON_INVASION
                    end

                    tooltip:SetCell(row, 1, playerData.buildingsExpanded and Garrison.ICON_CLOSE or Garrison.ICON_OPEN, nil, "LEFT", 1, nil, 0, 0, 20, 20)
                    tooltip:SetCell(row, 2, ("%s %s %s"):format(getColoredUnitName(playerData.info.playerName, playerData.info.playerClass, realmName), invasionAvailable, cacheWarning and Garrison.ICON_WARNING or ""), nil, "LEFT", 3)
                    tooltip:SetCell(row, 5, ("%s %s%s %s %s%s%s %s %s %s%s %s %s"):format(Garrison.ICON_CURRENCY_INEVITABLE_FATE_TOOLTIP, BreakUpLargeNumbers(playerData.currencySealOfInevitableFateAmount or 0), availableBonusRollQuests,
                        Garrison.ICON_CURRENCY_TEMPERED_FATE_TOOLTIP, BreakUpLargeNumbers(playerData.currencySealOfTemperedFateAmount or 0),
                        textPlaceholder,
                        Garrison.ICON_CURRENCY_OIL, BreakUpLargeNumbers(playerData.currencyOil or 0),
                        Garrison.ICON_CURRENCY_TOOLTIP, BreakUpLargeNumbers(playerData.currencyAmount or 0), estimatedCacheResourceAmount,
                        Garrison.ICON_CURRENCY_APEXIS_TOOLTIP, BreakUpLargeNumbers(playerData.currencyApexisAmount or 0)),
                        nil, "RIGHT", 1)

                    tooltip:SetCellScript(row, 1, "OnMouseUp", ExpandButton_OnMouseUp, { ("%s:%s"):format(realmName, playerName), Garrison.TYPE_BUILDING })
                    --tooltip:SetCellScript(row, 1, "OnMouseDown", ExpandButton_OnMouseDown, {playerData.buildingsExpanded, Garrison.TYPE_BUILDING})
                    tooltip:SetCellScript(row, 2, "OnMouseUp", ExpandButton_OnMouseUp, { ("%s:%s"):format(realmName, playerName), Garrison.TYPE_BUILDING })
                    --tooltip:SetCellScript(row, 2, "OnMouseDown", ExpandButton_OnMouseDown, {playerData.buildingsExpanded, Garrison.TYPE_BUILDING})

                    AddEmptyRow(tooltip, tooltipType)
                    AddSeparator(tooltip)

                    if not (playerData.buildingsExpanded) then

                        local buildingInfoIcon = Garrison:GetLootInfoForPlayer(playerData)

                        local playerBuildingUpgrade = ("%s %s %s %s"):format(getColoredUnitName(playerData.info.playerName, playerData.info.playerClass, realmName), invasionAvailable, cacheWarning and Garrison.ICON_WARNING or "", buildingInfoIcon)

                        local formattedShipment = ""

                        if (buildingCount.building.complete > 0 or buildingCount.building.building > 0) then
                            local isBuildingIcon = ""
                            local displayCount = 0
                            if buildingCount.building.complete > 0 then
                                isBuildingIcon = Garrison.ICON_ARROW_UP
                                displayCount = "(" .. buildingCount.building.complete .. ")"
                            else
                                isBuildingIcon = Garrison.ICON_ARROW_UP_WAITING
                                displayCount = "(" .. buildingCount.building.building .. ")"
                            end

                            --formattedShipment = formattedShipment..isBuildingIcon
                            --tooltip:SetCell(row, 3, ("%s %s"):format(isBuildingIcon, getColoredString(displayCount, colors.lightGray)), nil, "LEFT", 1)
                            playerBuildingUpgrade = playerBuildingUpgrade .. ("%s"):format(isBuildingIcon)
                        end

                        if (buildingCount.shipment.inProgress > 0 or buildingCount.shipment.ready > 0) then
                            formattedShipment = formattedShipment .. ("%s/%s"):format(buildingCount.shipment.inProgress,
                                getColoredString(buildingCount.shipment.ready, colors.green))
                        end

                        tooltip:SetCell(row, 2, playerBuildingUpgrade, nil, "LEFT", 2)
                        tooltip:SetCell(row, 4, formattedShipment, nil, "LEFT", 1)

                    elseif playerData.buildingsExpanded and buildingCount.building.total > 0 then
                        AddEmptyRow(tooltip, tooltipType, colors.darkGray)

                        if not configDb.general.building.hideHeader then
                            row = AddRow(tooltip, colors.darkGray)
                            tooltip:SetCell(row, 4, getColoredString(L["SHIPMENT"], colors.lightGray), nil, "CENTER", 1)
                            tooltip:SetCell(row, 5, getColoredString(L["TIME"], colors.lightGray), nil, "CENTER", 1)
                            AddEmptyRow(tooltip, tooltipType, colors.darkGray)
                        end

                        local sortedBuildingTable = Garrison.sort(playerData.buildings, unpack(sortOptions))
                        local lastGroupValue = nil
                        --local sortedBuildingTable = Garrison.sort(playerData.buildings, "name,a")

                        for plotID, buildingData in sortedBuildingTable do

                            local timeLeftBuilding = 0
                            if buildingData.isBuilding then
                                timeLeftBuilding = buildingData.buildTime - (now - buildingData.timeStart)
                            end

                            local rank, buildingInfoIcon = "", ""
                            if buildingData.isBuilding or buildingData.canActivate then

                                if (buildingData.isBuilding and timeLeftBuilding > 0) then
                                    buildingInfoIcon = Garrison.ICON_ARROW_UP_WAITING
                                else
                                    buildingInfoIcon = Garrison.ICON_ARROW_UP
                                end

                                --debugPrint(("[%s] isBuilding: %s, timeLeftBuilding: %s"):format(buildingData.name, _G.tostring(buildingData.isBuilding), _G.tostring(timeLeftBuilding)))

                                if buildingData.rank > 1 then
                                    rank = getColoredString("(" .. (buildingData.rank - 1) .. ")", colors.lightGray)
                                else
                                    rank = ""
                                end
                            else
                                rank = getColoredString("(" .. buildingData.rank .. ")", colors.lightGray)
                            end

                            buildingInfoIcon = buildingInfoIcon .. Garrison:GetLootInfoForBuilding(playerData, buildingData)

                            if not configDb.general.building.hideBuildingWithoutShipments or
                                    (buildingInfoIcon ~= "") or
                                    (buildingData.isBuilding or buildingData.canActivate) or
                                    (buildingData.shipment and buildingData.shipment.shipmentCapacity ~= nil and buildingData.shipment.shipmentCapacity > 0) then

                                if groupBy and #groupBy > 0 then
                                    local groupByValue = Garrison.getTableValue(buildingData, unpack(groupBy))


                                    if lastGroupValue == nil then
                                        lastGroupValue = groupByValue
                                    else
                                        if lastGroupValue == groupByValue then
                                            -- OK
                                        else
                                            AddEmptyRow(tooltip, tooltipType, colors.darkGray)
                                            AddSeparator(tooltip)
                                            AddEmptyRow(tooltip, tooltipType, colors.darkGray)

                                            if not configDb.general.building.hideHeader then
                                                row = AddRow(tooltip, colors.darkGray)
                                                tooltip:SetCell(row, 4, getColoredString(L["SHIPMENT"], colors.lightGray), nil, "CENTER", 1)
                                                tooltip:SetCell(row, 5, getColoredString(L["TIME"], colors.lightGray), nil, "CENTER", 1)
                                                AddEmptyRow(tooltip, tooltipType, colors.darkGray)
                                            end

                                            lastGroupValue = groupByValue
                                        end
                                    end

                                    --debugPrint("groupBy: "..tostring(unpack(groupBy)))
                                    --debugPrint(("%s: %s => %s"):format(buildingData.name, groupByValue or '-', tostring(isGrouped)))
                                end


                                -- Display building and Workorder data
                                row = AddRow(tooltip, colors.darkGray)


                                if configDb.display.showIcon then
                                    --tooltip:SetCell(row, 1, getIconString(, configDb.display.iconSize, false, false), nil, "LEFT", 1)

                                    tooltip:SetCell(row, 2, "", nil, "LEFT", 1, Garrison.iconProvider, 0, 0, nil, nil, Garrison.GetIconPath(buildingData.icon), configDb.display.iconSize)
                                end

                                tooltip:SetCell(row, 3, ("%s %s %s"):format(buildingData.name, rank, buildingInfoIcon), nil, "LEFT", 1)

                                --tooltip:SetCell(row, 3, isBuildingIcon, nil, "LEFT", 1)


                                if buildingData.hasFollowerSlot then
                                    local followerTexture, iconSize
                                    if buildingData.follower and buildingData.follower.followerName then
                                        followerTexture = buildingData.follower.portraitIconID
                                        iconSize = configDb.display.iconSize - 2
                                    else
                                        followerTexture = Garrison.ICON_PATH_FOLLOWER_NO_PORTRAIT
                                        iconSize = configDb.display.iconSize
                                    end

                                    tooltip:SetCell(row, 1, "", nil, "LEFT", 1, Garrison.iconProvider, 0, 0, nil, nil, followerTexture, iconSize)
                                end

                                if ((buildingData.isBuilding and timeLeftBuilding <= 0) or buildingData.canActivate) then
                                    tooltip:SetCell(row, 5, getColoredString(L["Can be activated"], colors.green), nil, "LEFT", 1)
                                elseif buildingData.isBuilding then

                                    local formattedTime = ("%s %s"):format(formattedSeconds(timeLeftBuilding),
                                        getColoredString("(" .. formattedSeconds(buildingData.buildTime) .. ")", colors.lightGray))

                                    tooltip:SetCell(row, 5, formattedTime, nil, "LEFT", 1)

                                elseif buildingData.shipment and buildingData.shipment.name and (buildingData.shipment.shipmentCapacity ~= nil and buildingData.shipment.shipmentCapacity > 0) then
                                    local shipmentData = buildingData.shipment

                                    local shipmentsReady, shipmentsInProgress, shipmentsAvailable, timeLeftNext, timeLeftTotal = Garrison:DoShipmentMagic(shipmentData, playerData.info)

                                    if shipmentData.shipmentCapacity then
                                        if shipmentsInProgress <= math.ceil(shipmentData.shipmentCapacity * 0.15) then
                                            shipmentsInProgress = getColoredString(shipmentsInProgress, colors.red)
                                        elseif shipmentsInProgress <= math.ceil(shipmentData.shipmentCapacity * 0.3) then
                                            shipmentsInProgress = getColoredString(shipmentsInProgress, colors.yellow)
                                        end
                                    end

                                    local formattedShipment = ("%s/%s %s"):format(shipmentsInProgress,
                                        getColoredString(shipmentsReady, shipmentsReady == 0 and colors.white or colors.green),
                                        getColoredString("(" .. shipmentsAvailable .. ")", colors.lightGray))


                                    tooltip:SetCell(row, 4, formattedShipment, nil, "LEFT", 1)

                                    if timeLeftNext > 0 and timeLeftTotal > 0 then
                                        local formattedTime = ("%s %s"):format(formattedSeconds(timeLeftNext),
                                            getColoredString("(" .. formattedSeconds(timeLeftTotal) .. ")", colors.lightGray))

                                        tooltip:SetCell(row, 5, formattedTime, nil, "LEFT", 1)
                                    end


                                else
                                    tooltip:SetCell(row, 4, "-", nil, "LEFT", 1)
                                end
                            end
                        end

                        AddEmptyRow(tooltip, tooltipType, colors.darkGray)
                        AddSeparator(tooltip)
                    end
                else
                    debugPrint("Hide " .. playerData.info.playerName)
                end
            end
        else --playerCount <= 0
        debugPrint(("[%s]: No players for realm - hiding"):format(realmName))
        end
    end
    AddEmptyRow(tooltip, tooltipType)
end

function Garrison:InitTooltipLegacy()
    garrisonDb = self.DB
    configDb = garrisonDb.profile
    globalDb = garrisonDb.global
    colors = Garrison.colors

    getColoredString, getColoredUnitName, formattedSeconds, getIconString = Garrison.getColoredString, Garrison.getColoredUnitName, Garrison.formattedSeconds, Garrison.getIconString
    pairsByKeys, formatRealmPlayer, tableSize = Garrison.pairsByKeys, Garrison.formatRealmPlayer, Garrison.tableSize
    textPlaceholder = getColoredString(" | ", colors.lightGray)

    if not Garrison.tooltipFunctions then
        Garrison.tooltipFunctions = {}
    end
    Garrison.tooltipFunctions[Garrison.TYPE_MISSION] = TooltipMission
    Garrison.tooltipFunctions[Garrison.TYPE_BUILDING] = TooltipBuilding
end
