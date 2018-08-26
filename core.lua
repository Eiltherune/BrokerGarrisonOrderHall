local ADDON_NAME, _ = ...
local _G = getfenv(0)

local LibStub = _G.LibStub

local BrokerGarrison = LibStub('AceAddon-3.0'):NewAddon(ADDON_NAME, 'AceConsole-3.0', "AceHook-3.0", 'AceEvent-3.0', 'AceTimer-3.0', "LibSink-2.0")
local Garrison = BrokerGarrison

_G["BrokerGarrison"] = {}

Garrison.versionString = GetAddOnMetadata(ADDON_NAME, "Version");
Garrison.cleanName = "Broker Garrison"

Garrison.detachframe = {}

local ldb = LibStub:GetLibrary("LibDataBroker-1.1")
local LDBIcon = ldb and LibStub("LibDBIcon-1.0")
local L = LibStub:GetLibrary("AceLocale-3.0"):GetLocale(ADDON_NAME)
local LibQTip = LibStub('LibQTip-1.0')
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local Toast, ToastVersion = LibStub("LibToast-1.0")
local LSM = LibStub:GetLibrary("LibSharedMedia-3.0")

-- LUA
local math, string, table, print, pairs, ipairs, unpack = _G.math, _G.string, _G.table, _G.print, _G.pairs, _G.ipairs, _G.unpack
local tonumber, strupper, select, time = _G.tonumber, _G.strupper, _G.select, _G.time
-- Blizzard
local BreakUpLargeNumbers, C_Garrison, GetCurrencyInfo = _G.BreakUpLargeNumbers, _G.C_Garrison, _G.GetCurrencyInfo
-- UI Elements
local InterfaceOptionsFrameAddOns, UIParentLoadAddOn, GarrisonLandingPage = _G.InterfaceOptionsFrameAddOns, _G.UIParentLoadAddOn, _G.GarrisonLandingPage
local GarrisonMissionFrame, GarrisonLandingPageMinimapButton = _G.GarrisonMissionFrame, _G.GarrisonLandingPageMinimapButton
-- UI Functions
local ShowUIPanel, HideUIPanel, CreateFont, PlaySoundFile = _G.ShowUIPanel, _G.HideUIPanel, _G.CreateFont, _G.PlaySoundFile
-- UI Hooks
local OptionsListButtonToggle_OnClick = _G.OptionsListButtonToggle_OnClick

local garrisonDb, configDb, globalDb, DEFAULT_FONT, colors, tooltipFunctions

-- Constants
local TYPE_BUILDING = "building"
local TYPE_MISSION = "mission"
local TYPE_SHIPMENT = "shipment"
local TYPE_ORDERHALL = "orderhall"

Garrison.TYPE_BUILDING = TYPE_BUILDING
Garrison.TYPE_MISSION = TYPE_MISSION
Garrison.TYPE_SHIPMENT = TYPE_SHIPMENT
Garrison.TYPE_ORDERHALL = TYPE_ORDERHALL

local addonInitialized = false
local delayedInit = false
local dependencyLoaded = false
local CONFIG_VERSION = 3

local timers = {}
Garrison.timers = timers
local atlas = {}
Garrison.atlas = atlas
local iconCache = {}
Garrison.iconCache = iconCache

local patternCache = {}
Garrison.patternCache = patternCache

local notificationQueue = {}
Garrison.notificationQueue = notificationQueue
local notificationQueueEnabled = false

-- LE_FOLLOWER_TYPE_SHIPYARD_6_2
-- LE_FOLLOWER_TYPE_GARRISON_7_0
-- LE_FOLLOWER_TYPE_GARRISON_6_0

Garrison.data = {}

-- Garrison Functions
local debugPrint, pairsByKeys, formatRealmPlayer, tableSize, getColoredString, getColoredUnitName, formattedSeconds, getIconString


local TOAST_MISSION_COMPLETE = "BrokerGarrisonMissionComplete"
local TOAST_BUILDING_COMPLETE = "BrokerGarrisonBuildingComplete"
local TOAST_SHIPMENT_COMPLETE = "BrokerGarrisonShipmentComplete"
local TOAST_SUMMARY = "BrokerGarrisonSummary"

local DB_DEFAULTS = {
    profile = {
        general = {
            mission = {
                ldbTemplate = "M1",
                hideCharactersWithoutMissions = true,
                ldbLabelText = L["Garrison: Missions"],
                showOnlyCurrentRealm = false,
                collapseOtherCharsOnLogin = false,
                compactTooltip = false,
                showFollowers = false,
                showRewards = true,
                showRewardsAmount = false,
                showRewardsXP = false,
                showWoD = true,
                showShip = true,
                showLegion = true,
                showBfA = true,
            },
            building = {
                hideBuildingWithoutShipments = false,
                hideHeader = false,
                ldbTemplate = "B1",
                ldbLabelText = L["Garrison: Buildings"],
                showOnlyCurrentRealm = false,
                collapseOtherCharsOnLogin = false,
                compactTooltip = false,
            },
            orderhall = {
                hideHeader = false,
                showOnlyCurrentRealm = false,
                hideInactiveTalents = true,
                collapseOtherCharsOnLogin = false,
                compactTooltip = false,
                ldbLabelText = L["Order Hall"],
                ldbTemplate = "A3",
            },
            hideGarrisonMinimapButton = false,
            highAccuracy = true,
            showSeconds = true,
            updateInCombat = true,
        },
        tooltip = {
            building = {
                sort = {
                    [1] = {
                        value = "b.canActivate",
                        ascending = true,
                    },
                    [2] = {
                        value = "b.isBuilding",
                        ascending = false,
                    },
                    [3] = {
                        value = "b.shipmentsReady",
                        ascending = false,
                    },
                    [4] = {
                        value = "b.shipmentCapacity",
                        ascending = false,
                    },
                    [5] = {
                        value = "b.name",
                        ascending = true,
                    },
                    ['*'] = {
                        value = "-",
                        ascending = false,
                    },
                },
                group = {
                    [1] = {
                        value = "b.size",
                        ascending = true,
                    },
                },
            },
            mission = {
                sort = {
                    [1] = {
                        value = "m.timeLeft",
                        ascending = true,
                    },
                    [2] = {
                        value = "m.level",
                        ascending = false,
                    },
                    [3] = {
                        value = "m.name",
                        ascending = true,
                    },
                    ['*'] = {
                        value = "-",
                        ascending = false,
                    },
                },
                group = {
                    [1] = {
                        value = "m.followerType",
                        ascending = true,
                    },
                },
            },
            orderhall = {
                sort = {
                    [1] = {
                        value = "tier",
                        ascending = true,
                    },
                    [2] = {
                        value = "uiOrder",
                        ascending = false,
                    },
                }
            }
        },
        notification = {
            sink = {},
            general = {
                disableInParty = true,
                disableInRaid = true,
                disableInPvP = true,
            },
            mission = {
                enabled = true,
                repeatOnLoad = false,
                toastEnabled = true,
                toastPersistent = false,
                hideBlizzardNotification = true,
                hideMinimapPulse = false,
                compactToast = false,
                notificationQueueEnabled = true,
                WoD = true,
                Shipyard = true,
                Legion = true,
                BfA = true,
            },
            building = {
                enabled = true,
                repeatOnLoad = false,
                toastEnabled = true,
                toastPersistent = false,
                hideBlizzardNotification = true,
                hideMinimapPulse = false,
                compactToast = false,
                notificationQueueEnabled = true,
            },
            shipment = {
                enabled = true,
                repeatOnLoad = false,
                toastEnabled = true,
                toastPersistent = false,
                hideBlizzardNotification = true,
                hideMinimapPulse = false,
                compactToast = false,
                notificationQueueEnabled = true,
            },
        },
        display = {
            scale = 1,
            autoHideDelay = 0.25,
            iconSize = 16,
            fontSize = 12,
            showIcon = true,
            backgroundAlpha = 255,
        },
        minimap = {
            load = false,
            mission = {},
            building = {},
            orderhall = {},
        },
        debugPrint = false,
    },
    global = {
        data = {}
    }
}

