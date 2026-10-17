function gadget:GetInfo()return{name='40K infantry native remains',desc='Single per-body native reclaim entitlement',author='Local project',layer=50,enabled=true}end
if not gadgetHandler:IsSyncedCode()then return false end
if not VFS.Include('40k_configs/four_faction_playtest.lua').Enabled(Spring.GetModOptions()or{})then return false end
if not VFS.FileExists('objects3d/40k_tactical_marine_corpse.glb')then return false end
local owner
function gadget:Initialize()
 local module=VFS.Include('40k_configs/tactical_marine_remains.lua')
 local enabled=VFS.Include('40k_configs/guard_squad_flamer_integration.lua').Enabled(Spring.GetModOptions()or{})
 if enabled then
  local recipe=VFS.Include('40k_configs/guard_flamer_remains_recipe.lua')
  recipe.Register(module,true)
  local found=false
  for _,d in pairs(FeatureDefs)do if d.name==recipe.Feature and(d.customParams or{}).parent_actor==recipe.Actor then found=true end end
  assert(found,'Genuine flamer remains FeatureDef required before runtime owner')
 end
 if VFS.Include('40k_configs/development_playtest.lua').OptionEnabled((Spring.GetModOptions()or{}).prototype_nob_remains_pilot)then
  assert(not VFS.Include('40k_configs/scale_pilot.lua').Enabled(Spring.GetModOptions()or{}),'Unpaired Nob remains scale085 candidate refused')
  local recipe=VFS.Include('40k_configs/nob_remains_recipe.lua');recipe.Register(module,true)
  local found=false
  for _,d in pairs(FeatureDefs)do if d.name==recipe.Feature and(d.customParams or{}).parent_actor==recipe.Actor then found=true end end
  assert(found,'Genuine Nob remains FeatureDef required before existing runtime owner')
 end
 local necronRecipe=VFS.Include('40k_configs/necron_remains_recipe.lua')
 for key in pairs(necronRecipe.Register(module,Spring.GetModOptions()or{},VFS))do
  local found=0
  for _,d in pairs(FeatureDefs)do
   if d.name==key and(d.customParams or{}).parent_actor then
    local actor=d.customParams.parent_actor
    if module.Actors[actor]and module.Actors[actor].feature==key then found=found+1 end
   end
  end
  assert(found==1,'Exactly one genuine Necron remains FeatureDef required before existing owner')
 end
 local kasrkin=VFS.Include('40k_configs/kasrkin_remains_recipe.lua')
 for key in pairs(kasrkin.Register(module,Spring.GetModOptions()or{},VFS))do
  local count=0;for _,d in pairs(FeatureDefs)do
   if d.name==key and(d.customParams or{}).parent_actor==kasrkin.Actor then count=count+1 end
  end;assert(count==1,'Exactly one Kasrkin FeatureDef required before existing remains owner')
 end
 local ogrynPilot=VFS.Include('40k_configs/ogryn_remains_pilot.lua');local ogrynOptions=Spring.GetModOptions()or{}
 if ogrynPilot.Enabled(ogrynOptions)then
  assert(ogrynPilot.Register(module,ogrynOptions,VFS),'Closed private Ogryn remains required')
  local count=0;for _,d in pairs(FeatureDefs)do if d.name==ogrynPilot.Feature and(d.customParams or{}).parent_actor==ogrynPilot.Actor then count=count+1 end end
  assert(count==1,'Exactly one Ogryn FeatureDef required before existing sole owner')
 end
 local terminatorPair=VFS.Include('40k_configs/terminator_scale_pair.lua');local pairOptions=Spring.GetModOptions()or{}
 if terminatorPair.Enabled(pairOptions)then
  terminatorPair.RegisterRemains(module,pairOptions,VFS)
  local found=false;for _,d in pairs(FeatureDefs)do local p=d.customParams or{}
   if d.name==terminatorPair.Feature and p.parent_actor=='imp_terminator'and tonumber(p.scale_pilot_factor)==.85 then found=true end
  end;assert(found,'Explicit paired Terminator FeatureDef required before sole remains owner')
 end
 local scoutPilot=VFS.Include('40k_configs/scout_remains_pilot.lua');local scoutOptions=Spring.GetModOptions()or{}
 if scoutPilot.Enabled(scoutOptions)then
  assert(scoutPilot.Register(module,scoutOptions,VFS),'Closed private Scout remains required')
  local found=0;for _,d in pairs(FeatureDefs)do if d.name==scoutPilot.Feature and(d.customParams or{}).parent_actor==scoutPilot.Actor then found=found+1 end end
  assert(found==1,'Exactly one Scout remains FeatureDef required before existing sole owner')
 end
 local burnaPilot=VFS.Include('40k_configs/burna_remains_pilot.lua');local burnaOptions=Spring.GetModOptions()or{}
 if burnaPilot.Enabled(burnaOptions)then
  assert(burnaPilot.Register(module,burnaOptions,VFS),'Closed private Burna remains required')
  local count=0;for _,d in pairs(FeatureDefs)do if d.name==burnaPilot.Feature and(d.customParams or{}).parent_actor==burnaPilot.Actor then count=count+1 end end
  assert(count==1,'Exactly one Burna FeatureDef required before existing sole owner')
 end
 local sluggaPilot=VFS.Include('40k_configs/slugga_remains_pilot.lua');local sluggaOptions=Spring.GetModOptions()or{}
 if sluggaPilot.Enabled(sluggaOptions)then
  assert(sluggaPilot.Register(module,sluggaOptions,VFS),'Closed private Slugga remains required')
  local count=0;for _,d in pairs(FeatureDefs)do if d.name==sluggaPilot.Feature and(d.customParams or{}).parent_actor==sluggaPilot.Actor then count=count+1 end end
  assert(count==1,'Exactly one Slugga FeatureDef required before existing sole owner')
 end
 if VFS.FileExists('40k_configs/ork_t1_roster_facts.lua')then
  local t1=VFS.Include('40k_configs/ork_t1_roster.lua')
  assert(t1.RegisterRemains(module,VFS.Include('40k_configs/ork_t1_roster_facts.lua'),VFS),'Closed genuine T1 remains required')
  for actor,row in pairs(t1.Actors)do
   local count=0;for _,d in pairs(FeatureDefs)do
    if d.name==row.feature and(d.customParams or{}).parent_actor==actor then count=count+1 end
   end;assert(count==1,'Exactly one T1 corpse FeatureDef required before existing sole owner')
  end
 end
 for _,actor in ipairs({'ork_ard_boy','ork_flash_gitz','ork_kommando'})do
  local path='40k_configs/'..actor..'_facts.lua'
  if VFS.FileExists(path)then
   local product=VFS.Include('40k_configs/'..actor..'_roster.lua')
   assert(product.RegisterRemains(module,VFS.Include(path),VFS),'Closed genuine infantry remains required: '..actor)
   local count=0
   for _,d in pairs(FeatureDefs)do
    if d.name==product.Feature and(d.customParams or{}).parent_actor==actor then count=count+1 end
   end
   assert(count==1,'Exactly one infantry corpse FeatureDef required: '..actor)
  end
 end
 owner=module.New(Spring,UnitDefs,FeatureDefs,WeaponDefs,VFS.Include('40k_configs/corpse_throw_policy.lua'),VFS.Include('40k_configs/persistent_salvage.lua'))
 if VFS.FileExists('40k_configs/corpse_pile_asset_closure.lua')then
  local c=VFS.Include('40k_configs/corpse_pile_asset_closure.lua')
  if c.enabled==true then
   owner.piles=VFS.Include('40k_configs/corpse_pile_aggregation.lua').New(Spring,UnitDefs,FeatureDefs,owner,CMD,{maxUnits=Game.maxUnits})
  end
 end
 for _,id in ipairs(owner.WatchedWeapons())do Script.SetWatchExplosion(id,true)end
 assert(owner.Restore(),'Saved infantry remains refused')
 if owner.piles then
  local units=Spring.GetAllUnits()or{};table.sort(units)
  for _,id in ipairs(units)do owner.piles.UnitChanged(id,Spring.GetUnitDefID(id))end
 end
 GG.Recoil40KTacticalRemains=owner
