-- V01 funded/non-economy scene only. No LOS, weapon, aim or physics writes.
local M={Version=1,MapName="Martyr's Gate 0.1"}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function positive(v)return finite(v)and v>0 end
local function shape(d)
 local c=d and d.collisionVolume
 if not d or not positive(d.xsize)or d.xsize%1~=0 or not positive(d.zsize)or d.zsize%1~=0 or not positive(d.radius)or type(c)~='table'then return end
 for _,k in ipairs({'scaleX','scaleY','scaleZ'})do if not positive(c[k])then return end end
 for _,k in ipairs({'offsetX','offsetY','offsetZ'})do if not finite(c[k])then return end end
 -- Circumscribed horizontal radius also covers any natural facing rotation.
 return math.max(math.sqrt((d.xsize*4)^2+(d.zsize*4)^2),d.radius,
  math.sqrt((math.abs(c.offsetX)+c.scaleX*.5)^2+(math.abs(c.offsetZ)+c.scaleZ*.5)^2))+16
end
function M.New(S,D,W,N,G,keys,emit)
 local C={cursor=0,used={},nativeAccepted=false,funded=true,economyAcceptance=false}
 local function refuse(why)C.reason=why;return nil,why end
 if G.mapName~=M.MapName or G.mapSizeX~=4096 or G.mapSizeZ~=4096 then return refuse('exclusive_approved_map_required')end
 for _,k in ipairs({'GetGroundHeight','GetGroundNormal','TestMoveOrder','GetAllUnits','GetAllFeatures','GetUnitPosition','GetUnitRadius','GetUnitCollisionVolumeData','GetFeaturePosition','GetFeatureRadius','GetFeatureCollisionVolumeData'})do
  if type(S[k])~='function'then return refuse('native_scene_API_'..k)end
 end
 C.shapes={};local tn=N.imp_russ;local td=tn and D[tn.id];local tr=shape(td)
 if not tr or not keys or #keys~=4 then return refuse('exact_actor_hostile_shapes_required')end
 C.targetDef=tn.id;C.shapes[tn.id]=tr;local halo=math.sqrt(160^2+180^2)+tr;local total=0
 for i,key in ipairs(keys)do
  local n=N[key];local d=n and D[n.id];local r=shape(d);local cp=d and d.customParams or{};local sight=d and(d.sightDistance or d.losRadius)
  if not r or not positive(sight)or cp.animsource~=key or type(d.weapons)~='table'or #d.weapons~=(i==4 and 4 or 2)then return refuse('exact_four_ten_mount_actors_required')end
  C.shapes[n.id]=r;halo=math.max(halo,r)
  for _,e in ipairs(d.weapons)do local w=W[e.weaponDef]
   if not w or not positive(w.range)or not({Cannon=true,LaserCannon=true,MissileLauncher=true})[w.type]then return refuse('actual_native_mount_range_required')end
   halo=math.max(halo,math.min(w.range*.55,sight*.75)+tr);total=total+1
  end
 end
 if total~=10 or halo>512 then return refuse('bounded_ten_mount_envelope_required')end
 C.halo=math.ceil(halo/8)*8;C.anchors={}
 -- Source-proven flat-pad centers first; near-pad anchors remain dynamic full-grid
 -- candidates, never assumed flat from a center sample. Every anchor consumed once.
 for _,x in ipairs({640,3456})do for _,dz in ipairs({0,-64,64,-128,128})do for _,dx in ipairs({0,-64,64,-128,128})do C.anchors[#C.anchors+1]={x+dx,2048+dz}end end end
 local function flat(x,z,r)
  if not finite(x)or not finite(z)or x-r<160 or z-r<160 or x+r>G.mapSizeX-160 or z+r>G.mapSizeZ-160 then return false,'map_full_envelope' end
  local lo,hi=math.huge,-math.huge
  -- Native 8-unit vertices in complete intersected cells plus exact box corners.
  local xs,zs={x-r,x+r},{z-r,z+r}
  for q=math.floor((x-r)/8)*8,math.ceil((x+r)/8)*8,8 do xs[#xs+1]=q end
  for q=math.floor((z-r)/8)*8,math.ceil((z+r)/8)*8,8 do zs[#zs+1]=q end
  for _,sx in ipairs(xs)do for _,sz in ipairs(zs)do
   local y=S.GetGroundHeight(sx,sz);local nx,ny,nz,slope=S.GetGroundNormal(sx,sz,true)
   if not finite(y)or y<=0 or not finite(nx)or not finite(ny)or not finite(nz)or not finite(slope)or ny<=0 or ny>1.001 or slope<0 or slope>.001 then return false,'native_flat_ground_normal' end
   lo=math.min(lo,y);hi=math.max(hi,y);if hi-lo>.125 then return false,'native_full_grid_height_span' end
  end end
  return true
 end
 local function nativeRadius(kind,id)
  local r=S['Get'..kind..'Radius'](id);local cv={S['Get'..kind..'CollisionVolumeData'](id)}
  if not positive(r)or #cv~=10 or type(cv[10])~='boolean'then return end
  for i=1,9 do if not finite(cv[i])then return end end
  if cv[1]<=0 or cv[2]<=0 or cv[3]<=0 then return end
  return math.max(r,math.sqrt((math.abs(cv[4])+cv[1]*.5)^2+(math.abs(cv[6])+cv[3]*.5)^2))+16
 end
 local function clear(x,z,r,ignore)
  for _,kind in ipairs({'Unit','Feature'})do
   local ids=S['GetAll'..kind..'s']();if type(ids)~='table'or #ids>(kind=='Unit'and 512 or 2048)then return false,'native_object_inventory_unavailable' end
   for i,id in ipairs(ids)do
    if not finite(id)or id<0 or id%1~=0 then return false,'native_object_identity' end
    if kind~='Unit'or id~=ignore then
     local ox,oy,oz=S['Get'..kind..'Position'](id);local rr=nativeRadius(kind,id)
     if not finite(ox)or not finite(oy)or not finite(oz)or not rr then return false,'native_object_shape_unavailable' end
     if (ox-x)^2+(oz-z)^2<(r+rr)^2 then return false,'native_foreign_'..kind..'_overlap' end
    end
   end
   -- Reject sparse/malformed maps: a missing native entry cannot mean clear.
   for k in pairs(ids)do if not finite(k)or k%1~=0 or k<1 or k>#ids then return false,'native_object_array_shape' end end
  end
  return true
 end
 function C.Legal(def,x,z,ignore)
  local r=C.shapes[def];if not r or not C.x or not finite(x)or not finite(z)then return false,'scene_not_selected_or_definition' end
  if math.abs(x-C.x)+r>C.halo or math.abs(z-C.z)+r>C.halo then return false,'full_body_outside_verified_scene' end
  local ok,why=flat(x,z,r);if not ok then return false,why end
  ok,why=clear(x,z,r,ignore);if not ok then return false,why end
  if S.TestMoveOrder(def,x,S.GetGroundHeight(x,z),z,0,0,0,true,true,false)~=true then return false,'native_move_order' end
  return true
 end
 function C.Choose(def)
  local r=C.shapes[def];if not r or def==C.targetDef then return nil,nil,'exact_actor_definition_required' end
  while C.cursor<#C.anchors do
   C.cursor=C.cursor+1;local p=C.anchors[C.cursor];local x,z=p[1],p[2];local ok,why=flat(x,z,C.halo)
   if ok then ok,why=clear(x,z,r)end
   if ok then ok=S.TestMoveOrder(def,x,S.GetGroundHeight(x,z),z,0,0,0,true,true,false)==true;why='native_actor_move_order'end
   if ok then
    C.x,C.z=x,z;C.used[C.cursor]=true
    if emit then emit('FLAT_SCENE candidate='..C.cursor..' x='..x..' z='..z..' halo='..C.halo..' mounts=10 full_native_8_grid=true funded=true economy_acceptance=false native_fire_acceptance=false')end
    return x,z
   end
   if emit then emit('FLAT_SCENE_REFUSAL candidate='..C.cursor..' reason='..tostring(why))end
  end
  return nil,nil,'no_unused_full_flat_native_actor_scene'
 end
 return C
end
return M
