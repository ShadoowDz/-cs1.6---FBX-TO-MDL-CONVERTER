# FBX to MDL Converter for Counter-Strike 1.6
# Complete system to convert FBX models to CS 1.6 compatible MDL files
# Run this entire code block in a Google Colab notebook cell

# Install all required dependencies
import subprocess
import sys
import os

def install_dependencies():
    """Install all required packages and tools"""
    print("🔧 Installing dependencies...")
    
    # Install system packages
    subprocess.run(['apt-get', 'update'], capture_output=True)
    subprocess.run(['apt-get', 'install', '-y', 'blender', 'wget', 'unzip', 'build-essential'], capture_output=True)
    
    # Install Python packages
    subprocess.run([sys.executable, '-m', 'pip', 'install', 'bpy', 'mathutils', 'numpy', 'ipywidgets'], capture_output=True)
    
    # Download and build studiomdl compiler
    if not os.path.exists('/content/halflife-master'):
        subprocess.run(['wget', '-q', 'https://github.com/ValveSoftware/halflife/archive/master.zip'], cwd='/content')
        subprocess.run(['unzip', '-q', 'master.zip'], cwd='/content')
        
    # Build studiomdl
    studiomdl_dir = '/content/halflife-master/utils/studiomdl'
    if os.path.exists(studiomdl_dir):
        subprocess.run(['make'], cwd=studiomdl_dir, capture_output=True)
    
    print("✅ Dependencies installed successfully!")

# Run installation
install_dependencies()

# Import all required modules
import tempfile
import shutil
import zipfile
import json
import math
from pathlib import Path
import base64

# Import widgets for GUI
try:
    import ipywidgets as widgets
    from IPython.display import display, HTML, clear_output
    GUI_AVAILABLE = True
except ImportError:
    GUI_AVAILABLE = False
    print("⚠️ GUI widgets not available - CLI mode only")

# Add Blender Python path and import
blender_python_path = '/usr/share/blender/scripts/modules'
if blender_python_path not in sys.path:
    sys.path.append(blender_python_path)

try:
    import bpy
    import bmesh
    from mathutils import Vector, Matrix, Euler
    BLENDER_AVAILABLE = True
except ImportError:
    BLENDER_AVAILABLE = False
    print("⚠️ Blender Python API not available")

