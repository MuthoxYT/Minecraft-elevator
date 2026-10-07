-- ============================================================
-- ELEVATOR MAIN CONTROLLER
-- Computer #0
-- ============================================================

-- REDSTONE
local DIRECTION = "left"
local SEQUENCER = "back"
local CONTACT   = "right"
local HOME      = "top"
local BOTTOM    = "bottom"

-- WIRED NETWORK
local NETWORK_SIDE = "front"

-- SPEED
local SPEED_RELAY_NAME = "redstone_relay_2"
local SPEED_SIDE = "right"

-- NETWORK
local BRIDGE_ID = 1

local PROTOCOL_STATE =
    "elevator_state"

local PROTOCOL_COMMAND =
    "elevator_command"

-- FILES
local CONFIG_FILE =
    "elevator.cfg"

local FLOOR_FILE =
    "floors.cfg"


-- ============================================================
-- STATE
-- ============================================================

local currentFloor = nil
local maxFloor = nil
local targetFloor = nil

local moving = false
local calibrating = false

local normalSpeed = 70

local currentPage =
    "main"

local floorNames = {}

local autoHomeEnabled = false
local autoHomeMinutes = 5
local autoHomeTimer = nil

local namingFloor = nil


-- ============================================================
-- PERIPHERALS
-- ============================================================

local speedRelay =
    peripheral.wrap(
        SPEED_RELAY_NAME
    )

if not speedRelay then
    error(
        "Speed Relay "
        .. SPEED_RELAY_NAME
        .. " nicht gefunden!"
    )
end


if peripheral.getType(
    NETWORK_SIDE
) ~= "modem" then

    error(
        "Kein Wired Modem auf "
        .. NETWORK_SIDE
    )
end


rednet.open(
    NETWORK_SIDE
)


-- ============================================================
-- SPEED
-- ============================================================

local function speedPercentToSignal(
    percent
)

    percent =
        math.max(
            50,
            math.min(
                100,
                percent
            )
        )


    local signal =
        math.floor(
            ((100 - percent) / 50)
            * 15
            + 0.5
        )


    return math.max(
        0,
        math.min(
            15,
            signal
        )
    )
end


local function setSpeed(percent)

    speedRelay.setAnalogOutput(
        SPEED_SIDE,
        speedPercentToSignal(
            percent
        )
    )
end


local function setNormalSpeed()
    setSpeed(normalSpeed)
end


local function setCalibrationSpeed()
    setSpeed(100)
end


-- ============================================================
-- CONFIG
-- ============================================================

local function loadConfig()

    if not fs.exists(
        CONFIG_FILE
    ) then
        return false
    end


    local file =
        fs.open(
            CONFIG_FILE,
            "r"
        )


    if not file then
        return false
    end


    local floorValue =
        file.readLine()

    local speedValue =
        file.readLine()

    local autoValue =
        file.readLine()

    local minutesValue =
        file.readLine()


    file.close()


    local loadedFloor =
        tonumber(
            floorValue
        )

    local loadedSpeed =
        tonumber(
            speedValue
        )

    local loadedMinutes =
        tonumber(
            minutesValue
        )


    if loadedFloor
        and loadedFloor >= 1
    then

        maxFloor =
            loadedFloor
    end


    if loadedSpeed
        and loadedSpeed >= 50
        and loadedSpeed <= 100
    then

        normalSpeed =
            loadedSpeed
    end


    if autoValue == "true" then

        autoHomeEnabled = true

    elseif autoValue == "false" then

        autoHomeEnabled = false
    end


    if loadedMinutes
        and loadedMinutes >= 1
        and loadedMinutes <= 60
    then

        autoHomeMinutes =
            loadedMinutes
    end


    return maxFloor ~= nil
end


