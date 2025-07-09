if not lib.checkDependency('ox_lib', '3.30.0', true) then return end

local QBCore = exports['qb-core']:GetCoreObject()
local UseTarget = GetConvar('UseTarget', 'false') == 'true'
local InApartment = false
local ClosestHouse = nil
local CurrentApartment = nil
local IsOwned = false
local CurrentDoorBell = 0
local CurrentOffset = 0
local HouseObj = {}
local POIOffsets = nil
local RangDoorbell = nil

-- target variables
local InApartmentTargets = {}

-- polyzone variables
local IsInsideEntranceZone = false
local IsInsideExitZone = false
local IsInsideStashZone = false
local IsInsideOutfitsZone = false
local IsInsideLogoutZone = false

-- ox_inventory compatibility
local ox_inventory = nil

if GetResourceState('ox_inventory') == 'started' then
    ox_inventory = exports.ox_inventory
end

-- polyzone integration

local function OpenEntranceMenu()
    local menuOptions = {}
    if IsOwned then
        menuOptions[#menuOptions + 1] = {
            title = Lang:t('text.enter'),
            icon = 'fa-solid fa-building-user',
            iconColor = 'white',
            event = 'apartments:client:EnterApartment',
            args = {}
        }
    elseif not IsOwned then
        menuOptions[#menuOptions + 1] = {
            title = Lang:t('text.move_here'),
            icon = 'fa-solid fa-building',
            iconColor = 'white',
            event = 'apartments:client:UpdateApartment',
            args = {}
        }
    end

    menuOptions[#menuOptions + 1] = {
        title = Lang:t('text.ring_doorbell'),
        icon = 'fa-solid fa-bell',
        iconColor = 'white',
        arrow = true,
        event = 'apartments:client:DoorbellMenu',
        args = {}
    }

    lib.registerContext({
        id = 'entrance_menu',
        title = 'Apartment Entrance',
        canClose = true,
        position = 'offcenter-right', -- Lation UI
        options = menuOptions
    })

    lib.showContext('entrance_menu')
end

local function OpenExitMenu()
    lib.registerContext({
        id = 'exit_menu',
        title = 'Apartment Exit',
        canClose = true,
        position = 'offcenter-right', -- Lation UI
        options = {
            {
                title = Lang:t('text.open_door'),
                icon = 'fa-solid fa-door-open',
                iconColor = 'white',
                event = 'apartments:client:OpenDoor',
                args = {}
            },
            {
                title = Lang:t('text.leave'),
                icon = 'fa-solid fa-right-from-bracket',
                iconColor = 'white',
                event = 'apartments:client:LeaveApartment',
                args = {}
            }
        }
    })

    lib.showContext('exit_menu')
end

-- exterior entrance (polyzone)

local function RegisterApartmentEntranceZone(apartmentID, apartmentData)
    local coords = apartmentData.coords['enter']
    local boxName = 'apartmentEntrance_' .. apartmentID
    local boxData = apartmentData.polyzoneBoxData

    if boxData.created then
        return
    end

    local zone = BoxZone:Create(coords, boxData.length, boxData.width, {
        name = boxName,
        heading = 340.0,
        minZ = coords.z - 1.0,
        maxZ = coords.z + 5.0,
        debugPoly = false
    })

    zone:onPlayerInOut(function(isPointInside)
        if isPointInside and not InApartment then
            if Apartments.DrawText == 'qb' then
                exports['qb-core']:DrawText(Lang:t('text.options'), 'left')
            elseif Apartments.DrawText == 'ox' then
                lib.showTextUI(Lang:t('text.options'), { position = 'left-center' })
            elseif Apartments.DrawText == 'jg' then
                exports['jg-textui']:DrawText(Lang:t('text.options'))
            end
        else
            if Apartments.DrawText == 'qb' then
                exports['qb-core']:HideText()
            elseif Apartments.DrawText == 'ox' then
                lib.hideTextUI()
            elseif Apartments.DrawText == 'jg' then
                exports['jg-textui']:HideText()
            end
        end
        IsInsideEntranceZone = isPointInside
    end)

    boxData.created = true
    boxData.zone = zone
end

-- exterior entrance (target)

