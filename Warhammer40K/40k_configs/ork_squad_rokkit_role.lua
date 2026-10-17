-- Isolated authored role recipe; coordinator opts in before final squad pricing.
-- Genuine Tankbusta body/weapon, not an invented Boyz weapon/material variant.
local M={Version=1,Profile='ork_shoota',Research='ork_squad_rokkit',Internal='ork_boy_rokkit_member'}
local function copy(v)if type(v)~='table'then return v end;local t={};for k,x in pairs(v)do t[k]=copy(x)end;return t end
function M.Configure(base)
 assert(base.byID[3]=='ork_shoota'and base.profiles.ork_shoota.id==3,'Ork stable ID changed')
 local result=copy(base);local p=result.profiles.ork_shoota
 assert(p.product=='ork_boy'and p.member=='ork_boy_member'and p.capacity==8,'Wrong ordinary Shoota family')
 assert(not p.special or(p.special==M.Internal and p.research==M.Research and p.specialSlot==8),'Conflicting Ork specialist role')
 p.specialSlot=8;p.special=M.Internal;p.sourceSpecial='ork_tankbusta';p.research=M.Research
 p.description='8 real Shoota Boyz; builders restore casualties for resources. Optional Waaagh Banner research equips one genuine Tankbusta.'
 p.researchRow={name='Mob rokkit specialist',description='Permanently equips one living member per Shoota mob as a genuine Tankbusta. Missing bodies still require paid builder repair.',
  producer='ork_waaagh_banner',cost={metal=300,energy=1500},time=40,requires={buildings={'ork_waaagh_banner'}}}
 return result
end
function M.Preflight(defs,V)
 for _,key in ipairs({'ork_boy','ork_tankbusta','ork_waaagh_banner'})do
  local d=assert(defs[key],'Missing genuine Ork source '..key);local c=d.customparams or{}
  assert(c.animsource==key and d.objectname and d.script,'Wrong actor identity '..key)
  for _,path in ipairs({'objects3d/'..d.objectname,'scripts/'..d.script,'scripts/generated/'..key..'_anim.lua','unittextures/'..key..'_tex1.png','unittextures/'..key..'_tex2.png'})do
   assert(V.FileExists(path),'Missing complete genuine actor '..path)
  end
 end
 local d=defs.ork_tankbusta;assert(d.canmove and d.canattack and not d.builder,'Tankbusta is not ordinary ranged infantry')
 for _,key in ipairs({'metalcost','energycost','buildtime'})do assert(type(d[key])=='number'and d[key]>0 and d[key]<math.huge,'Invalid genuine body bill')end
 assert(#d.weapons==1,'Tankbusta weapon layout changed')
 local w=assert(d.weapondefs[d.weapons[1].def:lower()],'Missing Tankbusta weapon')
 assert(w.weapontype=='MissileLauncher'and w.customparams.source_muzzle=='marker_boyz_rokkit_launcha_barrel'and w.customparams.source_fireclip=='fire','Wrong genuine Rokkit role')
 local b=V.Include('scripts/generated/ork_tankbusta_anim.lua');local marker=false
 for _,name in ipairs(b.bones or{})do if name==w.customparams.source_muzzle then marker=true end end
 assert(marker,'Genuine Rokkit muzzle absent from bank')
 for _,key in ipairs({'idle','walk','fire'})do local clip=assert(b.clips[key],'Missing genuine Tankbusta clip '..key);assert(clip.duration>0 and #clip.frames>1,'Unusable genuine Tankbusta clip '..key)end
 return{profile=M.Profile,research=M.Research,actor='ork_tankbusta',producer='ork_waaagh_banner',slot=8,capacity=8}
end
return M
