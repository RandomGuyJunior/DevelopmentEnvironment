function widget:GetInfo()
 return {name="40K opt-in test lifecycle",desc="Close only explicitly bounded diagnostic/demo games",author="Local project",layer=1003,enabled=true}
end
local options=Spring.GetModOptions()
-- This explicit cargo fixture owns its success/failure timeout and replay closure.
if options.prototype_diagnostic=='roster' and tostring(options.prototype_transport_review)=='1' then return end
local mode=options.prototype_diagnostic
local endFrame=tonumber(options.prototype_test_end_frame) or 0
if mode==nil or mode=="normal" or mode=="benchmark" or endFrame<=0 then return end
local sent=false
local speedSet=false
local testSpeed=math.max(1,math.min(3,tonumber(options.prototype_test_speed) or 1))
function widget:Update()
 local frame=Spring.GetGameFrame()
 if not speedSet and frame>=30 then
  speedSet=true
  if testSpeed>1 then Spring.SendCommands("setspeed "..testSpeed);Spring.Echo("40K TEST SPEED",testSpeed) end
 end
 -- Give the synced observer a full frame to flush its final evidence first.
 if not sent and frame>=endFrame+1 then
  sent=true
  Spring.Echo("40K TEST COMPLETE",mode,frame,"native replay finalisation")
  Spring.SendCommands("quitforce")
 end
end
