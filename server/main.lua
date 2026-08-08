local function trim(value)
  return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local IPLCalibrationSessions = {}
local IPLCalibrationRates = {}
local IPLCalibrationReports = {}

local function finiteNumber(value)
  value = tonumber(value)
  if not value or value ~= value or value == math.huge or value == -math.huge then return nil end
  return value + 0.0
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
      hasExit = shell.exit ~= nil,
      furnitureReady = MZInteriorsFurnitureBounds.Get(name) ~= nil
    }
  end

  table.sort(out, function(left, right)
    return tostring(left.name or '') < tostring(right.name or '')
  end)

  return out
end

local function listIPLInteriors()
  local catalog = MZInteriorsConfig and MZInteriorsConfig.IPLInteriors or {}
  local out = {}
  for code, definition in pairs(catalog) do
    definition = type(definition) == 'table' and definition or {}
    local selectable = definition.enabled == true and definition.calibrated == true
      and definition.entry ~= nil and tonumber(definition.interiorId) ~= nil
    out[#out + 1] = {
      name = tostring(code),
      label = trim(definition.label) ~= '' and trim(definition.label) or tostring(code),
      category = trim(definition.category),
      type = 'ipl',
      interiorId = tonumber(definition.interiorId),
      enabled = selectable,
      selectable = selectable,
      calibrated = definition.calibrated == true,
      disabledReason = selectable and nil or (definition.disabledReason or 'calibration_required'),
      furnitureReady = MZInteriorsFurnitureBounds.Get(code) ~= nil
    }
  end
  table.sort(out, function(left, right) return tostring(left.name) < tostring(right.name) end)
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

exports('GetIPLInteriors', function()
  return listIPLInteriors()
end)

exports('GetFurnitureBounds', function(shellName)
  local definition, err = MZInteriorsFurnitureBounds.Get(shellName)
  if not definition then return false, err end
  return true, MZInteriorsFurnitureBounds.Copy(definition)
end)

exports('ValidateFurniturePlacement', function(shellName, offset, footprintRadius)
  return MZInteriorsFurnitureBounds.ValidatePlacement(shellName, offset, footprintRadius)
end)

local function calibrationEnabled()
  local cfg = MZInteriorsConfig and MZInteriorsConfig.IPLCalibration or {}
  local convar = trim(cfg.convar)
  return convar ~= '' and GetConvarInt(convar, 0) == 1
end

local function canCalibrate(source)
  if tonumber(source) == 0 then return true end
  local ace = trim((MZInteriorsConfig.IPLCalibration or {}).ace)
  return ace ~= '' and IsPlayerAceAllowed(source, ace) == true
end

local function calibrationRequestAllowed(source)
  source = tonumber(source)
  if not source or source <= 0 then return false end
  local cfg = MZInteriorsConfig and MZInteriorsConfig.IPLCalibration or {}
  local windowMs = math.max(1000, math.floor(tonumber(cfg.requestWindowMs) or 10000))
  local limit = math.max(1, math.floor(tonumber(cfg.requestLimit) or 6))
  local now = GetGameTimer()
  local state = IPLCalibrationRates[source]
  if not state or now - state.startedAt >= windowMs then
    IPLCalibrationRates[source] = { startedAt = now, count = 1 }
    return true
  end
  state.count = state.count + 1
  return state.count <= limit
end

local function getPlayerPosition(source)
  source = tonumber(source)
  if not source or source <= 0 or not GetPlayerName(source) then return nil end
  local ped = GetPlayerPed(source)
  if not ped or ped <= 0 or not DoesEntityExist(ped) then return nil end
  local coords = GetEntityCoords(ped)
  if not coords then return nil end
  return { x = coords.x + 0.0, y = coords.y + 0.0, z = coords.z + 0.0 }
end

local function isNearCalibrationEntry(position, interiorCode)
  local definition = (MZInteriorsConfig.IPLInteriors or {})[trim(interiorCode):lower()]
  local entry = type(definition) == 'table' and definition.entry or nil
  if not position or not entry or not tonumber(entry.x) or not tonumber(entry.y)
      or not tonumber(entry.z) then return false end
  local radius = math.max(5.0, math.min(100.0,
    tonumber((MZInteriorsConfig.IPLCalibration or {}).entryRecoveryRadius) or 30.0))
  return math.sqrt(
    (position.x - entry.x) ^ 2 + (position.y - entry.y) ^ 2 + (position.z - entry.z) ^ 2
  ) <= radius
