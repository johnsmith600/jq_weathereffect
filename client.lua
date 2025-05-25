-- File: jq_weathereffects.lua

local QBCore = exports['qb-core']:GetCoreObject()

-- Configuration options
local config = {
    weatherEffects = {
        RAIN = {
            tractionMin = 0.6,
            tractionMax = 0.6,
            notify = "Heavy rain detected: Significantly adjusting vehicle handling.",
            intensityScaling = true -- Enable scaling based on rain intensity
        },
        SNOW = {
            tractionMin = 0.5,
            tractionMax = 0.5,
            notify = "Heavy snow detected: Significantly adjusting vehicle handling.",
            intensityScaling = true -- Enable scaling based on snow intensity
        },
        FOG = {
            tractionMin = 0.8,
            tractionMax = 0.8,
            notify = "Dense fog detected: Adjusting vehicle handling.",
            intensityScaling = false
        }
    },
    resetWeather = {"CLEAR", "SUNNY"},
    checkInterval = 10000, -- Check every 10 seconds
    enableLogging = true, -- Enable or disable logging
    defaultTraction = {min = 1.0, max = 1.0}, -- Default traction values
    enableEffects = true, -- Toggle for enabling/disabling effects
    intensityMultiplier = 2.0 -- Multiplier for increasing intensity
}

-- Cache to store original handling values
local handlingCache = {}

-- Function to log messages
local function Log(message)
    if config.enableLogging then
        print("[jq_weathereffects] " .. message)
    end
end

-- Function to get and cache original handling values
local function CacheOriginalHandling(vehicle)
    if not handlingCache[vehicle] then
        handlingCache[vehicle] = {
            tractionMin = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMin'),
            tractionMax = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMax')
        }
        Log("Cached original handling for vehicle: " .. vehicle)
    end
end

-- Function to adjust car handling based on weather
local function AdjustCarHandling(weather)
    if not config.enableEffects then return end

    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if vehicle ~= 0 then
        CacheOriginalHandling(vehicle)
        local effect = config.weatherEffects[weather]
        if effect then
            local tractionMin = effect.tractionMin
            local tractionMax = effect.tractionMax

            -- Apply intensity scaling if enabled
            if effect.intensityScaling then
                local intensity = GetWeatherIntensity(weather) * config.intensityMultiplier
                tractionMin = tractionMin * intensity
                tractionMax = tractionMax * intensity
            end

            -- Apply configured traction values
            SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMin', tractionMin)
            SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMax', tractionMax)
            QBCore.Functions.Notify(effect.notify, "info")
            Log("Applied weather effect for " .. weather .. " on vehicle: " .. vehicle)
        elseif table.contains(config.resetWeather, weather) then
            -- Reset to cached original values
            local originalHandling = handlingCache[vehicle]
            if originalHandling then
                SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMin', originalHandling.tractionMin)
                SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMax', originalHandling.tractionMax)
                handlingCache[vehicle] = nil -- Clear cache after resetting
                QBCore.Functions.Notify("Weather effects reset to normal.", "info")
                Log("Reset handling for vehicle: " .. vehicle)
            end
        end
    end
end

-- Helper function to check if a table contains a value
function table.contains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

-- Function to get weather intensity
local function GetWeatherIntensity(weather)
    -- Simulate intensity based on weather type and time
    local intensity = 1.0 -- Default intensity
    local timeFactor = (os.time() % 100) / 100 -- Creates a cyclic pattern over time

    if weather == "RAIN" then
        intensity = 0.7 + (0.3 * timeFactor) -- Intensity varies between 0.7 and 1.0
    elseif weather == "SNOW" then
        intensity = 0.5 + (0.3 * timeFactor) -- Intensity varies between 0.5 and 0.8
    elseif weather == "FOG" then
        intensity = 0.8 + (0.2 * timeFactor) -- Intensity varies between 0.8 and 1.0
    end

    return intensity
end

-- Command to toggle weather effects
RegisterCommand('toggleWeatherEffects', function()
    config.enableEffects = not config.enableEffects
    QBCore.Functions.Notify("Weather effects " .. (config.enableEffects and "enabled" or "disabled"), "info")
    Log("Weather effects " .. (config.enableEffects and "enabled" or "disabled"))
end, false)

GetWeatherIntensity()

-- Main loop to check weather and apply effects
CreateThread(function()
    while true do
        local weather = GetWeatherTypeTransition()
        
        -- Adjust car handling based on weather
        AdjustCarHandling(weather)

        -- Wait for the configured interval before checking again
        Wait(config.checkInterval)
    end
end)
