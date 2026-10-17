function gadget:GetInfo()
 return{name='40K generator scrap review',desc='One native machinery salvage feature',author='Local project',layer=0,enabled=true}
end
if not gadgetHandler:IsSyncedCode()then return end
local module=VFS.Include('40k_configs/ordinary_generator_scrap.lua')
if not module.Enabled(Spring.GetModOptions())then return end
local R
function gadget:Initialize()
 R=module.New(Spring,FeatureDefs,Game.gameSpeed or 30);R.Restore()
end
function gadget:AllowFeatureCreation(def,team,x,y,z)return not R or R.AllowCreation(def)end
function gadget:FeatureCreated(id)if R then R.Created(id)end end
function gadget:FeatureDestroyed(id)if R then R.Destroyed(id)end end
function gadget:AllowFeatureBuildStep(builder,team,id,def,part)return not R or R.AllowBuildStep(id,part)end
function gadget:GameFrame(frame)if R then R.Frame(frame)end end
