# BotJobs

**[English](#english) · [Español](#español)**

---

# English

**BotJobs** is a profession-jobs module for **AzerothCore + Eluna + AIO + mod-playerbots** (WoW 3.3.5). It lets you send your alts (altbots) on timed gathering jobs while you play, and they come back with loot and better skills.

It is a companion to **BotGarrison** (timed missions) and reuses its approach: AIO panel, bot parking, mail rewards and a client-side diary.

## Features

- **Four gathering professions:** Fishing, Herbalism, Mining and Skinning.
- **One NPC for everything:** Nerrak, a Kalu'ak fisherman. Talk to him, pick an alt that has the profession, choose a material and a duration (5 min, 30 min, 1 h or 3 h) and pay.
- **Bots leave and come back:** the bot says goodbye, is parked while working and returns when the job ends.
- **Loot by mail:** the chosen material, plus extra materials from the same profession, a chance of double loot and rare finds (gems, pearls, rare leather…).
- **Skill gains:** roughly 1 point per minute at the start, decreasing with skill level, plus a 1–5 bonus, capped per job. A bot never goes above its trained skill rank.
- **Prices follow loot value:** each job costs a share of the expected loot's value, so it scales with the material and the bot's skill.
- **Materials by skill:** only materials the bot can gather are offered.
- **Limits:** one job per bot at a time, a configurable maximum of simultaneous jobs per player, and a bot on a job cannot go on a BotGarrison mission (and vice versa).
- **Rest per bot:** after 3 completed jobs, a bot rests for 2× the time it worked (all configurable).
- **Comfort features:** "Repeat last job" button, minimap alert when a bot returns, journal of finished jobs, animated NPC with random lines.

## Requirements

- AzerothCore with **Eluna**
- **AIO** (server and client)
- **mod-playerbots** (altbots)
- **BotGarrison** is optional but recommended (mission ↔ job exclusivity needs a small patch, included)

## Installation

| File | Where |
|---|---|
| `BotJobs_Server.lua` | server `lua_scripts/` |
| `BotJobs_Npc.lua` | server `lua_scripts/` (optional: NPC lines and gestures) |
| `BotJobs.lua` + `BotJobs.toc` | client addon, same layout as BotGarrison (`Interface/AddOns/BotJobs/`) |
| `BotJobs_world.sql` | `acore_world` database (creates the NPC) |
| `BotJobs_characters.sql` | `acore_characters` database (two small tables) |
| `BotGarrison_Server.PATCHED.lua` | replaces your `BotGarrison_Server.lua` (optional) |

1. **NPC:** open `BotJobs_world.sql` and set `@DISPLAYID` to a Kalu'ak model (stand next to any Kalu'ak and use `.npc info`). Run it, then spawn the NPC in game with `.npc add 900200`.
2. **Characters DB:** run `BotJobs_characters.sql`. Safe to run more than once. If you don't want database tables, set `PERSIST_JOBS = false` (jobs and rests are then kept in memory only and lost on restart).
3. **Server scripts:** copy the Lua files into `lua_scripts/` and restart the server. After `.reload eluna`, respawn the NPC so it starts talking.
4. **BotGarrison patch (optional):** use `BotGarrison_Server.PATCHED.lua` **instead of** your current `BotGarrison_Server.lua`. Never keep both in `lua_scripts/`, or AIO will complain about a duplicate `BotGarrison` handler. The patch only adds two small insertions, see `NOTES.es.md`.
5. **Client:** install the addon folder and **enable it in the character-select AddOns list**, then restart the game.

## Usage

- Talk to Nerrak to open the panel. `/bj` (or `/oficios`) reopens it, `/bj diario` opens the journal.
- Choose a bot and profession, a material and a duration. The panel shows the cost, expected loot and expected skill gain.
- When a bot returns you get a chat summary, a minimap glow and a mail with the loot.

## Configuration