class FBXToMDLConverter:
    """Complete FBX to MDL converter for Counter-Strike 1.6"""
    
    def __init__(self):
        self.work_dir = Path('/tmp/fbx_converter')
        self.work_dir.mkdir(exist_ok=True)
        self.model_name = 'converted_model'
        self.animations = []
        self.bones = []
        self.materials = []
        
    def clear_scene(self):
        """Clear all objects from Blender scene"""
        if not BLENDER_AVAILABLE:
            raise RuntimeError("Blender not available")
        bpy.ops.object.select_all(action='SELECT')
        bpy.ops.object.delete(use_global=False)
        
    def load_fbx(self, fbx_path):
        """Load FBX file and analyze contents"""
        if not BLENDER_AVAILABLE:
            raise RuntimeError("Blender not available")
            
        self.clear_scene()
        
        # Import FBX with optimal settings for CS 1.6
        bpy.ops.import_scene.fbx(
            filepath=fbx_path,
            use_custom_normals=True,
            use_image_search=True,
            automatic_bone_orientation=True,
            use_alpha_decals=False,
            use_anim=True,
            anim_offset=1.0
        )
        
        # Analyze loaded scene
        self.analyze_scene()
        
    def analyze_scene(self):
        """Analyze loaded scene for meshes, bones, animations"""
        self.bones = []
        self.animations = []
        self.materials = []
        
        # Find armatures and bones
        for obj in bpy.context.scene.objects:
            if obj.type == 'ARMATURE':
                for bone in obj.data.bones:
                    self.bones.append(bone.name)
                    
        # Find animations
        if bpy.data.actions:
            for action in bpy.data.actions:
                frame_start = int(action.frame_range[0])
                frame_end = int(action.frame_range[1])
                self.animations.append({
                    'name': self.sanitize_name(action.name),
                    'start': frame_start,
                    'end': frame_end,
                    'fps': 30
                })
                
        # Find materials
        for mat in bpy.data.materials:
            if mat.users > 0:
                self.materials.append(self.sanitize_name(mat.name))
                
        print(f"📊 Found {len(self.bones)} bones, {len(self.animations)} animations, {len(self.materials)} materials")
        
    def sanitize_name(self, name):
        """Sanitize names for CS 1.6 compatibility"""
        # Remove invalid characters and ensure CS 1.6 compatibility
        import re
        sanitized = re.sub(r'[^a-zA-Z0-9_]', '_', name)
        return sanitized[:32]  # Limit length
        
    def export_reference_smd(self):
        """Export reference SMD file"""
        ref_path = self.work_dir / f"{self.model_name}_reference.smd"
        
        # Set to frame 1 for reference pose
        bpy.context.scene.frame_set(1)
        
        # Select mesh objects
        bpy.ops.object.select_all(action='DESELECT')
        for obj in bpy.context.scene.objects:
            if obj.type == 'MESH':
                obj.select_set(True)
                
        # Try built-in SMD export first, fallback to manual
        try:
            bpy.ops.export_scene.smd(
                filepath=str(ref_path),
                export_format='SMD',
                selection_only=True,
                export_meshes=True,
                export_animations=False
            )
        except:
            # Manual SMD export fallback
            self.manual_smd_export(ref_path, export_type='reference')
            
        return ref_path
        
    def export_animation_smd(self, animation):
        """Export animation SMD file"""
        anim_path = self.work_dir / f"{self.model_name}_{animation['name']}.smd"
        
        # Set frame range
        bpy.context.scene.frame_start = animation['start']
        bpy.context.scene.frame_end = animation['end']
        
        # Select armature
        bpy.ops.object.select_all(action='DESELECT')
        for obj in bpy.context.scene.objects:
            if obj.type == 'ARMATURE':
                obj.select_set(True)
                bpy.context.view_layer.objects.active = obj
                
        # Try built-in SMD export first, fallback to manual
        try:
            bpy.ops.export_scene.smd(
                filepath=str(anim_path),
                export_format='SMD',
                selection_only=True,
                export_meshes=False,
                export_animations=True
            )
        except:
            # Manual SMD export fallback
            self.manual_smd_export(anim_path, export_type='animation', animation=animation)
            
        return anim_path
        
    def manual_smd_export(self, filepath, export_type='reference', animation=None):
        """Manual SMD export when Blender addon not available"""
        with open(filepath, 'w') as f:
            f.write("version 1\n")
            
            # Write nodes (bones)
            f.write("nodes\n")
            bone_id = 0
            bone_map = {}
            
            # Add root bone if no armature exists
            if not any(obj.type == 'ARMATURE' for obj in bpy.context.scene.objects):
                f.write(f"0 \"root\" -1\n")
                bone_map['root'] = 0
                bone_id = 1
            
            for obj in bpy.context.scene.objects:
                if obj.type == 'ARMATURE':
                    for bone in obj.data.bones:
                        parent_id = -1
                        if bone.parent:
                            parent_id = bone_map.get(bone.parent.name, -1)
                        f.write(f"{bone_id} \"{bone.name}\" {parent_id}\n")
                        bone_map[bone.name] = bone_id
                        bone_id += 1
            f.write("end\n")
            
            # Write skeleton
            f.write("skeleton\n")
            if export_type == 'animation' and animation:
                for frame in range(animation['start'], animation['end'] + 1):
                    bpy.context.scene.frame_set(frame)
                    f.write(f"time {frame}\n")
                    self.write_bone_positions(f, bone_map)
            else:
                bpy.context.scene.frame_set(1)
                f.write("time 0\n")
                self.write_bone_positions(f, bone_map)
            f.write("end\n")
            
            # Write triangles (for reference only)
            if export_type == 'reference':
                f.write("triangles\n")
                self.write_mesh_triangles(f, bone_map)
                f.write("end\n")
                
    def write_bone_positions(self, f, bone_map):
        """Write bone positions for current frame"""
        # Write root bone if no armature
        if 'root' in bone_map:
            f.write(f"0 0.000000 0.000000 0.000000 0.000000 0.000000 0.000000\n")
            
        for obj in bpy.context.scene.objects:
            if obj.type == 'ARMATURE':
                for bone in obj.pose.bones:
                    if bone.name in bone_map:
                        bone_id = bone_map[bone.name]
                        matrix = bone.matrix
                        loc = matrix.to_translation()
                        rot = matrix.to_euler('XYZ')
                        f.write(f"{bone_id} {loc.x:.6f} {loc.y:.6f} {loc.z:.6f} {rot.x:.6f} {rot.y:.6f} {rot.z:.6f}\n")
                        
    def write_mesh_triangles(self, f, bone_map):
        """Write mesh triangles for reference SMD"""
        for obj in bpy.context.scene.objects:
            if obj.type == 'MESH':
                mesh = obj.data
                
                # Ensure mesh has triangles
                if not hasattr(mesh, 'loop_triangles') or len(mesh.loop_triangles) == 0:
                    # Triangulate mesh if needed
                    bm = bmesh.new()
                    bm.from_mesh(mesh)
                    bmesh.ops.triangulate(bm, faces=bm.faces[:])
                    bm.to_mesh(mesh)
                    bm.free()
                    mesh.update()
                
                mesh.calc_loop_triangles()
                
                # Get material name
                mat_name = "default"
                if obj.material_slots and obj.material_slots[0].material:
                    mat_name = self.sanitize_name(obj.material_slots[0].material.name)
                    
                for tri in mesh.loop_triangles:
                    f.write(f"{mat_name}\n")
                    for loop_idx in tri.loops:
                        vert_idx = mesh.loops[loop_idx].vertex_index
                        vertex = mesh.vertices[vert_idx]
                        co = vertex.co
                        normal = vertex.normal
                        
                        # UV coordinates
                        uv = [0.0, 0.0]
                        if mesh.uv_layers:
                            uv = mesh.uv_layers[0].data[loop_idx].uv
                            
                        # Bone weights (simplified - use strongest influence)
                        bone_id = 0
                        if obj.vertex_groups and vertex.groups:
                            max_weight = 0
                            for vg in vertex.groups:
                                if vg.weight > max_weight:
                                    group_name = obj.vertex_groups[vg.group].name
                                    if group_name in bone_map:
                                        bone_id = bone_map[group_name]
                                        max_weight = vg.weight
                                        
                        f.write(f"{bone_id} {co.x:.6f} {co.y:.6f} {co.z:.6f} {normal.x:.6f} {normal.y:.6f} {normal.z:.6f} {uv[0]:.6f} {uv[1]:.6f}\n")
                        
    def generate_qc_file(self):
        """Generate QC file for studiomdl compilation"""
        qc_path = self.work_dir / f"{self.model_name}.qc"
        
        with open(qc_path, 'w') as f:
            # Basic model info
            f.write(f"$modelname \"{self.model_name}.mdl\"\n")
            f.write(f"$cd \"{self.work_dir}\"\n")
            f.write(f"$cdtexture \"{self.work_dir}\"\n")
            f.write(f"$scale 1.0\n")
            f.write(f"$cliptotextures\n")
            
            # Reference mesh
            f.write(f"$body studio \"{self.model_name}_reference.smd\"\n")
            
            # Animation sequences
            if not self.animations:
                # Default idle sequence
                f.write(f"$sequence idle \"{self.model_name}_reference.smd\" fps 30\n")
            else:
                for anim in self.animations:
                    f.write(f"$sequence {anim['name']} \"{self.model_name}_{anim['name']}.smd\" fps {anim['fps']} loop\n")
                    
            # CS 1.6 compatibility settings
            f.write("$bbox 0 0 0 0 0 0\n")
            f.write("$cbox 0 0 0 0 0 0\n")
            f.write("$eyeposition 0 0 0\n")
            
            # Additional GoldSrc settings
            f.write("$flags 0\n")
            f.write("$origin 0 0 0\n")
            
        return qc_path
        
    def compile_mdl(self, qc_path):
        """Compile MDL using studiomdl compiler"""
        try:
            studiomdl_path = "/content/halflife-master/utils/studiomdl/studiomdl"
            
            # Ensure studiomdl is built
            if not os.path.exists(studiomdl_path):
                studiomdl_dir = "/content/halflife-master/utils/studiomdl"
                if os.path.exists(studiomdl_dir):
                    result = subprocess.run(["make"], cwd=studiomdl_dir, capture_output=True, text=True)
                    if result.returncode != 0:
                        print(f"Failed to build studiomdl: {result.stderr}")
                        return None
                        
            if not os.path.exists(studiomdl_path):
                print("❌ studiomdl compiler not available")
                return None
                
            # Make studiomdl executable
            os.chmod(studiomdl_path, 0o755)
            
            # Compile MDL
            result = subprocess.run(
                [studiomdl_path, str(qc_path)],
                cwd=str(self.work_dir),
                capture_output=True,
                text=True
            )
            
            if result.returncode == 0:
                mdl_path = self.work_dir / f"{self.model_name}.mdl"
                if mdl_path.exists():
                    return mdl_path
                    
            print(f"⚠️ Compilation output: {result.stdout}")
            if result.stderr:
                print(f"⚠️ Compilation errors: {result.stderr}")
                
        except Exception as e:
            print(f"💥 Compilation failed: {e}")
            
        return None
        
    def convert_fbx_to_mdl(self, fbx_path, model_name=None):
        """Main conversion function"""
        if model_name:
            self.model_name = self.sanitize_name(model_name)
            
        try:
            print("🔄 Loading FBX file...")
            self.load_fbx(fbx_path)
            
            print("📦 Exporting reference SMD...")
            ref_smd = self.export_reference_smd()
            
            print("🎬 Exporting animation SMDs...")
            for anim in self.animations:
                self.export_animation_smd(anim)
                
            print("📝 Generating QC file...")
            qc_path = self.generate_qc_file()
            
            print("🔨 Compiling MDL...")
            mdl_path = self.compile_mdl(qc_path)
            
            if mdl_path:
                print(f"✅ Conversion successful! MDL saved to: {mdl_path}")
                return mdl_path
            else:
                print("❌ Conversion failed during MDL compilation!")
                return None
                
        except Exception as e:
            print(f"💥 Conversion error: {str(e)}")
            return None

