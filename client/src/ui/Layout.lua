-- Builds the tables LayoutRules are made of, as Clay's CLAY_SIZING_* and CLAY_PADDING_ALL macros do.
-- Each call returns a new table, so rules are built once and kept; the constants below are shared and never changed.
local Layout = {}

---@type LayoutSizing
Layout.FIT = {type = "fit"}
---@type LayoutSizing
Layout.GROW = {type = "grow"}
---@type LayoutChildAlignment
Layout.CENTER = {x = "center", y = "center"}
---@type LayoutChildAlignment
Layout.CENTER_HORIZONTALLY = {x = "center"}
---@type LayoutChildAlignment
Layout.CENTER_VERTICALLY = {y = "center"}
-- the floating rule of an element left out of its parent's flow, taking no room there, usually while it is hidden
---@type LayoutFloating
Layout.OUT_OF_FLOW = {attachTo = "parent"}

---@param size number
---@return LayoutSizing
function Layout.fixed(size)
  return {type = "fixed", min = size, max = size}
end

---@param min number?
---@param max number?
---@return LayoutSizing
function Layout.fit(min, max)
  return {type = "fit", min = min, max = max}
end

---@param min number?
---@param max number?
---@return LayoutSizing
function Layout.grow(min, max)
  return {type = "grow", min = min, max = max}
end

-- The floating rule pinning a point of the element to the same point of its parent, moved by the offset
---@param point LayoutAttachPoint
---@param x number?
---@param y number?
---@return LayoutFloating
function Layout.floatAt(point, x, y)
  return {attachTo = "parent", attachPoints = {element = point, parent = point}, offset = {x = x or 0, y = y or 0}}
end

---@param width number
---@param height number
---@return LayoutSizingAxes
function Layout.fixedSize(width, height)
  return {horizontal = Layout.fixed(width), vertical = Layout.fixed(height)}
end

---@param all number the padding on every side
---@return LayoutPadding
function Layout.padding(all)
  return {left = all, right = all, top = all, bottom = all}
end

-- Returns the size the rules fix along the axis, nil if that axis isn't fixed
---@param rules LayoutRules
---@param axis "horizontal"|"vertical"
---@return number?
function Layout.fixedLength(rules, axis)
  local sizing = rules.sizing and rules.sizing[axis]
  if sizing and sizing.type == "fixed" then
    return sizing.min
  end
end

return Layout