-- Player info
local charInfo = {
    playerName = UnitName("player"),
    playerClass = select(2, UnitClass("player")),
    playerFaction = UnitFactionGroup("player"),
    realmName = GetRealmName(),
}
Garrison.charInfo = charInfo

local location = {
    garrisonMapName = ( C_Map.GetMapInfo(582).name and charInfo.playerFaction == "Alliance" ) or C_Map.GetMapInfo(590).name,
    zoneName = nil,
    inGarrison = nil,
    inOrderHall = nil,
}
Garrison.location = location
Garrison.legacyGarrisonEnabled = true

-- LDB init
local ldb_object_mission = LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject(ADDON_NAME .. "Mission",
    {
        type = "data source",
        label = L["Garrison: Missions"],
        icon = "Interface\\Icons\\Inv_Garrison_Resource",
        text = L["Garrison: Missions"],
    })

local ldb_object_building = LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject(ADDON_NAME .. "Building",
    {
        type = "data source",
        label = L["Garrison: Buildings"],
        icon = "Interface\\Icons\\Inv_Garrison_Resource",
        text = L["Garrison: Buildings"],
    })

local ldb_object_orderhall = LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject(ADDON_NAME .. "Orderhall",
    {
        type = "data source",
        label = L["Garrison: Orderhall"],
        icon = "Interface\\Icons\\Inv_Garrison_Resource",
        text = L["Garrison: Orderhall"],
    })


function Garrison:OnDependencyLoaded()
    if not dependencyLoaded then
        dependencyLoaded = true

        GarrisonLandingPage = _G.GarrisonLandingPage
        GarrisonMissionFrame = _G.GarrisonMissionFrame

        debugPrint("DependencyLoaded")

        Garrison:ScheduleTimer("RegisterEvents", 5)

        self:Hook("GarrisonCapacitiveDisplayFrame_Update", true)
    end
end

function Garrison:RegisterEvents()
    debugPrint("RegisterEvents")

    local fullUpdateRet = Garrison:FullUpdateBuilding(TYPE_BUILDING)

    Garrison:FullUpdateTalents()
    Garrison:FullUpdateShipments()
    -- needed?
    --Garrison:FullUpdateCategories()	

    timers.ldb_update = Garrison:ScheduleRepeatingTimer("LDBUpdate", 1)
    timers.notify_update = Garrison:ScheduleRepeatingTimer("QuickUpdate", 5)
    timers.icon_update = Garrison:ScheduleRepeatingTimer("SlowUpdate", 30)

    self:RegisterEvent("GARRISON_BUILDING_PLACED", "BuildingUpdate")
    self:RegisterEvent("GARRISON_BUILDING_REMOVED", "BuildingUpdate")
    self:RegisterEvent("GARRISON_BUILDING_UPDATE", "BuildingUpdate")
    self:RegisterEvent("GARRISON_BUILDING_ACTIVATED", "BuildingUpdate")
    self:RegisterEvent("GARRISON_UPDATE", "BuildingUpdate")
    self:RegisterEvent("SHIPMENT_UPDATE", "ShipmentStatusUpdate")

    Garrison:CheckInvasionAvailable()
    Garrison:CheckBuildingInfo()
    Garrison:CheckNumBonusRollQuests()
end

function Garrison:LoadDependencies()
    if not GarrisonMissionFrame or not GarrisonLandingPage then
        debugPrint("Loading Blizzard_GarrisonUI...")
        if UIParentLoadAddOn("Blizzard_GarrisonUI") then
            Garrison:OnDependencyLoaded()
        end
    end

    if not dependencyLoaded and _G.IsAddOnLoaded("Blizzard_GarrisonUI") then
        Garrison:OnDependencyLoaded()
    end
end

-- Helper Functions

local function toastCallback(callbackType, mouseButton, buttonDown, payload)

    local missionData = payload[1]

    if callbackType == "primary" then
        debugPrint("OK: " .. payload[1].name)
    end
    if callbackType == "secondary" then
        debugPrint("Dismiss: " .. payload[1].name)
        --missionData.notification = 2 -- Mission dismissed, never show again
        missionData.notificationDismissed = true
    end
end

local function toastSummary(toast, text, notificationType)
    if configDb.notification[notificationType].toastPersistent then
        toast:MakePersistent()
    end

    toast:SetTitle((L["%s - Summary"]):format(Garrison.NotificationTitle[notificationType]))
    toast:SetFormattedText(text)
    toast:SetIconTexture(Garrison.Icon[notificationType])
end


local function toastMissionComplete(toast, text, missionData)
    if (
        ( missionData.followerTypeID == 1 and configDb.notification.mission.WoD ) or
        ( missionData.followerTypeID == 2 and configDb.notification.mission.Shipyard ) or
        ( missionData.followerTypeID == 4 and configDb.notification.mission.Legion ) or
        ( missionData.followerTypeID == 22 and configDb.notification.mission.BfA ) ) then
        if configDb.notification.mission.toastPersistent then
            toast:MakePersistent()
        end
        toast:SetTitle(L["Mission complete"])
        toast:SetFormattedText(getColoredString(text, colors.green))

        if ToastVersion >= 8 and missionData.typeAtlas then
            toast:SetIconAtlas(missionData.typeAtlas)
        else
            toast:SetIconTexture([[Interface\Icons\Inv_Garrison_Resource]])
        end

        if configDb.notification.mission.extendedToast then
            toast:SetPrimaryCallback(_G.OKAY, toastCallback)
            toast:SetSecondaryCallback(L["Dismiss"], toastCallback)
            toast:SetPayload(missionData)
        end
    end
end

local function toastBuildingComplete(toast, text, buildingData)
    if configDb.notification.building.toastPersistent then
        toast:MakePersistent()
    end
    toast:SetTitle(L["Building complete"])
    toast:SetFormattedText(getColoredString(text, colors.green))
    toast:SetIconTexture(Garrison.GetIconPath(buildingData.icon))
    if configDb.notification.building.extendedToast then
        toast:SetPrimaryCallback(_G.OKAY, toastCallback)
        toast:SetSecondaryCallback(L["Dismiss"], toastCallback)
        toast:SetPayload(buildingData)
    end
end

local function toastShipmentComplete(toast, text, shipmentData)
    if configDb.notification.shipment.toastPersistent then
        toast:MakePersistent()
    end
    toast:SetTitle(L["Garrison: Shipment complete"])
    toast:SetFormattedText(getColoredString(text, colors.green))
    toast:SetIconTexture(Garrison.GetIconPath(shipmentData.texture))
    if configDb.notification.shipment.extendedToast then
        toast:SetPrimaryCallback(_G.OKAY, toastCallback)
        toast:SetSecondaryCallback(L["Dismiss"], toastCallback)
        toast:SetPayload(shipmentData)
    end
end

function Garrison:HandleNotificationQueue()
    if notificationQueue ~= nil and notificationQueue.lastUpdate and (time() - notificationQueue.lastUpdate) > 5 then
        -- send notification queue and delete
        local notificationCopy = notificationQueue
        notificationQueue = nil

        for notificationType, data in pairs(notificationCopy.data) do
            local toastEnabled = configDb.notification[notificationType].toastEnabled

            local toastText = ""

            for key, value in pairs(data) do

                toastText = toastText .. ("%s: %s\n"):format(key, getColoredString(value, colors.white))

                debugPrint(("[%s] HandleNotificationQueue (%s): %s"):format(notificationType, key, value))
            end

            if toastEnabled then
                Toast:Spawn(TOAST_SUMMARY, toastText, notificationType)
            end
        end
    end
end


function Garrison:AddNotificationToQueue(notificationType, paramCharInfo)
    local key = formatRealmPlayer(paramCharInfo, true)

    if notificationQueue == nil or notificationQueue.data == nil then
        notificationQueue = {
            firstUpdate = time(),
            data = {}
        }
    end

    notificationQueue.lastUpdate = time()

    if notificationQueue.data[notificationType] == nil then
        notificationQueue.data[notificationType] = {}
    end

    if notificationQueue.data[notificationType][key] == nil then
        notificationQueue.data[notificationType][key] = 1
    else
        notificationQueue.data[notificationType][key] = notificationQueue.data[notificationType][key] + 1
    end

    debugPrint(("[%s] AddNotificationToQueue (%s): %s"):format(notificationType, key, notificationQueue.data[notificationType][key]))
