MZInteriorsConfig = MZInteriorsConfig or {}

MZInteriorsConfig.Debug = false

MZInteriorsConfig.Commands = {
  enabled = true,
  requireAce = false,
  ace = 'group.mz_owner',

  enter = 'mint_enter',
  exit = 'mint_exit',
  cleanup = 'mint_cleanup',
  list = 'mint_list',
  enterIpl = 'mint_ipl',
  reportIpl = 'mint_ipl_report',
  statusIpl = 'mint_ipl_status',
  forceExitIpl = 'mint_ipl_force_exit'
}

MZInteriorsConfig.Notify = {
  useMzNotify = true,
  useOxLib = true,
  chatFallback = true
}

-- Base subterranea usada somente quando EnterShell nao recebe spawnBase.
-- Entradas locais/debug recebem offset por player/timer para reduzir sobreposicao;
-- uma spawnBase explicita e usada sem qualquer alteracao pelo mz_interiors.
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

    entry = vector4(4.693, -6.015, 1.11, 358.634),
    exit = vector4(4.693, -6.015, 1.11, 358.634),

    heading = 0.0,

    -- Primeiro shell liberado para placement residencial. Coordenadas relativas
    -- ao spawnBase e revisadas de forma conservadora.
    furniture = {
      enabled = true,
      revision = 1,
      bounds = {
        min = { x = -4.15, y = -6.45, z = 0.05 },
        max = { x = 5.25, y = 4.35, z = 2.80 }
      },
      blockedZones = {
        {
          name = 'saida',
          min = { x = 3.35, y = -6.45, z = 0.00 },
          max = { x = 5.25, y = -4.45, z = 2.80 }
        }
      }
    }
  },

  apartment_low = {
    label = 'Apartamento Simples',
    model = 'shell_v16low',
    enabled = true,
    offset = vector3(0.0, 0.0, 0.0),

    entry = vector4(4.693, -6.015, 1.11, 358.634),
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
    entry = vector4(1.44, -8.27, 1.15, 268.82),
    exit = vector4(1.44, -8.27, 1.15, 268.82),

    heading = 0.0
  },

  container = {
    label = 'Container',
    model = 'container_shell',
    enabled = true,
    offset = vector3(0.0, 0.0, 0.0),
    
    entry = vector4(0.08, -5.73, 1.24, 359.32),
    exit = vector4(0.08, -5.73, 1.24, 359.32),

    heading = 0.0
  },

  motel_modern = {
    label = 'Motel Moderno',
    model = 'modernhotel_shell',
    enabled = true,
    offset = vector3(0.0, 0.0, 0.0),

    entry = vector4(4.98, 4.35, 1.16, 179.79),
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

-- Interiores nativos candidatos para organizacoes. As referencias vieram do
-- catalogo tecnico ja auditado do mz_settings/Bob74. Cada IPL permanece
-- indisponivel ate entrada, saida, heading e interior ID serem aprovados.
MZInteriorsConfig.IPLInteriors = {
  meth_lab = {
    label = 'Laboratorio de metanfetamina', category = 'criminal.drug_lab',
    enabled = true, calibrated = true,
    load = { 'bkr_biker_interior_placement_interior_2_biker_dlc_int_ware01_milo_' },
    interiorId = 247041,
    -- Aprovado em staging em 2026-08-04. Interior 247041 e divergencia
    -- server/client de 0.016 m no momento da captura.
    entry = vector4(1009.49512, -3196.60010, -38.99826, 0.0),
    -- O IPL sozinho deixa o ambiente sem o cenario funcional. O rollout inicial
    -- usa o estilo basico, sem seguranca melhorada nem produtos em producao.
    entitySets = {
      inactive = {
        'meth_lab_empty', 'meth_lab_upgrade', 'meth_lab_security_high',
        'meth_lab_production'
      },
      active = { 'meth_lab_basic', 'meth_lab_setup' }
    },
    furniture = { enabled = false }
  },
  counterfeit_cash = {
    label = 'Fabrica de dinheiro falso', category = 'criminal.laundering',
    enabled = false, calibrated = false,
    load = { 'bkr_biker_interior_placement_interior_5_biker_dlc_int_ware04_milo_' },
    interiorId = 247809,
    entry = vector4(1121.897, -3195.338, -40.4025, 0.0),
    disabledReason = 'calibration_required',
    furniture = { enabled = false }
  },
  gunrunning_bunker = {
    label = 'Bunker de fabricacao', category = 'criminal.weapons',
    enabled = false, calibrated = false,
    load = { 'gr_grdlc_interior_placement_interior_1_grdlc_int_02_milo_' },
    interiorId = 258561,
    entry = vector4(892.6384, -3245.8664, -98.2645, 0.0),
    disabledReason = 'calibration_required',
    furniture = { enabled = false }
  }
}

MZInteriorsConfig.IPLCalibration = {
  convar = 'mz_interiors_ipl_calibration',
  ace = 'group.mz_owner',
  maxLoadTimeMs = 10000,
  interiorResolveTimeMs = 3000,
  sessionTimeoutMs = 900000,
  requestWindowMs = 10000,
  requestLimit = 6,
  reportDistanceTolerance = 3.0,
  entitySetApplyDelayMs = 250,
  entryRecoveryRadius = 30.0
}
