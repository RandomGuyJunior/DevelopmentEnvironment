function gadget:GetInfo()
 return {name="40K native production proof",desc="Opt-in two-factory human production and roster audit",author="Local project",layer=102,enabled=true}
end
if not gadgetHandler:IsSyncedCode() then return end
if Spring.GetModOptions().prototype_diagnostic~="production" then return end
local prefix,commander,base
local factories,queued,births,finished,produced,mexLocations={}, {}, {}, {}, {}, {}
local task=1
local awaiting=false
local issued=0
local result="pending"
local tasks={"mex","mex","solar","solar","lab","solar","solar","vp"}
local roster={arm={"imp_guardsman","imp_marine","imp_russ"},cor={"ork_boy","ork_meganob","ork_killa_kan"}}
local expected={
 armlab={"armck","imp_guardsman","imp_marine"},armalab={"armack","imp_guardsman","imp_marine"},
 armvp={"armcv","imp_russ"},armavp={"armacv","imp_russ"},
 corlab={"corck","ork_boy","ork_meganob"},coralab={"corack","ork_boy","ork_meganob"},
 corvp={"corcv","ork_killa_kan"},coravp={"coracv","ork_killa_kan"},
}
local permitted={imp_guardsman=true,imp_marine=true,imp_russ=true,ork_boy=true,ork_meganob=true,ork_killa_kan=true}
local function log(...) Spring.Echo("40K PRODUCTION",...) end
local function fail(reason)
 if result~="pending" then return end
 result="failed";Spring.SetGameRulesParam("40k_production_result",-1);log("FAIL",reason,Spring.GetGameFrame())
end
local function hasOption(defID,name)
 for _,id in ipairs(UnitDefs[defID].buildOptions or {}) do if UnitDefs[id].name==name then return true end end
 return false