local function saveConfig()

    local file =
        fs.open(
            CONFIG_FILE,
            "w"
        )


    if not file then
        error(
            "Config konnte nicht gespeichert werden!"
        )
    end


    if maxFloor ~= nil then

        file.writeLine(
            tostring(maxFloor)
        )

    else

        file.writeLine("")
    end


    file.writeLine(
        tostring(normalSpeed)
    )

    file.writeLine(
        tostring(autoHomeEnabled)
    )

    file.writeLine(
        tostring(autoHomeMinutes)
    )


    file.close()
end


-- ============================================================
-- FLOOR NAMES
-- ============================================================

local function loadFloorNames()

    floorNames = {}


    if not fs.exists(
        FLOOR_FILE
    ) then
        return
    end


    local file =
        fs.open(
            FLOOR_FILE,
            "r"
        )


    if not file then
        return
    end


    while true do

        local line =
            file.readLine()


        if not line then
            break
        end


        local floorString,
              name =
            string.match(
                line,
                "^(%-?%d+)=(.*)$"
            )


        if floorString
            and name
        then

            local floor =
                tonumber(
                    floorString
                )


            if floor ~= nil
                and name ~= ""
            then

                floorNames[floor] =
                    name
            end
        end
    end


    file.close()
end


local function saveFloorNames()

    local file =
        fs.open(
            FLOOR_FILE,
            "w"
        )


    if not file then
        error(
            "floors.cfg konnte nicht gespeichert werden!"
        )
    end


    if maxFloor ~= nil then

        for floor = 0, maxFloor do

            local name =
                floorNames[floor]


            if name
                and name ~= ""
            then

                file.writeLine(
                    tostring(floor)
                    .. "="
                    .. name
                )
            end
        end
    end


    file.close()
end


-- ============================================================
-- STATE AN PANEL SENDEN
-- ============================================================

local function sendState()

    local names = {}


    for floor, name
        in pairs(
            floorNames
        )
    do

        names[floor] =
            name
    end


    local state = {

        page =
            currentPage,

        currentFloor =
            currentFloor,

        maxFloor =
            maxFloor,

        targetFloor =
            targetFloor,

        moving =
            moving,

        calibrating =
            calibrating,

        normalSpeed =
            normalSpeed,

        autoHomeEnabled =
            autoHomeEnabled,

        autoHomeMinutes =
            autoHomeMinutes,

        floorNames =
            names,

        namingFloor =
            namingFloor
    }


    rednet.send(
        BRIDGE_ID,
        state,
        PROTOCOL_STATE
    )
end


-- ============================================================
-- AUTO HOME
-- ============================================================

local function cancelAutoHomeTimer()

    if autoHomeTimer ~= nil then

        os.cancelTimer(
            autoHomeTimer
        )

        autoHomeTimer = nil
    end
end


local function startAutoHomeTimer()

    cancelAutoHomeTimer()


    if not autoHomeEnabled then
        return
    end


    if currentFloor == nil then
        return
    end


    if currentFloor == 0 then
        return
    end


    if moving
        or calibrating
    then

        return
    end


    autoHomeTimer =
        os.startTimer(
            autoHomeMinutes
            * 60
        )
end


-- ============================================================
-- REDSTONE PULSE
-- ============================================================

local function pulse(side)

    redstone.setOutput(
        side,
        false
    )

    sleep(0.1)


    redstone.setOutput(
        side,
        true
    )

    sleep(0.2)


    redstone.setOutput(
        side,
        false
    )
end


-- ============================================================
-- HOME
-- ============================================================

local function home()

    cancelAutoHomeTimer()


    currentPage =
        "main"

    moving = true
    targetFloor = 0


    setNormalSpeed()

    sendState()


    if redstone.getInput(
        HOME
    ) then

        currentFloor = 0

        moving = false
        targetFloor = nil

        sendState()

        return true
    end


    redstone.setOutput(
        DIRECTION,
        true
    )


    pulse(
        SEQUENCER
    )


    local bottomArmed =
        not redstone.getInput(
            BOTTOM
        )


    while true do

        local homeNow =
            redstone.getInput(
                HOME
            )

        local bottomNow =
            redstone.getInput(
                BOTTOM
            )


        if not bottomArmed
            and not bottomNow
        then

            bottomArmed = true
        end


        -- HOME = harter Stop

        if homeNow then

            pulse(
                SEQUENCER
            )


            currentFloor = 0

            moving = false
            targetFloor = nil


            sendState()

            return true
        end


        -- BOTTOM unerwartet erneut erreicht

        if bottomArmed
            and bottomNow
        then

            pulse(
                SEQUENCER
            )


            currentFloor =
                maxFloor

            moving = false
            targetFloor = nil


            sendState()

            startAutoHomeTimer()

            return false
        end


        sleep(0.05)
    end
