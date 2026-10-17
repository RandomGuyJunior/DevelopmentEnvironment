function gadget:GetInfo()
 return {name="40K Centre March", desc="Deterministic prototype economy and grouped waves", author="Local project", layer=100, enabled=true}
end
if not gadgetHandler:IsSyncedCode() then return end
if tostring(Spring.GetModOptions().prototype_mixed_force)=='1' then return end


local sourceProgression=VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(Spring.GetModOptions().prototype_source_progression)
local diagnostic=Spring.GetModOptions().prototype_diagnostic
local function log(...)
 if diagnostic and diagnostic~="normal" then Spring.Echo(...) end
end
local AI_NAME = "40K Test AI - Centre March"
local GRACE = 240 * Game.gameSpeed
local WAVE_INTERVAL = 90 * Game.gameSpeed
local teams, teamOrder = {}, {}
local factionNames={Imperium=true,['Imperial Guard']=true,['Space Marines']=true,Orks=true,Necrons=true}
local nativeConstructors={armck=true,armcv=true,armack=true,armacv=true,corck=true,corcv=true,corack=true,coracv=true}
local baseline={imp_guardsman=true,imp_marine=true,imp_russ=true,ork_boy=true,ork_meganob=true,ork_killa_kan=true}
local weights={imp_guardsman=10,imp_marine=3,imp_commissar=2,imp_kasrkin=3,imp_scout=3,imp_devastator=2,imp_ogryn=2,imp_heavy_weapon_team=2,
 ork_boy=10,ork_meganob=3,ork_slugga=6,ork_burna=3,ork_tankbusta=3,ork_loota=2,ork_nob=3,ork_warboss=1,
 nec_warrior=10,nec_immortal=3,nec_flayed=3,nec_wraith=2}
local diagnosticAssets=diagnostic=='expandedproduction' or diagnostic=='vital' or diagnostic=='roster' or diagnostic=='ui'
local function flag(value)return value~=nil and value~=false and value~=0 and value~='0'end
local function faction(ud)
 local cp=ud.customParams or {}
 if factionNames[cp.faction] then return cp.faction end
 local prefix=ud.name:sub(1,3)
 return prefix=='arm' and 'Imperium' or prefix=='cor' and 'Orks' or nil
end
local airConstructorSignature=sourceProgression and VFS.Include('40k_configs/centre_march_air_constructor_signature.lua')
local function constructorSignature(ud)
 local cp=ud.customParams or {};local tier=tonumber(cp.prototype40k_constructor_tier);local domain=cp.prototype40k_constructor_domain
 if tier and tier>=1 and (domain=='infantry' or domain=='vehicle')then return domain..':'..tier end
 if airConstructorSignature then return airConstructorSignature.Air(ud)end
end
local function graphFactory(ud)
 local cp=ud.customParams or {};local tier=tonumber(cp.prototype40k_factory_tier);local domain=cp.prototype40k_factory_domain
 return tier and tier>=1 and (domain=='infantry' or domain=='vehicle')
end
local function accepted(ud)
 local cp=ud.customParams or {}
 if not flag(cp.prototype40k) then return false end
 if sourceProgression then
  if flag(cp.prototype40k_native_factory_pilot)or flag(cp.prototype40k_domain_candidate)then
   return type(ud.modelpath)=='string'and VFS.FileExists(ud.modelpath)and type(ud.scriptName)=='string'and VFS.FileExists(ud.scriptName)
  end
  local key=cp.animsource or cp.prototype40k_donor or ud.name
  return flag(cp.prototype40k_source_progression) and VFS.FileExists("objects3d/"..key..".glb") and VFS.FileExists("scripts/generated/"..key.."_anim.lua")
 end
 if baseline[ud.name] or diagnosticAssets then return true end
 return VFS and VFS.FileExists and (VFS.FileExists('40k_configs/validated/'..ud.name..'.lua') or
  cp.animsource and VFS.FileExists('40k_configs/validated/'..cp.animsource..'.lua')) or false
end
local function commander(ud)
 local cp=ud.customParams or {}
 return ud.name=='smcom' or ud.name=='armcom' or ud.name=='corcom' or ud.name=='nec_lord' or flag(cp.iscommander) or cp.prototype40k_vital=='commander'
end
local function mobile(ud)return (ud.speed or 0)>0 end
local function qualifiedConstructor(ud)
 return mobile(ud) and ud.isBuilder and not commander(ud) and (accepted(ud) or (not sourceProgression and nativeConstructors[ud.name]))
end
local function fighter(ud)
 return mobile(ud) and not commander(ud) and not ud.isBuilder and accepted(ud) and #(ud.weapons or {})>0
end
local function productRole(ud)
 local cp=ud.customParams or {};local role=cp.production_role or cp.rosterrole
 if role=='walker' or ud.name=='ork_killa_kan' then return 'walker' end
 if role=='tank' or role=='artillery' or role=='vehicle' or role=='transport' or ud.name=='imp_russ' then return 'tank' end
 return 'infantry'
