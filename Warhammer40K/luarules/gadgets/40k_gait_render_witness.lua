function gadget:GetInfo()
 return{name='40K opt-in gait rendered sequence witness',desc='Read-only native camera/screenshot sequence; no FPS acceptance',author='Local project',layer=153,enabled=true}
end
local options=Spring.GetModOptions()or{}
local function enabled(v)return v==true or v==1 or v=='1'end
if not(enabled(options.prototype_gait_movement_fixture)and enabled(options.prototype_animation_interpolation)and enabled(options.prototype_fractional_walk_sampling))then return false end
if gadgetHandler:IsSyncedCode()then return false end
local session,original,restored,used;local captures=0
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function note(event,...)
 local row=session or{};local a={...};for i=1,#a do a[i]=tostring(a[i])end
 Spring.Echo('40K_GAIT_RENDER '..event..' id='..tostring(row.id)..' actor='..tostring(row.actor)..' bank='..tostring(row.bank)..' factor='..tostring(row.factor)..' frame='..tostring(Spring.GetGameFrame())..' captures='..captures..' '..table.concat(a,' ')..' fps_acceptance=false continuous_video_acceptance=false')
end
local function restore()
 if original and not restored then Spring.SetCameraState(original,0);restored=true end
end
local function finish(reason)note('END',reason);session=nil;restore()end
local function begin(_,id,memberText,actor,bank,factor,proofFrame,x,y,z)
 if used then return end
 if not finite(id)or not finite(x)or not finite(y)or not finite(z)or not finite(proofFrame)or(not finite(factor)or(math.abs(factor-1)>1e-6 and math.abs(factor-.85)>1e-6))or type(bank)~='string'or bank==''or(actor~='space_marine'and actor~='guardsman')or type(memberText)~='string'then return end
 local members,seen={},{};for token in memberText:gmatch('[^,]+')do local value=tonumber(token);if not finite(value)or value%1~=0 or seen[value]then return end;seen[value]=true;members[#members+1]=value end
 if not seen[id]or #members~=(actor=='space_marine'and 4 or 8)then return end
 used=true;session={id=id,actor=actor,bank=bank,factor=factor,proofFrame=proofFrame,start=Spring.GetGameFrame(),members=memberText,x=x,y=y,z=z}
 if Spring.IsPosInLos(x,y,z)~=true then finish('SKIP_INITIAL_NO_LOS');return end
 local minimum=Spring.GetConfigFloat('OverheadMinZoomDistance',60)
 if not finite(minimum)then finish('SKIP_INVALID_NATIVE_CAMERA_MINIMUM');return end
 -- Native overhead Update clamps to configured minHeight. Choose it once;
 -- subsequent camera drift remains a refusal, never an automatic reframe.
 session.cameraHeight=math.max(240,minimum)
 original=Spring.GetCameraState();Spring.SetCameraState({name='ta',mode=1,px=x,py=y,pz=z,height=session.cameraHeight,angle=.9,flipped=-1},0)
 note('CAMERA_PLAN','requested_base_height=240','native_minimum='..minimum,'expected_height='..session.cameraHeight)
 session.nextFrame=session.start+12;note('BEGIN','members='..memberText,'source_proof_frame='..proofFrame,'static_camera=true','captures_limit=6','interval_simframes=3')
end
function gadget:Initialize()gadgetHandler:AddSyncAction('fortyk_gait_render_begin',begin)end
function gadget:GameFrame(frame)
 if session and session.restoreAt and frame>=session.restoreAt then finish('SIX_BOUNDED_REQUESTS_NOT_PIXEL_ACCEPTANCE')
 elseif session and frame-session.start>180 then finish('SKIP_NO_RENDER_OR_WINDOW_EXPIRED')end
end
function gadget:DrawScreen()
 local row=session;if not row or row.restoreAt or Spring.GetGameFrame()<row.nextFrame then return end
 local x,y,z=Spring.GetUnitViewPosition(row.id,true);local vx,_,vz=Spring.GetUnitVelocity(row.id)
 if not finite(x)or not finite(y)or not finite(z)or Spring.IsPosInLos(x,y,z)~=true or not finite(vx)or not finite(vz)or vx*vx+vz*vz<=1e-5 then finish('SKIP_NOT_VISIBLE_MOVING_BODY');return end
 local c=Spring.GetCameraState()
 if c.name~='ta'or not finite(c.height)or math.abs(c.height-row.cameraHeight)>.5 or not finite(c.px)or not finite(c.py)or not finite(c.pz)or math.abs(c.px-row.x)>.5 or math.abs(c.py-row.y)>.5 or math.abs(c.pz-row.z)>.5 then note('CAMERA_REFUSAL','expected=ta,'..row.x..','..row.y..','..row.z..','..row.cameraHeight,'actual='..tostring(c.name)..','..tostring(c.px)..','..tostring(c.py)..','..tostring(c.pz)..','..tostring(c.height));finish('SKIP_CAMERA_CHANGED');return end
 local sx,sy=Spring.WorldToScreenCoords(x,y,z);local width,height,viewX,viewY=Spring.GetViewGeometry()
 if not finite(sx)or not finite(sy)or not finite(width)or not finite(height)or sx<0 or sy<0 or sx>=width or sy>=height then finish('SKIP_OFFSCREEN');return end
 -- Native TraceScreenRay already flips Lua bottom-origin Y internally.
 local kind,id=Spring.TraceScreenRay(sx,sy,false,false,false,false)
 if kind~='unit'or id~=row.id then
  local hit=tostring(id);if type(id)=='table'then local a={};for i=1,math.min(#id,6)do a[#a+1]=tostring(id[i])end;hit=table.concat(a,',')end
  local volume='UNAVAILABLE';if Spring.GetUnitSelectionVolumeData then local a={Spring.GetUnitSelectionVolumeData(row.id)};local text={};for i=1,10 do text[i]=tostring(a[i])end;volume=table.concat(text,',')end
  note('TRACE_REFUSAL','kind='..tostring(kind),'hit='..hit,'expected_unit='..row.id,'screen='..sx..','..sy,
   'viewport='..width..','..height..','..tostring(viewX)..','..tostring(viewY),
   'body_no_select='..tostring(Spring.GetUnitNoSelect and Spring.GetUnitNoSelect(row.id)),
   'body_no_draw='..tostring(Spring.GetUnitNoDraw and Spring.GetUnitNoDraw(row.id)),
   'body_los='..tostring(Spring.IsPosInLos(x,y,z)),'selection_volume='..volume,'piece_visibility=NOT_EXPOSED_BY_NATIVE_PIECEINFO')
  finish('SKIP_OCCLUDED_OR_TRACE_LIMITED');return
 end
 local offset=Spring.GetFrameTimeOffset()
 if not finite(offset)then finish('SKIP_INVALID_RENDER_OFFSET');return end
 captures=captures+1;Spring.SendCommands('screenshot png')
 note('CAPTURE_REQUEST','sequence='..captures,'render_offset='..offset,'position='..x..','..y..','..z,'camera='..c.name..','..c.px..','..c.py..','..c.pz..','..c.height..','..c.angle,'native_los=true trace_target=true')
 row.nextFrame=Spring.GetGameFrame()+3
 if captures>=6 then row.restoreAt=Spring.GetGameFrame()+3 end
end
function gadget:Shutdown()gadgetHandler:RemoveSyncAction('fortyk_gait_render_begin');restore()end