end

local function endCalibrationLifecycle(source, lifecycleId, reason)
  if type(lifecycleId) ~= 'string' or lifecycleId == '' then return end
  if GetResourceState('mz_banguard') ~= 'started' then return end
  pcall(function()
    exports['mz_banguard']:EndSecurityLifecycle(source, lifecycleId, reason or 'ipl_calibration_cleanup')
  end)
end

local function beginCalibrationLifecycle(source, destination, returnPoint, interiorCode, reason)
  if GetResourceState('mz_banguard') ~= 'started' then return true, nil end
  local ok, lifecycleId = pcall(function()
    return exports['mz_banguard']:BeginSecurityLifecycle(source, 'interior_calibration', 30000, {
      bucket = GetPlayerRoutingBucket(source),
      x = destination.x, y = destination.y, z = destination.z,
      returnX = returnPoint and returnPoint.x or nil,
      returnY = returnPoint and returnPoint.y or nil,
      returnZ = returnPoint and returnPoint.z or nil,
      reason = reason,
      correlationId = ('ipl:%s:%s'):format(trim(interiorCode), reason)
    })
  end)
  if not ok or type(lifecycleId) ~= 'string' then return false, 'security_session_failed' end
  return true, lifecycleId
end

local function validateCalibrationContract(source, contract, payload)
  if GetResourceState('mz_banguard') ~= 'started' then return true end
  local ok, valid, reason = pcall(function()
    return exports['mz_banguard']:ValidateEventContract(source, contract, payload)
  end)
  if not ok then return false, 'contract_export_failed' end
  return valid == true, reason
end

local function clearCalibrationSession(source, reason)
  local session = IPLCalibrationSessions[tonumber(source)]
  if not session then return end
  IPLCalibrationSessions[tonumber(source)] = nil
  endCalibrationLifecycle(source, session.entryLifecycleId, reason)
  if session.exitLifecycleId ~= session.entryLifecycleId then
    endCalibrationLifecycle(source, session.exitLifecycleId, reason)
  end
end

RegisterCommand(tostring((MZInteriorsConfig.Commands or {}).enterIpl or 'mint_ipl'), function(source, args)
  if not calibrationEnabled() then
    if tonumber(source) == 0 then print('[mz_interiors] IPL calibration blocked: runner_convar_disabled') end
    return
  end

  local targetSource, interiorCode
  if tonumber(source) == 0 then
    targetSource = tonumber(args and args[1])
    interiorCode = trim(args and args[2])
  else
    targetSource = tonumber(source)
    interiorCode = trim(args and args[1])
  end
  if not targetSource or targetSource <= 0 or interiorCode == '' then
    print('[mz_interiors] usage player=/mint_ipl <code> console=mint_ipl <source> <code>')
    return
  end
  if not canCalibrate(source) then
    print(('[mz_interiors] IPL calibration blocked source=%s reason=forbidden'):format(source))
    return
  end
  local definition = (MZInteriorsConfig.IPLInteriors or {})[interiorCode]
  if type(definition) ~= 'table' then
    print(('[mz_interiors] IPL calibration blocked code=%s reason=ipl_interior_not_found'):format(interiorCode))
    return
  end
  local origin = getPlayerPosition(targetSource)
  local entry = definition.entry
  if not origin or not entry or tonumber(entry.x) == nil or tonumber(entry.y) == nil
      or tonumber(entry.z) == nil then
    print(('[mz_interiors] IPL calibration blocked target=%s reason=player_or_entry_unavailable'):format(targetSource))
    return
  end
  clearCalibrationSession(targetSource, 'calibration_replaced')
  local destination = { x = entry.x + 0.0, y = entry.y + 0.0, z = entry.z + 0.0 }
  local securityOk, lifecycleOrErr = beginCalibrationLifecycle(
    targetSource, destination, origin, interiorCode, 'ipl_calibration_enter'
  )
  if not securityOk then
    print(('[mz_interiors] IPL calibration blocked target=%s reason=%s'):format(targetSource, lifecycleOrErr))
    return
  end
  local cfg = MZInteriorsConfig and MZInteriorsConfig.IPLCalibration or {}
  IPLCalibrationSessions[targetSource] = {
    interiorCode = interiorCode,
    returnPoint = origin,
    bucket = GetPlayerRoutingBucket(targetSource),
    entryLifecycleId = lifecycleOrErr,
    entered = false,
    exitPending = false,
    expiresAt = GetGameTimer() + math.max(60000, math.floor(tonumber(cfg.sessionTimeoutMs) or 900000))
  }
  TriggerClientEvent(
    'mz_interiors:client:enterIPLCalibration', targetSource, interiorCode, lifecycleOrErr
  )
  print(('[mz_interiors] IPL calibration requested source=%s target=%s code=%s'):format(
    source, targetSource, interiorCode
  ))
end, true)

