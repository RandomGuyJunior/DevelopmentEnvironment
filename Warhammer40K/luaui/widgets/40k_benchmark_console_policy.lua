function widget:GetInfo()
 return {name='40K benchmark diagnostic console policy',desc='Keep structured benchmark records in native evidence, outside Chat repaint',author='Local project',layer=-94000,enabled=true,handler=true}
end
local options=Spring.GetModOptions()
local mode=options.prototype_diagnostic
local mixedV2=VFS.Include('40k_configs/mixed_v2_adapter.lua').Enabled(options)
local benchmark=mode=='benchmark' or mode=='combatbenchmark' or mixedV2
local walkReview=tostring(options.prototype_walk_sampling_review or '0')=='1'
 and tostring(options.prototype_animation_interpolation or '0')=='1'
 and tostring(options.prototype_fractional_walk_sampling or '0')=='1'
if not benchmark and not walkReview then return end
local prefixes={'40K_BENCH {','40K_FRAME_BUDGET {','40K_COMBAT_BENCH {','40K_NATIVE_PROFILE {','40K_WIDGET_PROFILE {'}
if mode=='benchmark' and tostring(options.prototype_mixed_force or '0')=='1' then prefixes[#prefixes+1]='40K_MIXED_BENCH {' end
-- WALK_STRUCTURED_CHAT_POLICY: retain malformed/non-machine diagnostic messages.
local function walkRecord(line)
 local tokens={};for token in line:gmatch('%S+')do tokens[#tokens+1]=token end
 local first,last,source,id,frame
 if tokens[1]~='40K' or tokens[2]~='WALK' then return false end
 if tokens[3]=='SOURCE' and #tokens==10 then source,id,frame=tokens[4],tokens[5],tokens[6];first,last=7,10
 elseif tokens[3]=='AFTER' and tokens[4]=='SIM' and #tokens==14 then source,id,frame=tokens[5],tokens[6],tokens[7];first,last=8,14
 elseif tokens[3]=='NATIVE' and #tokens>=23 then source,id,frame=tokens[4],tokens[5],tokens[6];first,last=#tokens-15,#tokens
 else return false end
 if not line:match('^40K WALK ') or not source:match('^[%w_%-]+$') or not id:match('^%d+$') or not frame:match('^%d+$') then return false end
 for i=first,last do if not tonumber(tokens[i]) then return false end end
 return true
end
if mixedV2 then prefixes[#prefixes+1]='40K_MIXED_V2 {'end
local owner,original,wrapper,stopped
local function restore()
 if owner and owner.AddConsoleLine==wrapper then owner.AddConsoleLine=original end
 owner,original,wrapper=nil,nil,nil
end
local function sync()
 if stopped then return end
 local chat=widgetHandler:FindWidget('Chat')
 if chat==owner and chat and chat.AddConsoleLine==wrapper then return end
 restore()
 if not chat or type(chat.AddConsoleLine)~='function' then return end
 owner,original=chat,chat.AddConsoleLine
 local saved=original
 wrapper=function(self,lines,priority,...)
  -- Unknown severity, errors, warnings, and non-string inputs retain the exact
  -- original call. Echo uses NOTICE; INFO is another normal record severity.
  if stopped or type(lines)~='string' or not LOG or (priority~=LOG.INFO and priority~=LOG.NOTICE) then return saved(self,lines,priority,...) end
  local header,body=lines:match('^(%[f=[0-9]+%] )(.*)$')
  body=body or lines
  local kept,removed={},false
  for line in (body..'\n'):gmatch('(.-)\n') do
   local owned=false
   if benchmark then for _,prefix in ipairs(prefixes) do if line:sub(1,#prefix)==prefix then owned=true;break end end end
   if not owned and walkReview then owned=walkRecord(line) end
   if owned then removed=true else kept[#kept+1]=line end
  end
  if not removed then return saved(self,lines,priority,...) end
  if #kept==0 then return end
  return saved(self,(header or '')..table.concat(kept,'\n'),priority,...)
 end
 owner.AddConsoleLine=wrapper
end
function widget:Initialize() sync() end
function widget:Update() sync() end
function widget:Shutdown() stopped=true;restore() end
