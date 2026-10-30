-- Unit-local simulation-frame scheduler, with bounded abandoned reservations.
return function()
 local owner,untilFrame,lastGroup=nil,-1,nil
 local preferredUntil=-1
 local chargeStart,chargeReady=nil,false
 local function group(n)return n>=2 and n<=3 and n or nil end
 local api={}
 function api.Block(n,frame)
  local g=group(n);if not g then return false end
  if chargeStart and g~=2 then return true end
  if frame<untilFrame and owner~=g then return true end
  if frame>=untilFrame and lastGroup and g~=(lastGroup==3 and 2 or 3) and frame<preferredUntil then return true end
  if g==2 then
   if not chargeStart then
    chargeStart=frame;chargeReady=false;owner=2;untilFrame=frame+45
    return true
   end
   if frame-chargeStart<45 then return true end
   chargeReady=true
  end
  if frame>=untilFrame then owner,untilFrame=g,frame+2 end
  return false
 end
 function api.Charging()return chargeStart~=nil end
 function api.Expired(frame)return chargeStart and frame-chargeStart>90 end
 function api.Cancel(frame)
  if chargeStart then chargeStart=nil;chargeReady=false;owner=nil;untilFrame=frame+3;lastGroup=2;preferredUntil=untilFrame+12 end
 end
 function api.Fired(n,frame,duration)
  local g=group(n);if not g then return end
  if n==2 then chargeStart=nil;chargeReady=false end
  if owner~=g then untilFrame=frame end
  owner=g;untilFrame=math.max(untilFrame,frame+duration)
  lastGroup=g;preferredUntil=untilFrame+12
 end
 return api
end
