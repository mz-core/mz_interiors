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
    local ok, err = MZInteriors.ExitShell()
    if not ok then
      MZInteriors.Notify(('Nao foi possivel sair: %s'):format(tostring(err or 'erro_desconhecido')), 'error')
    end
    return
  end

  if action == 'cleanup' then
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
end

RegisterNetEvent('mz_interiors:client:runCommand', function(action, args)
  MZInteriors.RunCommandAction(action, args)
end)

RegisterNetEvent('mz_interiors:client:commandDenied', function(reason)
  MZInteriors.Notify(('Comando negado: %s'):format(tostring(reason or 'sem_permissao')), 'error')
end)

registerDebugCommands()
