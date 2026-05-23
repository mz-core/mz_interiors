# Checklist mz_interiors

## Validacao local

- [ ] `luac -p mz_interiors/fxmanifest.lua`
- [ ] `luac -p mz_interiors/shared/config.lua`
- [ ] `luac -p mz_interiors/client/main.lua`
- [ ] `luac -p mz_interiors/client/shells.lua`
- [ ] `luac -p mz_interiors/server/main.lua`

## Teste no jogo

- [ ] `ensure mz_interiors`
- [ ] `restart mz_interiors`
- [ ] `/mint_list` lista shells configurados.
- [ ] `/mint_enter shell_test` cria shell e teleporta para dentro.
- [ ] `/mint_exit` retorna para fora e deleta shell.
- [ ] `/mint_cleanup` remove shell ativo, se existir.
- [ ] `restart mz_interiors` enquanto dentro retorna o player e limpa objeto.
- [ ] F8 sem erro.

## Antes de producao

- [ ] Garantir que os modelos de shell estao streamados.
- [ ] Desativar comandos debug ou ativar ACE.
- [ ] Ajustar `DefaultSpawnBase` para local seguro.
- [ ] Ajustar offsets dos shells usados pela base.
