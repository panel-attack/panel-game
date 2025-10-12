# Animation Loader JSON Documentation

## Root Level Properties

### `drawables`
An array containing drawable objects that will be rendered. This is the main container for all visual elements in the scene.

## Drawable Properties

### Basic Properties

#### `id`
A unique identifier for the drawable. Used for referencing this drawable from other drawables.

#### `filePath`
Path to an image file relative to the root path. When specified, loads a texture for this drawable that will be drawn.

#### `ref`
Reference to another drawable by ID or to another JSON file. To reference an ID in this file, just use the ID. To reference an ID in another file use "file.json#id". If you want to import a whole file, you can just use "file.json". This allows reusing existing drawables or importing from external files. File references are resolved relative to the current file's directory

#### `overrides`
Table of property overrides to apply when using a `ref`. Allows customizing referenced drawables without modifying the original. This will directly apply the properties recursively, so you can apply deep overrides if you use the same structure. Note you cannot apply overrides to a whole file import.

### Position and Size

#### `position`
Object containing `x` and `y` coordinates for the drawable's position.
- `x`: Horizontal position (default: 0)
- `y`: Vertical position (default: 0)

#### `size`
Object containing dimensions for the drawable. Use this to automaticaly change the xScale or yScale to be appropriate to match the given width or height
- `width`: Width the drawable should be drawn
- `height`: Height the drawable should be drawn

### Transform Properties

#### `rotation`
Rotation angle in radians (default: 0).

#### `scale`
- `xScale`: how much to scale the image and children in x direction, you can't specify this and width
- `yScale`: how much to scale the image and children in y direction, you can't specify this and height

#### `anchor`
Determines which point of the drawable is positioned at the x,y coordinates. Options:
- `"topLeft"` (default)
- `"topCenter"`
- `"topRight"`
- `"centerLeft"`
- `"center"`
- `"centerRight"`
- `"bottomLeft"`
- `"bottomCenter"`
- `"bottomRight"`

Drawables with non-`"topLeft"` anchor must have width and height greater than 0 set or a texture

#### `pivot`
Determines the point around which rotation and scaling occur. Same options as `anchor` (default: `"center"`).

Drawables with non-`"topLeft"` pivot must have width and height greater than 0 set or a texture

### Visual Properties

#### `alpha`
Transparency level from 0 (fully transparent) to 1 (fully opaque) (default: 1).

#### `tint`
RGB color tint applied to the drawable as an array of three values [r, g, b] where each component ranges from 0 to 1 (default: [1, 1, 1] for white/no tint).

#### `blendMode`
How this drawable blends with what's behind it (default: `"alpha"`). Uses Love2D blend modes.

#### `alphaMode`
How alpha blending is calculated (default: `"alphamultiply"`). Uses Love2D alpha modes.

#### `stencil`
Boolean indicating whether this drawable should only draw in the spots all its previous siblings draw. I.E. the siblings before this drawable will mask it. (default: false).

### Texture Properties

#### `wrap`
When set to `"repeat"`, enables texture wrapping and adds scrolling capabilities. Sets up the texture to repeat and enables `scrollX`/`scrollY` properties.

#### `scrollX`
Horizontal scroll offset for repeating textures (only available when `wrap` is `"repeat"`).

#### `scrollY`
Vertical scroll offset for repeating textures (only available when `wrap` is `"repeat"`).

### Animation Properties

#### `animationTracks`
Array of animation track objects that define how the drawable's properties change over time. Each track contains:

##### Track Properties:
- `steps`: Array of animation steps
- `loopTrack`: Boolean indicating whether the animation should loop
- `yoyo`: Boolean indicating whether the animation should reverse direction when reaching the end and repeat. Note that you only can do yoyo or loop, not both.

##### Step Properties (within each step in `steps`):
- `durationSeconds`: How long this step takes to complete
- `delaySeconds`: Delay before starting this step (optional)
- `easeType`: Easing function to use for the animation
  - `linear` – Constant speed.
  - `quadin` / `quadout` / `quadinout` – Ease using t² (slow > fast, fast > slow, or both).
  - `cubicin` / `cubicout` / `cubicinout` – Steeper cubic curve (t³).
  - `quartin` / `quartout` / `quartinout` – Even steeper quartic curve (t⁴).
  - `quintin` / `quintout` / `quintinout` – Sharpest power curve (t⁵).
  - `sinein` / `sineout` / `sineinout` – Smooth wave-like motion.
  - `expoin` / `expoout` / `expoinout` – Exponential acceleration/deceleration.
  - `circin` / `circout` / `circinout` – Circular motion effect.
  - `backin` / `backout` / `backinout` – Overshoots slightly before settling.
  - `bouncein` / `bounceout` / `bounceinout` – Bounce effect on entry/exit.
  - `elasticin` / `elasticout` / `elasticinout` – Springy, elastic motion.
- `animateProperties`: Object containing the target values for properties to animate to

### Hierarchy

#### `children`
Array of child drawables that will be rendered relative to this drawable's transform. Child drawables inherit the parent's transformations.