end
-- Higher layer runs before squad layer40 discards the casualty membership.
function gadget:UnitDestroyed(id,def,team)owner.Snapshot(id,def,team);if owner.piles then owner.piles.UnitLost(id)end end
function gadget:UnitCreated(id,def)if owner.piles then owner.piles.UnitChanged(id,def)end end
function gadget:UnitCommand(id,def)if owner.piles then owner.piles.UnitChanged(id,def)end end
function gadget:UnitCmdDone(id,def)if owner.piles then owner.piles.UnitChanged(id,def)end end
function gadget:UnitGiven(id,def)if owner.piles then owner.piles.UnitChanged(id,def)end end
function gadget:UnitTaken(id,def)if owner.piles then owner.piles.UnitChanged(id,def)end end
function gadget:Explosion(...)return owner.Explosion(...)end
function gadget:UnitDamaged(id,def,team,damage,paralyzer,weapon,projectile)owner.Damaged(id,def,team,damage,paralyzer,weapon,projectile)end
function gadget:AllowFeatureBuildStep(...)return owner.AllowFeatureBuildStep(...)end
function gadget:FeaturePreDamaged(...)return owner.FeaturePreDamaged(...)end
function gadget:FeatureDestroyed(id)owner.FeatureLost(id)end
function gadget:GameFrame(frame)owner.Frame(frame)end
function gadget:Shutdown()if GG.Recoil40KTacticalRemains==owner then GG.Recoil40KTacticalRemains=nil end end
