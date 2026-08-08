local function expect(condition, message)
  if not condition then error(message, 2) end
end

function vector3(x, y, z) return { x = x, y = y, z = z, __type = 'vector3' } end
function vector4(x, y, z, w) return { x = x, y = y, z = z, w = w, __type = 'vector4' } end

local commands, netEvents, handlers, clientEvents = {}, {}, {}, {}
local timer, playerPosition = 1000, { x = 150.0, y = 250.0, z = 30.0 }
local lifecycleCalls, lifecycleEnds, contractCalls = {}, {}, {}

json = { encode = function() return '{}' end }
function GetGameTimer() return timer end
function GetConvarInt(name) return name == 'mz_interiors_ipl_calibration' and 1 or 0 end
function GetResourceState(name) return name == 'mz_banguard' and 'started' or 'missing' end
function GetPlayerName(id) return tonumber(id) == 7 and 'Tester' or nil end
function GetPlayerPed(id) return tonumber(id) == 7 and 70 or 0 end
function DoesEntityExist(entity) return entity == 70 end
function GetEntityCoords() return vector3(playerPosition.x, playerPosition.y, playerPosition.z) end
function GetPlayerRoutingBucket() return 12 end
function IsPlayerAceAllowed() return true end
function RegisterCommand(name, callback) commands[name] = callback end
function RegisterNetEvent(name, callback) netEvents[name] = callback end
function AddEventHandler(name, callback) handlers[name] = callback end
function CreateThread() end
function Wait() end
function TriggerClientEvent(name, target, ...)
  clientEvents[#clientEvents + 1] = { name = name, target = target, args = { ... } }
end

local registeredExports = {}
exports = setmetatable({
  mz_banguard = {
    BeginSecurityLifecycle = function(_, target, kind, ttl, context)
      local id = ('life-%d'):format(#lifecycleCalls + 1)
      lifecycleCalls[#lifecycleCalls + 1] = {
        target = target, kind = kind, ttl = ttl, context = context, id = id
      }
      return id
    end,
    EndSecurityLifecycle = function(_, target, lifecycleId, reason)
      lifecycleEnds[#lifecycleEnds + 1] = {
        target = target, lifecycleId = lifecycleId, reason = reason
      }
      return true
    end,
    ValidateEventContract = function(_, target, contract, payload)
      contractCalls[#contractCalls + 1] = {
        target = target, contract = contract, payload = payload
      }
      return true
    end
  }
}, {
  __call = function(_, name, callback) registeredExports[name] = callback end
})

dofile('mz_interiors/shared/config.lua')
dofile('mz_interiors/shared/furniture_bounds.lua')
dofile('mz_interiors/server/main.lua')

expect(type(commands.mint_ipl) == 'function', 'calibration command missing')
commands.mint_ipl(0, { '7', 'meth_lab' })
expect(#lifecycleCalls == 1, 'entry lifecycle was not issued')
expect(lifecycleCalls[1].kind == 'interior_calibration', 'wrong lifecycle kind')
expect(lifecycleCalls[1].ttl == 30000, 'entry lifecycle TTL mismatch')
expect(lifecycleCalls[1].context.x == 1009.49512, 'entry destination was not server-owned')
expect(lifecycleCalls[1].context.returnX == 150.0, 'return point was not captured server-side')
expect(#clientEvents == 1 and clientEvents[1].name == 'mz_interiors:client:enterIPLCalibration',
  'entry client event missing')
expect(clientEvents[1].args[2] == 'life-1', 'entry lifecycle id missing from client event')

source = 7
netEvents['mz_interiors:server:IPLCalibrationResult']({
  phase = 'entry', lifecycleId = 'life-1', success = true
})
playerPosition = { x = 1009.49512, y = -3196.60010, z = -38.99826 }
netEvents['mz_interiors:server:IPLCalibrationReport']({
  code = 'meth_lab', x = 1009.49512, y = -3196.60010, z = -38.99826, heading = 90.0,
  expectedInteriorId = 247041, resolvedInteriorId = 247041, interiorMatches = true
})
expect(contractCalls[#contractCalls].contract == 'lifecycle.interiors.calibration.report',
  'calibration report contract was not validated')
netEvents['mz_interiors:server:requestIPLCalibrationExit']()
expect(#lifecycleCalls == 2, 'exit lifecycle was not issued')
expect(lifecycleCalls[2].context.x == 150.0 and lifecycleCalls[2].context.y == 250.0,
  'exit destination did not use the server-owned return point')
expect(clientEvents[2].name == 'mz_interiors:client:exitIPLCalibration', 'exit client event missing')

netEvents['mz_interiors:server:IPLCalibrationResult']({
  phase = 'exit', lifecycleId = 'life-2', success = true
})
netEvents['mz_interiors:server:requestIPLCalibrationExit']()
expect(#lifecycleCalls == 2, 'completed calibration session accepted another exit')
expect(#contractCalls == 5, 'calibration events did not pass through event contracts')
expect(#lifecycleEnds >= 1, 'calibration lifecycle was not cleaned up')

print('[mz_interiors][test] IPL BanGuard calibration harness passed')
