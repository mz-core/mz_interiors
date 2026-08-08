MZInteriors = MZInteriors or {}

local function trim(value)
  return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

function MZInteriors.Debug(message, data)
  if not MZInteriorsConfig or MZInteriorsConfig.Debug ~= true then
    return
  end

  local suffix = ''
  if data ~= nil then
    suffix = (' | %s'):format(json.encode(data))
  end

  print(('[mz_interiors] %s%s'):format(tostring(message), suffix))
end

function MZInteriors.Notify(message, notifyType)
  local text = tostring(message or '')
  local kind = tostring(notifyType or 'inform')
  local notifyConfig = MZInteriorsConfig.Notify or {}

  if notifyConfig.useMzNotify == true and GetResourceState('mz_notify') == 'started' then
    local ok = pcall(function()
      exports['mz_notify']:Notify({
        type = kind,
        title = 'Interiores',
        message = text
      })
    end)

    if ok then
      return
    end
  end

  if notifyConfig.useOxLib == true and lib and type(lib.notify) == 'function' then
    lib.notify({
      type = kind,
      title = 'Interiores',
      description = text
    })
    return
  end

  if notifyConfig.chatFallback ~= false then
    TriggerEvent('chat:addMessage', {
      color = { 120, 190, 255 },
      args = { 'mz_interiors', text }
    })
  else
    print(('[mz_interiors] %s'):format(text))
  end
end

function MZInteriors.GetShellConfig(shellName)
  local key = trim(shellName)
  if key == '' then
    return nil, 'invalid_shell'
  end

  local shells = MZInteriorsConfig and MZInteriorsConfig.Shells or {}
  local shell = shells[key]
  if type(shell) ~= 'table' then
    return nil, 'shell_not_found'
  end

  return shell, nil, key
end

function MZInteriors.GetIPLConfig(interiorCode)
  local key = trim(interiorCode)
  if key == '' then return nil, 'invalid_ipl_interior' end
  local catalog = MZInteriorsConfig and MZInteriorsConfig.IPLInteriors or {}
  local interior = catalog[key]
  if type(interior) ~= 'table' then return nil, 'ipl_interior_not_found' end
  return interior, nil, key
end

