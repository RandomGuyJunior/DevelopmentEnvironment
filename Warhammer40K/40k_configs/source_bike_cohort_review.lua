-- Read-only native receipt audit and measured ordinary order destinations.
-- No production/resource/health grants and no acceptance marker writing.
local M={Version=1}
local function near(a,b)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=.001 end
function M.New(Spring,UnitDefs,Game,F,commander,base,factories,mexes,controller)
 local H={};local key='imp_source_hq_addon_1';local fps=Game.gameSpeed
 local function native()local C=controller();return C,C and C.sourceMarineLifecycle end
 local function live(id,def,team,complete)
  local hp,_,_,_,built=Spring.GetUnitHealth(id)
  return hp and hp>0 and Spring.GetUnitTeam(id)==team and Spring.GetUnitDefID(id)==def and(not complete or built and built>=1)
 end
 local function costs(id,m,e,t)local bt,metal,energy=Spring.GetUnitCosts(id);return bt==t*fps and metal==m and energy==e end
 local function head(id,cmd,tag)local row=(Spring.GetUnitCommands(id,-1)or{})[1];return row and row.id==cmd and(tag==nil or row.tag==tag)and row end
 function H.CapRefusal(producer,team,def,issued)
  local C,B=native();local r=B and B.creationRefusals and B.creationRefusals[producer]
  local P=B and B.population;local u=C and C.units[producer]
  if not r or not u or not u.finished or u.team~=team or not live(producer,u.def,team,true)
   or r.reason~='source_capacity'or r.policy~='stock_drop_order'or r.builder~=producer or r.team~=team or r.def~=def
   or r.head~=-def or type(r.tag)~='number'or r.tag<=0 or r.tag~=math.floor(r.tag)or r.tag>16777216
   or r.frame<issued or r.frame>Spring.GetGameFrame()or r.infantry~=5 or r.support~=1 or r.capInfantry~=10 or r.capSupport~=1
   or r.requestedInfantry~=2 or r.requestedSupport~=1 or r.squad~=F.bike.source_squad or r.sha256~=F.source_hashes.bike_squad.sha256
   or not(r.infantry+r.requestedInfantry>r.capInfantry or r.support+r.requestedSupport>r.capSupport)
   or Spring.GetUnitIsBuilding(producer)or P.reservations[producer]then return nil,'actual_source_capacity_refusal_missing'end
  local i,s=P.Usage(team);local ci,cs=P.Capacity(team)
  if i~=r.infantry or s~=r.support or ci~=r.capInfantry or cs~=r.capSupport then return nil,'actual_source_capacity_changed'end
  return r
 end
 function H.InitialBirth(id,def,team,builder)
  local C,B=native();local P=B and B.population;local seed=P and P.member[id];local c=seed and P.cohorts[seed]
  local _,_,_,_,built=Spring.GetUnitHealth(id);local row=(Spring.GetFactoryCommands(builder,-1)or{})[1]
  if not C or not B or B.failed or not c or c.def~=def or c.team~=team or c.builder~=builder or c.complete or c.captured
   or not built or built>=1 or not row or row.id~=-def or row.tag~=c.tag or not live(id,def,team,false)then return nil,'initial_factory_population_witness' end
  local d=UnitDefs[def];local bt,m,e=Spring.GetUnitCosts(id);if not d or bt~=d.buildTime or m~=d.metalCost or e~=d.energyCost then return nil,'initial_actual_price' end
  if d.name=='imp_tactical_bike'then
   local A=B.bike;local r=A and A.initial[id]
   if not r or r.team~=team or r.def~=def or r.builder~=builder or not costs(id,170,30,30)then return nil,'bike_initial_native_witness' end
  end
  return{unit=id,def=def,team=team,builder=builder,seed=seed,tag=row.tag,frame=Spring.GetGameFrame(),work=d.buildTime,metal=d.metalCost,energy=d.energyCost}
 end
 function H.Factory(receipt)
  local C,B=native();local P=B and B.population;local c=P and P.cohorts[receipt.seed]
  if not C or not B or B.failed or not c or not c.complete or c.captured or P.member[receipt.unit]~=receipt.seed
   or c.team~=receipt.team or c.builder~=receipt.builder or c.tag~=receipt.tag or Spring.GetUnitIsBuilding(receipt.builder)~=receipt.unit
   or not live(receipt.unit,receipt.def,receipt.team,true)then return false,'native_factory_completion' end
  local bt,m,e=Spring.GetUnitCosts(receipt.unit);if bt~=receipt.work or m~=receipt.metal or e~=receipt.energy then return false,'actual_completed_price' end
  if UnitDefs[receipt.def].name=='imp_tactical_bike'then
   local R=B.bike.controller;local seed=R.member[receipt.unit];local cohort=seed and R.cohorts[seed]
   if not cohort or cohort.leader~=receipt.unit or cohort.team~=receipt.team then return false,'bike_cohort_founding' end
   receipt.bikeSeed=seed
  end
  receipt.completed=Spring.GetGameFrame();return true
 end
 function H.AddonSample(id,team,state)
  local C,B=native();local j=C and C.sourceVariantAddonJobs and(C.sourceVariantAddonJobs.jobs[id]or{})[key]
  if not j then return true end
  if not j.active then return true end
  if not B or B.failed or j.team~=team or j.def~=Spring.GetUnitDefID(id)or j.frames~=90*fps or j.cost.metal~=400 or j.cost.energy~=130
   or not head(id,j.cmd,j.tag)or j.steps<state.steps or not near(j.metal,400*j.steps/j.frames)or not near(j.energy,130*j.steps/j.frames)
   or state.tag and state.tag~=j.tag then return false,'actual_hq_paid_job' end
  state.steps=j.steps;state.tag=j.tag;state.cmd=j.cmd;return true
 end
 function H.AddonComplete(id,team,state,barracks)
  local C,B=native();local A=B and B.bike;local r=A and A.grants[id]
  if not C or not B or B.failed or not r or not C.sourceVariantAdapter.LocalAddon(id,team,key)or not A.Enabled(team)
   or not C.sourceVariantModifiers.IsApplied(team,key,id)or not A.HasEnableReceipt(team,key,id)then return false,'whole_hq_effect_receipt' end
  if not state.tag or r.tag~=state.tag or state.steps<90*fps-1 or r.metal~=400 or r.energy~=130 or r.frames~=90*fps
   or r.team~=team or r.def~=Spring.GetUnitDefID(id)then return false,'actual_hq_full_payment' end
  local _,max=Spring.GetUnitHealth(id);local _,otherMax=Spring.GetUnitHealth(barracks)
  if not near(max,state.max+500)or not near(otherMax,state.barracksMax)or Spring.GetUnitExperience(id)~=state.experience then return false,'local_hq_health_or_experience_confounder' end
  return true
 end
 function H.ReinforcementBirth(id,def,team,builder,expected)
  local C,B=native();local A=B and B.bike;local R=A and A.controller;local seed=R and R.member[builder];local c=seed and R.cohorts[seed];local j=seed and R.jobs[seed]
  local p=A and A.births[id];local P=B and B.population;local budget=P and P.member[builder]
  local bt,m,e=Spring.GetUnitCosts(id);local hp,_,_,_,built=Spring.GetUnitHealth(id)
  local checks={
   {'controller',C~=nil},{'native_lifecycle',B~=nil},{'native_lifecycle_unfailed',B and not B.failed},
   {'cohort',c~=nil},{'owned_leader',c and c.leader==builder and c.team==team},{'expected_cohort',c and c.seed==expected.seed},
   {'paid_job',j and j.paid==1},{'full_duration',j and j.steps==10*fps},{'full_metal',j and j.metal==80},{'full_energy',j and j.energy==40},
   {'native_owned_head',j and B and head(builder,B.command,j.tag)~=nil},{'expected_tag',j and(not expected.tag or expected.tag==j.tag)},
   {'native_birth_receipt',p and p.team==team and p.def==def and p.builder==builder},
   {'native_costs',bt==10*fps and m==80 and e==40},{'native_non_being_built_owner',live(id,def,team,false)and Spring.GetUnitIsBeingBuilt and Spring.GetUnitIsBeingBuilt(id)==false},
   {'population_member',P and budget and P.member[id]==budget},{'population_budget_member',P and P.cohorts[budget]and P.cohorts[budget].members[id]~=nil},
  }
  local refused={};for _,check in ipairs(checks)do if not check[2]then refused[#refused+1]=check[1]end end
  if #refused>0 then return nil,'actual_paid_reinforcement_birth_'..table.concat(refused,','),
   {buildProgress=built,health=hp,work=bt,metal=m,energy=e,lifecycleFailure=B and B.birthFailures and B.birthFailures[id],
    populationMember=P and P.member[id],budget=budget,paid=j and j.paid,steps=j and j.steps,receipt=p~=nil}end
  local nativeStamp=tonumber(F.source_hashes.marine_addon.sha256:sub(1,6),16)
  if Spring.GetUnitRulesParam(id,'40k_bike_native_paid_birth')~=nativeStamp or Spring.GetUnitRulesParam(id,'40k_bike_native_birth_team')~=team then return nil,'native_birth_receipt' end
  return{unit=id,def=def,team=team,builder=builder,seed=seed,budget=budget,tag=j.tag,frame=Spring.GetGameFrame(),metal=j.metal,energy=j.energy,steps=j.steps}
 end
 function H.ReinforcementSample(id,team,state)
  local C,B=native();local R=B and B.bike.controller;local j=R and R.jobs[state.seed]
  if not j then return true end
  if not head(id,B.command,j.tag)then return true end
  if B.failed or j.steps<state.steps or j.steps>10*fps or not near(j.metal,80*j.steps/(10*fps))or not near(j.energy,40*j.steps/(10*fps))or state.tag and state.tag~=j.tag then return false,'reinforcement_paid_progress' end
  state.steps=j.steps;state.tag=j.tag;return true
 end
 function H.ReinforcementComplete(receipt,count)
  local C,B=native();local R=B and B.bike.controller;local c=R and R.cohorts[receipt.seed];local P=B and B.population
  if not c or B.failed or R.jobs[receipt.seed]or R.member[receipt.unit]~=receipt.seed or P.member[receipt.unit]~=receipt.budget
   or c.team~=receipt.team or c.leader~=receipt.builder or not costs(receipt.unit,80,40,10)then return false,'completed_cohort_membership' end
  local n=0;for id in pairs(c.members)do n=n+1;if not live(id,receipt.def,receipt.team,true)or P.member[id]~=receipt.budget then return false,'owned_same_budget_members' end end
  if n~=count then return false,'actual_member_count' end
  local budget=P.cohorts[receipt.budget];if not budget or budget.captured or budget.team~=receipt.team then return false,'owned_budget_receipt' end
  local i,s=P.Usage(receipt.team);if i~=5 or s~=1 then return false,'source_budget_changed' end
  return true
 end
local function halfFootprint(ud,facing)
 local x=(ud.xsize or (ud.footprintx or 1)*2)*4
 local z=(ud.zsize or (ud.footprintz or 1)*2)*4
 if facing and facing%2==1 then return z,x end
 return x,z
end
local function unitHalf(id,ud,facing)
 local x,z=halfFootprint(ud,facing)
 if Spring.GetUnitCollisionVolumeData then
  local sx,_,sz,ox,_,oz=Spring.GetUnitCollisionVolumeData(id)
  if type(sx)=='number' and type(sz)=='number' then
   local cx,cz=math.abs(sx)/2+math.abs(ox or 0),math.abs(sz)/2+math.abs(oz or 0)
   if facing and facing%2==1 then cx,cz=cz,cx end
   x,z=math.max(x,cx),math.max(z,cz)
  end
 end
 return x,z
end
local function nearby(x,z)
 if Spring.GetUnitsInRectangle then return Spring.GetUnitsInRectangle(x-1024,z-1024,x+1024,z+1024) or {} end
 if Spring.GetAllUnits then return Spring.GetAllUnits() or {} end
 return Spring.GetTeamUnits(0) or {}
end
local function structureClear(def,x,z)
 local hx,hz=halfFootprint(UnitDefs[def],0)
 local builderDef=UnitDefs[Spring.GetUnitDefID(commander)]
 local bx,bz=unitHalf(commander,builderDef,0);local margin=math.max(32,bx+16,bz+16)
 for _,id in ipairs(nearby(x,z))do
  if id~=commander then
   local ud=UnitDefs[Spring.GetUnitDefID(id)]
   if ud and not ud.canFly and not ud.canfly and (ud.speed or 0)==0 then
    local ux,_,uz=Spring.GetUnitPosition(id)
    local facing=Spring.GetUnitBuildFacing and Spring.GetUnitBuildFacing(id) or 0
    local sx,sz=unitHalf(id,ud,facing)
    if ux and math.abs(x-ux)<hx+sx+margin and math.abs(z-uz)<hz+sz+margin then return false,'structure_builder_clearance_'..id end
   end
  end
 end
 return true
end
local function stance(def,pos)
 if not Spring.TestMoveOrder then return nil,'native_move_test_unavailable' end
 local builderDefID=Spring.GetUnitDefID(commander);local ud=UnitDefs[builderDefID]
 local range=ud.buildDistance or ud.builddistance or 128
 local radius=math.max(1,range-32);local hx,hz=halfFootprint(UnitDefs[def],0)
 local bx,bz=unitHalf(commander,ud,0);local cx,cy,cz=Spring.GetUnitPosition(commander)
 local candidates={}
 for i=0,15 do
  local angle=i*math.pi/8;local x=pos[1]+radius*math.cos(angle);local z=pos[3]+radius*math.sin(angle)
  local y=Spring.GetGroundHeight(x,z)
  local outside=math.abs(x-pos[1])>=hx+bx+8 or math.abs(z-pos[3])>=hz+bz+8
  local inrange=(x-pos[1])^2+(y-pos[2])^2+(z-pos[3])^2<=(range-8)^2
  if outside and inrange and x>32 and z>32 and x<Game.mapSizeX-32 and z<Game.mapSizeZ-32
   and Spring.TestMoveOrder(builderDefID,x,y,z,0,0,0,true,true,false) then
   candidates[#candidates+1]={x,y,z,distance=(x-cx)^2+(z-cz)^2}
  end
 end
 table.sort(candidates,function(a,b)return a.distance<b.distance end)
 if candidates[1] then return candidates[1] end
 return nil,'no_native_passable_build_range_stance'
end
local function site(def,x,z,maxring,angles)
 local rejected='no_dry_clear_site';local visited={};angles=angles or 16
 local stats={candidates=0,duplicates=0,bounds=0,egress=0,water=0,native0=0,native1=0,native2=0,nativeOther=0,features=0,structures=0,stances=0,minHeight=math.huge,maxHeight=-math.huge}
 for ring=0,maxring or 16 do
  for i=0,angles-1 do
   local a=i*2*math.pi/angles
   local xx,yy,zz=Spring.Pos2BuildPos(def,x+32*ring*math.cos(a),Spring.GetGroundHeight(x,z),z+32*ring*math.sin(a),0)
   local key=xx..':'..zz
   if visited[key] then stats.duplicates=stats.duplicates+1
   else
    visited[key]=true;stats.candidates=stats.candidates+1
    stats.minHeight=math.min(stats.minHeight,yy);stats.maxHeight=math.max(stats.maxHeight,yy)
    local clear=xx>64 and zz>64 and xx<Game.mapSizeX-64 and zz<Game.mapSizeZ-64
    if not clear then stats.bounds=stats.bounds+1;rejected='map_bounds' end
    if clear then
     for _,f in pairs(factories)do local fx,_,fz=Spring.GetUnitPosition(f);if fx and math.abs(xx-fx)<200 and zz>fz-80 and zz<fz+320 then clear=false;rejected='factory_egress_corridor' end end
     if not clear then stats.egress=stats.egress+1 end
    end
    if clear then
     local status,feature=Spring.TestBuildOrder(def,xx,yy,zz,0)
     local field=status==0 and 'native0' or status==1 and 'native1' or status==2 and 'native2' or 'nativeOther';stats[field]=stats[field]+1
     if feature then stats.features=stats.features+1 end
     if yy<0 then stats.water=stats.water+1;rejected='underwater_site'
     elseif status==2 and not feature then
      local reserved,reason=structureClear(def,xx,zz)
      if reserved then
       local pos={xx,yy,zz,0};local approach,why=stance(def,pos)
       if approach then return pos,approach,nil,stats end
       stats.stances=stats.stances+1;rejected=why
      else stats.structures=stats.structures+1;rejected=reason end
     elseif feature then rejected='reclaimable_feature_'..feature
     else rejected='native_footprint_blocked_'..tostring(status) end
    end
   end
  end
 end
 return nil,nil,rejected,stats
end

local function findMetal(def)
 local candidates={}
 for x=math.max(64,base[1]-1200),math.min(Game.mapSizeX-64,base[1]+1200),16 do
  for z=math.max(64,base[3]-1200),math.min(Game.mapSizeZ-64,base[3]+1200),16 do
   if (select(3,Spring.GetGroundInfo(x,z))or 0)>0 then candidates[#candidates+1]={x,z,(x-base[1])^2+(z-base[3])^2}end
  end
 end
 table.sort(candidates,function(a,b)if a[3]~=b[3]then return a[3]<b[3]end;if a[1]~=b[1]then return a[1]<b[1]end;return a[2]<b[2]end)
 for _,p in ipairs(candidates)do
  local separate=true;for _,m in ipairs(mexes)do if (p[1]-m[1])^2+(p[2]-m[2])^2<128^2 then separate=false end end
  if separate then local pos,approach=site(def,p[1],p[2],0);if pos then mexes[#mexes+1]={pos[1],pos[3]};return pos,approach end end
 end
end

 H.Site=site;H.Metal=findMetal
 function H.MoveSite(id,ordinal)
  local x,_,z=Spring.GetUnitPosition(id);local def=Spring.GetUnitDefID(id)
  for ring=0,3 do for i=0,23 do local angle=(i+ordinal)*math.pi/12;local radius=440+ring*80;local xx=x+radius*math.cos(angle);local zz=z+radius*math.sin(angle);local yy=Spring.GetGroundHeight(xx,zz)
   if xx>96 and zz>96 and xx<Game.mapSizeX-96 and zz<Game.mapSizeZ-96 and yy>=0 and Spring.TestMoveOrder(def,xx,yy,zz,0,0,0,true,true,false)then return{xx,yy,zz}end
  end end;return nil
 end
 return H
end
return M
