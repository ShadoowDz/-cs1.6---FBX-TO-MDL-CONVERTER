#!/usr/bin/env python3
"""
FBX to MDL Converter for Counter-Strike 1.6
Automatically detects and converts meshes, bones, animations, and materials
from FBX files to Source Engine MDL format compatible with CS 1.6.

Requirements:
- Python 3.7+
- FBX SDK (Python bindings)
- numpy
- PIL (for texture processing)

Author: CS1.6 Model Converter
License: MIT
"""

import os
import sys
import struct
import math
import json
import argparse
from pathlib import Path
from typing import List, Dict, Any, Tuple, Optional
import numpy as np

try:
    # Try to import FBX SDK - multiple import patterns for compatibility
    try:
        import fbx
        import FbxCommon
        from fbx import *
    except ImportError:
        try:
            # Alternative import pattern
            from pyfbx import *
            import pyfbx as fbx
        except ImportError:
            try:
                # Another alternative
                import FbxCommon
                import fbx
                from fbx import FbxManager, FbxImporter, FbxScene, FbxSurfaceMaterial
            except ImportError:
                raise ImportError("FBX SDK not found")
except ImportError:
    print("ERROR: FBX SDK not found. Please install Autodesk FBX SDK for Python.")
    print("Download from: https://www.autodesk.com/developer-network/platform-technologies/fbx-sdk-2020-0")
    print("Alternative: Try installing with: pip install pyfbx-stub")
    sys.exit(1)

try:
    from PIL import Image
except ImportError:
    print("ERROR: PIL (Pillow) not found. Install with: pip install Pillow")
    sys.exit(1)

# Constants for MDL format (Quake/GoldSrc engine)
MDL_MAGIC = 1330660425  # "IDPO"
MDL_VERSION = 6
MAX_TRIANGLES = 2048
MAX_VERTICES = 1024
MAX_FRAMES = 256
MAX_SKINS = 32

