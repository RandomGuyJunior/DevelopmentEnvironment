-- Attach one genuine decorative skull to existing Imperial mobile builders.
-- Applied after faction aliases; no native economic, collision or colour fields.
local M={}
M.Sources={imp_commissar=true,imp_enginseer=true,imp_force_commander_candidate=true}
local function yes(v)return v==true or v==1 or v=='1'end
function M.Apply(defs,V)
 local plans={};local report={applied=false,units={}}
 for key,d in pairs(defs)do
  local cp=d.customparams or{}
  if M.Sources[cp.animsource]and yes(d.builder)and yes(d.canmove)and cp.rosterrole=='builder'
    and (cp.faction=='Imperium'or cp.faction=='Imperial Guard'or cp.faction=='Space Marines')then
   local source=cp.animsource;local variant=source..'_servo'
   if yes(d.usepiececollisionvolumes)or yes(d.usepieceselectionvolumes)then
    return {applied=false,reason='piece_gameplay_bounds_enabled:'..key}
   end
   if d.script~='40k_roster.lua'or(d.objectname~=source..'.glb'and d.objectname~=variant..'.glb')then
    return {applied=false,reason='unexpected_builder_model:'..key}
   end
   for _,path in ipairs({'objects3d/'..variant..'.glb','unittextures/'..variant..'_tex1.png',
     'unittextures/'..variant..'_tex2.png','scripts/generated/servo_skull_attachment_anim.lua'})do
    if not V.FileExists(path)then return {applied=false,reason='missing_servo_asset:'..path}end
   end
   plans[#plans+1]={key=key,def=d,cp=cp,variant=variant}
  end
 end
 table.sort(plans,function(a,b)return a.key<b.key end)
 for _,p in ipairs(plans)do
  p.def.objectname=p.variant..'.glb'
  p.cp.source_servoskull='attached_v1';p.cp.source_nanopiece='servo_skull_nano'
  p.cp.source_servoskull_bank='servo_skull_attachment'
  report.units[#report.units+1]=p.key
 end
 report.applied=#plans>0;return report
end
return M