end


function Garrison:SendNotification(paramCharInfo, data, notificationType)

    local retVal = false

    local playerNotificationEnabled = globalDb.data[paramCharInfo.realmName][paramCharInfo.playerName].notificationEnabled
    local notificationQueueEnabled = configDb.notification[notificationType].notificationQueueEnabled
    local repeatOnLoad = configDb.notification[notificationType].repeatOnLoad

    if delayedInit then
        if configDb.notification[notificationType].enabled and (playerNotificationEnabled == nil or playerNotificationEnabled) then
            if (not data.notification or
                    (data.notification == 0) or
                    (not addonInitialized and (repeatOnLoad or notificationQueueEnabled) and not data.notificationDismissed) or
                    (notificationType == TYPE_SHIPMENT and (not data.notificationValue or data.shipmentsReadyEstimate > data.notificationValue))) then

                --debugPrint(("%s: %s > %s"):format(data.name, tostring(data.shipmentsReadyEstimate), tostring(data.notificationValue)))

                if not Garrison:DisableInInstance() then

                    local notificationText, toastName, toastText, soundName, toastEnabled, playSound, notificationTitle

                    if configDb.notification[notificationType].compactToast then
                        toastText = ("%s\n%s"):format(formatRealmPlayer(paramCharInfo, true), data.name)
                    else
                        toastText = ("%s\n\n%s"):format(formatRealmPlayer(paramCharInfo, true), data.name)
                    end

                    toastEnabled = configDb.notification[notificationType].toastEnabled
                    playSound = configDb.notification[notificationType].playSound
                    soundName = configDb.notification[notificationType].soundName or "None"


                    if (notificationType == TYPE_MISSION) then
                        notificationText = (L["Mission complete (%s): %s"]):format(formatRealmPlayer(paramCharInfo, false), data.name)
                        toastName = TOAST_MISSION_COMPLETE
                    elseif (notificationType == TYPE_BUILDING) then
                        notificationText = (L["Building complete (%s): %s"]):format(formatRealmPlayer(paramCharInfo, false), data.name)
                        toastName = TOAST_BUILDING_COMPLETE
                    elseif (notificationType == TYPE_SHIPMENT) then

                        if configDb.notification[notificationType].compactToast then
                            toastText = ("%s\n%s (%s / %s)"):format(formatRealmPlayer(paramCharInfo, true), data.name, data.shipmentsReadyEstimate, data.shipmentsTotal)
                        else
                            toastText = ("%s\n\n%s (%s / %s)"):format(formatRealmPlayer(paramCharInfo, true), data.name, data.shipmentsReadyEstimate, data.shipmentsTotal)
                        end

                        notificationText = (L["Shipment complete (%s): %s (%s / %s)"]):format(formatRealmPlayer(paramCharInfo, false), data.name, data.shipmentsReadyEstimate, data.shipmentsTotal)
                        toastName = TOAST_SHIPMENT_COMPLETE
                        data.notificationValue = data.shipmentsReadyEstimate
                    end

                    if not addonInitialized and notificationQueueEnabled then
                        -- don't display notifications, just save them and prepare for later output
                        Garrison:AddNotificationToQueue(notificationType, paramCharInfo, notificationTitle)
                    else
                        Garrison.fireEvent(notificationType, paramCharInfo, data)

                        debugPrint(notificationText)

                        self:Pour(notificationText, colors.green.r, colors.green.g, colors.green.b)

                        if toastEnabled then
                            Toast:Spawn(toastName, toastText, data)
                        end

                        if playSound then
                            PlaySoundFile(LSM:Fetch("sound", soundName))
                        end
                    end

                    data.notification = 1

                    retVal = true
                else
                    debugPrint(("Notifaction (%s) hidden (%s)"):format(data.name, notificationType))
                end
            end
        end
    end

    return retVal
end

function Garrison:GetPlayerMissionCount(paramCharInfo, missionCount, missions)
    local now = time()

    local numMissionsPlayer = tableSize(missions)

    if numMissionsPlayer > 0 then
        missionCount.total = missionCount.total + numMissionsPlayer

        for missionID, missionData in pairs(missions) do
            local timeLeft = missionData.duration - (now - missionData.start)

            -- Do mission handling while we are at it
            if (timeLeft < 0 and missionData.start == -1) then
                -- Detect completed mission


                -- Deprecated - should be detected on finished event
                local parsedTimeLeft = string.match(missionData.timeLeft, Garrison.COMPLETED_PATTERN)
                if (parsedTimeLeft == "0") then
                    -- 1 * 0 found in string -> assuming mission complete
                    missionData.start = 0
                end
            end

            -- Count

            -- Check to make sure the mission's type is enabled
            if (
            ( missionData.followerTypeID == 1 and configDb.general.mission.showWoD ) or
            ( missionData.followerTypeID == 2 and configDb.general.mission.showShip ) or
            ( missionData.followerTypeID == 4 and configDb.general.mission.showLegion ) or
            ( missionData.followerTypeID == 22 and configDb.general.mission.showBfA ) ) then
                if missionData.start > 0 then
                    if (timeLeft <= 0) then
                        missionCount.complete = missionCount.complete + 1
                        missionData.statusComplete = true
                    else
                        if missionCount.nextTime == -1 or timeLeft < missionCount.nextTime then
                            missionCount.nextTime = timeLeft
                            missionCount.nextData = missionData
                            missionCount.nextChar = paramCharInfo
                        end

                        missionCount.inProgress = missionCount.inProgress + 1
                    end
                else
                    if missionData.start == 0 then
                        missionCount.complete = missionCount.complete + 1
                        missionData.statusComplete = true
                    else
                        missionCount.inProgress = missionCount.inProgress + 1
                    end
                end

                missionData.missionState = missionData.statusComplete and Garrison.STATE_MISSION_COMPLETE or Garrison.STATE_MISSION_INPROGRESS

                missionData.timeLeftCalc = math.max(0, timeLeft)

                if (timeLeft < 0 and missionData.start >= 0) then
                    Garrison:SendNotification(paramCharInfo, missionData, TYPE_MISSION)
                end
            end
        end
    end
end


function Garrison:DoShipmentMagic(shipmentData, paramCharInfo)
    local now = time()

    local shipmentsReady, shipmentsInProgress, shipmentsAvailable
    local timeLeftNext = 0
    local timeLeftTotal = 0
    local shipmentsAvailable = shipmentData.shipmentCapacity

    if shipmentData and shipmentData.shipmentsTotal and shipmentData.creationTime then
        local timeDiff = (now - shipmentData.creationTime)
        local shipmentsReadyByTime = 0
        if shipmentData.duration and shipmentData.duration > 0 then
            shipmentsReadyByTime = math.floor(timeDiff / shipmentData.duration)
        end

        --if isCurrentChar(paramCharInfo) then
        --	shipmentsReady = shipmentData.shipmentsReady
        --else
        -- Only for other chars
        shipmentsReady = math.min(shipmentData.shipmentsReady + shipmentsReadyByTime, shipmentData.shipmentsTotal)
        --end
        shipmentsInProgress = shipmentData.shipmentsTotal - shipmentsReady
        shipmentsAvailable = math.max(0, shipmentData.shipmentCapacity - shipmentData.shipmentsTotal) -- thanks blizzard, api returns total > capacity sometimes.

        timeLeftNext = shipmentData.duration - timeDiff

        if shipmentsInProgress == 0 then
            timeLeftNext = 0
        else
            timeLeftNext = timeLeftNext + (shipmentData.duration * shipmentsReadyByTime)
            timeLeftTotal = timeLeftNext + (shipmentData.duration * (shipmentsInProgress - 1))
        end

        return shipmentsReady, shipmentsInProgress, shipmentsAvailable, timeLeftNext, timeLeftTotal
    else
        return 0, 0, shipmentsAvailable, 0, 0
    end
end