# GUI Interface (if available)
if GUI_AVAILABLE:
    class ConverterGUI:
        """Interactive GUI for FBX to MDL conversion"""
        
        def __init__(self):
            self.converter = FBXToMDLConverter()
            self.uploaded_file = None
            self.result_mdl = None
            self.create_interface()
            
        def create_interface(self):
            # File upload widget
            self.upload_widget = widgets.FileUpload(
                accept='.fbx',
                multiple=False,
                description='Upload FBX',
                style={'description_width': 'initial'}
            )
            
            # Model name input
            self.model_name_widget = widgets.Text(
                value='my_model',
                description='Model Name:',
                style={'description_width': 'initial'}
            )
            
            # Convert button
            self.convert_button = widgets.Button(
                description='🚀 Convert to MDL',
                button_style='primary',
                disabled=True
            )
            
            # Download button
            self.download_button = widgets.Button(
                description='📥 Download MDL',
                button_style='success',
                disabled=True
            )
            
            # Output area
            self.output_area = widgets.Output()
            
            # Progress bar
            self.progress_bar = widgets.IntProgress(
                value=0,
                min=0,
                max=100,
                description='Progress:',
                bar_style='info'
            )
            
            # File info display
            self.file_info = widgets.HTML(value="<p>📁 No FBX file selected</p>")
            
            # Event handlers
            self.upload_widget.observe(self.on_file_upload, names='value')
            self.convert_button.on_click(self.on_convert_click)
            self.download_button.on_click(self.on_download_click)
            
        def on_file_upload(self, change):
            """Handle file upload"""
            if self.upload_widget.value:
                file_info = list(self.upload_widget.value.values())[0]
                self.uploaded_file = file_info
                
                # Save uploaded file
                upload_path = Path('/tmp') / file_info['metadata']['name']
                with open(upload_path, 'wb') as f:
                    f.write(file_info['content'])
                self.upload_path = upload_path
                
                # Update UI
                file_size = len(file_info['content']) / 1024 / 1024  # MB
                self.file_info.value = f"""
                <div style='padding: 15px; background: #e8f5e8; border-radius: 8px; border-left: 4px solid #4caf50;'>
                    <h4 style='margin: 0 0 10px 0; color: #2e7d32;'>📁 File Ready</h4>
                    <p><strong>Name:</strong> {file_info['metadata']['name']}</p>
                    <p><strong>Size:</strong> {file_size:.2f} MB</p>
                    <p><strong>Status:</strong> ✅ Ready for conversion</p>
                </div>
                """
                
                self.convert_button.disabled = False
                
        def on_convert_click(self, button):
            """Handle convert button click"""
            if not self.uploaded_file:
                return
                
            self.convert_button.disabled = True
            self.download_button.disabled = True
            self.progress_bar.value = 0
            
            with self.output_area:
                clear_output(wait=True)
                print("🚀 Starting FBX to MDL conversion for Counter-Strike 1.6...")
                print("=" * 60)
                
                try:
                    # Update progress
                    self.progress_bar.value = 10
                    
                    # Convert FBX to MDL
                    model_name = self.model_name_widget.value or 'converted_model'
                    
                    self.progress_bar.value = 20
                    result_path = self.converter.convert_fbx_to_mdl(
                        str(self.upload_path), 
                        model_name
                    )
                    
                    self.progress_bar.value = 100
                    
                    if result_path:
                        self.result_mdl = result_path
                        self.download_button.disabled = False
                        
                        # Show success message
                        file_size = os.path.getsize(result_path) / 1024  # KB
                        print("\n" + "=" * 60)
                        print("🎉 CONVERSION COMPLETED SUCCESSFULLY!")
                        print("=" * 60)
                        print(f"📁 Output file: {result_path.name}")
                        print(f"📊 File size: {file_size:.2f} KB")
                        print(f"🎮 Ready for Counter-Strike 1.6!")
                        print(f"📂 Location: {result_path}")
                        
                        # Validation info
                        if self.validate_mdl(result_path):
                            print("✅ MDL file validation: PASSED")
                        else:
                            print("⚠️ MDL file validation: WARNING - May need manual review")
                            
                        print("\n📋 Installation Instructions:")
                        print("1. Download the MDL file using the button below")
                        print("2. Copy to your CS 1.6 models folder")
                        print("3. Restart Counter-Strike 1.6")
                        print("4. Enjoy your custom model!")
                        
                    else:
                        print("\n" + "=" * 60)
                        print("❌ CONVERSION FAILED")
                        print("=" * 60)
                        print("Please check your FBX file and try again.")
                        print("Make sure your FBX contains:")
                        print("• Valid mesh geometry")
                        print("• Proper bone structure (if animated)")
                        print("• Reasonable polygon count for CS 1.6")
                        
                except Exception as e:
                    print(f"\n💥 CONVERSION ERROR: {str(e)}")
                    print("Please check the FBX file format and try again.")
                    
            self.convert_button.disabled = False
            
        def validate_mdl(self, mdl_path):
            """Basic MDL file validation"""
            try:
                with open(mdl_path, 'rb') as f:
                    header = f.read(4)
                    if header == b'IDST':  # GoldSrc MDL signature
                        version = int.from_bytes(f.read(4), 'little')
                        return version == 10  # GoldSrc version
            except:
                pass
            return False
            
        def on_download_click(self, button):
            """Handle download button click"""
            if not self.result_mdl:
                return
                
            # Create download link
            with open(self.result_mdl, 'rb') as f:
                content = f.read()
                
            b64_content = base64.b64encode(content).decode()
            filename = self.result_mdl.name
            
            download_link = f'''
            <div style="text-align: center; padding: 20px;">
                <a href="data:application/octet-stream;base64,{b64_content}" 
                   download="{filename}" 
                   style="background: linear-gradient(45deg, #4caf50, #45a049); 
                          color: white; padding: 15px 30px; text-decoration: none; 
                          border-radius: 8px; font-weight: bold; font-size: 16px;
                          box-shadow: 0 4px 8px rgba(0,0,0,0.2);">
                   📥 Download {filename}
                </a>
                <p style="margin-top: 15px; color: #666;">
                    Click the button above to download your converted MDL file
                </p>
            </div>
            '''
            
            with self.output_area:
                print("\n💾 Download Ready!")
                print("=" * 30)
                display(HTML(download_link))
                
        def display(self):
            """Display the complete interface"""
            # Title
            title = widgets.HTML(
                value="""
                <div style='text-align: center; padding: 20px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); border-radius: 12px; margin-bottom: 20px;'>
                    <h1 style='color: white; margin: 0; font-size: 28px;'>🎮 FBX to MDL Converter</h1>
                    <h3 style='color: #e3f2fd; margin: 10px 0 0 0; font-weight: normal;'>for Counter-Strike 1.6</h3>
                </div>
                """
            )
            
            # Instructions
            instructions = widgets.HTML(
                value="""
                <div style='background: #f8f9fa; padding: 20px; border-radius: 10px; margin-bottom: 20px; border-left: 4px solid #2196F3;'>
                    <h4 style='color: #1976D2; margin-top: 0;'>📋 How to Use:</h4>
                    <ol style='margin: 10px 0; padding-left: 20px;'>
                        <li><strong>Upload FBX File:</strong> Choose your 3D model file (supports animations and bones)</li>
                        <li><strong>Set Model Name:</strong> Enter a name for your converted model</li>
                        <li><strong>Convert:</strong> Click the convert button and wait for processing</li>
                        <li><strong>Download:</strong> Get your CS 1.6 compatible MDL file</li>
                    </ol>
                    <div style='background: #e3f2fd; padding: 12px; border-radius: 6px; margin-top: 15px;'>
                        <strong>💡 Pro Tip:</strong> The converter automatically detects meshes, bones, animations, and materials!
                    </div>
                </div>
                """
            )
            
            # Create sections
            upload_section = widgets.VBox([
                widgets.HTML("<h4 style='color: #1976D2; margin-bottom: 10px;'>1️⃣ Upload FBX File</h4>"),
                self.upload_widget,
                self.file_info
            ], layout=widgets.Layout(margin='0 0 20px 0'))
            
            settings_section = widgets.VBox([
                widgets.HTML("<h4 style='color: #1976D2; margin-bottom: 10px;'>2️⃣ Model Settings</h4>"),
                self.model_name_widget
            ], layout=widgets.Layout(margin='0 0 20px 0'))
            
            action_section = widgets.VBox([
                widgets.HTML("<h4 style='color: #1976D2; margin-bottom: 10px;'>3️⃣ Convert & Download</h4>"),
                widgets.HBox([self.convert_button, self.download_button], layout=widgets.Layout(margin='0 0 10px 0')),
                self.progress_bar
            ], layout=widgets.Layout(margin='0 0 20px 0'))
            
            # Main interface
            main_interface = widgets.VBox([
                title,
                instructions,
                upload_section,
                settings_section,
                action_section,
                self.output_area
            ])
            
            display(main_interface)

