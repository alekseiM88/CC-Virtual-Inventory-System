-- virtual inventory autocomplete module
local interfaceabstraction = require("interfaceabstraction")

local autocomplete = {}

-- returns string, attempts to roughly complete the given name
function autocomplete.ItemNameFromCache(itemName, inventoryCache)
    local itemName = itemName or ""

    if itemName == "*" or inventoryCache.items[itemName] then return itemName end
    
    local storedItems = inventoryCache.items
    
    local nameMatches = {}
    
    for name, amount in pairs(storedItems) do
        if string.find(name, itemName, 1, true) then
            nameMatches[#nameMatches+1] = name
        end
    end
    
    if #nameMatches > 0 then
        table.sort(nameMatches, function(a, b) return string.len(a) < string.len(b) end)
        return unpack(nameMatches)
    end
    
    return nil
end

function autocomplete.ItemNameFromInterface(itemName, modem, interfaceName)
    local itemName = itemName or ""

    if itemName == "*" or string.find(itemName, ":", 1, true) then return itemName end
    
    local interfaceItems = interfaceabstraction.ListItems(modem, interfaceName)
    
    for _, item in pairs(interfaceItems) do
        if string.find(item.name, itemName, 1, true) then
            return item.name
        end
    end
    
    return nil
end

return autocomplete