-- ============================================================
-- ELEVATOR PANEL
-- Computer #2
-- ============================================================

local BRIDGE_ID = 1

local MODEM_SIDE =
    "top"

local PROTOCOL_STATE =
    "elevator_state"

local PROTOCOL_COMMAND =
    "elevator_command"


-- ============================================================
-- NETWORK
-- ============================================================

rednet.open(
    MODEM_SIDE
)


-- ============================================================
-- MONITOR
-- ============================================================

local monitor =
    peripheral.find(
        "monitor"
    )


if not monitor then

    error(
        "Kein Monitor gefunden!"
    )
end


if monitor.isColor
    and not monitor.isColor()
then

    error(
        "Advanced Monitor erforderlich!"
    )
end


monitor.setTextScale(0.5)


local WIDTH,
      HEIGHT =
    monitor.getSize()


-- ============================================================
-- STATE
-- ============================================================

local state = nil

local buttons = {}

local requestTimer = nil


-- ============================================================
-- NETWORK
-- ============================================================

local function sendCommand(
    action,
    data
)

    local packet = {
        action = action
    }


    if data then

        for key, value
            in pairs(data)
        do

            packet[key] =
                value
        end
    end


    rednet.send(
        BRIDGE_ID,
        packet,
        PROTOCOL_COMMAND
    )
end


local function requestState()

    sendCommand(
        "request_state"
    )
end


-- ============================================================
-- UI HELPERS
-- ============================================================

local function clearButtons()
    buttons = {}
end


local function addButton(
    x1,
    y1,
    x2,
    y2,
    action,
    data
)

    buttons[
        #buttons + 1
    ] = {

        x1 = x1,
        y1 = y1,

        x2 = x2,
        y2 = y2,

        action = action,
        data = data
    }
end


local function touched(
    button,
    x,
    y
)

    return
        x >= button.x1
        and x <= button.x2
        and y >= button.y1
        and y <= button.y2
end


local function fillArea(
    x1,
    y1,
    x2,
    y2,
    color
)

    x1 =
        math.max(
            1,
            x1
        )

    y1 =
        math.max(
            1,
            y1
        )

    x2 =
        math.min(
            WIDTH,
            x2
        )

    y2 =
        math.min(
            HEIGHT,
            y2
        )


    if x1 > x2
        or y1 > y2
    then

        return
    end


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
                x2 - x1 + 1
            )
        )
    end
end


