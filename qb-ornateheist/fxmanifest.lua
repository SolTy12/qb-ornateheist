fx_version 'cerulean'

game 'gta5'

shared_script 'config.lua'

client_script 'client.lua'

server_script 'server.lua'

-- Dependencies: qb-core + ox_inventory + ps-dispatch
-- Ensure your framework matches Config.Framework and Config.Inventory in config.lua
-- IMPORTANT: Make sure qb-core starts BEFORE this resource in server.cfg!

dependencies {
    'qb-core',
    'ox_inventory',
    'ps-dispatch'
}

files {
    "html/alarm.html",
    "html/alarm.ogg"
}

ui_page 'html/alarm.html'
