# Primitive2D

A Godot 4.7 addon for drawing custom 2D vector shapes from a list of vertices, with an optional keyframe system for morphing a shape's vertices and colors over time. Includes an editor plugin that lets you drag, insert, and delete vertices directly in the 2D viewport instead of editing raw arrays in the Inspector.

## Nodes

### `Primitive2D` (extends `Control`)

Draws a single static filled polygon with an optional outline.

| Property | Type | Description |
| --- | --- | --- |
| `vertices` | `PackedVector2Array` | Polygon vertices, in the control's local coordinate space. |
| `fill_color` | `Color` | Fill color (only drawn when there are 3+ vertices). |
| `draw_outline` | `bool` | Whether to draw the closed outline. |
| `outline_color` | `Color` | Outline color. |
| `outline_width` | `float` | Outline width, in pixels. |

### `AnimatedPrimitive2D` (extends `Primitive2D`)

Morphs between a list of keyframed poses over time. Each keyframe is a `PrimitiveKeyframe` resource capturing a full pose (vertices + colors) at a specific time; playback interpolates between the two keyframes surrounding the current time.

| Property | Type | Description |
| --- | --- | --- |
| `keyframes` | `Array[PrimitiveKeyframe]` | The animation's keyframes. Order in the array doesn't need to match chronological order — playback always sorts by `time`. |
| `timeline_length` | `float` | Total loop duration. Auto-grows to fit the furthest keyframe (never shrinks below it). If longer than the last keyframe's time, the shape holds that keyframe's pose for the remainder before looping. |
| `autoplay` | `bool` | Start playing automatically on `_ready()`. |
| `loop` | `bool` | Loop back to the start after `timeline_length`, instead of stopping. |

Methods: `play()`, `stop()`, `seek(time: float)`.

All keyframes must have the same vertex count for a segment to morph smoothly (vertex `i` moves to vertex `i`). A mismatched pair shows a configuration warning on the node and just snaps between poses instead of interpolating.

### `PrimitiveKeyframe` (extends `Resource`)

One keyframed pose.

| Property | Type | Description |
| --- | --- | --- |
| `time` | `float` | Timestamp, in seconds. |
| `vertices` | `PackedVector2Array` | This keyframe's vertex positions. |
| `fill_color` | `Color` | This keyframe's fill color. |
| `outline_color` | `Color` | This keyframe's outline color. |
| `outline_width` | `float` | This keyframe's outline width. |
| `tween_type` | `Tween.TransitionType` | Transition curve used for the segment *starting* at this keyframe (i.e. how it eases into the next one). |
| `ease_type` | `Tween.EaseType` | Ease direction for that same segment. |

## Editing in the 2D viewport

Selecting a `Primitive2D` or `AnimatedPrimitive2D` node shows yellow vertex handles in the 2D editor viewport:

- **Left-click + drag** a handle to move a vertex.
- **Double-click an edge** to insert a new vertex there.
- **Right-click a vertex** to delete it.

All of the above are undo/redo-aware (Ctrl+Z works as expected).

### Keyframe toolbar (`AnimatedPrimitive2D` only)

Selecting an `AnimatedPrimitive2D` additionally shows a toolbar above the 2D viewport:

- **Keyframe** spinbox — which keyframe the vertex handles are currently editing.
- **Time (s)** field — precise timestamp for the selected keyframe.
- **+ Add / − Delete** — add a keyframe (defaults to halfway between the selected keyframe and its next neighbor, or +1s if it's the last one) or delete the selected one.
- **Length (s)** field — sets `timeline_length` directly.
- **Snap 0.1s** checkbox — rounds every time value (dragging, typed values, add defaults) to the nearest tenth of a second.
- **Tween / Ease** dropdowns — set the selected keyframe's transition/ease type. Populated directly from the engine's `Tween.TransitionType`/`Tween.EaseType` enums, so it can't drift out of sync with what Godot actually supports.
- **Timeline strip** — every keyframe shown as a draggable marker positioned along the timeline; a separate cyan handle at the end controls `timeline_length` independently of any keyframe. Scroll the mouse wheel over the strip to zoom in/out, centered on the cursor.

## Requirements

Godot **4.7+**. The animation system relies on `Tween.interpolate_value()` (a static method for manual easing without a live `Tween` node) and `ClassDB.class_get_enum_constants()` (to populate the Tween/Ease dropdowns from the engine's own enums).

## File structure

```
addons/primitive_2d/
  plugin.cfg                  — plugin manifest
  plugin.gd                   — EditorPlugin: vertex handles + keyframe toolbar
  primitive_2d.gd             — Primitive2D node
  animated_primitive_2d.gd    — AnimatedPrimitive2D node
  primitive_keyframe.gd       — PrimitiveKeyframe resource
  keyframe_timeline.gd        — draggable timeline strip widget used by the toolbar
  icon_primitive2d.svg
  icon_animated_primitive2d.svg
  demo.tscn                   — example scene using both node types
```

## Enabling

Copy the `primitive_2d` folder into your project's `addons/` directory, then enable it under **Project Settings → Plugins** (or add it directly to `project.godot`):

```ini
[editor_plugins]

enabled=PackedStringArray("res://addons/primitive_2d/plugin.cfg")
```
