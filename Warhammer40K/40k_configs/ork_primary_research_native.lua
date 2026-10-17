-- Whole primary research participant. Payment, health, receipts remain common-owned.
local M={Version=1}
local function sorted(t)local a={};for k in pairs(t or{})do a[#a+1]=k end;table.sort(a);return a end
local function copy(t)if type(t)~='table'then return t end;local o={};for k,v in pairs(t)do o[k]=copy(v)end;return o end
local function finite(n)return type(n)=='number'and n==n and n>=0 and n<math.huge end
local function near(a,b)return finite(a)and finite(b)and math.abs(a-b)<math.max(.0001,b*.000001)end
local function fold(n,e,spatial)
 local u=e.usage_type;local v=e.value
 if u:find('addition',1,true)then return n+v*(spatial and 10 or 1)end
 if u:find('multiplication',1,true)then return n*v end
 if u:find('percentage',1,true)then return n*(1+v)end
 error('Unsupported exact source usage')
end
M.Fold=fold
function M.DamageMean(lo,hi,loFactor,hiFactor)
 assert(lo+hi>0,'Source damage interval must be positive');return(lo*loFactor+hi*hiFactor)/(lo+hi)
end
function M.New(C,S,D,W,F,Codec,armor,extra)
 local R={base={},applied={},failures={}};local manager
 local prefix='40k_primary_research_';local fingerprints={}
 local source={};for def,d in pairs(D)do source[def]=((d.customParams or{}).source_entity or''):match('([^/]+)%.lua$')end
 for k,p in pairs(F.profiles)do fingerprints[k]=Codec.Encode(p)end

 -- energyMake is a separate immutable native production path, not a resourcing pack.
 -- Wind/tidal and legacy negative upkeep require distinct conditional consumers.
 local function powerDefinition(def)
  local d=D[def];if not d then return nil,'power_definition_missing'end
  if not finite(d.energyMake)or not finite(d.energyUpkeep)or not finite(d.windGenerator)or not finite(d.tidalGenerator)then return nil,'power_definition_unreadable_or_negative_upkeep'end
  if d.windGenerator~=0 or d.tidalGenerator~=0 then return nil,'dynamic_wind_tidal_power_consumer_required'end
  return d.energyMake
 end
 local function powerQualified(id)
  local fixed,why=powerDefinition(S.GetUnitDefID(id));if fixed==nil then return nil,why end
  for _,key in ipairs({'umm','ume','uum','uue','cmm','cme','cum','cue'})do if not finite(S.GetUnitResourcing(id,key))then return nil,'actual_native_resourcing_state_unreadable:'..key end end
  return fixed
 end
 local damageKinds={max_damage_weapon_modifier=true,min_damage_weapon_modifier=true}
 local supported={income_power_player_modifier=true,health_maximum_modifier=true,health_regeneration_modifier=true,max_range_weapon_modifier=true,speed_maximum_modifier=true,health_rangedamage_received_1_modifier=true}
 local function weaponSource(w)
  local cp=w.customParams or{};local p=cp.source_weapon_profile or cp.source_weapon or cp.source_weapon_identity
  return p and(p:match('([^/]+)%.lua$')or p)
 end
 local armorKeys={[0]=true};for _,n in pairs(armor or{})do if finite(n)and n%1==0 then armorKeys[n]=true end end;armorKeys=sorted(armorKeys)
 function R.Owns(k)return F.profiles[k]~=nil end
 function R.Supported(k,p)
  local own=F.profiles[k]
  if not own or Codec.Encode(own)~=fingerprints[k]or not p or p.sha256~=own.sha256 then return false,'source_primary_profile_changed'end
  if own.requirement_consumer_missing then return false,'actual_requirement_consumer_required:'..own.requirement_consumer_missing end
  if extra and extra.Owns(k)then return extra.Supported(k,p)end
  if #own.effects==0 then return false,'source_research_unlock_requires_actual_ability_consumer'end
  for _,e in ipairs(own.effects)do
   local uniqueExclusive=e.exclusive and e.type=='speed_maximum_modifier'
   if uniqueExclusive then local count=0;for _,profile in pairs(F.profiles)do for _,row in ipairs(profile.effects)do if row.type==e.type and row.target==e.target then count=count+1 end end end;uniqueExclusive=count==1 end
   if e.probability~=1 or(e.exclusive and not uniqueExclusive)or not finite(e.value)then return false,'source_primary_probability_or_exclusivity'end
   if not e.usage_type:find('addition',1,true)and not e.usage_type:find('multiplication',1,true)and not e.usage_type:find('percentage',1,true)then return false,'source_primary_usage'end
   if e.type=='income_power_player_modifier'then
    if type(S.GetUnitResourcing)~='function'or type(S.SetUnitResourcing)~='function'then return false,'actual_native_resourcing_read_write_API_required'end
    if not e.usage_type:find('multiplication',1,true)or e.value<1 then return false,'exact_static_power_multiplier_required'end
    for id in pairs(C.units)do local fixed,why=powerQualified(id);if fixed==nil then return false,why end end
   elseif damageKinds[e.type]then
    local w=F.weapons[e.target];if not w or w.minimum+w.maximum<=0 then return false,'source_weapon_interval_missing'end
   elseif e.type=='income_power_player_modifier'and type(S.SetUnitResourcing)~='function'then return false,'actual_native_resourcing_write_API_required'
   elseif not supported[e.type]then return false,'actual_consumer_required:'..e.type end
  end
  if not(S.GetUnitWeaponDamages and S.SetUnitWeaponDamages and S.GetUnitWeaponState and S.SetUnitWeaponState and S.GetUnitMoveTypeData and S.MoveCtrl and S.MoveCtrl.SetGroundMoveTypeData)then return false,'actual_native_stat_api_missing'end
  return true
 end
 local function state(id)
  local d=S.GetUnitDefID(id);local team=S.GetUnitTeam(id);local hp,max,_,_,progress=S.GetUnitHealth(id)
  return d and D[d]and hp and hp>0 and d,team,hp,max,progress
 end
 local function read(id)
  local def,team=state(id);if not def then return nil end
  local o={def=def,team=team,weapons={}};local move=S.GetUnitMoveTypeData(id)
  o.speed=move and move.maxSpeed
  if S.GetUnitResourcing then o.ume=S.GetUnitResourcing(id,'ume');o.cme=S.GetUnitResourcing(id,'cme');if not finite(o.ume)or not finite(o.cme)then return nil end end
  o.powerFixed=powerDefinition(def);if o.powerFixed~=nil then o.powerModel='native_static_energyMake_plus_packs_v1'end
  for n,m in ipairs(D[def].weapons or{})do
   local wd=W[m.weaponDef];local identity=wd and weaponSource(wd)
   if identity then
    local row={source=identity,range=S.GetUnitWeaponState(id,n,'range'),damages={}}
    for _,a in ipairs(armorKeys)do row.damages[a]=S.GetUnitWeaponDamages(id,n,a);if not finite(row.damages[a])then return nil end end
    if not finite(row.range)then return nil end;o.weapons[n]=row
   end
  end
  return o
 end
 local function baseline(id,def,birth)
  local saved=S.GetUnitRulesParam(id,prefix..'base');local b
  if saved then b=Codec.Decode(saved);if not b or b.version~=M.Version or b.def~=def or b.source~=source[def]then return nil,'invalid_saved_primary_baseline'end
  else
   -- Never learn an already boosted baseline during reconstruction.
   if not birth then for k in pairs(F.profiles)do if C.HasResearch(S.GetUnitTeam(id),k)then return nil,'missing_saved_primary_baseline'end end end
   b=read(id);if not b then return nil,'native_primary_baseline_unreadable'end;b.version=M.Version;b.source=source[def]
   local encoded=Codec.Encode(b);S.SetUnitRulesParam(id,prefix..'base',encoded,{private=true});if S.GetUnitRulesParam(id,prefix..'base')~=encoded then return nil,'baseline_readback_failed'end
  end
  R.base[id]=b;return b
 end
 local function active(k,id,team,prospective)
  if prospective and prospective.key==k and prospective.team==team then return true end
  return C.HasResearch(team,k)and manager and manager.IsApplied(team,k)==true
 end
 function R.ModifyPlan(id,b,team,prospective,birth,out)
  if not source[b.def]then return out end
  local base,why=baseline(id,b.def,birth);if not base then return nil,why end
  local plan=copy(base);plan.team=team;plan.regen=0;plan.ranged=1;local intervals={}
  if extra and extra.SelectionPlan then local selected,why=extra.SelectionPlan(id,b,team,prospective,birth,plan);if not selected then return nil,why end;plan=selected end
  for _,k in ipairs(sorted(F.profiles))do if active(k,id,team,prospective)then
   local p=F.profiles[k];local okay,error=R.Supported(k,p);if not okay then return nil,error end
   for _,e in ipairs(p.effects)do
    if e.type=='income_power_player_modifier'then
     local fixed,why=powerQualified(id);if fixed==nil then return nil,why end
     if plan.powerModel~='native_static_energyMake_plus_packs_v1'or not finite(plan.powerFixed)or plan.powerFixed~=fixed or not finite(plan.ume)or not finite(plan.cme)then return nil,'complete_static_power_saved_baseline_required'end
     plan.ume=fold(plan.powerFixed+plan.ume,e)-plan.powerFixed;plan.cme=fold(plan.cme,e)
     if not finite(plan.ume)or not finite(plan.cme)then return nil,'invalid_complete_static_power_plan'end
    end
    if e.target==source[b.def]then
     if e.type=='health_maximum_modifier'then out.health=fold(out.health,e)
     elseif e.type=='health_regeneration_modifier'then plan.regen=fold(plan.regen,e)
     elseif e.type=='health_rangedamage_received_1_modifier'then plan.ranged=fold(plan.ranged,e)
     elseif e.type=='speed_maximum_modifier'then if not finite(plan.speed)or plan.speed<=0 then return nil,'genuine_ground_speed_missing'end;plan.speed=fold(plan.speed,e)end
    end
    for n,w in pairs(plan.weapons)do if e.target==w.source then
     if damageKinds[e.type]then
      local f=intervals[n]or{lo=1,hi=1};intervals[n]=f
      if e.type=='max_damage_weapon_modifier'then f.hi=fold(f.hi,e)else f.lo=fold(f.lo,e)end
     elseif e.type=='max_range_weapon_modifier'then
      if (W[D[b.def].weapons[n].weaponDef].customParams or{}).dynamicdamage=='1'then return nil,'dynamic_range_damage_consumer_required'end
      w.range=fold(w.range,e,true)
     end
    end end
   end
  end end
  for n,f in pairs(intervals)do local w=plan.weapons[n];local s=F.weapons[w.source];local factor=M.DamageMean(s.minimum,s.maximum,f.lo,f.hi)
   for a,v in pairs(w.damages)do w.damages[a]=v*factor end
  end
  if not finite(plan.regen)or not finite(plan.ranged)or plan.ranged>1 then return nil,'invalid_source_defensive_plan'end
  out.primaryPlan=plan
  if extra then local changed,why=extra.ModifyPlan(id,b,team,prospective,birth,out);if not changed then return nil,why end;out=changed end
  return out
 end
 function R.Snapshot(id)
  local stats=read(id);if not stats then return nil,'unreadable_primary_snapshot'end
  local additional;if extra then local why;additional,why=extra.Snapshot(id);if not additional then return nil,why end end
  return{extra=additional,stats=stats,applied=copy(R.applied[id]),saved=S.GetUnitRulesParam(id,prefix..'applied')}
 end
 local function applyStats(id,p)
  local def,team=state(id);if def~=p.def or team~=p.team then return false,'primary_actor_changed'end
  for n,w in pairs(p.weapons)do
   S.SetUnitWeaponDamages(id,n,w.damages);S.SetUnitWeaponState(id,n,{range=w.range})
   for a,v in pairs(w.damages)do if not near(S.GetUnitWeaponDamages(id,n,a),v)then return false,'weapon_damage_readback'end end
   if not near(S.GetUnitWeaponState(id,n,'range'),w.range)then return false,'weapon_range_readback'end
  end
  if p.ume~=nil then
   if not(S.GetUnitResourcing and S.SetUnitResourcing)then return false,'native_resourcing_api_missing'end
   S.SetUnitResourcing(id,{ume=p.ume,cme=p.cme})
   if not near(S.GetUnitResourcing(id,'ume'),p.ume)or not near(S.GetUnitResourcing(id,'cme'),p.cme)then return false,'native_resourcing_readback'end
  end
  local now=S.GetUnitMoveTypeData(id)
  if finite(p.speed)and now and not near(now.maxSpeed,p.speed)then S.MoveCtrl.SetGroundMoveTypeData(id,{maxSpeed=p.speed});now=S.GetUnitMoveTypeData(id);if not now or not near(now.maxSpeed,p.speed)then return false,'ground_speed_readback'end end
  return true
 end
 function R.ApplyPlan(id,p)
  if not p then return true end;local prior,reason=R.Snapshot(id);if not prior then return false,reason end
  local ok,okay,why=pcall(applyStats,id,p);if not ok or not okay then local restored=R.Restore(id,prior);return false,tostring(ok and why or okay)..(restored and ':rolled_back'or':rollback_incomplete')end
  if extra then local called,okay,why=pcall(extra.ApplyPlan,id,p.extra);if not called or not okay then local restored=R.Restore(id,prior);return false,tostring(called and why or okay)..(restored and ':rolled_back'or':rollback_incomplete')end end
  local encoded=Codec.Encode(p);local written=pcall(S.SetUnitRulesParam,id,prefix..'applied',encoded,{private=true})
  if not written then local restored=R.Restore(id,prior);return false,'primary_receipt_exception:'..(restored and'rolled_back'or'rollback_incomplete')end
  if S.GetUnitRulesParam(id,prefix..'applied')~=encoded then local restored=R.Restore(id,prior);return false,'primary_receipt_readback:'..(restored and'rolled_back'or'rollback_incomplete')end
  R.applied[id]=copy(p);return true
 end
 function R.Restore(id,snap)
  if not snap then return true end
  local okay=applyStats(id,snap.stats);if extra then local restored=extra.Restore(id,snap.extra);okay=okay and restored==true end;S.SetUnitRulesParam(id,prefix..'applied',snap.saved,{private=true});R.applied[id]=copy(snap.applied)
  return okay and S.GetUnitRulesParam(id,prefix..'applied')==snap.saved
 end
 function R.PreDamage(id,damage,paralyzer,weapon)
  local p=R.applied[id];local def,team=state(id);local wd=W[weapon]
  if not p or p.def~=def or p.team~=team or paralyzer or not wd or not finite(damage)then return damage end
  -- Preserve the explicitly authored ranged-damage ability, never armour/AP.
  local cp=wd.customParams or{};if wd.type=='Melee'or cp.source_fireclip=='melee'or cp.source_melee=='1'then return damage end
  return damage*p.ranged
 end
 function R.Frame(frame)
  if frame%(Game and Game.gameSpeed or 30)~=0 then return end
  for id,p in pairs(R.applied)do local def,team,hp,max,progress=state(id)
   if def~=p.def or team~=p.team then R.applied[id]=nil
   elseif progress and progress>=1 and p.regen>0 and hp<max then S.SetUnitHealth(id,{health=math.min(max,hp+p.regen)})end
  end
 end
 function R.Bind(m)manager=m;if extra then extra.Bind(m)end end
 return R
end
return M
