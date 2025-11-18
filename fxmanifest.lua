
fx_version 'cerulean'
game 'gta5'

author "Swkeep#7049 - Converted By Byanski_the_Dev"
description "Keep Companion - Converted"
version "2.0.0"

shared_scripts {
     '@qb-core/shared/locale.lua',
     '@ox_lib/init.lua',
     'locales/en.lua',
     'config.lua',
     'shared/shared.lua',
     'shared/util.lua',
     'shared/badwords.lua'
}

client_scripts {
     'client/animator.lua',
     'client/functions.lua',
     'client/client.lua',
     'client/menu.lua',
     'client/c_util.lua'
}

server_scripts {
     '@oxmysql/lib/MySQL.lua',
     'server/functions.lua',
     'server/server.lua'
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'
