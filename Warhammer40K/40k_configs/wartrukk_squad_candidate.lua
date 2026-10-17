-- Wartrukk-only candidate: one full8 basic mob, native real-body reservations.
local M={Option='prototype_wartrukk_transport_pilot',Policy='wartrukk_fixed8_hidden_real_bodies_v1'}
local function yes(v)return v==true or v==1 or v=='1'end
local function positive(v)return type(v)=='number'and v==v and v>0 and v<math.huge end
function M.NativeScope(options)
 options=options or{}
 if not yes(options.prototype_wartrukk_native_fixture)then return false end
 assert(options.prototype_diagnostic=='normal'and(options.prototype_source_acceptance==nil or options.prototype_source_acceptance=='')
  and yes(options.prototype_development_playtest)and yes(options.prototype_source_progression)
  and yes(options[M.Option])and yes(options.prototype_squad_transport_pilot)and yes(options.prototype_ork_slugga_squad),
  'Exact owned normal-source Wartrukk squad diagnostic required')
 for key,value in pairs(options)do
  if yes(value)and key~='prototype_wartrukk_native_fixture'and(key:match('_fixture$')or key:match('benchmark')or key:match('probe')or key=='prototype_burna_flame_combat')then error('Conflicting diagnostic '..key)end
 end
 return true
end
function M.Apply(defs,V,profiles,options)
 if not yes((options or{})[M.Option])then return{enabled=false}end
 assert(yes(options.prototype_squad_transport_pilot)and yes(options.prototype_ork_slugga_squad),'Existing squad transport and full8 Slugga owner required')
 local d=assert(defs.ork_trukk,'Exact existing Wartrukk required');local cp=assert(d.customparams)
 assert(d.objectname=='ork_trukk.glb'and d.script=='40k_roster.lua'and cp.animsource=='ork_trukk'and cp.faction=='Orks'
  and d.metalcost==150 and d.energycost==750 and d.buildtime==1800,'Exact unchanged chassis/economy required')
 assert(d.transportcapacity==6 and d.transportsize==2 and d.transportmass==1500,'Unadapted native six-body policy required')
 assert(d.corpse==nil and d.featuredefs==nil,'Do not replace an existing salvage owner')
 for _,p in ipairs({'objects3d/ork_trukk.glb','scripts/generated/ork_trukk_anim.lua','scripts/40k_roster.lua',
  'unittextures/ork_trukk_tex1.png','unittextures/ork_trukk_tex2.png','unitpics/40k_ork_trukk.png',
  'scripts/40k_wartrukk_squad.lua','40k_configs/wartrukk_squad_script.lua'})do assert(V.FileExists(p),'Missing exact dependency '..p)end
 local slugga=assert(profiles.profiles.ork_slugga);assert(slugga.capacity==8,'Current full8 basic squad required')
 local maxSize=0;local admitted=0;local basicAdmitted=false
 -- Native footprint capacity is distinct from logical body capacity. Include
 -- current specialist definitions so existing/future equipment stays safe.
 for _,p in pairs(profiles.profiles)do
  if p.capacity<=8 then
   local base=defs[p.member];local bc=base and base.customparams or{}
   if bc.faction=='Orks'and bc.rosterrole=='infantry'then
    local mass=0
    for slot=1,p.capacity do
     local name=p.special and slot==p.specialSlot and p.special or p.member
     local body=assert(defs[name],'Missing eligible real body '..name)
     local footprint=body.footprintx;local m=body.mass or math.max(1,math.min(1000000,assert(body.metalcost)))
     assert(positive(footprint)and footprint<=4 and positive(m)and m<100000 and not body.cantbetransported,'Actual infantry body limits')
     maxSize=math.max(maxSize,footprint);mass=mass+m
    end
    assert(mass<=1500,'Do not silently change actual native mass budget');admitted=admitted+1
    if p==slugga then basicAdmitted=true end
   end
  end
 end
 assert(basicAdmitted and admitted>0 and maxSize>0,'Actual full8 Slugga infantry bodies required')
 d.transportcapacity=8*maxSize;d.transportsize=maxSize;d.istransport=true;d.transportbyenemy=false
 d.fireplatform=false;d.isfireplatform=false;d.script='40k_wartrukk_squad.lua'
 d.name='Wartrukk';d.description='Armed infantry transport: one mob, up to 8 real bodies; provisional intact wreck'
 cp.source_transport_actor_capacity=8;cp.source_transport_policy=M.Policy;cp.prototype40k_transport_squad_limit=1
 cp.prototype40k_transport_profile=nil;cp.source_transport_adaptation_pending=1
 cp.source_transport_capacity_policy=nil -- The superseded six-body hook must not own admission.
 cp.source_transport_balance='8 bodies; full fixed slots reserved, including casualties; 1500 native mass limit'
 d.corpse='wreck';d.featuredefs={wreck={description='Wartrukk remains (temporary intact silhouette)',object='ork_trukk.glb',
  blocking=false,reclaimable=true,autoreclaimable=true,resurrectable=0,indestructible=true,flammable=false,health=1,
  metal=37.5,energy=0,footprintx=d.footprintx,footprintz=d.footprintz,featuredead='',
  customparams={parent_actor='ork_trukk',prototype40k_remains_domain='vehicle',one_salvage_owner=1,persistent_salvage=1,
   source_wreck_presentation='temporary unchanged genuine chassis; damaged derivative pending'}}}
 return{enabled=true,actorCapacity=8,footprintCapacity=d.transportcapacity,maxBodySize=maxSize,massLimit=1500,
  eligibleCurrentProfiles=admitted,nativeAccepted=false,ordinaryAccepted=false}
end
return M