RegisterCommand(tostring((MZInteriorsConfig.Commands or {}).statusIpl or 'mint_ipl_status'), function(source, args)
  if not canCalibrate(source) then
    print(('[mz_interiors] IPL calibration status blocked source=%s reason=forbidden'):format(source))
    return
  end
  local interiorCode = trim(args and args[1]):lower()
  if interiorCode == '' then
    print('[mz_interiors] usage mint_ipl_status <code>')
    return
  end
  local report = IPLCalibrationReports[interiorCode]
  if not report then
    print(('[mz_interiors][ipl_calibration_status] code=%s accepted=no reason=report_not_received'):format(
      interiorCode
    ))
    return
  end
  print(('[mz_interiors][ipl_calibration_status] %s'):format(json.encode(report)))
end, true)

local function requestCalibrationExit(src, forced)
  local session = IPLCalibrationSessions[src]
  if not session then
    print(('[mz_interiors][ipl_calibration_exit] source=%s authorized=no reason=session_not_found'):format(
      tostring(src)
    ))
    if forced == true then
      TriggerClientEvent('mz_interiors:client:forceExitIPLCalibration', src, nil, nil)
    end
    return false
  end
  local current = getPlayerPosition(src)
  if session.entered ~= true then
    if forced == true or isNearCalibrationEntry(current, session.interiorCode) then
      session.entered = true
      print(('[mz_interiors][ipl_calibration_exit] source=%s code=%s entry_recovered=%s'):format(
        tostring(src), tostring(session.interiorCode), forced == true and 'forced' or 'server_position'
      ))
    else
      print(('[mz_interiors][ipl_calibration_exit] source=%s code=%s authorized=no reason=entry_not_confirmed'):format(
        tostring(src), tostring(session.interiorCode)
      ))
      return false
    end
  end
  if session.exitPending == true then
    print(('[mz_interiors][ipl_calibration_exit] source=%s code=%s authorized=no reason=exit_already_pending'):format(
      tostring(src), tostring(session.interiorCode)
    ))
    return false
  end
  if GetPlayerRoutingBucket(src) ~= tonumber(session.bucket) then
    print(('[mz_interiors][ipl_calibration_exit] source=%s code=%s authorized=no reason=bucket_changed'):format(
      tostring(src), tostring(session.interiorCode)
    ))
    clearCalibrationSession(src, 'calibration_bucket_changed')
    if forced == true then
      TriggerClientEvent('mz_interiors:client:forceExitIPLCalibration', src, session.interiorCode, nil)
    end
    return false
  end
  if not current then
    print(('[mz_interiors][ipl_calibration_exit] source=%s code=%s authorized=no reason=player_position_unavailable'):format(
      tostring(src), tostring(session.interiorCode)
    ))
    return false
  end
  local securityOk, lifecycleOrErr = beginCalibrationLifecycle(
    src, session.returnPoint, current, session.interiorCode, 'ipl_calibration_exit'
  )
  if not securityOk then
    print(('[mz_interiors][ipl_calibration_exit] source=%s code=%s authorized=no reason=%s'):format(
      tostring(src), tostring(session.interiorCode), tostring(lifecycleOrErr)
    ))
    TriggerClientEvent('mz_interiors:client:commandDenied', src, lifecycleOrErr)
    return false
  end
  session.exitLifecycleId = lifecycleOrErr
  session.exitPending = true
  print(('[mz_interiors][ipl_calibration_exit] source=%s code=%s authorized=yes forced=%s'):format(
    tostring(src), tostring(session.interiorCode), forced == true and 'yes' or 'no'
  ))
  TriggerClientEvent(
    forced == true and 'mz_interiors:client:forceExitIPLCalibration'
      or 'mz_interiors:client:exitIPLCalibration',
    src, session.interiorCode, lifecycleOrErr
  )
  return true
