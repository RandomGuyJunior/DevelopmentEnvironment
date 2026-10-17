function gadget:GetInfo()return {name='40K four source walkers native review',desc='Isolated ordinary native movement; no pose/velocity controls',author='Local project',layer=108,enabled=true}end
if not gadgetHandler:IsSyncedCode() or Spring.GetModOptions().prototype_diagnostic~='walkreview' then return end
local names={'imp_guardsman','imp_marine','ork_boy','imp_kasrkin'};local actors={};local moved=false
local function lane()
 for z=700,Game.mapSizeZ-700,96 do for x=700,Game.mapSizeX-700,96 do
  local y=Spring.GetGroundHeight(x,z);local valid=y>20
  for n,name in ipairs(names)do local ud=UnitDefNames[name];if not ud then Spring.Echo('40K WALK FIXTURE','UNKNOWN','missing_native_definition',name);return end
   for d=0,400,40 do local px,pz=x+(n-1)*48,z+d;local py=Spring.GetGroundHeight(px,pz)
    if math.abs(py-y)>2 or not Spring.TestMoveOrder(ud.id,px,py,pz,0,0,0,true,true,false)then valid=false end
   end
  end
  if valid and #Spring.GetFeaturesInRectangle(x-50,z-50,x+220,z+450)==0 then return x,y,z end
 end end
end
function gadget:GameFrame(f)
 if f==90 then
  local x,y,z=lane();if not x then Spring.Echo('40K WALK FIXTURE','UNKNOWN','no_native_clear_four_actor_lane');return end
  for n,name in ipairs(names)do local px=x+(n-1)*48;local id=Spring.CreateUnit(name,px,Spring.GetGroundHeight(px,z),z,0,0)
   if not id then Spring.Echo('40K WALK FIXTURE','UNKNOWN','native_create_failed',name);return end
   actors[n]={id=id,x=px,z=z};Spring.GiveOrderToUnit(id,CMD.FIRE_STATE,{0},{});Spring.GiveOrderToUnit(id,CMD.MOVE_STATE,{0},{})
   Spring.SetGameRulesParam('40k_walk_review_actor_'..n,id,{public=true});Spring.Echo('40K WALK FIXTURE','CREATED',name,id,px,y,z)
  end
 end
 if f==150 and #actors==4 then for _,a in ipairs(actors)do Spring.GiveOrderToUnit(a.id,CMD.MOVE,{a.x,Spring.GetGroundHeight(a.x,a.z+380),a.z+380},{})end;moved=true end
 if moved and f==540 then
  for n,a in ipairs(actors)do local x,y,z=Spring.GetUnitPosition(a.id);local distance=math.sqrt((x-a.x)^2+(z-a.z)^2)
   Spring.Echo('40K WALK FIXTURE',distance>80 and 'NATIVE_MOVED_PASS' or 'UNKNOWN',names[n],a.id,distance);Spring.GiveOrderToUnit(a.id,CMD.STOP,{},{})
  end
  Spring.Echo('40K WALK FIXTURE','COMPLETE','source sampler acceptance requires separate paired phase/matrix reporter')
 end
end