end


-- ============================================================
-- CALIBRATION
-- ============================================================

local function calibrate()

    cancelAutoHomeTimer()


    currentPage =
        "main"

    calibrating = true
    moving = true
    targetFloor = nil


    setCalibrationSpeed()

    sendState()


    -- ========================================================
    -- HOME FINDEN
    -- ========================================================

    if not redstone.getInput(
        HOME
    ) then

        redstone.setOutput(
            DIRECTION,
            true
        )


        pulse(
            SEQUENCER
        )


        while not redstone.getInput(
            HOME
        ) do

            sleep(0.05)
        end


        pulse(
            SEQUENCER
        )
    end


    currentFloor = 0

    sendState()

    sleep(0.5)


    -- ========================================================
    -- NACH UNTEN
    -- ========================================================

    local countedFloors = 0


    redstone.setOutput(
        DIRECTION,
        false
    )


    pulse(
        SEQUENCER
    )


    -- HOME verlassen

    while redstone.getInput(
        HOME
    ) do

        sleep(0.05)
    end


    -- ========================================================
    -- CONTACTS ZAEHLEN
    -- ========================================================

    while true do

        while
            not redstone.getInput(
                CONTACT
            )
            and
            not redstone.getInput(
                BOTTOM
            )
        do

            sleep(0.05)
        end


        -- BOTTOM ist die letzte Etage

        if redstone.getInput(
            BOTTOM
        ) then

            countedFloors =
                countedFloors + 1


            currentFloor =
                countedFloors


            pulse(
                SEQUENCER
            )


            sendState()

            break
        end


        -- normaler Floor Contact

        countedFloors =
            countedFloors + 1


        currentFloor =
            countedFloors


        sendState()


        while redstone.getInput(
            CONTACT
        ) do

            if redstone.getInput(
                BOTTOM
            ) then

                break
            end


            sleep(0.05)
        end
    end


    maxFloor =
        countedFloors


    saveConfig()

    sendState()

    sleep(0.75)


    -- ========================================================
    -- ZURUECK NACH HOME
    -- ========================================================

    redstone.setOutput(
        DIRECTION,
        true
    )


    pulse(
        SEQUENCER
    )


    while redstone.getInput(
        BOTTOM
    ) do

        sleep(0.05)
    end


    while not redstone.getInput(
        HOME
    ) do

        sleep(0.05)
    end


    pulse(
        SEQUENCER
    )


    currentFloor = 0

    setNormalSpeed()


    calibrating = false
    moving = false
    targetFloor = nil


    sendState()
end


-- ============================================================
-- MOVE
-- ============================================================

