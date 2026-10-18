-- ============================================================
--  BotJobs — tabla de trabajos en curso (base de datos CHARACTERS)
--  Unica tabla nueva. Sirve para que los trabajos sobrevivan a reinicios y relogs.
--  Si no la quieres: CFG.PERSIST_JOBS = false (los trabajos solo viven en memoria).
-- ============================================================
CREATE TABLE IF NOT EXISTS `character_bot_jobs` (
    `player_guid` INT UNSIGNED NOT NULL,
    `bot_guid`    INT UNSIGNED NOT NULL,
    `bot_name`    VARCHAR(32)  NOT NULL,
    `prof`        VARCHAR(16)  NOT NULL,
    `item_id`     INT UNSIGNED NOT NULL,
    `minutes`     INT UNSIGNED NOT NULL,
    `price`       INT UNSIGNED NOT NULL,
    `start_time`  INT UNSIGNED NOT NULL,
    `end_time`    INT UNSIGNED NOT NULL,
    PRIMARY KEY (`player_guid`, `bot_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ------------------------------------------------------------
--  Descanso por bot (v0.4.0): tanda de trabajos y descanso pendiente.
--  Si no la quieres: CFG.PERSIST_JOBS = false (el descanso solo vive en memoria).
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `character_bot_job_cd` (
    `bot_guid`    INT UNSIGNED NOT NULL,
    `player_guid` INT UNSIGNED NOT NULL,
    `jobs`        INT UNSIGNED NOT NULL DEFAULT 0,
    `minutes`     INT UNSIGNED NOT NULL DEFAULT 0,
    `cd_until`    INT UNSIGNED NOT NULL DEFAULT 0,
    `last_time`   INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`bot_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
