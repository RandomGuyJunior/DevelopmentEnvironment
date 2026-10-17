function gadget:GetInfo()return{name='40K Spyder harvest review',desc='Genuine death-body ledger and source body-paid squad outputs; adapter gated',author='Local project',layer=67,enabled=true}end
if not gadgetHandler:IsSyncedCode()then return end
local o=Spring.GetModOptions()or{}
if not VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(o.prototype_spyder_harvest_review)or not VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(o.prototype_source_progression)or o.prototype_diagnostic~='expandedproduction'then return end
local M=VFS.Include('40k_configs/necron_spyder_harvest.lua');local A,Q,P,R;local seeking={}
local accountModule=VFS.Include('40k_configs/corpse_reclaim_account.lua')
local reclaimReview=accountModule.Enabled(o)
if not reclaimReview then Spring.Echo('40K SPYDER HARVEST REFUSAL','exclusive_alternative_salvage_account_required');return end
local commands={34581,34582,34583,34584}
local consumerActors={};local ownershipRefused=false;local initialised=false
local function ownerLive()return R~=nil and GG.Recoil40KCorpseAccount==R and not GG.Recoil40KTacticalRemains end
local function consumerReady()
 if not initialised then return false end
 if ownershipRefused then return false end
 if ownerLive()then return true end
 ownershipRefused=true
 -- Cancel only our own reservations/balances; never replace an unrelated owner.
 local ids={};for id in pairs(consumerActors)do ids[#ids+1]=id end;table.sort(ids)
 for _,id in ipairs(ids)do if A then A.ActorLost(id)end;seeking[id]=nil end
 if GG.Recoil40KSpyderHarvestReview==A then GG.Recoil40KSpyderHarvestReview=nil end
 if GG.Recoil40KSpyderPaidOrigin==P then GG.Recoil40KSpyderPaidOrigin=nil end
 Spring.Echo('40K SPYDER HARVEST REFUSAL','salvage_owner_liveness_lost_no_further_consumers')
 return false
end
local function attach()
 if A or Spring.GetGameFrame()>1 then return end
 if not R or GG.Recoil40KCorpseAccount~=R or GG.Recoil40KTacticalRemains then
  Spring.Echo('40K SPYDER HARVEST REFUSAL','single_existing_review_salvage_owner_required');return
 end
 Q=Q or GG.Recoil40KSpyderHarvestAdapter
 if not Q and GG.Recoil40KResearch then
  P=VFS.Include('40k_configs/necron_spyder_paid_origin.lua').Attach(GG.Recoil40KResearch,Spring,UnitDefs,UnitDefNames)
  Q=VFS.Include('40k_configs/necron_spyder_harvest_native.lua').New(Spring,UnitDefs,FeatureDefs,{scale=8,fps=Game.gameSpeed,
   OwnerAlive=ownerLive,CorpseAccount=R,eligibility='same_death_team_review',IsPaidSpyder=P.IsPaidSpyder,WithBodyProductionPermit=P.WithBodyProductionPermit,
   OutputReady=P.OutputReady,DeathEligible=P.DeathEligible,Witness=function(...)Spring.Echo('40K SPYDER HARVEST',...);if type(GG.Recoil40KSpyderHarvestWitness)=='function'then GG.Recoil40KSpyderHarvestWitness(...)end end})
 end
 if not Q or Q.PolicyDeclared~=true or type(Q.BirthDeathBody)~='function'or Q.Ready()~=true then return end
 local priorReady=Q.Ready;Q.Ready=function()return not ownershipRefused and ownerLive()and priorReady()or false end
 A=M.New(Spring,Q);if P then P.BindLedger(A)end;GG.Recoil40KSpyderHarvestReview=A
 if P then GG.Recoil40KSpyderPaidOrigin=P end
 Spring.Echo('40K SPYDER HARVEST READY',Spring.GetGameFrame(),'same_death_team_review','lethal_combat_only','ordinary_output_prerequisites')
end
function gadget:Initialize()
 if GG.Recoil40KCorpseAccount or GG.Recoil40KTacticalRemains then
  Spring.Echo('40K SPYDER HARVEST REFUSAL','existing_salvage_owner_preserved');return
 end
 if reclaimReview then R=accountModule.New(Spring,UnitDefs,FeatureDefs,Game.gameSpeed);R.Restore();GG.Recoil40KCorpseAccount=R end
 initialised=true
 for _,cmd in ipairs(commands)do gadgetHandler:RegisterCMDID(cmd)end
 attach()
end
local function descriptors(id)
 if not consumerReady()or Q.IsPaidSpyder(id,Spring.GetUnitTeam(id))~=true then return end
 consumerActors[id]=true
 for i,cmd in ipairs(commands)do
  if not Spring.FindUnitCmdDesc(id,cmd)then Spring.InsertUnitCmdDesc(id,{id=cmd,type=CMDTYPE.ICON,name=i==1 and 'Harvest Body' or M.Slots[i-1].name,action='40kspyder'..i,tooltip=i==1 and 'Seek a pristine source corpse; continuous3second pickup within5 source units. Reclaim and body currency are alternatives.'or ('Spend '..M.Slots[i-1].bodies..' bodies for3 source actors.')})end
 end
end
function gadget:UnitCreated(id,def,team,builder)if not consumerReady()then return end;if P then P.Birth(id,def,team,builder)end end
function gadget:UnitFromFactory(id,def,team,factory)if not consumerReady()then return end;if P and P.Factory(id,def,team,factory)then descriptors(id)end end
function gadget:UnitDamaged(id,def,team,damage,paralyzer,weapon,projectile,attacker)if not consumerReady()then return end;if P then P.Damaged(id,damage,paralyzer,attacker)end end
function gadget:UnitFinished(id)if not consumerReady()then return end;if A then descriptors(id)end end
function gadget:UnitDestroyed(id,def,team)
 if not consumerReady()then return end
 if not A then return end
 seeking[id]=nil;A.ActorLost(id)
 -- Native death event is the sole admission route; arbitrary pre-existing wrecks
 -- and resurrected/manual feature ids never mint harvest currency.
 local feature,source,lifetime=Q.BirthDeathBody(id,def,team)
 if feature then A.ObserveDeathBody(feature,id,def,team,source,Spring.GetGameFrame(),lifetime)end
 if P then P.Remove(id)end
end
function gadget:FeatureDestroyed(id)if not consumerReady()then return end;if A then A.FeatureLost(id)end;if R then R.FeatureLost(id)end end
function gadget:AllowFeatureBuildStep(builder,team,feature,featureDef,part)if not consumerReady()then return true end;return not R or R.AllowBuildStep(feature,part)end
function gadget:UnitTaken(id)if not consumerReady()then return end;if P then P.Remove(id)end;seeking[id]=nil;if A then A.ActorLost(id)end end
function gadget:UnitGiven(id)if P then P.Remove(id)end;seeking[id]=nil;if A then A.ActorLost(id)end end
function gadget:GameFrame(frame)if not consumerReady()then return end;if not A then attach()end;if A then A.Tick(frame)end;if R then R.Frame(frame)end end
function gadget:GameFramePost(frame)if not consumerReady()then return end;if A then A.PostFrame(frame)end;if R then R.PostFrame()end end
function gadget:AllowCommand(id,def,team,cmd,p)
 if not consumerReady()then for _,owned in ipairs(commands)do if cmd==owned then return false end end;return true end
 consumerActors[id]=true
 if cmd==commands[1]then return A and Q.IsPaidSpyder(id,team)==true and (not p or #p<=1)and true or false end
 if A then seeking[id]=nil;A.Cancel(id)end
 for i=1,3 do if cmd==commands[i+1]then if A and (not p or #p==0)then A.Produce(id,i,Spring.GetGameFrame())end;return false end end
 return true
end
function gadget:CommandFallback(id,def,team,cmd,p)
 if not consumerReady()then return cmd==commands[1],true end
 consumerActors[id]=true
 if cmd~=commands[1]or not A then return false end
 local f=Spring.GetGameFrame();local fid=seeking[id]or (p and p[1])or A.FindBody(id,f)
 if not fid then return true,true end
 local ok,reason=A.Pickup(id,fid,f)
 if ok then seeking[id]=nil;return true,true end
 if reason~='range'then seeking[id]=nil;return true,true end
 local x,y,z=Spring.GetFeaturePosition(fid);if not x then seeking[id]=nil;return true,true end
 seeking[id]=fid;Spring.SetUnitMoveGoal(id,x,y,z,M.PickupRadius*Q.scale*.9)
 return true,false
end
function gadget:Shutdown()if GG.Recoil40KCorpseAccount==R then GG.Recoil40KCorpseAccount=nil end;if GG.Recoil40KSpyderHarvestReview==A then GG.Recoil40KSpyderHarvestReview=nil end;if GG.Recoil40KSpyderPaidOrigin==P then GG.Recoil40KSpyderPaidOrigin=nil end end
