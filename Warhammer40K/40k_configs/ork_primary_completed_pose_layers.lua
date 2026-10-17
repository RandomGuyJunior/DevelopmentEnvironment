-- Source-informed native completed-pose layering. Optional root-owned integration.
-- Source action priority adaptation is explicit; no original-engine blend claim.
return function(data,profile,sample,buffers)
 assert(data and profile and sample and buffers,'Completed-pose dependencies missing')
 local bySource={}
 for _,clip in pairs(data.clips)do bySource[clip.source]=clip end
 for _,layer in ipairs(profile.layers)do
  local clip=assert(bySource[layer.source],'Declared completed-pose clip missing: '..layer.source)
  assert(clip.keyed_channels and #clip.keyed_channels==#data.bones,'Source channel mask missing')
 end
 return function(base,age,mode)
  if mode~='idle' and mode~='walk' and mode~='anchors' then return base end
  local row=base
  for index,layer in ipairs(profile.layers)do
   if mode~='anchors' or layer.anchor then
   local clip=bySource[layer.source]
   local time=layer.normalized and clip.duration*layer.normalized or age
   row=buffers.Overlay(clip,sample(clip,time,layer.normalized==nil),row,'completedlayer'..index)
   end
  end
  return row
 end
end
