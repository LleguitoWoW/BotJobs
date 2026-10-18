# BotJobs v0.4.0 — trabajos de profesión para altbots

Basado en BotGarrison. Pesca, herbalismo, minería y desuello.

## Archivos

| Archivo | Dónde |
|---|---|
| `BotJobs_Server.lua` | `lua_scripts/` del servidor |
| `BotJobs.lua` + `BotJobs.toc` | igual que BotGarrison (addon AIO; el `.lua` también en `lua_scripts/`) |
| `BotJobs_Npc.lua` | `lua_scripts/` (opcional): Nerrak habla y gesticula; saluda al abrir el panel |
| `BotJobs_world.sql` | `acore_world` (NPC, mismo formato que el Herald de BotGarrison) — rellenar `@DISPLAYID` |
| `BotJobs_characters.sql` | `acore_characters` (2 tablas: trabajos en curso y descanso por bot; opcionales con `PERSIST_JOBS=false`) |

Uso: habla con el NPC → panel. `/bj` reabre el panel, `/bj diario` el diario.

Novedades del cliente (v0.3.0): botón **Repetir último** (relanza el mismo compañero, material y duración si se puede;
el tooltip muestra el coste), **aviso en el minimapa** (brillo verde + sonido) cuando vuelve un compañero, y
**(tope)** en la lista cuando un compañero ya no puede subir más sin entrenar.

## Descanso por bot (v0.4.0)

Tras **3 trabajos completados** (`BOT_CD_JOBS`), el bot descansa **2× el tiempo trabajado** en esa tanda (`BOT_CD_MULT`).
Ejemplo: 5 + 5 + 60 min trabajados = 70 min → descanso de 140 min, contado desde que termina el 3.º.
- Hasta completar la tanda el bot trabaja sin restricciones; el panel muestra `[2/3]` junto al bot.
- Al elegir el 3.º trabajo, el resumen avisa de cuánto descansará.
- Durante el descanso el bot sale en gris con `(desc. 2h20)` y no se puede contratar.
- Al acabar el descanso el contador vuelve a 0. Si pasan 24 h sin completar la tanda (`BOT_CD_RESET_HOURS`) también se reinicia.
- Solo cuenta para BotJobs; las misiones de BotGarrison no se ven afectadas.
- Es por bot (no por jugador) y sobrevive a reinicios (tabla `character_bot_job_cd`; ejecuta `BotJobs_characters.sql` de nuevo, es seguro repetirlo).
- Se desactiva con `BOT_CD_ENABLED = false`.

## Parche obligatorio en `BotGarrison_Server.lua` (bot en trabajo ⇄ misión)

Ya aplicado en `BotGarrison_Server.PATCHED.lua` (tu archivo + estas 2 inserciones, nada más; haz `diff` para verlo). Si prefieres hacerlo a mano:

1. Justo después de `local ActiveMissions = {}` añade:

```lua
function BotGarrison_IsBotOnMission(guidLow)
    guidLow = tostring(guidLow)
    for _, m in pairs(ActiveMissions) do
        if m and not m.cancelled and m.botGuids then
            for g in string.gmatch(m.botGuids, "[^,]+") do
                if g == guidLow then return true end
            end
        end
    end
    return false
end
```

2. En `GetAltBots`, dentro de `addBot`, tras `if not SafeIsAltBot(bot) then return end` añade:

```lua
if BotJobs_IsBotOnJob and BotJobs_IsBotOnJob(g) then return end
```

Así los bots en trabajo no cuentan como compañeros disponibles para misiones, y BotJobs
rechaza (y marca en gris en el panel) los bots que estén de misión.

## Decisiones tomadas

**Diario: sí registra los trabajos.** Es cliente (SavedVariables), no toca la BD, y permite ver
oro gastado vs. habilidad ganada. Tiene su propio diario (`BotJobsDiary`), separado del de misiones.

**Duraciones (v0.2.0):** 5 min, 30 min, 1 h y 3 h (el de 6 h se quitó). La habilidad nunca pasa del rango
entrenado (75/150/…), así que los trabajos largos son sobre todo de botín: bonus de botín por duración
`loot` ×0.90 / ×1.00 / ×1.15 / ×1.40 y precio por minuto algo menor (`priceMult` 1.10 / 1.00 / 0.95 / 0.85).

