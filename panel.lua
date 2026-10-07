-- ============================================================
-- ELEVATOR PANEL - TOUCH TEST
-- Computer #2
-- top = Wireless Modem
-- ============================================================

local SENDER_ID = 1
local MODEM_SIDE = "top"

rednet.open(MODEM_SIDE)

local monitor = peripheral.find("monitor")

if not monitor then
    error("Kein Monitor gefunden!")
end

monitor.setTextScale(0.5)

local WIDTH, HEIGHT = monitor.getSize()

-- ============================================================
-- HILFSFUNKTIONEN
-- ============================================================

local function fillArea(x1, y1, x2, y2, color)
    monitor.setBackgroundColor(color)

    for y = y1, y2 do
        monitor.setCursorPos(x1, y)
        monitor.write(string.rep(" ", x2 - x1 + 1))
    end
end

local function centerText(y, text)
    local x = math.floor((WIDTH - #text) / 2) + 1
    monitor.setCursorPos(x, y)
    monitor.write(text)
end

-- ============================================================
-- BUTTON
-- ============================================================

local buttonWidth = 20
local buttonHeight = 5

local buttonX1 = math.floor((WIDTH - buttonWidth) / 2) + 1
local buttonX2 = buttonX1 + buttonWidth - 1

local buttonY1 = math.floor((HEIGHT - buttonHeight) / 2)
local buttonY2 = buttonY1 + buttonHeight - 1


local function drawScreen()
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
    monitor.clear()

    monitor.setTextColor(colors.lightGray)
    centerText(2, "FUNK-TEST")

    fillArea(
        buttonX1,
        buttonY1,
        buttonX2,
        buttonY2,
        colors.blue
    )

    monitor.setTextColor(colors.white)

    local label = "TEST SENDEN"

    local labelX =
        buttonX1
        + math.floor(
            (buttonWidth - #label) / 2
        )

    local labelY =
        buttonY1
        + math.floor(
            buttonHeight / 2
        )

    monitor.setCursorPos(labelX, labelY)
    monitor.write(label)

    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.gray)

    centerText(
        HEIGHT - 2,
        "Button antippen"
    )
end


local function isInsideButton(x, y)
    return
        x >= buttonX1
        and x <= buttonX2
        and y >= buttonY1
        and y <= buttonY2
end


local function showTouch(x, y, hit)
    monitor.setBackgroundColor(colors.black)
    monitor.setCursorPos(1, HEIGHT)
    monitor.clearLine()

    if hit then
        monitor.setTextColor(colors.lime)
    else
        monitor.setTextColor(colors.yellow)
    end

    local text =
        "Touch: "
        .. tostring(x)
        .. ","
        .. tostring(y)

    monitor.setCursorPos(
        math.floor((WIDTH - #text) / 2) + 1,
        HEIGHT
    )

    monitor.write(text)
end


local function flashButton()
    fillArea(
        buttonX1,
        buttonY1,
        buttonX2,
        buttonY2,
        colors.green
    )

    monitor.setTextColor(colors.black)

    local label = "GESENDET!"

    local labelX =
        buttonX1
        + math.floor(
            (buttonWidth - #label) / 2
        )

    local labelY =
        buttonY1
        + math.floor(
            buttonHeight / 2
        )

    monitor.setCursorPos(labelX, labelY)
    monitor.write(label)

    sleep(0.25)

    drawScreen()
end


-- ============================================================
-- START
-- ============================================================

drawScreen()

print("Panel aktiv")
print("Monitor: " .. WIDTH .. "x" .. HEIGHT)
print("Warte auf Monitor-Touch...")


-- ============================================================
-- EVENT LOOP
-- ============================================================

while true do
    local event, p1, p2, p3 = os.pullEvent()

    if event == "monitor_touch" then
        local side = p1
        local x = p2
        local y = p3

        print(
            "TOUCH: "
            .. tostring(x)
            .. ","
            .. tostring(y)
        )

        local hit =
            isInsideButton(x, y)

        showTouch(x, y, hit)

        if hit then
            rednet.send(
                SENDER_ID,
                {
                    type = "button_test",
                    x = x,
                    y = y
                },
                "elevator_touch_test"
            )

            flashButton()
        end
    end
end