function Garrison:GetPlayerBuildingCount(paramCharInfo, buildingCount, buildings)
    local now = time()

    local numBuildingsPlayer = tableSize(buildings)

    if numBuildingsPlayer > 0 then
        buildingCount.building.total = buildingCount.building.total + numBuildingsPlayer

        for plotID, buildingData in pairs(buildings) do

            if buildingData.isBuilding or buildingData.canActivate then
                -- Check for building complete
                local timeLeft = buildingData.buildTime - (now - buildingData.timeStart)

                if buildingData.canActivate or timeLeft < 0 then
                    Garrison:SendNotification(paramCharInfo, buildingData, TYPE_BUILDING)
                    buildingCount.building.complete = buildingCount.building.complete + 1
                    buildingData.canActivate = true
                    buildingData.buildingState = Garrison.STATE_BUILDING_COMPLETE
                else
                    buildingCount.building.building = buildingCount.building.building + 1
                    buildingData.buildingState = Garrison.STATE_BUILDING_BUILDING
                end
            else
                buildingCount.building.active = buildingCount.building.active + 1
                buildingData.buildingState = Garrison.STATE_BUILDING_ACTIVE

                local shipmentData = buildingData.shipment

                -- Check for work orders
                if shipmentData and shipmentData.name and shipmentData.shipmentsTotal then

                    local shipmentsReady, shipmentsInProgress, shipmentsAvailable, timeLeftNext = Garrison:DoShipmentMagic(shipmentData, paramCharInfo)

                    shipmentData.shipmentsReadyEstimate = shipmentsReady
                    shipmentData.shipmentsInProgress = shipmentsInProgress
                    shipmentData.shipmentsAvailable = shipmentsAvailable

                    if shipmentData.shipmentsReadyEstimate > 0 then
                        Garrison:SendNotification(paramCharInfo, shipmentData, TYPE_SHIPMENT)
                    end

                    if shipmentData.notificationValue and shipmentData.shipmentsReadyEstimate < shipmentData.notificationValue then
                        shipmentData.notificationValue = shipmentData.shipmentsReadyEstimate
                    end

                    buildingCount.shipment.inProgress = buildingCount.shipment.inProgress + shipmentsInProgress
                    buildingCount.shipment.ready = buildingCount.shipment.ready + shipmentsReady
                    buildingCount.shipment.total = buildingCount.shipment.total + shipmentData.shipmentsTotal
                    buildingCount.shipment.available = buildingCount.shipment.available + shipmentsAvailable

                    if timeLeftNext > 0 and (buildingCount.shipment.nextTime == -1 or timeLeftNext < buildingCount.shipment.nextTime) then
                        --debugPrint(("Update %s (%s)"):format(timeLeftNext, paramCharInfo.playerName))

                        buildingCount.shipment.nextTime = timeLeftNext
                        buildingCount.shipment.nextData = shipmentData
                        buildingCount.shipment.nextChar = paramCharInfo
                    end
                elseif shipmentData and shipmentData.name then
                    buildingCount.shipment.available = buildingCount.shipment.available + shipmentData.shipmentCapacity
                end
            end
        end
    end
end

function Garrison:GetPlayerOrderhallCount(paramCharInfo, orderhallCount, categories, talents)
    local now = time()

    local numCategoriesPlayer = tableSize(categories)

    if numCategoriesPlayer > 0 then
        orderhallCount.category.total = orderhallCount.category.total + numCategoriesPlayer
    end

    local numTalentsPlayer = tableSize(talents)
    local tiersAvailable = 0
    if numTalentsPlayer > 0 then
        for _, talentData in pairs(talents) do
            --debugPrint(("%s: %s"):format(talentData.name, talentData.talentAvailability))

            if Garrison.CheckOrderTalentAvailability(talentData.talentAvailability, 0) then
                tiersAvailable = tiersAvailable + 1
            end            
        end

        orderhallCount.talent.tiersAvailable = tiersAvailable  
        orderhallCount.talent.total = orderhallCount.talent.total + numTalentsPlayer
    end

    --debugPrint(("%s => %s / %s / %s"):format(paramCharInfo.playerName, numCategoriesPlayer, numTalentsPlayer, tiersAvailable))
end

function Garrison:GetOrderhallCount(paramCharInfo)
    local orderhallCount = {
        category = {
            total = 0,
            inProgress = 0,
            complete = 0,
        },
        talent = {
            total = 0,
            inProgress = 0,
            complete = 0,
            tiersAvailable = 0,
        }
    }

    local orderhallCountCurrent


    if paramCharInfo then
        Garrison:GetPlayerOrderhallCount(paramCharInfo, orderhallCount, globalDb.data[paramCharInfo.realmName][paramCharInfo.playerName].categories, globalDb.data[paramCharInfo.realmName][paramCharInfo.playerName].talents)
        --missionCountCurrent = missionCount
    else
        Garrison:GetPlayerOrderhallCount(charInfo, orderhallCount, globalDb.data[charInfo.realmName][charInfo.playerName].categories, globalDb.data[charInfo.realmName][charInfo.playerName].talents)

        orderhallCountCurrent = Garrison.deepcopy(orderhallCount, nil)

        for realmName, realmData in pairs(globalDb.data) do
            for playerName, playerData in pairs(realmData) do
                -- don't count/show disabled characters
                if playerData.ldbEnabled == nil or playerData.ldbEnabled then
                    if not Garrison.isCurrentChar(playerData.info) then
                        Garrison:GetPlayerOrderhallCount(playerData.info, orderhallCount, playerData.categories, playerData.talents)
                    end
                end
            end
        end
    end



    return orderhallCount, orderhallCountCurrent
end



function Garrison:GetMissionCount(paramCharInfo)
    local missionCount = {
        total = 0,
        inProgress = 0,
        complete = 0,
        nextTime = -1,
        nextName = nil,
        nextChar = nil,
    }
    local missionCountCurrent = nil

    if paramCharInfo then
        Garrison:GetPlayerMissionCount(paramCharInfo, missionCount, globalDb.data[paramCharInfo.realmName][paramCharInfo.playerName].missions)
        --missionCountCurrent = missionCount
    else
        Garrison:GetPlayerMissionCount(charInfo, missionCount, globalDb.data[charInfo.realmName][charInfo.playerName].missions)

        missionCountCurrent = Garrison.deepcopy(missionCount, nil)

        for realmName, realmData in pairs(globalDb.data) do
            for playerName, playerData in pairs(realmData) do
                -- don't count/show disabled characters
                if playerData.ldbEnabled == nil or playerData.ldbEnabled then
                    if not Garrison.isCurrentChar(playerData.info) then
                        Garrison:GetPlayerMissionCount(playerData.info, missionCount, playerData.missions)
                    end
                end
            end
        end
    end

    return missionCount, missionCountCurrent
end

function Garrison:GetBuildingCount(paramCharInfo)
    local buildingCount = {
        building = {
            total = 0,
            building = 0,
            complete = 0,
            active = 0,
        },
        shipment = {
            inProgress = 0,
            ready = 0,
            total = 0,
            available = 0,
            nextTime = -1,
            nextName = nil,
            nextChar = nil,
        }
    }
    local buildingCountCurrent


    if paramCharInfo then
        Garrison:GetPlayerBuildingCount(paramCharInfo, buildingCount, globalDb.data[paramCharInfo.realmName][paramCharInfo.playerName].buildings)
        --buildingCountCurrent = buildingCount
    else
        Garrison:GetPlayerBuildingCount(charInfo, buildingCount, globalDb.data[charInfo.realmName][charInfo.playerName].buildings)

        buildingCountCurrent = Garrison.deepcopy(buildingCount, nil)

        for realmName, realmData in pairs(globalDb.data) do
            for playerName, playerData in pairs(realmData) do
                -- don't count/show disabled characters
                if playerData.ldbEnabled == nil or playerData.ldbEnabled then
                    if not Garrison.isCurrentChar(playerData.info) then
                        Garrison:GetPlayerBuildingCount(playerData.info, buildingCount, playerData.buildings)
                    end
                end
            end
        end
    end

    return buildingCount, buildingCountCurrent
end


