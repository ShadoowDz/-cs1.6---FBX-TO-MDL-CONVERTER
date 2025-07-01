# FBX to MDL Converter for Counter-Strike 1.6

A comprehensive Python tool that automatically converts FBX files to MDL format compatible with Counter-Strike 1.6. This converter performs **100% automatic detection** of meshes, bones, animations, and materials from FBX files.

## ✨ Features

- **🔍 Automatic Detection**: Automatically finds and extracts:
  - Meshes (vertices, normals, UV coordinates, triangles)
  - Bones and skeleton data with transforms
  - Animation sequences with timing
  - Materials and texture data
- **📐 Proper MDL Format**: Creates CS 1.6 compatible MDL files with:
  - Correct magic number (IDPO) and version (6)
  - Compressed vertex data (0-255 range)
  - 162 precalculated normal vectors
  - 8-bit indexed texture support
- **🎨 Material Processing**: Converts textures to MDL-compatible format
- **🦴 Skeleton Support**: Handles bone hierarchies and transforms
- **🎬 Animation Support**: Extracts animation frames and timing
- **⚙️ Easy to Use**: Simple command-line interface

## 🚀 Installation

### Prerequisites

1. **Python 3.7+**
2. **Autodesk FBX SDK** (required for FBX file reading)
3. **Python packages** (install via pip)

### Step 1: Install Python Dependencies

```bash
pip install -r requirements.txt
```

### Step 2: Install FBX SDK

Download and install the Autodesk FBX SDK for Python:

1. Go to [Autodesk FBX SDK Downloads](https://www.autodesk.com/developer-network/platform-technologies/fbx-sdk-2020-0)
2. Download the Python version for your platform
3. Follow the installation instructions
4. Make sure the FBX Python bindings are available in your Python environment

**Alternative**: Try the community version:
```bash
pip install pyfbx-stub
```

## 📖 Usage

### Basic Usage

Convert an FBX file to MDL format:

```bash
python fbx_to_mdl_converter.py input.fbx output.mdl
```

### Advanced Usage

Generate QC file for StudioMDL compilation:

```bash
python fbx_to_mdl_converter.py input.fbx output.mdl --create-qc
```

Enable verbose output:

```bash
python fbx_to_mdl_converter.py input.fbx output.mdl --verbose
```

### Usage Examples

```bash
# Convert a weapon model
python fbx_to_mdl_converter.py ak47.fbx models/weapons/ak47.mdl

# Convert a player model with QC file
python fbx_to_mdl_converter.py player.fbx models/player/terrorist.mdl --create-qc

# Convert with verbose output
python fbx_to_mdl_converter.py model.fbx output.mdl -v
```

## 🔧 How It Works

### Automatic Detection Process

1. **FBX Scene Traversal**: Recursively explores all nodes in the FBX scene
2. **Mesh Detection**: Identifies mesh nodes and extracts:
   - Control points (vertices)
   - Normal vectors
   - UV coordinates
   - Triangle indices
3. **Bone Detection**: Finds skeleton nodes and captures:
   - Bone hierarchy
   - Transformation matrices
   - Parent-child relationships
4. **Animation Detection**: Discovers animation stacks with:
   - Frame timing
   - Animation sequences
   - Keyframe data
5. **Material Detection**: Extracts material properties:
   - Diffuse colors
   - Texture file paths
   - Material names

### MDL Format Conversion

1. **Vertex Compression**: Converts 3D coordinates to 0-255 range
2. **Normal Mapping**: Maps normals to 162 precalculated vectors
3. **Texture Processing**: Converts to 8-bit indexed color format
4. **Binary Writing**: Creates proper MDL binary structure

## 📁 File Structure

```
fbx_to_mdl_converter.py    # Main converter script
requirements.txt           # Python dependencies
test_converter.py         # Test and validation script
README.md                 # This file
```

## 🧪 Testing

Run the test suite to validate the converter:

```bash
python test_converter.py
```

This will:
- Test converter imports and functionality
- Validate MDL file structure
- Check all required components

## 📝 Technical Details

### Supported FBX Features

| Feature | Support | Notes |
|---------|---------|-------|
| Meshes | ✅ Full | Vertices, normals, UVs, triangles |
| Materials | ✅ Full | Diffuse color, textures |
| Textures | ✅ Full | Auto-converted to 8-bit indexed |
| Bones | ✅ Full | Hierarchy, transforms |
| Animations | ✅ Full | Multiple sequences, timing |
| Cameras | ❌ No | Not supported in MDL format |
| Lights | ❌ No | Not supported in MDL format |

### MDL Format Specifications

- **Magic Number**: `1330660425` ("IDPO")
- **Version**: `6` (Counter-Strike 1.6)
- **Max Triangles**: 2048
- **Max Vertices**: 1024
- **Max Frames**: 256
- **Max Skins**: 32
- **Normal Vectors**: 162 precalculated (anorms.h)

### Vertex Compression

Vertices are compressed from floating-point to unsigned char (0-255):

```python
compressed_value = (vertex_position - min_bound) / scale_factor
```

Where:
- `scale_factor = (max_bound - min_bound) / 255.0`
- `min_bound` and `max_bound` are calculated from mesh bounding box

## 🎯 CS 1.6 Integration

### Using Generated MDL Files

1. Place `.mdl` files in your CS 1.6 models directory:
   ```
   cstrike/models/player/
   cstrike/models/weapons/
   cstrike/models/props/
   ```

2. If textures are included, place them in the same directory

3. The models will be automatically loaded by the game

### QC File Generation

The converter can generate QC files for use with StudioMDL:

```qc
$modelname "model.mdl"
$cd "."
$cdtexture "."
$scale 1.0
$sequence idle "model" fps 1
```

## 🔍 Troubleshooting

### Common Issues

**FBX SDK not found:**
```
ERROR: FBX SDK not found. Please install Autodesk FBX SDK for Python.
```
- Install FBX SDK from Autodesk website
- Try alternative: `pip install pyfbx-stub`

**No meshes detected:**
- Check if FBX file contains mesh data
- Ensure FBX file is not corrupted
- Try exporting FBX with different settings

**Texture conversion failed:**
- Check if texture files exist
- Ensure textures are in supported formats (PNG, JPG, BMP, TGA)
- Converter will create default checkerboard if textures missing

**MDL file invalid:**
- Run test script to validate: `python test_converter.py`
- Check file permissions and disk space
- Verify input FBX file integrity

### Debug Mode

Enable verbose output for detailed information:

```bash
python fbx_to_mdl_converter.py input.fbx output.mdl --verbose
```

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License. See the source code header for details.

## 🔗 References

- [Autodesk FBX SDK Documentation](https://help.autodesk.com/view/FBX/2020/ENU/)
- [Counter-Strike MDL Format Specification](https://developer.valvesoftware.com/wiki/MDL)
- [Quake Model Format Documentation](https://www.gamers.org/dEngine/quake/spec/quake-spec34/qkspec_5.htm)

## 🏆 Credits

Created for the Counter-Strike 1.6 modding community. Special thanks to the developers who documented the MDL format and the FBX SDK team at Autodesk.

---

**Ready to convert your FBX models to CS 1.6 MDL format? Just run the converter and watch the magic happen! 🎮**