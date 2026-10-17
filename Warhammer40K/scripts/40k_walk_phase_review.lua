-- Opt-in diagnostic; exact selected source phase BEFORE the normal Apply call.
local counts={};local tracked=0
return function(id,source,frame,phase,clip,fractional)
 local vx,_,vz=Spring.GetUnitVelocity(id)
 if not vx or not vz or vx*vx+vz*vz<=.000001 then return end
 local count=counts[id]
 if not count then if tracked>=16 then return end;tracked=tracked+1;count=0 end
 if count>=120 then return end
 counts[id]=count+1
 local fps=clip.source_fps or #clip.frames/clip.duration
 Spring.Echo('40K WALK SOURCE',source,id,frame,string.format('%.17g',phase),
  string.format('%.17g',fps),#clip.frames,fractional and 1 or 0)
 -- The phase itself stays in the exact log; native float rules would round it.
 Spring.SetUnitRulesParam(id,'40k_walk_review_frame',frame,{public=true})
end
