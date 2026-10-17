function gadget:GetInfo()return{name='40K read-only resourcing accessor witness',desc='Explicit native accessor review only',author='Local project',layer=108,enabled=true}end
if not gadgetHandler:IsSyncedCode()then return end
local o=Spring.GetModOptions()
if tostring(o.prototype_native_resourcing_witness)~='1'then return end
assert(o.prototype_diagnostic=='roster'and tostring(o.prototype_ork_primary_visual_review)=='1','Isolated genuine visual actors required')
local finished=false
local firstSeen={}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
function gadget:GameFrame(frame)
 if finished or frame%30~=0 then return end
 assert(type(Spring.GetUnitResourcing)=='function','Reviewed native accessor missing')
 for _,id in ipairs(Spring.GetAllUnits())do
  local d=UnitDefs[Spring.GetUnitDefID(id)];local cp=d and d.customParams or{}
  if cp.animsource=='ork_bigger_generator'and cp.source_entity=='attrib/ebps/races/orks/structures/ork_bigger_generator.lua'then
   local hp,maximum,_,_,progress=Spring.GetUnitHealth(id)
   if hp and hp>0 and progress==1 then
    if not firstSeen[id]then firstSeen[id]=frame;return end
    if frame-firstSeen[id]<60 then return end
    finished=true -- A failed diagnostic must not flood every following frame.
    local values={};for _,key in ipairs({'umm','ume','uum','uue','cmm','cme','cum','cue'})do
     local count=select('#',Spring.GetUnitResourcing(id,key));local v=Spring.GetUnitResourcing(id,key)
     assert(count==1 and finite(v),'Missing/nonfinite actual native resource field: '..key);values[key]=v
    end
    assert(d.energyMake==90 and values.ume==0 and values.cme==0,'Immutable generator output and mutable adjustment packs differ from source baseline')
    local _,_,production=Spring.GetUnitResources(id)
    Spring.Echo('40K NATIVE RESOURCING WITNESS','READ',id,frame,'ume',values.ume,'cme',values.cme,'definition_energy',d.energyMake,'actual_energy_production',production)
    assert(finite(production)and math.abs(production-90)<.001,'Actual native generator production is not90/sec')
    assert(select('#',Spring.GetUnitResourcing(id,'bad'))==0,'Unknown key fabricated a value')
    assert(select('#',Spring.GetUnitResourcing(id,'ume'..string.char(0)))==0,'Embedded-null key accepted')
    assert(select('#',Spring.GetUnitResourcing(2147483647,'ume'))==0,'Unknown unit fabricated a value')
    Spring.Echo('40K NATIVE RESOURCING WITNESS','PASS',id,frame,'ume',values.ume,'cme',values.cme,'definition_energy',d.energyMake,'actual_energy_production',production,'eight_actual_fields',true,'read_only',true,'hp',hp,maximum)
    finished=true;return
   end
  end
 end
end