local function RegisterApartmentEntranceTarget(apartmentID, apartmentData)
    local coords = apartmentData.coords['enter']
    local boxName = 'apartmentEntrance_' .. apartmentID
    local boxData = apartmentData.polyzoneBoxData

    if boxData.created then
        return
    end

    local options = {}
    if apartmentID == ClosestHouse and IsOwned then
        options = {
            {
                type = 'client',
                event = 'apartments:client:EnterApartment',
                icon = 'fa-solid fa-building-user',
                label = Lang:t('text.enter'),
            },
        }
    else
        options = {
            {
                type = 'client',
                event = 'apartments:client:UpdateApartment',
                icon = 'fa-solid fa-building',
                label = Lang:t('text.move_here'),
            }
        }
    end
    options[#options + 1] = {
        type = 'client',
        event = 'apartments:client:DoorbellMenu',
        icon = 'fa-solid fa-bell',
        label = Lang:t('text.ring_doorbell'),
    }

    exports['qb-target']:AddBoxZone(boxName, coords, boxData.length, boxData.width, {
        name = boxName,
        heading = boxData.heading,
        debugPoly = boxData.debug,
        minZ = boxData.minZ,
        maxZ = boxData.maxZ,
    }, {
        options = options,
        distance = boxData.distance
    })

    boxData.created = true
end

-- interior interactable points (polyzone)

local function RegisterInApartmentZone(targetKey, coords, heading, text)
    if not InApartment then
        return
    end

    if InApartmentTargets[targetKey] and InApartmentTargets[targetKey].created then
        return
    end

    Wait(1500)

    local boxName = 'inApartmentTarget_' .. targetKey

    local zone = BoxZone:Create(coords, 1.5, 1.5, {
        name = boxName,
        heading = heading,
        minZ = coords.z - 1.0,
        maxZ = coords.z + 5.0,
        debugPoly = false
    })

    zone:onPlayerInOut(function(isPointInside)
        if isPointInside and text then
            if Apartments.DrawText == 'qb' then
                exports['qb-core']:DrawText(text, 'left')
            elseif Apartments.DrawText == 'ox' then
                lib.showTextUI(text, { position = 'left-center' })
            elseif Apartments.DrawText == 'jg' then
                exports['jg-textui']:DrawText(text)
            end
        else
            if Apartments.DrawText == 'qb' then
                exports['qb-core']:HideText()
            elseif Apartments.DrawText == 'ox' then
                lib.hideTextUI()
            elseif Apartments.DrawText == 'jg' then
                exports['jg-textui']:HideText()
            end
        end

        if targetKey == 'entrancePos' then
            IsInsideExitZone = isPointInside
        end

        if targetKey == 'stashPos' then
            IsInsideStashZone = isPointInside
        end

        if targetKey == 'outfitsPos' then
            IsInsideOutfitsZone = isPointInside
        end

        if targetKey == 'logoutPos' then
            IsInsideLogoutZone = isPointInside
        end
    end)

    InApartmentTargets[targetKey] = InApartmentTargets[targetKey] or {}
    InApartmentTargets[targetKey].created = true
    InApartmentTargets[targetKey].zone = zone
end

-- interior interactable points (target)

local function RegisterInApartmentTarget(targetKey, coords, heading, options)
    if not InApartment then
        return
    end

    if InApartmentTargets[targetKey] and InApartmentTargets[targetKey].created then
        return
    end

    local boxName = 'inApartmentTarget_' .. targetKey
    exports['qb-target']:AddBoxZone(boxName, coords, 1.5, 1.5, {
        name = boxName,
        heading = heading,
        minZ = coords.z - 1.0,
        maxZ = coords.z + 5.0,
        debugPoly = false,
    }, {
        options = options,
        distance = 1
    })

    InApartmentTargets[targetKey] = InApartmentTargets[targetKey] or {}
    InApartmentTargets[targetKey].created = true
end

-- shared

local function SetApartmentsEntranceTargets()
    if Apartments.Locations and next(Apartments.Locations) then
        for id, apartment in pairs(Apartments.Locations) do
            if apartment and apartment.coords and apartment.coords['enter'] then
                if UseTarget then
                    RegisterApartmentEntranceTarget(id, apartment)
                else
                    RegisterApartmentEntranceZone(id, apartment)
                end
            end
        end
    end
end

