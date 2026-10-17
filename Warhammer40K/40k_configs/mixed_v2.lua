-- Authored diagnostic populations. This is not a paid roster acceptance graph.
local M={mapName='Ashen Bastion 0.1',mapSize=4096,stages={100,250,500},
 settleWall=8,measureWall=35,minFPS=20,minSim=.95,minVisibleFraction=.8,maxPaidPerTeam=120,
 columns=25,spacing=112,startX=640,startZ=768,
 teams={
 {id=0,faction='Imperium',units={'imp_guardsman','imp_marine','imp_russ'},
  hq='imp_hq',factory='imp_barracks',product='imp_guardsman',builder='imp_enginseer',
  generator='imp_generator',mex='imp_mex',baseX=512,baseZ=512,mexX=512,mexZ=1664},
 {id=1,faction='Orks',units={'ork_boy','ork_meganob','ork_killa_kan'},
  hq='ork_settlement',factory='ork_boyz_hut',product='ork_boy',builder='ork_grot',
  generator='ork_generator',mex='ork_resource_factory',baseX=3584,baseZ=512,mexX=3584,mexZ=1664},
 {id=2,faction='Necrons',units={'nec_warrior','nec_immortal','nec_destroyer'},
  hq='nec_hq',factory='nec_hq',product='nec_warrior',builder='nec_scarab',
  generator='nec_generator',mex='nec_mex',baseX=2048,baseZ=3584,mexX=2048,mexZ=3072}}
}
function M.Enabled(o)
 return o and o.prototype_diagnostic=='mixedperf2' and tostring(o.prototype_mixed_v2)=='1'
end
function M.Selected(o)
 if not M.Enabled(o) then return nil end
 local out={}
 for _,t in ipairs(M.teams)do
  for _,name in ipairs(t.units)do out[name]=true end
  for _,key in ipairs({'hq','factory','product','builder','generator','mex'})do out[t[key]]=true end
 end
 return out
end
function M.Composition(total,side)
 assert(total==100 or total==250 or total==500,'unsupported population')
 assert(side>=1 and side<=3,'invalid side')
 local n=math.floor(total/3)+(side<=total%3 and 1 or 0)
 local elite,vehicle=math.floor(n*.2),math.floor(n*.1)
 return {n-elite-vehicle,elite,vehicle}
end
-- One authoritative serial map: all fixed movement loads before real battles.
M.windowOrder='movement_first_then_combat'
function M.Window(serial)
 if type(serial)~='number' or serial~=math.floor(serial) or serial<1 or serial>2*#M.stages then return nil end
 local stage=(serial-1)%#M.stages+1
 local phase=serial<=#M.stages and 'movement' or 'combat'
 return {serial=serial,stage=stage,phase=phase,target=M.stages[stage],
  populationScope=phase=='movement' and 'fixed_population' or 'battle_population_history'}
end
return M
