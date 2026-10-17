-- Authored workload specification; exact definitions, never model substitutions.
local M={stages={100,250,500},mapName="Ashen Bastion 0.1",columns=10,spacingX=208,spacingZ=112,startX=1000,startZ=640,
 settleWall=10,measureWall=45,minFPS=20,minSim=.95,maxLossFraction=.25,
 teams={{id=0,faction='Imperium',baseX=640,baseZ=2048,mexX=512,mexZ=1664,units={'imp_guardsman','imp_marine','imp_russ'},
 hq='imp_hq',factory='imp_barracks',product='imp_guardsman',builder='imp_enginseer',generator='imp_generator',mex='imp_mex',large='imp_basilisk'},
 {id=1,faction='Orks',baseX=3456,baseZ=2048,mexX=3584,mexZ=1664,units={'ork_boy','ork_meganob','ork_killa_kan'},
 hq='ork_settlement',factory='ork_boyz_hut',product='ork_boy',builder='ork_grot',generator='ork_generator',mex='ork_resource_factory',large='ork_deff_dread'}}}
function M.composition(total,large)
 assert(total%2==0,'balanced even total required')
 local half=total/2;local elite=math.floor(half*.2);local vehicle=math.floor(half*.1)
 local extra=large and math.floor(half*.1) or 0
 return {half-elite-vehicle-extra,elite,vehicle,extra}
end
return M
