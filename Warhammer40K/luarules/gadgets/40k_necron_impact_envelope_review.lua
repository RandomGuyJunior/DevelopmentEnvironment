-- Read-only native impact envelope receipts; never changes damage or presentation.
function gadget:GetInfo()return {name='40K Necron impact envelope observer',desc='Source review only actual native impact geometry',author='Local project',layer=111,enabled=true}end
if not gadgetHandler:IsSyncedCode()then return false end
local o=Spring.GetModOptions()or{}
local paid=o.prototype_source_acceptance=='necrons'and o.prototype_diagnostic=='expandedproduction'
local point=o.prototype_diagnostic=='roster'and o.prototype_roster_filter=='nec_nightbringer'and tonumber(o.prototype_test_speed or 1)==1
if not VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(o.prototype_source_progression)or not(paid or point)then return false end
local watched={};local impacts={};local count=0;local truncated=false
local function emit(...)Spring.Echo('40K NEC IMPACT ENVELOPE',Spring.GetGameFrame(),...)end
local function finite(x)return type(x)=='number'and x==x and math.abs(x)<math.huge end
local function vgood(v)return type(v)=='table'and finite(v[1])and finite(v[2])and finite(v[3])end
local function cylinder(p,half,axis)
 local a=axis+1;local b=a%3+1;local c=b%3+1
 if math.abs(half[b]-half[c])>1e-6 then return nil end
 local radial=math.sqrt(p[b]^2+p[c]^2);local dr=math.max(0,radial-half[b]);local da=math.max(0,math.abs(p[a])-half[a])
 return math.sqrt(dr*dr+da*da)
end
local function snapshot(id,x,y,z)
 local def=Spring.GetUnitDefID(id);local d=def and UnitDefs[def]
 if not d then emit('ACTOR_UNKNOWN',id);return end
 local sx,sy,sz,ox,oy,oz,kind,test,axis,disabled=Spring.GetUnitCollisionVolumeData(id)
 local px,py,pz,mx,my,mz=Spring.GetUnitPosition(id,true)
 local front,up,right=Spring.GetUnitVectors(id)
 emit('ACTOR',id,def,d.name,'base',px,py,pz,'mid',mx,my,mz,'volume',sx,sy,sz,ox,oy,oz,kind,test,axis,disabled,
 'flank',d.flankingBonusMode,d.flankingBonusMin,d.flankingBonusMax)
 if not(vgood(front)and vgood(up)and vgood(right))then emit('BASIS_UNKNOWN',id);return end
 emit('BASIS',id,'front',front[1],front[2],front[3],'up',up[1],up[2],up[3],'right',right[1],right[2],right[3])
 if not(finite(mx)and finite(my)and finite(mz)and finite(ox)and finite(oy)and finite(oz))then return end
 local cx=mx+right[1]*ox+up[1]*oy+front[1]*oz;local cy=my+right[2]*ox+up[2]*oy+front[2]*oz;local cz=mz+right[3]*ox+up[3]*oy+front[3]*oz
 local dx,dy,dz=x-cx,y-cy,z-cz
 local p={dx*right[1]+dy*right[2]+dz*right[3],dx*up[1]+dy*up[2]+dz*up[3],dx*front[1]+dy*front[2]+dz*front[3]}
 local distance;local metric='circular_cylinder_surface_distance'
 if kind==3 and finite(sx)and finite(sy)and finite(sz)and sx>0 and math.abs(sx-sy)<=1e-6 and math.abs(sx-sz)<=1e-6 then
  distance=math.max(0,math.sqrt(p[1]^2+p[2]^2+p[3]^2)-sx/2);metric='sphere_surface_distance'
 end
 if kind==1 and finite(sx)and finite(sy)and finite(sz)and sx>0 and sy>0 and sz>0 and axis and axis>=0 and axis<=2 then distance=cylinder(p,{sx/2,sy/2,sz/2},axis)end
 emit('STANDARD_ENVELOPE',id,'center',cx,cy,cz,'local_impact',p[1],p[2],p[3],metric,distance or 'unknown','piece_volume_not_proven',true)
end
function gadget:Initialize()
 for id,w in pairs(WeaponDefs)do
  if w.name=='nec_nightbringer_scythe_ranged' then watched[id]=true;Script.SetWatchExplosion(id,true)end
 end
end
function gadget:Explosion(weapon,x,y,z,owner,projectile)
 if not watched[weapon]or not owner or not(finite(x)and finite(y)and finite(z))then return false end
 local def=Spring.GetUnitDefID(owner)
 if not def or UnitDefs[def].name~='nec_nightbringer'then return false end
 if count>=16 then if not truncated then truncated=true;emit('TRUNCATED',16)end;return false end
 count=count+1
 local w=WeaponDefs[weapon];local f=Spring.GetGameFrame()
 impacts[projectile]={frame=f,weapon=weapon,owner=owner};emit('EXPLOSION',weapon,projectile,owner,x,y,z,'native_policy',w.noSelfDamage,w.impactOnly,w.damageAreaOfEffect,'engine_min_radius',math.max(1,w.damageAreaOfEffect or 0))
 snapshot(owner,x,y,z)
 local targetType,_,target=Spring.GetUnitWeaponTarget(owner,1)
 emit('CURRENT_TARGET',owner,targetType,targetType==1 and target or 'not_unit')
 if targetType==1 and target and target~=owner then snapshot(target,x,y,z)end
 return false -- Must never suppress the native explosion/CEG.
end
function gadget:UnitDamaged(id,def,team,damage,paralyzer,weapon,projectile,attacker)
 local r=impacts[projectile]
 if not r or r.weapon~=weapon or r.frame~=Spring.GetGameFrame()then return end
 emit('SAME_IMPACT_DAMAGE',projectile,weapon,id,attacker,damage,paralyzer,'self',id==attacker,'recorded_owner',r.owner)
end
function gadget:GameFrame(f)for id,r in pairs(impacts)do if f-r.frame>2 then impacts[id]=nil end end end
