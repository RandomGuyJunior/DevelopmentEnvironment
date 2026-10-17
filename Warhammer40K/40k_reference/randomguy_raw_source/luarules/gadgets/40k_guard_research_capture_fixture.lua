function gadget:GetInfo()return{name='40K paid Guard capture observer',desc='Default-off real stock capture, no setup or orders',author='Local project',layer=49,enabled=true}end
if not gadgetHandler:IsSyncedCode()then return false end
local M=VFS.Include('40k_configs/guard_capture_observer.lua')
if not M.Enabled(Spring.GetModOptions()or{})then return false end
local O
local function emit(event,row)local k={};for key in pairs(row)do k[#k+1]=key end;table.sort(k);local out={};for _,key in ipairs(k)do out[#out+1]=key..'='..tostring(row[key]):gsub('%s','_')end;Spring.Echo('40K_GUARD_CAPTURE '..event..' '..table.concat(out,' '))end
local function attach()if O then return end;assert(GG.Recoil40KResearch and GG.Recoil40KSquads,'paid owners unavailable after initialization');O=M.New(Spring,UnitDefs,UnitDefNames,GG.Recoil40KResearch,GG.Recoil40KSquads,CMD,emit);assert(not GG.Recoil40KGuardCaptureObserver,'existing capture observer');GG.Recoil40KGuardCaptureObserver=O end
function gadget:UnitCreated(...)if O then O.Created(...)end end
function gadget:UnitFinished(...)if O then O.Finished(...)end end
function gadget:UnitFromFactory(...)if O then O.Released(...)end end
function gadget:UnitTaken(...)if O then O.Taken(...)end end
function gadget:UnitGiven(...)if O then O.Given(...)end end
function gadget:AllowCommand(...)if O then return O.Command(...)end;return true end
function gadget:GameFrame(frame)
 if not O then attach()end
 if O.phase=='waiting'then
  local producer,product,capturer;local c=GG.Recoil40KResearch;local r=GG.Recoil40KSquads
  for id,jobs in pairs(c.jobs)do local j=jobs.guard_squad_flamer;if j and j.team==0 and j.steps>0 then assert(not producer,'ambiguous source research producer');producer=id end end
  if producer then
   for _,s in pairs(r.squads)do if s.team==0 and s.profile=='guard_line'and #r.Members(s.leader)==8 then assert(not product,'ambiguous source cohort');product=s.leader end end
   for _,id in ipairs(Spring.GetTeamUnits(1)or{})do local d=UnitDefs[Spring.GetUnitDefID(id)];if d and d.name=='armcom'and d.canCapture==true then assert(not capturer,'ambiguous Guard capture commander');capturer=id end end
   if product and capturer then O.Arm(producer,capturer,product)end
  end
 end
 O.Frame(frame)
end
function gadget:Shutdown()if GG.Recoil40KGuardCaptureObserver==O then GG.Recoil40KGuardCaptureObserver=nil end end
