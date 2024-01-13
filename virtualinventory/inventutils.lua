-- UTILS
local interfaceabstraction = require("interfaceabstraction")

local inventutils = {}

-- returns a number-indexed table of all
-- inventory peripherals' names connected to the
-- given wired modem.
-- blackList is table
function inventutils.GetModemPeripheralsOfType(modem, periphType, blackList)
    local periphNames = {}
    
    for _, name in ipairs(modem.getNamesRemote()) do
        if modem.hasTypeRemote(name, periphType) and (not blackList or not blackList[name]) then
            periphNames[#periphNames+1] = name
        end
    end
    
    return periphNames
end

function inventutils.CallRemoteMany(modem, periphs, methodName, ...)
    local varargs = {...}
    local returns = {}
    
    for _, name in ipairs(periphs) do
        returns[#returns+1] = modem.callRemote(name, methodName, unpack(varargs))
    end
    
    return returns
end


-- returns the amount actually transfered
function inventutils.TransferItemAmountFromInventoryToInventory(modem, periphAName, periphBName, itemName, amount)
    -- transfer amount of itemName from periphA to periphB
    local amountTransfered = 0
    local periphAItems = modem.callRemote(periphAName, "list")
    
    for slot, item in pairs(periphAItems) do
        if item.name == itemName then
            amountTransfered = amountTransfered + modem.callRemote(periphAName, "pushItems", periphBName, slot, math.min(item.count, amount - amountTransfered))
        end
        
        if amountTransfered >= amount then
            break
        end
    end
    
    return amountTransfered
end

-- because the above is not turtle safe
function inventutils.TransferItemAmountFromInterfaceToInventory(modem, interfaceName, inventoryName, itemName, amount)
    local amountTransfered = 0
    local interfaceItems = interfaceabstraction.ListItems(modem, interfaceName)
    
    for slot, item in pairs(interfaceItems) do
        if item.name == itemName or itemName == "*" then
            amountTransfered = amountTransfered + modem.callRemote(inventoryName, "pullItems", interfaceName, slot, math.min(item.count, amount - amountTransfered))
        end
        
        if amountTransfered >= amount then
            break
        end
    end
    
    return amountTransfered
end

function inventutils.GetItemCountOfInventory(modem, periphName, itemName)
    local count = 0

    if itemName == "*" then
        for k, v in pairs(modem.callRemote(periphName, "list")) do
            count = count + v.count
        end
    else
        for k, v in pairs(modem.callRemote(periphName, "list")) do
            if v.name == itemName then
                count = count + v.count
            end
        end
    end
    
    return count
end

-- returns new numerically indexed table with input tables' keys as values
function inventutils.GetSortedKeys(tab)
	local sorted = {}
	
	for k, v in pairs(tab) do
		sorted[#sorted+1] = k
	end
	
	table.sort(sorted, function(a, b) 
		return string.sub(a, 1, 1) < string.sub(b, 1, 1)
	end)
	
	return sorted
end

-- I think I copied this from stack overflow orignally, but I can't really remember anymore.
function inventutils.SplitStringWithTypeCoercion(str, separators)
    if separators == nil then
        separators = " "
    end
    
    local t = {}
    
    for subString in string.gmatch(str, "([^"..separators.."]+)") do
        table.insert(t, tonumber(subString) or subString)
    end
    
    return t
end

return inventutils