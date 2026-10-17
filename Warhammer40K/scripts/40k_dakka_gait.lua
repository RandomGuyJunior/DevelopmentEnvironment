-- Exact paired Dakka only. Source body/lift poses are retained; planted boots
-- travel backwards by precisely the distance advanced by the native mover.
-- This locomotion clock never changes simulation, weapon or research clocks.
local M={Policy='dakka_distance_locked_boots_v1',SpeedFraction=.9,
 Model='ork_dakka_stompa_jugref.glb',ModelSHA256='184bb884ba03f5ceef1dda85cdbb4648527a5f9e89f1b45928cb4f7538f50748',
 Bank='ork_dakka_stompa_jugref',Factor=.7060140223403837,
 Front=14.112013022606067,Back=-7.068407647605444}
M.Span=M.Front-M.Back;M.CycleDistance=2*M.Span
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
function M.ApplyUnits(defs)
 local d=defs.ork_dakka_stompa
 if not d or d.objectname~=M.Model then return false end
 local c=d.customparams or{};local r=assert(defs.corkorg,'Original Juggernaut reference required')
 assert(c.animsource=='ork_dakka_stompa'and c.ork_v14_scale_bank==M.Bank
  and tonumber(c.ork_v14_scale_factor)==M.Factor and c.source_native_glb_sha256==M.ModelSHA256,'Exact paired Dakka gait identity required')
 assert(r.objectname:lower()=='units/corkorg.s3o'and r.script:lower()=='units/corkorg.cob'
  and finite(r.speed)and r.speed>0,'Actual original corkorg speed required')
 assert(not c.source_dakka_gait_policy,'Duplicate Dakka gait owner')
 d.speed=r.speed*M.SpeedFraction
 c.source_dakka_gait_policy=M.Policy;c.source_dakka_gait_cycle_distance=M.CycleDistance
 c.source_dakka_reference_speed=r.speed;c.source_dakka_speed_fraction=M.SpeedFraction
 d.customparams=c
 return true
end
function M.New(source,cp,data,V)
 if not cp.source_dakka_gait_policy then return nil end
 assert(source=='ork_dakka_stompa'and cp.source_dakka_gait_policy==M.Policy
  and cp.ork_v14_scale_bank==M.Bank and tonumber(cp.ork_v14_scale_factor)==M.Factor
  and cp.source_native_glb_sha256==M.ModelSHA256
  and tonumber(cp.source_dakka_gait_cycle_distance)==M.CycleDistance,'Unknown Dakka gait pairing')
 local meta=data.scaleDerivative;local walk=assert(data.clips.walk,'Genuine Dakka move clip required')
 assert(meta and meta.factor==M.Factor and meta.recipe=='translation-only-v1'
  and meta.baseSha256=='b5f8b69e34c562ab04b07406229b33c904336270c3d59869a5d938bba59c6810'
  and walk.source=='move'and #walk.frames==21 and walk.source_fps==30,'Exact retained Dakka walk bank required')
 local sampler=V.Include('scripts/40k_walk_sampler.lua')()
 local indices={};for i,name in ipairs(data.bones)do indices[name]=i end
 local duration=#walk.frames/walk.source_fps;local unique=#walk.frames-1
 local boots={
  {name='bone_leg_left',start=.75,liftFirst=5,liftCount=10},
  {name='bone_leg_right',start=.25,liftFirst=12,liftCount=14},
 }
 local function at(index,frame,axis)
  local f=frame%unique;local i=math.floor(f);local t=f-i
  return walk.frames[i+1][index][axis]*(1-t)+walk.frames[(i+1)%unique+1][index][axis]*t
 end
 for _,b in ipairs(boots)do
  b.index=assert(indices[b.name],'Actual independent Dakka boot missing');b.ground=math.huge
  local lo,hi=math.huge,-math.huge
  for _,row in ipairs(walk.frames)do
   b.ground=math.min(b.ground,row[b.index][2]);lo=math.min(lo,row[b.index][3]);hi=math.max(hi,row[b.index][3])
  end
  assert(math.abs(lo-M.Back)<1e-4 and math.abs(hi-M.Front)<1e-4,'Changed source boot stride')
  b.liftStart=at(b.index,b.liftFirst,2);b.liftEnd=at(b.index,b.liftFirst+b.liftCount,2)
 end
 local outputs={{},{}};local outputIndex=0
 local api={StrideSpeed=M.CycleDistance/duration,CycleDistance=M.CycleDistance,Duration=duration}
 function api.Sample(age)
  assert(finite(age)and age>=0,'Finite Dakka gait phase required')
  local phase=(age/duration)%1
  -- Remove only the duplicated final endpoint hold; every body keypose and
  -- quaternion interpolation still comes from the genuine source move clip.
  local row=sampler(walk,phase*unique/walk.source_fps)
  outputIndex=outputIndex%2+1;local out=outputs[outputIndex]
  for i,v in ipairs(row)do
   local w=out[i]or{};out[i]=w;for a=1,6 do w[a]=v[a]end
  end
  for _,b in ipairs(boots)do
   local u=(phase-b.start)%1;local w=out[b.index]
   if u<.5 then
    w[2]=b.ground;w[3]=M.Front-M.Span*(u*2)
   else
    local t=(u-.5)*2
    local y=at(b.index,b.liftFirst+t*b.liftCount,2)
    w[2]=b.ground+math.max(0,y-(b.liftStart*(1-t)+b.liftEnd*t))
    -- Hermite return joins the planted velocity at BOTH ends. Its small
    -- overshoot is checked against actual boot geometry/selection bounds.
    w[3]=M.Back+M.Span*(-4*t*t*t+6*t*t-t)
   end
  end
  return out
 end
 return api
end
return M
