-- Authored compact equivalents of actual selected DoW/UA Necron effect graphs.
-- Genuine copied textures are optional; root resources must register TextureAliases.
-- This bank owns only local muzzle/contact layers, never range beams or damage.
local profiles=VFS.Include('40k_configs/necron_weapon_fx.lua')
local originals=profiles.SourceTexturesReady(VFS)
local fallback={arc='shot',beam='shot',ring='laserend',fractal='laserend',sparks='gunshotglow'}
local function tex(key)return originals and '40k_necron_source_'..key or fallback[key]end
-- Literal source muzzle colours149/223/116 and132/223/101 normalized to0–1.
local green='.584 .875 .455 .32  .518 .875 .396 .20  .08 .42 .04 .06  0 0 0 0'
local white='.94 1 .91 .30  .58 .90 .45 .16  .08 .38 .025 .04  0 0 0 0'
local dark='.025 .12 .015 .14  .01 .045 .005 .05  0 0 0 0'
local function pulse(scale)
 return {class='CBitmapMuzzleFlame',count=1,air=true,ground=true,water=true,unit=true,nounit=true,underwater=false,
 properties={dir='dir',fronttexture=tex('fractal'),sidetexture=tex('arc'),colormap=green,size=.42*scale,length=1.6*scale,ttl=8,sizegrowth=-.025*scale,frontoffset=0,useairlos=true}}
end
local function flecks(texture,n,size,life,speed,color,growth)
 return {class='CSimpleParticleSystem',count=1,air=true,ground=true,water=true,unit=true,nounit=true,underwater=false,
 properties={airdrag=.90,colormap=color,directional=false,emitrot=0,emitrotspread=45,emitvector='dir',gravity='0, 0, 0',numparticles=n,
 particlelife=life,particlelifespread=0,particlesize=size,particlesizespread=size*.15,particlespeed=speed,particlespeedspread=speed*.2,
 pos='0, 0, 0',sizegrowth=growth or 0,sizemod=1,texture=texture,useairlos=true}}
end
local definitions={}
for family,p in pairs(profiles.Profiles)do
 local s=p.scale
 local hit={usedefaultexplosions=false,glow=flecks(tex('fractal'),1,.8*s,8,0,white,-.05*s),sparks=flecks(tex('sparks'),p.contact_only and 3 or 2,.15*s,6,.35,green,-.02*s)}
 if p.contact_only then hit.corona=flecks(tex('ring'),1,.4*s,10,0,green,.07*s)
 elseif family=='particle_whip' then
  -- Source main crystal graph includes green/white beams, expanding rings and
  -- dark corona. Compact contact keeps those identities without38source layers.
  hit.corona=flecks(tex('ring'),1,.55*s,15,0,green,.10*s)
  hit.darkhalo=flecks(tex('ring'),1,.65*s,12,0,dark,.07*s)
 end
 definitions['40k_necron_'..family..'_impact']=hit
 if not p.contact_only then
  local muzzle={usedefaultexplosions=false,pulse=pulse(s),glint=flecks(tex('fractal'),1,.28*s,7,0,white,-.02*s)}
  if family=='particle_whip' or family=='particle_projector'then muzzle.corona=flecks(tex('ring'),1,.28*s,10,0,green,.045*s)end
  definitions['40k_necron_'..family..'_muzzle']=muzzle
 end
end
return definitions
