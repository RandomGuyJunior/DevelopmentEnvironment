-- Authored compact DoW/UA-inspired layers using pinned BAR texture aliases.
-- Lifetimes are simulation frames. No visual layer owns collision or damage.
local powder='1 .94 .72 .32  1 .5 .08 .22  .45 .13 .02 .06  0 0 0 0'
local red='1 .09 .025 .32  .8 .025 .01 .15  0 0 0 0'
local smoke='.2 .18 .15 .12  .12 .11 .095 .055  0 0 0 0'
local dirt='.3 .23 .15 .21  .17 .13 .09 .08  0 0 0 0'
local fire='.95 .8 .5 .28  .9 .47 .12 .2  .35 .13 .035 .08  0 0 0 0'
local power='.8 .9 1 .3  .32 .55 .8 .16  0 0 0 0'
local function flame(radius,length,ttl,color,energy)
 return {class='CBitmapMuzzleFlame',count=1,air=true,ground=true,water=true,unit=true,nounit=true,underwater=false,properties={dir='dir',colormap=color,fronttexture=energy and 'laserend' or 'muzzlefront',sidetexture=energy and 'shot' or 'muzzleside',frontoffset=0,size=radius,length=length,ttl=ttl,sizegrowth=-.25,useairlos=true}}
end
local function particles(texture,n,size,life,speed,color,spread,growth)
 return {class='CSimpleParticleSystem',count=1,air=true,ground=true,water=true,unit=true,nounit=true,underwater=false,properties={airdrag=.9,colormap=color,directional=false,emitrot=0,emitrotspread=spread or 25,emitvector='dir',gravity='0, .015, 0',numparticles=n,particlelife=life,particlelifespread=1,particlesize=size,particlesizespread=size*.2,particlespeed=speed,particlespeedspread=speed*.3,pos='0, 0, 0',sizegrowth=growth or 0,sizemod=1,texture=texture,useairlos=true}}
end
local function muzzle(radius,length,ttl,smokeSize)
 local d={usedefaultexplosions=false,flash=flame(radius,length,ttl,powder)}
 if smokeSize then d.smoke=particles('smoke_puff',1,smokeSize,7,.12,smoke,15,.045) end
 return d
end
local function hit(size,n,dustSize)
 local d={usedefaultexplosions=false,glint=particles('gunshotglow',1,size,3,0,powder,0,-.05),sparks=particles('gunshotglow',n,.16,5,.65,powder,65,-.03)}
 if dustSize then d.dust=particles('dirtpuff',1,dustSize,8,.14,dirt,45,.05);d.dust.unit=false;d.dust.air=false;d.dust.water=false;d.dust.properties.emitvector='0, 1, 0' end
 return d
end
local fx={}
local function add(kind,m,h) fx['40k_dow_'..kind..'_muzzle']=m;fx['40k_dow_'..kind..'_impact']=h end
for _,v in ipairs({{'lasgun',.18,1.5,.35},{'hellgun',.23,2.1,.5},{'multilaser',.28,2.6,.62}}) do
 add(v[1],{usedefaultexplosions=false,flash=flame(v[2],v[3],2,red,true)},{usedefaultexplosions=false,glint=particles('gunshotglow',1,v[4],2,0,red,0,-.08)})