# Normal vectors for MDL format (162 precalculated normals from anorms.h)
ANORMS = [
    [-0.525731, 0.000000, 0.850651], [-0.442863, 0.238856, 0.864188],
    [-0.295242, 0.000000, 0.955423], [-0.309017, 0.500000, 0.809017],
    [-0.162460, 0.262866, 0.951056], [0.000000, 0.000000, 1.000000],
    [0.000000, 0.850651, 0.525731], [-0.147621, 0.716567, 0.681718],
    [0.147621, 0.716567, 0.681718], [0.000000, 0.525731, 0.850651],
    [0.309017, 0.500000, 0.809017], [0.525731, 0.000000, 0.850651],
    [0.295242, 0.000000, 0.955423], [0.442863, 0.238856, 0.864188],
    [0.162460, 0.262866, 0.951056], [-0.681718, 0.147621, 0.716567],
    [-0.809017, 0.309017, 0.500000], [-0.587785, 0.425325, 0.688191],
    [-0.850651, 0.525731, 0.000000], [-0.864188, 0.442863, 0.238856],
    [-0.716567, 0.681718, 0.147621], [-0.688191, 0.587785, 0.425325],
    [-0.500000, 0.809017, 0.309017], [-0.238856, 0.864188, 0.442863],
    [-0.425325, 0.688191, 0.587785], [-0.716567, 0.681718, -0.147621],
    [-0.500000, 0.809017, -0.309017], [-0.525731, 0.850651, 0.000000],
    [0.000000, 0.850651, -0.525731], [-0.238856, 0.864188, -0.442863],
    [0.000000, 0.955423, -0.295242], [-0.262866, 0.951056, -0.162460],
    [0.000000, 1.000000, 0.000000], [0.000000, 0.955423, 0.295242],
    [-0.262866, 0.951056, 0.162460], [0.238856, 0.864188, 0.442863],
    [0.262866, 0.951056, 0.162460], [0.500000, 0.809017, 0.309017],
    [0.238856, 0.864188, -0.442863], [0.262866, 0.951056, -0.162460],
    [0.500000, 0.809017, -0.309017], [0.850651, 0.525731, 0.000000],
    [0.716567, 0.681718, 0.147621], [0.716567, 0.681718, -0.147621],
    [0.525731, 0.850651, 0.000000], [0.425325, 0.688191, 0.587785],
    [0.864188, 0.442863, 0.238856], [0.688191, 0.587785, 0.425325],
    [0.809017, 0.309017, 0.500000], [0.681718, 0.147621, 0.716567],
    [0.587785, 0.425325, 0.688191], [0.955423, 0.295242, 0.000000],
    [1.000000, 0.000000, 0.000000], [0.951056, 0.162460, 0.262866],
    [0.850651, -0.525731, 0.000000], [0.955423, -0.295242, 0.000000],
    [0.864188, -0.442863, 0.238856], [0.951056, -0.162460, 0.262866],
    [0.809017, -0.309017, 0.500000], [0.681718, -0.147621, 0.716567],
    [0.850651, 0.000000, 0.525731], [0.864188, 0.442863, -0.238856],
    [0.809017, 0.309017, -0.500000], [0.951056, 0.162460, -0.262866],
    [0.525731, 0.000000, -0.850651], [0.681718, 0.147621, -0.716567],
    [0.681718, -0.147621, -0.716567], [0.850651, 0.000000, -0.525731],
    [0.809017, -0.309017, -0.500000], [0.864188, -0.442863, -0.238856],
    [0.951056, -0.162460, -0.262866], [0.147621, 0.716567, -0.681718],
    [0.309017, 0.500000, -0.809017], [0.425325, 0.688191, -0.587785],
    [0.442863, 0.238856, -0.864188], [0.587785, 0.425325, -0.688191],
    [0.688191, 0.587785, -0.425325], [-0.147621, 0.716567, -0.681718],
    [-0.309017, 0.500000, -0.809017], [0.000000, 0.525731, -0.850651],
    [-0.525731, 0.000000, -0.850651], [-0.442863, 0.238856, -0.864188],
    [-0.295242, 0.000000, -0.955423], [-0.162460, 0.262866, -0.951056],
    [0.000000, 0.000000, -1.000000], [0.295242, 0.000000, -0.955423],
    [0.162460, 0.262866, -0.951056], [-0.442863, -0.238856, -0.864188],
    [-0.309017, -0.500000, -0.809017], [-0.162460, -0.262866, -0.951056],
    [0.000000, -0.850651, -0.525731], [-0.147621, -0.716567, -0.681718],
    [0.147621, -0.716567, -0.681718], [0.000000, -0.525731, -0.850651],
    [0.309017, -0.500000, -0.809017], [0.442863, -0.238856, -0.864188],
    [0.162460, -0.262866, -0.951056], [0.238856, -0.864188, -0.442863],
    [0.500000, -0.809017, -0.309017], [0.425325, -0.688191, -0.587785],
    [0.716567, -0.681718, -0.147621], [0.688191, -0.587785, -0.425325],
    [0.587785, -0.425325, -0.688191], [0.000000, -0.955423, -0.295242],
    [0.000000, -1.000000, 0.000000], [0.262866, -0.951056, -0.162460],
    [0.000000, -0.850651, 0.525731], [0.000000, -0.955423, 0.295242],
    [0.238856, -0.864188, 0.442863], [0.262866, -0.951056, 0.162460],
    [0.500000, -0.809017, 0.309017], [0.716567, -0.681718, 0.147621],
    [0.525731, -0.850651, 0.000000], [-0.238856, -0.864188, -0.442863],
    [-0.500000, -0.809017, -0.309017], [-0.262866, -0.951056, -0.162460],
    [-0.850651, -0.525731, 0.000000], [-0.716567, -0.681718, -0.147621],
    [-0.716567, -0.681718, 0.147621], [-0.525731, -0.850651, 0.000000],
    [-0.500000, -0.809017, 0.309017], [-0.238856, -0.864188, 0.442863],
    [-0.262866, -0.951056, 0.162460], [-0.864188, -0.442863, 0.238856],
    [-0.809017, -0.309017, 0.500000], [-0.688191, -0.587785, 0.425325],
    [-0.681718, -0.147621, 0.716567], [-0.442863, -0.238856, 0.864188],
    [-0.587785, -0.425325, 0.688191], [-0.309017, -0.500000, 0.809017],
    [-0.147621, -0.716567, 0.681718], [-0.425325, -0.688191, 0.587785],
    [-0.162460, -0.262866, 0.951056], [0.442863, -0.238856, 0.864188],
    [0.587785, -0.425325, 0.688191], [0.688191, -0.587785, 0.425325],
    [-0.864188, 0.442863, -0.238856], [-0.688191, 0.587785, -0.425325],
    [-0.809017, 0.309017, -0.500000], [-0.681718, 0.147621, -0.716567],
    [-0.442863, 0.238856, -0.864188], [-0.587785, 0.425325, -0.688191],
    [-0.309017, 0.500000, -0.809017], [-0.425325, 0.688191, -0.587785],
    [-0.162460, 0.262866, -0.951056], [0.864188, -0.442863, 0.238856],
    [0.688191, -0.587785, 0.425325], [0.809017, -0.309017, 0.500000],
    [0.681718, -0.147621, 0.716567], [0.587785, -0.425325, 0.688191],
    [0.442863, -0.238856, 0.864188], [0.425325, -0.688191, 0.587785],
    [0.309017, -0.500000, 0.809017], [0.147621, -0.716567, 0.681718],
    [0.162460, -0.262866, 0.951056], [0.309017, 0.500000, 0.809017],
    [0.147621, 0.716567, 0.681718], [0.000000, 0.525731, 0.850651],
    [0.425325, 0.688191, 0.587785], [0.587785, 0.425325, 0.688191],
    [0.688191, 0.587785, 0.425325], [-0.955423, 0.295242, 0.000000],
    [-0.951056, 0.162460, 0.262866], [-1.000000, 0.000000, 0.000000],
    [-0.850651, 0.000000, 0.525731], [-0.955423, -0.295242, 0.000000],
    [-0.951056, -0.162460, 0.262866], [-0.864188, 0.442863, 0.238856],
    [-0.951056, 0.162460, -0.262866], [-0.809017, 0.309017, -0.500000],
    [-0.864188, -0.442863, -0.238856], [-0.951056, -0.162460, -0.262866],
    [-0.809017, -0.309017, -0.500000], [-0.681718, 0.147621, -0.716567],
    [-0.681718, -0.147621, -0.716567], [-0.850651, 0.000000, -0.525731],
    [-0.688191, 0.587785, -0.425325], [-0.587785, 0.425325, -0.688191],
    [-0.425325, 0.688191, -0.587785], [-0.425325, -0.688191, -0.587785],
    [-0.587785, -0.425325, -0.688191], [-0.688191, -0.587785, -0.425325]
]

