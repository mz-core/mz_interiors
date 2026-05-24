local CurrentInterior = {
  active = false,
  shell = nil,
  shellName = nil,
  model = nil,
  object = nil,
  entrance = nil,
  exitCoords = nil,
  previousCoords = nil,
  previousHeading = nil,
  spawnCoords = nil,
  instanceId = nil,
  metadata = nil
}

local function cloneCurrentInterior()
  local copy = {}
  for key, value in pairs(CurrentInterior) do
    copy[key] = value
  end
  return copy
end

local function asVector3(value)
  if type(value) == 'vector3' then
    return value
  end

  if type(value) == 'vector4' then
    return vector3(value.x, value.y, value.z)
  end

  if type(value) == 'table' then
    return vector3(tonumber(value.x) or 0.0, tonumber(value.y) or 0.0, tonumber(value.z) or 0.0)
  end

  return nil
end

local function asVector4(value, fallbackHeading)
  if type(value) == 'vector4' then
    return value
  end

  if type(value) == 'vector3' then
    return vector4(value.x, value.y, value.z, tonumber(fallbackHeading) or 0.0)
  end

  if type(value) == 'table' then
    return vector4(
      tonumber(value.x) or 0.0,
      tonumber(value.y) or 0.0,
      tonumber(value.z) or 0.0,
      tonumber(value.w or value.h or value.heading or fallbackHeading) or 0.0
    )
  end

  return nil
end

local function waitForFadeOut(timeoutMs)
  local startedAt = GetGameTimer()
  while not IsScreenFadedOut() do
    Wait(0)
    if GetGameTimer() - startedAt > (timeoutMs or 1000) then
      break
    end
  end
end

local function fadeOut()
  local fade = MZInteriorsConfig.Fade or {}
  if fade.enabled == false then
    return
  end

  DoScreenFadeOut(tonumber(fade.outMs) or 250)
  waitForFadeOut(1200)
end

local function fadeIn()
  local fade = MZInteriorsConfig.Fade or {}
  if fade.enabled == false then
    return
  end

  DoScreenFadeIn(tonumber(fade.inMs) or 450)
end

local function loadModel(modelName)
  local modelHash = type(modelName) == 'number' and modelName or GetHashKey(tostring(modelName or ''))
  if modelHash == 0 or not IsModelValid(modelHash) then
    return false, 'invalid_model'
  end

  if HasModelLoaded(modelHash) then
    return true, modelHash
  end

  RequestModel(modelHash)

  local timeout = tonumber(MZInteriorsConfig.ModelLoadTimeoutMs) or 8000
  local startedAt = GetGameTimer()

  while not HasModelLoaded(modelHash) do
    Wait(25)
    if GetGameTimer() - startedAt >= timeout then
      return false, 'model_load_timeout'
    end
  end

  return true, modelHash
end

local function unloadModel(modelHash)
  if modelHash and modelHash ~= 0 then
    SetModelAsNoLongerNeeded(modelHash)
  end
end

local function deleteObject(object)
  if object and object ~= 0 and DoesEntityExist(object) then
    SetEntityAsMissionEntity(object, true, true)
    DeleteEntity(object)
  end
end

local function getSpawnBase(options)
  options = type(options) == 'table' and options or {}

  local configured = asVector3(options.spawnBase) or asVector3(MZInteriorsConfig.DefaultSpawnBase) or vector3(0.0, 0.0, -50.0)
  local spacing = tonumber(MZInteriorsConfig.SpawnSpacing) or 40.0
  local playerId = PlayerId()
  local slot = (playerId % 16)
  local jitter = (GetGameTimer() % 7) * 2.0

  return vector3(configured.x + (slot * spacing), configured.y + jitter, configured.z)
end

local function createShellObject(shellName, shell, spawnCoords)
  local ok, modelOrErr = loadModel(shell.model)
  if not ok then
    return false, modelOrErr
  end

  local modelHash = modelOrErr
  local heading = tonumber(shell.heading) or 0.0
  local object = CreateObject(modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, false, false, false)

  if not object or object == 0 or not DoesEntityExist(object) then
    unloadModel(modelHash)
    return false, 'object_create_failed'
  end

  SetEntityAsMissionEntity(object, true, true)
  SetEntityHeading(object, heading)
  FreezeEntityPosition(object, true)
  SetEntityInvincible(object, true)
  RequestCollisionAtCoord(spawnCoords.x, spawnCoords.y, spawnCoords.z)

  MZInteriors.Debug('shell_object_created', {
    shell = shellName,
    model = shell.model,
    object = object,
    x = spawnCoords.x,
    y = spawnCoords.y,
    z = spawnCoords.z
  })

  unloadModel(modelHash)
  return true, object