end
-- Copied UA lasgun muzzle combines a red beam with a brief warm hot core;
-- copied unit impact includes a separate spark layer. Keep the thin existing
-- red pulse/glint and add only compact short details, never a large glow orb.
local lasgunHot='1 .88 .76 .25  1 .22 .12 .12  0 0 0 0'
fx['40k_dow_lasgun_muzzle'].hotcore=flame(.055,.6,1,lasgunHot,true)
fx['40k_dow_lasgun_impact'].fleck=particles('gunshotglow',1,.055,3,.3,lasgunHot,35,-.025)
-- Sentinel's copied multilaser combines a warm inner beam with a white
-- impact flash and short warm smoke layer. Compact stock-texture details
-- distinguish it from infantry fire; native projectile/damage stay untouched.
local multilaserHot='1 .89 .58 .26  1 .36 .1 .12  0 0 0 0'
local multilaserWhite='1 .97 .94 .24  1 .72 .56 .12  0 0 0 0'
local multilaserHaze='.6 .45 .32 .075  .26 .23 .2 .035  0 0 0 0'
fx['40k_dow_multilaser_muzzle'].hotcore=flame(.085,1.3,1,multilaserHot,true)
fx['40k_dow_multilaser_impact'].whitecore=particles('gunshotglow',1,.18,2,0,multilaserWhite,0,-.05)
fx['40k_dow_multilaser_impact'].haze=particles('smoke_puff',1,.24,5,.025,multilaserHaze,20,.018)
for _,v in ipairs({{'bolter',.48,2.4,2,.3,.65,2,.35},{'heavy_bolter',.72,3.2,3,.45,.82,3,.5},{'assaultcannon',.6,2.8,2,.35,.65,2,.4},{'autocannon',.8,3.8,3,.6,1,3,.65},{'slugga',.45,1.9,2,.25,.45,1,.3},{'shoota',.55,2.5,2,.33,.55,2,.38},{'big_shoota',.72,3.1,3,.45,.75,2,.5}}) do
 add(v[1],muzzle(v[2],v[3],v[4],v[5]),hit(v[6],v[7],v[8]))
end
for _,v in ipairs({{'tankcannon',1.6,7,3.2,1.5,2},{'artillery',1.8,8,8,5,3},{'rokkit',.65,3,2.2,1,2}}) do
 local h=hit(v[4],5,v[5]);h.smoke=particles('smoke_puff',v[6],v[5],20,.25,smoke,45,.12)
 h.debris=particles('dirtpuff',4,v[5]*.7,15,.9,dirt,60,.08)
 h.debris.air=false;h.debris.water=false;h.debris.unit=false;h.debris.properties.emitvector='0, 1, 0';h.debris.properties.gravity='0, -.1, 0'
 add(v[1],muzzle(v[2],v[3],4,v[5]*.7),h)
end
fx['40k_dow_rokkit_trail']={usedefaultexplosions=false,smoke=particles('smoke_puff',1,.5,12,.02,smoke,0,.065)}
-- Native Flame projectile owns the stream; this is only the short pilot flash.
add('flamer',{usedefaultexplosions=false,pilot=flame(.38,1.4,3,fire)},{usedefaultexplosions=false,flame=particles('gunshotglow',2,.6,7,.12,fire,30,-.035),smoke=particles('smoke_puff',1,.55,10,.1,smoke,20,.025)})
-- Powered melee has no gun muzzle; only native contact produces this impact.
fx['40k_dow_claw_impact']={usedefaultexplosions=false,arc=flame(.12,.7,2,power,true),sparks=particles('gunshotglow',3,.12,4,.45,power,65,-.03)}
fx['40k_dow_choppa_impact']={usedefaultexplosions=false,sparks=particles('gunshotglow',2,.12,3,.4,powder,60,-.025)}
-- Genuine Necron sources include green Gauss, UA blue Tesla and crystal beams.
local gauss='.32 1 .12 .32  .1 .65 .025 .16  0 0 0 0'
for _,v in ipairs({{'gauss',.25,2,.6},{'gauss_heavy',.38,3,1},{'particle',.65,4.5,2.2}}) do
 add(v[1],{usedefaultexplosions=false,flash=flame(v[2],v[3],2,gauss,true)}, {usedefaultexplosions=false,glint=particles('gunshotglow',1,v[4],3,0,gauss,0,-.09),sparks=particles('gunshotglow',2,.16,4,.35,gauss,40,-.03)})
end
add('tesla',{usedefaultexplosions=false,arc=flame(.2,1.6,2,power,true)}, {usedefaultexplosions=false,glint=particles('gunshotglow',1,.8,3,0,power,0,-.08),sparks=particles('gunshotglow',3,.15,5,.4,power,55,-.03)})
fx['40k_dow_necron_blade_impact']={usedefaultexplosions=false,sparks=particles('gunshotglow',3,.12,4,.4,gauss,60,-.025)}
fx['40k_dow_blunt_impact']={usedefaultexplosions=false,dust=particles('dirtpuff',1,.35,5,.08,dirt,30,.02)}
return fx
