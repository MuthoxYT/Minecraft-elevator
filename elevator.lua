-- ============================================================
-- CREATE + CC:TWEAKED ELEVATOR CONTROLLER
--
-- COMPUTER:
-- left   = Richtungs-Gearshift
-- back   = Sequenced Gearshift
-- right  = normale Etagen-Contacts
-- top    = HOME / Etage 0
-- bottom = BOTTOM / unterste Etage
-- front  = Wired Modem
--
-- WIRED NETWORK:
-- monitor_0
-- redstone_relay_0 = Geschwindigkeitssteuerung
--
-- Adjustable Chain Gearshift:
-- Signal 0  = 100 %
-- Signal 15 =  50 %
-- ============================================================


-- ============================================================
-- HARDWARE
-- ============================================================

local DIRECTION = "left"
local SEQUENCER = "back"
local CONTACT   = "right"
local HOME      = "top"
local BOTTOM    = "bottom"

local SPEED_RELAY_NAME = "redstone_relay_1"

-- DIE SEITE DES REDSTONE RELAYS,
-- AN DER DAS SIGNAL ZUM ADJUSTABLE CHAIN GEARSHIFT RAUSGEHT
local SPEED_SIDE = "right"

local CONFIG_FILE = "elevator.cfg"


-- ============================================================
-- ZUSTAND
-- ============================================================

local currentFloor = nil
local maxFloor = nil

local moving = false
local calibrating = false
local targetFloor = nil

-- normale Fahrgeschwindigkeit in Prozent
-- erlaubt: 50 - 100
local normalSpeed = 70


-- ============================================================
-- PERIPHERALS
-- ============================================================

local monitor = peripheral.find("monitor")

if not monitor then
    error("Kein Advanced Monitor gefunden!")
end


local speedRelay =
    peripheral.wrap(SPEED_RELAY_NAME)

if not speedRelay then
    error(
        "Redstone Relay '"
        .. SPEED_RELAY_NAME
        .. "' nicht gefunden!"
    )
end


monitor.setTextScale(0.5)

local WIDTH, HEIGHT =
    monitor.getSize()


-- ============================================================
-- UI
-- ============================================================

local buttons = {}

local calibrationButton = nil
local speedMinusButton = nil
local speedPlusButton = nil


-- ============================================================
-- SPEED
--
-- Adjustable Chain Gearshift:
--
-- 0  = 100 %
-- 15 = 50 %
--
-- Prozent -> Redstone 0-15
-- ============================================================

local function speedPercentToSignal(percent)

    if percent < 50 then
        percent = 50
    end

    if percent > 100 then
        percent = 100
    end


    -- 100 % -> 0
    --  50 % -> 15

    local signal =
        math.floor(
            ((100 - percent) / 50)
            * 15
            + 0.5
        )


    if signal < 0 then
        signal = 0
    end

    if signal > 15 then
        signal = 15
    end


    return signal
end


local function setSpeed(percent)

    local signal =
        speedPercentToSignal(
            percent
        )


    speedRelay.setAnalogOutput(
        SPEED_SIDE,
        signal
    )
end


local function setNormalSpeed()

    setSpeed(
        normalSpeed
    )
end


local function setCalibrationSpeed()

    -- Kalibrierung immer Vollgas
    setSpeed(100)
end


-- ============================================================
-- KONFIGURATION LADEN
--
-- Zeile 1 = maxFloor
-- Zeile 2 = normalSpeed
-- ============================================================

local function loadConfig()

    if not fs.exists(CONFIG_FILE) then
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

    file.close()


    local loadedFloor =
        tonumber(floorValue)

    local loadedSpeed =
        tonumber(speedValue)


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


    return maxFloor ~= nil
end


-- ============================================================
-- KONFIGURATION SPEICHERN
-- ============================================================

