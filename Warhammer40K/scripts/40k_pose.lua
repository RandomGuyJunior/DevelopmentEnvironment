-- Full-fidelity pose composition with per-actor reusable storage.
-- Never mutate immutable generated frames. Snapshot before retaining a pose
-- across ticks, because composition destinations are deliberately reused.
return function(data, armBones, tolerances)
 tolerances=tolerances or {}
 local function threshold(value)
  return type(value)=="number" and value>=0 and value<math.huge and value or .000001
 end
 local moveThreshold=threshold(tolerances.translation)
 local turnThreshold=threshold(tolerances.rotation)
 local slots={}
 local masks={}
 local abs,pi=math.abs,math.pi
 local function destination(name,row)
  local out=slots[name]
  if not out then
   out={};for i=1,#row do out[i]={} end;slots[name]=out
  end
  return out
 end
 local api={}
 function api.Snapshot(row,name)
  if not row then return nil end
  local out=destination(name or 'snapshot',row)
  for i=1,#row do
   local v,w=row[i],out[i]
   w[1],w[2],w[3],w[4],w[5],w[6]=v[1],v[2],v[3],v[4],v[5],v[6]
  end
  return out
 end
 function api.Overlay(clip,row,base,name)
  local mask=clip.keyed_channels
  if not mask then return row end
  local out=destination(name or 'overlay',row)
  for i=1,#row do
   local v,b,w,m=row[i],base[i],out[i],mask[i]
   local p=m.position and v or b
   local r=m.rotation and v or b
   w[1],w[2],w[3],w[4],w[5],w[6]=p[1],p[2],p[3],r[4],r[5],r[6]
  end
  return out
 end
 function api.Arms(row,gunRow,clip,name)
  local mask=masks[clip]
  if not mask then
   mask={};masks[clip]=mask
   for i=1,#row do
    local m=clip.keyed_channels and clip.keyed_channels[i]
    mask[i]={armBones[i] and (not m or m.position),armBones[i] and (not m or m.rotation)}
   end
  end
  local out=destination(name or 'arms',row)
  for i=1,#row do
   local v,g,w,m=row[i],gunRow[i],out[i],mask[i]
   local p=m[1] and g or v
   local r=m[2] and g or v
   w[1],w[2],w[3],w[4],w[5],w[6]=p[1],p[2],p[3],r[4],r[5],r[6]
  end
  return out
 end
 function api.Blend(row,from,alpha,name)
  local out=destination(name or 'blend',row)
  for i=1,#row do
   local v,b,w=row[i],from[i],out[i]
   for a=1,3 do w[a]=b[a]+(v[a]-b[a])*alpha end
   for a=4,6 do w[a]=b[a]+((v[a]-b[a]+pi)%(2*pi)-pi)*alpha end
  end
  return out
 end
 local applied={}
 function api.Apply(row,bones,move,turn,interpolate)
  for i=1,#row do
   local v,previous=row[i],applied[i]
   if not previous then previous={};applied[i]=previous end
   local moveAxis,turnAxis
   for a=1,3 do
    if previous[a]==nil or abs(previous[a]-v[a])>moveThreshold then
     move(bones[i],a,v[a])
     -- Equal-target native animation clears noInterpolation at end of frame;
     -- the immediate source pose remains available to native weapons now.
     if interpolate and previous[a]~=nil then moveAxis=a end
     previous[a]=v[a]
    end
    if previous[a+3]==nil or abs(previous[a+3]-v[a+3])>turnThreshold then
     local accepted=turn(bones[i],a,v[a+3])
     if interpolate and previous[a+3]~=nil and accepted~=false then turnAxis=a end
     previous[a+3]=v[a+3]
    end
   end
   -- Native noInterpolation is per position/rotation VECTOR, not per axis.
   -- One accepted equal-target native animation clears each whole flag.
   if moveAxis then move(bones[i],moveAxis,v[moveAxis],1) end
   if turnAxis then turn(bones[i],turnAxis,v[turnAxis+3],1) end
  end
 end
 return api
end
