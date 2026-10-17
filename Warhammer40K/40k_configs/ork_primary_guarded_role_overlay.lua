-- Optional authored integration overlay; caller owns native readiness and source consumers.
local M={Version=1}
local names={ork_pile_o_guns='Pile-o-Guns',ork_boomy_platform='Boomy Platform',ork_bigger_generator='Bigger Generator',ork_giant_waagh_banner_sp_dxp3='Da Flyboyz Towa',ork_stormboy='Stormboy'}
local function copy(t)if type(t)~='table'then return t end;local o={};for k,v in pairs(t)do o[k]=copy(v)end;return o end
function M.Apply(defs,contract,options,hooks)
 local report={opened={},missing={}}
 if tostring((options or {}).prototype_ork_primary_roles or '0')~='1'then return report end
 assert(hooks and hooks.Ready and hooks.FileExists and (hooks.Definition or hooks.NativeDefinitions) and hooks.SourceProgressionReady,'Missing root-owned integration hooks')
 for key,facts in pairs(contract.actors)do
  local reason
  if not names[key]or not hooks.Ready(key)then reason='native_readiness'
  elseif not hooks.FileExists('objects3d/'..key..'.glb')or not hooks.FileExists('scripts/generated/'..key..'_anim.lua')then reason='private_assets'
  elseif not hooks.SourceProgressionReady(key,facts)then reason='source_paid_progression'
  elseif key=='ork_bigger_generator'and(not defs.ork_generator or type(defs.ork_generator.energymake)~='number'or defs.ork_generator.energymake<=0)then reason='native_energy_reference'
  elseif key=='ork_stormboy'and(not hooks.CohortReady or not hooks.CohortReady(facts.cohort)or not hooks.JumpReady or not hooks.JumpReady(facts.cohort))then reason='source_paid_cohort_and_jump'
  elseif next(facts.research)and(not hooks.ResearchReady or not hooks.ResearchReady(key,facts.research))then reason='whole_source_research' end
  local definition
  if not reason then
   if hooks.Definition then definition=hooks.Definition(key,facts)else definition=hooks.NativeDefinitions.Build(key,facts,contract.calibration[key],defs)end
  end
  if not reason and not definition then reason='native_armament_time_and_bounds_definition' end
  if reason then report.missing[key]=reason
  else
   local d=copy(definition);d.name=names[key];d.objectname=key..'.glb';d.script='40k_roster.lua';d.buildpic='40k_'..key..'.png'
   d.metalcost=facts.cost.metal;d.energycost=facts.cost.power*5;d.health=facts.health
   d.customparams=d.customparams or {};local cp=d.customparams
   cp.faction='Orks';cp.prototype40k=1;cp.animsource=key;cp.source_role=facts.role;cp.rosterrole=facts.role=='jump_infantry'and 'infantry'or facts.role=='energy'and 'generator'or facts.role;cp.unitgroup=d.builder and 'builder'or d.canattack and 'weapon'or 'util';cp.source_entity=facts.entity
   cp.source_completed_pose_profile=key;cp.integration_status='guarded_primary_native_review'
   if key=='ork_bigger_generator'then d.canattack=false;d.weapondefs={};d.weapons={};d.energymake=defs.ork_generator.energymake*facts.power_per_second/facts.reference_source_generator_power;cp.source_power_adaptation='preserve_source_generator_income_ratio_v1' end
   if key=='ork_giant_waagh_banner_sp_dxp3'then
    local products=hooks.Products and hooks.Products(facts.products)or {};local available={}
    for _,target in ipairs(products)do if defs[target]and hooks.Ready(target)then available[#available+1]=target end end
    if #available==0 then report.missing[key]='genuine_available_air_products'
    else d.builder=true;d.canmove=true;d.buildoptions=available end
   end
   if not report.missing[key]then defs[key]=d;report.opened[#report.opened+1]=key end
  end
 end
 -- Root-approved paid Grot construction adaptation. Never overwrite unrelated menus.
 for name,builder in pairs(defs)do
  local cp=builder.customparams or {}
  if name=='ork_grot'or(cp.faction=='Orks'and(cp.rosterrole=='builder'or cp.rosterrole=='commander')and hooks.Ready(name))then
   local seen={};for _,key in ipairs(builder.buildoptions or {})do seen[key]=true end
   for _,key in ipairs(report.opened)do if key~='ork_stormboy'and not seen[key]then builder.buildoptions=builder.buildoptions or {};builder.buildoptions[#builder.buildoptions+1]=key;seen[key]=true end end
  end
 end
 if defs.ork_boyz_hut and defs.ork_stormboy then
  local seen=false;for _,key in ipairs(defs.ork_boyz_hut.buildoptions or {})do if key=='ork_stormboy'then seen=true end end
  if not seen then defs.ork_boyz_hut.buildoptions=defs.ork_boyz_hut.buildoptions or {};table.insert(defs.ork_boyz_hut.buildoptions,'ork_stormboy')end
 end
 return report
end
return M
