-- ============================================================
--  BotJobs Pescador Kalu'ak  entry 900200
--  Base: WORLD
--  Misma estructura que botgarrison_herald_npc.sql (AzerothCore moderno,
--  modelo en creature_template_model).
-- ============================================================

-- >>> RELLENAR <<<  CreatureDisplayID de un Kalu'ak.
--   Para sacarlo: junto a cualquier Kalu'ak (p. ej. en Tundra Boreal) selecciónalo
--   y usa  .npc info  -> "DisplayID".
SET @DISPLAYID := 24055;

DELETE FROM `creature_template_model` WHERE `CreatureID` = 900200;
DELETE FROM `creature_template` WHERE `entry` = 900200;

INSERT INTO `creature_template` (
  `entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`,
  `KillCredit1`, `KillCredit2`,
  `name`, `subname`, `IconName`, `gossip_menu_id`,
  `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`,
  `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`,
  `rank`, `dmgschool`, `BaseAttackTime`, `RangeAttackTime`,
  `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`,
  `dynamicflags`, `family`, `type`, `type_flags`,
  `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`,
  `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`,
  `HealthModifier`, `ManaModifier`, `ArmorModifier`, `DamageModifier`,
  `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`,
  `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`
) VALUES (
  900200, 0, 0, 0,
  0, 0,
  'Nerrak', 'Trabajos de profesión', '', 0,
  80, 80, 2, 35, 1,
  1, 1.14286, 1, 1, 20,
  0, 0, 2000, 2000,
  1, 1, 1, 0, 2048,
  0, 0, 7, 0,
  0, 0, 0, 0, 0,
  0, 0, '', 0, 1,
  1, 1, 1, 1,
  1, 0, 0, 1,
  0, 2, '', 0
);

INSERT INTO `creature_template_model`
(`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
VALUES
(900200, 0, @DISPLAYID, 1, 1, 0);

-- Colocarlo en el mundo: en el juego, con  .npc add 900200
