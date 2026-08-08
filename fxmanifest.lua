fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Mazus'
description 'Data-driven temporary shell/interior layer for mz_core ecosystem'
version '0.2.0'

shared_scripts {
  'shared/config.lua',
  'shared/furniture_bounds.lua'
}

client_scripts {
  'client/main.lua',
  'client/shells.lua'
}

server_scripts {
  'server/main.lua'
}

files {
  'stream/*.ytyp'
}

data_file 'DLC_ITYP_REQUEST' 'stream/*.ytyp'
