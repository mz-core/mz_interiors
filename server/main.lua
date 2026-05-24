local function trim(value)
  return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function debugLog(message, data)
  if not MZInteriorsConfig or MZInteriorsConfig.Debug ~= true then
    return
  end

  local suffix = ''
  if data ~= nil then
    suffix = (' | %s'):format(json.encode(data))
  end

  print(('[mz_interiors][server] %s%s'):format(tostring(message), suffix))
end

local function listShells()
  local shells = MZInteriorsConfig and MZInteriorsConfig.Shells or {}
  local out = {}

  for name, shell in pairs(shells) do
    shell = type(shell) == 'table' and shell or {}
    local enabled = shell.enabled ~= false and shell.exit ~= nil and trim(shell.model) ~= ''
    out[#out + 1] = {
      name = tostring(name),
      label = trim(shell.label) ~= '' and trim(shell.label) or tostring(name),
      model = trim(shell.model),
      enabled = enabled,
      selectable = enabled,
      disabledReason = enabled and nil or (shell.disabledReason or 'missing_model_or_exit'),
      hasExit = shell.exit ~= nil
    }
  end

  table.sort(out, function(left, right)
    return tostring(left.name or '') < tostring(right.name or '')
  end)

  return out
end

local function canUseDebugCommand(source)
  local commands = MZInteriorsConfig.Commands or {}
  if commands.requireAce ~= true then
    return true
  end

  local ace = trim(commands.ace)
  if ace == '' then
    return false
  end

  return IsPlayerAceAllowed(source, ace) == true
end

RegisterNetEvent('mz_interiors:server:runCommand', function(action, args)
  local src = source

  if not canUseDebugCommand(src) then
    debugLog('command_denied', {
      source = src,
      action = action
    })
    TriggerClientEvent('mz_interiors:client:commandDenied', src, 'sem_permissao')
    return
  end

  TriggerClientEvent('mz_interiors:client:runCommand', src, trim(action), type(args) == 'table' and args or {})
end)

exports('GetShells', function()
  return listShells()
end)