Everything is in the `CFG` table at the top of `BotJobs_Server.lua`:

| Setting | Meaning |
|---|---|
| `MAX_JOBS_PER_PLAYER` | simultaneous jobs per player |
| `DURATIONS` | job lengths, price multiplier, skill cap and loot bonus |
| `PRICE_PCT`, `PRICE_VALUE_MULT` | how much a job costs relative to the loot value |
| `ITEMS_PER_MIN`, `BYCATCH_PCT`, `DOUBLE_CHANCE`, `RARE_*` | amount and variety of loot |
| `SKILL_*` | skill gain per minute, decay, bonus and difficulty tiers |
| `BOT_CD_*` | rest per bot: jobs per cycle, multiplier, idle reset |
| `PERSIST_JOBS` | keep jobs and rests across restarts |
| `DEBUG_MATERIALS` | print the real DB name, sell price and 1 h price of every material at startup |

Material and rare-item IDs are listed in the same file. IDs that do not exist in `item_template` are skipped at startup with a console warning; some IDs were written from memory, so check them once with `DEBUG_MATERIALS = true`.

## Notes

- A job that ends while you are offline is resolved when you log in.
- There is no cancel button: the gold is paid when the job starts.
- Spanish text only (panel, chat and NPC lines).

More technical details (in Spanish): [`NOTES.es.md`](NOTES.es.md).

---

# Español

**BotJobs** es un módulo de trabajos de profesión para **AzerothCore + Eluna + AIO + mod-playerbots** (WoW 3.3.5). Permite mandar a tus alters (altbots) a trabajos de recolección con temporizador mientras juegas, y vuelven con botín y mejor habilidad.

Es un complemento de **BotGarrison** (misiones con temporizador) y reutiliza su enfoque: panel AIO, aparcamiento de bots, recompensas por correo y diario en el cliente.

## Características

- **Cuatro profesiones de recolección:** Pesca, Herboristería, Minería y Desuello.
- **Un único NPC para todo:** Nerrak, un pescador Kalu'ak. Hablas con él, eliges un alter que tenga la profesión, un material y una duración (5 min, 30 min, 1 h o 3 h) y pagas.
- **El bot se va y vuelve:** se despide, queda aparcado mientras trabaja y regresa al terminar.
- **Botín por correo:** el material elegido, más materiales extra de la misma profesión, probabilidad de botín doble y hallazgos raros (gemas, perlas, cuero raro…).
- **Subida de habilidad:** aproximadamente 1 punto por minuto al principio, decreciendo con el nivel de habilidad, más un bonus de 1 a 5, con máximo por trabajo. Un bot nunca supera el rango que tiene entrenado.
- **Precio según el valor del botín:** cada trabajo cuesta una parte del valor del botín esperado, así que se ajusta al material y a la habilidad del bot.
- **Materiales según habilidad:** solo se ofrecen los materiales que el bot puede recolectar.
- **Límites:** un trabajo por bot a la vez, un máximo configurable de trabajos simultáneos por jugador, y un bot en trabajo no puede ir a una misión de BotGarrison (ni al revés).
- **Descanso por bot:** tras 3 trabajos completados, el bot descansa el doble del tiempo que ha trabajado (todo configurable).
- **Comodidades:** botón "Repetir último trabajo", aviso en el minimapa cuando vuelve un bot, diario de trabajos terminados y un NPC animado con frases aleatorias.

## Requisitos

- AzerothCore con **Eluna**
- **AIO** (servidor y cliente)
- **mod-playerbots** (altbots)
- **BotGarrison** es opcional pero recomendado (la exclusividad misión ↔ trabajo necesita un pequeño parche, incluido)

## Instalación

