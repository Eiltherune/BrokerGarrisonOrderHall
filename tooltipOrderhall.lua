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


local function TooltipOrderhall(tooltip, ExpandButton_OnMouseUp)

    local name, row, realmName, realmData, playerName, playerData, talentID, talentData
    local realmNum = 0
    local now = time()
    local dataCount = 0
    local tooltipType = Garrison.TYPE_ORDERHALL

    local sortOptions, groupBy = Garrison.getSortOptions(Garrison.TYPE_ORDERHALL, "name")

    for realmName, realmData in pairsByKeys(globalDb.data) do
        realmNum = realmNum + 1

        local playerCount = 0

        -- Preview building/player count
        local orderhallCountTable = {}

        for playerName, playerData in pairsByKeys(realmData) do
            orderhallCountTable[playerName] = Garrison:GetOrderhallCount(playerData.info)

            --debugPrint(("%s => %s"):format(playerName, orderhallCountTable[playerName].talent.tiersAvailable))

            if orderhallCountTable[playerName].talent.tiersAvailable > 0 and (playerData.tooltipEnabled == nil or playerData.tooltipEnabled and
                    (orderhallCountTable[playerName].talent.total > 0 or orderhallCountTable[playerName].category.total > 0)) then
                playerCount = playerCount + 1
            end
        end

        --debugPrint(playerCount)

        if playerCount > 0 and not (configDb.general.orderhall.showOnlyCurrentRealm and realmName ~= charInfo.realmName) then

            dataCount = dataCount + 1
            if realmNum > 1 then
                AddEmptyRow(tooltip, tooltipType)
            end

            row = tooltip:AddHeader()
            tooltip:SetCell(row, 1, ("%s"):format(getColoredString(("%s"):format(realmName), colors.lightGray)), nil, "LEFT", 6)

            AddEmptyRow(tooltip, tooltipType)
            AddSeparator(tooltip)

            local sortedPlayerTable = Garrison.sort(realmData, "order,a", "info.playerName,a")
            for playerName, playerData in sortedPlayerTable do

                local orderhallCount = orderhallCountTable[playerName]

                if orderhallCount.talent.tiersAvailable > 0 and (playerData.tooltipEnabled == nil or playerData.tooltipEnabled and (orderhallCount.talent.total > 0 or orderhallCount.category.total > 0)) then

                    AddEmptyRow(tooltip, tooltipType)
                    row = AddRow(tooltip)

                    tooltip:SetCell(row, 1, playerData.orderhallExpanded and Garrison.ICON_CLOSE or Garrison.ICON_OPEN, nil, "LEFT", 1, nil, 0, 0, 20, 20)
                    tooltip:SetCell(row, 2, ("%s %s %s"):format(getColoredUnitName(playerData.info.playerName, playerData.info.playerClass, realmName), "", ""), nil, "LEFT", 4)

                    tooltip:SetCellScript(row, 1, "OnMouseUp", ExpandButton_OnMouseUp, { ("%s:%s"):format(realmName, playerName), Garrison.TYPE_ORDERHALL })
                    tooltip:SetCellScript(row, 2, "OnMouseUp", ExpandButton_OnMouseUp, { ("%s:%s"):format(realmName, playerName), Garrison.TYPE_ORDERHALL })

                    AddEmptyRow(tooltip, tooltipType)
                    AddSeparator(tooltip)

                    local followerShipmentsTable = Garrison:SortFollowerShipments(playerData.followerShipments)
                    local looseShipmentsTable = Garrison:SortFollowerShipments(playerData.looseShipments)

                    if playerData.orderhallExpanded and ((playerData.categories and #playerData.categories > 0) or (playerData.talents and #playerData.talents > 0)) then

                        AddEmptyRow(tooltip, tooltipType, colors.darkGray)

                        -- Categories
                        for categoryId, categoryData in pairs(playerData.categories) do
                            row = AddRow(tooltip, colors.darkGray)
                            if configDb.display.showIcon then
                                tooltip:SetCell(row, 1, getIconString(categoryData.icon, configDb.display.iconSize, false), nil, "LEFT", 1)
                            end
                            tooltip:SetCell(row, 2, categoryData.name, nil, "LEFT", 1)

                            local formattedCategory = ("%s/%s"):format(categoryData.count,
                                getColoredString(categoryData.limit, categoryData.limit == 0 and colors.white or colors.green))

                            tooltip:SetCell(row, 3, formattedCategory, nil, "LEFT", 1)

                            -- Find follower Shipment
                            if (followerShipmentsTable[categoryData.name]) then
                                Garrison:DoTooltipShipment(tooltip, row, followerShipmentsTable[categoryData.name], playerData.info)
                            end

                            AddEmptyRow(tooltip, tooltipType)
                            AddSeparator(tooltip)
                            AddEmptyRow(tooltip, tooltipType)
                        end

                        for _, looseShipment in pairs(looseShipmentsTable) do
                            row = AddRow(tooltip, colors.darkGray)
                            if configDb.display.showIcon then
                                tooltip:SetCell(row, 1, getIconString(looseShipment.texture, configDb.display.iconSize, false), nil, "LEFT", 1)
                            end
                            tooltip:SetCell(row, 2, looseShipment.name, nil, "LEFT", 1)

                            Garrison:DoTooltipShipment(tooltip, row, looseShipment, playerData.info)

                            AddEmptyRow(tooltip, tooltipType)
                        end

                        -- Talents
                        if configDb.general.orderhall.hideAllTalents then else
                            local sortedTalentTable = Garrison.sort(playerData.talents, "tier,a", "uiOrder,a")
                            local lastGroupValue = nil
                            local lastTier = -1

                            for talentId, talentData in sortedTalentTable do
                                if configDb.general.orderhall.hideInactiveTalents and not Garrison.CheckOrderTalentAvailability(talentData.talentAvailability, 0)
                                then
                                    --debugPrint("Hide Unavailable Talent: ".. talentData.name)
                                else

                                    local addSeparator = false
                                    if (lastTier ~= talentData.tier) then
                                        lastTier = talentData.tier
                                        --AddEmptyRow(tooltip)
                                        AddSeparator(tooltip)
                                        row = AddRow(tooltip, colors.darkGray)
                                        addSeparator = true
                                    end

                                    local offset = (talentData.uiOrder * 3)

                                    if configDb.display.showIcon then
                                        tooltip:SetCell(row, offset + 1, getIconString(talentData.icon, configDb.display.iconSize, false), nil, "LEFT", 1)
                                    end
                                    tooltip:SetCell(row, offset + 2, talentData.name, nil, "LEFT", 1)

                                    local timeLeftTalent = talentData.researchDuration - (now - talentData.researchStartTime)

                                    if (talentData.researched) then
                                        tooltip:SetCell(row, offset + 3, getColoredString(L["Active"], colors.green), nil, "RIGHT", 1)
                                    elseif (talentData.isBeingResearched) then
                                        if (timeLeftTalent < 0) then
                                            tooltip:SetCell(row, offset + 3, getColoredString(L["Complete"], colors.green), nil, "RIGHT", 1)
                                        else
                                            local formattedTime = ("%s %s"):format(formattedSeconds(timeLeftTalent),
                                                getColoredString("(" .. formattedSeconds(talentData.researchDuration) .. ")", colors.lightGray))
                                            tooltip:SetCell(row, offset + 3, formattedTime, nil, "RIGHT", 1)
                                        end
                                    else
                                        if Garrison.CheckOrderTalentAvailability(talentData.talentAvailability, 0) then
                                            tooltip:SetCell(row, offset + 3, getColoredString(L["Inactive"], colors.red), nil, "RIGHT", 1)
                                        else
                                            tooltip:SetCell(row, offset + 3, getColoredString(L["Unavailable"], colors.red), nil, "RIGHT", 1)
                                        end
                                    end

                                    if (addSeparator) then
                                        AddSeparator(tooltip)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    if dataCount == 0 then
        row = AddRow(tooltip, colors.darkGray)
        tooltip:SetCell(row, 1, getColoredString(L["OrderHalls not available"], colors.lightGray), nil, "LEFT", 6)
    end
    AddEmptyRow(tooltip, tooltipType)
end


function Garrison:SortFollowerShipments(shipmentList)
    local followerShipmentTable = {}

    if shipmentList then
        for _, shipmentData in pairs(shipmentList) do
            followerShipmentTable[shipmentData.name] = shipmentData
        end
    end

    return followerShipmentTable
end

function Garrison:DoTooltipShipment(tooltip, row, shipmentData, playerInfo)
    if shipmentData then

        local shipmentsReady, shipmentsInProgress, shipmentsAvailable, timeLeftNext, timeLeftTotal = Garrison:DoShipmentMagic(shipmentData, playerInfo)

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
    end
end

function Garrison:InitTooltipOrderhall()
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
    Garrison.tooltipFunctions[Garrison.TYPE_ORDERHALL] = TooltipOrderhall
end
