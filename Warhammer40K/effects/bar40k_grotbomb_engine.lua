local motor={
 flame={air=true,ground=true,water=true,underwater=false,class='CBitmapMuzzleFlame',count=1,
  properties={colormap='1 .85 .35 .9  1 .32 .05 .6  .12 .04 .01 .01',dir='dir',fronttexture='flare',sidetexture='muzzleside',length=17,size=5,sizegrowth=-.25,ttl=5}},
 smoke={air=true,ground=true,water=true,underwater=false,class='CSimpleParticleSystem',count=1,
  properties={airdrag=.92,colormap='.35 .32 .28 .35  .12 .12 .12 .18  0 0 0 0',directional=false,emitrot=12,emitrotspread=8,emitvector='dir',gravity='0, .02, 0',numparticles=1,particlelife=18,particlelifespread=6,particlesize=4,particlesizespread=1,particlespeed=1.5,particlespeedspread=.5,pos='0,0,0',sizegrowth=.25,sizemod=1,texture='smoke'}}}
local ignition={flash={air=true,ground=true,water=true,underwater=false,class='CBitmapMuzzleFlame',count=1,
 properties={colormap='1 .9 .5 1  1 .3 .05 .5  0 0 0 0',dir='dir',fronttexture='flare',sidetexture='muzzleside',length=23,size=8,sizegrowth=-.35,ttl=7}}}
return {bar40k_grotbomb_motor=motor,bar40k_grotbomb_ignition=ignition}
