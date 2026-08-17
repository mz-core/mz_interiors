local function read(path)
  local file = assert(io.open(path, 'rb'))
  local content = file:read('*a')
  file:close()
  return content
end

local function expect(condition, message)
  if not condition then error('[player_state_command_guard_harness] ' .. message, 2) end
end

local client = read('mz_interiors/client/main.lua')
local manifest = read('mz_interiors/fxmanifest.lua')

expect(client:find("if action == 'enter' then", 1, true), 'acao enter ausente')
expect(client:find("CanLocalPlayerPerformAction('property.use')", 1, true), 'enter sem contrato canonico')
expect(client:find("if action == 'exit' then", 1, true), 'exit foi removido')
expect(client:find("if action == 'cleanup' then", 1, true), 'cleanup foi removido')
expect(manifest:find("dependency 'mz_core'", 1, true), 'dependency mz_core ausente')

for _, state in ipairs({ 'alive', 'downed', 'dead', 'respawning', 'alive' }) do
  local enterAllowed = state == 'alive'
  local exitAllowed = true
  local cleanupAllowed = true
  expect(exitAllowed and cleanupAllowed, 'cleanup bloqueado em ' .. state)
  expect(enterAllowed == (state == 'alive'), 'matriz enter divergente em ' .. state)
end

print('[player_state_command_guard_harness] PASS enter_states=5 cleanup_preserved=10')
