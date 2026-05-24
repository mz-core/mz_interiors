MZInteriorsConfig = MZInteriorsConfig or {}

MZInteriorsConfig.Debug = false

MZInteriorsConfig.Commands = {
  enabled = true,
  requireAce = false,
  ace = 'group.mz_owner',

  enter = 'mint_enter',
  exit = 'mint_exit',
  cleanup = 'mint_cleanup',
  list = 'mint_list'
}

MZInteriorsConfig.Notify = {
  useMzNotify = true,
  useOxLib = true,
  chatFallback = true
}

-- Base subterranea usada para shells temporarios de debug/MVP.
-- Cada entrada recebe pequeno offset por player/timer para reduzir sobreposicao.
MZInteriorsConfig.DefaultSpawnBase = vector3(0.0, 0.0, -50.0)
MZInteriorsConfig.SpawnSpacing = 40.0
MZInteriorsConfig.ModelLoadTimeoutMs = 8000
MZInteriorsConfig.CollisionTimeoutMs = 5000
MZInteriorsConfig.Fade = {
  enabled = true,
  outMs = 250,
  inMs = 450
}

-- Estes modelos existem na referencia qb-interior, mas o mz_interiors nao copia
-- assets. Garanta que os modelos estejam streamados por algum resource do servidor
-- antes de usar os comandos/exports.
MZInteriorsConfig.Shells = {
  shell_test = {
    label = 'Shell Teste',
    model = 'shell_v16low',
    enabled = true,
    offset = vector3(0.0, 0.0, 0.0),
    exit = vector4(4.693, -6.015, 1.11, 358.634),
    heading = 0.0
  },

  apartment_low = {
    label = 'Apartamento Simples',
    model = 'shell_v16low',
    enabled = true,
    offset = vector3(0.0, 0.0, 0.0),
    exit = vector4(4.693, -6.015, 1.11, 358.634),
    heading = 0.0
  },

  house_mid = {
    label = 'Casa Media',
    model = 'shell_v16mid',
    enabled = true,
    offset = vector3(0.0, 0.0, 0.0),
    -- Offset relativo ao spawn da shell. Antes estava -48.85, o que jogava
    -- o player para baixo da shell quando DefaultSpawnBase.z = -50.0.
    exit = vector4(1.44, -8.27, 1.15, 268.82),
    heading = 0.0
  },

  container = {
    label = 'Container',
    model = 'container_shell',
    enabled = true,
    offset = vector3(0.0, 0.0, 0.0),
    exit = vector4(0.08, -5.73, 1.24, 359.32),
    heading = 0.0
  },

  motel_modern = {
    label = 'Motel Moderno',
    model = 'modernhotel_shell',
    enabled = true,
    offset = vector3(0.0, 0.0, 0.0),
    exit = vector4(4.98, 4.35, 1.16, 179.79),
    heading = 0.0
  },

  standard_motel = {
    label = 'Motel Standard',
    model = 'standardmotel_shell',
    enabled = false,
    disabledReason = 'missing_exit_offset'
  },

  mid_apartment_furnished = {
    label = 'Apartamento Medio Mobiliado',
    model = 'furnitured_midapart',
    enabled = false,
    disabledReason = 'missing_exit_offset'
  },

  frank_aunt = {
    label = 'Casa Tia Denise',
    model = 'shell_frankaunt',
    enabled = false,
    disabledReason = 'missing_exit_offset'
  },

  lester_house = {
    label = 'Casa Lester',
    model = 'shell_lester',
    enabled = false,
    disabledReason = 'missing_exit_offset'
  },

  michael_house = {
    label = 'Casa Michael',
    model = 'shell_michael',
    enabled = false,
    disabledReason = 'missing_exit_offset'
  },

  office_01 = {
    label = 'Escritorio 01',
    model = 'shell_office1',
    enabled = false,
    disabledReason = 'missing_exit_offset'
  },

  ranch = {
    label = 'Ranch',
    model = 'shell_ranch',
    enabled = false,
    disabledReason = 'missing_exit_offset'
  },

  store_01 = {
    label = 'Loja 01',
    model = 'shell_store1',
    enabled = false,
    disabledReason = 'missing_exit_offset'
  },

  trailer = {
    label = 'Trailer',
    model = 'shell_trailer',
    enabled = false,
    disabledReason = 'missing_exit_offset'
  },

  trevor_house = {
    label = 'Casa Trevor',
    model = 'shell_trevor',
    enabled = false,
    disabledReason = 'missing_exit_offset'
  },

  warehouse_01 = {
    label = 'Warehouse 01',
    model = 'shell_warehouse1',
    enabled = false,
    disabledReason = 'missing_exit_offset'
  },

  garage_shell = {
    label = 'Garagem Shell',
    model = 'shell_garagem',
    enabled = false,
    disabledReason = 'missing_exit_offset'
  }
}