function Garrison:UpdateConfig()
    if GarrisonLandingPageMinimapButton then
        if GarrisonLandingPageMinimapButton:IsShown() then
            if configDb.general.hideGarrisonMinimapButton then
                GarrisonLandingPageMinimapButton:Hide()
            end
        else
            if not configDb.general.hideGarrisonMinimapButton then
                GarrisonLandingPageMinimapButton:Show()
            end
        end
    end

    if LDBIcon and configDb.minimap.load then
        if configDb.minimap.mission.hide then
            LDBIcon:Hide("BrokerGarrisonLDBMission")
        else
            LDBIcon:Show("BrokerGarrisonLDBMission")
        end

        if configDb.minimap.building.hide then
            LDBIcon:Hide("BrokerGarrisonLDBBuilding")
        else
            LDBIcon:Show("BrokerGarrisonLDBBuilding")
        end
    end
end

local updater
local tooltipRegistry = {}

local DrawTooltip
do
    local NUM_TOOLTIP_COLUMNS = {
        [TYPE_BUILDING] = 5,
        [TYPE_MISSION] = 5,
        [TYPE_ORDERHALL] = 6,
    }

    local ALIGNMENT_TOOLTIP_COLUMNS = {}

    local LDB_anchor
    local tooltipType
    local tooltip
    local locked = false
    local tooltipTypeNew

    local last_update = 0

    updater = _G.CreateFrame("Frame", nil, _G.UIParent)

    updater:SetScript("OnUpdate",
        function(self, elapsed)
            last_update = last_update + elapsed

            if last_update < 0.1 then
                return
            end

            --tooltipRegistry[TYPE_BUILDING].tooltip

            if tooltip and tooltipType then
                --debugPrint("onupdate tooltip: "..tooltipType)
                if tooltip:IsMouseOver() or (LDB_anchor and LDB_anchor:IsMouseOver()) then
                    --debugPrint("mouseover")
                    self.elapsed = (self.elapsed or 0) + last_update

                    if (configDb.general.highAccuracy and self.elapsed >= 1) or self.elapsed > 30 then
                        --debugPrint("redraw")
                        self.elapsed = 0
                        DrawTooltip(LDB_anchor, tooltipType)
                    end
                end
            end

            last_update = 0
        end)

    local function ExpandButton_OnMouseUp(tooltip_cell, param, button)
        local realm_and_character, paramType = unpack(param)

        local realm, character_name = (":"):split(realm_and_character, 2)

        if paramType == TYPE_MISSION then
            globalDb.data[realm][character_name].missionsExpanded = not globalDb.data[realm][character_name].missionsExpanded
        elseif paramType == TYPE_BUILDING then
            globalDb.data[realm][character_name].buildingsExpanded = not globalDb.data[realm][character_name].buildingsExpanded
        elseif paramType == TYPE_ORDERHALL then
            globalDb.data[realm][character_name].orderhallExpanded = not globalDb.data[realm][character_name].orderhallExpanded
        end

        DrawTooltip(tooltipRegistry[paramType].anchor, paramType)
    end

    local function ExpandButton_OnMouseDown(tooltip_cell, param, button)
        --local is_expanded, paramType = unpack(param)

        --local line, column = tooltip_cell:GetPosition()
        --tooltip:SetCell(line, column, is_expanded and Garrison.ICON_CLOSE_DOWN or Garrison.ICON_OPEN_DOWN)
    end

    local function Tooltip_OnRelease_Mission(arg)
        tooltipRegistry[TYPE_MISSION].tooltip = nil
        tooltipRegistry[TYPE_MISSION].anchor = nil

        if tooltipType and tooltipType == TYPE_MISSION then
            LDB_anchor = nil
            tooltipType = nil
            --elseif tooltipType and tooltipType == TYPE_BUILDING then
        elseif tooltipType and (tooltipType ~= TYPE_MISSION) then
            debugPrint("OnReleaseDraw: " .. tooltipType)
            DrawTooltip(LDB_anchor, tooltipType)
        end
    end

    local function Tooltip_OnRelease_Building(arg)
        tooltipRegistry[TYPE_BUILDING].tooltip = nil
        tooltipRegistry[TYPE_BUILDING].anchor = nil

        if tooltipType and tooltipType == TYPE_BUILDING then
            LDB_anchor = nil
            tooltipType = nil
            --elseif tooltipType and tooltipType == TYPE_MISSION then
        elseif tooltipType and (tooltipType ~= TYPE_BUILDING) then
            debugPrint("OnReleaseDraw: " .. tooltipType)
            DrawTooltip(LDB_anchor, tooltipType)
        end
    end

    local function Tooltip_OnRelease_Orderhall(arg)
        tooltipRegistry[TYPE_ORDERHALL].tooltip = nil
        tooltipRegistry[TYPE_ORDERHALL].anchor = nil

        if tooltipType and tooltipType == TYPE_ORDERHALL then
            LDB_anchor = nil
            tooltipType = nil
        elseif tooltipType and (tooltipType ~= TYPE_ORDERHALL) then
            debugPrint("OnReleaseDraw: " .. tooltipType)
            DrawTooltip(LDB_anchor, tooltipType)
        end
    end

    function DrawTooltip(anchor_frame, paramTooltipType)
        if not configDb.general.updateInCombat and InCombatLockdown() then
            return
        end

        if not anchor_frame then
            return
        end
        LDB_anchor = anchor_frame

        if tooltipType ~= paramTooltipType then
            -- mission <> building switch
            debugPrint("Switched tooltip")
            tooltipTypeNew = paramTooltipType
        end

        tooltipType = paramTooltipType
        if not tooltipRegistry[tooltipType] then
            tooltipRegistry[tooltipType] = {}
        end

        tooltip = tooltipRegistry[tooltipType].tooltip
        tooltipRegistry[tooltipType].anchor = LDB_anchor
        --LDB_anchor = tooltipRegistry[tooltipType].tooltip

        locked = true

        local detached = Garrison:IsDetached(tooltipType)

        if not tooltip then

            for i = 1, NUM_TOOLTIP_COLUMNS[tooltipType] do
                ALIGNMENT_TOOLTIP_COLUMNS[i] = "LEFT"
            end

            tooltipRegistry[tooltipType].tooltip = LibQTip:Acquire("BrokerGarrisonTooltip-" .. paramTooltipType, NUM_TOOLTIP_COLUMNS[tooltipType], unpack(ALIGNMENT_TOOLTIP_COLUMNS))
            tooltip = tooltipRegistry[tooltipType].tooltip

            if tooltipType == TYPE_MISSION then
                tooltip.OnRelease = Tooltip_OnRelease_Mission
            elseif tooltipType == TYPE_BUILDING then
                tooltip.OnRelease = Tooltip_OnRelease_Building
            elseif tooltipType == TYPE_ORDERHALL then
                tooltip.OnRelease = Tooltip_OnRelease_Orderhall
            end

            tooltip:EnableMouse(true)

            if detached then
                LDB_anchor = UIParent
                tooltipRegistry[tooltipType].anchor = LDB_anchor
                tooltip:SmartAnchorTo(UIParent)
                tooltip:SetAutoHideDelay(nil, UIParent)
            else
                tooltip:SmartAnchorTo(anchor_frame)
                tooltip:SetAutoHideDelay(configDb.display.autoHideDelay or 0.25, LDB_anchor)
            end

            tooltip:SetScale(configDb.display.scale or 1)
            tooltip:SetHighlightTexture(nil)
            local font = LSM:Fetch("font", configDb.display.fontName or DEFAULT_FONT)
            local fontSize = configDb.display.fontSize or 12
            local headerFontSize = fontSize + 2

            local tmpFont = CreateFont("BrokerGarrisonTooltipFont")
            tmpFont:SetFont(font, fontSize)

            local tmpHeaderFont = CreateFont("BrokerGarrisonTooltipHeaderFont")
            tmpHeaderFont:SetFont(font, headerFontSize)

            tooltip:SetFont(tmpFont)
            tooltip:SetHeaderFont(tmpHeaderFont)
        end

        local now = time()
        local name, row, realmName, realmData, playerName, playerData, missionID, missionData

        tooltip:Clear()
        tooltip:SetCellMarginH(0)

        tooltip:SetCellMarginV(0)

        local realmNum = 0
        local textPlaceholder = getColoredString(" | ", colors.lightGray)

        tooltipFunctions[tooltipType](tooltip, ExpandButton_OnMouseUp)

        --debugPrint(("r: %s, g: %s, b: %s, a: %s"):format(configDb.display.backgroundColor.r, configDb.display.backgroundColor.g, configDb.display.backgroundColor.b, configDb.display.backgroundColor.a))

        tooltip:SetBackdropColor(0, 0, 0, 255 / configDb.display.backgroundAlpha)

        tooltip:Show()

        tooltip:UpdateScrolling()

        if detached then
            tooltip:SmartAnchorTo(UIParent)
            tooltip:SetAutoHideDelay(nil, UIParent)
        else
            tooltip:SmartAnchorTo(anchor_frame)
            tooltip:SetAutoHideDelay(configDb.display.autoHideDelay or 0.25, LDB_anchor)
        end

        locked = false
    end

    function ldb_object_building:OnEnter()
        DrawTooltip(self, TYPE_BUILDING)
    end

    function ldb_object_building:OnLeave()
        --updater.elapsed = 0
    end

    function ldb_object_mission:OnEnter()
        DrawTooltip(self, TYPE_MISSION)
    end

    function ldb_object_orderhall:OnEnter()
        DrawTooltip(self, TYPE_ORDERHALL)
    end

    local function onclick(button, paramType)
        if button == "LeftButton" then
            Garrison:LoadDependencies()

            if IsShiftKeyDown() then
                Garrison:ToggleDetached(paramType)
            else
                if GarrisonLandingPage then
                    if (not GarrisonLandingPage:IsShown()) then
                        ShowGarrisonLandingPage(C_Garrison.GetLandingPageGarrisonType());
                    else
                        HideUIPanel(GarrisonLandingPage)
                    end
                end
            end
        else
            for i, button in ipairs(InterfaceOptionsFrameAddOns.buttons) do
                if button.element and button.element.name == ADDON_NAME and button.element.collapsed then
                    OptionsListButtonToggle_OnClick(button.toggle)
                end
            end
            if AceConfigDialog.OpenFrames[ADDON_NAME] then
                AceConfigDialog:Close(ADDON_NAME)
            else
                AceConfigDialog:Open(ADDON_NAME)
            end
        end
    end

    function ldb_object_mission:OnClick(button)
        onclick(button, TYPE_MISSION)
    end

    function ldb_object_building:OnClick(button)
        onclick(button, TYPE_BUILDING)
    end

    function ldb_object_orderhall:OnClick(button)
        onclick(button, TYPE_ORDERHALL)
    end