local function saveConfig()

    local file =
        fs.open(
            CONFIG_FILE,
            "w"
        )


    if not file then

        error(
            "Konfiguration konnte nicht gespeichert werden!"
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


    file.close()
end


-- ============================================================
-- REDSTONE PULS
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
-- TEXT ZENTRIEREN
-- ============================================================

local function centerText(y, text)

    local x =
        math.floor(
            (WIDTH - #text) / 2
        ) + 1


    if x < 1 then
        x = 1
    end


    monitor.setCursorPos(
        x,
        y
    )

    monitor.write(text)
end


-- ============================================================
-- FLAECHE FUELLEN
-- ============================================================

local function fillArea(
    x1,
    y1,
    x2,
    y2,
    color
)

    monitor.setBackgroundColor(
        color
    )


    for y = y1, y2 do

        monitor.setCursorPos(
            x1,
            y
        )


        monitor.write(
            string.rep(
                " ",
                math.max(
                    0,
                    x2 - x1 + 1
                )
            )
        )
    end
end


-- ============================================================
-- BUTTON ZEICHNEN
-- ============================================================

local function drawButton(
    x1,
    y1,
    x2,
    y2,
    label,
    background,
    foreground
)

    fillArea(
        x1,
        y1,
        x2,
        y2,
        background
    )


    monitor.setTextColor(
        foreground
    )


    local width =
        x2 - x1 + 1


    local labelX =
        x1
        + math.floor(
            (width - #label) / 2
        )


    local labelY =
        y1
        + math.floor(
            (y2 - y1) / 2
        )


    monitor.setCursorPos(
        labelX,
        labelY
    )

    monitor.write(label)
end


-- ============================================================
-- MONITOR
-- ============================================================

local function drawScreen()

    WIDTH, HEIGHT =
        monitor.getSize()


    monitor.setBackgroundColor(
        colors.black
    )

    monitor.setTextColor(
        colors.white
    )

    monitor.clear()


    buttons = {}

    calibrationButton = nil
    speedMinusButton = nil
    speedPlusButton = nil


    -- ========================================================
    -- HEADER
    -- ========================================================

    monitor.setBackgroundColor(
        colors.gray
    )

    monitor.setTextColor(
        colors.white
    )

    monitor.setCursorPos(
        1,
        1
    )

    monitor.clearLine()

    centerText(
        1,
        "AUFZUG"
    )


    -- ========================================================
    -- AKTUELLE ETAGE
    -- ========================================================

    monitor.setBackgroundColor(
        colors.black
    )

    monitor.setTextColor(
        colors.lightGray
    )

    centerText(
        3,
        "AKTUELLE ETAGE"
    )


    monitor.setTextColor(
        colors.white
    )


    if currentFloor ~= nil then

        centerText(
            4,
            tostring(currentFloor)
        )

    else

        centerText(
            4,
            "?"
        )
    end


    -- ========================================================
    -- STATUS
    -- ========================================================

    if calibrating then

        monitor.setTextColor(
            colors.orange
        )

        centerText(
            6,
            "KALIBRIERUNG - 100%"
        )


    elseif moving then

        monitor.setTextColor(
            colors.orange
        )


        if targetFloor ~= nil then

            centerText(
                6,
                "FAHRE ZU "
                .. tostring(
                    targetFloor
                )
            )

        else

            centerText(
                6,
                "FAHRT"
            )
        end


    else

        monitor.setTextColor(
            colors.lime
        )

        centerText(
            6,
            "BEREIT"
        )
    end


    -- ========================================================
    -- SPEED
    -- ========================================================

    monitor.setTextColor(
        colors.lightGray
    )

    centerText(
        8,
        "FAHRGESCHWINDIGKEIT"
    )


    local minusX1 =
        math.floor(
            WIDTH / 2
        ) - 9

    local minusX2 =
        minusX1 + 4


    local plusX1 =
        math.floor(
            WIDTH / 2
        ) + 5

    local plusX2 =
        plusX1 + 4


    local speedY1 = 9
    local speedY2 = 11


    local controlColor =
        colors.gray

    local controlText =
        colors.white


    if moving
        or calibrating
    then

        controlColor =
            colors.lightGray

        controlText =
            colors.gray
    end


    drawButton(
        minusX1,
        speedY1,
        minusX2,
        speedY2,
        "-",
        controlColor,
        controlText
    )


    drawButton(
        plusX1,
        speedY1,
        plusX2,
        speedY2,
        "+",
        controlColor,
        controlText
    )


    monitor.setBackgroundColor(
        colors.black
    )

    monitor.setTextColor(
        colors.white
    )


    local speedText =
        tostring(
            normalSpeed
        ) .. "%"


    centerText(
        10,
        speedText
    )


    speedMinusButton = {
        x1 = minusX1,
        y1 = speedY1,
        x2 = minusX2,
        y2 = speedY2
    }


    speedPlusButton = {
        x1 = plusX1,
        y1 = speedY1,
        x2 = plusX2,
        y2 = speedY2
    }


    -- ========================================================
    -- NOCH NICHT KALIBRIERT
    -- ========================================================

    if maxFloor == nil then

        monitor.setTextColor(
            colors.white
        )


        centerText(
            14,
            "Keine Kalibrierung"
        )


        local label =
            "KALIBRIEREN"


        local buttonWidth =
            math.min(
                math.max(
                    #label + 4,
                    16
                ),
                WIDTH - 4
            )


        local x1 =
            math.floor(
                (
                    WIDTH
                    - buttonWidth
                ) / 2
            ) + 1


        local x2 =
            x1
            + buttonWidth
            - 1


        local y1 =
            math.max(
                16,
                HEIGHT - 4
            )


        local y2 =
            math.min(
                HEIGHT - 1,
                y1 + 2
            )


        if y2 >= y1 then

            drawButton(
                x1,
                y1,
                x2,
                y2,
                label,
                colors.orange,
                colors.black
            )


            calibrationButton = {
                x1 = x1,
                y1 = y1,
                x2 = x2,
                y2 = y2
            }
        end


        monitor.setBackgroundColor(
            colors.black
        )

        monitor.setTextColor(
            colors.white
        )

        return
    end


    -- ========================================================
    -- ETAGENBUTTONS
    -- ========================================================

    local floorCount =
        maxFloor + 1


    local startY = 13


    local calibrationHeight = 3


    local calibrationY1 =
        HEIGHT
        - calibrationHeight


    local calibrationY2 =
        HEIGHT - 1


    local availableHeight =
        calibrationY1
        - startY
        - 1


    if availableHeight < 1 then
        availableHeight = 1
    end


    local buttonWidth = 5
    local buttonHeight = 3

    local gapX = 1
    local gapY = 1


    local columns =
        math.floor(
            (WIDTH + gapX)
            /
            (buttonWidth + gapX)
        )


    if columns < 1 then
        columns = 1
    end


    if columns > floorCount then
        columns = floorCount
    end


    local rows =
        math.ceil(
            floorCount
            / columns
        )


    while
        rows
            * (
                buttonHeight
                + gapY
            )
            - gapY
            > availableHeight
        and columns < floorCount
    do

        columns =
            columns + 1


        rows =
            math.ceil(
                floorCount
                / columns
            )
    end


    if
        rows
            * (
                buttonHeight
                + gapY
            )
            - gapY
        > availableHeight
    then

        buttonHeight = 1
        gapY = 0
    end


    local totalWidth =
        columns
        * buttonWidth
        + (
            columns - 1
        ) * gapX


    local startX =
        math.floor(
            (
                WIDTH
                - totalWidth
            ) / 2
        ) + 1


    if startX < 1 then
        startX = 1
    end


    local index = 0


    for floor = 0, maxFloor do

        local column =
            index % columns


        local row =
            math.floor(
                index / columns
            )


        local x1 =
            startX
            + column
            * (
                buttonWidth
                + gapX
            )


        local y1 =
            startY
            + row
            * (
                buttonHeight
                + gapY
            )


        local x2 =
            math.min(
                WIDTH,
                x1
                + buttonWidth
                - 1
            )


        local y2 =
            math.min(
                calibrationY1 - 2,
                y1
                + buttonHeight
                - 1
            )


        if y1 <= y2 then

            local background =
                colors.gray

            local foreground =
                colors.white


            if floor ==
                currentFloor
            then

                background =
                    colors.green


            elseif moving
                or calibrating
            then

                background =
                    colors.lightGray

                foreground =
                    colors.gray
            end


            drawButton(
                x1,
                y1,
                x2,
                y2,
                tostring(floor),
                background,
                foreground
            )


            buttons[
                #buttons + 1
            ] = {

                floor = floor,

                x1 = x1,
                y1 = y1,

                x2 = x2,
                y2 = y2
            }
        end


        index =
            index + 1
    end


    -- ========================================================
    -- KALIBRIEREN
    -- ========================================================

    local label =
        "KALIBRIEREN"


    local buttonWidth =
        math.min(
            math.max(
                #label + 4,
                16
            ),
            WIDTH - 4
        )


    local x1 =
        math.floor(
            (
                WIDTH
                - buttonWidth
            ) / 2
        ) + 1


    local x2 =
        x1
        + buttonWidth
        - 1


    local y1 =
        calibrationY1


    local y2 =
        calibrationY2


    if not moving
        and not calibrating
    then

        drawButton(
            x1,
            y1,
            x2,
            y2,
            label,
            colors.orange,
            colors.black
        )

    else

        drawButton(
            x1,
            y1,
            x2,
            y2,
            label,
            colors.gray,
            colors.lightGray
        )
    end


    calibrationButton = {

        x1 = x1,
        y1 = y1,

        x2 = x2,
        y2 = y2
    }


    monitor.setBackgroundColor(
        colors.black
    )

    monitor.setTextColor(
        colors.white
    )
end


-- ============================================================
-- HIT TEST
-- ============================================================

local function buttonTouched(
    button,
    x,
    y
)

    if not button then
        return false
    end


    return
        x >= button.x1
        and x <= button.x2
        and y >= button.y1
        and y <= button.y2
end


-- ============================================================
-- NAECHSTE ETAGE
-- ============================================================

local function waitForNextFloor()

    while redstone.getInput(
        CONTACT
    ) do

        sleep(0.05)
    end


    while not redstone.getInput(
        CONTACT
    ) do

        sleep(0.05)
    end
end


-- ============================================================
-- HOME
-- ============================================================

local function home()

    moving = true
    targetFloor = 0


    -- Homing mit normaler
    -- Fahrgeschwindigkeit
    setNormalSpeed()


    drawScreen()


    if redstone.getInput(
        HOME
    ) then

        currentFloor = 0

        moving = false
        targetFloor = nil

        drawScreen()

        return
    end


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


    currentFloor = 0

    moving = false
    targetFloor = nil


    drawScreen()
end


-- ============================================================
-- KALIBRIERUNG
-- ============================================================

local function calibrate()

    calibrating = true
    moving = true
    targetFloor = nil


    -- Kalibrierung immer 100 %
    setCalibrationSpeed()


    drawScreen()


    -- ========================================================
    -- HOME SUCHEN
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


    drawScreen()

    sleep(0.5)


    -- ========================================================
    -- RUNTER
    -- ========================================================

    local countedFloors = 0


    redstone.setOutput(
        DIRECTION,
        false
    )


    pulse(
        SEQUENCER
    )


    while redstone.getInput(
        HOME
    ) do

        sleep(0.05)
    end


    -- ========================================================
    -- ZAEHLEN
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


        -- ====================================================
        -- BOTTOM
        -- ====================================================

        if redstone.getInput(
            BOTTOM
        ) then

            countedFloors =
                countedFloors + 1


            currentFloor =
                countedFloors


            drawScreen()


            pulse(
                SEQUENCER
            )


            break
        end


        -- ====================================================
        -- NORMALER CONTACT
        -- ====================================================

        countedFloors =
            countedFloors + 1


        currentFloor =
            countedFloors


        drawScreen()


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


    -- ========================================================
    -- SPEICHERN
    -- ========================================================

    maxFloor =
        countedFloors


    saveConfig()


    drawScreen()

    sleep(1)


    -- ========================================================
    -- WIEDER NACH HOME
    -- ========================================================

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


    currentFloor = 0


    -- Nach Kalibrierung wieder
    -- normale Geschwindigkeit
    setNormalSpeed()


    calibrating = false
    moving = false
    targetFloor = nil


    drawScreen()
end


-- ============================================================
-- FAHRT
-- ============================================================

local function moveTo(target)

    if currentFloor == nil then
        return
    end


    if target == currentFloor then
        return
    end


    -- Gewaehlte Geschwindigkeit
    setNormalSpeed()


    moving = true
    targetFloor = target


    drawScreen()


    local goingUp =
        target < currentFloor


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


    pulse(
        SEQUENCER
    )


    -- ========================================================
    -- HOME
    -- ========================================================

    if target == 0 then

        while not redstone.getInput(
            HOME
        ) do

            sleep(0.05)
        end


        pulse(
            SEQUENCER
        )


        currentFloor = 0

        moving = false
        targetFloor = nil


        drawScreen()

        return
    end


    -- ========================================================
    -- BOTTOM
    -- ========================================================

    if
        target == maxFloor
        and not goingUp
    then

        while not redstone.getInput(
            BOTTOM
        ) do


            if redstone.getInput(
                CONTACT
            ) then

                currentFloor =
                    currentFloor + 1


                drawScreen()


                while redstone.getInput(
                    CONTACT
                ) do

                    sleep(0.05)
                end

            else

                sleep(0.05)
            end
        end


        pulse(
            SEQUENCER
        )


        currentFloor =
            maxFloor


        moving = false
        targetFloor = nil


        drawScreen()

        return
    end


    -- ========================================================
    -- NORMALE ETAGE
    -- ========================================================

    while currentFloor ~= target do

        waitForNextFloor()


        if goingUp then

            currentFloor =
                currentFloor - 1

        else

            currentFloor =
                currentFloor + 1
        end


        drawScreen()
    end


    pulse(
        SEQUENCER
    )


    moving = false
    targetFloor = nil


    drawScreen()
end


-- ============================================================
-- ETAGENBUTTON ERMITTELN
-- ============================================================

local function getTouchedFloor(
    x,
    y
)

    for _, button
        in ipairs(buttons)
    do

        if buttonTouched(
            button,
            x,
            y
        ) then

            return button.floor
        end
    end


    return nil
end


-- ============================================================
-- SPEED AENDERN
-- ============================================================

local function changeSpeed(amount)

    normalSpeed =
        normalSpeed + amount


    if normalSpeed < 50 then
        normalSpeed = 50
    end


    if normalSpeed > 100 then
        normalSpeed = 100
    end


    -- Direkt an Hardware schicken
    setNormalSpeed()


    -- Einstellung dauerhaft speichern
    saveConfig()


    drawScreen()
end


-- ============================================================
-- START
-- ============================================================

loadConfig()


-- Gewaehlte normale Geschwindigkeit
-- sofort setzen
setNormalSpeed()


-- Referenzposition bestimmen
home()


drawScreen()


-- ============================================================
-- HAUPTSCHLEIFE
-- ============================================================

while true do

    local event,
          side,
          x,
          y =
        os.pullEvent(
            "monitor_touch"
        )


    if not moving
        and not calibrating
    then


        -- ====================================================
        -- SPEED -
        -- ====================================================

        if buttonTouched(
            speedMinusButton,
            x,
            y
        ) then

            changeSpeed(-5)


        -- ====================================================
        -- SPEED +
        -- ====================================================

        elseif buttonTouched(
            speedPlusButton,
            x,
            y
        ) then

            changeSpeed(5)


        -- ====================================================
        -- KALIBRIEREN
        -- ====================================================

        elseif buttonTouched(
            calibrationButton,
            x,
            y
        ) then

            calibrate()


        -- ====================================================
        -- ETAGE
        -- ====================================================

        else

            local selectedFloor =
                getTouchedFloor(
                    x,
                    y
                )


            if
                selectedFloor ~= nil
                and maxFloor ~= nil
            then

                moveTo(
                    selectedFloor
                )
            end
        end
    end
end