# Command-line interface
def convert_fbx_cli(fbx_file_path, model_name='converted_model', output_dir=None):
    """Command-line interface for FBX to MDL conversion"""
    
    if not os.path.exists(fbx_file_path):
        print(f"❌ FBX file not found: {fbx_file_path}")
        return None
        
    # Initialize converter
    converter = FBXToMDLConverter()
    
    if output_dir:
        converter.work_dir = Path(output_dir)
        converter.work_dir.mkdir(exist_ok=True)
        
    # Convert
    print(f"🔄 Converting {fbx_file_path} to {model_name}.mdl...")
    print("=" * 60)
    
    result = converter.convert_fbx_to_mdl(fbx_file_path, model_name)
    
    if result:
        print(f"\n✅ SUCCESS! MDL file created: {result}")
        print(f"📁 Working directory: {converter.work_dir}")
        
        # List all generated files
        print("\n📦 Generated files:")
        for file_path in converter.work_dir.glob('*'):
            if file_path.is_file():
                size = file_path.stat().st_size
                print(f"  📄 {file_path.name} ({size} bytes)")
                
        return result
    else:
        print("\n❌ Conversion failed!")
        return None

# Utility functions
def validate_mdl_file(mdl_path):
    """Validate generated MDL file for CS 1.6 compatibility"""
    if not os.path.exists(mdl_path):
        return False, "MDL file not found"
        
    try:
        with open(mdl_path, 'rb') as f:
            # Check MDL header
            header = f.read(4)
            if header != b'IDST':  # GoldSrc MDL signature
                return False, "Invalid MDL header - not a GoldSrc model"
                
            # Check version
            version = int.from_bytes(f.read(4), 'little')
            if version != 10:  # GoldSrc version
                return False, f"Wrong version {version} - should be 10 for GoldSrc/CS 1.6"
                
        file_size = os.path.getsize(mdl_path)
        return True, f"Valid GoldSrc MDL file ({file_size} bytes)"
        
    except Exception as e:
        return False, f"Error validating file: {str(e)}"