local function moveTo(target)

    if currentFloor == nil
        or maxFloor == nil
    then

        return
    end


    target =
        tonumber(target)


    if target == nil then
        return
    end


    if target < 0
        or target > maxFloor
    then

        return
    end


    if target == currentFloor then

        startAutoHomeTimer()

        return
    end


    cancelAutoHomeTimer()


    currentPage =
        "main"


    setNormalSpeed()


    local goingUp =
        target
        < currentFloor


    moving = true
    targetFloor = target


    sendState()


    if goingUp then

        redstone.setOutput(
            DIRECTION,
            true
        )

    else

        redstone.setOutput(
            DIRECTION,
            false
        )
    end


    -- aktuelle Sensorsignale merken

    local contactActive =
        redstone.getInput(
            CONTACT
        )

    local homeArmed =
        not redstone.getInput(
            HOME
        )

    local bottomArmed =
        not redstone.getInput(
            BOTTOM
        )


    pulse(
        SEQUENCER
    )


    while true do

        local homeNow =
            redstone.getInput(
                HOME
            )

        local bottomNow =
            redstone.getInput(
                BOTTOM
            )

        local contactNow =
            redstone.getInput(
                CONTACT
            )


        -- ====================================================
        -- START-ENDSCHALTER VERLASSEN
        -- ====================================================

        if not homeArmed
            and not homeNow
        then

            homeArmed = true
        end


        if not bottomArmed
            and not bottomNow
        then

            bottomArmed = true
        end


        -- ====================================================
        -- HOME = HARTER STOP
        -- ====================================================

        if homeArmed
            and homeNow
        then

            pulse(
                SEQUENCER
            )


            currentFloor = 0

            moving = false
            targetFloor = nil


            sendState()

            return
        end


        -- ====================================================
        -- BOTTOM = HARTER STOP
        -- ====================================================

        if bottomArmed
            and bottomNow
        then

            pulse(
                SEQUENCER
            )


            currentFloor =
                maxFloor

            moving = false
            targetFloor = nil


            sendState()

            startAutoHomeTimer()

            return
        end


        -- ====================================================
        -- NORMALER FLOOR CONTACT
        -- ====================================================

        if contactNow
            and not contactActive
        then

            if goingUp then

                currentFloor =
                    math.max(
                        0,
                        currentFloor - 1
                    )

            else

                currentFloor =
                    math.min(
                        maxFloor,
                        currentFloor + 1
                    )
            end


            -- Ziel erreicht

            if currentFloor
                == target
            then

                pulse(
                    SEQUENCER
                )


                moving = false
                targetFloor = nil


                sendState()

                startAutoHomeTimer()

                return

            else

                sendState()
            end
        end


        contactActive =
            contactNow


        sleep(0.05)
    end
end


-- ============================================================
-- SPEED SETTINGS
-- ============================================================

local function changeSpeed(amount)

    normalSpeed =
        normalSpeed
        + amount


    normalSpeed =
        math.max(
            50,
            math.min(
                100,
                normalSpeed
            )
        )


    setNormalSpeed()

    saveConfig()

    sendState()
end


-- ============================================================
-- AUTO HOME SETTINGS
-- ============================================================

local function toggleAutoHome()

    autoHomeEnabled =
        not autoHomeEnabled


    if autoHomeEnabled then

        startAutoHomeTimer()

    else

        cancelAutoHomeTimer()
    end


    saveConfig()

    sendState()
end


local function changeAutoHomeTime(
    amount
)

    autoHomeMinutes =
        autoHomeMinutes
        + amount


    autoHomeMinutes =
        math.max(
            1,
            math.min(
                60,
                autoHomeMinutes
            )
        )


    if autoHomeEnabled then
        startAutoHomeTimer()
    end


    saveConfig()

    sendState()
end


-- ============================================================
-- FLOOR NAME EDITOR
-- ============================================================

local function editFloorName(
    floor
)

    if maxFloor == nil then
        return
    end


    if floor < 0
        or floor > maxFloor
    then

        return
    end


    namingFloor =
        floor


    sendState()


    local oldName =
        floorNames[floor]


    term.setBackgroundColor(
        colors.black
    )

    term.setTextColor(
        colors.white
    )

    term.clear()

    term.setCursorPos(
        1,
        1
    )


    print(
        "=============================="
    )

    print(
        " AUFZUG - ETAGE BENENNEN"
    )

    print(
        "=============================="
    )

    print("")

    print(
        "Etage: "
        .. tostring(floor)
    )


    if oldName then

        print(
            "Aktuell: "
            .. oldName
        )

    else

        print(
            "Aktuell: -"
        )
    end


    print("")

    print(
        "Neuen Namen eingeben"
    )

    print(
        "Leer = Namen entfernen"
    )

    print("")

    write("> ")


    local newName =
        read()


    newName =
        string.gsub(
            newName,
            "=",
            ""
        )


    newName =
        string.match(
            newName,
            "^%s*(.-)%s*$"
        )


    if newName == "" then

        floorNames[floor] =
            nil

    else

        floorNames[floor] =
            string.sub(
                newName,
                1,
                24
            )
    end


    saveFloorNames()


    namingFloor = nil


    term.clear()

    term.setCursorPos(
        1,
        1
    )


    print(
        "Etage gespeichert."
    )


    sendState()
