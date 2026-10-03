-- An entity that owns a RollbackBuffer and can be rolled back or rewound by the Match
---@class CanRollback : CanRollbackComponent
---@field saveForRollback fun(self: table, frame: integer?)
---@field rollbackRewindToFrame fun(self: table, frame: integer, isRewind: boolean): boolean?

-- A part of a CanRollback owner that saves its state into, and restores it from, a sub-table of the owner's rollback copy
---@class CanRollbackComponent
---@field saveIntoRollbackCopy fun(self: table, copy: table)
---@field restoreFromRollbackCopy fun(self: table, copy: table, frame: integer, isRewind: boolean)