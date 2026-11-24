require("client.src.server_queue")

local queue = ServerQueue()

assert(queue:size() == 0)

-- queue:push(1)
-- assert(queue:size() == 1)
-- assert(queue:top() == 1)
-- assert(queue:size() == 1)
-- assert(queue:pop() == 1)
-- assert(queue:size() == 0)


local table1 = {test="a"}
local table2 = {bob="a"}
local table3 = {alice="a"}
queue:push(table1)
queue:push(table2)
queue:push(table3)

local visited = {}
for index, message in queue:getMessageIterator() do
  visited[#visited + 1] = message
  if message == table2 then
    queue:remove(index)
  end
end
assert(visited[1] == table1 and visited[2] == table2 and visited[3] == table3, "messages should visit every message oldest first")
assert(queue:top() == table1)
assert(queue:size() == 2)

assert(queue:pop_next_with("alice") == table3)
assert(queue:size() == 1)
assert(queue:pop_next_with("test") == table1)
assert(queue:size() == 0)

-- a message left at the head while the ones behind it are taken out, as a state keeps a lobby message through a match
local kept = {lobbyStateV2 = {}}
queue:push(kept)
for _ = 1, 3 do
  queue:push({O = "A"})
end
for index, message in queue:getMessageIterator() do
  if message ~= kept then
    queue:remove(index)
  end
end
for _ in queue:getMessageIterator() do
end
assert(queue.last - queue.first + 1 == queue:size(),
       "a walk should close the holes taken messages left, but the queue spans " .. (queue.last - queue.first + 1) .. " for " .. queue:size())
assert(queue:top() == kept)
