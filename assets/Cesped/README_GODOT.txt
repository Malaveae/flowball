Godot grass texture pack

Files:
- grass_albedo_1024.png: square grass base color, optimized for tiling in UI/pitch surfaces.
- grass_normal_1024.png: generated normal map for subtle grass relief.
- grass_roughness_1024.png: roughness map.
- grass_albedo_2048.png: higher resolution albedo option.

Godot 4 use:
1. Import PNG files into res://textures/grass/.
2. Create a StandardMaterial3D.
3. Set Albedo Texture = grass_albedo_1024.png.
4. Enable Normal Map = grass_normal_1024.png.
5. Set Roughness Texture = grass_roughness_1024.png or Roughness around 0.8.
6. In the texture import settings, enable Repeat.
7. On the mesh UV scale, use 6x6 to 12x12 for a football pitch.
