-- ============================================
-- CREATE + CC:TWEAKED ELEVATOR
-- Testaufbau: Etagen 0 - 2
--
-- LEFT  = Richtungs-Gearshift
-- BACK  = Sequenced Gearshift
-- RIGHT = normale Etagen-Contacts (1, 2)
-- TOP   = Home-Contact / Etage 0
-- ============================================

local DIRECTION = "left"
local SEQUENCER = "back"
local CONTACT   = "right"
local HOME      = "top"

local MIN_FLOOR = 0
local MAX_FLOOR = 2

-- Beim Start ist die Position unbekannt.
local currentFloor = nil


-- ============================================
-- REDSTONE-PULS
-- ============================================

local function pulse(side)
    redstone.setOutput(side, false)
    sleep(0.1)

    redstone.setOutput(side, true)
    sleep(0.2)

    redstone.setOutput(side, false)
end


-- ============================================
-- AUF NAECHSTE NORMALE ETAGE WARTEN
-- ============================================

local function waitForNextFloor()

    -- Falls wir momentan auf einem normalen
    -- Contact stehen, diesen erst verlassen.
    while redstone.getInput(CONTACT) do
        sleep(0.05)
    end

    -- Danach auf den naechsten normalen
    -- Etagen-Contact warten.
    while not redstone.getInput(CONTACT) do
        sleep(0.05)
    end
end


-- ============================================
-- HOMING
-- ============================================

local function home()

    term.clear()
    term.setCursorPos(1, 1)

    print("=== HOMING ===")
    print("")

    -- Falls wir schon auf Etage 0 stehen:
    if redstone.getInput(HOME) then
        currentFloor = 0

        print("Home bereits erkannt.")
        print("Aktuelle Etage: 0")

        sleep(1)
        return
    end

    print("Position unbekannt.")
    print("Fahre nach oben zu Home...")

    -- TRUE = hoch
    redstone.setOutput(DIRECTION, true)

    -- Aufzug starten
    pulse(SEQUENCER)

    -- Auf separaten Home-Sensor warten
    while not redstone.getInput(HOME) do
        sleep(0.05)
    end

    -- Home erreicht -> sofort stoppen
    pulse(SEQUENCER)

    currentFloor = 0

    print("")
    print("HOME erreicht!")
    print("Aktuelle Etage: 0")

    sleep(1)
end


-- ============================================
-- ZU ETAGE FAHREN
-- ============================================

local function moveTo(targetFloor)

    if targetFloor == currentFloor then
        print("Bereits auf Etage " .. currentFloor)
        return
    end

    local goingUp = targetFloor < currentFloor

    if goingUp then
        print(
            "Fahre HOCH: "
            .. currentFloor
            .. " -> "
            .. targetFloor
        )

        -- TRUE = hoch
        redstone.setOutput(DIRECTION, true)

    else
        print(
            "Fahre RUNTER: "
            .. currentFloor
            .. " -> "
            .. targetFloor
        )

        -- FALSE = runter
        redstone.setOutput(DIRECTION, false)
    end

    -- Aufzug starten
    pulse(SEQUENCER)


    -- ========================================
    -- SONDERFALL: ZIEL = HOME / ETAGE 0
    -- ========================================

    if targetFloor == 0 then

        while not redstone.getInput(HOME) do
            sleep(0.05)
        end

        pulse(SEQUENCER)

        currentFloor = 0

        print("Etage 0 erreicht")
        return
    end


    -- ========================================
    -- NORMALE ETAGEN 1 - 2
    -- ========================================

    while currentFloor ~= targetFloor do

        waitForNextFloor()

        if goingUp then
            currentFloor = currentFloor - 1
        else
            currentFloor = currentFloor + 1
        end

        print("Etage " .. currentFloor .. " erreicht")
    end

    -- Ziel erreicht -> stoppen
    pulse(SEQUENCER)

    print("Angekommen auf Etage " .. currentFloor)
end


-- ============================================
-- PROGRAMMSTART
-- ============================================

-- Nach jedem Start zuerst Referenzfahrt.
home()


-- ============================================
-- HAUPTSCHLEIFE
-- ============================================

while true do

    term.clear()
    term.setCursorPos(1, 1)

    print("=== AUFZUG ===")
    print("")
    print("Aktuelle Etage: " .. currentFloor)
    print("")
    write(
        "Ziel ("
        .. MIN_FLOOR
        .. "-"
        .. MAX_FLOOR
        .. "): "
    )

    local target = tonumber(read())

    if target
        and target >= MIN_FLOOR
        and target <= MAX_FLOOR
        and target % 1 == 0 then

        moveTo(target)

        print("")
        print("Enter fuer neue Fahrt...")
        read()

    else

        print("")
        print("Ungueltige Etage!")
        sleep(1)
    end
end
