-- Scoped ranged-walker rockets: existing stock textures, visual-only CEGs.
local FIRE='1 .9 .65 .32  1 .48 .08 .2  .45 .1 .015 .06  0 0 0 0'
local SMOKE='.2 .18 .16 .14  .12 .11 .1 .065  0 0 0 0'
local DIRT='.3 .23 .15 .2  .17 .13 .09 .08  0 0 0 0'
local function particles(texture,count,size,life,speed,color,growth)
 return{class='CSimpleParticleSystem',count=1,air=true,ground=true,water=true,unit=true,nounit=true,underwater=false,
  properties={airdrag=.88,colormap=color,directional=false,emitrot=0,emitrotspread=45,emitvector='dir',
   gravity='0, .015, 0',numparticles=count,particlelife=life,particlelifespread=1,
   particlesize=size,particlesizespread=size*.2,particlespeed=speed,particlespeedspread=speed*.3,
   pos='0, 0, 0',sizegrowth=growth,sizemod=1,texture=texture,useairlos=true}}
end
local debris=particles('dirtpuff',4,1.8,15,.9,DIRT,.08)
debris.air=false;debris.water=false;debris.unit=false
debris.properties.emitvector='0, 1, 0';debris.properties.gravity='0, -.1, 0'
return{
 ['40k_ork_ranged_rokkit_trail']={usedefaultexplosions=false,
  head=particles('gunshotglow',1,1.25,2,0,FIRE,-.08),
  smoke=particles('smoke_puff',1,.65,12,.02,SMOKE,.065)},
 ['40k_ork_ranged_rokkit_impact']={usedefaultexplosions=false,
  flash=particles('gunshotglow',1,5.5,5,0,FIRE,-.16),
  sparks=particles('gunshotglow',6,.3,7,.85,FIRE,-.03),
  smoke=particles('smoke_puff',2,2.4,20,.25,SMOKE,.12),debris=debris},
}
