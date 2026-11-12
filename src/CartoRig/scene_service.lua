-- CartoRig V1 FINAL: one Scene per CURRENT Fusion composition.
-- No timeline creation, implicit clip insertion or cross-composition edits.
local api=require("CartoRig.blackmagic_api")
local factory=require("CartoRig.node_factory")
local catalog=require("CartoRig.catalog")
local M={}
local index_cache={}

local function catalog_index(opts)
  opts=opts or {}
  local root=opts.localappdata or os.getenv("LOCALAPPDATA")
  if type(root)~="string" or root=="" then
    return nil,"DATA_MISSING: LOCALAPPDATA unavailable"
  end
  local path=root.."\\CartoRig\\App\\data\\ne_catalog.tsv"
  if index_cache[path] then return index_cache[path] end
  local index,err=catalog.open(path)
  if not index then return nil,err end
  index_cache[path]=index
  return index
end

local function current_composition(resolve)
  local page,pageErr=api.call(resolve,"GetCurrentPage")
  if pageErr then return nil,"FUSION_CONTEXT_UNAVAILABLE: "..tostring(pageErr) end
  if page~="fusion" then
    return nil,"FUSION_PAGE_REQUIRED: open the target composition on the Fusion page"
  end

  local fusion,err=api.call(resolve,"Fusion")
  if not fusion then
    return nil,"FUSION_CONTEXT_UNAVAILABLE: Resolve.Fusion(): "..tostring(err)
  end

  -- Blackmagic's Fusion scripting reference exposes CurrentComp as a property.
  -- Some host versions also expose GetCurrentComp(). Prefer the documented
  -- property, and never guess a composition from the timeline.
  local comp,propErr=api.get(fusion,"CurrentComp","Fusion.CurrentComp")
  if not comp then
    local getter,methodErr=api.method(fusion,"GetCurrentComp")
    if getter then
      comp,propErr=api.call(fusion,"GetCurrentComp")
    else
      propErr=methodErr or propErr
    end
  end
  if not comp then
    return nil,"NO_ACTIVE_FUSION_COMPOSITION: "..tostring(propErr or "Fusion.CurrentComp is nil")
  end
  local checked,checkErr=api.require_object(comp,"Fusion.CurrentComp","GetToolList")
  if not checked then return nil,"FUSION_CONTEXT_INVALID: "..tostring(checkErr) end
  return checked
end

function M.inspect_active(resolve)
  local comp,err=current_composition(resolve)
  if not comp then return nil,err end
  local state,stateErr=factory.inspect(comp)
  if not state then return nil,stateErr end
  return {
    composition=comp,scene_id=state.scene_id,
    has_scene=state.has_scene,title=state.title,
    objects=state.objects or {}
  }
end

-- A Scene window is bound to the Fusion composition that was current when
-- the window opened, or when the editor explicitly requested Open Scene.
-- Do not use Scene UUID alone: duplicated compositions may temporarily have
-- identical persisted UUIDs before controlled remapping.
local function require_bound(resolve,binding,require_scene)
  if type(binding)~="table" or not binding.composition then
    return nil,"SCENE_CONTEXT_UNBOUND: reopen the active composition in Scene"
  end
  local active,err=M.inspect_active(resolve)
  if not active then return nil,err end
  if active.composition~=binding.composition then
    return nil,"SCENE_CONTEXT_CHANGED: use Open Scene to confirm the active Fusion composition"
  end
  if binding.scene_id~=active.scene_id then
    return nil,"SCENE_CONTEXT_CHANGED: persisted Scene identity changed; reopen Scene"
  end
  if require_scene and not active.has_scene then
    return nil,"NO_SCENE: use Create Scene first"
  end
  return active
end

function M.open_scene(resolve)
  local active,err=M.inspect_active(resolve)
  if not active then return nil,err end
  if not active.has_scene then
    return nil,"NO_SCENE: current composition has no CartoRig Scene"
  end
  return active
end

function M.create_scene(resolve,title,binding,opts)
  if type(title)~="string" or title:match("^%s*$") then
    return nil,"INVALID_TITLE: Scene title is required"
  end
  local active,err=require_bound(resolve,binding,false)
  if not active then return nil,err end
  if active.has_scene then
    return nil,"SCENE_EXISTS: current composition already contains a Scene; use Open Scene"
  end
  local created,createErr=factory.create_scene(active.composition,title,opts or {})
  if not created then return nil,createErr end
  local observed,observeErr=M.inspect_active(resolve)
  if not observed then return nil,"SCENE_POST_CREATE_UNREADABLE: "..tostring(observeErr) end
  if not observed.has_scene or observed.scene_id~=created.scene_id or
     observed.composition~=active.composition then
    return nil,"SCENE_POST_CREATE_INVALID: current composition did not retain created Scene"
  end
  return observed
end

function M.search_locations(query,geo_type,opts)
  local index,err=catalog_index(opts)
  if not index then return nil,err end
  return catalog.search(index,query,geo_type or "All",50)
end

function M.add_region(resolve,binding,dataset_id,source_id,opts)
  local active,err=require_bound(resolve,binding,true)
  if not active then return nil,err end
  local index,indexErr=catalog_index(opts)
  if not index then return nil,indexErr end
  local feature,featureErr=catalog.find(index,dataset_id,source_id)
  if not feature then return nil,featureErr end
  if feature.geo_type~="Country" and feature.geo_type~="State" then
    return nil,"REGION_TYPE_UNSUPPORTED: select Country or State/Province"
  end
  local result,createErr=factory.add_region(active.composition,feature,opts or {})
  if not result then return nil,createErr end
  local observed,observeErr=M.inspect_active(resolve)
  if not observed then return nil,"REGION_POST_CREATE_INVALID: "..tostring(observeErr) end
  if observed.scene_id~=active.scene_id then
    return nil,"REGION_POST_CREATE_INVALID: Scene identity changed"
  end
  local found=false
  for _,obj in ipairs(observed.objects) do
    if obj.id==result.object_id and obj.type==feature.geo_type then
      found=true
      break
    end
  end
  if not found then
    return nil,"REGION_POST_CREATE_INVALID: created node was not persisted"
  end
  result.objects=observed.objects
  return result
end

function M.rename_object(resolve,binding,object_id,new_name)
  local active,err=require_bound(resolve,binding,true)
  if not active then return nil,err end
  if type(new_name)~="string" or new_name:match("^%s*$") then
    return nil,"RENAME_NAME_REQUIRED: enter a display name"
  end
  return factory.rename_object(active.composition,object_id,new_name)
end

function M.rename_scene(resolve,binding,new_title)
  local active,err=require_bound(resolve,binding,true)
  if not active then return nil,err end
  return factory.rename_scene(active.composition,new_title)
end

function M.repair_palette(resolve,binding)
  local active,err=require_bound(resolve,binding,true)
  if not active then return nil,err end
  return factory.repair_region_palette(active.composition)
end

return M
