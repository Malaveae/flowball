# Preparation texture provenance

Created with the built-in image-generation tool on 2026-09-30. These are albedo assets used on real Blender meshes and in Godot materials. No full-screen concept image is used in the running scene.

## turf_albedo.png

Generation ID: `exec-9177cf2e-7580-4bed-83cd-81b38d6fbc1a`.

> Create a production video-game texture asset, square 1024x1024: seamless tileable stylized football pitch grass ALBEDO, directly orthographic straight down. Dense small interwoven narrow grass blades, lush saturated fresh lime and olive green with deep green crevices, premium colorful 3D cel-shaded TV arcade football aesthetic. Fairly fine blades across entire image, uniform consistent density and color; no large patches. Soft painted shading on individual blades but no global lighting gradient, no cast shadows, no perspective, no horizon, no objects, no white pitch lines, no text, no border. All four edges must tile seamlessly. This will be UV repeated on actual football pitch geometry, not used as a scene background.

## crowd_albedo.png

Original generation ID: `exec-53975017-bfed-4dc5-b77d-c502bed4be60`.

> Production game texture: a rectangular wide horizontal seamless football stadium crowd terrace albedo tile, aspect ratio 3:2 or wide landscape. Orthographic straight-on frontal view, frame filled edge to edge with 8 compact rows of seated and standing football supporters with heads and torsos visible. Hundreds of small individually varied stylized 3D cel-shaded people, toy animation quality, readable simplified faces, dark blue stadium seats, jerseys predominantly cobalt and navy with scattered emerald green orange purple ivory yellow. Varied poses with some raised arms; avoid rigid identical grid poses. Deep dark navy ambient shadows, rich restrained blue palette with colorful jerseys. NO architecture, NO roof, NO stairs, NO railings, NO banners, NO foreground, NO football pitch, NO sky, NO lettering or UI. Rows have same scale top and bottom, no perspective. Crowd fills full image right to all edges with no margins. A texture for distant inclined 3D spectator terrace surfaces, horizontally repeatable, not an illustration of a whole stadium.

User requested less detail/blur. The **final texture** is this image edit, generation ID `exec-fa37639b-7c49-4d52-a99b-979b6485ec9d`:

> Edit this crowd texture for a background videogame stadium. Greatly REDUCE detail. Replace the individually detailed people with much smaller, simple cel-shaded audience silhouettes: little round heads, broad shoulders, jersey color blocks, occasional raised arms, no eyes noses mouths fingers fabric or logos. About twice as many figures across and more rows so crowd reads as a dense collective colorful atmosphere. Apply soft optical blur to the entire texture to merge tiny features, while preserving clear broad blue orange green purple yellow color patches and dark navy gaps. Predominantly dark blue. Keep full frame crowd edge to edge, straight-on orthographic layout, seamless horizontal tiling, no architecture no text no border. The result should be visibly simplified and softly unfocused, a background texture which does not compete with the gameplay ball.

## ball_albedo.png

Generation ID: `exec-e43cdb7e-3b42-49bd-9294-602c842d5768`.

> Game asset texture, 2:1 wide equirectangular UV albedo map for a spherical football, entire canvas is the UV texture itself edge to edge. Cream white synthetic leather base, sweeping connected modern football panel graphics in electric blue, orange-red, emerald green with a small amount of dark navy. Contemporary expressive angular curved ribbons, most surface white. Delicate dark thin curved seam lines subdividing irregular panels, tiny uniform leather pores. Flat uniform albedo lighting. Horizontal left and right edges join seamlessly. NO spherical ball picture, NO previews, NO UV wireframe, NO labels, NO text, NO numbers, NO logos, NO black background, NO exploded panels, NO shadows, NO border. A rectangular pattern wrapped directly onto a UV sphere in Blender. Colorful premium cel shaded TV arcade sports game.

## Integration

`tools/blender/build_preparation.py` packs the selected PNGs into the `.blend` sources and exports GLB textures. Godot generates turf mipmaps explicitly, applies crowd tint, retains the ball albedo and adds runtime lighting. UV pole compression on the ball and horizontal crowd repetition remain normal texture-art review points.
