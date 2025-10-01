fx_version "cerulean"
lua54 "yes"
game "gta5"

author "raymans"
description "RM Billing"
version "1.0.0"

ui_page 'web/build/index.html'

files {
    "modules/*.lua",
	"web/build/index.html",
	"web/build/**/*",
    "rm_billing.sql",
}

shared_scripts {
    "@ox_lib/init.lua",
    "config.lua",
}

client_script {
    "client/client.lua",
}

server_script {
    "server/server.lua",
    '@oxmysql/lib/MySQL.lua',
}