-- Existing native sensors only. No new ranges, income path or polling gadget.
local M={}
M.Profiles={
 imp_comms_array={source='imp_comms_array',faction='Imperial Guard',label='Radar / jammer'},
 imp_marine_comms_array={source='imp_comms_array',faction='Space Marines',label='Radar / jammer'},
 ork_waaagh_banner={source='ork_waaagh_banner',faction='Orks',label='Radar / support'},
}
function M.Apply(defs,options,hybrid)
 local report={enabled=hybrid.Enabled(options),changed={}}
 if not report.enabled then return report end
 for name,p in pairs(M.Profiles)do
  local d=defs[name];local cp=d and d.customparams or{}
  if d and tostring(cp.prototype40k_four_faction)=='1'and cp.faction==p.faction and cp.animsource==p.source then
   local radar,los=tonumber(d.radardistance),tonumber(d.sightdistance)
   assert(radar and los and radar>los and los>0,'Existing native sensor coverage drift: '..name)
   -- Engine UnitDef defaults both false. Non-LOS sensors are removed from the
   -- native coverage map while inactive; a radius alone cannot provide radar.
   d.activatewhenbuilt=true;d.onoffable=true
   cp.native_sensor_role='existing_radar_activation_v1'
   cp.prototype40k_short_role=p.label;cp.unitgroup='util'
   report.changed[#report.changed+1]=name
  end
 end
 table.sort(report.changed);return report
end
return M
