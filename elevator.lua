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
-- monitor
-- redstone_relay_1 = Geschwindigkeit
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

-- Seite des Relays zum Adjustable Chain Gearshift
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

local normalSpeed = 70

-- "main" oder "settings"
local currentPage = "main"


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
-- BUTTONS
-- ============================================================

local floorButtons = {}

local settingsButton = nil

local speedMinusButton = nil
local speedPlusButton = nil

local calibrationButton = nil
local backButton = nil


-- ============================================================
-- SPEED
-- ============================================================

local function speedPercentToSignal(percent)

    percent =
        math.max(
            50,
            math.min(
                100,
                percent
            )
        )


    -- 100 % -> Signal 0
    --  50 % -> Signal 15

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

    setSpeed(100)
end


-- ============================================================
-- KONFIGURATION LADEN
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
-- UI HILFSFUNKTIONEN
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


local function resetButtons()

    floorButtons = {}

    settingsButton = nil

    speedMinusButton = nil
    speedPlusButton = nil

    calibrationButton = nil
    backButton = nil
end


local function clearScreen()

    WIDTH, HEIGHT =
        monitor.getSize()


    monitor.setBackgroundColor(
        colors.black
    )

    monitor.setTextColor(
        colors.white
    )

    monitor.clear()

    resetButtons()
end


-- ============================================================
-- HEADER
-- ============================================================

local function drawHeader(title)

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
        title
    )


    monitor.setBackgroundColor(
        colors.black
    )
end


-- ============================================================
-- MAIN SCREEN
-- ============================================================