end

function Garrison:IsDetached(paramType)
    return Garrison.detachframe[paramType] and Garrison.detachframe[paramType]:IsShown()
end

function Garrison:HideDetached(paramType)
    Garrison.detachframe[paramType]:Hide()
end

function Garrison:ToggleDetached(paramType)
    if Garrison:IsDetached(paramType) then
        Garrison:HideDetached(paramType)
    else
        Garrison:ShowDetached(paramType)
    end
end

local posx, posy

function Garrison:ShowDetached(paramType)
    local tooltip = tooltipRegistry[paramType] and tooltipRegistry[paramType].tooltip or nil

    if not Garrison.detachframe[paramType] then
        local f = _G.CreateFrame("Frame", "BrokerGarrisonFrame" .. paramType, _G.UIParent, "BasicFrameTemplate")


        f:SetMovable(true)
        f:SetFrameStrata("TOOLTIP")
        f:SetClampedToScreen(true)
        f:EnableMouse(true)
        f:SetUserPlaced(true)
        f.type = paramType

        if false and posx and posy then
            f:SetPoint("TOPLEFT", posx, -posy)
        else
            f:SetPoint("CENTER")
        end
        f:SetScript("OnMouseDown", function()
            f:StartMoving()
        end)

        f:SetScript("OnMouseUp", function()
            f:StopMovingOrSizing()
            posx = f:GetLeft()
            posy = UIParent:GetTop() - (f:GetTop() * f:GetScale())
        end)

        f:SetScript("OnHide", function()
            if tooltipRegistry[f.type] and tooltipRegistry[f.type].tooltip then
                LibQTip:Release(tooltipRegistry[f.type].tooltip);
            end
        end)

        f:SetScript("OnUpdate", function(self)
            local tooltip = tooltipRegistry[f.type] and tooltipRegistry[f.type].tooltip or nil
            if not tooltip then f:Hide(); return end
            local w, h = tooltip:GetSize()
            self:SetSize(w * tooltip:GetScale(), (h + 20) * tooltip:GetScale())
            tooltip:ClearAllPoints()
            tooltip:SetPoint("BOTTOMLEFT", Garrison.detachframe[f.type])
            tooltip:SetFrameLevel(Garrison.detachframe[f.type]:GetFrameLevel() + 1)
            tooltip:Show()
        end)

        f:SetScript("OnKeyDown", function(self, key)
            if key == "ESCAPE" then
                f:SetPropagateKeyboardInput(false)
                f:Hide();
            end
        end)

        f:EnableKeyboard(true)
        Garrison.detachframe[paramType] = f
    end

    local f = Garrison.detachframe[paramType]
    f:SetPropagateKeyboardInput(true)

    if tooltipRegistry[paramType] and tooltipRegistry[paramType].tooltip then tooltipRegistry[paramType].tooltip:Hide() end

    f:Show()

    DrawTooltip(f, paramType)
end

function Garrison:UpdateUnknownMissions(missionsLoaded)
    local activeMissions = {}

    local garrisonMission = {}

    for key, garrisonMission in pairs(Garrison:GetInProgressMissions()) do
        activeMissions[garrisonMission.missionID] = true
        -- Mission not found in Database
        if not globalDb.data[charInfo.realmName][charInfo.playerName].missions[garrisonMission.missionID]
                or globalDb.data[charInfo.realmName][charInfo.playerName].missions[garrisonMission.missionID].start == -1 then

            local parsedTime = Garrison:GetParsedStartTime(garrisonMission.timeLeft, garrisonMission.durationSeconds)
            --debugPrint(("Parse Duration: %s => %s"):format(garrisonMission.timeLeft, parsedTime))

            Garrison:GARRISON_MISSION_STARTED("manual", garrisonMission.missionID, parsedTime)

            local mission = {
                id = garrisonMission.missionID,
                name = garrisonMission.name,
                start = -1,
                duration = garrisonMission.durationSeconds,
                notification = 0,
                timeLeft = garrisonMission.timeLeft,
                type = garrisonMission.type,
                typeAtlas = garrisonMission.typeAtlas,
                level = garrisonMission.level,
            }
            --globalDb.data[charInfo.realmName][charInfo.playerName].missions[garrisonMission.missionID] = mission

            -- debugPrint("Update untracked Mission: "..garrisonMission.missionID)
        end
    end

    if missionsLoaded then
        -- cleanup unknown missions
        local missionID
        for missionID, _ in pairs(globalDb.data[charInfo.realmName][charInfo.playerName].missions) do
            if not activeMissions[missionID] then
                globalDb.data[charInfo.realmName][charInfo.playerName].missions[missionID] = nil
                debugPrint("Removed unknown Mission: " .. missionID)
            end
        end
    end

    local completeMissions = {}

    for key, garrisonMission in pairs(Garrison:GetCompleteMissions()) do
        if (globalDb.data[charInfo.realmName][charInfo.playerName].missions[garrisonMission.missionID]) then
            if globalDb.data[charInfo.realmName][charInfo.playerName].missions[garrisonMission.missionID].start ~= 0 then
                debugPrint("Finished Mission (Loop): " .. garrisonMission.missionID)
                globalDb.data[charInfo.realmName][charInfo.playerName].missions[garrisonMission.missionID].start = 0
            end
        else
            debugPrint("Unknown Mission (Loop): " .. garrisonMission.missionID)
        end
    end
end


