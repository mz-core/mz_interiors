local function read(path)
  local file = assert(io.open(path, 'rb'))
  local content = file:read('*a')
  file:close()
  return content
end
local function expect(condition, message) if not condition then error(message, 2) end end

local config = read('mz_interiors/shared/config.lua')
local main = read('mz_interiors/client/main.lua')
local client = read('mz_interiors/client/shells.lua')
local server = read('mz_interiors/server/main.lua')
local housesClient = read('mz_houses/client/main.lua')
local housesServer = read('mz_houses/server/service.lua')
local housesMain = read('mz_houses/server/main.lua')
local profiles = read('mz_org_activities/shared/facilities.lua')

for _, code in ipairs({ 'meth_lab', 'counterfeit_cash', 'gunrunning_bunker' }) do
  expect(config:find(code, 1, true), ('IPL catalog entry missing: %s'):format(code))
end
expect(config:find("enabled = true, calibrated = true", 1, true),
  'approved meth lab calibration is not versioned')
expect(config:find('entry = vector4(1009.49512, -3196.60010, -38.99826, 0.0)', 1, true),
  'approved meth lab safe position is not versioned')
expect(client:find('function MZInteriors.EnterIPL', 1, true), 'IPL client entry missing')
expect(config:find("active = { 'meth_lab_basic', 'meth_lab_setup' }", 1, true),
  'meth lab staging style is missing')
expect(config:find('bkr_biker_interior_placement_interior_2_biker_dlc_int_ware01_milo_', 1, true),
  'meth lab IPL must use the runtime placement name with trailing underscore')
expect(config:find("'meth_lab_production'", 1, true),
  'meth lab production set is not explicitly disabled')
expect(client:find('applyIPLEntitySets', 1, true), 'IPL entity-set application is missing')
expect(client:find('applyIPLEntitySets(definition, resolvedInterior or expectedInterior)', 1, true),
  'IPL entity sets must be applied only after the interior resolves')
expect(client:find('ActivateInteriorEntitySet', 1, true)
  and client:find('DeactivateInteriorEntitySet', 1, true)
  and client:find('RefreshInterior', 1, true),
  'IPL entity-set lifecycle is incomplete')
expect(client:find("CurrentInterior.kind = 'ipl'", 1, true), 'IPL current context missing')
expect(config:find('mz_interiors_ipl_calibration', 1, true), 'IPL calibration convar missing')
expect(server:find('IsPlayerAceAllowed', 1, true), 'IPL calibration ACE guard missing')
expect(server:find("'interior_calibration'", 1, true), 'BanGuard calibration lifecycle missing')
expect(server:find("'lifecycle.interiors.calibration.exit'", 1, true), 'calibration exit contract missing')
expect(server:find("'lifecycle.interiors.calibration.report'", 1, true),
  'calibration report contract missing')
expect(server:find('reportDistanceTolerance', 1, true),
  'server-side calibration position comparison missing')
expect(server:find('IPLCalibrationReports', 1, true),
  'accepted calibration evidence cache missing')
expect(server:find('mint_ipl_force_exit', 1, true)
  and main:find("'mz_interiors:client:forceExitIPLCalibration'", 1, true),
  'IPL calibration emergency exit is missing')
expect(server:find("entry_recovered=%s", 1, true)
  and server:find('entryRecoveryRadius', 1, true),
  'IPL exit cannot recover a missing entry acknowledgement')
expect(server:find('calibrationRequestAllowed', 1, true), 'calibration event rate limit missing')
expect(main:find("action == 'ipl_report'", 1, true), 'IPL calibration report missing')
expect(main:find('resolvedInteriorId', 1, true), 'IPL resolved interior report missing')
expect(main:find("err or 'ipl_entry_failed'", 1, true),
  'IPL calibration entry failure does not report its error code')
expect(server:find("'[mz_interiors][ipl_calibration_entry]", 1, true),
  'IPL calibration entry diagnostic is missing')
expect(main:find("'mz_interiors:server:IPLCalibrationReport'", 1, true),
  'IPL report is not submitted for server-side validation')
expect(main:find('requestIPLCalibrationExit', 1, true), 'server-authorized IPL exit missing')
expect(main:find('lifecycleReady', 1, true), 'BanGuard lifecycle confirmation missing')
expect(housesClient:find("interiorType == 'ipl'", 1, true), 'houses client IPL branch missing')
expect(housesServer:find('IsIPLSelectable', 1, true), 'houses server IPL validation missing')
expect(housesMain:find('mhouse_setipl', 1, true), 'houses IPL admin command missing')
expect(housesMain:find("RegisterCommand('mhouse_prepare_org_facility'", 1, true),
  'guarded organization facility property preparer is missing')
expect(housesMain:find('mz_houses_org_facility_runner', 1, true)
  and housesMain:find("category = 'organization'", 1, true)
  and housesMain:find("activities = true", 1, true),
  'organization facility preparer does not enforce staging and property binding')
expect(profiles:find("interiorCode = 'meth_lab'", 1, true), 'drug profile IPL mapping missing')
expect(profiles:find("interiorCode = 'counterfeit_cash'", 1, true), 'laundering IPL mapping missing')
expect(profiles:find("interiorCode = 'gunrunning_bunker'", 1, true), 'weapon IPL mapping missing')
expect(profiles:find("interiorType = 'ipl', interiorCode = 'meth_lab', enabled = true", 1, true),
  'approved drug lab profile is not enabled')
expect(profiles:find("interiorType = 'ipl', interiorCode = 'counterfeit_cash', enabled = false", 1, true)
  and profiles:find("interiorType = 'ipl', interiorCode = 'gunrunning_bunker', enabled = false", 1, true),
  'uncalibrated facility profile was enabled')
expect(not profiles:find("interiorCode = 'container'", 1, true), 'container mapped to real profile')

print('[mz_interiors][test] organization IPL contract harness passed')
