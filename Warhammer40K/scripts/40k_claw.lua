-- Genuine source melee pose controller. Damage is exclusively native WeaponDef Melee.
-- VFS.Include returns a factory; pass data, unitID, params, piece, pose, Sleep.
return function(env)
 local clip=env.data.clips.melee
 local params=env.params or {}
 local weapon=tonumber(params.clawweapon) or 2
 local contact=clip and tonumber(clip.contact_frame)
 local valid=clip and clip.frames and #clip.frames>1 and contact
   and contact==math.floor(contact) and contact>=1 and contact<=#clip.frames
   and clip.duration and clip.duration>0 and params.clawmarker
 local muzzle=valid and env.piece(params.clawmarker) or nil
 local api={enabled=valid and muzzle~=nil,weapon=weapon}
 if not api.enabled then
  Spring.Echo("40K CLAW DISABLED: genuine clip/contact frame/marker missing",env.unitID)
  function api.IsActive() return false end
  function api.UpdatePose() return nil end
  function api.Aim() return false end
  function api.Query() return nil end
  function api.Cancel() end
  function api.Shot() return false end
  return api
 end
 local count=#clip.frames
 local sourceFPS=clip.source_fps or count/clip.duration
 local contactSeconds=(contact-1)/sourceFPS
 local reload=tonumber(params.clawreload) or 2.4
 local pendingStart,impactFrame,nextWindup=nil,nil,0
 local function now() return Spring.GetGameFrame() end
 local function rowAt(seconds)
  return clip.frames[math.min(count,math.max(1,math.floor(seconds*sourceFPS)+1))]
 end
 function api.Query() return muzzle end
 function api.Cancel() pendingStart=nil;impactFrame=nil end
 function api.UpdatePose(frame)
  frame=frame or now()
  if impactFrame then
   local age=contactSeconds+(frame-impactFrame)/30
   if age<=clip.duration then return rowAt(age) end
   impactFrame=nil
  end
  if pendingStart then
   local age=(frame-pendingStart)/30
   -- An engine-cancelled swing does not hold the unit in a permanent attack pose.
   if age>contactSeconds+1.5 then pendingStart=nil;return nil end
   return rowAt(math.min(contactSeconds,age))
  end
  return nil
 end
 function api.IsActive(frame) return api.UpdatePose(frame)~=nil end
 function api.Aim(moving)
  if moving or now()<nextWindup or impactFrame then return false end
  if not pendingStart then pendingStart=now() end
  local remaining=contactSeconds-(now()-pendingStart)/30
  if remaining>0 then env.Sleep(math.ceil(remaining*1000)) end
  if moving or not pendingStart then return false end
  -- Native damage follows the successful Aim callback; Shot stamps actual impact time.
  env.pose(clip.frames[contact])
  return true
 end
 function api.Shot(num)
  if num~=weapon then return false end
  impactFrame=now();pendingStart=nil
  nextWindup=impactFrame+math.ceil(math.max(clip.duration-contactSeconds,reload-contactSeconds)*30)
  env.pose(clip.frames[contact])
  local diagnostic=Spring.GetModOptions().prototype_diagnostic
  if diagnostic and diagnostic~="normal" then
   Spring.Echo("40K CLAW CONTACT",env.unitID,num,impactFrame,contact,clip.source)
  end
  return true
 end
 return api
end
