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
    offset = vector3(0.0, 0.0, 0.0),
    exit = vector4(4.693, -6.015, 1.11, 358.634),
    heading = 0.0
  },

  apartment_low = {
    label = 'Apartamento Simples',
    model = 'shell_v16low',
    offset = vector3(0.0, 0.0, 0.0),
    exit = vector4(4.693, -6.015, 1.11, 358.634),
    heading = 0.0
  },

  house_mid = {
    label = 'Casa Media',
    model = 'shell_v16mid',
    offset = vector3(0.0, 0.0, 0.0),
    exit = vector4(1.561, -14.305, 1.147, 2.263),
    heading = 0.0
  },

  container = {
    label = 'Container',
    model = 'container_shell',
    offset = vector3(0.0, 0.0, 0.0),
    exit = vector4(0.08, -5.73, 1.24, 359.32),
    heading = 0.0
  },

  motel_modern = {
    label = 'Motel Moderno',
    model = 'modernhotel_shell',
    offset = vector3(0.0, 0.0, 0.0),
    exit = vector4(4.98, 4.35, 1.16, 179.79),
    heading = 0.0
  }
}