local function SetInApartmentTargets()
    if not POIOffsets then
        -- do nothing
        return
    end

    local entrancePos = vector3(Apartments.Locations[ClosestHouse].coords.enter.x + POIOffsets.exit.x, Apartments.Locations[ClosestHouse].coords.enter.y + POIOffsets.exit.y, Apartments.Locations[ClosestHouse].coords.enter.z - CurrentOffset + POIOffsets.exit.z)
    local stashPos = vector3(Apartments.Locations[ClosestHouse].coords.enter.x - POIOffsets.stash.x, Apartments.Locations[ClosestHouse].coords.enter.y - POIOffsets.stash.y, Apartments.Locations[ClosestHouse].coords.enter.z - CurrentOffset + POIOffsets.stash.z)
    local outfitsPos = vector3(Apartments.Locations[ClosestHouse].coords.enter.x - POIOffsets.clothes.x, Apartments.Locations[ClosestHouse].coords.enter.y - POIOffsets.clothes.y, Apartments.Locations[ClosestHouse].coords.enter.z - CurrentOffset + POIOffsets.clothes.z)
    local logoutPos = vector3(Apartments.Locations[ClosestHouse].coords.enter.x - POIOffsets.logout.x, Apartments.Locations[ClosestHouse].coords.enter.y + POIOffsets.logout.y, Apartments.Locations[ClosestHouse].coords.enter.z - CurrentOffset + POIOffsets.logout.z)

    if UseTarget then
        RegisterInApartmentTarget('entrancePos', entrancePos, 0, {
            {
                type = 'client',
                event = 'apartments:client:OpenDoor',
                icon = 'fa-solid fa-door-open',
                label = Lang:t('text.open_door'),
            },
            {
                type = 'client',
                event = 'apartments:client:LeaveApartment',
                icon = 'fa-solid fa-right-from-bracket',
                label = Lang:t('text.leave'),
            },
        })
        RegisterInApartmentTarget('stashPos', stashPos, 0, {
            {
                type = 'client',
                event = 'apartments:client:OpenStash',
                icon = 'fas fa-box-open',
                label = Lang:t('text.open_stash'),
            },
        })
        RegisterInApartmentTarget('outfitsPos', outfitsPos, 0, {
            {
                type = 'client',
                event = 'apartments:client:ChangeOutfit',
                icon = 'fas fa-tshirt',
                label = Lang:t('text.change_outfit'),
            },
        })
        RegisterInApartmentTarget('logoutPos', logoutPos, 0, {
            {
                type = 'client',
                event = 'apartments:client:Logout',
                icon = 'fas fa-sign-out-alt',
                label = Lang:t('text.logout'),
            },
        })
    else
        RegisterInApartmentZone('stashPos', stashPos, 0, '[E] ' .. Lang:t('text.open_stash'))
        RegisterInApartmentZone('outfitsPos', outfitsPos, 0, '[E] ' .. Lang:t('text.change_outfit'))
        RegisterInApartmentZone('logoutPos', logoutPos, 0, '[E] ' .. Lang:t('text.logout'))
        RegisterInApartmentZone('entrancePos', entrancePos, 0, Lang:t('text.options'))
    end
end

local function DeleteApartmentsEntranceTargets()
    if Apartments.Locations and next(Apartments.Locations) then
        for id, apartment in pairs(Apartments.Locations) do
            if UseTarget then
                exports['qb-target']:RemoveZone('apartmentEntrance_' .. id)
            else
                if apartment.polyzoneBoxData.zone then
                    apartment.polyzoneBoxData.zone:destroy()
                    apartment.polyzoneBoxData.zone = nil
                end
            end
            apartment.polyzoneBoxData.created = false
        end
    end
end

local function DeleteInApartmentTargets()
    IsInsideExitZone = false
    IsInsideStashZone = false
    IsInsideOutfitsZone = false
    IsInsideLogoutZone = false

    if InApartmentTargets and next(InApartmentTargets) then
        for id, apartmentTarget in pairs(InApartmentTargets) do
            if UseTarget then
                exports['qb-target']:RemoveZone('inApartmentTarget_' .. id)
            else
                if apartmentTarget.zone then
                    apartmentTarget.zone:destroy()
                    apartmentTarget.zone = nil
                end
            end
        end
    end
    InApartmentTargets = {}
end

-- utility functions

local function loadAnimDict(dict)
    while (not HasAnimDictLoaded(dict)) do
        RequestAnimDict(dict)
        Wait(5)
    end
end

local function openHouseAnim()
    loadAnimDict('anim@heists@keycard@')
    TaskPlayAnim(PlayerPedId(), 'anim@heists@keycard@', 'exit', 5.0, 1.0, -1, 16, 0, 0, 0, 0)
    Wait(400)
    ClearPedTasks(PlayerPedId())
