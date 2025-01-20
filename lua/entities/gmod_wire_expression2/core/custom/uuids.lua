E2Lib.RegisterExtension("uuid", true, "Get entities by a unique ID.")

__e2setcost(1)
e2function number entity:uuid()
  if not IsValid(this) then return self:throw("Invalid entity!", 0) end
  if not ent.UUID then return self:throw("Missing UUID!", 0) end
  return this.UUID
end

__e2setcost(3)
e2function entity byUUID(number id)
  local ent uuid.GetEntity(id)
  return IsValid(ent) and ent or nil
end

E2Helper.Descriptions["uuid(e:)"] = "Gets an entity's persistent unique ID"
E2Helper.Descriptions["byUUID(n)"] = "Gets the entity associated with the unique ID"