**Precio = valor del botín:** `valor esperado × PRICE_PCT (40 %) × priceMult`. El valor de una unidad es el `SellPrice`
de `item_template` × `PRICE_VALUE_MULT` (el precio de vendedor se queda corto frente al mercado: pesca ×2,
herbalismo ×2,5, minería ×2, desuello ×2). Si un objeto no tiene `SellPrice` se usa `PRICE_FALLBACK`.
Cada material tiene así su propio precio (el panel lo muestra en los botones de duración). Ajustes rápidos:
`PRICE_PCT` sube/baja todo; `PRICE_VALUE_MULT` ajusta cada profesión. Con `DEBUG_MATERIALS = true` la consola
muestra, para cada material, su SellPrice, las unidades y el precio de 1 h.

**Subida de habilidad:** `min × 1.0 × max(0.10, 1 − hab/450)` + bonus 1–5, con tope por duración
(`DURATIONS[].cap`: 15 / 50 / 75 / 75) y nunca por encima del rango entrenado del bot.
Un material muy por debajo de la habilidad rinde menos (`SKILL_TIERS`: ×1 / ×0.75 / ×0.5 / ×0.25).

**Botín (v0.2.0):**
- *Principal:* material elegido, `ITEMS_PER_MIN × rate × loot(duración)` ±15 % (pesca 0.9, hierbas 0.7,
  mineral 0.6, cuero 0.5 por minuto; ≈ ×1.8 respecto a v0.1).
- *Doble:* 10 % de probabilidad de que el principal salga ×2 (`DOUBLE_CHANCE`).
- *Extras:* un 30 % más de unidades (`BYCATCH_PCT`) de **otros materiales de la misma profesión** con requisito
  entre habilidad−150 y habilidad (`BYCATCH_RANGE`).
- *Raros:* tabla `RARE` (perlas, gemas, cuero raro…) con probabilidad por hora de trabajo (×`RARE_CHANCE_MULT`),
  solo de rango parecido a la habilidad (`RARE_RANGE`) y máximo `RARE_MAX` por trabajo.
Todo llega por correo, en pilas respetando el máximo de cada objeto.

## Notas y límites

- **Persistencia:** una única tabla nueva en characters (`character_bot_jobs`). Es lo mínimo para que un
  trabajo de 6 h sobreviva a un reinicio.
- **Si terminas con el jugador desconectado:** el trabajo se resuelve al volver a entrar (a los ~8 s). El bot
  estará offline, así que su habilidad se actualiza directamente en `character_skills` (SQL). Si está online se
  usa `SetSkill`. Un bot que se desconectó estando aparcado reaparecerá en el mapa de aparcamiento
  (mismo comportamiento que en BotGarrison).
- **Skill API:** se usan `HasSkill`, `GetPureSkillValue`, `GetPureMaxSkillValue` y `SetSkill(id, step, val, max)`
  con `step = max/75`. Si tu build de Eluna nombra algo distinto, el servidor imprimirá el error.
- **IDs de material:** al arrancar se descartan los que no existan en `item_template` (aviso en consola).
  Los marcados `-- verificar ID` (pescados de Rasganorte) y los de la tabla `RARE` (gemas, perlas, cueros) los puse de memoria; pon `DEBUG_MATERIALS = true`
  una vez para ver el nombre real de cada ID en consola y corrige los que no cuadren. Los nombres en español
  son aproximados y solo afectan al panel.
- `BotGarrison_IsBotOnMission` solo ve misiones ya cargadas en memoria (BotGarrison las carga de la BD al abrir el panel/tablón tras un reinicio). Caso límite: justo tras reiniciar, antes de que el jugador toque BotGarrison, un bot de misión podría contratarse para un trabajo.
- No hay botón de cancelar (el oro ya está pagado). Si lo quieres, es fácil de añadir.
- Vigilancia: un watchdog re-aparca al bot si lo traes a mano; no bloquea comandos de chat.
- **Trabajos antiguos:** si habías lanzado un trabajo de 6 h con la v0.1, al terminar se resuelve igual (usa botín ×1.0 al no existir ya esa duración).
- Panel: los botones de duración muestran el precio del material elegido; el resumen incluye extras y probabilidad de doble.
