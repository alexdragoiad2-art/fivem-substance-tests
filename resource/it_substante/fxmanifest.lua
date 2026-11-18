fx_version 'cerulean'
game 'gta5'
lua54 'yes'

description 'FiveM ESX - consum (mancare, bauturi, alcool, droguri), alcoolemie/substante in corp, etilotest si drugtest'
version '1.0.0'

ui_page 'web/index.html'

shared_scripts {
  '@ox_lib/init.lua',
  '@es_extended/imports.lua',
  'config.lua',
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/corp.lua',
  'server/teste.lua',
  'server/tox.lua',
}

client_scripts {
  'client/consum.lua',
  'client/efecte.lua',
  'client/teste.lua',
}

files {
  'web/index.html',
  'web/style.css',
  'web/app.js',
  'stream/it_aparate.ytyp',
}

-- modelele aparatelor (in mana si pe jos): MODELE\Blender\aparate_politie\aparate.py
data_file 'DLC_ITYP_REQUEST' 'stream/it_aparate.ytyp'

dependencies {
  'es_extended',
  'ox_lib',
  'ox_inventory',
  'oxmysql',
}
