# AnimationLoader JSON Properties Documentation

## Root Level Properties

### `drawables`
An array containing drawable objects that will be rendered. This is the main container for all visual elements in the scene.

## Node Properties

### Basic Properties

#### `id`
A unique identifier for the node. Used for referencing this node from other nodes.

#### `filePath`
Path to an image file relative to the root path. When specified, loads a texture for this node and automatically sets width/height from the image dimensions.

#### `ref`
Reference to another node by ID or to another JSON file. When referencing a file, use the `.json` extension. Allows reusing existing nodes or importing from external files.

#### `overrides`
Table of property overrides to apply when using a `ref`. Allows customizing referenced nodes without modifying the original.

### Position and Size

#### `position`
Object containing `x` and `y` coordinates for the node's position.
- `x`: Horizontal position (default: 0)
- `y`: Vertical position (default: 0)

#### `size`
Object containing dimensions for the node.
- `width`: Width of the node (default: 0, or image width if `filePath` is used)
- `height`: Height of the node (default: 0, or image height if `filePath` is used)

### Transform Properties

#### `rotation`
Rotation angle in radians (default: 0).

#### `scale`
- `xScale`: how much to scale the image and children in x direction
- `yScale`: how much to scale the image and children in y direction

#### `anchor`
Determines which point of the node is positioned at the x,y coordinates. Options:
- `"topLeft"` (default)
- `"topCenter"`
- `"topRight"`
- `"centerLeft"`
- `"center"`
- `"centerRight"`
- `"bottomLeft"`
- `"bottomCenter"`
- `"bottomRight"`

#### `pivot`
Determines the point around which rotation and scaling occur. Same options as `anchor` (default: `"center"`).

### Visual Properties

#### `alpha`
Transparency level from 0 (fully transparent) to 1 (fully opaque) (default: 1).

#### `tint`
RGB color tint applied to the node as an array of three values [r, g, b] where each component ranges from 0 to 1 (default: [1, 1, 1] for white/no tint).

#### `blendMode`
How this node blends with what's behind it (default: `"alpha"`). Uses Love2D blend modes.

#### `alphaMode`
How alpha blending is calculated (default: `"alphamultiply"`). Uses Love2D alpha modes.

#### `stencil`
Boolean indicating whether this node should be used as a stencil mask for clipping other nodes (default: false).

### Texture Properties

#### `wrap`
When set to `"repeat"`, enables texture wrapping and adds scrolling capabilities. Sets up the texture to repeat and enables `scrollX`/`scrollY` properties.

#### `scrollX`
Horizontal scroll offset for repeating textures (only available when `wrap` is `"repeat"`).

#### `scrollY`
Vertical scroll offset for repeating textures (only available when `wrap` is `"repeat"`).

### Animation Properties

#### `animationTracks`
Array of animation track objects that define how the node's properties change over time. Each track contains:

##### Track Properties:
- `steps`: Array of animation steps
- `loopTrack`: Boolean indicating whether the animation should loop
- `yoyo`: Boolean indicating whether the animation should reverse direction when reaching the end

##### Step Properties (within each step in `steps`):
- `durationSeconds`: How long this step takes to complete
- `delaySeconds`: Delay before starting this step (optional)
- `easeType`: Easing function to use for the animation
- `animateProperties`: Object containing the target values for properties to animate to

### Hierarchy

#### `children`
Array of child nodes that will be rendered relative to this node's transform. Child nodes inherit the parent's transformations.

## Notes

- Nodes with non-`"topLeft"` anchor or pivot must have width and height greater than 0
- When using `stencil`, the node must have a parent with siblings
- File references in `ref` properties are resolved relative to the current file's directory
- All position, size, and transform properties can be animated using `animationTracks`