--[[
  UUIDs are stored in an entity's "UUID" key as an integer.
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

hook.Add("LoadCustomPersistData", "entity uuids custom persist data", function(ent, data)
  if data then
    if data.UUID then
      ent.UUID = data.UUID
    end
  end
end)

hook.Add("PersistenceSave", "entity uuids on save map id fix", function(name)
  for _, ent in ents.Iterator() do
    if ent:CreatedByMap() and ent:GetPersistent() then
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
    end
    
    if ent.UUID then --entity has UUID already, register it
      load_with_id(ent)
    end
  end
  initialized = true
end

hook.Add("InitPostEntity", "entity uuid on map load", InitUUIDs)