end
local aliases={armmex='mex',cormex='mex',armsolar='solar',corsolar='solar',armlab='infantry',corlab='infantry',armvp='tank',corvp='walker'}
local function structureRole(ud)
 local cp=ud.customParams or {};local r=cp.prototype40k_vital or cp.production_role or cp.rosterrole
 if aliases[ud.name] then return aliases[ud.name] end
 if r=='extractor' or r=='mex' then return 'mex' end
 if (r=='generator' or r=='energy') and not ud.needGeo then return 'solar' end
 if r=='barracks' or r=='infantry_factory' then return 'infantry' end
 if r=='tank_factory' then return 'tank' end
 if r=='walker_factory' then return 'walker' end
 if r=='HQ' or r=='hq' or r=='command_factory' then return 'hq' end
end
local function controller()return sourceProgression and GG and GG.Recoil40KResearch end
local function canBuild(team,def,builder)
 local c=controller()
 return not sourceProgression or c and c.CanBuild(team,def,builder,false)==true
end
local function canonical(ud)local cp=ud.customParams or{};return cp.prototype40k_tech_requires or cp.prototype40k_donor or ud.name end
local rally
local paidPressure
local squadAI=VFS.Include('40k_configs/squad_ai_adapter.lua').New(Spring,UnitDefs,CMD,
 function()return GG and GG.Recoil40KSquads end,
 function()return GG and GG.Recoil40KSquadTransport end)
local squadResearch=VFS.Include('40k_configs/centre_march_squad_research.lua').New(Spring,UnitDefs,VFS.Include('40k_configs/active_squad_profiles.lua'))
local paidPressureEnabled=sourceProgression and diagnostic=="expandedproduction" and tostring(Spring.GetModOptions().prototype_source_paid_match)=="1"

local function alive(id, team)
 return id and Spring.ValidUnitID(id) and not Spring.GetUnitIsDead(id)
  and Spring.GetUnitTeam(id)==team
end
local function sortedUnits(team)
 local list=Spring.GetTeamUnits(team) or {}
 table.sort(list)
 return list
end
local function dryFlat(x,z)
 local y=Spring.GetGroundHeight(x,z)
 if x<64 or z<64 or x>Game.mapSizeX-64 or z>Game.mapSizeZ-64 or y<5 then return end
 for _,offset in ipairs({{-32,0},{32,0},{0,-32},{0,32}}) do
  if math.abs(y-Spring.GetGroundHeight(x+offset[1],z+offset[2]))>12 then return end
 end
 return y
end
local function centre()
 local x,z=Game.mapSizeX/2,Game.mapSizeZ/2
 for ring=0,30 do
  for i=0,15 do
   local a=i*math.pi/8
   local xx,zz=x+ring*32*math.cos(a),z+ring*32*math.sin(a)
   local y=dryFlat(xx,zz)
   if y then return {xx,y,zz} end
  end
 end
 -- Prefer a dry meeting point anywhere within the central half, not water.
 for xx=Game.mapSizeX/4,Game.mapSizeX*3/4,64 do
  for zz=Game.mapSizeZ/4,Game.mapSizeZ*3/4,64 do
   local y=dryFlat(xx,zz)
   if y then return {xx,y,zz} end
  end
 end
 return {x,Spring.GetGroundHeight(x,z),z}
end
local function blockedApron(t,x,z,def)
 local radius=math.max(def.xsize or 2,def.zsize or 2)*4+24
 for _,factory in ipairs(t.factories or {}) do
  local fx,_,fz=Spring.GetUnitPosition(factory)
  -- Factories face south (facing 0); leave their front clear for the Russ/Kan.
  if fx and math.abs(x-fx)<100+radius and z>fz-40-radius and z<fz+230+radius then return true end
 end
 return false
end
local function staticOverlap(t,x,z,def)
 -- Own unfinished/completed immobile footprints, not just factory exit aprons.
 local team=t.com and Spring.GetUnitTeam(t.com)
 if team==nil then return false end
 local hx,hz=(def.xsize or 2)*4,(def.zsize or 2)*4
 for _,id in ipairs(Spring.GetTeamUnits(team) or {})do
  local other=UnitDefs[Spring.GetUnitDefID(id)]
  if other and not mobile(other) and not other.canFly then
   local ox,_,oz=Spring.GetUnitPosition(id)
   local sx,sz=(other.xsize or 2)*4,(other.zsize or 2)*4
   local facing=Spring.GetUnitBuildFacing and Spring.GetUnitBuildFacing(id) or 0
   if facing%2==1 then sx,sz=sz,sx end
   if ox and math.abs(x-ox)<hx+sx+16 and math.abs(z-oz)<hz+sz+16 then return true,id end
  end
 end
 return false
end
local function siteDiagnostic(t,defID,x,z,result,feature,reason,occupant,selected)
 if not paidPressureEnabled then return end
 local f=Spring.GetGameFrame();t.siteLogFrames=t.siteLogFrames or{}
 if t.siteLogFrames[defID]and f-t.siteLogFrames[defID]<90 then return end
 t.siteLogFrames[defID]=f
 local head=Spring.GetUnitCommands(t.com,1);head=head and head[1]
 log('40K AI SITE',Spring.GetUnitTeam(t.com),UnitDefs[defID].name,x,z,
  'native_result',result or 'untested','feature',feature or 'none','reason',reason,
  'occupant',occupant or 'none','selected',selected or false,
  'builder',t.com,'head',head and head.id or 'none','frame',f)
