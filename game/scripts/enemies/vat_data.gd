class_name VatData
extends Resource
## Baked vertex animation for one enemy model: every animation frame's vertex
## positions and normals stored in textures, so crowds can be drawn with a
## single MultiMesh and animated in the vertex shader.

## Merged mesh; UV2.x holds each vertex's column in the textures.
@export var mesh: ArrayMesh
## RGBA half floats, width = vertex count, one row per frame.
@export var positions: Image
## RGBA8 normals (n * 0.5 + 0.5), same layout.
@export var normals: Image
## name -> Vector4(first_row, frame_count, fps, loop 1/0)
@export var anims: Dictionary = {}
## Height of the model's head (for stomps and hit effects).
@export var height := 2.0