end
local function audit()
 local violations=0
 for _,ud in pairs(UnitDefs) do
  local p=ud.name:sub(1,3)
  if p=="arm" or p=="cor" then
   for _,id in ipairs(ud.buildOptions or {}) do
    local target=UnitDefs[id]
    if target and not permitted[target.name] and not target.isBuilder and
     (target.canMove or #(target.weapons or {})>0) then
     violations=violations+1;log("FORBIDDEN_BUILD_OPTION",ud.name,target.name)
    end
   end
  end
 end
 for name,options in pairs(expected) do
  local def=UnitDefNames[name]
  if not def then violations=violations+1;log("FACTORY_MISSING",name)
  else
   local actual=UnitDefs[def.id].buildOptions or {}
   if #actual~=#options then violations=violations+1;log("FACTORY_ROSTER_SIZE",name,#actual,#options) end
   for _,n in ipairs(options) do if not hasOption(def.id,n) then violations=violations+1;log("FACTORY_ROSTER_MISSING",name,n) end end
  end
 end
 for _,p in ipairs({"arm","cor"}) do
  for _,builder in ipairs({p.."com",p.."ck",p.."cv"}) do
   local def=UnitDefNames[builder]
   for _,kind in ipairs({"lab","vp"}) do
    if not def or not hasOption(def.id,p..kind) then violations=violations+1;log("CONSTRUCTOR_FACTORY_MISSING",builder,p..kind) end
   end
  end
 end
 local leg=UnitDefNames.leglab
 if leg then
  local native={"legck","legrezbot","leggob","leglob","legcen","legbal","legkark","legaabot"}
  if #(UnitDefs[leg.id].buildOptions or {})~=#native then violations=violations+1 end
  for _,n in ipairs(native) do if not hasOption(leg.id,n) then violations=violations+1;log("LEGION_ROSTER_CHANGED",n) end end
 else log("LEGION_NOT_LOADED","prefix-only wrapper remains unchanged") end
 log("ROSTER_AUDIT","two factory roles",violations,"violations")
 return violations==0
end
local function site(def,x,z,ringLimit)
 for ring=0,ringLimit or 24 do
  for i=0,15 do
   local a=i*math.pi/8
   local xx=math.floor((x+ring*32*math.cos(a))/16)*16+8
   local zz=math.floor((z+ring*32*math.sin(a))/16)*16+8
   local apron=true
   for _,factory in pairs(factories) do
    local fx,_,fz=Spring.GetUnitPosition(factory)
    if fx and math.abs(xx-fx)<180 and zz>fz-64 and zz<fz+320 then apron=false end
   end
   if xx>64 and zz>64 and xx<Game.mapSizeX-64 and zz<Game.mapSizeZ-64 then
    local y=Spring.GetGroundHeight(xx,zz)
    if y>=5 and apron and Spring.TestBuildOrder(def,xx,y,zz,0)==2 then return {xx,y,zz,0} end
   end
  end
 end
end
local function mexSite(def)
 local candidates={}
 for x=math.max(64,base[1]-800),math.min(Game.mapSizeX-64,base[1]+800),16 do
  for z=math.max(64,base[3]-800),math.min(Game.mapSizeZ-64,base[3]+800),16 do
   if (select(3,Spring.GetGroundInfo(x,z)) or 0)>0 then candidates[#candidates+1]={x,z,(x-base[1])^2+(z-base[3])^2} end
  end
 end
 table.sort(candidates,function(a,b)if a[3]~=b[3] then return a[3]<b[3] end;if a[1]~=b[1] then return a[1]<b[1] end;return a[2]<b[2] end)
 for _,candidate in ipairs(candidates) do
  local separated=true
  for _,p in ipairs(mexLocations) do if (candidate[1]-p[1])^2+(candidate[2]-p[2])^2<96^2 then separated=false end end
  if separated then
   local p=site(def,candidate[1],candidate[2],0)
   if p and (select(3,Spring.GetGroundInfo(p[1],p[3])) or 0)>0 then mexLocations[#mexLocations+1]={p[1],p[3]};return p end
  end
 end
end
local function buildNext()
 local kind=tasks[task]
 if not kind then return end
 local name=prefix..kind
 local def=UnitDefNames[name]
 if not def or not hasOption(Spring.GetUnitDefID(commander),name) then fail("commander_cannot_build_"..name);return end
 local p
 if kind=="mex" then p=mexSite(def.id)
 elseif kind=="lab" then p=site(def.id,base[1]+192,base[3]-192)
 elseif kind=="vp" then p=site(def.id,base[1]-256,base[3]-256)
 else p=site(def.id,base[1]-160,base[3]+96) end
 if not p then fail("no_clear_build_site_"..name);return end
 awaiting=true;issued=Spring.GetGameFrame()
 Spring.GiveOrderToUnit(commander,-def.id,p,{})
 log("NATIVE_BUILD_ORDER",commander,name,p[1],p[3],issued)
end
local function queue(kind,id)
 if queued[kind] then return end
 queued[kind]=true
 for _,name in ipairs(expected[prefix..kind]) do
  local def=UnitDefNames[name]
  if not def or not hasOption(Spring.GetUnitDefID(id),name) then fail("wrong_factory_"..kind.."_"..name);return end
  local desc=Spring.FindUnitCmdDesc(id,-def.id)
  if not desc then fail("factory_build_command_missing_"..name);return end
  Spring.GiveOrderToUnit(id,-def.id,{},{})
  log("NATIVE_FACTORY_QUEUE",id,prefix..kind,name,desc)
 end
end
function gadget:Initialize() if not audit() then fail("build_roster_audit") end end
function gadget:UnitCreated(id,def,team,builder)
 if team==0 then births[id]={builder=builder};log("CREATED",UnitDefs[def].name,id,"builder",builder or "initial") end
end
function gadget:UnitFinished(id,def,team)
 if team~=0 or not prefix then return end
 local name=UnitDefs[def].name
 local birth=births[id]
 if not birth or not birth.builder then return end
 log("FINISHED",name,id,"builder",birth.builder,Spring.GetGameFrame())
 if birth.builder==commander then
  if name==prefix.."lab" then factories.lab=id;queue("lab",id) end
  if name==prefix.."vp" then factories.vp=id;queue("vp",id) end
  if awaiting and name==prefix..tasks[task] then
   finished[name]=true;awaiting=false;task=task+1
  end
 else
  local kind=birth.builder==factories.lab and "lab" or birth.builder==factories.vp and "vp"
  if kind then
   local allowed=false;for _,n in ipairs(expected[prefix..kind]) do if name==n then allowed=true end end
   if not allowed then fail("unexpected_product_"..kind.."_"..name);return end
   finished[name]=true
   if permitted[name] then produced[#produced+1]=id end
   local x,_,z=Spring.GetUnitPosition(birth.builder)
   local sx=math.min(Game.mapSizeX-96,x+240+(#produced%4)*24)
   local sz=math.min(Game.mapSizeZ-96,z+240)
   Spring.GiveOrderToUnit(id,CMD.MOVE,{sx,Spring.GetGroundHeight(sx,sz),sz},{})
   log("FACTORY_PROVENANCE",kind,name,id,birth.builder)
  end
 end
end
function gadget:UnitDestroyed(id)
 if id==commander then fail("commander_destroyed") end
 if id==factories.lab or id==factories.vp then fail("required_factory_destroyed") end
end
function gadget:GameFrame(f)
 if result~="pending" or f%30~=0 then return end
 if f>1800*Game.gameSpeed then fail("production_timeout_30_minutes");return end
 if not commander then
  local units=Spring.GetTeamUnits(0) or {};table.sort(units)
  for _,id in ipairs(units) do
   local name=UnitDefs[Spring.GetUnitDefID(id)].name
   if name=="armcom" or name=="corcom" then
    commander=id;prefix=name:sub(1,3)
    local x,y,z=Spring.GetUnitPosition(id);base={x,y,z}
    log("HUMAN_FACTION",0,prefix,id,x,z);break
   end
  end
  if not commander then if f>900 then fail("normal_team0_commander_missing") end;return end
 end
 if awaiting then if f-issued>600*Game.gameSpeed then fail("native_construction_stalled") end;return end
 if tasks[task] then buildNext();return end
 local complete=factories.lab and factories.vp and finished[prefix.."ck"] and finished[prefix.."cv"]
 for _,name in ipairs(roster[prefix]) do complete=complete and finished[name] end
 if complete then
  result="passed";Spring.SetGameRulesParam("40k_production_result",1)
  log("PASS",prefix,"native_barracks_heavy_factory_both_builders_two_mex_four_solars_three_combat_types",f)
  local cx,cz=Game.mapSizeX/2,Game.mapSizeZ/2
  local rally
  for ring=0,30 do
   for i=0,15 do
    local a=i*math.pi/8;local x,z=cx+ring*32*math.cos(a),cz+ring*32*math.sin(a)
    local y=Spring.GetGroundHeight(x,z)
    if not rally and y>=5 and math.abs(y-Spring.GetGroundHeight(x+32,z))<=12 and math.abs(y-Spring.GetGroundHeight(x,z+32))<=12 then rally={x,y,z} end
   end
  end
  if rally then
   for _,id in ipairs(produced) do Spring.GiveOrderToUnit(id,CMD.FIGHT,rally,{}) end
   log("HUMAN_FORCE_CENTRE",#produced,rally[1],rally[3],f)
  end
 end
end
