-- Measured source stride coupled to world travel; normal play only.
-- Does not touch animation evaluation, simulation, weapons, construction or research.
local M={}
local function finite(v)return type(v)=='number'and v==v and v<math.huge and v>-math.huge end
function M.Apply(defs,options,policy,tuning)
 if not policy.Enabled(options)then return{applied=0,uncalibrated={}}end
 local result={applied=0,uncalibrated={}}
 for key,d in pairs(defs)do
  local cp=d.customparams or{};local row=tuning[cp.animsource]
  if row and tonumber(d.speed)and d.speed>0 and d.canmove~=false then
   if row.contacts>0 and finite(row.stride)and row.stride>0 and finite(row.rate)and row.rate>0 then
    cp.locomotion_previous_speed=cp.locomotion_previous_speed or d.speed
    d.speed=row.stride*row.rate
    cp.locomotion_source_stride=row.stride;cp.locomotion_playback=row.rate
    cp.locomotion_clip=row.clip;cp.locomotion_contact_samples=row.contacts
    cp.locomotion_policy='natural_source_stride_v1';d.customparams=cp
    result.applied=result.applied+1
   else result.uncalibrated[#result.uncalibrated+1]=key end
  end
 end
 table.sort(result.uncalibrated)
 return result
end
return M
