-- Review-only movement envelopes for genuine unchanged source collision bodies.
local M={}
M.Actors={
 ork_trukk={class='40k_ork_trukk_envelope10',donor='tank3',speedClass=0,footprint=10,source='ork_trukk',radius=49.9389763,mid={-.125669479370117,17.7694672895595,5.286651611328125},nativeCost={150,750,1800}},
 ork_slugga={class='40k_ork_slugga_envelope4',donor='sbot2',speedClass=1,footprint=4,source='ork_slugga',radius=14.8468504,mid={.488512754440308,9.44525544345379,4.93884778022766},nativeCost={12,60,144}},
}
local function copy(v)if type(v)~='table'then return v end;local t={};for k,x in pairs(v)do t[k]=copy(x)end;return t end
local function enabled(options)return options and options.prototype_diagnostic=='roster' and tostring(options.prototype_transport_envelope_review)=='1'end
function M.Radius(a)return a.radius+math.sqrt(a.mid[1]^2+a.mid[2]^2+a.mid[3]^2)end
function M.NativeMoveRadius(footprint)return (2*footprint-1)*4 end
function M.ApplyMoveDefs(defs,options,available)
 if not enabled(options)then return defs end
 assert(type(available)=='function','Exact enabled actor availability predicate required')
 for _,key in ipairs({'ork_trukk','ork_slugga'})do local a=M.Actors[key]
  if available(key)then
   local donor,existing;for _,d in ipairs(defs)do local n=type(d.name)=='string'and d.name:lower();if n==a.donor then donor=d end;if n==a.class then existing=d end end
   assert(donor,'Missing real movement donor '..a.donor)
   assert(M.NativeMoveRadius(a.footprint)>=M.Radius(a),'Movement envelope understates actual native body')
   if existing then assert(existing.footprintx==a.footprint and existing.footprintz==a.footprint and existing.speedmodclass==a.speedClass,'Conflicting movement class')
   else local d=copy(donor);d.name=a.class;d.footprintx=a.footprint;d.footprintz=a.footprint;d.speedModClass=nil;d.speedmodclass=a.speedClass;defs[#defs+1]=d end
  end
 end
 return defs
end
function M.ApplyDefinitions(defs,options)
 if not enabled(options)then return defs end
 for key,a in pairs(M.Actors)do local d=defs[key]
  if d then
   local cp=d.customparams or {};assert(cp.animsource==a.source and tostring(cp.prototype40k)=='1','Wrong source actor '..key)
   assert(d.objectname==key..'.glb'and d.script=='40k_roster.lua','Wrong model/script '..key)
   assert(d.metalcost==a.nativeCost[1]and d.energycost==a.nativeCost[2]and d.buildtime==a.nativeCost[3],'Changed actor admission identity '..key)
   -- All geometry, collision fields, weapon and movement physics stay unchanged.
   d.movementclass=a.class;d.footprintx=a.footprint;d.footprintz=a.footprint
   if key=='ork_trukk'then d.transportcapacity=24;d.transportsize=4;cp.source_transport_actor_capacity=6;cp.source_transport_capacity_policy='six_actors_footprint4_v1' end
  end
 end
 return defs
end
return M
