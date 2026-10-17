function gadget:GetInfo()return{name='40K ordinary Marine capture order assistant',desc='Exclusive default-off paid two-owner source scene; root-assisted orders',author='Local project',layer=152,enabled=true}end
if not gadgetHandler:IsSyncedCode()then return false end
local M=VFS.Include('40k_configs/marine_capture_orders.lua')
local options=Spring.GetModOptions()or{}
if not M.Enabled(options)then return false end
local site=VFS.Include('40k_configs/ordinary_paid_construction_site.lua')
local endpoint=VFS.Include('40k_configs/paid_factory_egress_review.lua')
local geometry=VFS.Include('40k_configs/guard_factory_egress_geometry.lua')
local A
local initialGameFrame=true
local function emit(...)Spring.Echo('40K_MARINE_CAPTURE_ASSISTANT',...)end
local function choose(def,builder,metal)
 -- Existing chooser treats unknown rectangle inventories as empty. Refuse those.
 local proxy=setmetatable({GetUnitsInRectangle=function(...)
  local list=Spring.GetUnitsInRectangle(...);assert(type(list)=='table','unknown native placement inventory');return list
 end,GetUnitsInCylinder=function(...)
  local list=Spring.GetUnitsInCylinder(...);assert(type(list)=='table','unknown native metal inventory');return list
 end},{__index=Spring})
 return site.Choose(proxy,UnitDefs,GG,Game,def,builder,metal,emit)
end
local function park(body,factory)return endpoint.Plan(Spring,UnitDefs,body,factory,Game.mapSizeX,Game.mapSizeZ)end
local function clear(factory,body)return geometry.Outside(Spring,UnitDefs,factory,body)end
function gadget:GameFrame(frame)
 if initialGameFrame then
  initialGameFrame=false
  if frame==0 and type(Spring.GetGameFrame)=='function'and Spring.GetGameFrame()==0 then return end
 end
 if not A then A=M.New(Spring,UnitDefs,UnitDefNames,GG,CMD,options,choose,park,clear,emit)end;A.Frame(frame)
end
function gadget:UnitCreated(...)if A then A.Created(...)end end
function gadget:UnitFinished(...)if A then A.Finished(...)end end
function gadget:UnitFromFactory(...)if A then A.Released(...)end end
