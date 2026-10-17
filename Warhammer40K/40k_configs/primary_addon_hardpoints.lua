-- Narrow script/gadget guard. Full addon effects/research remain independently gated.
local M={}
function M.SquadPolicy(facts,kind,upgraded)
 local p=assert(facts[kind],'Unknown genuine source squad')
 local out={source_initial_size=p.initial_size,maximum_members=p.maximum_size,cost=p.reinforcement_cost,combat_time_multiplier=p.combat_time_multiplier,native_ready=false}
 if kind=='bike'then
  -- Actual SBP applies -1 enable; paid addon applies +2 enable. This is an
  -- explicitly documented positive-enable interpretation, NOT +2 members.
  out.reinforcement_enabled=upgraded==true and p.reinforcement_disabled_value+p.addon_enable_value>0
 elseif kind=='stormboy'then
  out.reinforcement_enabled=true;out.maximum_members=upgraded==true and p.upgraded_maximum_size or p.maximum_size
 else error('Only copied source bike/Stormboy squads are supported')end
 return out
end
function M.MountGate(S,C,defs,facts,config)
 assert(type(config)=='table'and type(config.ModelAccepted)=='function'and type(config.entityByDef)=='table','Root accepted/diagnostic model gate required')
 local h=facts.hq;local checked={}
 local function model(id,def)
  local d=defs[def];local cp=d and d.customParams or{}
  if config.entityByDef[def]~=facts.source_hashes.settlement.virtual or cp.source_model_sha256~=h.generated_glb_sha256 then return false,'wrong_genuine_model' end
  if not config.ModelAccepted(id,def,h)then return false,'unaccepted_model' end
  if checked[id]==def then return true end
  local map=S.GetUnitPieceMap(id);if type(map)~='table'then return false,'missing_piece_map' end
  for _,m in ipairs(h.weapon_mounts)do
   for _,name in ipairs({m.muzzle,m.aimpiece,m.pitchpiece,'turret_barrel_'..m.muzzle:match('marker_turret_(.+)$')})do
    if type(map[name])~='number'or map[name]<0 then return false,'missing_piece:'..name end
   end
  end
  checked[id]=def;return true
 end
 local R={}
 function R.Allowed(id,weaponNum)
  local m=h.weapon_mounts[weaponNum];if not m then return false,'unknown_mount' end
  local def,team=S.GetUnitDefID(id),S.GetUnitTeam(id)
  local okay,why=model(id,def);if not okay then return false,why end
  local hp,max,_,_,progress=S.GetUnitHealth(id)
  local actor=C.units[id]
  if not hp or hp<=0 or not progress or progress<1 or not actor or actor.team~=team or actor.def~=def or not actor.finished then return false,'unfinished_or_stale_actor' end
  if m.source_baseline_active then return true end
  local a=C.sourceVariantAdapter
  if not a or not a.LocalAddon(id,team,m.source_requires_local_addon)then return false,'paid_local_addon_missing' end
  return true
 end
 function R.Remove(id)checked[id]=nil end
 return R
end
return M
