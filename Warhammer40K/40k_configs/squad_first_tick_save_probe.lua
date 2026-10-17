-- Optional diagnostic boundary, never the exact unchanged-frame save gate.
local M={}
local function copy(v)
 if type(v)~='table'then return v end
 local t={};for k,x in pairs(v)do t[k]=copy(x)end;return t
end
local function equal(a,b)
 if type(a)~=type(b)then return false end
 if type(a)~='table'then return a==b end
 for k,v in pairs(a)do if not equal(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end;return true
end
function M.Schedule(enabled,Script,S,baseline,read,notify)
 if not enabled then return nil end
 assert(type(baseline)=='table'and type(baseline.frame)=='number'and baseline.frame==S.GetGameFrame(),'seal frame required')
 assert(type(read)=='function'and type(notify)=='function'and type(Script.DelayByFrames)=='function','actual diagnostic interfaces required')
 local sealed=copy(baseline);local expected=sealed.frame+1;local status='scheduled';local observed;local reason
 local function wake()
  if status~='scheduled'then return end
  local frame=S.GetGameFrame()
  if frame~=expected then status='refused';reason='unexpected_first_tick_frame'
  else
   local current,why=read(frame);observed=copy(current)
   if type(current)~='table'or current.frame~=expected then status='refused';reason=why or'missing_current_native_state'
   else
    local same=true
    -- Only the explicitly expected TOP-LEVEL native frame differs. Neither
    -- snapshot is rewritten; all nested jobs/generations/times must match.
    for k,v in pairs(sealed)do if k~='frame'and not equal(v,current[k])then same=false;reason='state_changed_'..tostring(k);break end end
    for k in pairs(current)do if sealed[k]==nil then same=false;reason='unexpected_field_'..tostring(k);break end end
    status=same and'matched_first_tick_native_load_witness_required'or'refused'
   end
  end
  notify({status=status,reason=reason,restoredFrame=sealed.frame,expectedFrame=expected,observedFrame=frame,exactCheckpointPassed=false,nativeResumeAccepted=false})
 end
 Script.DelayByFrames(1,wake)
 return {Read=function()return{status=status,reason=reason,sealed=copy(sealed),observed=copy(observed),expectedFrame=expected,exactCheckpointPassed=false,nativeResumeAccepted=false}end}
end
return M
