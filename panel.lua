rednet.open("top")

local SENDER_ID = 1

local monitor = peripheral.find("monitor")

if not monitor then
    error("Kein Monitor gefunden!")
end

monitor.setTextScale(0.5)
monitor.setBackgroundColor(colors.black)
monitor.setTextColor(colors.white)
monitor.clear()

monitor.setCursorPos(2, 2)
monitor.write("PANEL AKTIV")

monitor.setCursorPos(2, 4)
monitor.write("WARTE AUF DATEN")

while true do
    local event, p1, p2, p3 = os.pullEvent()

    if event == "rednet_message" then
        local sender = p1
        local message = p2
        local protocol = p3

        if sender == SENDER_ID
            and protocol == "elevator_test"
        then
            monitor.setBackgroundColor(colors.black)
            monitor.setTextColor(colors.lime)
            monitor.clear()

            monitor.setCursorPos(2, 2)
            monitor.write(tostring(message))

            monitor.setTextColor(colors.white)
            monitor.setCursorPos(2, 4)
            monitor.write("TOUCH MICH")
        end

    elseif event == "monitor_touch" then
        local side = p1
        local x = p2
        local y = p3

        monitor.setTextColor(colors.yellow)
        monitor.setCursorPos(2, 6)
        monitor.clearLine()
        monitor.write("Touch: " .. x .. "," .. y)

        rednet.send(
            SENDER_ID,
            {
                type = "touch",
                x = x,
                y = y
            },
            "elevator_touch_test"
        )
    end
end
