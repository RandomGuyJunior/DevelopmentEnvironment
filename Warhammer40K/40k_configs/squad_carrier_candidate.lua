-- Explicit coordinator-only source overlay. Does not activate itself.
local M={Version=1,Key='ork_looted_rhino',Profile='ork_shoota'}
local function positive(n)return type(n)=='number'and n==n and n>0 and n<math.huge end
function M.Apply(defs,V,profiles)
 local d=assert(defs[M.Key]);local cp=assert(d.customparams)
 local p=assert(profiles.profiles[M.Profile])
 assert(p.capacity==8 and cp.animsource==M.Key and cp.faction=='Orks'
  and tonumber(cp.source_squad_transport_slots)==1,'Wrong genuine carrier/profile')
 assert(d.objectname==M.Key..'.glb' and d.script=='40k_roster.lua','Carrier already adapted')
 for _,path in ipairs({'objects3d/'..d.objectname,'scripts/'..d.script,
  'scripts/40k_squad_carrier.lua','40k_configs/squad_carrier_script.lua',
  'scripts/generated/'..M.Key..'_anim.lua','unittextures/'..M.Key..'_tex1.png',
  'unittextures/'..M.Key..'_tex2.png'})do assert(V.FileExists(path),'Missing carrier asset '..path)end
 local size,mass,maxSize=0,0,0
 for slot=1,p.capacity do
  local name=p.special and slot==p.specialSlot and p.special or p.member
  local body=assert(defs[name],'Apply after real per-body squad definitions')
  local footprint=body.footprintx
  -- Native default mass is metal cost clamped to [1,1e6]. Internal bodies
  -- retain per-body prices; never derive from the factory aggregate product.
  local m=body.mass or math.max(1,math.min(1000000,assert(body.metalcost)))
  assert(positive(footprint)and positive(m)and m<100000 and not body.cantbetransported,'Native body limits')
  size=size+footprint;mass=mass+m;maxSize=math.max(maxSize,footprint)
 end
 d.transportcapacity=size;d.transportsize=maxSize;d.transportmass=mass
 d.istransport=true;d.transportbyenemy=false;d.fireplatform=false
 -- Native destruction kills enclosed cargo; no invented rescue/heal ability.
 d.releaseheld=false;d.script='40k_squad_carrier.lua'
 cp.source_transport_actor_capacity=p.capacity
 cp.prototype40k_transport_profile=M.Profile;cp.prototype40k_transport_squad_limit=1
 cp.source_transport_policy='one_fixed8_hidden_real_bodies_v1'
 cp.source_transport_adaptation_pending=1 -- Native proof remains outstanding.
 return{key=M.Key,profile=M.Profile,capacity=p.capacity,size=size,mass=mass,maxSize=maxSize}
end
return M