end

local function EnterApartment(house, apartmentId, new)
    TriggerServerEvent('InteractSound_SV:PlayOnSource', 'houses_door_open', 0.1)
    openHouseAnim()
    Wait(250)
    QBCore.Functions.TriggerCallback('apartments:GetApartmentOffset', function(offset)
        if offset == nil or offset == 0 then
            QBCore.Functions.TriggerCallback('apartments:GetApartmentOffsetNewOffset', function(newoffset)
                if newoffset > 230 then
                    newoffset = 210
                end
                CurrentOffset = newoffset
                TriggerServerEvent('apartments:server:AddObject', apartmentId, house, CurrentOffset)
                local coords = { x = Apartments.Locations[house].coords.enter.x, y = Apartments.Locations[house].coords.enter.y, z = Apartments.Locations[house].coords.enter.z - CurrentOffset }
                local data = exports['qb-interior']:CreateApartmentFurnished(coords)
                Wait(100)
                HouseObj = data[1]
                POIOffsets = data[2]
                InApartment = true
                CurrentApartment = apartmentId
                ClosestHouse = house
                RangDoorbell = nil
                Wait(500)
                TriggerEvent('qb-weathersync:client:DisableSync')
                Wait(100)
                TriggerServerEvent('qb-apartments:server:SetInsideMeta', house, apartmentId, true, false)
                TriggerServerEvent('InteractSound_SV:PlayOnSource', 'houses_door_close', 0.1)
                TriggerServerEvent('apartments:server:setCurrentApartment', CurrentApartment)
            end, house)
        else
            if offset > 230 then
                offset = 210
            end
            CurrentOffset = offset
            TriggerServerEvent('InteractSound_SV:PlayOnSource', 'houses_door_open', 0.1)
            TriggerServerEvent('apartments:server:AddObject', apartmentId, house, CurrentOffset)
            local coords = { x = Apartments.Locations[ClosestHouse].coords.enter.x, y = Apartments.Locations[ClosestHouse].coords.enter.y, z = Apartments.Locations[ClosestHouse].coords.enter.z - CurrentOffset }
            local data = exports['qb-interior']:CreateApartmentFurnished(coords)
            Wait(100)
            HouseObj = data[1]
            POIOffsets = data[2]
            InApartment = true
            CurrentApartment = apartmentId
            Wait(500)
            TriggerEvent('qb-weathersync:client:DisableSync')
            Wait(100)
            TriggerServerEvent('qb-apartments:server:SetInsideMeta', house, apartmentId, true, true)
            TriggerServerEvent('InteractSound_SV:PlayOnSource', 'houses_door_close', 0.1)
            TriggerServerEvent('apartments:server:setCurrentApartment', CurrentApartment)
        end

        if new ~= nil then
            if new then
                TriggerEvent('qb-interior:client:SetNewState', true)
            else
                TriggerEvent('qb-interior:client:SetNewState', false)
            end
        else
            TriggerEvent('qb-interior:client:SetNewState', false)
        end
    end, apartmentId)
end

local function LeaveApartment(house)
    TriggerServerEvent('InteractSound_SV:PlayOnSource', 'houses_door_open', 0.1)
    openHouseAnim()
    TriggerServerEvent('qb-apartments:returnBucket')
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(10) end
    exports['qb-interior']:DespawnInterior(HouseObj, function()
        TriggerEvent('qb-weathersync:client:EnableSync')
        SetEntityCoords(PlayerPedId(), Apartments.Locations[house].coords.enter.x, Apartments.Locations[house].coords.enter.y, Apartments.Locations[house].coords.enter.z)
        SetEntityHeading(PlayerPedId(), Apartments.Locations[house].coords.enter.w)
        Wait(1000)
        TriggerServerEvent('apartments:server:RemoveObject', CurrentApartment, house)
        TriggerServerEvent('qb-apartments:server:SetInsideMeta', CurrentApartment, false)
        CurrentApartment = nil
        InApartment = false
        CurrentOffset = 0
        DoScreenFadeIn(1000)
        TriggerServerEvent('InteractSound_SV:PlayOnSource', 'houses_door_close', 0.1)
        TriggerServerEvent('apartments:server:setCurrentApartment', nil)

        DeleteInApartmentTargets()
        DeleteApartmentsEntranceTargets()
    end)
