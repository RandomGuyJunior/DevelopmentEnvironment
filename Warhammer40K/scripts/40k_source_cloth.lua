-- Optional copied-source cloth composition. Explicit bone ownership only.
return function(data,params,buffers,sample,warn)
 local selected={}
 for name in tostring(params.source_cloth_bones or ''):gmatch('[^,;]+')do selected[name:match('^%s*(.-)%s*$')]=true end
 if not next(selected)then return nil end
 local clips={}
 for _,mode in ipairs({'idle','walk','melee'})do
  local label=params['source_cloth_'..mode..'clip']
  local clip=label and data.clips[label]
  if clip and clip.keyed_channels then
   local mask={keyed_channels={}};local count=0
   for i,name in ipairs(data.bones)do
    local m=clip.keyed_channels[i]
    local p=selected[name] and m and m.position or false
    local r=selected[name] and m and m.rotation or false
    mask.keyed_channels[i]={position=p,rotation=r}
    if p or r then count=count+1 end
   end
   if count>0 then clips[mode]={clip=clip,mask=mask}
   else warn('cloth:'..mode,'Cloth source has no configured keyed bones: '..tostring(label))end
  elseif label then warn('cloth:'..mode,'Cloth source clip/mask missing: '..tostring(label))end
 end
 if not next(clips)then return nil end
 return function(row,mode,age)
  -- Full-body special actions retain complete ownership.
  if mode=='transition' or mode=='jump' or mode=='build'then return row end
  local c=clips[mode=='walk' and 'walk' or mode=='melee' and 'melee' or 'idle']
  if not c then return row end
  return buffers.Overlay(c.mask,sample(c.clip,age,mode~='melee'),row,'cloth')
 end
end
