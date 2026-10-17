function gadget:GetInfo()return{name='40K owned native paid squad order tags',desc='Default-off real local queue INSERT/REMOVE diagnostic',author='Local project',layer=39,enabled=true}end
if not gadgetHandler:IsSyncedCode()then return false end
local options=Spring.GetModOptions()or{}
local development=VFS.Include('40k_configs/development_playtest.lua')
if not development.Enabled(options)or not development.OptionEnabled(options.prototype_squad_order_tags_fixture)then return false end
local D
function gadget:Initialize()
 local function emit(event,...)local a={...};for i=1,#a do a[i]=tostring(a[i])end;Spring.Echo('40K_SQUAD_ORDER_TAGS '..event..' frame='..Spring.GetGameFrame()..' '..table.concat(a,' '))end
 local E=development.OptionEnabled
 if not E(options.prototype_squad_paid_fixture)or(options.prototype_squad_paid_faction or'marine')~='marine'
  or E(options.prototype_squad_fixture)or E(options.prototype_squad_save_checkpoint_fixture)or E(options.prototype_gait_movement_fixture)then
  emit('REFUSED','exclusive_ordinary_paid_marine_required');GG.Recoil40KSquadOrderTagsFixture={Hold=function()return true,'FAIL incompatible_order_tag_route'end};return
 end
 local P=VFS.Include('40k_configs/active_squad_profiles.lua')
 -- Actual squad owner initializes later (layer40); bind it at the paid checkpoint.
 GG.Recoil40KSquadOrderTagsFixture={Hold=function(ctx,frame)
  if not D then
   if not GG.Recoil40KSquads then return true,'FAIL missing_actual_squad_owner'end
   D=VFS.Include('40k_configs/native_order_tags.lua').New(Spring,CMD,GG.Recoil40KSquads,P,UnitDefs,Game,emit)
  end
  return D.Hold(ctx,frame)
 end}
end
function gadget:AllowCommand(id,def,team,cmd,params,opts,tag,player,synced,lua,insert)
 if D then D.Event(id,cmd,tag,player,synced,lua,insert)end;return true
end
function gadget:Shutdown()GG.Recoil40KSquadOrderTagsFixture=nil end
