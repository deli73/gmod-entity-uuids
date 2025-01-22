--[[
  UUIDs are stored in an entity's "UUID" key as an integer.
  (Also, persistent map entities store their source entity's ID as baseMapEnt)
  Allegedly the precision works up to a value of 1e+14 (100 trillion)Should be plenty of values lmao.
  We're just gonna go up to 1e+10 (10 billion)
  Map-created entities get priority access to the numbers less than 10000
  Players' UUID is just the negative of their AccountID; this isn't perfectly reliable but it's fine.

  If ents_by_uuid[id] is truthy, then the ID is used!
  Note: UUIDs of removed entities are only reserved until server restart. This should be fine i think.
]]--

uuid = {}

local ents_by_uuid = {} --key = uuid, val = entity reference. associative array basically.
initialized = false

function uuid.GetEntity(id)
  return ents_by_uuid[id]
end

local function load_with_id(ent)
  local id = ent.UUID
  if not id then --this should be impossible unless we fucked up lol
    error("[Entity UUIDs] Called load_with_id on entity without an ID set!")
  end
  ents_by_uuid[id] = ent
  hook.Run("LoadedUUID", ent)
end

local function give_new_id(ent)
  local seed = (SysTime() + ent:GetCreationID()*10)
  local id = nil
  repeat --try random numbers until we get a unique one
    id = math.floor( util.SharedRandom("entity_uuid_gen", 10000, 1e+10, seed) )
    seed = seed + SysTime() / 10
  until not ents_by_uuid[id]
  ent.UUID = id
  load_with_id(ent) --now that the ID has been given, register it in the list
end


hook.Add("OnEntityCreated", "entity uuid on creation", function(ent)
  --on creation of new entities and persist-loaded ones, load ID or give new one.
  --...we gotta wait for the entity to finish being initialized before we do this.
  timer.Simple(0, function()
    if not IsValid(ent) or ent:IsPlayer() then return end
    if ent.UUID and ents_by_uuid[ent.UUID] then return end
    if ent.UUID then
      load_with_id(ent)
    else --entity needs new UUID
      give_new_id(ent)
    end
  end)
end)

-- override persist load to force UUID data to be read
-- this is a big hack lmao
hook.Add("PostGamemodeLoaded", "entity uuid persist load override", function()
  hook.Add("PersistenceLoad", "PersistenceLoad", function(name)
    local data = file.Read("persist/" .. game.GetMap() .. "_" .. name .. ".txt")
    if not data then return end

    local tab = util.JSONToTable(data)
    if not tab then return end
    if not tab.Entities then return end
    if not tab.Constraints then return end

    local entities = duplicator.Paste(nil, tab.Entities, tab.Constraints)

    MsgN("[Entity UUIDs] Loading persistent UUIDs...")
    local count = 0
    for k,ent in pairs(entities) do
      ent:SetPersistent(true)
      hook.Run("LoadCustomPersistData", ent, tab.Entities[k])
      local data = tab.Entities[k]
      if data then
        if data.UUID then
          ent.UUID = data.UUID
          count = count + 1
        end
        if data.baseMapEnt then
          ent.baseMapEnt = data.baseMapEnt
        end
      end
    end
    MsgN("[Entity UUIDs] " .. count .. " persistent IDs loaded." )
  end)
end)

-- hook.Add("LoadCustomPersistData", "entity uuids custom persist data", function(ent, data)

-- end)

hook.Add("PersistenceSave", "entity uuids on save map id fix", function(name)
  for _, ent in ents.Iterator() do
    if ent:CreatedByMap() and ent:GetPersistent() then
      ent.baseMapEnt = ent:MapCreationID()
      ents_by_uuid[ent.UUID] = nil
      give_new_id(ent)
    end
  end
end)

gameevent.Listen("player_connect")
hook.Add("player_connect", "entity uuid set for player", function(data)
  timer.Simple(0, function()
    local ply = Player(data.userid)
    if not IsValid(ply) then return end
    if data.bot then --bots get a random ID, since they're created fresh every time
      give_new_id(ply)
    else --players use the negative of their account ID as a UUID instead
      ply.UUID = -ply:AccountID()
      load_with_id(ply)
    end
  end)
end)

local function InitUUIDs()
  MsgN("[Entity UUIDs] Initializing...")
  local to_remove = {}

  for _, ent in ents.Iterator() do
    if ent:IsPlayer() then --can players even be here?
      ent.UUID = -ent:AccountID() --this should work, i think
    end

    if ent:CreatedByMap() then --map created entity, give it the map creation id as a UUID
      ent.UUID = ent:MapCreationID()
    else
      if ent.UUID and ent.baseMapEnt then --REMOVE MATCHING MAP ENTITIES? TEMP/HACK/DEBUG
        table.insert(to_remove, ent.baseMapEnt)
      end
    end
    
    if ent.UUID then --entity has UUID already, register it
      load_with_id(ent)
    end
  end

  for i,v in ipairs(to_remove) do
    local ent = ents.GetMapCreatedEntity(v)
    if ent then ent:Remove() end
  end
  initialized = true
end

hook.Add("InitPostEntity", "entity uuid on map load", InitUUIDs)