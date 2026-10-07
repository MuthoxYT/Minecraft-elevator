-- ============================================================
-- CREATE + CC:TWEAKED ELEVATOR CONTROLLER
-- ============================================================
--
-- COMPUTER:
-- left   = Richtungs-Gearshift
-- back   = Sequenced Gearshift
-- right  = normale Etagen-Contacts
-- top    = HOME / Etage 0
-- bottom = BOTTOM / letzte Etage
-- front  = Wired Modem
--
-- WIRED NETWORK:
-- monitor
-- redstone_relay_1 = Geschwindigkeit
--
-- DATEIEN:
-- elevator.cfg
-- floors.cfg
--
-- FEATURES:
-- - automatische Kalibrierung
-- - Etagen-Namen
-- - Geschwindigkeit 50-100 %
-- - HOME/BOTTOM Sicherheits-Endschalter
-- - automatische Rueckfahrt zu Etage 0
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
local targetFloor = nil

local moving = false
local calibrating = false

local normalSpeed = 70

-- main / settings / names
local currentPage = "main"

local floorNames = {}


-- ============================================================
-- AUTO HOME
-- ============================================================

local autoHomeEnabled = false
local autoHomeMinutes = 5

local autoHomeTimer = nil


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
local nameFloorButtons = {}

local settingsButton = nil

local speedMinusButton = nil
local speedPlusButton = nil

local autoHomeButton = nil
local autoMinusButton = nil
local autoPlusButton = nil

local namesButton = nil
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

    -- 100 % -> 0
    --  50 % -> 15

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
        speedPercentToSignal(percent)
    )
end


local function setNormalSpeed()
    setSpeed(normalSpeed)
end


local function setCalibrationSpeed()
    setSpeed(100)
end


-- ============================================================
-- CONFIG LADEN
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


    -- Alte Config:
    -- Zeile 1 = maxFloor
    -- Zeile 2 = normalSpeed
    --
    -- Neue Config:
    -- Zeile 3 = autoHomeEnabled
    -- Zeile 4 = autoHomeMinutes

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
        tonumber(floorValue)

    local loadedSpeed =
        tonumber(speedValue)

    local loadedMinutes =
        tonumber(minutesValue)


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


