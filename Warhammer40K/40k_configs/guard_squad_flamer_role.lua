-- Genuine privately converted Guardsman flamer candidate; no live hook/profile activation.
local M={Version=1,Profile='guard_line',Research='guard_squad_flamer',Internal='imp_guardsman_flamer_member'}
local function copy(v)if type(v)~='table'then return v end;local t={};for k,x in pairs(v)do t[k]=copy(x)end;return t end
function M.Configure(base)
 assert(base.byID[2]=='guard_line'and base.profiles.guard_line.id==2,'Guard stable ID changed')
 local result=copy(base);local p=result.profiles.guard_line
 assert(p.product=='imp_guardsman'and p.member=='imp_guardsman_member'and p.capacity==8,'Wrong ordinary Guard family')
 assert(not p.special or(p.special==M.Internal and p.research==M.Research and p.specialSlot==8),'Conflicting Guard specialist')
 p.specialSlot=8;p.special=M.Internal;p.sourceSpecial='imp_guardsman_flamer';p.research=M.Research
 p.description='8 real Guardsmen; builders restore casualties for resources. Optional Tactica research equips one genuine Guardsman flamer.'
 p.researchRow={name='Squad flamer',description='One genuine Guardsman flamer specialist per line squad; missing bodies require paid builder repair.',
  producer='imp_research',cost={metal=200,energy=1000},time=35,requires={buildings={'imp_research'}}}
 return result
end
function M.SourceDefinition(body)
 assert(body and(body.customparams or{}).animsource=='guardsman','Actual Guardsman source body required')
 local c=body.customparams or{};assert(not c.prototype40k_squad_product and not c.prototype40k_squad_internal and not body.builder,'Unaggregated ordinary body required')
 local d=copy(body);d.name='Guardsman Flamer';d.description='Genuine short-range flame specialist';d.objectname='guardsman_flamer.glb';d.script='40k_roster.lua'
 d.metalcost=18;d.energycost=90;d.buildtime=220;d.buildoptions={}
 d.customparams.animsource='guardsman_flamer';d.customparams.rosterrole='infantry';d.customparams.fireperiod=.2;d.customparams.muzzlefx=1024
 d.sfxtypes={explosiongenerators={'custom:40k_dow_flamer_muzzle'}}
 d.weapondefs={flamer={name='Guardsman Flamer',weapontype='Flame',range=130,reloadtime=1.4,weaponvelocity=240,turret=true,tolerance=4000,
  accuracy=180,sprayangle=130,areaofeffect=14,cratermult=0,impulsefactor=0,collidefriendly=true,collideenemy=true,collideground=true,
  collidefeature=true,collideneutral=true,collidenontarget=true,avoidfriendly=true,avoidfeature=true,damage={default=8},
  burst=4,burstrate=.2,duration=.45,rgbcolor='1 .45 .05',explosiongenerator='custom:40k_dow_flamer_impact',
  customparams={source_muzzle='marker_flamer_muzzle',source_fireclip='fire',source_fx_family='flamer',source_muzzlefx=1024}}}
 d.weapons={{def='flamer',onlytargetcategory='SURFACE'}};return d
end
function M.Preflight(defs,V)
 local d=assert(defs.imp_guardsman_flamer,'Missing genuine converted flamer definition')
 assert(defs.imp_guardsman and defs.imp_research,'Missing ordinary Guard or optional Tactica')
 assert(d.customparams.animsource=='guardsman_flamer'and d.objectname=='guardsman_flamer.glb'and d.script=='40k_roster.lua','Wrong genuine flamer actor')
 assert(d.canmove and d.canattack and not d.builder and #d.weapons==1,'Wrong flamer infantry layout')
 for _,path in ipairs({'objects3d/guardsman_flamer.glb','scripts/40k_roster.lua','scripts/generated/guardsman_flamer_anim.lua',
  'unittextures/guardsman_flamer_tex1.png','unittextures/guardsman_flamer_tex2.png'})do assert(V.FileExists(path),'Missing genuine complete flamer '..path)end
 local w=assert(d.weapondefs[d.weapons[1].def:lower()]);assert(w.weapontype=='Flame'and w.customparams.source_muzzle=='marker_flamer_muzzle'and w.customparams.source_fireclip=='fire','Wrong source flamer weapon')
 local bank=V.Include('scripts/generated/guardsman_flamer_anim.lua');local found=false
 for _,name in ipairs(bank.bones)do if name=='marker_flamer_muzzle'then found=true end end;assert(found,'Missing flamer muzzle')
 for key,source in pairs({idle='idle_1',walk='move_run_1',fire='idle_firing_flamer',death='die_normal_1'})do
  local clip=assert(bank.clips[key],'Missing genuine flamer clip');assert(clip.source==source and clip.duration>0 and #clip.frames>1,'Wrong genuine flamer clip source')
 end
 for _,key in ipairs({'metalcost','energycost','buildtime'})do assert(type(d[key])=='number'and d[key]>0 and d[key]<math.huge,'Invalid body bill')end
 return{profile=M.Profile,actor='guardsman_flamer',capacity=8,slot=8,research=M.Research,nativeAccepted=false}
end
return M
