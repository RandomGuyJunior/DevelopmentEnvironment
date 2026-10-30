function gadget:GetInfo() return {name='Squad presentation and persistent salvage',layer=10000,enabled=true} end
if not gadgetHandler:IsSyncedCode() then
  local function mark(u,d)
    local cp=UnitDefs[d].customParams
    -- Temporary user comparison: use the ordinary interpolation path.
    gl.SetUnitBufferUniforms(u,{0},15)
  end
  function gadget:Initialize() for _,u in ipairs(Spring.GetAllUnits()) do mark(u,Spring.GetUnitDefID(u)) end end
  function gadget:UnitCreated(u,d) mark(u,d) end
  function gadget:UnitEnteredLos(u,team,ally,d) mark(u,d or Spring.GetUnitDefID(u)) end
  return
end
local remains={}
local serial=0
local function remove(id)
  if not remains[id] then return end
  -- Return only UNRECLAIMED entitlement when a living member is restored or
  -- its casualty is restored. Previously reclaimed metal can never be minted again.
  local u=Spring.GetFeatureRulesParam(id,'squad_remains_source')
  local i=Spring.GetFeatureRulesParam(id,'squad_remains_member')
  local token=Spring.GetFeatureRulesParam(id,'squad_remains_token')
  if u and i and Spring.ValidUnitID(u) and Spring.GetUnitRulesParam(u,'squad_salvage_token_'..i)==token then
    local metal=GG.SquadSalvageValue and GG.SquadSalvageValue(id) or Spring.GetFeatureResources(id)
    Spring.SetUnitRulesParam(u,'squad_salvage_'..i,metal or 0,{private=true})
    Spring.SetUnitRulesParam(u,'squad_salvage_token_'..i,-1,{private=true})
  end
  if GG.SquadSalvageDetach then GG.SquadSalvageDetach(id) end
  remains[id]=nil
  if Spring.ValidFeatureID(id) then Spring.DestroyFeature(id) end
end
local function variant(u)
  local def=UnitDefs[Spring.GetUnitDefID(u)]
  if def.customParams.squad_corpse_variant then return def.customParams.squad_corpse_variant end
  local name=def.name
  return name=='igguards' and 'guard' or name=='orkbadmoons' and 'badmoons' or name=='orkslugga' and 'evilsunz' or 'goffs'
end
function gadget:Initialize()
  GG.SquadPresentation={}
  GG.SquadRemoveRemains=function(handle)
    if handle and remains[handle.id] and Spring.GetFeatureRulesParam(handle.id,'squad_remains_token')==handle.token then remove(handle.id) end
  end
  GG.SquadRemains=function(u,index,x,z,yaw)
    local pose=index%3==0 and 'die_alt2' or index%3==1 and 'die' or 'die_alt'
    local name='squad_corpse_'..variant(u)..'_'..pose
    local id=Spring.CreateFeature(name,x,Spring.GetGroundHeight(x,z),z,math.floor(yaw*65536/(2*math.pi))%65536,Spring.GetUnitTeam(u))
    if id then
      serial=serial+1
      local def=UnitDefs[Spring.GetUnitDefID(u)]
      local fraction=tonumber(def.customParams.squad_reclaim_fraction) or .5
      local capacity=math.max(1,tonumber(def.customParams.squad_capacity) or 10)
      fraction=math.max(0,math.min(1,fraction))
      local metal=Spring.GetUnitRulesParam(u,'squad_salvage_'..index)
      if metal==nil then metal=def.metalCost*fraction/capacity end
      Spring.SetFeatureResources(id,metal,0,math.max(1,def.buildTime*fraction/capacity),1,metal,0)
      Spring.SetUnitRulesParam(u,'squad_salvage_'..index,0,{private=true})
      Spring.SetUnitRulesParam(u,'squad_salvage_token_'..index,serial,{private=true})
      remains[id]=true
      Spring.SetFeatureRulesParam(id,'squad_remains_persistent',1)
      Spring.SetFeatureRulesParam(id,'squad_remains_source',u)
      Spring.SetFeatureRulesParam(id,'squad_remains_member',index)
      Spring.SetFeatureRulesParam(id,'squad_remains_token',serial)
      Spring.SetFeatureBlocking(id,false,false,false,false,false,false,false)
    end
    return id and {id=id,token=serial}
  end
  for _,id in ipairs(Spring.GetAllFeatures()) do
    local token=Spring.GetFeatureRulesParam(id,'squad_remains_token')
    if token then remains[id]=true;serial=math.max(serial,token) end
  end
end
function gadget:GameFramePost(f)
  for u,update in pairs(GG.SquadPresentation) do
    if Spring.ValidUnitID(u) then update() else GG.SquadPresentation[u]=nil end
  end
end
-- Reclaim is negative build power; positive corpse repair/resurrection is forbidden.
function gadget:AllowFeatureBuildStep(builder,team,id,def,part)
  local cp=FeatureDefs[def] and FeatureDefs[def].customParams
  if cp and cp.squad_remains then return part<0 end
  return true
end
function gadget:FeatureDestroyed(id) remains[id]=nil end
function gadget:UnitDestroyed(u) GG.SquadPresentation[u]=nil end
function gadget:Shutdown() GG.SquadPresentation=nil;GG.SquadRemains=nil;GG.SquadRemoveRemains=nil end
