rednet.open("back")
rednet.open("top")

local MAIN_ID = 0
local ELEVATOR_ID = 2

print("Sender aktiv")
print("Main: " .. MAIN_ID)
print("Fahrstuhl: " .. ELEVATOR_ID)

while true do
    local sender, message, protocol = rednet.receive()

    if sender == MAIN_ID then
        rednet.send(ELEVATOR_ID, message, protocol)

    elseif sender == ELEVATOR_ID then
        rednet.send(MAIN_ID, message, protocol)
    end
end
