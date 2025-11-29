script_name("Flux")
script_author("rmux")
script_version("1.3.0")
script_dependencies("SAMP")

require "lib.moonloader"
local sampev = require 'lib.samp.events'
local key = require('vkeys')
local imgui = require 'imgui'
local encoding = require 'encoding'
local memory = require 'memory'
local ffi = require 'ffi'

encoding.default = 'CP1251'
local u8 = encoding.UTF8

-- ===============================================================================
-- [FFI DEFINITIONS]
-- ===============================================================================
local getBonePosition = ffi.cast("int (__thiscall*)(void*, float*, int, bool)", 0x5E4280)
local bonePosVec = ffi.new("float[3]") -- Buffer for bone coordinates to avoid GC overhead

-- ===============================================================================
-- [CONFIGURATION & CONSTANTS]
-- ===============================================================================
local CONSTANTS = {
    MIN_DRIFT_SPEED = 5.0,
    SPEED_CALIBRATION = 0.847,
    HIGH_SPEED_THRESHOLD = 150.0,
    GROUND_STICK_FORCE = 0.15,
    LOG_FILE = "moonloader/Flux_log.txt",
    CONFIG_FILE = "moonloader/Flux_keybinds.cfg"
}

-- ===============================================================================
-- [STATE MANAGEMENT]
-- ===============================================================================
local Features = {
    Global = {
        scriptEnabled = true,
        reconnectDelay = 5,
        activeTab = 1
    },
    Weapon = {
        spread = false,
        norl = false,
        instantCrosshair = false,
        patch_showCrosshairInstantly = nil
    },
    Visual = {
        espEnabled = false,
        linesEnabled = false,
        skeletonEnabled = false, -- Added Skeleton
        infoBarEnabled = false,
        boxThickness = 0.005,
        fovEnabled = false,
        fovRadius = 100
    },
    Car = {
        driftMode = false,
        driftType = "toggle",
        accelMode = false,
        targetSpeed = 0,
        currentTargetSpeed = 0,
        speedIncrement = 10,
        damageMult = 1.0,
        groundStick = true,
        gmCar = false,
        gmWheels = false,
        antiBoom = false,
        waterDrive = false,
        fireCar = false,
        fixWheels = false,
        lastHP = 1000,
        justGotInCar = true,
        shiftPressed = false
    },
    Misc = {
        antiStun = false,
        fakeAfk = false,
        fakeLag = false,
        noFall = false,
        oxygen = false,
        megaJump = false,
        bmxMegaJump = false,
        godMode = false,
        noBikeFall = false,
        quickStop = false
    }
}

-- ImGui Buffers
local UI_Buffers = {
    mainWindow = imgui.ImBool(false),
    damageMult = imgui.ImFloat(1.0),
    targetSpeed = imgui.ImInt(0),
    driftType = imgui.ImInt(1),
    boxThickness = imgui.ImFloat(0.005),
    infoBar = imgui.ImBool(false),
    speedIncrement = imgui.ImInt(10),
    antiBoom = imgui.ImBool(false),
    quickStop = imgui.ImBool(false),
    gmWheels = imgui.ImBool(false),
    groundStick = imgui.ImBool(true),
    noFall = imgui.ImBool(false),
    oxygen = imgui.ImBool(false),
    megaJump = imgui.ImBool(false),
    bmxMegaJump = imgui.ImBool(false),
    godMode = imgui.ImBool(false),
    reconnectDelay = imgui.ImInt(5)
}

-- ===============================================================================
-- [KEYBINDS]
-- ===============================================================================
local font_info = renderCreateFont("Arial", 9, 5)

local keybinds = {
    menu_toggle = VK_U,
    esp_toggle = VK_F4,
    lines_toggle = VK_F5,
    drift_toggle = VK_LSHIFT,
    speed_boost = VK_LCONTROL,
    speed_increase = VK_P,
    speed_decrease = VK_L,
    speed_toggle = VK_O,
    antistun_toggle = VK_F3,
    fakeafk_toggle = VK_F6,
    fakelag_toggle = VK_F7,
    nospread_toggle = VK_F8,
    godmode_toggle = VK_F9,
    waterdrive_toggle = VK_F10,
    firecar_toggle = VK_F11,
    instant_crosshair_toggle = VK_F12,
    noreload_toggle = VK_F2,
    reconnect_key = VK_0
}

local keybind_names = {
    menu_toggle = "Menu Toggle", esp_toggle = "ESP Toggle", lines_toggle = "Lines Toggle",
    drift_toggle = "Drift Key", speed_boost = "Speed Boost", speed_increase = "Speed Increase",
    speed_decrease = "Speed Decrease", speed_toggle = "Speed Control Toggle",
    antistun_toggle = "AntiStun Toggle", fakeafk_toggle = "FakeAFK Toggle",
    fakelag_toggle = "FakeLag Toggle", nospread_toggle = "NoSpread Toggle",
    godmode_toggle = "GodMode Toggle", waterdrive_toggle = "WaterDrive Toggle",
    firecar_toggle = "FireCar Toggle", instant_crosshair_toggle = "Instant Crosshair Toggle",
    noreload_toggle = "NoReload Toggle", reconnect_key = "Reconnect (Hold LShift)"
}