function Garrison:Update()
    if not configDb.general.updateInCombat and InCombatLockdown() then
        return
    end

    Garrison:FullUpdateBuilding(TYPE_SHIPMENT)

    Garrison:UpdateUnknownMissions(false)

    Garrison:UpdateLDB()

    -- First update
    if delayedInit then
        addonInitialized = true
    end
end

function Garrison:UpdateLDB()
    -- LDB Text
    local missionCount, missionCountCurrent = Garrison:GetMissionCount(nil)
    local buildingCount, buildingCountCurrent = Garrison:GetBuildingCount(nil)

    local currencyTotal, currencyAmount = 0, 0
    local currencyApexisAmount, currencyApexisTotal = 0, 0
    local currencySealOfTemperedFateAmount = 0
    local currencySealOfInevitableFateAmount = 0
    local currencyOil = 0

    local currencyOrderResourcesAmount = 0
    local currencyAncientManaAmount = 0
    local currencyAncientManaMax = 2000

    local resourceCacheAmountMaxFilling = 0
    local cacheSize = 0

    local resourceCacheAmount, resourceCacheAmountMax = 0, 0
    local resourceCacheAmountMaxChar = nil
    local resourceCacheAmountMaxSize = 500

    local now = time()

    local invasionAvailable
    local invasionAvailableCurrent

    for realmName, realmData in pairs(globalDb.data) do
        for playerName, playerData in pairs(realmData) do
            -- don't count/show disabled characters
            if playerData.ldbEnabled == nil or playerData.ldbEnabled then

                local tmpResourceCacheAmount = Garrison.getResourceFromTimestamp(playerData.cacheSize, playerData.garrisonCacheLastLooted, now)

                if Garrison.isCurrentChar(playerData.info) then
                    currencyAmount = (playerData.currencyAmount or 0)
                    currencyApexisAmount = playerData.currencyApexisAmount or 0
                    currencySealOfTemperedFateAmount = playerData.currencySealOfTemperedFateAmount or 0
                    currencySealOfInevitableFateAmount = playerData.currencySealOfInevitableFateAmount or 0
                    currencyOrderResourcesAmount = playerData.currencyOrderResourcesAmount or 0
                    currencyAncientManaAmount = playerData.currencyAncientManaAmount or 0
                    currencyOil = playerData.currencyOil or 0
                    cacheSize = playerData.cacheSize or 0

                    resourceCacheAmount = tmpResourceCacheAmount or 0

                    if playerData.invasion and playerData.invasion.available then
                        --debugPrint("invasionAvailableCurrent!!!!!")
                        invasionAvailableCurrent = true
                    end
                end
                currencyTotal = currencyTotal + (playerData.currencyAmount or 0)
                currencyApexisTotal = currencyApexisTotal + (playerData.currencyApexisAmount or 0)
                if playerData.invasion and playerData.invasion.available then
                    invasionAvailable = true
                end

                local tmpResourceCacheFilling = (tmpResourceCacheAmount or 0) / (playerData.cacheSize or 500)
                if tmpResourceCacheAmount then
                    if tmpResourceCacheFilling > resourceCacheAmountMaxFilling then
                        --if tmpResourceCacheAmount > resourceCacheAmountMax then
                        resourceCacheAmountMax = tmpResourceCacheAmount
                        resourceCacheAmountMaxChar = playerData.info
                        resourceCacheAmountMaxSize = playerData.cacheSize
                        resourceCacheAmountMaxFilling = tmpResourceCacheFilling
                    end
                    --resourceCacheAmountMax = math.max(resourceCacheAmountMax, tmpResourceCacheAmount)
                end
            end
        end
    end

    local data = {
        missionCount = missionCount,
        buildingCount = buildingCount,
        missionCountCurrent = missionCountCurrent,
        buildingCountCurrent = buildingCountCurrent,
        currencyAmount = currencyAmount,
        currencyApexisAmount = currencyApexisAmount,
        currencySealOfTemperedFateAmount = currencySealOfTemperedFateAmount,
        currencySealOfInevitableFateAmount = currencySealOfInevitableFateAmount,
        currencyOrderResourcesAmount = currencyOrderResourcesAmount,
        currencyAncientManaAmount = currencyAncientManaAmount,
        currencyApexisTotal = currencyApexisTotal,
        currencyOil = currencyOil,
        cacheSize = cacheSize,
        currencyTotal = currencyTotal,
        currencyIcon = Garrison.ICON_CURRENCY,
        currencyApexisIcon = Garrison.ICON_CURRENCY_APEXIS,
        resourceCacheAmountMaxFilling = resourceCacheAmountMaxFilling,
        resourceCacheAmountMaxSize = resourceCacheAmountMaxSize,
        cacheSize = cacheSize,
        resourceCacheAmountMax = resourceCacheAmountMax,
        resourceCacheAmountMaxChar = resourceCacheAmountMaxChar,
        resourceCacheAmount = resourceCacheAmount,
        invasionAvailable = invasionAvailable,
        invasionAvailableCurrent = invasionAvailableCurrent,
    }
    Garrison.data = data
    --_G["BrokerGarrison"].data = Garrison.data


    ldb_object_mission.text = Garrison.replaceVariables(Garrison:GetLDBText(Garrison.TYPE_MISSION), data)
    ldb_object_mission.label = configDb.general.mission.ldbLabelText

    ldb_object_building.text = Garrison.replaceVariables(Garrison:GetLDBText(Garrison.TYPE_BUILDING), data)
    ldb_object_building.label = configDb.general.building.ldbLabelText

    ldb_object_orderhall.text = Garrison.replaceVariables(Garrison:GetLDBText(Garrison.TYPE_ORDERHALL), data)
    ldb_object_orderhall.label = configDb.general.orderhall.ldbLabelText
end


