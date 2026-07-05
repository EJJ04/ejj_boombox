fx_version 'cerulean'
game 'gta5'

author 'EJJ'
description 'EJJ Boombox'

ui_page 'web/dist/index.html'

files {
    'web/dist/index.html',
    'web/dist/assets/*.css',
    'web/dist/assets/*.js',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_script 'client/main.lua'
server_script 'server/main.lua'

dependencies {
    'ox_inventory',
    'xsound',
    'ox_lib',
    'ox_target',
}