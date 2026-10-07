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
-- DATEIEN:
-- elevator.cfg = Kalibrierung + Geschwindigkeit
-- floors.cfg   = Etagen-Namen
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
local SPEED_SIDE = "right"

local CONFIG_FILE = "elevator.cfg"
local FLOOR_FILE  = "floors.cfg"


-- ============================================================
-- ZUSTAND
-- ============================================================

local currentFloor = nil
local maxFloor = nil

local moving = false
local calibrating = false
local targetFloor = nil

local normalSpeed = 70

-- main / settings / names
local currentPage = "main"

-- [EtagenNummer] = "Name"
local floorNames = {}


-- ============================================================
-- PERIPHERALS
-- ============================================================

local monitor = peripheral.find("monitor")

if not monitor then
    error("Kein Advanced Monitor gefunden!")
end

local speedRelay = peripheral.wrap(SPEED_RELAY_NAME)

if not speedRelay then
    error(
        "Redstone Relay '"
        .. SPEED_RELAY_NAME
        .. "' nicht gefunden!"
    )
end

monitor.setTextScale(0.5)

local WIDTH, HEIGHT = monitor.getSize()


-- ============================================================
-- BUTTONS
-- ============================================================

local floorButtons = {}

local settingsButton = nil

local speedMinusButton = nil
local speedPlusButton = nil

local namesButton = nil
local calibrationButton = nil
local backButton = nil

local nameFloorButtons = {}


-- ============================================================
-- SPEED
-- ============================================================

local function speedPercentToSignal(percent)

    percent = math.max(
        50,
        math.min(100, percent)
    )

    -- 100 % -> Signal 0
    --  50 % -> Signal 15

    local signal = math.floor(
        ((100 - percent) / 50) * 15 + 0.5
    )

    return math.max(
        0,
        math.min(15, signal)
    )
end


local function setSpeed(percent)

    local signal =
        speedPercentToSignal(percent)

    speedRelay.setAnalogOutput(
        SPEED_SIDE,
        signal
    )
end


local function setNormalSpeed()
    setSpeed(normalSpeed)
end


local function setCalibrationSpeed()
    setSpeed(100)
end


-- ============================================================
-- HAUPTKONFIGURATION LADEN
-- ============================================================

local function loadConfig()

    if not fs.exists(CONFIG_FILE) then
        return false
    end

    local file =
        fs.open(CONFIG_FILE, "r")

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
        maxFloor = loadedFloor
    end

    if loadedSpeed
        and loadedSpeed >= 50
        and loadedSpeed <= 100
    then
        normalSpeed = loadedSpeed
    end

    return maxFloor ~= nil
end


-- ============================================================
-- HAUPTKONFIGURATION SPEICHERN
-- ============================================================

local function saveConfig()

    local file =
        fs.open(CONFIG_FILE, "w")

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
-- ETAGEN-NAMEN LADEN
-- ============================================================

local function loadFloorNames()

    floorNames = {}

    if not fs.exists(FLOOR_FILE) then
        return
    end

    local file =
        fs.open(FLOOR_FILE, "r")

    if not file then
        return
    end

    while true do

        local line =
            file.readLine()

        if not line then
            break
        end

        -- Format:
        -- 2=WERKSTATT

        local floorString, name =
            string.match(
                line,
                "^(%-?%d+)=(.*)$"
            )

        if floorString
            and name
        then

            local floor =
                tonumber(floorString)

            if floor ~= nil
                and name ~= ""
            then
                floorNames[floor] = name
            end
        end
    end

    file.close()
end


-- ============================================================
-- ETAGEN-NAMEN SPEICHERN
-- ============================================================