end

RegisterCommand(tostring((MZInteriorsConfig.Commands or {}).forceExitIpl or 'mint_ipl_force_exit'), function(source, args)
  if not canCalibrate(source) then return end
  local targetSource = tonumber(source) == 0 and tonumber(args and args[1]) or tonumber(source)
  if not targetSource or targetSource <= 0 or not GetPlayerName(targetSource) then
    print('[mz_interiors] usage console=mint_ipl_force_exit <source>')
    return
  end
  requestCalibrationExit(targetSource, true)
end, true)

RegisterNetEvent('mz_interiors:server:requestIPLCalibrationExit', function()
  local src = tonumber(source)
  if not calibrationRequestAllowed(src) then
    print(('[mz_interiors][ipl_calibration_exit] source=%s authorized=no reason=rate_limited'):format(
      tostring(src)
    ))
    return
  end
  local contractOk, contractErr = validateCalibrationContract(
    src, 'lifecycle.interiors.calibration.exit', {}
  )
  if not contractOk then
    print(('[mz_interiors][ipl_calibration_exit] source=%s authorized=no reason=%s'):format(
      tostring(src), tostring(contractErr or 'contract_rejected')
    ))
    return
  end
  requestCalibrationExit(src, false)
end)

RegisterNetEvent('mz_interiors:server:IPLCalibrationResult', function(payload)
  local src = tonumber(source)
  payload = type(payload) == 'table' and payload or {}
  if not calibrationRequestAllowed(src) then
    print(('[mz_interiors][ipl_calibration_result] source=%s accepted=no reason=rate_limited'):format(
      tostring(src)
    ))
    return
  end
  local contractOk, contractErr = validateCalibrationContract(
    src, 'lifecycle.interiors.calibration.result', payload
  )
  if not contractOk then
    print(('[mz_interiors][ipl_calibration_result] source=%s accepted=no reason=%s'):format(
      tostring(src), tostring(contractErr or 'contract_rejected')
    ))
    return
  end
  local session = IPLCalibrationSessions[src]
  if not session then
    print(('[mz_interiors][ipl_calibration_result] source=%s accepted=no reason=session_not_found'):format(
      tostring(src)
    ))
    return
  end
  local phase = trim(payload.phase):lower()
  local lifecycleId = trim(payload.lifecycleId)
  if phase == 'entry' and lifecycleId == trim(session.entryLifecycleId) then
    if payload.success == true then
      session.entered = true
      print(('[mz_interiors][ipl_calibration_entry] source=%s code=%s success=yes'):format(
        tostring(src), tostring(session.interiorCode)
      ))
      return
    end
    print(('[mz_interiors][ipl_calibration_entry] source=%s code=%s success=no reason=%s'):format(
      tostring(src), tostring(session.interiorCode), trim(payload.error) ~= '' and trim(payload.error)
        or 'ipl_entry_failed'
    ))
    clearCalibrationSession(src, 'calibration_entry_failed')
    return
  end
  if phase == 'exit' and session.exitPending == true
      and lifecycleId == trim(session.exitLifecycleId) then
    if payload.success == true then
      clearCalibrationSession(src, 'calibration_completed')
      return
    end
    print(('[mz_interiors][ipl_calibration_exit] source=%s code=%s success=no reason=%s'):format(
      tostring(src), tostring(session.interiorCode), trim(payload.error) ~= '' and trim(payload.error)
        or 'ipl_exit_failed'
    ))
    endCalibrationLifecycle(src, session.exitLifecycleId, 'calibration_exit_failed')
    session.exitLifecycleId = nil
    session.exitPending = false
    return
  end
  print(('[mz_interiors][ipl_calibration_result] source=%s code=%s accepted=no reason=phase_or_lifecycle_mismatch'):format(
    tostring(src), tostring(session.interiorCode)
  ))
end)