local key_names = {
    [VK_LBUTTON] = "LMB", [VK_RBUTTON] = "RMB", [VK_MBUTTON] = "MMB", [VK_BACK] = "Backspace", 
    [VK_TAB] = "Tab", [VK_RETURN] = "Enter", [VK_LSHIFT] = "L.Shift", [VK_RSHIFT] = "R.Shift", 
    [VK_LCONTROL] = "L.Ctrl", [VK_RCONTROL] = "R.Ctrl", [VK_LMENU] = "L.Alt", [VK_RMENU] = "R.Alt",
    [VK_SPACE] = "Space", [VK_PRIOR] = "Page Up", [VK_NEXT] = "Page Down", [VK_END] = "End", 
    [VK_HOME] = "Home", [VK_LEFT] = "Left", [VK_UP] = "Up", [VK_RIGHT] = "Right", 
    [VK_DOWN] = "Down", [VK_INSERT] = "Insert", [VK_DELETE] = "Delete", [VK_F1] = "F1",
    [VK_F2] = "F2", [VK_F3] = "F3", [VK_F4] = "F4", [VK_F5] = "F5", [VK_F6] = "F6", [VK_F7] = "F7",
    [VK_F8] = "F8", [VK_F9] = "F9", [VK_F10] = "F10", [VK_F11] = "F11", [VK_F12] = "F12"
}
for i = 48, 57 do key_names[i] = string.char(i) end
for i = 65, 90 do key_names[i] = string.char(i) end
for i = 96, 105 do key_names[i] = "Num " .. (i-96) end

local waiting_for_key = nil

-- ===============================================================================
-- [CORE FUNCTIONS]
-- ===============================================================================
function writeLog(message)
    local file = io.open(CONSTANTS.LOG_FILE, "a")
    if file then
        file:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. message .. "\n")
        file:close()
    end
end

function getKeyName(keyCode) return key_names[keyCode] or "Key " .. keyCode end
function getFPS() return memory.getfloat(0xB7CB50, 4, false) end

function performReconnect(delay)
    lua_thread.create(function()
        local ip, port = sampGetCurrentServerAddress()
        local sname = sampGetCurrentServerName()
        sampAddChatMessage("{AAAAAA}[Flux] {FFFFFF}Reconnecting in {FF0000}" .. delay .. "{FFFFFF} seconds...", -1)
        sampSetGamestate(0)
        sampDisconnectWithReason(1)
        wait(delay * 1000)
        sampConnectToServer(ip, port)
        sampAddChatMessage("{AAAAAA}[Flux] {FFFFFF}Connecting to {00FF00}" .. sname, -1)
        writeLog("Performed reconnect to " .. ip .. ":" .. port)
    end)
end

function showCrosshairInstantlyPatch(enable)
    if enable then
        if not Features.Weapon.patch_showCrosshairInstantly then
            Features.Weapon.patch_showCrosshairInstantly = memory.read(0x0058E1D9, 1, true)
        end
        memory.write(0x0058E1D9, 0xEB, 1, true)
    elseif Features.Weapon.patch_showCrosshairInstantly ~= nil then
        memory.write(0x0058E1D9, Features.Weapon.patch_showCrosshairInstantly, 1, true)
        Features.Weapon.patch_showCrosshairInstantly = nil
    end
end

function getVehicleRotationVelocity(vehicle)
    local ptr = getCarPointer(vehicle)
    if ptr == 0 then return 0, 0, 0 end
    return memory.getfloat(ptr + 0x50), memory.getfloat(ptr + 0x54), memory.getfloat(ptr + 0x58)
end

function setVehicleRotationVelocity(vehicle, x, y, z)
    local ptr = getCarPointer(vehicle)
    if ptr == 0 then return end
    memory.setfloat(ptr + 0x50, x)
    memory.setfloat(ptr + 0x54, y)
    memory.setfloat(ptr + 0x58, z)
end

function nopHook(name, bool)
    sampev[name] = function()
        if bool then return false end
    end
end

-- Skeleton Helpers (Adapted from Zuwi)
function getBodyPartCoordinates(id, handle)
    local pedptr = getCharPointer(handle)
    if pedptr == 0 then return 0,0,0 end
    getBonePosition(ffi.cast("void*", pedptr), bonePosVec, id, true)
    return bonePosVec[0], bonePosVec[1], bonePosVec[2]
end

function explode_argb(argb)
    local a = bit.band(bit.rshift(argb, 24), 0xFF)
    local r = bit.band(bit.rshift(argb, 16), 0xFF)
    local g = bit.band(bit.rshift(argb, 8), 0xFF)
    local b = bit.band(argb, 0xFF)
    return a, r, g, b
end

function join_argb(a, r, g, b)
    return bit.bor(b, bit.lshift(g, 8), bit.lshift(r, 16), bit.lshift(a, 24))
end