end
local function site(t,defID,x,z,maximumRing)
 local def=UnitDefs[defID]
 local firstReject
 for ring=0,maximumRing or 12 do
  for i=0,7 do
   local angle=i*math.pi/4
   local xx=math.floor((x+ring*32*math.cos(angle))/16)*16+8
   local zz=math.floor((z+ring*32*math.sin(angle))/16)*16+8
   local y=dryFlat(xx,zz)
   -- TestBuildOrder snaps internally; dispatch must use that same native site.
   if y and Spring.Pos2BuildPos then
    xx,y,zz=Spring.Pos2BuildPos(defID,xx,y,zz,0)
    if type(xx)~='number' or type(y)~='number' or type(zz)~='number'
     or xx~=xx or y~=y or zz~=zz or math.abs(xx)==math.huge
     or math.abs(y)==math.huge or math.abs(zz)==math.huge then y=nil end
    if y and not dryFlat(xx,zz) then y=nil end
   else y=nil end
   if y and not blockedApron(t,xx,zz,def) then
    local result,feature=Spring.TestBuildOrder(defID,xx,y,zz,0)
    local overlap,occupant=staticOverlap(t,xx,zz,def)
    -- Exact pinned API maps OPEN to 2; result1 is occupied, never legal.
    if result==2 and not feature and not overlap then
     if firstReject then siteDiagnostic(t,defID,firstReject.x,firstReject.z,firstReject.result,firstReject.feature,firstReject.reason,firstReject.occupant,xx..','..zz)end
     return {xx,y,zz,0}
    end
    firstReject=firstReject or {x=xx,z=zz,result=result,feature=feature,occupant=occupant,
     reason=overlap and 'owned_static_footprint' or feature and 'reclaimable_feature' or 'native_not_open'}
   end
  end
 end
 if firstReject then siteDiagnostic(t,defID,firstReject.x,firstReject.z,firstReject.result,firstReject.feature,firstReject.reason,firstReject.occupant,false)end