function Garrison:OnInitialize()
    garrisonDb = LibStub("AceDB-3.0"):New(ADDON_NAME .. "DB", DB_DEFAULTS, true)
    globalDb = garrisonDb.global
    configDb = garrisonDb.profile

    self.DB = garrisonDb

    -- Data migration
    if _G.Broker_GarrisonDB.data then
        globalDb.data = _G.Broker_GarrisonDB.data
        _G.Broker_GarrisonDB.data = nil
    end

    -- DB
    if not globalDb.data[charInfo.realmName] then
        globalDb.data[charInfo.realmName] = {}
    end

    if (not globalDb.data[charInfo.realmName][charInfo.playerName]) then
        globalDb.data[charInfo.realmName][charInfo.playerName] = {
            missions = {},
            buildings = {},
            shipments = {},
            talents = {},
            categories = {},
            missionsExpanded = true,
            buildingsExpanded = true,
            orderhallExpanded = true,
            info = charInfo,
            currencyAmount = 0,
            tooltipEnabled = true,
            notificationEnabled = true,
        }
    end

    if (not globalDb.data[charInfo.realmName][charInfo.playerName]["missions"]) then
        globalDb.data[charInfo.realmName][charInfo.playerName]["missions"] = {}
    end

    -- Upgrade Code, 1 => 2
    if not globalDb.data[charInfo.realmName][charInfo.playerName].configVersion then
        globalDb.data[charInfo.realmName][charInfo.playerName].configVersion = 2

        globalDb.data[charInfo.realmName][charInfo.playerName].tooltipEnabled = true
        globalDb.data[charInfo.realmName][charInfo.playerName].notificationEnabled = true
        globalDb.data[charInfo.realmName][charInfo.playerName].ldbEnabled = true
    end

    if globalDb.data[charInfo.realmName][charInfo.playerName].configVersion == 2 then
        globalDb.data[charInfo.realmName][charInfo.playerName].configVersion = 3
        globalDb.data[charInfo.realmName][charInfo.playerName].orderhallExpanded = true
    end



    if not globalDb.data[charInfo.realmName][charInfo.playerName].cacheSize then
        globalDb.data[charInfo.realmName][charInfo.playerName].cacheSize = 500
    end

    if not charInfo.bonusEnabled then
        -- Check for level
        local playerLevel = _G.UnitLevel("player")

        if playerLevel == _G.GetMaxPlayerLevel() then
            globalDb.data[charInfo.realmName][charInfo.playerName].info.bonusEnabled = true
        end
    end

    if (not globalDb.data[charInfo.realmName][charInfo.playerName]["talents"]) then
        globalDb.data[charInfo.realmName][charInfo.playerName]["talents"] = {}
    end
    if (not globalDb.data[charInfo.realmName][charInfo.playerName]["categories"]) then
        globalDb.data[charInfo.realmName][charInfo.playerName]["categories"] = {}
    end
    if (not globalDb.data[charInfo.realmName][charInfo.playerName]["followerShipments"]) then
        globalDb.data[charInfo.realmName][charInfo.playerName]["followerShipments"] = {}
    end
    if (not globalDb.data[charInfo.realmName][charInfo.playerName]["looseShipments"]) then
        globalDb.data[charInfo.realmName][charInfo.playerName]["looseShipments"] = {}
    end
    if (not globalDb.data[charInfo.realmName][charInfo.playerName]["warTalents"]) then
        globalDb.data[charInfo.realmName][charInfo.playerName]["warTalents"] = {}
    end
    if (not globalDb.data[charInfo.realmName][charInfo.playerName]["troopShipments"]) then
        globalDb.data[charInfo.realmName][charInfo.playerName]["troopShipments"] = {}
    end

    self:InitHelper()
    self:InitEvent()

    self:InitTooltipLegacy()
    self:InitTooltipOrderhall()

    -- Assign functions
    debugPrint, pairsByKeys, formatRealmPlayer, tableSize = Garrison.debugPrint, Garrison.pairsByKeys, Garrison.formatRealmPlayer, Garrison.tableSize
    getColoredString, getColoredUnitName, formattedSeconds, getIconString = Garrison.getColoredString, Garrison.getColoredUnitName, Garrison.formattedSeconds, Garrison.getIconString
    tooltipFunctions = Garrison.tooltipFunctions

    colors = Garrison.colors

    self:SetupOptions()
    self:SetupAPI()

    Garrison:SetSinkStorage(configDb.notification.sink)

    Toast:Register(TOAST_MISSION_COMPLETE, toastMissionComplete)
    Toast:Register(TOAST_BUILDING_COMPLETE, toastBuildingComplete)
    Toast:Register(TOAST_SHIPMENT_COMPLETE, toastShipmentComplete)
    Toast:Register(TOAST_SUMMARY, toastSummary)

    self:RegisterEvent("GARRISON_MISSION_STARTED", "GARRISON_MISSION_STARTED")
    self:RegisterEvent("GARRISON_MISSION_COMPLETE_RESPONSE", "GARRISON_MISSION_COMPLETE_RESPONSE")
    self:RegisterEvent("GARRISON_MISSION_FINISHED", "GARRISON_MISSION_FINISHED")

    self:RegisterEvent("GARRISON_SHOW_LANDING_PAGE", "GARRISON_SHOW_LANDING_PAGE")
    self:RegisterEvent("GARRISON_MISSION_NPC_OPENED", "GARRISON_MISSION_NPC_OPENED")

    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "ZoneUpdate")
    self:RegisterEvent("ZONE_CHANGED", "ZoneUpdate")

    self:RegisterEvent("ADDON_LOADED", "CheckAddonLoaded")
    --self:RegisterEvent("VIGNETTE_REMOVED", "VignetteEvent")
    --self:RegisterEvent("VIGNETTE_ADDED", "VignetteEvent")
    self:RegisterEvent("SHOW_LOOT_TOAST", "LootToastEvent")
    self:RegisterEvent("CHAT_MSG_LOOT", "ChatLootEvent")

    -- disabled for now - need to figure out a better way to silence blizzard notifications
    --self:RawHook("GarrisonMissionAlertSystem", true);
    --self:RawHook("GarrisonBuildingAlertSystem", true);

    if configDb.notification.mission.hideBlizzardNotification then
        if AlertFrame ~= nil and AlertFrame:IsEventRegistered("GARRISON_MISSION_FINISHED") then
            debugPrint("Unregister GARRISON_MISSION_FINISHED")
            AlertFrame:UnregisterEvent("GARRISON_MISSION_FINISHED")
        end
    end

    if configDb.notification.building.hideBlizzardNotification then
        if AlertFrame ~= nil and AlertFrame:IsEventRegistered("GARRISON_BUILDING_ACTIVATABLE") then
            debugPrint("Unregister GARRISON_BUILDING_ACTIVATABLE")
            AlertFrame:UnregisterEvent("GARRISON_BUILDING_ACTIVATABLE")
        end
    end

    --self:RawHookScript(GarrisonShipMissionAlertSystem, "AddAlert", "MissionAlert", true)
    --self:RawHookScript(GarrisonMissionAlertSystem, "AddAlert", "MissionAlert", true)
    --self:RawHookScript(GarrisonBuildingAlertSystem, "AddAlert", "BuildingAlert", true)


    -- Order Halls
    self:RegisterEvent("GARRISON_TALENT_COMPLETE", "GARRISON_TALENT_COMPLETE");
    self:RegisterEvent("GARRISON_TALENT_UPDATE", "GARRISON_TALENT_UPDATE");
    self:RegisterEvent("GARRISON_FOLLOWER_CATEGORIES_UPDATED", "GARRISON_FOLLOWER_CATEGORIES_UPDATED");
    self:RegisterEvent("GARRISON_FOLLOWER_ADDED", "GARRISON_FOLLOWER_ADDED");
    self:RegisterEvent("GARRISON_FOLLOWER_REMOVED", "GARRISON_FOLLOWER_REMOVED");

    C_Garrison.RequestClassSpecCategoryInfo(LE_FOLLOWER_TYPE_GARRISON_7_0)

    self:RawHook("GarrisonMinimapBuilding_ShowPulse", true)
    self:RawHook("GarrisonMinimapShipmentCreated_ShowPulse", true)
    self:RawHook("GarrisonMinimapMission_ShowPulse", true)

    self:SecureHook(C_Garrison, "RecruitFollower", "RecruitFollower")

    timers.init_update = Garrison:ScheduleTimer("DelayedUpdate", 5)

    ldb_object_mission.icon = Garrison.ICON_PATH_MISSION
    ldb_object_building.icon = Garrison.ICON_PATH_BUILDING
    ldb_object_orderhall.icon = Garrison.ICON_PATH_CURRENCY_ORDER_RESOURCES

    if LDBIcon and configDb.minimap.load then
        LDBIcon:Register("BrokerGarrisonLDBMission", ldb_object_mission, configDb.minimap.mission)
        LDBIcon:Register("BrokerGarrisonLDBBuilding", ldb_object_building, configDb.minimap.building)
        LDBIcon:Register("BrokerGarrisonLDBOrderhall", ldb_object_orderhall, configDb.minimap.orderhall)
    else
        LDBIcon = nil
    end

    Garrison:UpdateConfig()

    -- collapse other characters (if option is enabled)
    for realmName, realmData in pairs(globalDb.data) do
        for playerName, playerData in pairs(realmData) do
            local isCurrentChar = Garrison.isCurrentChar(playerData.info)
            if configDb.general.building.collapseOtherCharsOnLogin then
                playerData.buildingsExpanded = isCurrentChar
            end
            if configDb.general.mission.collapseOtherCharsOnLogin then
                playerData.missionsExpanded = isCurrentChar
            end
            if configDb.general.mission.collapseOtherCharsOnLogin then
                playerData.orderhallExpanded = isCurrentChar
            end

            -- add sort order for players
            if not playerData.order then
                playerData.order = 5
            end
        end
    end
end

function Garrison:DelayedUpdate()
    Garrison:LoadDependencies()

    for questId, cacheSize in pairs(Garrison.cacheSizeQuestId) do
        if (_G.IsQuestFlaggedCompleted(questId)) then
            Garrison:SetCacheSize(cacheSize);
        end
    end

    delayedInit = true
    Garrison:UpdateCurrency()
    Garrison:UpdateLocation()

    --self:RegisterEvent("SHIPMENT_CRAFTER_CLOSED", "ShipmentUpdate")
    self:RegisterEvent("CURRENCY_DISPLAY_UPDATE", "UpdateCurrency")
end