| Archivo | Dónde |
|---|---|
| `BotJobs_Server.lua` | `lua_scripts/` del servidor |
| `BotJobs_Npc.lua` | `lua_scripts/` del servidor (opcional: frases y gestos del NPC) |
| `BotJobs.lua` + `BotJobs.toc` | addon del cliente, igual que BotGarrison (`Interface/AddOns/BotJobs/`) |
| `BotJobs_world.sql` | base de datos `acore_world` (crea el NPC) |
| `BotJobs_characters.sql` | base de datos `acore_characters` (dos tablas pequeñas) |
| `BotGarrison_Server.PATCHED.lua` | sustituye a tu `BotGarrison_Server.lua` (opcional) |

1. **NPC:** abre `BotJobs_world.sql` y pon en `@DISPLAYID` el modelo de un Kalu'ak (ponte junto a cualquiera y usa `.npc info`). Ejecútalo y crea el NPC en el juego con `.npc add 900200`.
2. **Base de datos de personajes:** ejecuta `BotJobs_characters.sql`. Se puede repetir sin problema. Si no quieres tablas, pon `PERSIST_JOBS = false` (los trabajos y descansos se guardan solo en memoria y se pierden al reiniciar).
3. **Scripts del servidor:** copia los archivos Lua a `lua_scripts/` y reinicia el servidor. Tras un `.reload eluna`, haz respawn del NPC para que empiece a hablar.
4. **Parche de BotGarrison (opcional):** usa `BotGarrison_Server.PATCHED.lua` **en lugar de** tu `BotGarrison_Server.lua` actual. Nunca dejes los dos en `lua_scripts/`, o AIO se quejará de un manejador `BotGarrison` duplicado. El parche solo añade dos pequeñas inserciones, mira `NOTES.es.md`.
5. **Cliente:** instala la carpeta del addon y **actívalo en la lista de AddOns de la selección de personaje**; después reinicia el juego.

## Uso

- Habla con Nerrak para abrir el panel. `/bj` (o `/oficios`) lo vuelve a abrir y `/bj diario` abre el diario.
- Elige un bot y su profesión, un material y una duración. El panel muestra el coste, el botín esperado y la subida de habilidad esperada.
- Cuando un bot vuelve recibes un resumen en el chat, un brillo en el minimapa y un correo con el botín.

## Configuración

Todo está en la tabla `CFG` al principio de `BotJobs_Server.lua`:

| Opción | Qué hace |
|---|---|
| `MAX_JOBS_PER_PLAYER` | trabajos simultáneos por jugador |
| `DURATIONS` | duraciones, multiplicador de precio, tope de habilidad y bonus de botín |
| `PRICE_PCT`, `PRICE_VALUE_MULT` | cuánto cuesta un trabajo respecto al valor del botín |
| `ITEMS_PER_MIN`, `BYCATCH_PCT`, `DOUBLE_CHANCE`, `RARE_*` | cantidad y variedad del botín |
| `SKILL_*` | subida de habilidad por minuto, decrecimiento, bonus y tramos de dificultad |
| `BOT_CD_*` | descanso por bot: trabajos por tanda, multiplicador, reinicio por inactividad |
| `PERSIST_JOBS` | conservar trabajos y descansos tras reiniciar |
| `DEBUG_MATERIALS` | al arrancar imprime el nombre real en la BD, el precio de venta y el precio de 1 h de cada material |

Los IDs de materiales y objetos raros están en el mismo archivo. Los IDs que no existan en `item_template` se descartan al arrancar con un aviso en consola; algunos IDs los escribí de memoria, así que conviene revisarlos una vez con `DEBUG_MATERIALS = true`.

## Notas

- Un trabajo que termina con el jugador desconectado se resuelve al volver a entrar.
- No hay botón de cancelar: el oro se paga al empezar el trabajo.
- Todo el texto (panel, chat y frases del NPC) está en español.

Más detalles técnicos: [`NOTES.es.md`](NOTES.es.md).

<img width="3840" height="2160" alt="WoWScrnShot_101826_231507" src="https://github.com/user-attachments/assets/83fbbd04-ff9b-41b4-854d-3086d6ed5595" />