-- ===============================================================================
-- [RENDERING & UI]
-- ===============================================================================
function drawVisuals()
    -- Combined visual loop for efficiency
    local visuals = Features.Visual
    if not visuals.espEnabled and not visuals.linesEnabled and not visuals.skeletonEnabled and not visuals.infoBarEnabled then return end

    -- 1. Info Bar
    if visuals.infoBarEnabled then
        local sw, sh = getScreenResolution()
        local myX, myY, myZ = getCharCoordinates(PLAYER_PED)
        local fps = math.floor(getFPS())
        local ping = sampGetPlayerPing(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED)))
        local time = os.date('%H:%M:%S')
        local text = string.format("FPS: %d | Ping: %d | Time: %s | Pos: %.1f, %.1f, %.1f", fps, ping, time, myX, myY, myZ)
        local tLen = renderGetFontDrawTextLength(font_info, text)
        renderDrawBoxWithBorder(sw/2 - tLen/2 - 10, sh - 30, tLen + 20, 20, 0xCC000000, 1, 0xFF432070)
        renderFontDrawText(font_info, text, sw/2 - tLen/2, sh - 28, 0xFFFFFFFF)
    end

    -- 2. Player Loop (ESP, Lines, Skeleton)
    if visuals.espEnabled or visuals.linesEnabled or visuals.skeletonEnabled then
        local sw, sh = getScreenResolution()
        local myX, myY, myZ = getCharCoordinates(PLAYER_PED)
        local myScreenX, myScreenY = convert3DCoordsToScreen(myX, myY, myZ)

        for id = 0, sampGetMaxPlayerId(true) do
            if sampIsPlayerConnected(id) then
                local exists, handle = sampGetCharHandleBySampPlayerId(id)
                if exists and doesCharExist(handle) and isCharOnScreen(handle) and handle ~= PLAYER_PED then
                    local x, y, z = getCharCoordinates(handle)
                    
                    -- Standard Box ESP / Lines Data
                    local headx, heady = convert3DCoordsToScreen(x, y, z + 1.0)
                    local footx, footy = convert3DCoordsToScreen(x, y, z - 1.0)

                    -- Color Calculation
                    local color = sampGetPlayerColor(id)
                    local aa, rr, gg, bb = explode_argb(color)
                    local skelColor = join_argb(255, rr, gg, bb) -- Force full alpha for skeleton

                    -- DRAW BOX ESP
                    if visuals.espEnabled and headx and heady then
                        local height = math.abs(footy - heady)
                        local width = math.abs(height * -0.25)
                        renderDrawBoxWithBorder(headx - width, heady, math.abs(2 * width), height, 0, sh * visuals.boxThickness, 0xFF00FF00)
                        
                        -- HP/Armor Bars
                        local health = sampGetPlayerHealth(id)
                        local hpWidth = math.abs(2 * width) * math.min(math.max(health / 100.0, 0.0), 1.0)
                        renderDrawLine(headx - width, footy + 7, headx - width + hpWidth, footy + 7, 3, 0xFFFF0000)
                        
                        local armor = sampGetPlayerArmor(id)
                        if armor > 0 then
                            local armorWidth = math.abs(2 * width) * math.min(math.max(armor / 100.0, 0.0), 1.0)
                            renderDrawLine(headx - width, footy + 12, headx - width + armorWidth, footy + 12, 3, 0xFFFFFFFF)
                        end
                    end

                    -- DRAW LINES
                    if visuals.linesEnabled and headx and myScreenX then
                        local height = math.abs(footy - heady)
                        renderDrawLine(sw / 2, sh, headx, heady + height / 2, 2.0, 0xFF00FFFF)
                    end

                    -- DRAW SKELETON (Ported from Zuwi)
                    if visuals.skeletonEnabled then
                        -- Main body parts linkage
                        local t = {3, 4, 5, 51, 52, 41, 42, 31, 32, 33, 21, 22, 23, 2}
                        for v = 1, #t do
                            local pos1X, pos1Y, pos1Z = getBodyPartCoordinates(t[v], handle)
                            local pos2X, pos2Y, pos2Z = getBodyPartCoordinates(t[v] + 1, handle)
                            local pos1_sX, pos1_sY = convert3DCoordsToScreen(pos1X, pos1Y, pos1Z)
                            local pos2_sX, pos2_sY = convert3DCoordsToScreen(pos2X, pos2Y, pos2Z)
                            
                            if pos1_sX and pos2_sX then
                                renderDrawLine(pos1_sX, pos1_sY, pos2_sX, pos2_sY, 1, skelColor)
                            end
                        end
                        
                        -- Connecting shoulders/hips to spine
                        for v = 4, 5 do
                            local pos2X, pos2Y, pos2Z = getBodyPartCoordinates(v * 10 + 1, handle) -- 41, 51
                            local pos2_sX, pos2_sY = convert3DCoordsToScreen(pos2X, pos2Y, pos2Z)
                            -- Connect to Spine/Neck area roughly
                            local spineX, spineY, spineZ = getBodyPartCoordinates(4, handle) 
                            local spine_sX, spine_sY = convert3DCoordsToScreen(spineX, spineY, spineZ)

                            if pos2_sX and spine_sX then
                                renderDrawLine(spine_sX, spine_sY, pos2_sX, pos2_sY, 1, skelColor)
                            end
                        end
                    end
                end
            end
        end
    end
end

function apply_flux_style()
    imgui.SwitchContext()
    local style = imgui.GetStyle()
    local colors = style.Colors
    local clr = imgui.Col
    local ImVec4 = imgui.ImVec4
    -- FLUX THEME
    style.WindowRounding = 8.0
    style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
    style.ChildWindowRounding = 6.0
    style.FrameRounding = 4.0
    style.ItemSpacing = imgui.ImVec2(8, 6)
    style.ScrollbarSize = 10.0
    style.ScrollbarRounding = 9.0
    style.GrabMinSize = 10.0
    style.GrabRounding = 4.0
    colors[clr.Text] = ImVec4(0.95, 0.95, 0.95, 1.00)
    colors[clr.WindowBg] = ImVec4(0.10, 0.10, 0.12, 0.98)
    colors[clr.ChildWindowBg] = ImVec4(0.12, 0.12, 0.14, 1.00)
    colors[clr.Border] = ImVec4(0.43, 0.20, 0.70, 0.50)
    colors[clr.FrameBg] = ImVec4(0.20, 0.18, 0.24, 0.54)
    colors[clr.FrameBgHovered] = ImVec4(0.43, 0.20, 0.70, 0.40)
    colors[clr.FrameBgActive] = ImVec4(0.43, 0.20, 0.70, 0.67)
    colors[clr.TitleBg] = ImVec4(0.10, 0.10, 0.12, 1.00)
    colors[clr.TitleBgActive] = ImVec4(0.10, 0.10, 0.12, 1.00)
    colors[clr.CheckMark] = ImVec4(0.60, 0.30, 0.90, 1.00)
    colors[clr.SliderGrab] = ImVec4(0.60, 0.30, 0.90, 1.00)
    colors[clr.SliderGrabActive] = ImVec4(0.75, 0.40, 0.95, 1.00)
    colors[clr.Button] = ImVec4(0.25, 0.20, 0.35, 0.60)
    colors[clr.ButtonHovered] = ImVec4(0.43, 0.20, 0.70, 0.70)
    colors[clr.ButtonActive] = ImVec4(0.43, 0.20, 0.70, 1.00)
    colors[clr.Header] = ImVec4(0.43, 0.20, 0.70, 0.50)
    colors[clr.HeaderHovered] = ImVec4(0.46, 0.20, 0.70, 0.80)
    colors[clr.HeaderActive] = ImVec4(0.43, 0.20, 0.70, 1.00)
    colors[clr.Separator] = ImVec4(0.43, 0.20, 0.70, 0.50)