end
local function scan(team,t)
 t.factories={};t.factoryKinds={};t.constructors={};t.constructorSignatures={};t.roles={};t.counts={mex=0,solar=0,lab=0,vp=0};t.unfinished={}
 local owned=sortedUnits(team)
 for _,id in ipairs(owned) do
  local ud=UnitDefs[Spring.GetUnitDefID(id)]
  if ud and commander(ud) and faction(ud) and (ud.name~='nec_lord' or accepted(ud)) and (not alive(t.com,team) or id==t.com) then
   t.com=id;t.faction=faction(ud)
   if not t.base then local x,y,z=Spring.GetUnitPosition(id);t.base={x,y,z};log('40K AI BASE',team,t.faction,x,z) end
  end
 end
 if not t.faction then return end
 for _,id in ipairs(owned) do
  local defID=Spring.GetUnitDefID(id);local ud=UnitDefs[defID]
  if ud and faction(ud)==t.faction then
   local _,_,_,_,progress=Spring.GetUnitHealth(id)
   local complete=progress and progress>=1
   if qualifiedConstructor(ud)then
    local signature=constructorSignature(ud)
    -- Incomplete native paid constructors already satisfy the pending domain;
    -- a second factory must not duplicate them before UnitFinished.
    if signature then t.constructorSignatures[signature]=true end
   end
   if mobile(ud) and ud.isBuilder and (commander(ud) or qualifiedConstructor(ud)) and complete then t.constructors[#t.constructors+1]=id end
   local role=not mobile(ud) and structureRole(ud)
   if role then
    t.roles[role]=(t.roles[role] or 0)+1
    if complete and (role=='mex' or role=='solar') then t.counts[role]=t.counts[role]+1 end

   end
   if not mobile(ud) and not complete and (role or sourceProgression and accepted(ud))then t.unfinished[#t.unfinished+1]=id end
   if not mobile(ud) and ud.isBuilder and complete and #(ud.buildOptions or {})>0 then
    local factory=false
    for _,product in ipairs(ud.buildOptions) do
     local target=UnitDefs[product]
     if target and faction(target)==t.faction and fighter(target) then factory=true;t.roles['production_'..productRole(target)]=true end
    end
    if factory or graphFactory(ud) or role=='hq' then
     t.factories[#t.factories+1]=id;t.factoryKinds[id]=role or 'mixed'
     if role=='infantry' then t.counts.lab=t.counts.lab+1 else t.counts.vp=t.counts.vp+1 end
    end
   end
  end
 end
 table.sort(t.constructors,function(a,b)if a==b then return false end;if a==t.com then return true end;if b==t.com then return false end;return a<b end)
end
local function buildChoice(t,kind)
 for _,builder in ipairs(t.constructors) do
  local options=UnitDefs[Spring.GetUnitDefID(builder)].buildOptions or {};local candidates={}
  for _,id in ipairs(options) do
   local ud=UnitDefs[id]

   local productionReady=kind~='infantry'and kind~='tank'and kind~='walker'
   if ud and not productionReady then for _,product in ipairs(ud.buildOptions or{})do local target=UnitDefs[product];if target and faction(target)==t.faction and (fighter(target) or qualifiedConstructor(target))then productionReady=true;break end end end
   if ud and productionReady and not mobile(ud) and faction(ud)==t.faction and structureRole(ud)==kind and (not sourceProgression and aliases[ud.name] or accepted(ud)) and canBuild(Spring.GetUnitTeam(builder),id,builder) then candidates[#candidates+1]=id end
  end
  table.sort(candidates,function(a,b)
   local ua,ub=UnitDefs[a],UnitDefs[b]
   if flag(aliases[ua.name])~=flag(aliases[ub.name]) then return flag(aliases[ua.name]) end
   if (ua.metalCost or 0)~=(ub.metalCost or 0) then return (ua.metalCost or 0)<(ub.metalCost or 0) end
   return ua.name<ub.name
  end)
  local commands=Spring.GetUnitCommands(builder,1)
  if #candidates>0 and (not commands or #commands==0) then return builder,candidates[1] end
 end
end
local function stockExtractorSite(team,t,defID,api)
 if type(api.metalSpotsList)~='table'or type(api.GetBuildingPositions)~='function'or type(api.IsMexPositionValid)~='function'then return end
 local x,z=t.base[1],t.base[3];local candidates={}
 for _,spot in ipairs(api.metalSpotsList)do
  for _,pos in ipairs(api.GetBuildingPositions(spot,defID,0,true)or{})do
   if type(pos.x)=='number'and type(pos.z)=='number'then
    candidates[#candidates+1]={x=pos.x,z=pos.z,spot=spot,distance=(pos.x-x)^2+(pos.z-z)^2}
   end
  end
 end
 table.sort(candidates,function(a,b)if a.distance~=b.distance then return a.distance<b.distance end;if a.x~=b.x then return a.x<b.x end;return a.z<b.z end)
 for _,c in ipairs(candidates)do
  local xx,zz=c.x,c.z;local y=dryFlat(xx,zz)
  if y then
   if Spring.Pos2BuildPos then xx,y,zz=Spring.Pos2BuildPos(defID,xx,y,zz,0)end
   local result,feature=Spring.TestBuildOrder(defID,xx,y,zz,0)
   local overlap=staticOverlap(t,xx,zz,UnitDefs[defID])
   if result==2 and not feature and not overlap and not blockedApron(t,xx,zz,UnitDefs[defID])and api.IsMexPositionValid(c.spot,xx,zz)then
    local free=true
    for _,id in ipairs(Spring.GetTeamUnits(team)or{})do
     local d=UnitDefs[Spring.GetUnitDefID(id)]
     if d and(d.extractsMetal or 0)>0 then local mx,_,mz=Spring.GetUnitPosition(id);if mx and(mx-c.spot.x)^2+(mz-c.spot.z)^2<(Game.extractorRadius or 96)^2 then free=false;break end end
    end
    if free then return defID,{xx,y,zz,0}end
   end
  end
 end
end
local function extractorSite(team,t,defID)
 local api=GG and GG.resource_spot_finder
 -- Spot maps use the same full-yield position provider and final native snap
 -- as stock placement. Raw positive metal does not establish legal admission.
 if api and not api.isMetalMap then return stockExtractorSite(team,t,defID,api)end
 local x,z=t.base[1],t.base[3]
 local candidates=t.metalCandidates or {}
 if not t.metalCandidates then
 for xx=math.max(64,x-800),math.min(Game.mapSizeX-64,x+800),32 do
  for zz=math.max(64,z-800),math.min(Game.mapSizeZ-64,z+800),32 do
   local metal=select(3,Spring.GetGroundInfo(xx,zz)) or 0
   if metal>0 and dryFlat(xx,zz) then
    candidates[#candidates+1]={xx,zz,metal,(xx-x)^2+(zz-z)^2}
   end
  end
 end
 table.sort(candidates,function(a,b)
  if a[4]~=b[4] then return a[4]<b[4] end
  if a[3]~=b[3] then return a[3]>b[3] end
  if a[1]~=b[1] then return a[1]<b[1] end
  return a[2]<b[2]
 end)
 t.metalCandidates=candidates
 end
 local extractors={}
 for _,id in ipairs(sortedUnits(team)) do
  if Spring.GetUnitDefID(id)==defID then
   local mx,_,mz=Spring.GetUnitPosition(id)
   extractors[#extractors+1]={mx,mz}
  end
 end
 for _,candidate in ipairs(candidates) do
  local free=true
  for _,extractor in ipairs(extractors) do
   if (extractor[1]-candidate[1])^2+(extractor[2]-candidate[2])^2<math.max(96,Game.extractorRadius or 96)^2 then free=false;break end
  end
  if free then
   local p=site(t,defID,candidate[1],candidate[2],1)
   if p and (select(3,Spring.GetGroundInfo(p[1],p[3])) or 0)>0 then return defID,p end
  end
 end
end
local orkNavalSite=sourceProgression and VFS.Include('40k_configs/centre_march_ork_naval_site.lua')
local function structureSite(t,kind,defID,builder)
 if orkNavalSite and UnitDefs[defID]and UnitDefs[defID].name=='fortyk_ork_naval_factory'then
  return orkNavalSite.Select(Spring,UnitDefs,t,defID,builder,staticOverlap,blockedApron)
 end
 local x,z=t.base[1],t.base[3]
 if kind=='infantry' then return site(t,defID,x+192,z-192,18) end
 if kind=='tank' then return site(t,defID,x-224,z-256,20) end
 if kind=='walker' then return site(t,defID,x+440,z-300,22) end
 if kind=='hq' then return site(t,defID,x-450,z-430,22) end
 return site(t,defID,x-160,z+96,22)
end
local function maintainEconomy(team,t,f)
 if not alive(t.com,team) or not t.base then return end
 if #t.unfinished>0 then
  for _,builder in ipairs(t.constructors) do
   local commands=Spring.GetUnitCommands(builder,1)
   if not commands or #commands==0 then Spring.GiveOrderToUnit(builder,CMD.REPAIR,{t.unfinished[1]},{});return end
  end
  return
 end
 local function build(kind)
  local builder,def=buildChoice(t,kind);if not builder then return false end
  local p
  if kind=='mex' then p=select(2,extractorSite(team,t,def)) else p=structureSite(t,kind,def) end
  if not p then return false end
  if GG and GG.Recoil40KPaidBuildWitness then GG.Recoil40KPaidBuildWitness.Before(builder,def,p) end
  local nativeReturn=Spring.GiveOrderToUnit(builder,-def,p,{})
  if GG and GG.Recoil40KPaidBuildWitness then GG.Recoil40KPaidBuildWitness.After(builder,def,p,nativeReturn) end
  if paidPressureEnabled then
   local head=Spring.GetUnitCommands(builder,1);head=head and head[1]
   log('40K AI BUILD NATIVE',team,UnitDefs[def].name,'return',tostring(nativeReturn),
    'head',head and head.id or 'none','tag',head and head.tag or 'none','builder',builder,'frame',f)
  end
  if nativeReturn==false then return false end
  log('40K AI BUILD',team,UnitDefs[def].name,p[1],p[3],f,builder)
  return true
 end
 if t.counts.mex<2 and build('mex') then return end
 if t.counts.solar<2 and build('solar') then return end
 if not t.roles.production_infantry and not t.roles.infantry and build('infantry') then return end
 if t.counts.solar<4 and build('solar') then return end
 if not t.roles.production_tank and not t.roles.tank and build('tank') then return end
 if not t.roles.production_walker and not t.roles.walker and build('walker') then return end
 if t.counts.mex<3 and build('mex') then return end
 if t.counts.solar<8 and build('solar') then return end
 -- Commander starts the real economy; an optional source HQ is not a chore.
 local energy,storage,_,ei,ee=Spring.GetTeamResources(team,'energy')
 if t.counts.solar<16 and energy and ((ei or 0)<(ee or 0)*1.25 or (storage>0 and energy/storage<.25 and (ei or 0)<250)) and build('solar') then return end
 local _,_,_,mi=Spring.GetTeamResources(team,'metal')
 if t.counts.mex<5 and (mi or 0)<8 then build('mex') end
end
-- Source progression uses the same public controller and native commands as a
-- player. Readiness, costs, caps and unsupported effects remain authoritative
-- there; the AI only resolves dependencies and selects an idle owned producer.
local function progressSource(team,t,f)
 local c=controller()
 if not c or not t.base or t.counts.mex<2 then return end
 if paidPressureEnabled and tostring(Spring.GetModOptions().prototype_paid_tech_witness)=='1'then
  GG.Recoil40KPaidTechWitness=GG.Recoil40KPaidTechWitness or VFS.Include('40k_configs/centre_march_paid_tech_witness_v2.lua').New()
  GG.Recoil40KPaidTechWitness.Observe{enabled=true,Spring=Spring,UnitDefs=UnitDefs,controller=c,team=team,faction=t.faction,frame=f,
   source=VFS.Include('40k_configs/primary_variant_progression.lua'),Log=log}
 end
 -- Avoid loading diagnostic-only source graphs in every ordinary AI tick.
 if paidPressureEnabled and VFS.Include('40k_configs/centre_march_paid_banners.lua').Step{
  Spring=Spring,UnitDefs=UnitDefs,team=team,state=t,controller=c,frame=f,enabled=paidPressureEnabled,
  Witness=GG and GG.Recoil40KPaidBuildWitness,source=VFS.Include('40k_configs/primary_variant_progression.lua'),Ready=accepted,CanBuild=canBuild,
  Site=function(def)return structureSite(t,'research',def)end,Log=log}then return end
 local owned=sortedUnits(team)
 local function finished(id)
  if not alive(id,team) then return false end
  local hp,_,_,_,progress=Spring.GetUnitHealth(id)
  return hp and hp>0 and progress and progress>=1
 end
 local function present(name)
  for _,id in ipairs(owned)do
   local ud=UnitDefs[Spring.GetUnitDefID(id)]
   if ud and canonical(ud)==name then return true end
  end
  for _,builder in ipairs(t.constructors)do
   for _,command in ipairs(Spring.GetUnitCommands(builder,-1)or{})do
    local ud=command.id and command.id<0 and UnitDefs[-command.id]
    if ud and canonical(ud)==name then return true end
   end
  end
  return false
 end
 local function complete(name)
  for _,id in ipairs(owned)do
   local ud=UnitDefs[Spring.GetUnitDefID(id)]
   if ud and canonical(ud)==name and finished(id) then return true end
  end
  return false
 end
 local function idle(id)
  local queue=Spring.GetUnitCommands(id,1)
  return not queue or #queue==0
 end
 local keys={};for key in pairs(c.records)do keys[#keys+1]=key end
 table.sort(keys,function(a,b)
  local ra,rb=c.records[a].row,c.records[b].row
  local ta,tb=ra.grants_tier or ra.tier or (ra.requires or {}).tier or 0,rb.grants_tier or rb.tier or (rb.requires or {}).tier or 0
  if ta~=tb then return ta<tb end
  return a<b
 end)
 local function ourProducer(name)
  for _,ud in pairs(UnitDefs)do if canonical(ud)==name and faction(ud)==t.faction and accepted(ud)then return true end end
  return false
 end
 local building,research,requirements
 requirements=function(r,seen)
  r=r or{}
  if r.production_method then return false end -- possession is not factory production
  for _,name in ipairs(r.buildings or{})do
   if not complete(name)then return building(name,seen)end
  end
  for _,key in ipairs(r.research or{})do
   if not c.HasResearch(team,key)then return research(key,seen)end
  end
  if (c.tiers[team]or 0)<(r.tier or 0)then
   for _,key in ipairs(keys)do
    local record=c.records[key]
    if (record.row.grants_tier or record.row.tier or 0)>=(r.tier or 0) and ourProducer(record.producer)
      and not c.HasResearch(team,key) then
     local issued=research(key,seen);if issued then return true end
    end
   end
   return false
  end
 end
 building=function(name,seen)
  if present(name)or seen['b:'..name]then return false end
  seen['b:'..name]=true
  -- Resolve actual menu entries (including correctly bound donor aliases), not
  -- a guessed UnitDef name or a substitute native factory.
  for _,builder in ipairs(t.constructors)do
   if finished(builder) and idle(builder)then
    for _,def in ipairs(UnitDefs[Spring.GetUnitDefID(builder)].buildOptions or{})do
     local ud=UnitDefs[def]
     if ud and canonical(ud)==name and not mobile(ud) and faction(ud)==t.faction and accepted(ud)then
      if not canBuild(team,def,builder)then
       if requirements(c.requirements[name],seen)then return true end
      else
       local role=structureRole(ud);local p
       if role=='mex' then p=select(2,extractorSite(team,t,def))else p=structureSite(t,role,def,builder)end
       if p then
        local witness=GG and GG.Recoil40KPaidBuildWitness
        local receipt=witness and witness.ReadonlyCommandBefore and witness.ReadonlyCommandBefore(builder,def,p,true)
        local nativeReturn=Spring.GiveOrderToUnit(builder,-def,p,{})
        if witness and witness.ReadonlyCommandAfter then witness.ReadonlyCommandAfter(receipt,builder,def,p,nativeReturn)end
        if nativeReturn==false then return false end
        log('40K AI TECHNOLOGY BUILD',team,name,builder,f)
        return true
       end
      end
     end
    end
   end
  end
  return false
 end
 research=function(key,seen)
  if c.HasResearch(team,key) or (c.reserved[team]or{})[key]or seen['r:'..key]then return false end
  seen['r:'..key]=true
  local record=c.records[key]
  if not record or not ourProducer(record.producer)then return false end
  if not complete(record.producer)then return building(record.producer,seen)end
  if requirements(record.row.requires,seen)then return true end
  if t.counts.solar<2 then return false end
  if not squadResearch.Ready(team,key,record,c,owned)then return false end
  for _,id in ipairs(owned)do
   local u=c.units[id]
   if u and u.team==team and u.finished and u.name==record.producer and finished(id) and idle(id)
     and c.Requirement(team,record.row.requires,id,false)==true then
    -- Native descriptor existence/disabled state is an additional fail-closed
    -- guard. GiveOrder invokes the real AllowCommand reservation path.
    for _,desc in ipairs(Spring.GetUnitCmdDescs(id)or{})do
     if desc.id==record.cmd and not desc.disabled then
      local nativeReturn=Spring.GiveOrderToUnit(id,record.cmd,{},{})
      if nativeReturn==false then return false end
      log('40K AI RESEARCH ORDER',team,key,id,f)
      return true
     end
    end
   end
  end
  return false
 end
 for _,key in ipairs(keys)do if research(key,{})then return end end
 for _,factory in ipairs(t.factories)do
  for _,def in ipairs(UnitDefs[Spring.GetUnitDefID(factory)].buildOptions or{})do
   local ud=UnitDefs[def]
   if ud and fighter(ud) and faction(ud)==t.faction and not canBuild(team,def,factory)then
    if requirements(c.requirements[canonical(ud)],{})then return end
   end
  end
 end
 -- Once prerequisite research is paid, construct source factories actually
 -- offered by our builders. Unsupported/missing products never create a route.
 local targets={}
 for _,builder in ipairs(t.constructors)do
  for _,def in ipairs(UnitDefs[Spring.GetUnitDefID(builder)].buildOptions or{})do
   local ud=UnitDefs[def]
   if ud and not mobile(ud) and accepted(ud) and faction(ud)==t.faction
    and (graphFactory(ud) or structureRole(ud)~='hq')then
    for _,product in ipairs(ud.buildOptions or{})do
     local target=UnitDefs[product]
     if target and faction(target)==t.faction and fighter(target)then targets[canonical(ud)]=true;break end
    end
   end
  end
 end
 local names={};for name in pairs(targets)do names[#names+1]=name end;table.sort(names)
 for _,name in ipairs(names)do if building(name,{})then return end end
end
local function production(team,t,f)
 local training=0;local signatures={};local airQueueUnknown=false
 for key in pairs(t.constructorSignatures or{})do signatures[key]=true end
 for _,factory in ipairs(t.factories) do
  local pending=t.constructorPending[factory]
  if pending and Spring.GetFactoryCommandCount(factory)>0 then
   local pd=type(pending)=='number'and UnitDefs[pending]
   if airConstructorSignature and (not pd or airConstructorSignature.Air(pd))then
    local reserved=false
    if pd and qualifiedConstructor(pd)then
     reserved=airConstructorSignature.Pending(pd,pending,Spring.GetFactoryCommands and Spring.GetFactoryCommands(factory,-1),t.faction)
    end
    if reserved==true then
     training=training+1;signatures[airConstructorSignature.Air(pd)]=true
    elseif reserved==nil then airQueueUnknown=true
    else t.constructorPending[factory]=nil end
   else
    training=training+1
    local signature=type(pending)=='number' and constructorSignature(UnitDefs[pending])
    if signature then signatures[signature]=true end
   end
  else t.constructorPending[factory]=nil end
  -- Also honour existing player/native queues, not only an AI memory receipt.
  if Spring.GetFactoryCommands then
   local queue=Spring.GetFactoryCommands(factory,-1)
   if airConstructorSignature and not airConstructorSignature.Queue(queue)then airQueueUnknown=true;queue={}end
   for _,command in ipairs(queue or{})do
    local product=command.id and command.id<0 and UnitDefs[-command.id]
    if product and faction(product)==t.faction and qualifiedConstructor(product)then
     local signature=constructorSignature(product);if signature then signatures[signature]=true end
    end
   end
  elseif airConstructorSignature then airQueueUnknown=true
  end
 end
 for _,factory in ipairs(t.factories) do
  if Spring.GetFactoryCommandCount(factory)==0 and t.counts.mex>=2 and t.counts.solar>=2 then
   local def=UnitDefs[Spring.GetUnitDefID(factory)];local choices,builders={},{}
   for _,product in ipairs(def.buildOptions or {}) do
    local ud=UnitDefs[product]
    if ud and faction(ud)==t.faction then
     if fighter(ud) and canBuild(team,product,factory) then
      local weight=weights[ud.name] or 1
      choices[#choices+1]={id=product,name=ud.name,weight=weight,role=productRole(ud)}
     elseif qualifiedConstructor(ud) and canBuild(team,product,factory) then builders[#builders+1]=product end
    end
   end
   table.sort(builders,function(a,b)return UnitDefs[a].name<UnitDefs[b].name end)
   local selected
   for _,product in ipairs(builders)do
    local ud=UnitDefs[product];local signature=constructorSignature(ud)
    local useful=false
    for _,target in ipairs(ud.buildOptions or{})do
     local structure=UnitDefs[target]
     if structure and not mobile(structure) and faction(structure)==t.faction
       and (accepted(structure) or not sourceProgression and aliases[structure.name])
       and (structureRole(structure) or graphFactory(structure))then useful=true;break end
    end
    -- One real constructor per available domain/tier opens its actual legal
    -- menu. This requirement takes precedence over the legacy two-person cap.
    if signature and not signatures[signature] and useful and not(airQueueUnknown and airConstructorSignature and airConstructorSignature.Air(ud))then selected=product;break end
   end
   if not selected and #t.constructors+training<2 then
    for _,product in ipairs(builders)do if not constructorSignature(UnitDefs[product])then selected=product;break end end
   end
   if selected then
    local nativeReturn=Spring.GiveOrderToUnit(factory,-selected,{},{})
    if nativeReturn~=false then
     t.constructorPending[factory]=selected;training=training+1
     local signature=constructorSignature(UnitDefs[selected]);if signature then signatures[signature]=true end
     log('40K AI QUEUE',team,factory,'constructor',UnitDefs[selected].name,f)
    end
   else
    table.sort(choices,function(a,b)return a.name<b.name end)
    local schedule={};for _,choice in ipairs(choices) do for _=1,choice.weight do schedule[#schedule+1]=choice end end
    if #schedule>0 then
     for offset=1,#schedule do
      local cycle=((t.factoryCycles[factory] or 0)+offset-1)%#schedule+1;local choice=schedule[cycle]
      local allowed=choice.role=='infantry' or (t.heavyFactoryCycles[factory] or 0)*6<t.infantryCycles
      allowed=allowed and canBuild(team,choice.id,factory)
      local m,_,_,mi=Spring.GetTeamResources(team,'metal');local ud=UnitDefs[choice.id]
      -- Skip unaffordable superheavy entries without blocking cheaper source
      -- types later in the same stable cycle; revisit next cycle as income grows.
      if (ud.metalCost or 0)>1000 then allowed=allowed and (mi or 0)>=8 and (m or 0)>=(ud.metalCost or 0)*.25 end
      if allowed then
       local nativeReturn=Spring.GiveOrderToUnit(factory,-choice.id,{},{})
       if nativeReturn~=false then
        t.factoryCycles[factory]=cycle
        if choice.role=='infantry' then t.infantryCycles=t.infantryCycles+1 else t.heavyCycles=t.heavyCycles+1;t.heavyFactoryCycles[factory]=(t.heavyFactoryCycles[factory] or 0)+1 end
        log('40K AI QUEUE',team,factory,choice.role,choice.name,f)
        break
       end
      end
     end
    end
   end
  end
 end
end
local function stageUnit(team,t,id,waitingSlot)
 local x,_,z=Spring.GetUnitPosition(id)
 local dx,dz=rally[1]-t.base[1],rally[3]-t.base[3]
 local length=math.sqrt(dx*dx+dz*dz)
 if length>0 then dx,dz=dx/length,dz/length else dx,dz=0,1 end
 local slot=((waitingSlot or #t.waiting)-1)%12
 local sx=x+dx*170+dz*(slot-5.5)*18
 local sz=z+dz*170-dx*(slot-5.5)*18
 local y=dryFlat(sx,sz)
 if y then Spring.GiveOrderToUnit(id,CMD.MOVE,{sx,y,sz},{}) end
 -- Prevent automatic chasing before a wave is released; firing at intruders
 -- is allowed. The commander receives construction orders only.
 Spring.GiveOrderToUnit(id,CMD.MOVE_STATE,{0},{})
end
function gadget:Initialize()
 rally=centre()
 if paidPressureEnabled then paidPressure=VFS.Include("40k_configs/centre_march_pressure.lua").New(Spring,UnitDefs,Game,CMD,fighter,log,squadAI) end
 local list=Spring.GetTeamList()
 table.sort(list)
 for _,team in ipairs(list) do
  if Spring.GetTeamLuaAI(team)==AI_NAME then
   teams[team]={waiting={},wave=0,lastWave=GRACE-WAVE_INTERVAL,factories={},infantryCycles=0,heavyCycles=0,factoryCycles={},constructorPending={},heavyFactoryCycles={}}
   teamOrder[#teamOrder+1]=team
   log("40K AI TEAM",team,AI_NAME,rally[1],rally[3],"grace_frames",GRACE)
  end
 end
end
function gadget:UnitFinished(id,def,team)
 local t=teams[team]
 if not t then return end
 local ud=UnitDefs[def]
 if fighter(ud) then
  if not t.base then scan(team,t) end
  t.waiting[#t.waiting+1]=id
  -- Membership can be bound after synchronous internal UnitFinished. Stage
  -- through the adapter on the next regular tick, once per logical squad.
  log("40K PRODUCTION",team,ud.name,id)
 end
end
function gadget:UnitDestroyed(id,def,team)
 local t=teams[team]
 if t and (UnitDefs[def].customParams or {}).prototype40k then log("40K CASUALTY",team,UnitDefs[def].name,id) end
end
function gadget:GameFrame(f)
 if f%90~=0 then return end
 for _,team in ipairs(teamOrder) do
  local t=teams[team]
  scan(team,t)
  maintainEconomy(team,t,f)
  if t.faction then progressSource(team,t,f);production(team,t,f) end
  if t.base then squadAI.Repair(team,t.constructors)end
  local waitingBodies=squadAI.Collect(team,t,function(id,slot)if t.base then stageUnit(team,t,id,slot)end end)
  if f>=GRACE and f-t.lastWave>=WAVE_INTERVAL and waitingBodies>=6 then
   local wave,count=squadAI.Wave(team,t,24)
   for _,id in ipairs(wave)do
    Spring.GiveOrderToUnit(id,CMD.MOVE_STATE,{1},{})
    Spring.GiveOrderToUnit(id,CMD.FIGHT,rally,{})
    if paidPressure then paidPressure.Release(team,id,rally,f) end
   end
   t.wave,t.lastWave=t.wave+1,f
   log("40K WAVE",team,t.wave,count,f)
  end
  if paidPressure and f>=GRACE then paidPressure.Frame(team,f) end
  if f%(30*Game.gameSpeed)==0 then
   local metal,_,_,mi,me=Spring.GetTeamResources(team,"metal")
   local energy,_,_,ei,ee=Spring.GetTeamResources(team,"energy")
   log("40K AI ECONOMY",team,f,t.counts.mex,t.counts.solar,#t.factories,
    metal,mi,me,energy,ei,ee,"waiting",#t.waiting)
  end
 end
end

-- Native callin only: do not manufacture a winner, kill a team or auto-end.
function gadget:GameOver(winningAllyTeams)
 if not paidPressure then return end
 local winners={};for _,ally in ipairs(winningAllyTeams or{})do winners[#winners+1]=ally end;table.sort(winners)
 log('40K PAID MATCH GAMEOVER','winning_allyteams',table.concat(winners,','),'frame',Spring.GetGameFrame(),'native_callin',true)
end