local function saveFloorNames()

    local file =
        fs.open(FLOOR_FILE, "w")

    if not file then
        error(
            "Etagen-Namen konnten nicht gespeichert werden!"
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
-- NAME EINER ETAGE
-- ============================================================

local function getFloorName(floor)

    if floor == nil then
        return nil
    end

    local name =
        floorNames[floor]

    if name
        and name ~= ""
    then
        return name
    end

    return nil
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

    text = tostring(text)

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


local function fillArea(
    x1,
    y1,
    x2,
    y2,
    color
)

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

    if labelX < x1 then
        labelX = x1
    end

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
    nameFloorButtons = {}

    settingsButton = nil

    speedMinusButton = nil
    speedPlusButton = nil

    namesButton = nil
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

    monitor.setCursorPos(1, 1)
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

    drawHeader("AUFZUG")


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

        local name =
            getFloorName(currentFloor)

        if name then

            monitor.setTextColor(
                colors.yellow
            )

            centerText(
                5,
                name
            )
        end

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
            7,
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

            local text =
                directionText
                .. "FAHRT ZU "
                .. tostring(targetFloor)

            local targetName =
                getFloorName(targetFloor)

            centerText(
                7,
                text
            )

            if targetName then

                monitor.setTextColor(
                    colors.yellow
                )

                centerText(
                    8,
                    targetName
                )
            end

        else

            centerText(
                7,
                "FAHRT"
            )
        end

    else

        monitor.setTextColor(
            colors.lime
        )

        centerText(
            7,
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
            11,
            "Keine Etagen"
        )

        centerText(
            12,
            "kalibriert"
        )

    else

        -- ====================================================
        -- ETAGENRASTER
        -- ====================================================

        local floorCount =
            maxFloor + 1

        local startY = 10

        local bottomReserved = 5

        local endY =
            HEIGHT
            - bottomReserved

        local availableHeight =
            endY
            - startY
            + 1

        local buttonWidth = 5
        local buttonHeight = 3

        local gapX = 1
        local gapY = 1

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

                if floor
                    == currentFloor
                then

                    background =
                        colors.green

                elseif moving
                    and floor
                        == targetFloor
                then

                    background =
                        colors.orange

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
        tostring(normalSpeed)
        .. "%"
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
    -- ETAGEN BENENNEN
    -- ========================================================

    local namesLabel =
        "ETAGEN BENENNEN"

    local namesWidth =
        math.min(
            22,
            WIDTH - 4
        )

    local namesX1 =
        math.floor(
            (
                WIDTH
                - namesWidth
            )
            / 2
        ) + 1

    local namesX2 =
        namesX1
        + namesWidth
        - 1

    local namesY1 = 15
    local namesY2 = 17

    if maxFloor ~= nil then

        drawButton(
            namesX1,
            namesY1,
            namesX2,
            namesY2,
            namesLabel,
            colors.blue,
            colors.white
        )

    else

        drawButton(
            namesX1,
            namesY1,
            namesX2,
            namesY2,
            namesLabel,
            colors.lightGray,
            colors.gray
        )
    end

    namesButton = {
        x1 = namesX1,
        y1 = namesY1,

        x2 = namesX2,
        y2 = namesY2
    }


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

    local calibrationY1 = 19
    local calibrationY2 = 21

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
end


-- ============================================================
-- ETAGEN BENENNEN SCREEN
-- ============================================================

local function drawNames()

    clearScreen()

    drawHeader(
        "ETAGEN BENENNEN"
    )

    monitor.setTextColor(
        colors.lightGray
    )

    centerText(
        3,
        "ETAGE AUSWAEHLEN"
    )

    if maxFloor == nil then

        monitor.setTextColor(
            colors.red
        )

        centerText(
            6,
            "Nicht kalibriert"
        )

        return
    end


    -- ========================================================
    -- ETAGENLISTE / RASTER
    -- ========================================================

    local floorCount =
        maxFloor + 1

    local startY = 5
    local endY = HEIGHT - 5

    local availableHeight =
        endY - startY + 1

    local buttonWidth = 12
    local buttonHeight = 3

    local gapX = 1
    local gapY = 1


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
        )
        * gapX


    if totalWidth > WIDTH then

        buttonWidth =
            math.max(
                5,
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

            local name =
                getFloorName(floor)

            local label =
                tostring(floor)

            if name then

                -- Name nur so lang machen,
                -- dass der Button nicht kaputtgeht.

                local available =
                    buttonWidth - 4

                if available > 1 then

                    local shortName =
                        string.sub(
                            name,
                            1,
                            available
                        )

                    label =
                        tostring(floor)
                        .. " "
                        .. shortName
                end
            end


            drawButton(
                x1,
                y1,
                x2,
                y2,
                label,
                colors.gray,
                colors.white
            )


            nameFloorButtons[
                #nameFloorButtons + 1
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
    -- ZURUECK
    -- ========================================================

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
        "ZURUECK",
        colors.gray,
        colors.white
    )


    backButton = {

        x1 = backX1,
        y1 = backY1,

        x2 = backX2,
        y2 = backY2
    }
end


-- ============================================================
-- SCREEN ZEICHNEN
-- ============================================================

local function drawScreen()

    if currentPage == "settings" then

        drawSettings()

    elseif currentPage == "names" then

        drawNames()

    else

        drawMain()
    end
end


-- ============================================================
-- ETAGENNAME AM COMPUTER EINGEBEN
-- ============================================================

local function editFloorName(floor)

    -- Monitor zeigt an,
    -- was gerade bearbeitet wird.

    clearScreen()

    drawHeader(
        "ETAGE "
        .. tostring(floor)
    )

    monitor.setTextColor(
        colors.yellow
    )

    centerText(
        5,
        "NAME AM COMPUTER"
    )

    centerText(
        6,
        "EINGEBEN"
    )


    local oldName =
        getFloorName(floor)

    if oldName then

        monitor.setTextColor(
            colors.lightGray
        )

        centerText(
            9,
            "Aktuell:"
        )

        monitor.setTextColor(
            colors.white
        )

        centerText(
            10,
            oldName
        )
    end


    -- ========================================================
    -- COMPUTER TERMINAL
    -- ========================================================

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
        "================================"
    )

    print(
        "   AUFZUG - ETAGE BENENNEN"
    )

    print(
        "================================"
    )

    print("")

    print(
        "Etage: "
        .. tostring(floor)
    )


    if oldName then

        print(
            "Aktueller Name: "
            .. oldName
        )

    else

        print(
            "Aktueller Name: -"
        )
    end


    print("")

    print(
        "Neuen Namen eingeben."
    )

    print(
        "Leer lassen = Namen entfernen."
    )

    print("")

    write("> ")


    local newName =
        read()


    -- Gleichheitszeichen entfernen,
    -- da "=" unser Dateitrenner ist.

    newName =
        string.gsub(
            newName,
            "=",
            ""
        )


    -- Fuehrende / folgende Leerzeichen entfernen

    newName =
        string.match(
            newName,
            "^%s*(.-)%s*$"
        )


    if newName == "" then

        floorNames[floor] = nil

    else

        -- Begrenzen, damit keine
        -- riesigen Namen entstehen.

        newName =
            string.sub(
                newName,
                1,
                24
            )

        floorNames[floor] =
            newName
    end


    saveFloorNames()


    term.clear()

    term.setCursorPos(
        1,
        1
    )

    print(
        "Etage "
        .. tostring(floor)
        .. " gespeichert."
    )


    if floorNames[floor] then

        print(
            "Name: "
            .. floorNames[floor]
        )

    else

        print(
            "Name entfernt."
        )
    end


    sleep(0.8)


    currentPage = "names"

    drawScreen()
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

    currentPage = "main"

    calibrating = true
    moving = true
    targetFloor = nil

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


        -- BOTTOM = LETZTE ETAGE

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


        -- NORMALER CONTACT

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
    -- WIEDER HOME
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
    buttons,
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
-- START
-- ============================================================

loadConfig()

loadFloorNames()

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

    if currentPage == "main" then

        if not moving
            and not calibrating
        then

            if buttonTouched(
                settingsButton,
                x,
                y
            ) then

                currentPage =
                    "settings"

                drawScreen()

            else

                local selectedFloor =
                    getTouchedFloor(
                        floorButtons,
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


        -- ETAGEN BENENNEN

        elseif maxFloor ~= nil
            and buttonTouched(
                namesButton,
                x,
                y
            )
        then

            currentPage =
                "names"

            drawScreen()


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


    -- ========================================================
    -- ETAGEN BENENNEN
    -- ========================================================

    elseif currentPage
        == "names"
    then

        local selectedFloor =
            getTouchedFloor(
                nameFloorButtons,
                x,
                y
            )


        if selectedFloor ~= nil then

            editFloorName(
                selectedFloor
            )


        elseif buttonTouched(
            backButton,
            x,
            y
        ) then

            currentPage =
                "settings"

            drawScreen()
        end
    end
end
