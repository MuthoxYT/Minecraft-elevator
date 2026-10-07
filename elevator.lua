-- ============================================
-- CREATE + CC:TWEAKED ELEVATOR
--
-- LEFT  = Richtungs-Gearshift
-- BACK  = Sequenced Gearshift
-- RIGHT = normale Etagen-Contacts
-- TOP   = Home / Etage 0
--
-- Monitor wird automatisch erkannt.
-- ============================================

local DIRECTION = "left"
local SEQUENCER = "back"
local CONTACT   = "right"
local HOME      = "top"

local MIN_FLOOR = 0
local MAX_FLOOR = 2

local currentFloor = nil
local moving = false
local targetFloor = nil

-- Monitor automatisch finden
local monitor = peripheral.find("monitor")

if not monitor then
    error("Kein Monitor gefunden!")
end

monitor.setTextScale(0.5)

local WIDTH, HEIGHT = monitor.getSize()

-- Hier speichern wir die Positionen der Buttons
local buttons = {}


-- ============================================
-- HILFSFUNKTIONEN
-- ============================================

local function centerText(y, text)
    local x = math.floor((WIDTH - #text) / 2) + 1

    monitor.setCursorPos(x, y)
    monitor.write(text)
end


local function pulse(side)
    redstone.setOutput(side, false)
    sleep(0.1)

    redstone.setOutput(side, true)
    sleep(0.2)

    redstone.setOutput(side, false)
end


-- ============================================
-- MONITOR ZEICHNEN
-- ============================================

local function drawScreen()

    WIDTH, HEIGHT = monitor.getSize()

    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
    monitor.clear()

    buttons = {}

    -- Titel
    monitor.setBackgroundColor(colors.gray)
    monitor.setTextColor(colors.white)

    monitor.setCursorPos(1, 1)
    monitor.clearLine()

    centerText(1, "AUFZUG")


    -- Aktuelle Etage
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.lightGray)

    centerText(3, "AKTUELLE ETAGE")

    monitor.setTextColor(colors.white)

    if currentFloor ~= nil then
        centerText(4, tostring(currentFloor))
    else
        centerText(4, "?")
    end


    -- Status
    if moving then
        monitor.setTextColor(colors.orange)

        centerText(
            6,
            "FAHRE ZU " .. tostring(targetFloor)
        )
    else
        monitor.setTextColor(colors.lime)
        centerText(6, "BEREIT")
    end


    -- ========================================
    -- ETAGEN-BUTTONS
    -- ========================================

    local floorCount = MAX_FLOOR - MIN_FLOOR + 1

    local buttonWidth = 7
    local buttonHeight = 3
    local gap = 2

    -- Anzahl Buttons pro Reihe automatisch
    local columns = math.floor(
        (WIDTH + gap) /
        (buttonWidth + gap)
    )

    if columns < 1 then
        columns = 1
    end

    if columns > floorCount then
        columns = floorCount
    end

    local rows = math.ceil(floorCount / columns)

    local totalWidth =
        columns * buttonWidth
        + (columns - 1) * gap

    local startX =
        math.floor((WIDTH - totalWidth) / 2) + 1

    local startY = 8

    local index = 0

    for floor = MIN_FLOOR, MAX_FLOOR do

        local column = index % columns
        local row = math.floor(index / columns)

        local x1 =
            startX
            + column * (buttonWidth + gap)

        local y1 =
            startY
            + row * (buttonHeight + 1)

        local x2 = x1 + buttonWidth - 1
        local y2 = y1 + buttonHeight - 1


        -- Farbe bestimmen
        local background = colors.gray
        local foreground = colors.white

        if floor == currentFloor then
            background = colors.green

        elseif moving then
            background = colors.lightGray
            foreground = colors.gray

        elseif floor == targetFloor then
            background = colors.orange
        end


        -- Button zeichnen
        monitor.setBackgroundColor(background)
        monitor.setTextColor(foreground)

        for y = y1, y2 do
            monitor.setCursorPos(x1, y)
            monitor.write(
                string.rep(" ", buttonWidth)
            )
        end

        local label = tostring(floor)

        local labelX =
            x1
            + math.floor(
                (buttonWidth - #label) / 2
            )

        local labelY =
            y1
            + math.floor(buttonHeight / 2)

        monitor.setCursorPos(labelX, labelY)
        monitor.write(label)


        -- Touch-Bereich speichern
        buttons[#buttons + 1] = {
            floor = floor,
            x1 = x1,
            y1 = y1,
            x2 = x2,
            y2 = y2
        }

        index = index + 1
    end


    -- Farben zuruecksetzen
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
end


-- ============================================
-- AUF NAECHSTE ETAGE WARTEN
-- ============================================

local function waitForNextFloor()

    -- Alten Contact verlassen
    while redstone.getInput(CONTACT) do
        sleep(0.05)
    end

    -- Neuen Contact erreichen
    while not redstone.getInput(CONTACT) do
        sleep(0.05)
    end
end


-- ============================================
-- HOMING
-- ============================================

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


    -- Hoch
    redstone.setOutput(DIRECTION, true)

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


-- ============================================
-- ZU ETAGE FAHREN
-- ============================================

local function moveTo(target)

    if target == currentFloor then
        return
    end

    moving = true
    targetFloor = target

    drawScreen()

    local goingUp = target < currentFloor


    -- Richtung setzen
    if goingUp then

        -- TRUE = hoch
        redstone.setOutput(
            DIRECTION,
            true
        )

    else

        -- FALSE = runter
        redstone.setOutput(
            DIRECTION,
            false
        )

    end


    -- Start
    pulse(SEQUENCER)


    -- ========================================
    -- ZIEL = HOME / ETAGE 0
    -- ========================================

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


    -- ========================================
    -- NORMALE ETAGEN
    -- ========================================

    while currentFloor ~= target do

        waitForNextFloor()

        if goingUp then
            currentFloor =
                currentFloor - 1
        else
            currentFloor =
                currentFloor + 1
        end

        -- Anzeige waehrend der Fahrt
        -- aktualisieren
        drawScreen()
    end


    -- Stop
    pulse(SEQUENCER)

    moving = false
    targetFloor = nil

    drawScreen()
end


-- ============================================
-- TOUCH AUSWERTEN
-- ============================================

local function getTouchedFloor(x, y)

    for _, button in ipairs(buttons) do

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


-- ============================================
-- START
-- ============================================

monitor.setTextScale(0.5)

home()

drawScreen()


-- ============================================
-- HAUPTSCHLEIFE
-- ============================================

while true do

    local event, side, x, y =
        os.pullEvent("monitor_touch")

    if not moving then

        local selectedFloor =
            getTouchedFloor(x, y)

        if selectedFloor ~= nil then
            moveTo(selectedFloor)
        end
    end
end
