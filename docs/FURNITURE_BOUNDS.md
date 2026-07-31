# Bounds de móveis

Os bounds são caixas AABB relativas ao `spawnBase` da shell. O servidor usa essas
caixas para impedir placement fora do interior ou sobre zonas reservadas.

```lua
furniture = {
  enabled = true,
  revision = 1,
  bounds = {
    min = { x = -4.0, y = -6.0, z = 0.0 },
    max = { x = 5.0, y = 4.0, z = 2.8 }
  },
  blockedZones = {
    {
      name = 'saida',
      min = { x = 3.0, y = -6.0, z = 0.0 },
      max = { x = 5.0, y = -4.0, z = 2.8 }
    }
  }
}
```

O footprint do catálogo expande a checagem horizontal. Assim, o centro de um sofá
não pode ser colocado junto da parede se parte do modelo ultrapassar os bounds.

`shell_test` é a primeira calibração ativa. Antes de liberar outro shell, revise
visualmente os seis limites e a zona da saída, incrementando `revision` sempre que
alterá-los.

Exports server-side:

- `GetFurnitureBounds(shellName)`
- `ValidateFurniturePlacement(shellName, offset, footprintRadius)`

Exports client-side:

- `ValidateCurrentFurniturePlacement(worldCoords, footprintRadius)`
- `CaptureCurrentInteriorPoint(worldCoords)`
- `ResolveCurrentInteriorPoint(offset)`