-- ============================================================
-- CONFIG SPEICHERN
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


    file.writeLine(
        tostring(autoHomeEnabled)
    )


    file.writeLine(
        tostring(autoHomeMinutes)
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


-- ============================================================
-- ETAGEN-NAMEN SPEICHERN
-- ============================================================

local function saveFloorNames()

    local file =
        fs.open(
            FLOOR_FILE,
            "w"
        )

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
-- ETAGENNAME
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
-- AUTO-HOME TIMER
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
            autoHomeMinutes * 60
        )
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

    text =
        tostring(text)


    local x =
        math.floor(
            (WIDTH - #text)
            / 2
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
            (width - #label)
            / 2
        )


    local labelY =
        y1
        + math.floor(
            (y2 - y1)
            / 2
        )


    if labelX < x1 then
        labelX = x1
    end


    monitor.setCursorPos(
        labelX,
        labelY
    )

    monitor.write(
        string.sub(
            label,
            1,
            width
        )
    )
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

    autoHomeButton = nil
    autoMinusButton = nil
    autoPlusButton = nil

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
-- ETAGENBUTTON MIT NAME
-- ============================================================

local function drawFloorButton(
    x1,
    y1,
    x2,
    y2,
    floor,
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

    local height =
        y2 - y1 + 1


    local floorText =
        tostring(floor)


    local floorX =
        x1
        + math.floor(
            (width - #floorText)
            / 2
        )


    local floorName =
        getFloorName(floor)


    -- Genug Hoehe fuer Nummer + Name

    if height >= 3
        and floorName
    then

        monitor.setCursorPos(
            floorX,
            y1
        )

        monitor.write(
            floorText
        )


        local displayName =
            floorName


        if #displayName > width then

            if width >= 4 then

                displayName =
                    string.sub(
                        displayName,
                        1,
                        width - 2
                    )
                    .. ".."

            else

                displayName =
                    string.sub(
                        displayName,
                        1,
                        width
                    )
            end
        end


        local nameX =
            x1
            + math.floor(
                (width - #displayName)
                / 2
            )


        monitor.setCursorPos(
            nameX,
            y2
        )

        monitor.write(
            displayName
        )

    else

        local floorY =
            y1
            + math.floor(
                (height - 1)
                / 2
            )


        monitor.setCursorPos(
            floorX,
            floorY
        )

        monitor.write(
            floorText
        )
    end
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


        local name =
            getFloorName(
                currentFloor
            )


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

            centerText(
                7,
                directionText
                .. "FAHRT ZU "
                .. tostring(
                    targetFloor
                )
            )


            local targetName =
                getFloorName(
                    targetFloor
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
    -- ETAGEN
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

        local floorCount =
            maxFloor + 1


        local startY = 10
        local endY = HEIGHT - 5

        local availableHeight =
            endY - startY + 1


        -- Wir nutzen bei wenigen Etagen
        -- breitere Buttons fuer die Namen.

        local buttonWidth

        if floorCount <= 3 then

            buttonWidth =
                math.floor(
                    (WIDTH - 8)
                    / floorCount
                )

            buttonWidth =
                math.min(
                    12,
                    buttonWidth
                )

        elseif floorCount <= 6 then

            buttonWidth = 9

        else

            buttonWidth = 7
        end


        local buttonHeight = 3

        local gapX = 2
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


                drawFloorButton(
                    x1,
                    y1,
                    x2,
                    y2,
                    floor,
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
    -- EINSTELLUNGEN BUTTON
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
end


-- ============================================================
-- SETTINGS
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
        3,
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


    drawButton(
        minusX1,
        5,
        minusX2,
        7,
        "-",
        colors.gray,
        colors.white
    )


    drawButton(
        plusX1,
        5,
        plusX2,
        7,
        "+",
        colors.gray,
        colors.white
    )


    speedMinusButton = {

        x1 = minusX1,
        y1 = 5,

        x2 = minusX2,
        y2 = 7
    }


    speedPlusButton = {

        x1 = plusX1,
        y1 = 5,

        x2 = plusX2,
        y2 = 7
    }


    monitor.setBackgroundColor(
        colors.black
    )

    monitor.setTextColor(
        colors.white
    )


    centerText(
        6,
        tostring(normalSpeed)
        .. "%"
    )


    -- ========================================================
    -- AUTO HOME
    -- ========================================================

    monitor.setTextColor(
        colors.lightGray
    )

    centerText(
        10,
        "AUTO-RUECKFAHRT"
    )


    local autoLabel


    if autoHomeEnabled then
        autoLabel = "[X] AKTIV"
    else
        autoLabel = "[ ] AUS"
    end


    local autoWidth = 14

    local autoX1 =
        math.floor(
            (WIDTH - autoWidth)
            / 2
        ) + 1


    local autoX2 =
        autoX1
        + autoWidth
        - 1


    drawButton(
        autoX1,
        12,
        autoX2,
        14,
        autoLabel,
        autoHomeEnabled
            and colors.green
            or colors.gray,
        colors.white
    )


    autoHomeButton = {

        x1 = autoX1,
        y1 = 12,

        x2 = autoX2,
        y2 = 14
    }


    -- ========================================================
    -- AUTO HOME ZEIT
    -- ========================================================

    monitor.setTextColor(
        colors.lightGray
    )

    centerText(
        16,
        "WARTEZEIT"
    )


    local autoMinusX1 =
        center - 10

    local autoMinusX2 =
        autoMinusX1 + 5


    local autoPlusX1 =
        center + 5

    local autoPlusX2 =
        autoPlusX1 + 5


    drawButton(
        autoMinusX1,
        18,
        autoMinusX2,
        20,
        "-",
        colors.gray,
        colors.white
    )


    drawButton(
        autoPlusX1,
        18,
        autoPlusX2,
        20,
        "+",
        colors.gray,
        colors.white
    )


    autoMinusButton = {

        x1 = autoMinusX1,
        y1 = 18,

        x2 = autoMinusX2,
        y2 = 20
    }


    autoPlusButton = {

        x1 = autoPlusX1,
        y1 = 18,

        x2 = autoPlusX2,
        y2 = 20
    }


    monitor.setBackgroundColor(
        colors.black
    )

    monitor.setTextColor(
        colors.white
    )


    centerText(
        19,
        tostring(
            autoHomeMinutes
        )
        .. " MIN"
    )


    -- ========================================================
    -- ETAGEN BENENNEN
    -- ========================================================

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


    drawButton(
        namesX1,
        23,
        namesX2,
        25,
        "ETAGEN BENENNEN",
        maxFloor
            and colors.blue
            or colors.lightGray,
        maxFloor
            and colors.white
            or colors.gray
    )


    namesButton = {

        x1 = namesX1,
        y1 = 23,

        x2 = namesX2,
        y2 = 25
    }


    -- ========================================================
    -- KALIBRIEREN
    -- ========================================================

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


    drawButton(
        calibrationX1,
        27,
        calibrationX2,
        29,
        "KALIBRIEREN",
        colors.orange,
        colors.black
    )


    calibrationButton = {

        x1 = calibrationX1,
        y1 = 27,

        x2 = calibrationX2,
        y2 = 29
    }


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
-- ETAGEN BENENNEN
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
            "NICHT KALIBRIERT"
        )

        return
    end


    local floorCount =
        maxFloor + 1


    local startY = 5
    local endY = HEIGHT - 5


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


    local availableHeight =
        endY - startY + 1


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
                getFloorName(
                    floor
                )


            local label =
                tostring(floor)


            if name then

                local available =
                    buttonWidth - 4


                if available > 1 then

                    label =
                        tostring(floor)
                        .. " "
                        .. string.sub(
                            name,
                            1,
                            available
                        )
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


    -- Zurueck

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
-- SCREEN
-- ============================================================

local function drawScreen()

    if currentPage
        == "settings"
    then

        drawSettings()


    elseif currentPage
        == "names"
    then

        drawNames()


    else

        drawMain()
    end
end


-- ============================================================
-- ETAGENNAME BEARBEITEN
-- ============================================================

local function editFloorName(floor)

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
        getFloorName(
            floor
        )


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

        floorNames[floor] = nil

    else

        floorNames[floor] =
            string.sub(
                newName,
                1,
                24
            )
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


    sleep(0.5)


    currentPage =
        "names"

    drawScreen()
end


-- ============================================================
-- NAECHSTEN CONTACT ABWARTEN
-- ============================================================

local function waitForNextFloor()

    -- Aktuellen Contact verlassen

    while redstone.getInput(
        CONTACT
    ) do

        sleep(0.05)
    end


    -- Naechsten Contact erreichen

    while not redstone.getInput(
        CONTACT
    ) do

        -- HOME/BOTTOM werden in moveTo
        -- fuer Endfahrten separat ueberwacht.

        sleep(0.05)
    end
end


-- ============================================================
-- HOME
-- ============================================================

local function home()

    cancelAutoHomeTimer()

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

        -- Sicherheitsfall:
        -- Wenn wir beim Hochfahren BOTTOM
        -- verlassen, ist das kein Fehler.

        sleep(0.05)
    end


    -- HOME ist IMMER harter Stop

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

    cancelAutoHomeTimer()

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


        -- HOME = harter Stop

        pulse(
            SEQUENCER
        )
    end


    currentFloor = 0

    drawScreen()

    sleep(0.5)


    -- ========================================================
    -- RUNTERFAHREN
    -- ========================================================

    local countedFloors = 0


    redstone.setOutput(
        DIRECTION,
        false
    )


    pulse(
        SEQUENCER
    )


    -- HOME erst verlassen

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
        -- BOTTOM = LETZTE ETAGE + HARTER STOP
        -- ====================================================

        if redstone.getInput(
            BOTTOM
        ) then

            countedFloors =
                countedFloors + 1


            currentFloor =
                countedFloors


            -- SOFORT STOPPEN

            pulse(
                SEQUENCER
            )


            drawScreen()

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

            -- Falls BOTTOM gleichzeitig
            -- auftaucht, sofort raus.

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


    -- BOTTOM erst verlassen

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


    -- HOME = harter Stop

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


    if maxFloor == nil then
        return
    end


    if target < 0
        or target > maxFloor
    then

        return
    end


    if target == currentFloor then

        -- Auch ein Druck auf die aktuelle
        -- Etage setzt Auto-Home neu.

        startAutoHomeTimer()

        return
    end


    cancelAutoHomeTimer()


    currentPage = "main"

    setNormalSpeed()


    local startFloor =
        currentFloor


    local goingUp =
        target < currentFloor


    moving = true
    targetFloor = target


    drawScreen()


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
    -- START-ENDSCHALTER ERST VERLASSEN
    -- ========================================================

    if startFloor == 0 then

        while redstone.getInput(
            HOME
        ) do

            sleep(0.05)
        end


    elseif startFloor == maxFloor then

        while redstone.getInput(
            BOTTOM
        ) do

            sleep(0.05)
        end
    end


    -- ========================================================
    -- FAHRT ZU HOME
    -- ========================================================

    if target == 0 then

        while true do

            -- HOME = SOFORT STOP

            if redstone.getInput(
                HOME
            ) then

                pulse(
                    SEQUENCER
                )


                currentFloor = 0

                moving = false
                targetFloor = nil


                drawScreen()

                return
            end


            -- BOTTOM waehrend Fahrt nach oben
            -- waere unerwartet. Ebenfalls stoppen.

            if redstone.getInput(
                BOTTOM
            ) then

                pulse(
                    SEQUENCER
                )


                currentFloor =
                    maxFloor

                moving = false
                targetFloor = nil


                drawScreen()

                startAutoHomeTimer()

                return
            end


            sleep(0.05)
        end
    end


    -- ========================================================
    -- FAHRT ZU BOTTOM
    -- ========================================================

    if target == maxFloor then

        local contactActive = false


        while true do

            -- BOTTOM = SOFORT STOP

            if redstone.getInput(
                BOTTOM
            ) then

                pulse(
                    SEQUENCER
                )


                currentFloor =
                    maxFloor

                moving = false
                targetFloor = nil


                drawScreen()

                startAutoHomeTimer()

                return
            end


            -- HOME waehrend Fahrt nach unten
            -- nach dem Verlassen waere unerwartet.

            if redstone.getInput(
                HOME
            ) then

                pulse(
                    SEQUENCER
                )


                currentFloor = 0

                moving = false
                targetFloor = nil


                drawScreen()

                return
            end


            -- Zwischenetagen mitzaehlen

            local contact =
                redstone.getInput(
                    CONTACT
                )


            if contact
                and not contactActive
            then

                contactActive = true


                if currentFloor
                    < maxFloor
                then

                    currentFloor =
                        currentFloor + 1
                end


                drawScreen()


            elseif not contact then

                contactActive = false
            end


            sleep(0.05)
        end
    end


    -- ========================================================
    -- NORMALE ZIELETAGE
    -- ========================================================

    local contactActive =
        redstone.getInput(
            CONTACT
        )


    while currentFloor
        ~= target
    do

        -- ====================================================
        -- HARTER HOME-ENDSTOP
        -- ====================================================

        if redstone.getInput(
            HOME
        ) then

            pulse(
                SEQUENCER
            )


            currentFloor = 0

            moving = false
            targetFloor = nil


            drawScreen()

            return
        end


        -- ====================================================
        -- HARTER BOTTOM-ENDSTOP
        -- ====================================================

        if redstone.getInput(
            BOTTOM
        ) then

            pulse(
                SEQUENCER
            )


            currentFloor =
                maxFloor

            moving = false
            targetFloor = nil


            drawScreen()

            startAutoHomeTimer()

            return
        end


        -- ====================================================
        -- CONTACT FLANKE
        -- ====================================================

        local contact =
            redstone.getInput(
                CONTACT
            )


        if contact
            and not contactActive
        then

            contactActive = true


            if goingUp then

                currentFloor =
                    currentFloor - 1

            else

                currentFloor =
                    currentFloor + 1
            end


            drawScreen()


            if currentFloor
                == target
            then

                pulse(
                    SEQUENCER
                )

                break
            end


        elseif not contact then

            contactActive = false
        end


        sleep(0.05)
    end


    moving = false
    targetFloor = nil


    drawScreen()


    startAutoHomeTimer()
end


-- ============================================================
-- SPEED AENDERN
-- ============================================================

local function changeSpeed(amount)

    normalSpeed =
        normalSpeed
        + amount


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
-- AUTO HOME AN/AUS
-- ============================================================

local function toggleAutoHome()

    autoHomeEnabled =
        not autoHomeEnabled


    if not autoHomeEnabled then

        cancelAutoHomeTimer()

    else

        startAutoHomeTimer()
    end


    saveConfig()

    drawScreen()
end


-- ============================================================
-- AUTO HOME ZEIT
-- ============================================================

local function changeAutoHomeTime(amount)

    autoHomeMinutes =
        autoHomeMinutes
        + amount


    if autoHomeMinutes < 1 then
        autoHomeMinutes = 1
    end


    if autoHomeMinutes > 60 then
        autoHomeMinutes = 60
    end


    -- Falls bereits ein Timer laeuft:
    -- mit neuer Zeit neu starten.

    if autoHomeEnabled then

        startAutoHomeTimer()
    end


    saveConfig()

    drawScreen()
end


-- ============================================================
-- BUTTON -> ETAGE
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
-- EVENT LOOP
-- ============================================================

while true do

    local event,
          p1,
          p2,
          p3 =
        os.pullEvent()


    -- ========================================================
    -- MONITOR TOUCH
    -- ========================================================

    if event
        == "monitor_touch"
    then

        local side = p1
        local x = p2
        local y = p3


        -- ====================================================
        -- MAIN
        -- ====================================================

        if currentPage
            == "main"
        then

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
                    then

                        moveTo(
                            selectedFloor
                        )
                    end
                end
            end


        -- ====================================================
        -- SETTINGS
        -- ====================================================

        elseif currentPage
            == "settings"
        then

            if buttonTouched(
                speedMinusButton,
                x,
                y
            ) then

                changeSpeed(-5)


            elseif buttonTouched(
                speedPlusButton,
                x,
                y
            ) then

                changeSpeed(5)


            elseif buttonTouched(
                autoHomeButton,
                x,
                y
            ) then

                toggleAutoHome()


            elseif buttonTouched(
                autoMinusButton,
                x,
                y
            ) then

                changeAutoHomeTime(-1)


            elseif buttonTouched(
                autoPlusButton,
                x,
                y
            ) then

                changeAutoHomeTime(1)


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


            elseif buttonTouched(
                calibrationButton,
                x,
                y
            ) then

                calibrate()


            elseif buttonTouched(
                backButton,
                x,
                y
            ) then

                currentPage =
                    "main"

                drawScreen()


                -- Erst nach Verlassen
                -- der Einstellungen darf
                -- Auto-Home wieder loslegen.

                startAutoHomeTimer()
            end


        -- ====================================================
        -- NAMEN
        -- ====================================================

        elseif currentPage
            == "names"
        then

            local selectedFloor =
                getTouchedFloor(
                    nameFloorButtons,
                    x,
                    y
                )


            if selectedFloor
                ~= nil
            then

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


    -- ========================================================
    -- AUTO-HOME TIMER
    -- ========================================================

    elseif event
        == "timer"
    then

        local timerID = p1


        if autoHomeTimer ~= nil
            and timerID
                == autoHomeTimer
        then

            autoHomeTimer = nil


            -- Nur fahren, wenn:
            -- - Auto Home noch aktiv
            -- - nicht Etage 0
            -- - Aufzug steht
            -- - keine Kalibrierung
            -- - Main Screen aktiv

            if autoHomeEnabled
                and currentFloor ~= nil
                and currentFloor ~= 0
                and not moving
                and not calibrating
            then

                if currentPage
                    == "main"
                then

                    moveTo(0)

                else

                    -- Benutzer ist noch in
                    -- Einstellungen/Namen.
                    --
                    -- Nicht einfach losfahren.
                    -- Timer erneut starten.

                    startAutoHomeTimer()
                end
            end
        end
    end
end
