E2Lib.RegisterExtension("uuid", true, "Get entities by a unique ID.")

E2Lib.registerEvent("uuidSet", {{"Entity", "e"}})
hook.Add("LoadedUUID", "persistent owner bot wire event", function(ent)
  E2Lib.triggerEvent("uuidSet", ent)
end)

__e2setcost(5)
e2function number entity:uuid()
  if not IsValid(this) then return self:throw("Invalid entity!", 0) end
  if not this.UUID then return self:throw("Missing UUID!", 0) end
  return this.UUID
end

__e2setcost(5)
e2function entity byUUID(number id)
  local ent uuid.GetEntity(id)
  return IsValid(ent) and ent or nil
end