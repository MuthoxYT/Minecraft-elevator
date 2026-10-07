local DIRECTION = "left"
local SEQUENCER = "back"
local CONTACT   = "right"

-- Vorerst Startposition fuer den Test
local currentFloor = 1

local function pulse(side)
    redstone.setOutput(side, false)
    sleep(0.1)

    redstone.setOutput(side, true)
    sleep(0.2)

    redstone.setOutput(side, false)
end

local function waitForNextFloor()
    -- Aktuellen Contact erst verlassen
    while redstone.getInput(CONTACT) do
        sleep(0.05)
    end

    -- Auf naechsten Contact warten
    while not redstone.getInput(CONTACT) do
        sleep(0.05)
    end
end

local function moveTo(targetFloor)
    if targetFloor == currentFloor then
        print("Bereits auf Etage " .. currentFloor)
        return
    end

    local goingUp = targetFloor < currentFloor

    if goingUp then
        print("Fahre HOCH: " .. currentFloor .. " -> " .. targetFloor)
        redstone.setOutput(DIRECTION, true)
    else
        print("Fahre RUNTER: " .. currentFloor .. " -> " .. targetFloor)
        redstone.setOutput(DIRECTION, false)
    end

    -- Aufzug starten
    pulse(SEQUENCER)

    while currentFloor ~= targetFloor do
        waitForNextFloor()

        if goingUp then
            currentFloor = currentFloor - 1
        else
            currentFloor = currentFloor + 1
        end

        print("Etage " .. currentFloor .. " erreicht")
    end

    -- Aufzug stoppen
    pulse(SEQUENCER)

    print("Angekommen auf Etage " .. currentFloor)
end


-- =========================
-- HAUPTPROGRAMM
-- =========================

while true do
    term.clear()
    term.setCursorPos(1, 1)

    print("=== AUFZUG ===")
    print("")
    print("Aktuelle Etage: " .. currentFloor)
    print("")
    write("Ziel (1-3): ")

    local target = tonumber(read())

    if target and target >= 1 and target <= 3 then
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
