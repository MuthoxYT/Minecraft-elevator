-- ============================================================
-- CREATE + CC:TWEAKED ELEVATOR CONTROLLER
--
-- REDSTONE:
-- left   = Richtungs-Gearshift
-- back   = Sequenced Gearshift
-- right  = normale Etagen-Contacts
-- top    = HOME / oberste Etage 0
-- bottom = BOTTOM / unterste Etage
--
-- DIRECTION:
-- true  = hoch
-- false = runter
-- ============================================================


-- ============================================================
-- KONFIGURATION
-- ============================================================

local DIRECTION = "left"
local SEQUENCER = "back"
local CONTACT   = "right"
local HOME      = "top"
local BOTTOM    = "bottom"

local CONFIG_FILE = "elevator.cfg"

local currentFloor = nil
local maxFloor = nil

local moving = false
local calibrating = false
local targetFloor = nil


-- ============================================================
-- MONITOR
-- ============================================================

local monitor = peripheral.find("monitor")

if not monitor then
    error("Kein Advanced Monitor gefunden!")
end

monitor.setTextScale(0.5)

local WIDTH, HEIGHT = monitor.getSize()

local buttons = {}
local calibrationButton = nil


-- ============================================================
-- KONFIGURATION LADEN
-- ============================================================

local function loadConfig()

    if not fs.exists(CONFIG_FILE) then
        return false
    end

    local file = fs.open(CONFIG_FILE, "r")

    if not file then
        return false
    end

    local value = file.readLine()
    file.close()

    local number = tonumber(value)

    if not number or number < 1 then
        return false
    end

    maxFloor = number

    return true
end


-- ============================================================
-- KONFIGURATION SPEICHERN
-- ============================================================

local function saveConfig()

    local file = fs.open(CONFIG_FILE, "w")

    if not file then
        error("Konfiguration konnte nicht gespeichert werden!")
    end

    file.writeLine(tostring(maxFloor))
    file.close()
end


-- ============================================================
-- REDSTONE-PULS
-- ============================================================

local function pulse(side)

    redstone.setOutput(side, false)
    sleep(0.1)

    redstone.setOutput(side, true)
    sleep(0.2)

    redstone.setOutput(side, false)
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

    monitor.setCursorPos(x, y)
    monitor.write(text)
end


-- ============================================================
-- FLAECHE ZEICHNEN
-- ============================================================

local function fillArea(x1, y1, x2, y2, color)

    monitor.setBackgroundColor(color)

    for y = y1, y2 do

        monitor.setCursorPos(x1, y)

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
-- MONITOR ZEICHNEN
-- ============================================================

