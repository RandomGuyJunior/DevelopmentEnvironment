local result={}
for _,variant in ipairs({'goffs','badmoons','evilsunz','guard'}) do
  for _,pose in ipairs({'die','die_alt','die_alt2'}) do
    local name='squad_corpse_'..variant..'_'..pose
    result[name]={description='Fallen infantry',object=name..'.glb',blocking=false,collidable=false,
      footprintx=1,footprintz=1,height=3,damage=1000000,metal=0,energy=0,reclaimable=true,autoreclaimable=true,resurrectable=0,
      burnable=false,upright=true,customparams={squad_remains=true}}
  end
end
result.squad_salvage_pile={description='Infantry salvage pile',object='squad_corpse_evilsunz_die.glb',blocking=false,collidable=false,footprintx=3,footprintz=3,height=3,damage=1000000,metal=0,energy=0,reclaimable=true,autoreclaimable=true,resurrectable=0,burnable=false,upright=true,customparams={squad_remains=true,squad_salvage_pile=true}}
for _,variant in ipairs({'gretchin','shoota','loota','kommando','nob','ardboy','burna','stormboy','dakka','meganob','flashgit','tankbusta','grotcannon','mekgun','kansquad'}) do
 for _,pose in ipairs({'die','die_alt','die_alt2'}) do
  local name='squad_corpse_'..variant..'_'..pose
  result[name]={description='Fallen Ork squad member',object=name..'.glb',blocking=false,collidable=false,
   footprintx=1,footprintz=1,height=3,damage=1000000,metal=0,energy=0,reclaimable=true,autoreclaimable=true,resurrectable=0,
   burnable=false,upright=true,customparams={squad_remains=true}}
 end
end
return result
