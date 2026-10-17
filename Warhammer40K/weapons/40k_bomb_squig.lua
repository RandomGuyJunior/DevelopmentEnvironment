-- A single native death/self-destruct blast; no ordinary gun or Lua damage.
return {['40k_bomb_squig_blast']={name='Bomb Squig detonation',weapontype='Cannon',
 areaofeffect=72,edgeeffectiveness=.35,impulsefactor=0,cratermult=0,
 explosiongenerator='custom:40k_dow_rokkit_impact',damage={default=180},
 soundhit='40k_explosion',soundhitvolume=1}}
