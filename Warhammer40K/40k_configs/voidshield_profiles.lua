-- Resolved UA literals, not proof of source squad ownership or engine behavior.
-- No UnitDef selects this profile until the coordinator verifies all gates.
return {
 warhound_guard={
  maximum=1875,initial=1875,moraleArmour=.5,
  activeRegen=1,brokenRegen=32.25,minimumBreakFrames=1800,recoveryThreshold=50,
  entity='guard/troops/guard_warhound_titan',
  squad='guard/guard_squad_warhound_titan',
  ability='ua_titan_shield',
  unresolved={'squad references nonexistent space_marines/troops/guard_warhound_titan',
   'active regeneration literals disagree with ability description',
   'source lethal morale-hit health ordering requires measurement'},
 },
}