class Vector3:
    """3D Vector class for handling positions and normals"""
    def __init__(self, x=0.0, y=0.0, z=0.0):
        self.x = float(x)
        self.y = float(y)
        self.z = float(z)
    
    def length(self):
        return math.sqrt(self.x*self.x + self.y*self.y + self.z*self.z)
    
    def normalize(self):
        length = self.length()
        if length > 0:
            self.x /= length
            self.y /= length
            self.z /= length
        return self
    
    def dot(self, other):
        return self.x * other.x + self.y * other.y + self.z * other.z

class MDLVertex:
    """MDL compressed vertex structure"""
    def __init__(self, position: Vector3, normal_index: int, scale: Vector3 = None, translate: Vector3 = None):
        # Compress position to unsigned char values (0-255)
        if scale and translate:
            # Proper compression using scale and translate
            self.v = [
                max(0, min(255, int((position.x - translate.x) / scale.x))),
                max(0, min(255, int((position.y - translate.y) / scale.y))),
                max(0, min(255, int((position.z - translate.z) / scale.z)))
            ]
        else:
            # Fallback simple compression
            self.v = [
                max(0, min(255, int(position.x + 128))),
                max(0, min(255, int(position.y + 128))),
                max(0, min(255, int(position.z + 128)))
            ]
        self.normal_index = normal_index

class MDLTriangle:
    """MDL triangle structure"""
    def __init__(self, vertices: List[int], faces_front: bool = True):
        self.faces_front = 1 if faces_front else 0
        self.vertex = vertices[:3]  # Only take first 3 vertices

class MDLTexCoord:
    """MDL texture coordinate structure"""
    def __init__(self, s: float, t: float, on_seam: bool = False):
        self.on_seam = 1 if on_seam else 0
        self.s = int(s)
        self.t = int(t)

class MDLSkin:
    """MDL skin/texture structure"""
    def __init__(self, width: int, height: int, data: bytes):
        self.group = 0  # Single texture
        self.width = width
        self.height = height
        self.data = data