end

local function SetClosestApartment()
    local pos = GetEntityCoords(PlayerPedId())
    local current = nil
    local dist = 100
    for id, _ in pairs(Apartments.Locations) do
        local distcheck = #(pos - vector3(Apartments.Locations[id].coords.enter.x, Apartments.Locations[id].coords.enter.y, Apartments.Locations[id].coords.enter.z))
        if distcheck < dist then
            current = id
        end
    end
    if current ~= ClosestHouse and LocalPlayer.state.isLoggedIn and not InApartment then
        ClosestHouse = current
        QBCore.Functions.TriggerCallback('apartments:IsOwner', function(result)
            IsOwned = result
            DeleteApartmentsEntranceTargets()
            DeleteInApartmentTargets()
        end, ClosestHouse)
    end
end

function MenuOwners()
    QBCore.Functions.TriggerCallback('apartments:GetAvailableApartments', function(apartments)
        if next(apartments) == nil then
            if Apartments.Notify == 'qb' then
                QBCore.Functions.Notify(Lang:t('error.nobody_home'), 'error', 3500)
            elseif Apartments.Notify == 'ox' then
                lib.notify({
                    title = 'Nobody Home',
                    description = Lang:t('error.nobody_home'),
                    duration = 3500,
                    position = 'center-right',
                    type = 'error'
                })
            end
            CloseMenuFull()
        else
            local menuOptions = {}
            for k, v in pairs(apartments) do
                menuOptions[#menuOptions + 1] = {
                    title = v,
                    icon = 'fa-solid fa-user',
                    iconColor = 'white',
                    description = '',
                    event = 'apartments:client:RingMenu',
                    args = {
                        apartmentId = k
                    }
                }
            end

            lib.registerContext({
                id = 'owners_menu',
                title = Lang:t('text.tennants'),
                canClose = true,
                options = menuOptions
            })

            lib.showContext('owners_menu')
        end
    end, ClosestHouse)
end

function CloseMenuFull()
    lib.hideContext()
end

-- Event Handlers

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        if HouseObj ~= nil then
            exports['qb-interior']:DespawnInterior(HouseObj, function()
                CurrentApartment = nil
                TriggerEvent('qb-weathersync:client:EnableSync')
                DoScreenFadeIn(500)
                while not IsScreenFadedOut() do
                    Wait(10)
                end
                SetEntityCoords(PlayerPedId(), Apartments.Locations[ClosestHouse].coords.enter.x, Apartments.Locations[ClosestHouse].coords.enter.y, Apartments.Locations[ClosestHouse].coords.enter.z)
                SetEntityHeading(PlayerPedId(), Apartments.Locations[ClosestHouse].coords.enter.w)
                Wait(1000)
                InApartment = false
                DoScreenFadeIn(1000)
            end)
        end

        DeleteApartmentsEntranceTargets()
        DeleteInApartmentTargets()
    end
end)

-- Events

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    CurrentApartment = nil
    InApartment = false
    CurrentOffset = 0

    DeleteApartmentsEntranceTargets()
    DeleteInApartmentTargets()
end)

RegisterNetEvent('apartments:client:setupSpawnUI', function(cData)
    QBCore.Functions.TriggerCallback('apartments:GetOwnedApartment', function(result)
        if result then
            TriggerEvent('qb-spawn:client:setupSpawns', cData, false, nil)
            TriggerEvent('qb-spawn:client:openUI', true)
            TriggerEvent('apartments:client:SetHomeBlip', result.type)
        else
            if Apartments.Starting then
                TriggerEvent('qb-spawn:client:setupSpawns', cData, true, Apartments.Locations)
                TriggerEvent('qb-spawn:client:openUI', true)
            else
                TriggerEvent('qb-spawn:client:setupSpawns', cData, false, nil)
                TriggerEvent('qb-spawn:client:openUI', true)
                TriggerEvent('apartments:client:SetHomeBlip', nil)
            end
        end
    end, cData.citizenid)
end)

