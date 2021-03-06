local Position = require 'stdlib/area/position'
local Entity = require 'stdlib/entity/entity'
local Area = require 'stdlib/area/area'
require 'stdlib/event/event'
require 'stdlib/table'
local table_filter = table.filter

-- should be fine desync-wise as it's loading a local file
aliengoopcracking = {}
require 'config'

local function distanceToOrigin(pos)
  return Position.distance(pos, Position.construct(0,0))
end

local function calculateAmount(pos)
  -- Magic number: size of a chunk, in tiles (x,y)
  local center = (distanceToOrigin(pos) * aliengoopcracking.increasePerChunk) / 32
  local amount = center + aliengoopcracking.goopVariance * (math.random() - 0.5)
  return math.floor(math.max(aliengoopcracking.minimumGoop, amount * aliengoopcracking.baselineGoop))
end

local function filterFluids(entity)
  return entity.prototype.resource_category == 'basic-fluid'
end

local function filterGoopWells(entity)
  return entity.name == 'alien-goop-cracking-goop' or entity.name == 'alien-goop-cracking-super-goop'
end

local function replaceWell(old, new)
  new.position = old.position
  old.surface.create_entity(new)
  old.destroy()
end

local function enrichWell(well, amount)
  if well.name == 'alien-goop-cracking-goop' then
    -- make it super charged
    replaceWell(well, {
      name = 'alien-goop-cracking-super-goop',
      amount = well.amount + amount
    })
  else
    -- just add the extra amount
    well.amount = well.amount + amount
  end
end

local function getCompetitors(surface, area)
  return table_filter(surface.find_entities_filtered{area = area, type = "resource"}, filterFluids)
end

local function createGoopWell(surface, area)
  local position = Area.center(area)
  local amount = calculateAmount(position)

  local competitors = getCompetitors(surface, area)

  if not competitors or #competitors <= 0 then
    -- spawn well, as usual
    local type = 'alien-goop-cracking-goop'
    if math.random() < aliengoopcracking.superChance then type = 'alien-goop-cracking-super-goop' end
    surface.create_entity {name = type, position = position, amount = amount}
  else
    -- can't spawn well, filter extra goop wells
    local siblings = table_filter(competitors, filterGoopWells)
    if (#siblings <= 0) then return end
    -- if there's any siblings, enrich them
    local subamount = math.floor(amount / #siblings)
    for _,well in pairs(siblings) do
      enrichWell(well, subamount)
    end
  end
end

local function shouldSpawn(event)
  return event.entity.type == 'unit-spawner'
end

Event.register(defines.events.on_entity_died, function(event)
  if shouldSpawn(event) then
    local surface = event.entity.surface
    local area = Entity.to_collision_area(event.entity)

    if math.random() < aliengoopcracking.goopChance then
      createGoopWell(surface, area)
    else
      local competitors = getCompetitors(surface, area)
      for _,well in pairs(competitors) do
        if math.random() < aliengoopcracking.boostChance then enrichWell(well, 0) end
      end
    end
  end
end)