function gadget:GetInfo()return{name='Owned stock transport reference observer',desc='Read-only sequential native callbacks/ground pose; never whole-squad or economy acceptance',author='Local project',layer=153,enabled=true}end
if not gadgetHandler:IsSyncedCode()then return false end
local o=Spring.GetModOptions()or{}
if tostring(o.prototype_stock_transport_reference)~='1'then return false end
local M=VFS.Include('40k_configs/stock_transport_reference.lua')
local observer;local finished={};local delivered={};local start;local done=false
local function emit(event,...)local t={...};for i=1,#t do t[i]=tostring(t[i])end;Spring.Echo('40K '..event..' '..table.concat(t,' '))end
local function finish(why)if done then return end;done=true;emit('STOCK_TRANSPORT_COMPLETE',why,'funded_physical_reference=true economy_acceptance=false whole8_capacity_acceptance=false mesh_contact_acceptance=false')end
function gadget:UnitFinished(id)finished[id]=true end
function gadget:UnitFromFactory(id,def,team,producer)
 local d=UnitDefs[def];local pd=UnitDefs[Spring.GetUnitDefID(producer)]
 if not d or not pd or(d.name~='corhvytrans'and d.name~='corak')then return end
 local target=d.name=='corhvytrans'and'corap'or'corlab'
 if pd.name~=target then finish('REFUSED stock_reference_nonstock_factory_product');return end
 local reachable=false;for _,v in ipairs(pd.buildOptions or{})do if v==def then reachable=true end end
 if not reachable then finish('REFUSED actual_stock_menu_missing_product');return end
 if delivered[id]then finish('REFUSED duplicate_stock_delivery_callback');return end
 delivered[id]={def=def,team=team,producer=producer}
 emit('STOCK_TRANSPORT_NATIVE_PRODUCT','id='..id,'def='..d.name,'producer='..producer,'factory='..pd.name,'funded_costs_not_economy_acceptance=true')
end
function gadget:UnitLoaded(...)if observer then observer.Loaded(...)end end
function gadget:UnitUnloaded(...)if observer then observer.Unloaded(...)end end
function gadget:GameFrame(frame)
 if done then return end;start=start or frame
 if frame-start>1800*Game.gameSpeed then finish('INCONCLUSIVE owned_stock_reference_timeout');return end
 if observer then local result=observer.Step(frame);if result then finish(result)end;return end
 if frame%30~=0 then return end
 local carriers,bodies={},{};local team
 for id,r in pairs(delivered)do if finished[id]and not Spring.GetUnitIsDead(id)then
  local d=UnitDefs[r.def]
  if d.name=='corhvytrans'then carriers[#carriers+1]=id elseif d.name=='corak'then bodies[#bodies+1]=id end
  if team and team~=r.team then finish('REFUSED stock_reference_mixed_product_teams');return end;team=r.team
 end end
 if #carriers>1 or #bodies>8 then finish('REFUSED stock_reference_exact_one_donor_eight_products');return end
 if #carriers==1 and #bodies==8 then
  table.sort(bodies)
  observer=M.New({Spring=Spring,UnitDefs=UnitDefs,UnitDefNames=UnitDefNames,carrier=carriers[1],bodies=bodies,
   options=o,mode=tostring(o.prototype_stock_transport_reference_mode or'whole8'),donorMD5=M.DonorMD5,Emit=emit})
  if observer.result then finish(observer.result)end
 end
end