RegisterNetEvent('mz_interiors:server:IPLCalibrationReport', function(payload)
  local src = tonumber(source)
  payload = type(payload) == 'table' and payload or {}
  if not calibrationRequestAllowed(src)
      or not validateCalibrationContract(
        src, 'lifecycle.interiors.calibration.report', payload
      ) then return end
  local session = IPLCalibrationSessions[src]
  if not session then
    print(('[mz_interiors][ipl_calibration_report] source=%s accepted=no reason=session_not_found'):format(
      tostring(src)
    ))
    return
  end
  if session.exitPending == true then
    print(('[mz_interiors][ipl_calibration_report] source=%s code=%s accepted=no reason=exit_pending'):format(
      tostring(src), tostring(session.interiorCode)
    ))
    return
  end
  local serverPosition = getPlayerPosition(src)
  if session.entered ~= true then
    if isNearCalibrationEntry(serverPosition, session.interiorCode) then
      session.entered = true
      print(('[mz_interiors][ipl_calibration_report] source=%s code=%s entry_recovered=server_position'):format(
        tostring(src), tostring(session.interiorCode)
      ))
    else
      print(('[mz_interiors][ipl_calibration_report] source=%s code=%s accepted=no reason=entry_not_confirmed'):format(
        tostring(src), tostring(session.interiorCode)
      ))
      return
    end
  end

  local interiorCode = trim(payload.code):lower()
  local definition = (MZInteriorsConfig.IPLInteriors or {})[interiorCode]
  local expectedInteriorId = type(definition) == 'table' and tonumber(definition.interiorId) or nil
  local resolvedInteriorId = math.floor(finiteNumber(payload.resolvedInteriorId) or 0)
  local claimedExpectedId = math.floor(finiteNumber(payload.expectedInteriorId) or 0)
  local x, y, z = finiteNumber(payload.x), finiteNumber(payload.y), finiteNumber(payload.z)
  local heading = finiteNumber(payload.heading)
  if interiorCode == '' or interiorCode ~= trim(session.interiorCode):lower()
      or not expectedInteriorId or claimedExpectedId ~= expectedInteriorId
      or resolvedInteriorId ~= expectedInteriorId or payload.interiorMatches ~= true
      or not x or not y or not z or not heading or heading < 0.0 or heading > 360.0 then
    print(('[mz_interiors][ipl_calibration_report] source=%s code=%s accepted=no reason=invalid_report'):format(
      tostring(src), interiorCode ~= '' and interiorCode or 'invalid'
    ))
    return
  end

  if not serverPosition then return end
  local dx, dy, dz = x - serverPosition.x, y - serverPosition.y, z - serverPosition.z
  local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
  local tolerance = math.max(0.25, math.min(10.0,
    tonumber((MZInteriorsConfig.IPLCalibration or {}).reportDistanceTolerance) or 3.0))
  if distance > tolerance then
    print(('[mz_interiors][ipl_calibration_report] source=%s code=%s accepted=no reason=position_mismatch distance=%.3f'):format(
      tostring(src), interiorCode, distance
    ))
    return
  end

  local report = {
    accepted = true,
    code = interiorCode,
    source = src,
    playerName = tostring(GetPlayerName(src) or 'unknown'),
    candidateEntry = { x = x, y = y, z = z, w = heading % 360.0 },
    serverPosition = {
      x = serverPosition.x + 0.0,
      y = serverPosition.y + 0.0,
      z = serverPosition.z + 0.0
    },
    serverDistance = tonumber(('%.3f'):format(distance)),
    expectedInteriorId = expectedInteriorId,
    resolvedInteriorId = resolvedInteriorId,
    interiorMatches = true,
    capturedAt = os.date('!%Y-%m-%dT%H:%M:%SZ')
  }
  IPLCalibrationReports[interiorCode] = report
  session.report = report
  print(('[mz_interiors][ipl_calibration_report] %s'):format(json.encode(report)))
end)

AddEventHandler('playerDropped', function()
  local src = tonumber(source)
  clearCalibrationSession(src, 'player_dropped')
  IPLCalibrationRates[src] = nil
end)

CreateThread(function()
  while true do
    Wait(30000)
    local now = GetGameTimer()
    for source, session in pairs(IPLCalibrationSessions) do
      if not GetPlayerName(source) or now >= (tonumber(session.expiresAt) or 0) then
        clearCalibrationSession(source, 'calibration_expired')
      end
    end
  end
end)
