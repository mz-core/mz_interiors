MZInteriorsFurnitureBounds = MZInteriorsFurnitureBounds or {}

local function finite(value)
  value = tonumber(value)
  if not value or value ~= value or value == math.huge or value == -math.huge then return nil end
  return value
end

local function point(value)
  if type(value) ~= 'table' and type(value) ~= 'vector3' and type(value) ~= 'vector4' then return nil end
  local x = finite(value.x or value[1])
  local y = finite(value.y or value[2])
  local z = finite(value.z or value[3])
  if not x or not y or not z then return nil end
  return { x = x + 0.0, y = y + 0.0, z = z + 0.0 }
end

local function box(value)
  value = type(value) == 'table' and value or {}
  local minimum = point(value.min)
  local maximum = point(value.max)
  if not minimum or not maximum then return nil end
  if minimum.x >= maximum.x or minimum.y >= maximum.y or minimum.z >= maximum.z then return nil end
  return { min = minimum, max = maximum }
end

local function copyBox(value)
  return {
    min = { x = value.min.x, y = value.min.y, z = value.min.z },
    max = { x = value.max.x, y = value.max.y, z = value.max.z }
  }
end

function MZInteriorsFurnitureBounds.Normalize(shellName, raw)
  shellName = tostring(shellName or ''):gsub('^%s+', ''):gsub('%s+$', '')
  raw = type(raw) == 'table' and raw or {}
  if shellName == '' then return nil, 'invalid_shell' end
  if raw.enabled ~= true then return nil, 'furniture_bounds_disabled' end
  local bounds = box(raw.bounds)
  if not bounds then return nil, 'invalid_furniture_bounds' end
  local blockedZones = {}
  for index, zone in ipairs(type(raw.blockedZones) == 'table' and raw.blockedZones or {}) do
    if index > 64 then return nil, 'too_many_blocked_zones' end
    local normalized = box(zone)
    if not normalized then return nil, 'invalid_blocked_zone' end
    normalized.name = tostring(zone.name or ('zone_%d'):format(index)):sub(1, 64)
    blockedZones[#blockedZones + 1] = normalized
  end
  return {
    shell = shellName,
    revision = math.max(1, math.floor(tonumber(raw.revision) or 1)),
    bounds = bounds,
    blockedZones = blockedZones
  }
end

function MZInteriorsFurnitureBounds.Get(shellName)
  shellName = tostring(shellName or ''):gsub('^%s+', ''):gsub('%s+$', '')
  local shells = type(MZInteriorsConfig) == 'table' and MZInteriorsConfig.Shells or {}
  local ipls = type(MZInteriorsConfig) == 'table' and MZInteriorsConfig.IPLInteriors or {}
  local shell = type(shells[shellName]) == 'table' and shells[shellName]
    or type(ipls[shellName]) == 'table' and ipls[shellName] or nil
  if not shell or shell.enabled == false then return nil, 'shell_unavailable' end
  return MZInteriorsFurnitureBounds.Normalize(shellName, shell.furniture)
end

function MZInteriorsFurnitureBounds.Copy(definition)
  if type(definition) ~= 'table' or type(definition.bounds) ~= 'table' then return nil end
  local result = {
    shell = definition.shell,
    revision = definition.revision,
    bounds = copyBox(definition.bounds),
    blockedZones = {}
  }
  for _, zone in ipairs(definition.blockedZones or {}) do
    local copy = copyBox(zone)
    copy.name = zone.name
    result.blockedZones[#result.blockedZones + 1] = copy
  end
  return result
end

function MZInteriorsFurnitureBounds.ValidatePlacement(shellName, offset, footprintRadius)
  local definition, err = MZInteriorsFurnitureBounds.Get(shellName)
  if not definition then return false, err end
  offset = point(offset)
  if not offset then return false, 'invalid_furniture_offset' end
  local radius = finite(footprintRadius)
  if not radius or radius < 0.05 or radius > 20.0 then return false, 'invalid_footprint_radius' end
  local bounds = definition.bounds
  if offset.x - radius < bounds.min.x or offset.x + radius > bounds.max.x
    or offset.y - radius < bounds.min.y or offset.y + radius > bounds.max.y
    or offset.z < bounds.min.z or offset.z > bounds.max.z then
    return false, 'outside_furniture_bounds'
  end
  for _, zone in ipairs(definition.blockedZones) do
    if offset.x + radius >= zone.min.x and offset.x - radius <= zone.max.x
      and offset.y + radius >= zone.min.y and offset.y - radius <= zone.max.y
      and offset.z >= zone.min.z and offset.z <= zone.max.z then
      return false, 'blocked_furniture_zone'
    end
  end
  return true, {
    shell = definition.shell,
    revision = definition.revision,
    offset = offset,
    footprintRadius = radius,
    wallClearance = math.min(
      (offset.x - radius) - bounds.min.x,
      bounds.max.x - (offset.x + radius),
      (offset.y - radius) - bounds.min.y,
      bounds.max.y - (offset.y + radius)
    )
  }
end