local function drawScreen()

    WIDTH, HEIGHT = monitor.getSize()

    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
    monitor.clear()

    buttons = {}
    calibrationButton = nil


    -- ========================================================
    -- TITEL
    -- ========================================================

    monitor.setBackgroundColor(colors.gray)
    monitor.setTextColor(colors.white)

    monitor.setCursorPos(1, 1)
    monitor.clearLine()

    centerText(1, "AUFZUG")


    -- ========================================================
    -- AKTUELLE ETAGE
    -- ========================================================

    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.lightGray)

    centerText(3, "AKTUELLE ETAGE")

    monitor.setTextColor(colors.white)

    if currentFloor ~= nil then

        centerText(
            4,
            tostring(currentFloor)
        )

    else

        centerText(4, "?")
    end


    -- ========================================================
    -- STATUS
    -- ========================================================

    if calibrating then

        monitor.setTextColor(colors.orange)

        centerText(
            6,
            "KALIBRIERUNG"
        )

    elseif moving then

        monitor.setTextColor(colors.orange)

        if targetFloor ~= nil then

            centerText(
                6,
                "FAHRE ZU "
                    .. tostring(targetFloor)
            )

        else

            centerText(
                6,
                "FAHRT"
            )
        end

    else

        monitor.setTextColor(colors.lime)

        centerText(
            6,
            "BEREIT"
        )
    end


    -- ========================================================
    -- NOCH NICHT KALIBRIERT
    -- ========================================================

    if maxFloor == nil then

        monitor.setTextColor(colors.white)

        centerText(
            9,
            "Keine Kalibrierung"
        )

        centerText(
            10,
            "vorhanden"
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
                (WIDTH - buttonWidth) / 2
            ) + 1

        local x2 =
            x1 + buttonWidth - 1

        local y1 =
            math.max(
                12,
                HEIGHT - 4
            )

        local y2 =
            math.min(
                HEIGHT - 1,
                y1 + 2
            )


        if y2 >= y1 then

            fillArea(
                x1,
                y1,
                x2,
                y2,
                colors.orange
            )

            monitor.setTextColor(
                colors.black
            )

            local labelX =
                x1
                + math.floor(
                    (
                        buttonWidth
                        - #label
                    ) / 2
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

    local startY = 8

    local calibrationHeight = 3

    local calibrationY1 =
        HEIGHT - calibrationHeight

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
            floorCount / columns
        )


    while
        rows
            * (buttonHeight + gapY)
            - gapY
            > availableHeight
        and columns < floorCount
    do

        columns = columns + 1

        rows =
            math.ceil(
                floorCount / columns
            )
    end


    if
        rows
            * (buttonHeight + gapY)
            - gapY
        > availableHeight
    then

        buttonHeight = 1
        gapY = 0
    end


    local totalWidth =
        columns * buttonWidth
        + (columns - 1) * gapX

    local startX =
        math.floor(
            (WIDTH - totalWidth) / 2
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
                * (buttonWidth + gapX)

        local y1 =
            startY
            + row
                * (buttonHeight + gapY)

        local x2 =
            math.min(
                WIDTH,
                x1 + buttonWidth - 1
            )

        local y2 =
            math.min(
                calibrationY1 - 2,
                y1 + buttonHeight - 1
            )


        if y1 <= y2 then

            local background =
                colors.gray

            local foreground =
                colors.white


            if floor == currentFloor then

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


            local label =
                tostring(floor)

            local actualWidth =
                x2 - x1 + 1

            local labelX =
                x1
                + math.floor(
                    (
                        actualWidth
                        - #label
                    ) / 2
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


        index = index + 1
    end


    -- ========================================================
    -- KALIBRIEREN BUTTON
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
            (WIDTH - buttonWidth) / 2
        ) + 1

    local x2 =
        x1 + buttonWidth - 1

    local y1 =
        calibrationY1

    local y2 =
        calibrationY2


    if not moving
        and not calibrating
    then

        fillArea(
            x1,
            y1,
            x2,
            y2,
            colors.orange
        )

        monitor.setTextColor(
            colors.black
        )

    else

        fillArea(
            x1,
            y1,
            x2,
            y2,
            colors.gray
        )

        monitor.setTextColor(
            colors.lightGray
        )
    end


    local labelX =
        x1
        + math.floor(
            (
                buttonWidth
                - #label
            ) / 2
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
-- AUF NAECHSTEN NORMALEN CONTACT WARTEN
-- ============================================================

local function waitForNextFloor()

    -- Falls wir gerade auf einem Contact stehen:
    -- erst verlassen.
    while redstone.getInput(CONTACT) do
        sleep(0.05)
    end


    -- Dann naechsten Contact erreichen.
    while not redstone.getInput(CONTACT) do
        sleep(0.05)
    end
end


-- ============================================================
-- HOMING
-- ============================================================

local function home()

    moving = true
    targetFloor = 0

    drawScreen()


    -- Bereits auf Home?
    if redstone.getInput(HOME) then

        currentFloor = 0

        moving = false
        targetFloor = nil

        drawScreen()

        return
    end


    -- Richtung hoch
    redstone.setOutput(
        DIRECTION,
        true
    )

    -- Start
    pulse(SEQUENCER)


    -- Auf Home warten
    while not redstone.getInput(HOME) do
        sleep(0.05)
    end


    -- Stop
    pulse(SEQUENCER)


    currentFloor = 0

    moving = false
    targetFloor = nil

    drawScreen()
end


-- ============================================================
-- KALIBRIERUNG
--
-- HOME   = ETAGE 0
-- CONTACTS DAZWISCHEN = 1, 2, 3, ...
-- BOTTOM = LETZTE ETAGE
-- ============================================================

local function calibrate()

    calibrating = true
    moving = true
    targetFloor = nil

    drawScreen()


    -- ========================================================
    -- 1. ZUERST HOME SUCHEN
    -- ========================================================

    if not redstone.getInput(HOME) then

        redstone.setOutput(
            DIRECTION,
            true
        )

        pulse(SEQUENCER)


        while not redstone.getInput(HOME) do
            sleep(0.05)
        end


        pulse(SEQUENCER)
    end


    currentFloor = 0

    drawScreen()

    sleep(0.5)


    -- ========================================================
    -- 2. VON HOME NACH UNTEN FAHREN
    -- ========================================================

    local countedFloors = 0


    -- Richtung runter
    redstone.setOutput(
        DIRECTION,
        false
    )

    -- Start
    pulse(SEQUENCER)


    -- Home komplett verlassen
    while redstone.getInput(HOME) do
        sleep(0.05)
    end


    -- ========================================================
    -- 3. ETAGEN ZAEHLEN
    -- ========================================================

    while true do

        -- Warten, bis entweder
        -- CONTACT oder BOTTOM aktiv wird.
        while
            not redstone.getInput(CONTACT)
            and not redstone.getInput(BOTTOM)
        do
            sleep(0.05)
        end


        -- ====================================================
        -- BOTTOM ERREICHT
        -- ====================================================

        if redstone.getInput(BOTTOM) then

            -- Bottom ist SELBST die letzte Etage.
            countedFloors =
                countedFloors + 1

            currentFloor =
                countedFloors

            drawScreen()

            -- Fahrt stoppen
            pulse(SEQUENCER)

            break
        end


        -- ====================================================
        -- NORMALER CONTACT ERREICHT
        -- ====================================================

        countedFloors =
            countedFloors + 1

        currentFloor =
            countedFloors

        drawScreen()


        -- WICHTIG:
        -- Diesen Contact komplett verlassen,
        -- bevor ein weiterer gezaehlt werden darf.
        while redstone.getInput(CONTACT) do

            -- Falls Bottom bereits waehrenddessen
            -- erreicht wird, verlassen wir diese
            -- Schleife.
            if redstone.getInput(BOTTOM) then
                break
            end

            sleep(0.05)
        end


        -- Falls Bottom inzwischen aktiv ist,
        -- wird er im naechsten Schleifendurchlauf
        -- als letzte Etage verarbeitet.
    end


    -- ========================================================
    -- 4. ERMITTELTE ETAGENZAHL SPEICHERN
    -- ========================================================

    maxFloor =
        countedFloors

    saveConfig()

    drawScreen()

    sleep(1)


    -- ========================================================
    -- 5. ZURUECK ZU HOME
    -- ========================================================

    redstone.setOutput(
        DIRECTION,
        true
    )

    pulse(SEQUENCER)


    while not redstone.getInput(HOME) do
        sleep(0.05)
    end


    pulse(SEQUENCER)


    currentFloor = 0

    calibrating = false
    moving = false
    targetFloor = nil

    drawScreen()
end


-- ============================================================
-- ZU ETAGE FAHREN
-- ============================================================

local function moveTo(target)

    if currentFloor == nil then
        return
    end


    if target == currentFloor then
        return
    end


    moving = true
    targetFloor = target

    drawScreen()


    local goingUp =
        target < currentFloor


    -- Richtung setzen
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


    -- Start
    pulse(SEQUENCER)


    -- ========================================================
    -- ZIEL = HOME / ETAGE 0
    -- ========================================================

    if target == 0 then

        while not redstone.getInput(HOME) do
            sleep(0.05)
        end


        pulse(SEQUENCER)


        currentFloor = 0

        moving = false
        targetFloor = nil

        drawScreen()

        return
    end


    -- ========================================================
    -- ZIEL = UNTERSTE ETAGE
    --
    -- Hier benutzen wir BOTTOM als absoluten Sensor.
    -- ========================================================

    if target == maxFloor
        and not goingUp
    then

        while not redstone.getInput(BOTTOM) do

            -- Zwischenetagen trotzdem anzeigen
            if redstone.getInput(CONTACT) then

                currentFloor =
                    currentFloor + 1

                drawScreen()


                while redstone.getInput(CONTACT) do
                    sleep(0.05)
                end

            else

                sleep(0.05)
            end
        end


        pulse(SEQUENCER)

        currentFloor =
            maxFloor

        moving = false
        targetFloor = nil

        drawScreen()

        return
    end


    -- ========================================================
    -- NORMALE ETAGEN
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


    -- Ziel erreicht
    pulse(SEQUENCER)


    moving = false
    targetFloor = nil

    drawScreen()
end


-- ============================================================
-- TOUCH: ETAGE
-- ============================================================

local function getTouchedFloor(x, y)

    for _, button
        in ipairs(buttons)
    do

        if
            x >= button.x1
            and x <= button.x2
            and y >= button.y1
            and y <= button.y2
        then

            return button.floor
        end
    end


    return nil
end


-- ============================================================
-- TOUCH: KALIBRIEREN
-- ============================================================

local function calibrationTouched(x, y)

    if not calibrationButton then
        return false
    end


    return
        x >= calibrationButton.x1
        and x <= calibrationButton.x2
        and y >= calibrationButton.y1
        and y <= calibrationButton.y2
end


-- ============================================================
-- PROGRAMMSTART
-- ============================================================

loadConfig()

-- Bei jedem Neustart nur Home suchen.
home()

drawScreen()


-- ============================================================
-- HAUPTSCHLEIFE
-- ============================================================

while true do

    local event, side, x, y =
        os.pullEvent(
            "monitor_touch"
        )


    if not moving
        and not calibrating
    then

        -- Kalibrierung gedrueckt
        if calibrationTouched(x, y) then

            calibrate()

        else

            -- Etage gedrueckt
            local selectedFloor =
                getTouchedFloor(x, y)


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
