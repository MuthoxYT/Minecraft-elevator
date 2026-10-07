-- ============================================================
-- ELEVATOR NETWORK BRIDGE
-- Computer #1
-- ============================================================

local MAIN_ID = 0
local PANEL_ID = 2

local WIRED_MODEM = "back"
local WIRELESS_MODEM = "top"


-- ============================================================
-- MODEMS
-- ============================================================

if peripheral.getType(
    WIRED_MODEM
) ~= "modem" then

    error(
        "Kein Wired Modem auf "
        .. WIRED_MODEM
    )
end


if peripheral.getType(
    WIRELESS_MODEM
) ~= "modem" then

    error(
        "Kein Wireless Modem auf "
        .. WIRELESS_MODEM
    )
end


rednet.open(
    WIRED_MODEM
)

rednet.open(
    WIRELESS_MODEM
)


print(
    "Elevator Bridge #"
    .. os.getComputerID()
)

print(
    "Main:  #"
    .. MAIN_ID
)

print(
    "Panel: #"
    .. PANEL_ID
)

print("")
print("Bridge aktiv.")


-- ============================================================
-- BRIDGE LOOP
-- ============================================================

while true do

    local sender,
          message,
          protocol =
        rednet.receive()


    -- MAIN -> PANEL

    if sender
        == MAIN_ID
    then

        rednet.send(
            PANEL_ID,
            message,
            protocol
        )


    -- PANEL -> MAIN

    elseif sender
        == PANEL_ID
    then

        rednet.send(
            MAIN_ID,
            message,
            protocol
        )
    end
end
