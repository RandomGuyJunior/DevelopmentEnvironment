function widget:GetInfo()
 return {name="40K accepted unit localization",desc="Conditional names through native BAR I18N",
  author="Local project",layer=-999999.5,enabled=true}
end
-- Run after native Tweakdefs (-1000000), which seeds the old CP tooltips,
-- and before native Language (-999999), which refreshes translated UnitDefs.
-- BAR preserves numeric layers, so this also orders LanguageChanged refreshes.
local labels=VFS.Include('40k_configs/unit_description_labels.lua',nil,VFS.GAME)
local function refresh()
 if not BAR or not BAR.I18N or type(BAR.I18N.set)~='function' then return end
 local language=Spring.GetConfigString('language','en')
 -- Four-faction labels for the native prefix-based picker.
 local factionStarts={
  arm={'armcom','Imperial Guard','Infantry supported by heavy weapons, tanks and artillery.'},
  cor={'corcom','Orks','Numerous infantry supported by walkers and heavy war machines.'},
  smc={'smcom','Space Marines','Elite infantry supported by Dreadnoughts and armoured vehicles.'},
  nec={'nec_lord','Necrons','Durable warriors supported by constructs and awakening technology.'},
 }
 for prefix,entry in pairs(factionStarts)do
  local d=UnitDefNames[entry[1]];local cp=d and d.customParams or{}
  if tostring(cp.prototype40k_four_faction)=='1'and cp.faction==entry[2]then
   BAR.I18N.set('en.units.factions.'..prefix,entry[2])
   BAR.I18N.set('en.ui.factionPicker.factions.'..prefix,entry[3])
   if language~='en'then
    BAR.I18N.set(language..'.units.factions.'..prefix,entry[2])
    BAR.I18N.set(language..'.ui.factionPicker.factions.'..prefix,entry[3])
   end
  end
 end
 local count=0
 for key,d in pairs(UnitDefNames) do
  local cp=d.customParams or {}
  if labels.Accepted(d)then
   local englishName=cp.i18n_en_humanname or cp.prototype40k_ui_name
   local englishDescription=labels.Description(key,d)
   if englishName then BAR.I18N.set('en.units.names.'..key,englishName)end
   if englishDescription then BAR.I18N.set('en.units.descriptions.'..key,englishDescription) end
   if language~='en' then
    -- Correct changed actors in the selected language, without fabricating a
    -- translation. Explicit localized CP overrides always win.
    local name=cp['i18n_'..language..'_humanname'] or englishName
    if name then BAR.I18N.set(language..'.units.names.'..key,name)end
    local description=cp['i18n_'..language..'_tooltip'] or englishDescription
    if description then BAR.I18N.set(language..'.units.descriptions.'..key,description) end
   end
   count=count+1
  end
 end
 Spring.Echo('40K UI LOCALIZATION',language,count,'accepted source actors; native fallback names retained')
end
function widget:Initialize() refresh() end
function widget:LanguageChanged() refresh() end