local function listShells()
  local shells = MZInteriorsConfig and MZInteriorsConfig.Shells or {}
  local names = {}

  for name in pairs(shells) do
    names[#names + 1] = name
  end

  table.sort(names)

  if #names == 0 then
    MZInteriors.Notify('Nenhum shell cadastrado.', 'error')
    return
  end

  MZInteriors.Notify(('Shells: %s'):format(table.concat(names, ', ')), 'inform')

  for _, name in ipairs(names) do
    local shell = shells[name] or {}
    print(('[mz_interiors] %s - %s (%s) enabled=%s reason=%s'):format(
      name,
      tostring(shell.label or 'Sem label'),
      tostring(shell.model or 'sem_model'),
      tostring(shell.enabled ~= false and shell.exit ~= nil),
      tostring(shell.disabledReason or 'nil')
    ))
  end
end

function MZInteriors.RunCommandAction(action, args)
  action = trim(action)
  args = type(args) == 'table' and args or {}

  if action == 'list' then
    listShells()
    return
  end

  if action == 'enter' then
    local shellName = trim(args[1])
    if shellName == '' then
      MZInteriors.Notify('Uso: /' .. tostring((MZInteriorsConfig.Commands or {}).enter or 'mint_enter') .. ' shellName', 'error')
      return
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local ok, err = MZInteriors.EnterShell(shellName, vector4(coords.x, coords.y, coords.z, heading), {
      reason = 'debug_command'
    })

    if not ok then
      MZInteriors.Notify(('Nao foi possivel entrar: %s'):format(tostring(err or 'erro_desconhecido')), 'error')
    end
    return
  end

  if action == 'exit' then
    local current = MZInteriors.GetCurrentInterior()
    local metadata = type(current.metadata) == 'table' and current.metadata or {}
    if trim(metadata.houseCode) ~= '' then
      MZInteriors.Notify('Use a saida da propriedade para encerrar a sessao corretamente.', 'error')
      return
    end
    if current.kind == 'ipl' and metadata.calibration == true then
      MZInteriors.Notify('Solicitando saida segura do IPL...', 'inform')
      TriggerServerEvent('mz_interiors:server:requestIPLCalibrationExit')
      return
    end
    local ok, err = MZInteriors.ExitShell()
    if not ok then
      MZInteriors.Notify(('Nao foi possivel sair: %s'):format(tostring(err or 'erro_desconhecido')), 'error')
    end
    return
  end

  if action == 'cleanup' then
    local current = MZInteriors.GetCurrentInterior()
    local metadata = type(current.metadata) == 'table' and current.metadata or {}
    if trim(metadata.houseCode) ~= '' then
      MZInteriors.Notify('Use a saida da propriedade para encerrar a sessao corretamente.', 'error')
      return
    end
    if current.kind == 'ipl' and metadata.calibration == true then
      TriggerServerEvent('mz_interiors:server:requestIPLCalibrationExit')
      return
    end
    local ok, err = MZInteriors.DestroyCurrentInterior({
      teleportBack = true,
      reason = 'debug_cleanup'
    })
    if ok then
      MZInteriors.Notify('Interior limpo.', 'success')
    else
      MZInteriors.Notify(('Nada para limpar: %s'):format(tostring(err or 'sem_interior')), 'inform')
    end
    return
  end

  if action == 'ipl_report' then
    local current = MZInteriors.GetCurrentInterior()
    if current.active ~= true or current.kind ~= 'ipl' then
      MZInteriors.Notify('Entre em um IPL de calibracao antes de gerar o relatorio.', 'error')
      return
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local resolvedInteriorId = type(GetInteriorFromEntity) == 'function'
      and tonumber(GetInteriorFromEntity(ped)) or nil
    local definition = type(current.shell) == 'table' and current.shell or {}
    local report = {
      code = current.interiorCode or current.shellName,
      coords = {
        x = tonumber(('%0.5f'):format(coords.x)),
        y = tonumber(('%0.5f'):format(coords.y)),
        z = tonumber(('%0.5f'):format(coords.z)),
        w = tonumber(('%0.3f'):format(GetEntityHeading(ped)))
      },
      expectedInteriorId = tonumber(definition.interiorId),
      resolvedInteriorId = resolvedInteriorId,
      interiorMatches = tonumber(definition.interiorId) == resolvedInteriorId
    }

    print(('[mz_interiors][ipl_calibration] %s'):format(json.encode(report)))
    TriggerServerEvent('mz_interiors:server:IPLCalibrationReport', {
      code = tostring(report.code or ''),
      x = report.coords.x,
      y = report.coords.y,
      z = report.coords.z,
      heading = report.coords.w,
      expectedInteriorId = report.expectedInteriorId,
      resolvedInteriorId = report.resolvedInteriorId,
      interiorMatches = report.interiorMatches == true
    })
    MZInteriors.Notify(
      ('Relatorio %s enviado ao F8 e ao servidor. ID=%s, confere=%s.'):format(
        tostring(report.code),
        tostring(report.resolvedInteriorId or 'nil'),
        tostring(report.interiorMatches)
      ),
      report.interiorMatches and 'success' or 'error'
    )
    return
  end
end

local function requestCommand(action, args)
  local commands = MZInteriorsConfig.Commands or {}
  if commands.requireAce == true then
    TriggerServerEvent('mz_interiors:server:runCommand', action, args or {})
    return
  end

  MZInteriors.RunCommandAction(action, args)
end

local function registerDebugCommands()
  local commands = MZInteriorsConfig.Commands or {}
  if commands.enabled ~= true then
    return
  end

  RegisterCommand(tostring(commands.list or 'mint_list'), function()
    requestCommand('list', {})
  end, false)

  RegisterCommand(tostring(commands.enter or 'mint_enter'), function(_, args)
    requestCommand('enter', args or {})
  end, false)

  RegisterCommand(tostring(commands.exit or 'mint_exit'), function()
    requestCommand('exit', {})
  end, false)

  RegisterCommand(tostring(commands.cleanup or 'mint_cleanup'), function()
    requestCommand('cleanup', {})
  end, false)

  RegisterCommand(tostring(commands.reportIpl or 'mint_ipl_report'), function()
    requestCommand('ipl_report', {})
  end, false)
end

RegisterNetEvent('mz_interiors:client:runCommand', function(action, args)
  MZInteriors.RunCommandAction(action, args)
end)

RegisterNetEvent('mz_interiors:client:commandDenied', function(reason)
  MZInteriors.Notify(('Comando negado: %s'):format(tostring(reason or 'sem_permissao')), 'error')
end)

local function reportCalibrationResult(phase, lifecycleId, success, errorCode)
  if type(lifecycleId) == 'string' and lifecycleId ~= '' and success == true then
    TriggerServerEvent('mz_banguard:server:lifecycleReady', lifecycleId)
  end
  TriggerServerEvent('mz_interiors:server:IPLCalibrationResult', {
    phase = phase,
    lifecycleId = type(lifecycleId) == 'string' and lifecycleId or nil,
    success = success == true,
    error = success == true and nil or trim(errorCode):lower():sub(1, 64)
  })
end

RegisterNetEvent('mz_interiors:client:enterIPLCalibration', function(interiorCode, lifecycleId)
  local ped = PlayerPedId()
  local coords = GetEntityCoords(ped)
  local heading = GetEntityHeading(ped)
  local ok, err = MZInteriors.EnterIPL(
    interiorCode,
    vector4(coords.x, coords.y, coords.z, heading),
    {
      calibration = true,
      reason = 'staging_calibration',
      metadata = {
        calibration = true,
        securityLifecycleId = lifecycleId
      }
    }
  )
  if not ok then
    reportCalibrationResult('entry', lifecycleId, false, err or 'ipl_entry_failed')
    MZInteriors.Notify(('Nao foi possivel abrir IPL: %s'):format(tostring(err)), 'error')
    return
  end
  reportCalibrationResult('entry', lifecycleId, true)
  MZInteriors.Notify(
    ('Use /%s na posicao segura escolhida e depois /%s para sair.'):format(
      tostring((MZInteriorsConfig.Commands or {}).reportIpl or 'mint_ipl_report'),
      tostring((MZInteriorsConfig.Commands or {}).exit or 'mint_exit')
    ),
    'inform'
  )
end)

RegisterNetEvent('mz_interiors:client:exitIPLCalibration', function(interiorCode, lifecycleId)
  local current = MZInteriors.GetCurrentInterior()
  local metadata = type(current.metadata) == 'table' and current.metadata or {}
  if current.active ~= true or current.kind ~= 'ipl' or metadata.calibration ~= true
      or trim(current.interiorCode or current.shellName) ~= trim(interiorCode) then
    reportCalibrationResult('exit', lifecycleId, false, 'ipl_exit_context_mismatch')
    return
  end
  local ok, err = MZInteriors.ExitShell()
  reportCalibrationResult('exit', lifecycleId, ok == true, err or 'ipl_exit_failed')
  if not ok then
    MZInteriors.Notify(('Nao foi possivel sair do IPL: %s'):format(tostring(err)), 'error')
  end
end)

RegisterNetEvent('mz_interiors:client:forceExitIPLCalibration', function(interiorCode, lifecycleId)
  local current = MZInteriors.GetCurrentInterior()
  local metadata = type(current.metadata) == 'table' and current.metadata or {}
  if current.active ~= true or current.kind ~= 'ipl' or metadata.calibration ~= true
      or (trim(interiorCode) ~= ''
        and trim(current.interiorCode or current.shellName) ~= trim(interiorCode)) then
    return
  end
  if type(lifecycleId) == 'string' and lifecycleId ~= '' then
    TriggerServerEvent('mz_banguard:server:lifecycleReady', lifecycleId)
  end
  local ok, err = MZInteriors.DestroyCurrentInterior({
    teleportBack = true,
    reason = 'forced_calibration_exit'
  })
  reportCalibrationResult('exit', lifecycleId, ok == true, err or 'ipl_force_exit_failed')
  MZInteriors.Notify(
    ok == true and 'Saida de calibracao concluida.'
      or ('Falha ao sair da calibracao: %s'):format(tostring(err)),
    ok == true and 'success' or 'error'
  )
end)

registerDebugCommands()