end

function CenterText(text)
    local width = imgui.GetWindowWidth()
    local calc = imgui.CalcTextSize(text)
    imgui.SetCursorPosX( width / 2 - calc.x / 2 )
    imgui.Text(text)
end

-- ===============================================================================
-- [IMGUI DRAW FRAME]
-- ===============================================================================
function imgui.OnDrawFrame()
    if UI_Buffers.mainWindow.v then
        imgui.SetNextWindowSize(imgui.ImVec2(720, 550), imgui.Cond.FirstUseEver)
        imgui.Begin(u8'Flux Panel', UI_Buffers.mainWindow)

        imgui.BeginChild('##sidebar', imgui.ImVec2(160, -1), true)
            imgui.PushItemWidth(-1)
            if imgui.Button(Features.Global.activeTab == 1 and u8'> Weapon' or u8'Weapon', imgui.ImVec2(-1, 40)) then Features.Global.activeTab = 1 end
            if imgui.Button(Features.Global.activeTab == 2 and u8'> Visual' or u8'Visual', imgui.ImVec2(-1, 40)) then Features.Global.activeTab = 2 end
            if imgui.Button(Features.Global.activeTab == 3 and u8'> Car' or u8'Car', imgui.ImVec2(-1, 40)) then Features.Global.activeTab = 3 end
            if imgui.Button(Features.Global.activeTab == 4 and u8'> Misc' or u8'Misc', imgui.ImVec2(-1, 40)) then Features.Global.activeTab = 4 end
            if imgui.Button(Features.Global.activeTab == 5 and u8'> Keybinds' or u8'Keybinds', imgui.ImVec2(-1, 40)) then Features.Global.activeTab = 5 end
            if imgui.Button(Features.Global.activeTab == 6 and u8'> About' or u8'About', imgui.ImVec2(-1, 40)) then Features.Global.activeTab = 6 end
            
            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()
            imgui.TextColored(imgui.ImVec4(0.6, 0.3, 0.9, 1.0), u8"Quick Actions")
            if imgui.Button(u8'Reconnect', imgui.ImVec2(-1, 30)) then performReconnect(Features.Global.reconnectDelay) end
            if imgui.Button(u8'Fix Wheels', imgui.ImVec2(-1, 30)) then
                if isCharInAnyCar(PLAYER_PED) then
                    local veh = storeCarCharIsInNoSave(PLAYER_PED)
                    for i = 0, 3 do fixCarTire(veh, i) end
                    sampAddChatMessage("{00FF00}[Flux] Wheels fixed!", -1)
                else
                    sampAddChatMessage("{FF0000}[Flux] Not in vehicle!", -1)
                end
            end
            imgui.PopItemWidth()
        imgui.EndChild()

        imgui.SameLine()

        imgui.BeginChild('##content', imgui.ImVec2(-1, -1), true)

        if Features.Global.activeTab == 1 then -- WEAPON
            CenterText(u8'WEAPON CONFIGURATION')
            imgui.Separator()
            imgui.Spacing()
            if imgui.Checkbox(u8'NoSpread', imgui.ImBool(Features.Weapon.spread)) then
                Features.Weapon.spread = not Features.Weapon.spread
                sampAddChatMessage(Features.Weapon.spread and '{00FF00}NoSpread ON' or '{FF0000}NoSpread OFF', -1)
            end
            imgui.SameLine()
            imgui.TextDisabled("(F8)")

            if imgui.Checkbox(u8'NoReload', imgui.ImBool(Features.Weapon.norl)) then
                Features.Weapon.norl = not Features.Weapon.norl
                sampAddChatMessage(Features.Weapon.norl and '{00FF00}NoReload ON' or '{FF0000}NoReload OFF', -1)
            end
            imgui.SameLine()
            imgui.TextDisabled("(F2)")

            if imgui.Checkbox(u8'Instant Crosshair', imgui.ImBool(Features.Weapon.instantCrosshair)) then
                Features.Weapon.instantCrosshair = not Features.Weapon.instantCrosshair
                showCrosshairInstantlyPatch(Features.Weapon.instantCrosshair)
                sampAddChatMessage(Features.Weapon.instantCrosshair and '{00FF00}Instant Crosshair ON' or '{FF0000}Instant Crosshair OFF', -1)
            end
            imgui.SameLine()
            imgui.TextDisabled("(F12)")

        elseif Features.Global.activeTab == 2 then -- VISUAL
            CenterText(u8'VISUAL CONFIGURATION')
            imgui.Separator()
            imgui.Spacing()

            if imgui.Checkbox(u8'Enable ESP (F4)', imgui.ImBool(Features.Visual.espEnabled)) then
                Features.Visual.espEnabled = not Features.Visual.espEnabled
            end
            if imgui.Checkbox(u8'Show Lines (F5)', imgui.ImBool(Features.Visual.linesEnabled)) then
                Features.Visual.linesEnabled = not Features.Visual.linesEnabled
            end
            if imgui.Checkbox(u8'Show Skeleton', imgui.ImBool(Features.Visual.skeletonEnabled)) then
                Features.Visual.skeletonEnabled = not Features.Visual.skeletonEnabled
            end
            if imgui.Checkbox(u8'Show Info Bar', UI_Buffers.infoBar) then
                Features.Visual.infoBarEnabled = UI_Buffers.infoBar.v
            end
            imgui.Spacing()
            imgui.Separator()
            imgui.Text("Settings")
            if imgui.SliderFloat(u8'Box Thickness', UI_Buffers.boxThickness, 0.001, 0.01, "%.3f") then
                Features.Visual.boxThickness = UI_Buffers.boxThickness.v
            end

        elseif Features.Global.activeTab == 3 then -- CAR
            CenterText(u8'VEHICLE MANAGER')
            imgui.Separator()
            imgui.Columns(2, "CarCols", true)
            
            -- Left Column
            imgui.TextColored(imgui.ImVec4(0.6, 0.3, 0.9, 1.0), u8"[ Vehicle Information ]")
            if isCharInAnyCar(PLAYER_PED) then
                local car = storeCarCharIsInNoSave(PLAYER_PED)
                local model = getCarModel(car)
                local speed = getCarSpeed(car)
                local health = getCarHealth(car)

                local carPtr = getCarPointer(car)
                local currentGear = 0
                if carPtr ~= 0 then
                    currentGear = memory.getint8(carPtr + 0x49C)
                end

                -- Calculate Handling Pointer
                local address = callFunction(0x00403DA0,1,1,model)
                local phandling = readMemory((address + 0x4A),2,false) * 0xE0 + 0xC2B9DC
                local maxGears = readMemory(phandling + 0x76, 1, false)

                imgui.Text(u8'Model ID: ' .. model)
                imgui.Text(u8'Gear: ' .. currentGear .. ' / ' .. maxGears) 
                imgui.Text(u8'Speed: ' .. string.format("%.1f", speed))
                
                local hp_frac = math.min(math.max(health / 1000.0, 0.0), 1.0)
                imgui.ProgressBar(hp_frac, imgui.ImVec2(-1, 0), string.format("%.0f HP", health))

                if imgui.Button(u8'Remove Gear Limit', imgui.ImVec2(-1, 20)) then
                    writeMemory(phandling + 0x76, 1, 20, false)
                    sampAddChatMessage("{00FF00}[Flux] Gear limit set to 20!", -1)
                end
            else
                imgui.TextColored(imgui.ImVec4(1, 0, 0, 1), u8'Not in a vehicle')
            end
            
            imgui.Spacing()
            imgui.Separator()
            imgui.TextColored(imgui.ImVec4(0.6, 0.3, 0.9, 1.0), u8"[ Speed Control ]")
            if imgui.Checkbox(u8'Auto Speed (O)', imgui.ImBool(Features.Car.accelMode)) then
                Features.Car.accelMode = not Features.Car.accelMode
            end
            
            imgui.PushItemWidth(100)
            if imgui.InputInt(u8'Step', UI_Buffers.speedIncrement) then
                if UI_Buffers.speedIncrement.v < 1 then UI_Buffers.speedIncrement.v = 1 end
                Features.Car.speedIncrement = UI_Buffers.speedIncrement.v
            end
            if imgui.InputInt(u8'Target', UI_Buffers.targetSpeed) then
                if UI_Buffers.targetSpeed.v < 1 then UI_Buffers.targetSpeed.v = 1 end
                Features.Car.targetSpeed = UI_Buffers.targetSpeed.v
            end
            imgui.PopItemWidth()
            if imgui.Button(u8'Apply Speed', imgui.ImVec2(-1, 20)) then
                if isCharInAnyCar(PLAYER_PED) and UI_Buffers.targetSpeed.v > 0 then
                    Features.Car.accelMode = true
                    Features.Car.targetSpeed = math.floor(UI_Buffers.targetSpeed.v / CONSTANTS.SPEED_CALIBRATION)
                    Features.Car.currentTargetSpeed = UI_Buffers.targetSpeed.v
                    sampAddChatMessage("{00FF00}[Flux] Speed control enabled - Target: " .. Features.Car.currentTargetSpeed, -1)
                else
                    sampAddChatMessage("{FF0000}[Flux] Invalid speed or not in car!", -1)
                end
            end

            imgui.NextColumn() -- Right Column
            imgui.TextColored(imgui.ImVec4(0.6, 0.3, 0.9, 1.0), u8"[ Physics & Handling ]")
            if imgui.Checkbox(u8'Drift Mode', imgui.ImBool(Features.Car.driftMode)) then
                Features.Car.driftMode = not Features.Car.driftMode
            end
            
            local drift_types = {u8'Hold Shift', u8'Toggle Shift', u8'Always On'}
            imgui.PushItemWidth(-1)
            if imgui.Combo(u8'##DriftType', UI_Buffers.driftType, drift_types) then
                local types = {"hold", "toggle", "always"}
                Features.Car.driftType = types[UI_Buffers.driftType.v + 1]
                if Features.Car.driftType == "always" then Features.Car.driftMode = true 
                elseif Features.Car.driftType == "hold" then Features.Car.driftMode = false end
            end
            imgui.PopItemWidth()

            if imgui.Checkbox(u8'Ground Stick', UI_Buffers.groundStick) then Features.Car.groundStick = UI_Buffers.groundStick.v end
            
            imgui.TextColored(imgui.ImVec4(0.6, 0.3, 0.9, 1.0), u8"[ Cheats ]")
            if imgui.Checkbox(u8'GM InCar', imgui.ImBool(Features.Car.gmCar)) then Features.Car.gmCar = not Features.Car.gmCar end
            if imgui.Checkbox(u8'GM Wheels', UI_Buffers.gmWheels) then Features.Car.gmWheels = UI_Buffers.gmWheels.v end
            if imgui.Checkbox(u8'AntiBoom', UI_Buffers.antiBoom) then Features.Car.antiBoom = UI_Buffers.antiBoom.v end
            if imgui.Checkbox(u8'NoBike Fall', imgui.ImBool(Features.Misc.noBikeFall)) then Features.Misc.noBikeFall = not Features.Misc.noBikeFall end
            if imgui.Checkbox(u8'WaterDrive', imgui.ImBool(Features.Car.waterDrive)) then Features.Car.waterDrive = not Features.Car.waterDrive end
            if imgui.Checkbox(u8'FireCar', imgui.ImBool(Features.Car.fireCar)) then Features.Car.fireCar = not Features.Car.fireCar end

            imgui.Text(u8'Damage Mult:')
            imgui.PushItemWidth(-1)
            if imgui.SliderFloat(u8'##DmgMult', UI_Buffers.damageMult, 0.0, 1.0, "%.2f") then Features.Car.damageMult = UI_Buffers.damageMult.v end
            imgui.PopItemWidth()
            imgui.Columns(1)

        elseif Features.Global.activeTab == 4 then -- MISC
            CenterText(u8'MISCELLANEOUS')
            imgui.Separator()
            imgui.Columns(2, "MiscCols", false)
            if imgui.Checkbox(u8'AntiStun (F3)', imgui.ImBool(Features.Misc.antiStun)) then Features.Misc.antiStun = not Features.Misc.antiStun end
            if imgui.Checkbox(u8'Infinite Oxygen', UI_Buffers.oxygen) then Features.Misc.oxygen = UI_Buffers.oxygen.v end
            if imgui.Checkbox(u8'Mega Jump', UI_Buffers.megaJump) then Features.Misc.megaJump = UI_Buffers.megaJump.v end
            if imgui.Checkbox(u8'BMX Mega Jump', UI_Buffers.bmxMegaJump) then Features.Misc.bmxMegaJump = UI_Buffers.bmxMegaJump.v end
            if imgui.Button("Fix Wheels") then
                if isCharInAnyCar(PLAYER_PED) then
                    local veh = storeCarCharIsInNoSave(PLAYER_PED)
                    for i = 0, 3 do fixCarTire(veh, i) end
                else sampAddChatMessage("{FF0000}Not in vehicle!", -1) end
            end
            if imgui.Checkbox(u8'GodMode (F9)', UI_Buffers.godMode) then Features.Misc.godMode = UI_Buffers.godMode.v end
            imgui.NextColumn()
            if imgui.Checkbox(u8'QuickStop', UI_Buffers.quickStop) then Features.Misc.quickStop = UI_Buffers.quickStop.v end
            if imgui.Checkbox(u8'FakeAFK (F6)', imgui.ImBool(Features.Misc.fakeAfk)) then
                Features.Misc.fakeAfk = not Features.Misc.fakeAfk
                nopHook('onSendPlayerSync', Features.Misc.fakeAfk)
                nopHook('onSendVehicleSync', Features.Misc.fakeAfk)
                nopHook('onSendPassengerSync', Features.Misc.fakeAfk)
            end
            if imgui.Checkbox(u8'FakeLag (F7)', imgui.ImBool(Features.Misc.fakeLag)) then Features.Misc.fakeLag = not Features.Misc.fakeLag end
            if imgui.Checkbox(u8'No Fall', UI_Buffers.noFall) then Features.Misc.noFall = UI_Buffers.noFall.v end
            imgui.Text("Reconnect Delay (sec):")
            if imgui.SliderInt("##recon_delay", UI_Buffers.reconnectDelay, 1, 30) then Features.Global.reconnectDelay = UI_Buffers.reconnectDelay.v end
            if imgui.Button(u8'Reconnect Now', imgui.ImVec2(-1, 25)) then performReconnect(Features.Global.reconnectDelay) end
            imgui.Columns(1)

        elseif Features.Global.activeTab == 5 then -- KEYBINDS
            CenterText(u8'KEYBIND MANAGER')
            imgui.Separator()
            imgui.TextColored(imgui.ImVec4(0.8, 0.8, 0.8, 1), u8'Press ESC to cancel key binding')
            imgui.BeginChild("KeybindScroll", imgui.ImVec2(0, 300), true)
            for bind_name, key_code in pairs(keybinds) do
                local display_name = keybind_names[bind_name] or bind_name
                imgui.PushID(bind_name)
                imgui.AlignTextToFramePadding()
                imgui.TextColored(imgui.ImVec4(0.9, 0.9, 0.9, 1), u8(display_name))
                imgui.SameLine(250)
                local key_color = waiting_for_key == bind_name and imgui.ImVec4(1, 1, 0, 1) or imgui.ImVec4(0.5, 0.8, 1, 1)
                imgui.TextColored(key_color, getKeyName(key_code))
                imgui.SameLine(320)
                local button_text = waiting_for_key == bind_name and u8'...' or u8'Set'
                local button_color = waiting_for_key == bind_name and imgui.ImVec4(1, 1, 0, 1) or imgui.ImVec4(0.2, 0.6, 0.2, 1)
                imgui.PushStyleColor(imgui.Col.Button, button_color)
                if imgui.Button(button_text, imgui.ImVec2(50, 0)) then waiting_for_key = bind_name end
                imgui.PopStyleColor()
                imgui.SameLine()
                if imgui.Button(u8'X', imgui.ImVec2(30, 0)) then waiting_for_key = nil end
                imgui.PopID()
            end
            imgui.EndChild()
            imgui.Separator()
            if imgui.Button(u8'Save Config', imgui.ImVec2(100, 30)) then
                local file = io.open(CONSTANTS.CONFIG_FILE, "w")
                if file then
                    for k, v in pairs(keybinds) do file:write(k .. "=" .. v .. "\n") end
                    file:close()
                    sampAddChatMessage("{00FF00}[Flux] Keybinds saved!", -1)
                end
            end
            if waiting_for_key then
                for vkey = 1, 255 do
                    if wasKeyPressed(vkey) and vkey ~= VK_ESCAPE then
                        keybinds[waiting_for_key] = vkey
                        waiting_for_key = nil
                        break
                    elseif wasKeyPressed(VK_ESCAPE) then
                        waiting_for_key = nil
                        break
                    end
                end
            end

        elseif Features.Global.activeTab == 6 then -- ABOUT
            CenterText(u8'ABOUT FLUX')
            imgui.Separator()
            imgui.Text(u8'Flux - Multi-purpose Utility Script')
            imgui.Text(u8'Version: 1.3.0 (Skeleton Update)')
            imgui.Text(u8'Author: rmux')
        end
        imgui.EndChild()
        imgui.End()
    end
