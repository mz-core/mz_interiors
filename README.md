# mz_interiors

Camada basica de interiores/shells temporarios para o ecossistema MZ.

Este resource foi criado para ser usado futuramente por `mz_houses` e `mz_realestate`, mas nesta fase ele nao implementa casas, venda, dono, chaves, bau, guarda-roupa, garagem, SQL ou decoracao.

## O que ele faz

- Cria um shell/interior temporario client-side.
- Teleporta o player para o offset interno configurado.
- Permite sair e voltar para a posicao externa anterior.
- Deleta o shell ao sair, limpar ou reiniciar o resource.
- Expoe funcoes client-side para outros resources.
- Inclui comandos debug para teste.

## Referencia

O comportamento foi inspirado conceitualmente no `qb-interior`, mas o codigo nao foi copiado. O `mz_interiors` usa config data-driven e mantem a responsabilidade limitada a interiores.

## Importante sobre modelos/stream

O `mz_interiors` pode carregar assets de shells pela pasta `stream/`. O `fxmanifest.lua` ja inclui `.ytyp` dessa pasta quando eles existirem. Os exemplos em `shared/config.lua` usam nomes encontrados na referencia `qb-interior`, como:

- `shell_v16low`
- `shell_v16mid`
- `container_shell`
- `modernhotel_shell`

Para funcionar no jogo, esses modelos precisam estar streamados pelo proprio `mz_interiors` ou por outro resource do servidor. Se o modelo nao estiver carregado/disponivel, o comando retornara erro de model.

## Config

Arquivo:

```txt
mz_interiors/shared/config.lua
```

Principais opcoes:

- `MZInteriorsConfig.Debug`
- `MZInteriorsConfig.Commands.enabled`
- `MZInteriorsConfig.Commands.requireAce`
- `MZInteriorsConfig.Commands.ace`
- `MZInteriorsConfig.DefaultSpawnBase`
- `MZInteriorsConfig.CollisionTimeoutMs`
- `MZInteriorsConfig.Shells`

Exemplo de shell:

```lua
MZInteriorsConfig.Shells.shell_test = {
  label = 'Shell Teste',
  model = 'shell_v16low',
  offset = vector3(0.0, 0.0, 0.0),
  exit = vector4(4.693, -6.015, 1.11, 358.634),
  heading = 0.0
}
```

Shells atualmente selecionaveis:

```txt
apartment_low -> shell_v16low
container -> container_shell
house_mid -> shell_v16mid
motel_modern -> modernhotel_shell
shell_test -> shell_v16low
```

Outros modelos existentes em `stream/` ficam cadastrados como `enabled = false`
quando ainda nao possuem offset seguro de saida. Eles aparecem no diagnostico,
mas nao devem ser oferecidos como opcao de criacao/edicao de imovel ate serem
calibrados.

`house_mid` usa offset relativo de saida `z = 1.15`. Um offset negativo nesse
campo joga o player abaixo da shell, porque ele e somado ao
`DefaultSpawnBase.z`.

## Comandos debug

Comandos padrao:

```txt
/mint_list
/mint_enter shell_test
/mint_exit
/mint_cleanup
```

Se `requireAce = true`, o server valida:

```txt
MZInteriorsConfig.Commands.ace
```

Por padrao, `requireAce = false` para facilitar teste local. Em producao, desative os comandos ou ative ACE.

## Exports client-side

```lua
exports['mz_interiors']:EnterShell(shellName, entranceCoords, options)
exports['mz_interiors']:ExitShell()
exports['mz_interiors']:DestroyCurrentInterior()
exports['mz_interiors']:IsInsideInterior()
exports['mz_interiors']:GetCurrentInterior()
exports['mz_interiors']:GetShells()
```

`GetShells()` tambem existe server-side e retorna uma lista sanitizada com
`name`, `label`, `model`, `enabled`, `selectable`, `hasExit` e
`disabledReason`. O `mz_houses` usa esse contrato para montar o select do menu
admin e validar shell no servidor.

Exemplo:

```lua
local coords = GetEntityCoords(PlayerPedId())
exports['mz_interiors']:EnterShell('shell_test', vector4(coords.x, coords.y, coords.z, GetEntityHeading(PlayerPedId())), {
  instanceId = 'debug:test'
})
```

## Teste rapido

No `server.cfg`:

```txt
ensure mz_interiors
```

No jogo:

```txt
/mint_list
/mint_enter shell_test
/mint_exit
/mint_cleanup
```

Verifique:

- O shell e criado.
- O player entra no offset correto.
- `/mint_exit` volta para fora.
- O objeto e deletado.
- `restart mz_interiors` nao deixa o player preso dentro do shell.

## Limitacoes atuais

- Sem banco.
- Sem casas.
- Sem venda/compra.
- Sem dono/chaves.
- Sem bau.
- Sem guarda-roupa.
- Sem garagem.
- Sem MLO avancado.
- Sem instancia server-side/bucket nesta fase.

## Proximo passo recomendado

Criar `mz_houses` basico usando estes exports:

- cadastrar casa;
- validar acesso;
- chamar `EnterShell`;
- registrar ponto de saida;
- chamar `ExitShell`;
- integrar bau/wardrobe/garagem em fases separadas.
