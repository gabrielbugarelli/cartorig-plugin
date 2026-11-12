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
    def test_scene_is_not_editable_from_script_panel(self):
        source=(ROOT/"host"/"cartorig-dev-scene.lua").read_text(encoding="utf-8")
        self.assertIn("Create Scene",source)
        self.assertIn("service.create,resolve,title",source)
        self.assertNotIn("OpenScene",source)
        self.assertNotIn("Open Scene",source)
        self.assertNotIn("SetActiveTool",source)
        self.assertNotIn("TOOLB_Selected",source)
        self.assertIn('service.search_locations,query,filter',source)
        self.assertIn('service.add_region,resolve,scene.scene_id,result.dataset_id,result.source_id',source)
        self.assertIn('ID="SceneContext"',source)
        self.assertIn('ID="SearchResults"',source)
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
        self.assertIn("input:CopyOf()",source)
        self.assertIn("Shape()",source)
        self.assertIn("OutlineOfShape",source)
        self.assertIn('self:GetData("CartoRig.V1.GeometryFile")',source)
        self.assertIn('self:GetData("CartoRig.V1.SourceId")',source)
        self.assertNotIn("http",source)

    def test_factory_hard_fail_on_unregistered_fuses(self):
        source=(ROOT/"src/CartoRig/node_factory.lua").read_text(encoding="utf-8")
        for regid,_ in TOOLS.values():
            self.assertIn(regid,source)
        self.assertIn("NODE_CREATE_FAILED",source)
        self.assertIn("SCENE_EXISTS",source)
        self.assertIn("SCENE_CREATE_FAILED",source)
        service=(ROOT/"src/CartoRig/timeline_service.lua").read_text()
        boundary=(ROOT/"src/CartoRig/blackmagic_api.lua").read_text()
        fusion=(ROOT/"src/CartoRig/fusion_contract.lua").read_text()
        self.assertIn('require("CartoRig.blackmagic_api")',service)
        self.assertIn("InsertFusionCompositionIntoTimeline",service)
        self.assertIn("GetFusionCompByIndex",service)
        self.assertIn("SetCurrentTimecode",service)
        self.assertIn("OpenPage",service)
        self.assertIn('api.sequence(raw or {}',service)
        self.assertNotIn('for index,item in pairs(items)',service)
        self.assertNotIn('for _,item in pairs(clips)',service)
        self.assertIn('BINDING_METADATA={__flags=true}',boundary)
        self.assertIn('api.table_values',fusion)
        self.assertIn('fusion.output_tool(output',fusion)
        self.assertIn('FUSION_CONNECT_WRONG_SOURCE',fusion)
        domain=(ROOT/"src/CartoRig/domain.lua").read_text()
        self.assertNotIn('rawget(_G, "bmd")',domain)
        self.assertNotIn('api.call_function(bmd,"createuuid")',domain)
        self.assertNotIn('math.randomseed',domain)
        self.assertIn('disallow_new_mediaout=true',service)
        self.assertNotIn('require_existing_mediaout',service)
        self.assertNotIn('GetTrackTypeAndIndex',service)
        self.assertIn('inserted=after.items[itemId]',service)
        self.assertIn('GetIsTrackLocked',service)
        self.assertIn('GetIsTrackEnabled',service)
        self.assertIn('SetTrackEnable',service)
        self.assertIn('GetTrackName',service)
        self.assertIn('SetTrackName',service)
        self.assertIn('GetMarkInOut',service)
        self.assertIn('GetMarkers',service)
        self.assertIn('SetTrackLock',service)
        self.assertIn('DeleteTrack',service)
        self.assertIn('DeleteTimelines',service)
        self.assertIn('ROLLBACK_INCOMPLETE',service)
        self.assertIn('TRACK_TYPES={"video","audio","subtitle"}',service)
        self.assertNotIn('expected exactly three structural nodes',source)
        self.assertIn('structural={Scene=0,WorldMap=0,Camera=0}',source)
if __name__=="__main__":
    unittest.main()