end

-- ===============================================================================
-- [HOOKS]
-- ===============================================================================
function sampev.onSendPlayerSync() Features.Car.justGotInCar = true end

function sampev.onSendVehicleSync(data)
    if data == nil or data.vehicleHealth == nil then return end
    if Features.Car.fireCar then data.vehicleHealth = 4 end
    
    if Features.Car.justGotInCar then
        Features.Car.justGotInCar = false
        Features.Car.lastHP = data.vehicleHealth
        return
    end
    
    local newHP = data.vehicleHealth
    if newHP < Features.Car.lastHP then
        local damage = Features.Car.lastHP - newHP
        local reducedDamage = damage * Features.Car.damageMult
        local hp = Features.Car.lastHP - reducedDamage
        if isCharInAnyCar(PLAYER_PED) then
            local car = storeCarCharIsInNoSave(PLAYER_PED)
            if doesVehicleExist(car) then
                setCarHealth(car, hp)
                data.vehicleHealth = hp
            end
        end
    end
    Features.Car.lastHP = data.vehicleHealth or Features.Car.lastHP
end

-- ===============================================================================
-- [LOGIC PROCESSORS]
-- ===============================================================================
local function HandleKeybinds()
    -- Menu
    if wasKeyPressed(keybinds.menu_toggle) then
        UI_Buffers.mainWindow.v = not UI_Buffers.mainWindow.v
        imgui.Process = UI_Buffers.mainWindow.v
    end
    -- Reconnect
    if isKeyDown(VK_LSHIFT) and wasKeyPressed(keybinds.reconnect_key) then
        performReconnect(Features.Global.reconnectDelay)
    end
    -- Speed Control
    if wasKeyPressed(keybinds.speed_toggle) then
        Features.Car.accelMode = not Features.Car.accelMode
        sampAddChatMessage(Features.Car.accelMode and "{00FF00}[Flux] Speed ON" or "{FF0000}[Flux] Speed OFF", -1)
    end
    if wasKeyPressed(keybinds.speed_increase) then
        Features.Car.currentTargetSpeed = math.min(Features.Car.currentTargetSpeed + Features.Car.speedIncrement, 600)
        Features.Car.targetSpeed = math.floor(Features.Car.currentTargetSpeed / CONSTANTS.SPEED_CALIBRATION)
        UI_Buffers.targetSpeed.v = Features.Car.currentTargetSpeed
        sampAddChatMessage("{00FF00}[Flux] Target speed: " .. Features.Car.currentTargetSpeed, -1)
    end
    if wasKeyPressed(keybinds.speed_decrease) then
        Features.Car.currentTargetSpeed = math.max(Features.Car.currentTargetSpeed - Features.Car.speedIncrement, 1)
        Features.Car.targetSpeed = math.floor(Features.Car.currentTargetSpeed / CONSTANTS.SPEED_CALIBRATION)
        UI_Buffers.targetSpeed.v = Features.Car.currentTargetSpeed
        sampAddChatMessage("{00FF00}[Flux] Target speed: " .. Features.Car.currentTargetSpeed, -1)
    end
    -- Toggles
    local function toggleFeature(key, featureTable, keyName, msgName, hookName)
        if wasKeyPressed(key) then
            featureTable[keyName] = not featureTable[keyName]
            local state = featureTable[keyName]
            sampAddChatMessage((state and "{00FF00}" or "{FF0000}") .. "[Flux] " .. msgName .. (state and " ON" or " OFF"), -1)
            if hookName then
                nopHook('onSendPlayerSync', state)
                nopHook('onSendVehicleSync', state)
                nopHook('onSendPassengerSync', state)
            end
            if keyName == 'instantCrosshair' then showCrosshairInstantlyPatch(state) end
        end
    end

    toggleFeature(keybinds.esp_toggle, Features.Visual, 'espEnabled', 'ESP')
    toggleFeature(keybinds.lines_toggle, Features.Visual, 'linesEnabled', 'ESP Lines')
    toggleFeature(keybinds.antistun_toggle, Features.Misc, 'antiStun', 'AntiStun')
    toggleFeature(keybinds.fakeafk_toggle, Features.Misc, 'fakeAfk', 'FakeAFK', true)
    toggleFeature(keybinds.fakelag_toggle, Features.Misc, 'fakeLag', 'FakeLag')
    toggleFeature(keybinds.nospread_toggle, Features.Weapon, 'spread', 'NoSpread')
    toggleFeature(keybinds.godmode_toggle, Features.Misc, 'godMode', 'GodMode')
    toggleFeature(keybinds.waterdrive_toggle, Features.Car, 'waterDrive', 'WaterDrive')
    toggleFeature(keybinds.firecar_toggle, Features.Car, 'fireCar', 'FireCar')
    toggleFeature(keybinds.instant_crosshair_toggle, Features.Weapon, 'instantCrosshair', 'Instant Crosshair')
    toggleFeature(keybinds.noreload_toggle, Features.Weapon, 'norl', 'NoReload')