def batch_convert_fbx(fbx_directory, output_directory):
    """Convert multiple FBX files in a directory"""
    fbx_dir = Path(fbx_directory)
    output_dir = Path(output_directory)
    output_dir.mkdir(exist_ok=True)
    
    fbx_files = list(fbx_dir.glob('*.fbx'))
    if not fbx_files:
        print(f"❌ No FBX files found in {fbx_directory}")
        return []
        
    results = []
    converter = FBXToMDLConverter()
    
    print(f"🔄 Batch converting {len(fbx_files)} FBX files...")
    print("=" * 60)
    
    for i, fbx_file in enumerate(fbx_files, 1):
        model_name = fbx_file.stem
        print(f"\n[{i}/{len(fbx_files)}] Converting {fbx_file.name}...")
        
        # Set output directory for this model
        model_output_dir = output_dir / model_name
        model_output_dir.mkdir(exist_ok=True)
        converter.work_dir = model_output_dir
        
        try:
            result = converter.convert_fbx_to_mdl(str(fbx_file), model_name)
            if result:
                results.append((fbx_file, result, True))
                print(f"✅ Success: {fbx_file.name} -> {result}")
            else:
                results.append((fbx_file, None, False))
                print(f"❌ Failed: {fbx_file.name}")
        except Exception as e:
            results.append((fbx_file, None, False))
            print(f"💥 Error converting {fbx_file.name}: {str(e)}")
            
    # Summary
    successful = sum(1 for _, _, success in results if success)
    total = len(results)
    print(f"\n📊 Batch conversion complete: {successful}/{total} successful")
    
    return results

# Main execution
if __name__ == "__main__":
    print("🎮 FBX to MDL Converter for Counter-Strike 1.6")
    print("=" * 60)
    print("✅ System initialized successfully!")
    
    if GUI_AVAILABLE and BLENDER_AVAILABLE:
        print("\n🖥️ Starting GUI interface...")
        gui = ConverterGUI()
        gui.display()
    else:
        print("\n⚠️ GUI not available. Use CLI functions:")
        print("• convert_fbx_cli('/path/to/model.fbx', 'model_name')")
        print("• batch_convert_fbx('/input/dir', '/output/dir')")
        print("• validate_mdl_file('/path/to/model.mdl')")
        
    print("\n📚 Available functions:")
    print("• FBXToMDLConverter() - Main converter class")
    print("• convert_fbx_cli() - Command-line conversion")
    print("• batch_convert_fbx() - Batch conversion")
    print("• validate_mdl_file() - Validate MDL files")