end


-- ============================================================
-- COMMAND HANDLER
-- ============================================================

local function handleCommand(
    message
)

    if type(message)
        ~= "table"
    then

        return
    end


    local action =
        message.action


    -- Panel fragt Zustand an

    if action
        == "request_state"
    then

        sendState()

        return
    end


    -- Während Fahrt/Kalibrierung
    -- keine Bedienung zulassen

    if moving
        or calibrating
    then

        return
    end


    -- ========================================================
    -- MAIN
    -- ========================================================

    if action
        == "go_floor"
    then

        if currentPage
            == "main"
        then

            moveTo(
                message.floor
            )
        end


    elseif action
        == "open_settings"
    then

        currentPage =
            "settings"

        sendState()


    -- ========================================================
    -- SETTINGS
    -- ========================================================

    elseif action
        == "speed_minus"
    then

        changeSpeed(-5)


    elseif action
        == "speed_plus"
    then

        changeSpeed(5)


    elseif action
        == "toggle_auto_home"
    then

        toggleAutoHome()


    elseif action
        == "auto_time_minus"
    then

        changeAutoHomeTime(-1)


    elseif action
        == "auto_time_plus"
    then

        changeAutoHomeTime(1)


    elseif action
        == "open_names"
    then

        if maxFloor ~= nil then

            currentPage =
                "names"

            sendState()
        end


    elseif action
        == "calibrate"
    then

        calibrate()


    elseif action
        == "back_main"
    then

        currentPage =
            "main"

        sendState()

        startAutoHomeTimer()


    -- ========================================================
    -- NAMES
    -- ========================================================

    elseif action
        == "edit_name"
    then

        if currentPage
            == "names"
        then

            local floor =
                tonumber(
                    message.floor
                )


            if floor ~= nil then

                editFloorName(
                    floor
                )
            end
        end


    elseif action
        == "back_settings"
    then

        currentPage =
            "settings"

        sendState()
    end
end


-- ============================================================
-- STARTUP
-- ============================================================

loadConfig()
loadFloorNames()

setNormalSpeed()


print(
    "Elevator Main #"
    .. os.getComputerID()
)

print(
    "Bridge: #"
    .. BRIDGE_ID
)

print(
    "Network: "
    .. NETWORK_SIDE
)


-- Beim Start erst HOME suchen

home()

sendState()


-- ============================================================
-- EVENT LOOP
-- ============================================================

while true do

    local event,
          p1,
          p2,
          p3 =
        os.pullEvent()


    -- ========================================================
    -- NETWORK
    -- ========================================================

    if event
        == "rednet_message"
    then

        local sender =
            p1

        local message =
            p2

        local protocol =
            p3


        if sender
            == BRIDGE_ID
            and protocol
                == PROTOCOL_COMMAND
        then

            handleCommand(
                message
            )
        end


    -- ========================================================
    -- AUTO HOME TIMER
    -- ========================================================

    elseif event
        == "timer"
    then

        local timerID =
            p1


        if autoHomeTimer ~= nil
            and timerID
                == autoHomeTimer
        then

            autoHomeTimer =
                nil


            if autoHomeEnabled
                and currentFloor ~= nil
                and currentFloor ~= 0
                and not moving
                and not calibrating
            then

                -- Nur automatisch fahren,
                -- wenn der Nutzer auf MAIN ist.

                if currentPage
                    == "main"
                then

                    moveTo(0)

                else

                    startAutoHomeTimer()
                end
            end
        end
    end
end