end

local function waitForCollisionAt(coords, timeoutMs)
  if not coords then
    return false
  end

  RequestCollisionAtCoord(coords.x, coords.y, coords.z)
  NewLoadSceneStart(coords.x, coords.y, coords.z, coords.x, coords.y, coords.z, 35.0, 0)

  local startedAt = GetGameTimer()
  local loaded = false
  while GetGameTimer() - startedAt < (tonumber(timeoutMs) or tonumber(MZInteriorsConfig.CollisionTimeoutMs) or 5000) do
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    if HasCollisionLoadedAroundEntity(PlayerPedId()) then
      loaded = true
      break
    end
    Wait(50)
  end

  NewLoadSceneStop()
  return loaded
end

local function resetState()
  CurrentInterior.active = false
  CurrentInterior.shell = nil
  CurrentInterior.shellName = nil
  CurrentInterior.model = nil
  CurrentInterior.object = nil
  CurrentInterior.entrance = nil
  CurrentInterior.exitCoords = nil
  CurrentInterior.previousCoords = nil
  CurrentInterior.previousHeading = nil
  CurrentInterior.spawnCoords = nil
  CurrentInterior.instanceId = nil
  CurrentInterior.metadata = nil
end

function MZInteriors.DestroyCurrentInterior(options)
  options = type(options) == 'table' and options or {}

  local hadInterior = CurrentInterior.active == true or (CurrentInterior.object and CurrentInterior.object ~= 0)
  local object = CurrentInterior.object
  local ped = PlayerPedId()

  if options.teleportBack == true and CurrentInterior.entrance then
    local target = asVector4(CurrentInterior.entrance, CurrentInterior.previousHeading)
    if target then
      SetEntityCoords(ped, target.x, target.y, target.z, false, false, false, false)
      SetEntityHeading(ped, target.w)
    end
  end

  FreezeEntityPosition(ped, false)
  deleteObject(object)
  resetState()

  MZInteriors.Debug('destroy_current_interior', {
    hadInterior = hadInterior,
    reason = options.reason
  })

  if not hadInterior then
    return false, 'not_inside'
  end

  return true
end