RegisterNetEvent('apartments:client:SpawnInApartment', function(apartmentId, apartment)
    local pos = GetEntityCoords(PlayerPedId())
    if RangDoorbell ~= nil then
        local doorbelldist = #(pos - vector3(Apartments.Locations[RangDoorbell].coords.enter.x, Apartments.Locations[RangDoorbell].coords.enter.y, Apartments.Locations[RangDoorbell].coords.enter.z))
        if doorbelldist > 5 then
            if Apartments.Notify == 'qb' then
                QBCore.Functions.Notify(Lang:t('error.to_far_from_door'))
            elseif Apartments.Notify == 'ox' then
                lib.notify({
                    title = 'Too Far Away',
                    description = Lang:t('error.to_far_from_door'),
                    position = 'center-right',
                    type = 'error'
                })
            end
            return
        end
    end
    ClosestHouse = apartment
    EnterApartment(apartment, apartmentId, true)
    IsOwned = true
end)

RegisterNetEvent('qb-apartments:client:LastLocationHouse', function(apartmentType, apartmentId)
    ClosestHouse = apartmentType
    EnterApartment(apartmentType, apartmentId, false)
end)

RegisterNetEvent('apartments:client:SetHomeBlip', function(home)
    CreateThread(function()
        SetClosestApartment()
        for name, _ in pairs(Apartments.Locations) do
            RemoveBlip(Apartments.Locations[name].blip)

            Apartments.Locations[name].blip = AddBlipForCoord(Apartments.Locations[name].coords.enter.x, Apartments.Locations[name].coords.enter.y, Apartments.Locations[name].coords.enter.z)
            if (name == home) then
                SetBlipSprite(Apartments.Locations[name].blip, 475)
                SetBlipCategory(Apartments.Locations[name].blip, 11)
            else
                SetBlipSprite(Apartments.Locations[name].blip, 476)
                SetBlipCategory(Apartments.Locations[name].blip, 10)
            end
            SetBlipDisplay(Apartments.Locations[name].blip, 4)
            SetBlipScale(Apartments.Locations[name].blip, 0.65)
            SetBlipAsShortRange(Apartments.Locations[name].blip, true)
            SetBlipColour(Apartments.Locations[name].blip, 3)
            AddTextEntry(Apartments.Locations[name].label, Apartments.Locations[name].label)
            BeginTextCommandSetBlipName(Apartments.Locations[name].label)
            EndTextCommandSetBlipName(Apartments.Locations[name].blip)
        end
    end)
end)

RegisterNetEvent('apartments:client:RingMenu', function(data)
    RangDoorbell = ClosestHouse
    TriggerServerEvent('InteractSound_SV:PlayOnSource', 'doorbell', 0.1)
    TriggerServerEvent('apartments:server:RingDoor', data.apartmentId, ClosestHouse)
end)

RegisterNetEvent('apartments:client:RingDoor', function(player, _)
    CurrentDoorBell = player
    TriggerServerEvent('InteractSound_SV:PlayOnSource', 'doorbell', 0.1)
    if Apartments.Notify == 'qb' then
        QBCore.Functions.Notify(Lang:t('info.at_the_door'))
    elseif Apartments.Notify == 'ox' then
        lib.notify({
            title = 'Doorbell',
            description = Lang:t('info.at_the_door'),
            position = 'center-right',
            type = 'inform'
        })
    end
end)

RegisterNetEvent('apartments:client:DoorbellMenu', function()
    MenuOwners()
end)

RegisterNetEvent('apartments:client:EnterApartment', function()
    QBCore.Functions.TriggerCallback('apartments:GetOwnedApartment', function(result)
        if result ~= nil then
            EnterApartment(ClosestHouse, result.name)
        end
    end)
end)

RegisterNetEvent('apartments:client:UpdateApartment', function()
    local apartmentType = ClosestHouse
    local apartmentLabel = Apartments.Locations[ClosestHouse].label
    QBCore.Functions.TriggerCallback('apartments:GetOwnedApartment', function(result)
        if result == nil then
            TriggerServerEvent("apartments:server:CreateApartment", apartmentType, apartmentLabel, false)
        else
            TriggerServerEvent('apartments:server:UpdateApartment', apartmentType, apartmentLabel)
        end
    end)

    IsOwned = true

    DeleteApartmentsEntranceTargets()
    DeleteInApartmentTargets()
end)

RegisterNetEvent('apartments:client:OpenDoor', function()
    if CurrentDoorBell == 0 then
        if Apartments.Notify == 'qb' then
            QBCore.Functions.Notify(Lang:t('error.nobody_at_door'))
        elseif Apartments.Notify == 'ox' then
            lib.notify({
                title = 'Nobody Home',
                description = Lang:t('error.nobody_at_door'),
                position = 'center-right',
                type = 'error'
            })
        end
        return
    end
    TriggerServerEvent('apartments:server:OpenDoor', CurrentDoorBell, CurrentApartment, ClosestHouse)
    CurrentDoorBell = 0
end)