end

local function RunVehicleLogic()
    if not Features.Global.scriptEnabled or not isCharInAnyCar(PLAYER_PED) then return end

    local car = storeCarCharIsInNoSave(PLAYER_PED)
    local speed = getCarSpeed(car)
    
    -- 1. Speed Boost
    if isKeyDown(keybinds.speed_boost) and Features.Car.accelMode then
        setCarForwardSpeed(car, speed * 1.5)
    end

    -- 2. Auto Speed
    if Features.Car.accelMode then
        local speedDiff = Features.Car.targetSpeed - speed
        if math.abs(speedDiff) > 2 then
            setCarForwardSpeed(car, speed + (speedDiff * (speedDiff > 0 and 0.1 or 0.05)))
        end
        
        -- Ground Stick
        if Features.Car.groundStick and speed > CONSTANTS.HIGH_SPEED_THRESHOLD then
            local rx, ry, rz = getVehicleRotationVelocity(car)
            setVehicleRotationVelocity(car, rx * 0.8, ry * 0.8, rz)
            if not isVehicleOnAllWheels(car) and isCarInAirProper(car) then
                local vx, vy, vz = getCarSpeedVector(car)
                setCarSpeedVector(car, vx, vy, vz - CONSTANTS.GROUND_STICK_FORCE)
            end
        end
    end

    -- 3. Drift Logic
    local lshift = isKeyDown(keybinds.drift_toggle)
    if Features.Car.driftType == "hold" then Features.Car.driftMode = lshift
    elseif Features.Car.driftType == "toggle" and lshift and not Features.Car.shiftPressed then
        Features.Car.driftMode = not Features.Car.driftMode
        sampAddChatMessage(Features.Car.driftMode and "{FFFF00}[Flux] Drift Enabled" or "{FFFF00}[Flux] Drift Disabled", -1)
    end
    Features.Car.shiftPressed = lshift

    if Features.Car.driftMode and isVehicleOnAllWheels(car) and doesVehicleExist(car) and speed > CONSTANTS.MIN_DRIFT_SPEED then
        setCarCollision(car, false)
        if isCarInAirProper(car) then setCarCollision(car, true) end
        if isKeyDown(VK_A) then addToCarRotationVelocity(car, 0, 0, 0.03) end
        if isKeyDown(VK_D) then addToCarRotationVelocity(car, 0, 0, -0.03) end
    else
        setCarCollision(car, true)
    end

    -- 4. Car Cheats
    if Features.Car.gmCar then setCarProofs(car, true, true, true, true, true) end
    if Features.Car.gmWheels then setCanBurstCarTires(car, false) end
    if Features.Car.antiBoom and isCarUpsidedown(car) then setCarHealth(car, 1000) end
    if Features.Car.waterDrive then memory.write(9867602, 1, 4) else memory.write(9867602, 0, 4) end
    if Features.Car.fixWheels then for i = 0, 3 do fixCarTire(car, i) end end
