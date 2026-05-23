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
