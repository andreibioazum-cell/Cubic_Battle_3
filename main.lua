-- main.lua для Cubic Battle 3 (только мобильная версия, без музыки)
-- Поддерживает: Lobby, Game, Shop, Credits, Settings
-- Сохранение: монеты, список купленных скинов, надетый скин, настройки звука

local lobby = require("lobby")
local game = require("game")
local controls = require("controls")
local shop = require("shop")
local credits = require("credits")
local settings = require("settings")

GameState = { current = "lobby" }

local lastTap = 0
local lastState = nil

-- ========== ЗВУКИ ==========
sfxOn = true

function toggleSfx()
    sfxOn = not sfxOn
end

function playButtonSound()
    if not sfxOn then return end
    local sound, err = love.audio.newSource("cartoon-button-click-sound.mp3", "static")
    if sound then
        sound:setVolume(0.5)
        sound:play()
    end
end

-- ========== СОХРАНЕНИЕ ==========
SAVE_DATA = { coins = 0, ownedSkins = {}, equippedSkin = "NONE", sfxOn = true }
local SAVE_FILE = "data.txt"

function SAVE_SAVE()
    local ownedStr = table.concat(SAVE_DATA.ownedSkins, ",")
    local content = tostring(SAVE_DATA.coins) .. "\n" ..
                    ownedStr .. "\n" ..
                    SAVE_DATA.equippedSkin .. "\n" ..
                    tostring(sfxOn and 1 or 0)
    local success, err = pcall(function()
        love.filesystem.write(SAVE_FILE, content)
    end)
    if success then
        print("Сохранено: coins=" .. SAVE_DATA.coins .. ", owned=" .. ownedStr .. ", equipped=" .. SAVE_DATA.equippedSkin)
    else
        print("Ошибка сохранения: " .. tostring(err))
    end
end

local function loadSave()
    local info = love.filesystem.getInfo(SAVE_FILE)
    if not info then
        print("Нет файла сохранения, используем значения по умолчанию")
        SAVE_DATA = { coins = 0, ownedSkins = {}, equippedSkin = "NONE" }
        sfxOn = true
        return
    end

    local data, err = love.filesystem.read(SAVE_FILE)
    if not data then
        print("Ошибка чтения сохранения: " .. tostring(err))
        SAVE_DATA = { coins = 0, ownedSkins = {}, equippedSkin = "NONE" }
        sfxOn = true
        return
    end

    local lines = {}
    for line in data:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end

    local coins = tonumber(lines[1]) or 0
    local ownedStr = lines[2] or ""
    local equippedSkin = lines[3] or "NONE"
    local sfxVal = tonumber(lines[4]) or 1

    local ownedSkins = {}
    if ownedStr ~= "" then
        for name in ownedStr:gmatch("[^,]+") do
            table.insert(ownedSkins, name)
        end
    end

    SAVE_DATA = {
        coins = coins,
        ownedSkins = ownedSkins,
        equippedSkin = equippedSkin
    }
    sfxOn = sfxVal == 1

    print("Загружено: coins=" .. coins .. ", owned=" .. ownedStr .. ", equipped=" .. equippedSkin)
end

-- ========== LOVE CALLBACKS ==========
function love.load()
    love.graphics.setDefaultFilter("linear", "linear")
    loadSave()
    controls.load()
end

function love.update(dt)
    if dt > 0.05 then dt = 0.05 end

    if GameState.current ~= lastState then
        print("Переход в состояние: " .. tostring(GameState.current))
        if GameState.current == "lobby" then
            if lobby.load then lobby.load() end
        elseif GameState.current == "game" then
            if game.load then game.load() end
        elseif GameState.current == "shop" then
            if shop.load then shop.load(SAVE_DATA) end
        elseif GameState.current == "credits" then
            if credits.load then credits.load() end
        elseif GameState.current == "settings" then
            if settings.load then settings.load() end
        end
        lastState = GameState.current
    end

    if GameState.current == "lobby" then
        lobby.update(dt)
    elseif GameState.current == "game" then
        controls.update(dt)
        game.update(dt)
    end
end

function love.draw()
    if GameState.current == "lobby" then
        lobby.draw()
    elseif GameState.current == "game" then
        game.draw()
        controls.draw()
    elseif GameState.current == "shop" then
        shop.draw(SAVE_DATA.coins)
    elseif GameState.current == "credits" then
        credits.draw()
    elseif GameState.current == "settings" then
        settings.draw()
    end
end

function love.resize(w, h)
    if lobby.resize then lobby.resize(w, h) end
    if game.resize  then game.resize(w, h)  end
    if shop.resize  then shop.resize()      end
    if credits.resize then credits.resize() end
    if settings.resize then settings.resize() end
    controls.resize()
end

-- ========== ТАЧ ==========
local function dispatch(fn, id, x, y)
    local s = GameState.current
    if s == "lobby" and lobby[fn] then
        lobby[fn](id, x, y)
    elseif s == "game" and game[fn] then
        game[fn](id, x, y)
    elseif s == "shop" and shop[fn] then
        if fn == "touchpressed" then
            local newCoins, changed = shop.touchpressed(id, x, y, SAVE_DATA.coins, SAVE_DATA)
            if changed then
                SAVE_SAVE()
            end
            if newCoins ~= SAVE_DATA.coins then
                SAVE_DATA.coins = newCoins
                SAVE_SAVE()
            end
        else
            shop[fn](id, x, y)
        end
    elseif s == "credits" and credits[fn] then
        credits[fn](id, x, y)
    elseif s == "settings" and settings[fn] then
        settings[fn](id, x, y)
    end
end

function love.touchpressed(id, x, y)
    local now = love.timer.getTime()
    if now - lastTap < 0.05 then return end
    lastTap = now

    if GameState.current == "game" then
        controls.touchpressed(id, x, y)
    end
    dispatch("touchpressed", id, x, y)
end

function love.touchmoved(id, x, y)
    if GameState.current == "game" then
        controls.touchmoved(id, x, y)
    end
    dispatch("touchmoved", id, x, y)
end

function love.touchreleased(id, x, y)
    if GameState.current == "game" then
        local shot, dx, dy = controls.touchreleased(id)
        if shot and game.spawnPlayerBullet then
            game.spawnPlayerBullet(dx, dy)
        end
    end
    dispatch("touchreleased", id, x, y)
end