function MZInteriors.EnterShell(shellName, entranceCoords, options)
  options = type(options) == 'table' and options or {}

  if CurrentInterior.active == true then
    return false, 'already_inside'
  end

  local shell, shellErr, normalizedShellName = MZInteriors.GetShellConfig(shellName)
  if not shell then
    return false, shellErr or 'shell_not_found'
  end

  if shell.enabled == false then
    return false, shell.disabledReason or 'shell_disabled'
  end

  if not shell.model or tostring(shell.model) == '' then
    return false, 'missing_model'
  end

  local ped = PlayerPedId()
  local previousCoords = GetEntityCoords(ped)
  local previousHeading = GetEntityHeading(ped)
  local entrance = asVector4(entranceCoords, previousHeading) or vector4(previousCoords.x, previousCoords.y, previousCoords.z, previousHeading)

  local spawnBase = getSpawnBase(options)
  local shellOffset = asVector3(shell.offset) or vector3(0.0, 0.0, 0.0)
  local spawnCoords = vector3(spawnBase.x + shellOffset.x, spawnBase.y + shellOffset.y, spawnBase.z + shellOffset.z)
  local exitOffset = asVector4(options.exitCoords or shell.exit, shell.heading)

  if not exitOffset then
    return false, 'missing_exit_offset'
  end

  local internalCoords = vector4(
    spawnCoords.x + exitOffset.x,
    spawnCoords.y + exitOffset.y,
    spawnCoords.z + exitOffset.z,
    tonumber(options.heading or exitOffset.w or shell.heading) or 0.0
  )

  MZInteriors.Debug('enter_shell_prepare', {
    shell = normalizedShellName,
    model = shell.model,
    spawn = { x = spawnCoords.x, y = spawnCoords.y, z = spawnCoords.z },
    target = { x = internalCoords.x, y = internalCoords.y, z = internalCoords.z, w = internalCoords.w }
  })

  fadeOut()
  FreezeEntityPosition(ped, true)

  local created, objectOrErr = createShellObject(normalizedShellName, shell, spawnCoords)
  if not created then
    FreezeEntityPosition(ped, false)
    fadeIn()
    return false, objectOrErr
  end

  SetEntityCoords(ped, internalCoords.x, internalCoords.y, internalCoords.z, false, false, false, false)
  SetEntityHeading(ped, internalCoords.w)
  local collisionLoaded = waitForCollisionAt(vector3(internalCoords.x, internalCoords.y, internalCoords.z))
  MZInteriors.Debug('enter_shell_collision', {
    shell = normalizedShellName,
    loaded = collisionLoaded == true
  })
  Wait(100)
  FreezeEntityPosition(ped, false)
  fadeIn()

  CurrentInterior.active = true
  CurrentInterior.shell = shell
  CurrentInterior.shellName = normalizedShellName
  CurrentInterior.model = shell.model
  CurrentInterior.object = objectOrErr
  CurrentInterior.entrance = entrance
  CurrentInterior.exitCoords = internalCoords
  CurrentInterior.previousCoords = vector3(previousCoords.x, previousCoords.y, previousCoords.z)
  CurrentInterior.previousHeading = previousHeading
  CurrentInterior.spawnCoords = spawnCoords
  CurrentInterior.instanceId = options.instanceId or ('client:%s:%s'):format(GetPlayerServerId(PlayerId()), GetGameTimer())
  CurrentInterior.metadata = options.metadata

  MZInteriors.Debug('entered_shell', {
    shell = normalizedShellName,
    model = shell.model,
    instanceId = CurrentInterior.instanceId,
    reason = options.reason
  })

  MZInteriors.Notify('Voce entrou no interior.', 'success')
  return true, cloneCurrentInterior()
end

function MZInteriors.ExitShell()
  if CurrentInterior.active ~= true then
    return false, 'not_inside'
  end

  local ped = PlayerPedId()
  local target = asVector4(CurrentInterior.entrance, CurrentInterior.previousHeading)

  fadeOut()
  FreezeEntityPosition(ped, true)

  if target then
    SetEntityCoords(ped, target.x, target.y, target.z, false, false, false, false)
    SetEntityHeading(ped, target.w)
  end

  deleteObject(CurrentInterior.object)
  resetState()

  Wait(100)
  FreezeEntityPosition(ped, false)
  fadeIn()

  MZInteriors.Notify('Voce saiu do interior.', 'success')
  return true
end

function MZInteriors.IsInsideInterior()
  return CurrentInterior.active == true
end

function MZInteriors.GetCurrentInterior()
  return cloneCurrentInterior()
end

function MZInteriors.GetShells()
  local shells = MZInteriorsConfig.Shells or {}
  local out = {}

  for name, shell in pairs(shells) do
    shell = type(shell) == 'table' and shell or {}
    local enabled = shell.enabled ~= false and shell.exit ~= nil and tostring(shell.model or '') ~= ''
    out[#out + 1] = {
      name = name,
      label = shell.label or name,
      model = shell.model,
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

exports('EnterShell', function(shellName, entranceCoords, options)
  return MZInteriors.EnterShell(shellName, entranceCoords, options)
end)

exports('ExitShell', function()
  return MZInteriors.ExitShell()
end)

exports('DestroyCurrentInterior', function(options)
  options = type(options) == 'table' and options or {}
  if options.teleportBack == nil then
    options.teleportBack = true
  end
  options.reason = options.reason or 'export'
  return MZInteriors.DestroyCurrentInterior(options)
end)

exports('IsInsideInterior', function()
  return MZInteriors.IsInsideInterior()
end)

exports('GetCurrentInterior', function()
  return MZInteriors.GetCurrentInterior()
end)

exports('GetShells', function()
  return MZInteriors.GetShells()
end)

AddEventHandler('onResourceStop', function(resource)
  if resource ~= GetCurrentResourceName() then
    return
  end

  MZInteriors.DestroyCurrentInterior({
    teleportBack = true,
    reason = 'resource_stop'
  })
end)