end

local function RunCharacterLogic()
    -- 1. Weapon/Combat
    if Features.Misc.antiStun and not isCharDead(PLAYER_PED) then
        local anims = {'DAM_armL_frmBK', 'DAM_armL_frmFT', 'DAM_armL_frmLT', 'DAM_armR_frmBK', 'DAM_armR_frmFT', 'DAM_armR_frmRT', 'DAM_LegL_frmBK', 'DAM_LegL_frmFT', 'DAM_LegL_frmLT', 'DAM_LegR_frmBK', 'DAM_LegR_frmFT', 'DAM_LegR_frmRT', 'DAM_stomach_frmBK', 'DAM_stomach_frmFT', 'DAM_stomach_frmLT', 'DAM_stomach_frmRT'}
        for _, v in pairs(anims) do
            if isCharPlayingAnim(PLAYER_PED, v) then setCharAnimSpeed(PLAYER_PED, v, 999) end
        end
    end

    if Features.Weapon.spread then memory.setfloat(0x8D2E64, 0.0) else memory.setfloat(0x8D2E64, 1.0) end

    if Features.Weapon.norl then
        local weapon = getCurrentCharWeapon(PLAYER_PED)
        local nbs = raknetNewBitStream()
        raknetBitStreamWriteInt32(nbs, weapon)
        raknetBitStreamWriteInt32(nbs, 0)
        raknetEmulRpcReceiveBitStream(22, nbs)
        raknetDeleteBitStream(nbs)
    end
    
    if Features.Weapon.instantCrosshair then showCrosshairInstantlyPatch(true) end

    -- 2. Movement/Misc
    if Features.Misc.quickStop and (isCharPlayingAnim(PLAYER_PED, 'RUN_STOP') or isCharPlayingAnim(PLAYER_PED, 'RUN_STOPR')) then
        clearCharTasksImmediately(PLAYER_PED)
    end

    setCharCanBeKnockedOffBike(PLAYER_PED, Features.Misc.noBikeFall)
    
    if Features.Misc.fakeLag then for i = 1,3 do sampSetSendrate(i, 1000) end
    else for i = 1,3 do sampSetSendrate(i, 0) end end

    if Features.Misc.noFall and not isCharDead(PLAYER_PED) then
        if isCharPlayingAnim(PLAYER_PED, 'KO_SKID_BACK') or isCharPlayingAnim(PLAYER_PED, 'FALL_COLLAPSE') then
            clearCharTasksImmediately(PLAYER_PED)
        end
    end

    memory.setint8(0x96916E, Features.Misc.oxygen and 1 or 0, false)
    memory.setint8(0x96916C, Features.Misc.megaJump and 1 or 0, false)
    memory.setint8(0x969161, Features.Misc.bmxMegaJump and 1 or 0, false)
    
    if Features.Misc.godMode then setCharProofs(PLAYER_PED, true, true, true, true, true)
    else setCharProofs(PLAYER_PED, false, false, false, false, false) end
end

-- ===============================================================================
-- [MAIN LOOP]
-- ===============================================================================
function main()
    -- Load Config
    local file = io.open(CONSTANTS.CONFIG_FILE, "r")
    if file then
        for line in file:lines() do
            local key, value = line:match("([^=]+)=([^=]+)")
            if key and value then keybinds[key] = tonumber(value) end
        end
        file:close()
        writeLog("Keybinds loaded from config")
    end
    
    while not isSampLoaded() or not isSampAvailable() do wait(100) end
    
    apply_flux_style()
    sampAddChatMessage("{00FF00}[Flux 1.3] Script loaded! Press 'U' for menu.", -1)
    writeLog("Script loaded successfully!")
    imgui.Process = false
    
    while true do
        wait(0)
        local success, error = pcall(function()
            drawVisuals() -- Combined visual function
            HandleKeybinds()
            RunVehicleLogic()
            RunCharacterLogic()
        end)
        
        if not success then
            local errorMsg = "[Flux] Error: " .. tostring(error)
            sampAddChatMessage("{FF0000}" .. errorMsg, -1)
            writeLog(errorMsg)
        end
    end
end