local function drawMain()

    clearScreen()

    drawHeader(
        "AUFZUG"
    )


    -- ========================================================
    -- AKTUELLE ETAGE
    -- ========================================================

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
            "KALIBRIERUNG"
        )


    elseif moving then

        monitor.setTextColor(
            colors.orange
        )


        local directionText = ""

        if targetFloor ~= nil
            and currentFloor ~= nil
        then

            if targetFloor
                < currentFloor
            then

                directionText = "^ "

            else

                directionText = "v "
            end
        end


        if targetFloor ~= nil then

            centerText(
                6,
                directionText
                .. "FAHRT ZU "
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
    -- KEINE KALIBRIERUNG
    -- ========================================================

    if maxFloor == nil then

        monitor.setTextColor(
            colors.white
        )

        centerText(
            10,
            "Keine Etagen"
        )

        centerText(
            11,
            "kalibriert"
        )

    else

        -- ====================================================
        -- ETAGENRASTER
        -- ====================================================

        local floorCount =
            maxFloor + 1


        local startY = 9

        -- Platz fuer Einstellungen unten
        local bottomReserved = 5

        local endY =
            HEIGHT
            - bottomReserved


        local availableHeight =
            endY
            - startY
            + 1


        -- Grundgroesse
        local buttonWidth = 5
        local buttonHeight = 3

        local gapX = 1
        local gapY = 1


        -- ====================================================
        -- SPALTEN BERECHNEN
        -- ====================================================

        local columns =
            math.floor(
                (WIDTH + gapX)
                /
                (
                    buttonWidth
                    + gapX
                )
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


        -- ====================================================
        -- FALLS ZU HOCH:
        -- MEHR SPALTEN
        -- ====================================================

        while
            rows
                * (
                    buttonHeight
                    + gapY
                )
                - gapY
                > availableHeight
            and
            columns < floorCount
        do

            columns =
                columns + 1


            rows =
                math.ceil(
                    floorCount
                    / columns
                )
        end


        -- ====================================================
        -- FALLS IMMER NOCH ZU HOCH:
        -- KLEINERE BUTTONS
        -- ====================================================

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


        -- ====================================================
        -- BUTTONBREITE ANPASSEN
        -- ====================================================

        local totalWidth =
            columns
            * buttonWidth
            + (
                columns - 1
            )
            * gapX


        if totalWidth > WIDTH then

            buttonWidth =
                math.max(
                    3,
                    math.floor(
                        (
                            WIDTH
                            - (
                                columns - 1
                            )
                            * gapX
                        )
                        / columns
                    )
                )


            totalWidth =
                columns
                * buttonWidth
                + (
                    columns - 1
                )
                * gapX
        end


        local startX =
            math.floor(
                (
                    WIDTH
                    - totalWidth
                )
                / 2
            ) + 1


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
                    endY,
                    y1
                    + buttonHeight
                    - 1
                )


            if y1 <= endY
                and y1 <= y2
            then

                local background =
                    colors.gray

                local foreground =
                    colors.white


                -- Aktuelle Etage
                if floor
                    == currentFloor
                then

                    background =
                        colors.green


                -- Ziel
                elseif moving
                    and floor
                        == targetFloor
                then

                    background =
                        colors.orange


                -- Waehrend Fahrt
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


                floorButtons[
                    #floorButtons + 1
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
    end


    -- ========================================================
    -- EINSTELLUNGEN
    -- ========================================================

    local label =
        "EINSTELLUNGEN"


    local buttonWidth =
        math.min(
            math.max(
                #label + 4,
                18
            ),
            WIDTH - 4
        )


    local x1 =
        math.floor(
            (
                WIDTH
                - buttonWidth
            )
            / 2
        ) + 1


    local x2 =
        x1
        + buttonWidth
        - 1


    local y1 =
        HEIGHT - 3

    local y2 =
        HEIGHT - 1


    if not moving
        and not calibrating
    then

        drawButton(
            x1,
            y1,
            x2,
            y2,
            label,
            colors.gray,
            colors.white
        )

    else

        drawButton(
            x1,
            y1,
            x2,
            y2,
            label,
            colors.lightGray,
            colors.gray
        )
    end


    settingsButton = {

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
-- SETTINGS SCREEN
-- ============================================================

local function drawSettings()

    clearScreen()

    drawHeader(
        "EINSTELLUNGEN"
    )


    -- ========================================================
    -- SPEED
    -- ========================================================

    monitor.setTextColor(
        colors.lightGray
    )

    centerText(
        4,
        "FAHRGESCHWINDIGKEIT"
    )


    local center =
        math.floor(
            WIDTH / 2
        )


    local minusX1 =
        center - 10

    local minusX2 =
        minusX1 + 5


    local plusX1 =
        center + 5

    local plusX2 =
        plusX1 + 5


    local speedY1 = 6
    local speedY2 = 8


    drawButton(
        minusX1,
        speedY1,
        minusX2,
        speedY2,
        "-",
        colors.gray,
        colors.white
    )


    drawButton(
        plusX1,
        speedY1,
        plusX2,
        speedY2,
        "+",
        colors.gray,
        colors.white
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


    monitor.setBackgroundColor(
        colors.black
    )

    monitor.setTextColor(
        colors.white
    )


    centerText(
        7,
        tostring(
            normalSpeed
        ) .. "%"
    )


    -- ========================================================
    -- ERKANNTE ETAGEN
    -- ========================================================

    monitor.setTextColor(
        colors.lightGray
    )

    centerText(
        11,
        "ERKANNTE ETAGEN"
    )


    monitor.setTextColor(
        colors.white
    )


    if maxFloor ~= nil then

        centerText(
            12,
            tostring(
                maxFloor + 1
            )
        )

    else

        centerText(
            12,
            "NICHT KALIBRIERT"
        )
    end


    -- ========================================================
    -- KALIBRIEREN
    -- ========================================================

    local calibrationLabel =
        "KALIBRIEREN"


    local calibrationWidth =
        math.min(
            20,
            WIDTH - 4
        )


    local calibrationX1 =
        math.floor(
            (
                WIDTH
                - calibrationWidth
            )
            / 2
        ) + 1


    local calibrationX2 =
        calibrationX1
        + calibrationWidth
        - 1


    local calibrationY1 =
        15

    local calibrationY2 =
        17


    drawButton(
        calibrationX1,
        calibrationY1,
        calibrationX2,
        calibrationY2,
        calibrationLabel,
        colors.orange,
        colors.black
    )


    calibrationButton = {

        x1 = calibrationX1,
        y1 = calibrationY1,

        x2 = calibrationX2,
        y2 = calibrationY2
    }


    -- ========================================================
    -- ZURUECK
    -- ========================================================

    local backLabel =
        "ZURUECK"


    local backWidth =
        math.min(
            16,
            WIDTH - 4
        )


    local backX1 =
        math.floor(
            (
                WIDTH
                - backWidth
            )
            / 2
        ) + 1


    local backX2 =
        backX1
        + backWidth
        - 1


    local backY1 =
        HEIGHT - 3

    local backY2 =
        HEIGHT - 1


    drawButton(
        backX1,
        backY1,
        backX2,
        backY2,
        backLabel,
        colors.gray,
        colors.white
    )


    backButton = {

        x1 = backX1,
        y1 = backY1,

        x2 = backX2,
        y2 = backY2
    }


    monitor.setBackgroundColor(
        colors.black
    )

    monitor.setTextColor(
        colors.white
    )
end


-- ============================================================
-- SCREEN ZEICHNEN
-- ============================================================

local function drawScreen()

    if currentPage
        == "settings"
    then

        drawSettings()

    else

        drawMain()
    end
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

    currentPage = "main"

    moving = true
    targetFloor = 0


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

    -- Zur Hauptseite wechseln,
    -- damit man den Vorgang sieht.
    currentPage = "main"

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
    -- ETAGEN ZAEHLEN
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
        -- BOTTOM = LETZTE ETAGE
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
    -- WIEDER HOCH ZU HOME
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


    -- Normale Geschwindigkeit wiederherstellen
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


    currentPage = "main"

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


    setNormalSpeed()

    saveConfig()

    drawScreen()
end


-- ============================================================
-- ETAGENBUTTON SUCHEN
-- ============================================================

local function getTouchedFloor(
    x,
    y
)

    for _, button
        in ipairs(
            floorButtons
        )
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
-- START
-- ============================================================

loadConfig()

setNormalSpeed()

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


    -- ========================================================
    -- MAIN
    -- ========================================================

    if currentPage
        == "main"
    then

        if not moving
            and not calibrating
        then

            -- Einstellungen
            if buttonTouched(
                settingsButton,
                x,
                y
            ) then

                currentPage =
                    "settings"

                drawScreen()


            else

                -- Etage
                local selectedFloor =
                    getTouchedFloor(
                        x,
                        y
                    )


                if selectedFloor
                    ~= nil
                    and maxFloor
                    ~= nil
                then

                    moveTo(
                        selectedFloor
                    )
                end
            end
        end


    -- ========================================================
    -- SETTINGS
    -- ========================================================

    elseif currentPage
        == "settings"
    then


        -- SPEED -
        if buttonTouched(
            speedMinusButton,
            x,
            y
        ) then

            changeSpeed(-5)


        -- SPEED +
        elseif buttonTouched(
            speedPlusButton,
            x,
            y
        ) then

            changeSpeed(5)


        -- KALIBRIEREN
        elseif buttonTouched(
            calibrationButton,
            x,
            y
        ) then

            calibrate()


        -- ZURUECK
        elseif buttonTouched(
            backButton,
            x,
            y
        ) then

            currentPage =
                "main"

            drawScreen()
        end
    end
end
