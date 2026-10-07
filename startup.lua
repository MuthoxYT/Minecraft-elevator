-- Fahrstuhl-Panel automatisch starten

while true do
    local ok = shell.run("panel")

    if not ok then
        printError("Panel konnte nicht gestartet werden.")
    end

    -- Falls panel aus irgendeinem Grund beendet/crasht,
    -- nach 1 Sekunde automatisch erneut starten.
    sleep(1)
end
