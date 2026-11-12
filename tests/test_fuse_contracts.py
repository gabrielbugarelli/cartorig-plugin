"""Static checks of registered independent Fusion Fuse nodes, NOT host-render acceptance."""
from pathlib import Path
import re
import unittest

ROOT=Path(__file__).resolve().parents[1]
TOOLS={
    "WorldMap":("CartoRigWorldMap","CT_SourceTool"),
    "Camera":("CartoRigCamera","CT_Tool"),
    "Scene":("CartoRigScene","CT_Tool"),
    "Region":("CartoRigRegion","CT_Tool"),
}

class FuseContractTests(unittest.TestCase):
    def test_unique_reg_ids_physical_tools_and_pages(self):
        ids=set()
        for kind,(regid,hostkind) in TOOLS.items():
            source=(ROOT/"fuses"/f"{regid}.fuse").read_text(encoding="utf-8")
            self.assertIn(f'FuRegisterClass("{regid}",',source)
            self.assertIn(hostkind,source)
            self.assertIn('self:AddControlPage("Control")',source)
            self.assertIn('self:AddControlPage("Motion")',source)
            self.assertIn('self:AddOutput("Output","Output"',source)
            self.assertIn('function Process(req)',source)
            self.assertNotIn(regid,ids)
            ids.add(regid)
    def test_scene_is_bound_to_active_fusion_composition(self):
        source=(ROOT/"host/cartorig-dev-scene.lua").read_text(encoding="utf-8")
        service=(ROOT/"src/CartoRig/scene_service.lua").read_text(encoding="utf-8")
        self.assertIn('require,"CartoRig.scene_service"',source)
        self.assertIn('ID="OpenScene"',source)
        self.assertIn('ID="CreateScene"',source)
        self.assertIn('ID="ObjectContext"',source)
        self.assertIn('service.create_scene,resolve,title,current',source)
        self.assertIn('service.open_scene,resolve',source)
        self.assertIn('service.add_region,resolve,current,row.dataset_id,row.source_id',source)
        self.assertIn('service.rename_scene,resolve,current',source)
        self.assertIn('service.rename_object,resolve,current,obj.id',source)
        self.assertNotIn("SetActiveTool",source)
        self.assertNotIn("TOOLB_Selected",source)
        self.assertNotIn("InsertFusionCompositionIntoTimeline",source)
        self.assertIn('api.call(resolve,"Fusion")',service)
        self.assertIn('api.get(fusion,"CurrentComp"',service)
        self.assertIn('active.composition~=binding.composition',service)
        self.assertIn('SCENE_CONTEXT_CHANGED',service)
        self.assertNotIn('GetCurrentTimeline',service)
        self.assertNotIn('InsertFusionCompositionIntoTimeline',service)

    def test_scene_control_is_read_only_identity_and_diagnostics(self):
        source=(ROOT/"fuses"/"CartoRigScene.fuse").read_text(encoding="utf-8")
        self.assertIn('"SceneIdentity"',source)
        self.assertIn('"SceneLinks"',source)
        self.assertIn('"SceneData"',source)
        self.assertIn('INPID_InputControl="TextEditControl"',source)
        self.assertIn("TEC_ReadOnly=true",source)
        factory=(ROOT/"src/CartoRig/node_factory.lua").read_text(encoding="utf-8")
        self.assertIn('fusion.set_input(nodes.Scene,"SceneIdentity"',factory)
        self.assertIn('fusion.set_input(nodes.Scene,"SceneLinks"',factory)
        self.assertIn('fusion.set_input(nodes.Scene,"SceneData"',factory)

    def test_land_source_is_offline_and_not_fake(self):
        source=(ROOT/"fuses"/"CartoRigWorldMap.fuse").read_text(encoding="utf-8")
        self.assertIn("ne_50m_land.lua",source)
        self.assertNotIn("http",source)
        self.assertIn("Shape()",source)
        self.assertIn("ImageChannel(img,",source)
        self.assertNotIn("#result~=1422",source)
        builder=(ROOT/"tools/build_natural_earth.py").read_text(encoding="utf-8")
        self.assertIn('"50m_physical/ne_50m_land"',builder)
        self.assertIn('"10m_cultural/ne_10m_admin_1_states_provinces"',builder)
        self.assertIn('"source_commit": source_commit',builder)
    def test_region_is_physical_independent_render_with_native_control(self):
        source=(ROOT/"fuses"/"CartoRigRegion.fuse").read_text(encoding="utf-8")
        self.assertIn('INPID_InputControl="TextEditControl"',source)
        self.assertIn("TEC_ReadOnly=true",source)
        self.assertIn('"Fill Color"',source)
        self.assertIn('"Stroke Width (px)"',source)
        self.assertIn('"Opacity"',source)
        self.assertIn('"Visibility"',source)
        self.assertIn('"Fit Bounds"',source)
        self.assertIn('"BoundsInfo"',source)
        self.assertIn("input:CopyOf()",source)
        self.assertIn("Shape()",source)
        self.assertIn("OutlineOfShape",source)
        self.assertIn('self:GetData("CartoRig.V1.GeometryFile")',source)
        self.assertIn('self:GetData("CartoRig.V1.SourceId")',source)
        self.assertNotIn("http",source)

    def test_topology_and_palette_binding_are_not_just_inspector_labels(self):
        world = (ROOT/"fuses"/"CartoRigWorldMap.fuse").read_text(encoding="utf-8")
        region = (ROOT/"fuses"/"CartoRigRegion.fuse").read_text(encoding="utf-8")
        self.assertIn("result.topology_schema~=2", world)
        self.assertIn("result.ring_roles", world)
        self.assertIn("local seam=previousLon>=0 and 180 or -180", world)
        self.assertIn('IMG_Channel="Alpha"', world)
        self.assertIn('"Reset WorldMap Style"', world)
        self.assertIn("InMapOpacity:SetSource(Number(1),time)", world)
        self.assertIn("data.topology_schema~=2", region)
        self.assertIn("data.ring_roles", region)
        self.assertIn('"InheritWorldMapFill"', region)
        self.assertIn("function NotifyChanged(inp,param,time)", region)
        self.assertIn('WorldLandControls=inherited_color_inputs', region)
        self.assertIn('WorldBorderControls=inherited_color_inputs', region)
        self.assertIn('IC_Visible=false,INP_External=true,INP_Active=true', region)
        self.assertNotIn("self.Comp:GetToolList", region)
        self.assertNotIn("world:GetInput", region)
        self.assertIn('"InheritWorldMapBorder"', region)
        self.assertIn('inherited_world_color(req,WorldLandControls,"Land")', region)
        self.assertIn('inherited_world_color(req,WorldBorderControls,"Border")', region)
        factory=(ROOT/"src"/"CartoRig"/"node_factory.lua").read_text(encoding="utf-8")
        self.assertIn('link_region_palette(region,chain.world)', factory)
        self.assertIn('api.call(input,"SetExpression",expression)', factory)
        self.assertIn('api.call(input,"GetExpression")', factory)
        self.assertIn('NAMES.WorldMap.."."..prefix..suffix', factory)
        self.assertIn("InInheritBorder:SetSource(Number(1),time)", region)
        self.assertIn("readnum(InInheritLand,req", region)
        self.assertIn('"ResetStyle"', region)
        self.assertIn("InInheritLand:SetSource(Number(1),time)", region)

    def test_region_process_does_not_query_fusion_graph_during_render(self):
        source=(ROOT/"fuses"/"CartoRigRegion.fuse").read_text(encoding="utf-8")
        render=source[source.index("function Process(req)"):]
        for forbidden in ("GetToolList(", "GetInput(", "FindInput(", "self.Comp:"):
            self.assertNotIn(forbidden,render,
                "Region render cannot perform host graph lookups: "+forbidden)
        self.assertIn("readnum(inputs[index],req",source)

    def test_camera_reset_is_a_native_state_change_not_a_placeholder(self):
        camera = (ROOT/"fuses"/"CartoRigCamera.fuse").read_text(encoding="utf-8")
        self.assertIn('"ResetPose"', camera)
        self.assertIn("INPID_InputControl=\"ButtonControl\"", camera)
        self.assertIn("function NotifyChanged(inp,param,time)", camera)
        self.assertIn("InLatitude:SetSource(Number(0),time)", camera)
        self.assertIn("InZoom:SetSource(Number(1),time)", camera)

    def test_native_buttons_do_not_fire_on_node_initialization(self):
        for name in ("CartoRigWorldMap", "CartoRigRegion", "CartoRigCamera"):
            source = (ROOT/"fuses"/f"{name}.fuse").read_text(encoding="utf-8")
            self.assertIn("INP_InitialNotify=false", source,
                          f"{name} could reset saved Inspector values during project reopen")
        region = (ROOT/"fuses"/"CartoRigRegion.fuse").read_text(encoding="utf-8")
        self.assertIn('INP_DoNotifyChanged=(base=="Fill" or base=="Stroke")', region)
        self.assertIn("INP_InitialNotify=false", region)

    def test_node_factory_has_lexical_blackmagic_api_import(self):
        source=(ROOT/"src/CartoRig/node_factory.lua").read_text(encoding="utf-8")
        declaration='local api=require("CartoRig.blackmagic_api")'
        self.assertIn(declaration, source)
        self.assertLess(source.index(declaration), source.index('api.call('),
            "Region creation must never depend on an accidental global api")
        self.assertIn('link_region_palette(region,chain.world)', source)
        self.assertIn('function factory.repair_region_palette(comp)', source)

    def test_core_factory_and_fusion_safety_contract(self):
        source=(ROOT/"src/CartoRig/node_factory.lua").read_text(encoding="utf-8")
        for regid,_ in TOOLS.values():
            self.assertIn(regid,source)
        for contract in (
            "NODE_CREATE_FAILED","SCENE_EXISTS","SCENE_CREATE_FAILED",
            "function factory.rename_scene(comp,new_title)",
            'structural={Scene=0,WorldMap=0,Camera=0}',
            'local BOUND_WEST=P.."BoundWest"',
            'fusion.set_input(tool,"BoundsInfo"',
        ):
            self.assertIn(contract,source)
        service=(ROOT/"src/CartoRig/scene_service.lua").read_text(encoding="utf-8")
        self.assertIn('require("CartoRig.blackmagic_api")',service)
        self.assertIn('factory.create_scene(active.composition',service)
        self.assertIn('factory.add_region(active.composition',service)
        self.assertIn('factory.rename_scene(active.composition',service)
        self.assertIn('SCENE_CONTEXT_CHANGED',service)
        boundary=(ROOT/"src/CartoRig/blackmagic_api.lua").read_text()
        fusion=(ROOT/"src/CartoRig/fusion_contract.lua").read_text()
        self.assertIn('BINDING_METADATA={__flags=true}',boundary)
        self.assertIn('api.table_values',fusion)
        self.assertIn('FUSION_CONNECT_WRONG_SOURCE',fusion)
        domain=(ROOT/"src/CartoRig/domain.lua").read_text()
        self.assertNotIn('math.randomseed',domain)

if __name__=="__main__":
    unittest.main()
