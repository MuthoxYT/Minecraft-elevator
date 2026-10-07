local DIRECTION = "left"
local SEQUENCER = "back"
local CONTACT   = "right"

-- NUR FUER DEN TEST:
-- Wir starten auf Etage 3
local currentFloor = 3

local function pulse(side)
    redstone.setOutput(side, false)
    sleep(0.1)

    redstone.setOutput(side, true)
    sleep(0.2)

    redstone.setOutput(side, false)
end

local function waitForNextFloor()

    -- Erst aktuellen Contact verlassen
    while redstone.getInput(CONTACT) do
        sleep(0.05)
    end

    print("Contact verlassen")

    -- Dann auf naechsten Contact warten
    while not redstone.getInput(CONTACT) do
        sleep(0.05)
    end

    print("Neuer Contact erreicht")
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

    -- Sequenced Gearshift START
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

    -- Sequenced Gearshift STOP
    pulse(SEQUENCER)

    print("ZIEL ERREICHT: Etage " .. currentFloor)
end


print("=== AUFZUG TEST ===")
print("Aktuelle Etage: " .. currentFloor)

write("Ziel-Etage (1-3): ")
local target = tonumber(read())

if target == nil or target < 1 or target > 3 then
    print("Ungueltige Etage")
    return
end

moveTo(target)
