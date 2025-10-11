-- Focusable Mixin
--
-- Marks any object as capable of receiving keyboard/controller focus.
-- Use in tandem with FocusDirector.lua
--
-- The focus system works as follows:
-- 1. Apply Focusable(object) to mark an object as focusable
-- 2. FocusDirector manages which object currently has focus
-- 3. When FocusDirector.setFocus(object) is called, it dynamically assigns:
--    - object.hasFocus = true
--    - object.yieldFocus = function() to release focus
-- 4. Only the currently focused object will receive input via receiveInputs()
--
-- IMPORTANT: yieldFocus() is NOT provided by this mixin!
-- It is dynamically assigned by FocusDirector when the object gains focus.

local function focusable(object)
  object.isFocusable = true
  object.hasFocus = false

  -- Ensure the object implements input handling
  if object.receiveInputs == nil then
    object.receiveInputs = function(inputs)
      error("Focusable object of type " .. object.TYPE .. " doesn't implement input interpretation")
    end
  end

  -- NOTE: yieldFocus is NOT implemented here!
  -- It is dynamically assigned by FocusDirector when focus is granted:
  -- object.yieldFocus = function()
  --   object.hasFocus = false
  --   director.focused = nil
  --   if callback then callback() end
  -- end
end

return focusable