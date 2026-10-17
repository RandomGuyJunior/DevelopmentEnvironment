function gadget:GetInfo()return{name='40K funded elite corpse reclaim',desc='Native seeded-feature reclaim only; no death or ordinary economy proof',author='Local project',layer=126,enabled=true}end
if not gadgetHandler:IsSyncedCode()then return false end
local o=Spring.GetModOptions()or{};local M=VFS.Include('40k_configs/elite_corpse_reclaim_fixture.lua');if not M.Enabled(o)then return false end
assert(VFS.Include('40k_configs/four_faction_playtest.lua').Enabled(o),'Actual development progression required')
local R,done
local function stop(reason)if done then return end;done=true;Spring.Echo('40K ELITE CORPSE RECLAIM END',reason,'funded=true','ordinaryEconomy=false','lethalDeath=false','nativeAccepted=false');Spring.SetGameRulesParam('40k_elite_corpse_reclaim_finished',1)end
function gadget:Initialize()
 local ok,error=pcall(function()
  assert(not GG.Recoil40KSpyderHarvestReview and not GG.Recoil40KCorpseAccount,'Alternate payout owner refused')
  local owner=VFS.Include('40k_configs/tactical_marine_remains.lua')
  -- A source registration table only; never instantiate a second owner.New/Killed.
  VFS.Include('40k_configs/scout_remains_pilot.lua').Register(owner,o,VFS)
  VFS.Include('40k_configs/kasrkin_remains_recipe.lua').Register(owner,o,VFS)
  VFS.Include('40k_configs/ogryn_remains_pilot.lua').Register(owner,o,VFS)
  local rows,builder=M.Admit(o,FeatureDefs,UnitDefs,owner)
  R=M.New(Spring,FeatureDefs,UnitDefs,CMD,rows,builder,tonumber(o.prototype_elite_corpse_reclaim_team),Game.mapSizeX,Game.mapSizeZ,Game.maxUnits);R.Begin()
 end)
 if not ok then stop('REFUSED '..tostring(error));if R then R.Cleanup()end end
end
function gadget:GameFrame()if done or not R then return end;local ok,error=pcall(R.Step);if not ok then stop('REFUSED '..tostring(error));R.Cleanup()elseif R.done then stop('SOURCE_PROTOCOL_COMPLETE_NATIVE_REVIEW_PENDING')end end
function gadget:AllowFeatureBuildStep(id,team,fid,def,part)
 if not done and R then local ok,error=pcall(R.BuildStep,id,team,fid,def,part);if not ok then stop('REFUSED '..tostring(error));return false end end
 return true -- Native owner still controls actual permission and payout.
end
function gadget:FeatureDestroyed(fid)if not R then return end;local ok,error=pcall(R.FeatureDestroyed,fid);if not ok then stop('REFUSED '..tostring(error))end end
function gadget:UnitDestroyed(id)if R then R.UnitDestroyed(id)end end
function gadget:Shutdown()if R then R.Cleanup()end end
