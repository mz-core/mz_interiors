MZInteriorsConfig = {
  Shells = {
    staging = {
      enabled = true,
      furniture = {
        enabled = true,
        revision = 3,
        bounds = {
          min = { x = -5, y = -5, z = 0 },
          max = { x = 5, y = 5, z = 3 }
        },
        blockedZones = {
          {
            name = 'exit',
            min = { x = 3, y = -5, z = 0 },
            max = { x = 5, y = -3, z = 3 }
          }
        }
      }
    },
    missing_bounds = { enabled = true }
  }
}
MZInteriorsFurnitureBounds = nil

dofile('mz_interiors/shared/furniture_bounds.lua')

local function expect(condition, message)
  if not condition then error(message, 2) end
end

local definition, definitionError = MZInteriorsFurnitureBounds.Get('staging')
expect(definition ~= nil and definitionError == nil, 'valid staging bounds were rejected')
expect(definition.revision == 3 and #definition.blockedZones == 1, 'bounds metadata was lost')

local valid, context = MZInteriorsFurnitureBounds.ValidatePlacement(
  'staging',
  { x = 0, y = 0, z = 0.1 },
  0.5
)
expect(valid == true and context.shell == 'staging', 'valid placement was rejected')
expect(context.wallClearance == 4.5, 'wall clearance feedback is incorrect')

local outside, outsideError = MZInteriorsFurnitureBounds.ValidatePlacement(
  'staging',
  { x = 4.8, y = 0, z = 0.1 },
  0.5
)
expect(outside == false and outsideError == 'outside_furniture_bounds', 'footprint outside bounds must fail')

local blocked, blockedError = MZInteriorsFurnitureBounds.ValidatePlacement(
  'staging',
  { x = 3.2, y = -3.2, z = 0.1 },
  0.2
)
expect(blocked == false and blockedError == 'blocked_furniture_zone', 'exit zone must reject placement')

local missing, missingError = MZInteriorsFurnitureBounds.Get('missing_bounds')
expect(missing == nil and missingError == 'furniture_bounds_disabled', 'shell without bounds must fail closed')

print('[mz_interiors][test] furniture bounds harness passed')