local function centerText(
    y,
    text
)

    text =
        tostring(text)


    if #text > WIDTH then

        text =
            string.sub(
                text,
                1,
                WIDTH
            )
    end


    local x =
        math.floor(
            (WIDTH - #text)
            / 2
        ) + 1


    monitor.setCursorPos(
        math.max(
            1,
            x
        ),
        y
    )

    monitor.write(text)
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


    local width =
        x2 - x1 + 1


    if #label > width then

        label =
            string.sub(
                label,
                1,
                width
            )
    end


    monitor.setTextColor(
        foreground
    )


    local textX =
        x1
        + math.floor(
            (width - #label)
            / 2
        )


    local textY =
        y1
        + math.floor(
            (y2 - y1)
            / 2
        )


    monitor.setCursorPos(
        textX,
        textY
    )

    monitor.write(label)
end


local function clearScreen()

    WIDTH,
    HEIGHT =
        monitor.getSize()


    monitor.setBackgroundColor(
        colors.black
    )

    monitor.setTextColor(
        colors.white
    )

    monitor.clear()

    clearButtons()
end


local function drawHeader(
    title
)

    fillArea(
        1,
        1,
        WIDTH,
        1,
        colors.gray
    )


    monitor.setTextColor(
        colors.white
    )

    centerText(
        1,
        title
    )
end


local function getFloorName(
    floor
)

    if not state
        or not state.floorNames
    then

        return nil
    end


    return
        state.floorNames[floor]
        or
        state.floorNames[
            tostring(floor)
        ]
end


-- ============================================================
-- FLOOR BUTTON
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


    local number =
        tostring(floor)

    local name =
        getFloorName(
            floor
        )


    if height >= 2
        and name
        and name ~= ""
    then

        local numberX =
            x1
            + math.floor(
                (width - #number)
                / 2
            )


        monitor.setCursorPos(
            numberX,
            y1
        )

        monitor.write(
            number
        )


        local displayName =
            name


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
            y1 + 1
        )

        monitor.write(
            displayName
        )

    else

        local numberX =
            x1
            + math.floor(
                (width - #number)
                / 2
            )


        local numberY =
            y1
            + math.floor(
                (height - 1)
                / 2
            )


        monitor.setCursorPos(
            numberX,
            numberY
        )

        monitor.write(
            number
        )
    end
end


-- ============================================================
-- WAIT SCREEN
-- ============================================================

local function drawWaiting()

    clearScreen()

    drawHeader(
        "AUFZUG"
    )


    monitor.setTextColor(
        colors.orange
    )

    centerText(
        math.floor(
            HEIGHT / 2
        ),
        "VERBINDE..."
    )


    monitor.setTextColor(
        colors.gray
    )

    centerText(
        math.floor(
            HEIGHT / 2
        ) + 2,
        "Hauptcomputer #0"
    )
end


-- ============================================================
-- MAIN PAGE
-- ============================================================

local function drawMain()

    clearScreen()

    drawHeader(
        "AUFZUG"
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


    if state.currentFloor
        ~= nil
    then

        centerText(
            4,
            tostring(
                state.currentFloor
            )
        )


        local currentName =
            getFloorName(
                state.currentFloor
            )


        if currentName then

            monitor.setTextColor(
                colors.yellow
            )

            centerText(
                5,
                currentName
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

    if state.calibrating then

        monitor.setTextColor(
            colors.orange
        )

        centerText(
            7,
            "KALIBRIERUNG"
        )


    elseif state.moving then

        monitor.setTextColor(
            colors.orange
        )


        if state.targetFloor
            ~= nil
        then

            centerText(
                7,
                "FAHRT ZU "
                .. tostring(
                    state.targetFloor
                )
            )


            local targetName =
                getFloorName(
                    state.targetFloor
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
    -- FLOOR GRID
    -- ========================================================

    if state.maxFloor
        == nil
    then

        monitor.setTextColor(
            colors.white
        )

        centerText(
            11,
            "NICHT KALIBRIERT"
        )

    else

        local floorCount =
            state.maxFloor
            + 1


        local startY = 10
        local endY =
            HEIGHT - 5


        local availableHeight =
            endY - startY + 1


        local buttonHeight
        local gapY


        if floorCount <= 6 then

            buttonHeight = 3
            gapY = 1

        else

            buttonHeight = 2
            gapY = 0
        end


        local maxRows =
            math.floor(
                (
                    availableHeight
                    + gapY
                )
                /
                (
                    buttonHeight
                    + gapY
                )
            )


        if maxRows < 1 then
            maxRows = 1
        end


        local columns


        if floorCount <= 4 then

            columns =
                floorCount

        else

            columns =
                math.ceil(
                    floorCount
                    / maxRows
                )
        end


        if columns < 1 then
            columns = 1
        end


        local gapX = 1


        local buttonWidth =
            math.floor(
                (
                    WIDTH
                    - (
                        columns - 1
                    )
                    * gapX
                    - 2
                )
                / columns
            )


        buttonWidth =
            math.max(
                4,
                math.min(
                    14,
                    buttonWidth
                )
            )


        local totalWidth =
            columns
            * buttonWidth
            + (
                columns - 1
            )
            * gapX


        local startX =
            math.floor(
                (
                    WIDTH
                    - totalWidth
                )
                / 2
            ) + 1


        local index = 0


        for floor = 0,
            state.maxFloor
        do

            local column =
                index
                % columns


            local row =
                math.floor(
                    index
                    / columns
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
                x1
                + buttonWidth
                - 1


            local y2 =
                y1
                + buttonHeight
                - 1


            if y2 <= endY then

                local background =
                    colors.gray

                local foreground =
                    colors.white


                if floor
                    == state.currentFloor
                then

                    background =
                        colors.green


                elseif state.moving
                    and floor
                        == state.targetFloor
                then

                    background =
                        colors.orange


                elseif state.moving
                    or state.calibrating
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


                if not state.moving
                    and not state.calibrating
                then

                    addButton(
                        x1,
                        y1,
                        x2,
                        y2,
                        "go_floor",
                        {
                            floor =
                                floor
                        }
                    )
                end
            end


            index =
                index + 1
        end
    end


    -- ========================================================
    -- SETTINGS
    -- ========================================================

    local label =
        "EINSTELLUNGEN"


    local width =
        math.min(
            20,
            WIDTH - 4
        )


    local x1 =
        math.floor(
            (WIDTH - width)
            / 2
        ) + 1


    local x2 =
        x1 + width - 1


    local y1 =
        HEIGHT - 3

    local y2 =
        HEIGHT - 1


    local enabled =
        not state.moving
        and not state.calibrating


    drawButton(
        x1,
        y1,
        x2,
        y2,
        label,
        enabled
            and colors.gray
            or colors.lightGray,
        enabled
            and colors.white
            or colors.gray
    )


    if enabled then

        addButton(
            x1,
            y1,
            x2,
            y2,
            "open_settings"
        )
    end
end


-- ============================================================
-- SETTINGS PAGE
-- ============================================================

local function drawSettings()

    clearScreen()

    drawHeader(
        "EINSTELLUNGEN"
    )


    local buttonHeight =
        HEIGHT >= 30
        and 3
        or 2


    local center =
        math.floor(
            WIDTH / 2
        )


    -- ========================================================
    -- SPEED
    -- ========================================================

    local speedTitleY = 3
    local speedY1 = 4
    local speedY2 =
        speedY1
        + buttonHeight
        - 1


    monitor.setTextColor(
        colors.lightGray
    )

    centerText(
        speedTitleY,
        "FAHRGESCHWINDIGKEIT"
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


    addButton(
        minusX1,
        speedY1,
        minusX2,
        speedY2,
        "speed_minus"
    )


    addButton(
        plusX1,
        speedY1,
        plusX2,
        speedY2,
        "speed_plus"
    )


    monitor.setBackgroundColor(
        colors.black
    )

    monitor.setTextColor(
        colors.white
    )


    centerText(
        speedY1
        + math.floor(
            (buttonHeight - 1)
            / 2
        ),
        tostring(
            state.normalSpeed
        )
        .. "%"
    )


    -- ========================================================
    -- AUTO HOME
    -- ========================================================

    local autoTitleY =
        speedY2 + 2

    local autoY1 =
        autoTitleY + 1

    local autoY2 =
        autoY1
        + buttonHeight
        - 1


    monitor.setTextColor(
        colors.lightGray
    )

    centerText(
        autoTitleY,
        "AUTO-RUECKFAHRT"
    )


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


    local autoLabel


    if state.autoHomeEnabled then

        autoLabel =
            "[X] AKTIV"

    else

        autoLabel =
            "[ ] AUS"
    end


    drawButton(
        autoX1,
        autoY1,
        autoX2,
        autoY2,
        autoLabel,
        state.autoHomeEnabled
            and colors.green
            or colors.gray,
        colors.white
    )


    addButton(
        autoX1,
        autoY1,
        autoX2,
        autoY2,
        "toggle_auto_home"
    )


    -- ========================================================
    -- WAIT TIME
    -- ========================================================

    local waitTitleY =
        autoY2 + 2

    local waitY1 =
        waitTitleY + 1

    local waitY2 =
        waitY1
        + buttonHeight
        - 1


    monitor.setTextColor(
        colors.lightGray
    )

    centerText(
        waitTitleY,
        "WARTEZEIT"
    )


    drawButton(
        minusX1,
        waitY1,
        minusX2,
        waitY2,
        "-",
        colors.gray,
        colors.white
    )


    drawButton(
        plusX1,
        waitY1,
        plusX2,
        waitY2,
        "+",
        colors.gray,
        colors.white
    )


    addButton(
        minusX1,
        waitY1,
        minusX2,
        waitY2,
        "auto_time_minus"
    )


    addButton(
        plusX1,
        waitY1,
        plusX2,
        waitY2,
        "auto_time_plus"
    )


    monitor.setBackgroundColor(
        colors.black
    )

    monitor.setTextColor(
        colors.white
    )


    centerText(
        waitY1
        + math.floor(
            (buttonHeight - 1)
            / 2
        ),
        tostring(
            state.autoHomeMinutes
        )
        .. " MIN"
    )


    -- ========================================================
    -- NAMES
    -- ========================================================

    local namesY1 =
        waitY2 + 2

    local namesY2 =
        namesY1
        + buttonHeight
        - 1


    local namesWidth =
        math.min(
            22,
            WIDTH - 4
        )


    local namesX1 =
        math.floor(
            (WIDTH - namesWidth)
            / 2
        ) + 1

    local namesX2 =
        namesX1
        + namesWidth
        - 1


    local namesEnabled =
        state.maxFloor
        ~= nil


    drawButton(
        namesX1,
        namesY1,
        namesX2,
        namesY2,
        "ETAGEN BENENNEN",
        namesEnabled
            and colors.blue
            or colors.lightGray,
        namesEnabled
            and colors.white
            or colors.gray
    )


    if namesEnabled then

        addButton(
            namesX1,
            namesY1,
            namesX2,
            namesY2,
            "open_names"
        )
    end


    -- ========================================================
    -- CALIBRATION
    -- ========================================================

    local calibrationY1 =
        namesY2 + 2

    local calibrationY2 =
        calibrationY1
        + buttonHeight
        - 1


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
        calibrationY1,
        calibrationX2,
        calibrationY2,
        "KALIBRIEREN",
        colors.orange,
        colors.black
    )


    addButton(
        calibrationX1,
        calibrationY1,
        calibrationX2,
        calibrationY2,
        "calibrate"
    )


    -- ========================================================
    -- BACK
    -- ========================================================

    local backWidth =
        math.min(
            16,
            WIDTH - 4
        )


    local backX1 =
        math.floor(
            (WIDTH - backWidth)
            / 2
        ) + 1

    local backX2 =
        backX1
        + backWidth
        - 1


    local backY1 =
        HEIGHT
        - buttonHeight
        - 1

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


    addButton(
        backX1,
        backY1,
        backX2,
        backY2,
        "back_main"
    )
end


-- ============================================================
-- FLOOR NAMES PAGE
-- ============================================================

local function drawNames()

    clearScreen()


    -- Hauptcomputer wartet auf Eingabe

    if state.namingFloor
        ~= nil
    then

        drawHeader(
            "ETAGE "
            .. tostring(
                state.namingFloor
            )
        )


        monitor.setTextColor(
            colors.yellow
        )


        centerText(
            5,
            "NAME AM"
        )

        centerText(
            6,
            "HAUPTCOMPUTER"
        )

        centerText(
            7,
            "EINGEBEN"
        )


        local oldName =
            getFloorName(
                state.namingFloor
            )


        if oldName then

            monitor.setTextColor(
                colors.lightGray
            )

            centerText(
                10,
                "AKTUELL:"
            )


            monitor.setTextColor(
                colors.white
            )

            centerText(
                11,
                oldName
            )
        end


        return
    end


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


    if state.maxFloor
        == nil
    then

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
        state.maxFloor
        + 1


    local startY = 5

    local endY =
        HEIGHT - 5


    local availableHeight =
        endY - startY + 1


    local buttonHeight =
        floorCount <= 6
        and 3
        or 2


    local gapY =
        buttonHeight == 3
        and 1
        or 0


    local maxRows =
        math.floor(
            (
                availableHeight
                + gapY
            )
            /
            (
                buttonHeight
                + gapY
            )
        )


    if maxRows < 1 then
        maxRows = 1
    end


    local columns =
        math.ceil(
            floorCount
            / maxRows
        )


    if floorCount <= 4 then
        columns = floorCount
    end


    local gapX = 1


    local buttonWidth =
        math.floor(
            (
                WIDTH
                - (
                    columns - 1
                )
                * gapX
                - 2
            )
            / columns
        )


    buttonWidth =
        math.max(
            5,
            math.min(
                14,
                buttonWidth
            )
        )


    local totalWidth =
        columns
        * buttonWidth
        + (
            columns - 1
        )
        * gapX


    local startX =
        math.floor(
            (
                WIDTH
                - totalWidth
            )
            / 2
        ) + 1


    local index = 0


    for floor = 0,
        state.maxFloor
    do

        local column =
            index % columns


        local row =
            math.floor(
                index
                / columns
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
            x1
            + buttonWidth
            - 1


        local y2 =
            y1
            + buttonHeight
            - 1


        if y2 <= endY then

            drawFloorButton(
                x1,
                y1,
                x2,
                y2,
                floor,
                colors.gray,
                colors.white
            )


            addButton(
                x1,
                y1,
                x2,
                y2,
                "edit_name",
                {
                    floor =
                        floor
                }
            )
        end


        index =
            index + 1
    end


    -- BACK

    local backWidth =
        math.min(
            16,
            WIDTH - 4
        )


    local backX1 =
        math.floor(
            (WIDTH - backWidth)
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


    addButton(
        backX1,
        backY1,
        backX2,
        backY2,
        "back_settings"
    )
end


-- ============================================================
-- DRAW
-- ============================================================

local function draw()

    if not state then

        drawWaiting()

        return
    end


    if state.page
        == "settings"
    then

        drawSettings()


    elseif state.page
        == "names"
    then

        drawNames()


    else

        drawMain()
    end
end


-- ============================================================
-- TOUCH
-- ============================================================

local function handleTouch(
    x,
    y
)

    for i =
        #buttons,
        1,
        -1
    do

        local button =
            buttons[i]


        if touched(
            button,
            x,
            y
        ) then

            sendCommand(
                button.action,
                button.data
            )

            return
        end
    end
end


-- ============================================================
-- START
-- ============================================================

print(
    "Elevator Panel #"
    .. os.getComputerID()
)

print(
    "Bridge: #"
    .. BRIDGE_ID
)

print(
    "Monitor: "
    .. WIDTH
    .. "x"
    .. HEIGHT
)


drawWaiting()

requestState()

requestTimer =
    os.startTimer(3)


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
    -- STATE
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
                == PROTOCOL_STATE
            and type(message)
                == "table"
        then

            state =
                message

            draw()
        end


    -- ========================================================
    -- TOUCH
    -- ========================================================

    elseif event
        == "monitor_touch"
    then

        local x =
            p2

        local y =
            p3


        handleTouch(
            x,
            y
        )


    -- ========================================================
    -- RECONNECT / STATE REFRESH
    -- ========================================================

    elseif event
        == "timer"
    then

        if p1
            == requestTimer
        then

            requestState()

            requestTimer =
                os.startTimer(3)
        end
    end
end