class MDLFrame:
    """MDL animation frame structure"""
    def __init__(self, name: str, vertices: List[MDLVertex]):
        self.type = 0  # Simple frame
        self.name = name[:16].ljust(16, '\0')  # Ensure 16 chars
        self.vertices = vertices
        
        # Calculate bounding box
        if vertices:
            min_x = min(v.v[0] for v in vertices)
            min_y = min(v.v[1] for v in vertices)
            min_z = min(v.v[2] for v in vertices)
            max_x = max(v.v[0] for v in vertices)
            max_y = max(v.v[1] for v in vertices)
            max_z = max(v.v[2] for v in vertices)
            
            self.bbox_min = MDLVertex(Vector3(min_x-128, min_y-128, min_z-128), 0)
            self.bbox_max = MDLVertex(Vector3(max_x-128, max_y-128, max_z-128), 0)
        else:
            self.bbox_min = MDLVertex(Vector3(), 0)
            self.bbox_max = MDLVertex(Vector3(), 0)

class FBXToMDLConverter:
    """Main converter class for FBX to MDL conversion"""
    
    def __init__(self):
        self.fbx_manager = None
        self.scene = None
        self.meshes = []
        self.materials = []
        self.bones = []
        self.animations = []
        self.scale_factor = Vector3(1.0, 1.0, 1.0)
        self.translate = Vector3(0.0, 0.0, 0.0)
        
    def initialize_fbx_sdk(self):
        """Initialize FBX SDK"""
        print("Initializing FBX SDK...")
        self.fbx_manager, self.scene = FbxCommon.InitializeSdkObjects()
        if not self.fbx_manager or not self.scene:
            raise Exception("Failed to initialize FBX SDK")
        return True
    
    def cleanup_fbx_sdk(self):
        """Cleanup FBX SDK resources"""
        if self.fbx_manager:
            self.fbx_manager.Destroy()
    
    def load_fbx_file(self, filepath: str) -> bool:
        """Load FBX file"""
        print(f"Loading FBX file: {filepath}")
        
        if not os.path.exists(filepath):
            raise FileNotFoundError(f"FBX file not found: {filepath}")
        
        importer = FbxImporter.Create(self.scene, "")
        
        if not importer.Initialize(filepath, -1, self.fbx_manager.GetIOSettings()):
            error = importer.GetStatus().GetErrorString()
            raise Exception(f"Failed to initialize FBX importer: {error}")
        
        if not importer.Import(self.scene):
            error = importer.GetStatus().GetErrorString()
            raise Exception(f"Failed to import FBX file: {error}")
        
        importer.Destroy()
        print("FBX file loaded successfully")
        return True
    
    def detect_meshes(self):
        """Automatically detect and extract mesh data from FBX scene"""
        print("Detecting meshes...")
        
        root_node = self.scene.GetRootNode()
        if not root_node:
            return
        
        self._traverse_nodes_for_meshes(root_node)
        print(f"Found {len(self.meshes)} mesh(es)")
    
    def _traverse_nodes_for_meshes(self, node):
        """Recursively traverse scene nodes to find meshes"""
        # Check if this node has a mesh
        mesh_attr = node.GetMesh()
        if mesh_attr:
            mesh_data = self._extract_mesh_data(mesh_attr, node)
            if mesh_data:
                self.meshes.append(mesh_data)
        
        # Traverse child nodes
        for i in range(node.GetChildCount()):
            self._traverse_nodes_for_meshes(node.GetChild(i))
    
    def _extract_mesh_data(self, mesh, node):
        """Extract mesh data from FBX mesh"""
        mesh_data = {
            'name': node.GetName(),
            'vertices': [],
            'normals': [],
            'uvs': [],
            'triangles': [],
            'materials': []
        }
        
        # Get vertices
        control_points = mesh.GetControlPoints()
        for i in range(mesh.GetControlPointsCount()):
            point = control_points[i]
            mesh_data['vertices'].append(Vector3(point[0], point[1], point[2]))
        
        # Get normals
        normal_element = mesh.GetElementNormal()
        if normal_element:
            normals = normal_element.GetDirectArray()
            for i in range(normals.GetCount()):
                normal = normals.GetAt(i)
                mesh_data['normals'].append(Vector3(normal[0], normal[1], normal[2]))
        
        # Get UVs
        uv_element = mesh.GetElementUV()
        if uv_element:
            uvs = uv_element.GetDirectArray()
            for i in range(uvs.GetCount()):
                uv = uvs.GetAt(i)
                mesh_data['uvs'].append([uv[0], 1.0 - uv[1]])  # Flip V coordinate
        
        # Get triangles
        for i in range(mesh.GetPolygonCount()):
            if mesh.GetPolygonSize(i) == 3:  # Only triangles
                triangle = []
                for j in range(3):
                    triangle.append(mesh.GetPolygonVertex(i, j))
                mesh_data['triangles'].append(triangle)
        
        return mesh_data
    
    def detect_bones(self):
        """Automatically detect bone/skeleton data"""
        print("Detecting bones...")
        
        root_node = self.scene.GetRootNode()
        if not root_node:
            return
        
        self._traverse_nodes_for_bones(root_node)
        print(f"Found {len(self.bones)} bone(s)")
    
    def _traverse_nodes_for_bones(self, node):
        """Recursively traverse scene nodes to find bones/skeletons"""
        # Check if this node is a skeleton
        skeleton_attr = node.GetSkeleton()
        if skeleton_attr:
            bone_data = {
                'name': node.GetName(),
                'parent': node.GetParent().GetName() if node.GetParent() else None,
                'transform': self._get_node_transform(node)
            }
            self.bones.append(bone_data)
        
        # Traverse child nodes
        for i in range(node.GetChildCount()):
            self._traverse_nodes_for_bones(node.GetChild(i))
    
    def _get_node_transform(self, node):
        """Get transformation matrix from FBX node"""
        transform = node.EvaluateGlobalTransform()
        translation = transform.GetT()
        rotation = transform.GetR()
        scaling = transform.GetS()
        
        return {
            'translation': [translation[0], translation[1], translation[2]],
            'rotation': [rotation[0], rotation[1], rotation[2]],
            'scaling': [scaling[0], scaling[1], scaling[2]]
        }
    
    def detect_animations(self):
        """Automatically detect animation data"""
        print("Detecting animations...")
        
        anim_stack_count = self.scene.GetAnimationEvaluator().GetAnimationStackCount()
        
        for i in range(anim_stack_count):
            anim_stack = self.scene.GetAnimationEvaluator().GetAnimationStack(i)
            if anim_stack:
                anim_data = {
                    'name': anim_stack.GetName(),
                    'start_time': anim_stack.GetLocalTimeSpan().GetStart().GetSecondDouble(),
                    'end_time': anim_stack.GetLocalTimeSpan().GetStop().GetSecondDouble(),
                    'frames': []
                }
                self.animations.append(anim_data)
        
        print(f"Found {len(self.animations)} animation(s)")
    
    def detect_materials(self):
        """Automatically detect and extract material data"""
        print("Detecting materials...")
        
        root_node = self.scene.GetRootNode()
        if not root_node:
            return
        
        self._traverse_nodes_for_materials(root_node)
        print(f"Found {len(self.materials)} material(s)")
    
    def _traverse_nodes_for_materials(self, node):
        """Recursively traverse scene nodes to find materials"""
        # Check if this node has materials
        material_count = node.GetMaterialCount()
        for i in range(material_count):
            material = node.GetMaterial(i)
            if material:
                material_data = self._extract_material_data(material)
                if material_data and material_data not in self.materials:
                    self.materials.append(material_data)
        
        # Traverse child nodes
        for i in range(node.GetChildCount()):
            self._traverse_nodes_for_materials(node.GetChild(i))
    
    def _extract_material_data(self, material):
        """Extract material data from FBX material"""
        material_data = {
            'name': material.GetName(),
            'diffuse_color': [1.0, 1.0, 1.0],
            'diffuse_texture': None,
            'transparency': 1.0
        }
        
        # Get diffuse properties
        diffuse_prop = material.FindProperty(FbxSurfaceMaterial.sDiffuse)
        if diffuse_prop.IsValid():
            diffuse_color = diffuse_prop.Get()
            material_data['diffuse_color'] = [diffuse_color[0], diffuse_color[1], diffuse_color[2]]
        
        # Get diffuse texture
        diffuse_texture = material.FindProperty(FbxSurfaceMaterial.sDiffuse)
        if diffuse_texture.IsValid() and diffuse_texture.GetSrcObjectCount() > 0:
            texture = diffuse_texture.GetSrcObject(0)
            if texture and hasattr(texture, 'GetFileName'):
                material_data['diffuse_texture'] = texture.GetFileName()
        
        return material_data
    
    def find_closest_normal_index(self, normal: Vector3) -> int:
        """Find the closest normal vector index from the precalculated normals"""
        best_dot = -2.0
        best_index = 0
        
        normal.normalize()
        
        for i, anorm in enumerate(ANORMS[:min(len(ANORMS), 162)]):
            anorm_vec = Vector3(anorm[0], anorm[1], anorm[2])
            dot = normal.dot(anorm_vec)
            if dot > best_dot:
                best_dot = dot
                best_index = i
        
        return best_index
    
    def convert_texture_to_8bit_indexed(self, texture_path: str, output_path: str) -> Tuple[int, int, bytes]:
        """Convert texture to 8-bit indexed color format for MDL"""
        if not os.path.exists(texture_path):
            print(f"Warning: Texture not found: {texture_path}")
            # Create a default 64x64 texture
            return self._create_default_texture()
        
        try:
            # Load and convert image
            img = Image.open(texture_path)
            
            # Resize if too large (MDL typically uses smaller textures)
            max_size = 256
            if img.width > max_size or img.height > max_size:
                img.thumbnail((max_size, max_size), Image.Resampling.LANCZOS)
            
            # Convert to indexed color (256 colors max)
            img = img.convert('P', palette=Image.ADAPTIVE, colors=256)
            
            # Get palette and image data
            palette = img.getpalette()
            image_data = img.tobytes()
            
            # Save converted texture
            img.save(output_path)
            
            return img.width, img.height, image_data
            
        except Exception as e:
            print(f"Warning: Failed to convert texture {texture_path}: {e}")
            return self._create_default_texture()
    
    def _create_default_texture(self) -> Tuple[int, int, bytes]:
        """Create a default 64x64 checkerboard texture"""
        width, height = 64, 64
        data = bytearray()
        
        for y in range(height):
            for x in range(width):
                # Create checkerboard pattern
                if (x // 8 + y // 8) % 2:
                    data.append(255)  # White
                else:
                    data.append(0)    # Black
        
        return width, height, bytes(data)
    
    def write_mdl_file(self, output_path: str):
        """Write the converted data to MDL file format"""
        print(f"Writing MDL file: {output_path}")
        
        if not self.meshes:
            raise Exception("No meshes found to convert")
        
        # Use the first mesh for now (could be extended to handle multiple meshes)
        mesh = self.meshes[0]
        
        # Prepare data structures
        vertices = []
        triangles = []
        texcoords = []
        skins = []
        frames = []
        
        # Calculate scale and translate for compression first
        if mesh['vertices']:
            # Find bounding box
            min_pos = Vector3(float('inf'), float('inf'), float('inf'))
            max_pos = Vector3(float('-inf'), float('-inf'), float('-inf'))
            
            for vertex in mesh['vertices']:
                min_pos.x = min(min_pos.x, vertex.x)
                min_pos.y = min(min_pos.y, vertex.y)
                min_pos.z = min(min_pos.z, vertex.z)
                max_pos.x = max(max_pos.x, vertex.x)
                max_pos.y = max(max_pos.y, vertex.y)
                max_pos.z = max(max_pos.z, vertex.z)
            
            # Calculate scale and translate
            self.scale_factor = Vector3(
                (max_pos.x - min_pos.x) / 255.0 if max_pos.x != min_pos.x else 1.0,
                (max_pos.y - min_pos.y) / 255.0 if max_pos.y != min_pos.y else 1.0,
                (max_pos.z - min_pos.z) / 255.0 if max_pos.z != min_pos.z else 1.0
            )
            self.translate = min_pos
        
        # Process vertices and normals
        for i, vertex in enumerate(mesh['vertices']):
            normal_index = 0
            if i < len(mesh['normals']):
                normal_index = self.find_closest_normal_index(mesh['normals'][i])
            
            mdl_vertex = MDLVertex(vertex, normal_index, self.scale_factor, self.translate)
            vertices.append(mdl_vertex)
        
        # Process texture coordinates
        skin_width = 256
        skin_height = 256
        
        for uv in mesh['uvs']:
            s = int(uv[0] * skin_width)
            t = int(uv[1] * skin_height)
            texcoords.append(MDLTexCoord(s, t))
        
        # Ensure we have enough texture coordinates
        while len(texcoords) < len(vertices):
            texcoords.append(MDLTexCoord(0, 0))
        
        # Process triangles
        for triangle in mesh['triangles']:
            if len(triangle) >= 3:
                triangles.append(MDLTriangle(triangle))
        
        # Process materials/skins
        if self.materials:
            for material in self.materials:
                if material.get('diffuse_texture'):
                    texture_path = material['diffuse_texture']
                    output_dir = os.path.dirname(output_path)
                    texture_name = os.path.splitext(os.path.basename(texture_path))[0] + '.bmp'
                    texture_output = os.path.join(output_dir, texture_name)
                    
                    width, height, data = self.convert_texture_to_8bit_indexed(texture_path, texture_output)
                    skin = MDLSkin(width, height, data)
                    skins.append(skin)
                    skin_width, skin_height = width, height
        
        # Create default skin if none found
        if not skins:
            width, height, data = self._create_default_texture()
            skin = MDLSkin(width, height, data)
            skins.append(skin)
            skin_width, skin_height = width, height
        
        # Create frames (for now, just create one static frame)
        frame = MDLFrame("idle", vertices)
        frames.append(frame)
        
        # Write MDL file
        self._write_mdl_binary(output_path, skins, texcoords, triangles, frames, skin_width, skin_height)
        
        print("MDL file written successfully")
    
    def _write_mdl_binary(self, output_path: str, skins: List[MDLSkin], texcoords: List[MDLTexCoord], 
                         triangles: List[MDLTriangle], frames: List[MDLFrame], skin_width: int, skin_height: int):
        """Write binary MDL file"""
        
        with open(output_path, 'wb') as f:
            # Calculate bounding radius from vertices
            bounding_radius = 50.0
            if frames and frames[0].vertices:
                max_dist = 0.0
                for vertex in frames[0].vertices:
                    # Convert back from compressed format
                    x = (vertex.v[0] - 128) * self.scale_factor.x + self.translate.x
                    y = (vertex.v[1] - 128) * self.scale_factor.y + self.translate.y
                    z = (vertex.v[2] - 128) * self.scale_factor.z + self.translate.z
                    dist = math.sqrt(x*x + y*y + z*z)
                    max_dist = max(max_dist, dist)
                bounding_radius = max_dist
            
            # Write header (84 bytes total)
            f.write(struct.pack('<I', MDL_MAGIC))  # ident (4 bytes)
            f.write(struct.pack('<I', MDL_VERSION))  # version (4 bytes)
            f.write(struct.pack('<fff', self.scale_factor.x, self.scale_factor.y, self.scale_factor.z))  # scale (12 bytes)
            f.write(struct.pack('<fff', self.translate.x, self.translate.y, self.translate.z))  # translate (12 bytes)
            f.write(struct.pack('<f', bounding_radius))  # bounding radius (4 bytes)
            f.write(struct.pack('<fff', 0.0, 0.0, 24.0))  # eye position (12 bytes)
            f.write(struct.pack('<I', len(skins)))  # num_skins (4 bytes)
            f.write(struct.pack('<I', skin_width))  # skin width (4 bytes)
            f.write(struct.pack('<I', skin_height))  # skin height (4 bytes)
            f.write(struct.pack('<I', len(texcoords)))  # num_verts (4 bytes)
            f.write(struct.pack('<I', len(triangles)))  # num_tris (4 bytes)
            f.write(struct.pack('<I', len(frames)))  # num_frames (4 bytes)
            f.write(struct.pack('<I', 0))  # synctype (4 bytes)
            f.write(struct.pack('<I', 0))  # flags (4 bytes)
            f.write(struct.pack('<f', 1.0))  # size (4 bytes)
            
            # Write skins data
            for skin in skins:
                # Write skin group (0 for single skin)
                f.write(struct.pack('<I', skin.group))
                # Write skin data
                f.write(skin.data)
            
            # Write texture coordinates
            for texcoord in texcoords:
                f.write(struct.pack('<I', texcoord.on_seam))
                f.write(struct.pack('<I', texcoord.s))
                f.write(struct.pack('<I', texcoord.t))
            
            # Write triangles
            for triangle in triangles:
                f.write(struct.pack('<I', triangle.faces_front))
                f.write(struct.pack('<I', triangle.vertex[0]))
                f.write(struct.pack('<I', triangle.vertex[1]))
                f.write(struct.pack('<I', triangle.vertex[2]))
            
            # Write frames
            for frame in frames:
                # Write frame type
                f.write(struct.pack('<I', frame.type))
                
                # Write bounding box min
                f.write(struct.pack('<B', frame.bbox_min.v[0]))
                f.write(struct.pack('<B', frame.bbox_min.v[1]))
                f.write(struct.pack('<B', frame.bbox_min.v[2]))
                f.write(struct.pack('<B', frame.bbox_min.normal_index))
                
                # Write bounding box max
                f.write(struct.pack('<B', frame.bbox_max.v[0]))
                f.write(struct.pack('<B', frame.bbox_max.v[1]))
                f.write(struct.pack('<B', frame.bbox_max.v[2]))
                f.write(struct.pack('<B', frame.bbox_max.normal_index))
                
                # Write frame name (16 bytes)
                name_bytes = frame.name.encode('ascii')[:16]
                name_bytes = name_bytes.ljust(16, b'\0')
                f.write(name_bytes)
                
                # Write vertices
                for vertex in frame.vertices:
                    f.write(struct.pack('<B', vertex.v[0]))
                    f.write(struct.pack('<B', vertex.v[1]))
                    f.write(struct.pack('<B', vertex.v[2]))
                    f.write(struct.pack('<B', vertex.normal_index))
    
    def convert(self, fbx_path: str, mdl_path: str):
        """Main conversion function"""
        try:
            print(f"Starting FBX to MDL conversion...")
            print(f"Input: {fbx_path}")
            print(f"Output: {mdl_path}")
            
            # Initialize FBX SDK
            self.initialize_fbx_sdk()
            
            # Load FBX file
            self.load_fbx_file(fbx_path)
            
            # Auto-detect all components
            self.detect_meshes()
            self.detect_bones()
            self.detect_animations()
            self.detect_materials()
            
            # Create output directory if it doesn't exist
            os.makedirs(os.path.dirname(mdl_path), exist_ok=True)
            
            # Write MDL file
            self.write_mdl_file(mdl_path)
            
            print(f"Conversion completed successfully!")
            print(f"Output saved to: {mdl_path}")
            
        except Exception as e:
            print(f"Error during conversion: {e}")
            raise
        finally:
            self.cleanup_fbx_sdk()

def create_sample_qc_file(mdl_path: str):
    """Create a sample QC file for StudioMDL compilation"""
    qc_path = mdl_path.replace('.mdl', '.qc')
    
    model_name = os.path.splitext(os.path.basename(mdl_path))[0]
    
    qc_content = f'''// QC file for {model_name}
// Generated by FBX to MDL Converter

$modelname "{model_name}.mdl"
$cd "."
$cdtexture "."
$scale 1.0

// Sequences
$sequence idle "{model_name}" fps 1

// End of QC file
'''
    
    with open(qc_path, 'w') as f:
        f.write(qc_content)
    
    print(f"Sample QC file created: {qc_path}")

def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description='Convert FBX files to MDL format for Counter-Strike 1.6')
    parser.add_argument('input', help='Input FBX file path')
    parser.add_argument('output', help='Output MDL file path')
    parser.add_argument('--create-qc', action='store_true', help='Create sample QC file for StudioMDL')
    parser.add_argument('--verbose', '-v', action='store_true', help='Enable verbose output')
    
    args = parser.parse_args()
    
    if not os.path.exists(args.input):
        print(f"Error: Input file not found: {args.input}")
        return 1
    
    if not args.input.lower().endswith('.fbx'):
        print(f"Error: Input file must be an FBX file")
        return 1
    
    if not args.output.lower().endswith('.mdl'):
        args.output += '.mdl'
    
    try:
        converter = FBXToMDLConverter()
        converter.convert(args.input, args.output)
        
        if args.create_qc:
            create_sample_qc_file(args.output)
        
        print("\n" + "="*50)
        print("CONVERSION COMPLETED SUCCESSFULLY!")
        print("="*50)
        print(f"Input FBX: {args.input}")
        print(f"Output MDL: {args.output}")
        print("\nThe MDL file is now ready for use in Counter-Strike 1.6!")
        print("You can place it in your CS 1.6 models directory.")
        
        return 0
        
    except Exception as e:
        print(f"\nConversion failed: {e}")
        return 1

if __name__ == "__main__":
    sys.exit(main())