RegisterNetEvent('apartments:client:LeaveApartment', function()
    LeaveApartment(ClosestHouse)
end)

RegisterNetEvent('apartments:client:OpenStash', function()
    if CurrentApartment then
        TriggerServerEvent('InteractSound_SV:PlayOnSource', 'StashOpen', 0.4)
        if not ox_inventory then
            TriggerServerEvent('apartments:server:openStash', CurrentApartment)
        else
            if not ox_inventory:openInventory('stash', CurrentApartment) then
                TriggerServerEvent('qb-apartments:server:RegisterStash', CurrentApartment, Apartments.Locations[ClosestHouse].label)
                ox_inventory:openInventory('stash', CurrentApartment)
            end
        end
    end
end)

RegisterNetEvent('apartments:client:ChangeOutfit', function()
    TriggerServerEvent('InteractSound_SV:PlayOnSource', 'Clothes1', 0.4)
    TriggerEvent('qb-clothing:client:openOutfitMenu')
end)

RegisterNetEvent('apartments:client:Logout', function()
    TriggerServerEvent('qb-houses:server:LogoutLocation')
end)

-- Threads

if UseTarget then
    CreateThread(function()
        local sleep = 5000
        while not LocalPlayer.state.isLoggedIn do
            -- do nothing
            Wait(sleep)
        end

        while true do
            sleep = 1000

            if not InApartment then
                SetClosestApartment()
                SetApartmentsEntranceTargets()
            elseif InApartment then
                SetInApartmentTargets()
            end
            Wait(sleep)
        end
    end)
else
    CreateThread(function()
        local sleep = 5000
        while not LocalPlayer.state.isLoggedIn do
            -- do nothing
            Wait(sleep)
        end

        while true do
            sleep = 1000

            if not InApartment then
                SetClosestApartment()
                SetApartmentsEntranceTargets()

                if IsInsideEntranceZone then
                    sleep = 0
                    if IsControlJustPressed(0, 38) then
                        OpenEntranceMenu()
                        if Apartments.DrawText == 'qb' then
                            exports['qb-core']:HideText()
                        elseif Apartments.DrawText == 'ox' then
                            lib.hideTextUI()
                        elseif Apartments.DrawText == 'jg' then
                            exports['jg-textui']:HideText()
                        end
                    end
                end
            elseif InApartment then
                sleep = 0

                SetInApartmentTargets()

                if IsInsideExitZone then
                    if IsControlJustPressed(0, 38) then
                        OpenExitMenu()
                        if Apartments.DrawText == 'qb' then
                            exports['qb-core']:HideText()
                        elseif Apartments.DrawText == 'ox' then
                            lib.hideTextUI()
                        elseif Apartments.DrawText == 'jg' then
                            exports['jg-textui']:HideText()
                        end
                    end
                end

                if IsInsideStashZone then
                    if IsControlJustPressed(0, 38) then
                        TriggerEvent('apartments:client:OpenStash')
                        if Apartments.DrawText == 'qb' then
                            exports['qb-core']:HideText()
                        elseif Apartments.DrawText == 'ox' then
                            lib.hideTextUI()
                        elseif Apartments.DrawText == 'jg' then
                            exports['jg-textui']:HideText()
                        end
                    end
                end

                if IsInsideOutfitsZone then
                    if IsControlJustPressed(0, 38) then
                        TriggerEvent('apartments:client:ChangeOutfit')
                        if Apartments.DrawText == 'qb' then
                            exports['qb-core']:HideText()
                        elseif Apartments.DrawText == 'ox' then
                            lib.hideTextUI()
                        elseif Apartments.DrawText == 'jg' then
                            exports['jg-textui']:HideText()
                        end
                    end
                end

                if IsInsideLogoutZone then
                    if IsControlJustPressed(0, 38) then
                        TriggerEvent('apartments:client:Logout')
                        if Apartments.DrawText == 'qb' then
                            exports['qb-core']:HideText()
                        elseif Apartments.DrawText == 'ox' then
                            lib.hideTextUI()
                        elseif Apartments.DrawText == 'jg' then
                            exports['jg-textui']:HideText()
                        end
                    end
                end
            end

            Wait(sleep)
        end
    end)
end