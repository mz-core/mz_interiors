local CurrentInterior = {
  active = false,
  shell = nil,
  shellName = nil,
  model = nil,
  object = nil,
  entrance = nil,
  exitCoords = nil,
  entryCoords = nil,
  defaultEntryCoords = nil,
  previousCoords = nil,
  previousHeading = nil,
  spawnCoords = nil,
  shellHeading = nil,
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

local function normalizeHeading(value)
  value = tonumber(value) or 0.0
  return ((value % 360.0) + 360.0) % 360.0
end

-- Converte um offset relativo à origem lógica spawnCoords
-- para uma coordenada mundial.
local function shellOffsetToWorld(object, logicalOrigin, offset)
  logicalOrigin = asVector3(logicalOrigin)
  offset = asVector3(offset)

  if not logicalOrigin or not offset then
    return nil
  end

  if not object or object == 0 or not DoesEntityExist(object) then
    return nil
  end

  local entityOrigin = GetEntityCoords(object)

  local nativeWorld = GetOffsetFromEntityInWorldCoords(
    object,
    offset.x,
    offset.y,
    offset.z
  )

  if not nativeWorld then
    return nil
  end

  -- Corrige a diferença entre a origem real do objeto
  -- e a origem lógica usada pelos offsets antigos.
  return vector3(
    nativeWorld.x + (logicalOrigin.x - entityOrigin.x),
    nativeWorld.y + (logicalOrigin.y - entityOrigin.y),
    nativeWorld.z + (logicalOrigin.z - entityOrigin.z)
  )
end

-- Converte uma coordenada mundial para offset relativo
-- à origem lógica spawnCoords.
local function worldToShellOffset(object, logicalOrigin, worldCoords)
  logicalOrigin = asVector3(logicalOrigin)
  worldCoords = asVector3(worldCoords)

  if not logicalOrigin or not worldCoords then
    return nil
  end

  if not object or object == 0 or not DoesEntityExist(object) then
    return nil
  end

  local entityOrigin = GetEntityCoords(object)

  local adjustedWorld = vector3(
    worldCoords.x + (entityOrigin.x - logicalOrigin.x),
    worldCoords.y + (entityOrigin.y - logicalOrigin.y),
    worldCoords.z + (entityOrigin.z - logicalOrigin.z)
  )

  return GetOffsetFromEntityGivenWorldCoords(
    object,
    adjustedWorld.x,
    adjustedWorld.y,
    adjustedWorld.z
  )
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

  -- Uma origem fornecida pelo consumidor identifica uma instancia gerenciada
  -- externamente (por exemplo, uma propriedade do mz_houses). Nesse caso ela
  -- precisa ser exatamente igual em todos os clients que compartilham o bucket.
  local provided = asVector3(options.spawnBase)
  if provided then
    return vector3(provided.x, provided.y, provided.z)
  end

  -- Entradas locais/debug sem origem explicita mantem o espalhamento legado
  -- para reduzir sobreposicao fora de uma instancia server-side gerenciada.
  local configured = asVector3(MZInteriorsConfig.DefaultSpawnBase) or vector3(0.0, 0.0, -50.0)
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
  CurrentInterior.entryCoords = nil
  CurrentInterior.previousCoords = nil
  CurrentInterior.previousHeading = nil
  CurrentInterior.spawnCoords = nil
  CurrentInterior.instanceId = nil
  CurrentInterior.metadata = nil
  CurrentInterior.defaultEntryCoords = nil
  CurrentInterior.shellHeading = nil
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

  local spawnCoords = vector3(
    spawnBase.x + shellOffset.x,
    spawnBase.y + shellOffset.y,
    spawnBase.z + shellOffset.z
  )

  local shellHeading = normalizeHeading(shell.heading)

  local defaultEntryOffset = asVector4(
    options.entryCoords or options.exitCoords or shell.entry or shell.exit,
    shellHeading
  )

  if not defaultEntryOffset then
    return false, 'missing_entry_offset'
  end

  MZInteriors.Debug('enter_shell_prepare', {
    shell = normalizedShellName,
    model = shell.model,
    spawn = {
      x = spawnCoords.x,
      y = spawnCoords.y,
      z = spawnCoords.z
    },
    entryOffset = {
      x = defaultEntryOffset.x,
      y = defaultEntryOffset.y,
      z = defaultEntryOffset.z,
      w = defaultEntryOffset.w
    }
  })

  fadeOut()
  FreezeEntityPosition(ped, true)

  local created, objectOrErr = createShellObject(
    normalizedShellName,
    shell,
    spawnCoords
  )

  if not created then
    FreezeEntityPosition(ped, false)
    fadeIn()
    return false, objectOrErr
  end

  local defaultWorld = shellOffsetToWorld(
    objectOrErr,
    spawnCoords,
    vector3(
      defaultEntryOffset.x,
      defaultEntryOffset.y,
      defaultEntryOffset.z
    )
  )

  if not defaultWorld then
    deleteObject(objectOrErr)
    FreezeEntityPosition(ped, false)
    fadeIn()
    return false, 'invalid_default_entry'
  end

  local defaultInternalCoords = vector4(
    defaultWorld.x,
    defaultWorld.y,
    defaultWorld.z,
    normalizeHeading(shellHeading + defaultEntryOffset.w)
  )

  local internalCoords = defaultInternalCoords
  local entryOffset = asVector3(options.entryOffset)

  if entryOffset then
    local customCoords = shellOffsetToWorld(
      objectOrErr,
      spawnCoords,
      entryOffset
    )

    if not customCoords then
      deleteObject(objectOrErr)
      FreezeEntityPosition(ped, false)
      fadeIn()
      return false, 'invalid_custom_entry'
    end

    internalCoords = vector4(
      customCoords.x,
      customCoords.y,
      customCoords.z,
      normalizeHeading(
        shellHeading + (tonumber(options.entryHeading) or 0.0)
      )
    )
  end

  SetEntityCoords(ped, internalCoords.x, internalCoords.y, internalCoords.z, false, false, false, false)
  SetEntityHeading(ped, internalCoords.w)
  local collisionLoaded = waitForCollisionAt(vector3(internalCoords.x, internalCoords.y, internalCoords.z))
  MZInteriors.Debug('enter_shell_collision', {
    shell = normalizedShellName,
    loaded = collisionLoaded == true
  })
  if entryOffset and collisionLoaded ~= true then
    deleteObject(objectOrErr)
    SetEntityCoords(ped, previousCoords.x, previousCoords.y, previousCoords.z, false, false, false, false)
    SetEntityHeading(ped, previousHeading)
    FreezeEntityPosition(ped, false)
    fadeIn()
    return false, 'custom_entry_collision_failed'
  end
  Wait(100)
  FreezeEntityPosition(ped, false)
  fadeIn()
CurrentInterior.active = true
CurrentInterior.shell = shell
CurrentInterior.shellName = normalizedShellName
CurrentInterior.model = shell.model
CurrentInterior.object = objectOrErr
CurrentInterior.entrance = entrance

-- Ponto padrão configurado no shell.
CurrentInterior.exitCoords = defaultInternalCoords
CurrentInterior.defaultEntryCoords = defaultInternalCoords

-- Ponto real usado nesta entrada:
-- padrão ou personalizado.
CurrentInterior.entryCoords = internalCoords

CurrentInterior.previousCoords = vector3(
  previousCoords.x,
  previousCoords.y,
  previousCoords.z
)

CurrentInterior.previousHeading = previousHeading

-- Origem lógica usada para calcular todos os offsets internos.
CurrentInterior.spawnCoords = spawnCoords

-- Rotação real usada pelo shell.
CurrentInterior.shellHeading = shellHeading

CurrentInterior.instanceId =
  options.instanceId
  or ('client:%s:%s'):format(
    GetPlayerServerId(PlayerId()),
    GetGameTimer()
  )

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

function MZInteriors.ResolveCurrentInteriorPoint(offset)
  if CurrentInterior.active ~= true then
    return nil, 'not_inside'
  end

  local world = shellOffsetToWorld(
    CurrentInterior.object,
    CurrentInterior.spawnCoords,
    offset
  )

  if not world then
    return nil, 'invalid_offset'
  end

  return {
    x = world.x + 0.0,
    y = world.y + 0.0,
    z = world.z + 0.0
  }
end

function MZInteriors.CaptureCurrentInteriorPoint(worldCoords)
  if CurrentInterior.active ~= true then
    return nil, 'not_inside'
  end

  local offset = worldToShellOffset(
    CurrentInterior.object,
    CurrentInterior.spawnCoords,
    worldCoords
  )

  if not offset then
    return nil, 'invalid_world_coords'
  end

  return {
    x = offset.x + 0.0,
    y = offset.y + 0.0,
    z = offset.z + 0.0
  }
end

function MZInteriors.ValidateCurrentFurniturePlacement(worldCoords, footprintRadius)
  local offset, captureErr = MZInteriors.CaptureCurrentInteriorPoint(worldCoords)
  if not offset then return false, captureErr end
  local valid, result = MZInteriorsFurnitureBounds.ValidatePlacement(
    CurrentInterior.shellName,
    offset,
    footprintRadius
  )
  if valid ~= true then return false, result end
  result.world = {
    x = tonumber(worldCoords and worldCoords.x) or 0.0,
    y = tonumber(worldCoords and worldCoords.y) or 0.0,
    z = tonumber(worldCoords and worldCoords.z) or 0.0
  }
  return true, result
end

function MZInteriors.FindCurrentFurniturePlacementSeed(footprintRadius)
  if CurrentInterior.active ~= true then return nil, 'not_inside' end
  local definition, definitionErr = MZInteriorsFurnitureBounds.Get(CurrentInterior.shellName)
  if not definition then return nil, definitionErr end

  local radius = tonumber(footprintRadius)
  if not radius or radius < 0.05 or radius > 20.0 then
    return nil, 'invalid_footprint_radius'
  end

  local margin = 0.05
  local minimum = definition.bounds.min
  local maximum = definition.bounds.max
  local minX, maxX = minimum.x + radius + margin, maximum.x - radius - margin
  local minY, maxY = minimum.y + radius + margin, maximum.y - radius - margin
  if minX > maxX or minY > maxY then return nil, 'furniture_bounds_too_small' end

  local pedOffset = worldToShellOffset(
    CurrentInterior.object,
    CurrentInterior.spawnCoords,
    GetEntityCoords(PlayerPedId())
  )
  local preferredX = pedOffset and pedOffset.x or ((minX + maxX) * 0.5)
  local preferredY = pedOffset and pedOffset.y or ((minY + maxY) * 0.5)
  local candidates = {}
  for xIndex = 0, 4 do
    local x = minX + ((maxX - minX) * (xIndex / 4.0))
    for yIndex = 0, 4 do
      local y = minY + ((maxY - minY) * (yIndex / 4.0))
      candidates[#candidates + 1] = {
        x = x,
        y = y,
        z = minimum.z + margin,
        distance = ((x - preferredX) ^ 2) + ((y - preferredY) ^ 2)
      }
    end
  end
  table.sort(candidates, function(left, right) return left.distance < right.distance end)

  for _, candidate in ipairs(candidates) do
    local valid = MZInteriorsFurnitureBounds.ValidatePlacement(
      CurrentInterior.shellName,
      candidate,
      radius
    )
    if valid == true then
      local world = shellOffsetToWorld(
        CurrentInterior.object,
        CurrentInterior.spawnCoords,
        candidate
      )
      if world then
        return { x = world.x + 0.0, y = world.y + 0.0, z = world.z + 0.0 }
      end
    end
  end
  return nil, 'no_valid_furniture_seed'
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

exports('ResolveCurrentInteriorPoint', function(offset)
  return MZInteriors.ResolveCurrentInteriorPoint(offset)
end)

exports('CaptureCurrentInteriorPoint', function(worldCoords)
  return MZInteriors.CaptureCurrentInteriorPoint(worldCoords)
end)

exports('ValidateCurrentFurniturePlacement', function(worldCoords, footprintRadius)
  return MZInteriors.ValidateCurrentFurniturePlacement(worldCoords, footprintRadius)
end)

exports('FindCurrentFurniturePlacementSeed', function(footprintRadius)
  return MZInteriors.FindCurrentFurniturePlacementSeed(footprintRadius)
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
