local inventutils = require("inventutils")
local interfaceabstraction = require("interfaceabstraction")
local pretty = require("cc.pretty")
local libinvent = {}

-- VIRTUAL INVENTORY
function libinvent.TabulateItems(inventData, inventories)
    local virtualInventory = {}
    
    virtualInventory.items = {}
    virtualInventory.peripherals = inventories
    virtualInventory.inventoryTotals = {}
    
    for peripheralIndex, inven in ipairs(inventData) do
        virtualInventory.inventoryTotals[peripheralIndex] = 0
        for _, item in pairs(inven) do
            if not virtualInventory.items[item.name] then
                virtualInventory.items[item.name] = {}
            end
        
            local itemTable = virtualInventory.items[item.name]
            
            -- peripheralIndex is peripheral in peripherals
            itemTable[peripheralIndex] = (itemTable[peripheralIndex] or 0) + item.count
            
            virtualInventory.inventoryTotals[peripheralIndex] = virtualInventory.inventoryTotals[peripheralIndex] + item.count
        end
    end
    
    return virtualInventory
end

function libinvent.CreateVirtualInventory(modem, interfacePeripheralName)
    local inventories = inventutils.GetModemPeripheralsOfType(modem, "inventory", {[interfacePeripheralName]=true})

    local returns = inventutils.CallRemoteMany(modem, inventories, "list")

    local virtualInventory = libinvent.TabulateItems(returns, inventories)
    virtualInventory.modem = modem
    virtualInventory.interfacePeripheralName = interfacePeripheralName
    
    return virtualInventory
end


-- pulls items from the virtual inventory into the output
-- returns the amount actually pulled
-- inventoryPeripheral is a wrapped inventory peripheral
function libinvent.PullItems(virtualInventory, itemName, amount)
    local interfaceName = virtualInventory.interfacePeripheralName
    
    local inventoryNames = virtualInventory.peripherals
    local inventoryTotals = virtualInventory.inventoryTotals
    
    local modem = virtualInventory.modem
    
    local vItems = virtualInventory.items
    local amountTransfered = 0
    
    if not vItems[itemName] then return amountTransfered end
    
    amount = (amount >= 0) and math.floor(amount) or 9999999
    
    libinvent.InvalidateInventoryCacheForItemName(virtualInventory.displayCache, itemName)
    
    for peripheralIndex, itemAmount in pairs(vItems[itemName]) do
        if itemAmount > 0 then
        
            local amountPulledFromPeripheral = inventutils.TransferItemAmountFromInventoryToInventory(modem, inventoryNames[peripheralIndex], interfaceName, itemName, amount - amountTransfered)
            
            inventoryTotals[peripheralIndex] = inventoryTotals[peripheralIndex] - amountPulledFromPeripheral
        
            vItems[itemName][peripheralIndex] = vItems[itemName][peripheralIndex] - amountPulledFromPeripheral
            if vItems[itemName][peripheralIndex] <= 0 then
                vItems[itemName][peripheralIndex] = nil
            end
            
            amountTransfered = amountTransfered + amountPulledFromPeripheral
            
            print(string.format("Amount pulled from peripheral %s is %i", inventoryNames[peripheralIndex], amountPulledFromPeripheral))
        end
        
        if amountTransfered >= amount then 
            break
        end
    end

    return amountTransfered
end

-- pushes items from the interface into the virtual inventory
function libinvent.PushItems(virtualInventory, itemName, amount)
    local interfaceName = virtualInventory.interfacePeripheralName
    
    local inventoryNames = virtualInventory.displayCache.sortedPeripherals
    local inventoryTotals = virtualInventory.inventoryTotals
    
    local modem = virtualInventory.modem
    
    local vItems = virtualInventory.items
    local amountTransfered = 0
    
    if itemName ~= "*" then
        libinvent.InvalidateInventoryCacheForItemName(virtualInventory.displayCache, itemName)
        
        if not vItems[itemName] then 
            vItems[itemName] = {} 
        end
    end
    
    amount = math.min((amount >= 0) and math.floor(amount) or 9999999, interfaceabstraction.GetItemCount(modem, interfaceName, itemName))
    
    for sortedIndex, sortedInventoryData in pairs(inventoryNames) do
        local peripheralIndex = sortedInventoryData.originalIndex
        local peripheralName = sortedInventoryData.name

        if itemName ~= "*" then -- regular case
            local amountPulledFromInterface = inventutils.TransferItemAmountFromInterfaceToInventory(modem, interfaceName, peripheralName, itemName, amount - amountTransfered)
            
            inventoryTotals[peripheralIndex] = inventoryTotals[peripheralIndex] + amountPulledFromInterface
            vItems[itemName][peripheralIndex] = (vItems[itemName][peripheralIndex] or 0) + amountPulledFromInterface
            amountTransfered = amountTransfered + amountPulledFromInterface
            
            print(string.format("Amount pulled from interface is %i", amountPulledFromInterface))
        else -- wildcard?
            local interfaceItems = interfaceabstraction.ListItems(modem, interfaceName)
            
            for slot, item in pairs(interfaceItems) do
                if not vItems[item.name] then 
                    vItems[item.name] = {} 
                end

                --local amountPulledFromInterface = inventutils.TransferItemAmountFromInterfaceToInventory(modem, interfaceName, peripheralName, item.name, math.min(item.count, amount - amountTransfered))
                local amountPulledFromInterface = modem.callRemote(peripheralName, "pullItems", interfaceName, slot, math.min(item.count, amount - amountTransfered))

                inventoryTotals[peripheralIndex] = inventoryTotals[peripheralIndex] + amountPulledFromInterface
                vItems[item.name][peripheralIndex] = (vItems[item.name][peripheralIndex] or 0) + amountPulledFromInterface
                amountTransfered = amountTransfered + amountPulledFromInterface
                
                libinvent.InvalidateInventoryCacheForItemName(virtualInventory.displayCache, item.name)
                
                print(string.format("Pushing item '%s' pulled from interface with an amount of %i", item.name, amountPulledFromInterface))
            
                if amountTransfered >= amount then 
                    break
                end
            end   
        end
        
        if amountTransfered >= amount then 
            break
        end
    end
    
    return amountTransfered
end

-- INVENTORY CACHE
function libinvent.CreateInventoryCache(virtualInventory)
    local inventoryCache = {}
    
    inventoryCache.sourceInventory = virtualInventory
    virtualInventory.displayCache = inventoryCache
    
    inventoryCache.items = {}
    
    for name, item in pairs(inventoryCache.sourceInventory.items) do
        libinvent.UpdateInventoryCache(inventoryCache, name)
    end
    
    -- sort source inventory peripherals by their fullness.
    libinvent.SortCacheInventories(inventoryCache)
    
    return inventoryCache
end

-- re-tally the count of the given block
function libinvent.UpdateInventoryCache(inventoryCache, itemName)
    if not inventoryCache.sourceInventory.items[itemName] then return end
    inventoryCache.items[itemName] = 0
    for _, count in pairs(inventoryCache.sourceInventory.items[itemName]) do
        inventoryCache.items[itemName] = inventoryCache.items[itemName] + count
    end
    
    -- clear index of sourceInventory is count is zero so we don't have 0 indices (sneaky)
    if inventoryCache.items[itemName] == 0 then
        inventoryCache.sourceInventory.items[itemName] = nil
        inventoryCache.items[itemName] = nil
    end
end

function libinvent.SortCacheInventories(inventoryCache)

    -- lazy init
    if not inventoryCache.sortedPeripherals then
        inventoryCache.sortedPeripherals = {}
        for i, name in pairs(inventoryCache.sourceInventory.peripherals) do
            inventoryCache.sortedPeripherals[i] = {["originalIndex"] = i, ["name"] = name}
        end
    end
    
    local sortedPeripherals = inventoryCache.sortedPeripherals
    local inventoryTotals = inventoryCache.sourceInventory.inventoryTotals
    
    table.sort(sortedPeripherals, function(a, b)
        return inventoryTotals[a.originalIndex] < inventoryTotals[b.originalIndex]
    end)
end

function libinvent.InvalidateInventoryCacheForItemName(inventoryCache, itemName)
    if not inventoryCache.invalidIndices then
        inventoryCache.invalidIndices = {}
    end
    
    inventoryCache.invalidIndices[itemName] = true
end

function libinvent.ValidateInventoryCache(inventoryCache)
    if not inventoryCache.invalidIndices then
        return
    end
    
    for name, _ in pairs(inventoryCache.invalidIndices) do
        libinvent.UpdateInventoryCache(inventoryCache, name)
    end
    
    libinvent.SortCacheInventories(inventoryCache)
    
    inventoryCache.invalidIndices = nil
end

function libinvent.PrintHelpText(helpSwitch)
	local sortedKeys = inventutils.GetSortedKeys(helpSwitch)

	for _, key in ipairs(sortedKeys) do
		print("\n"..helpSwitch[key])
		io.input(io.stdin)
		io.read("l")
	end
	
	print("Help end reached.")
end

-- Assumes a wired modem, will not work with wireless modems.

-- Example.
--[[
local interfacePeripheralName = "minecraft:chest_1"
local inventoryModem = peripheral.wrap("left")

local virtualInventory = libinvent.CreateVirtualInventory(inventoryModem, interfacePeripheralName)

local inventoryCache = libinvent.CreateInventoryCache(virtualInventory)
]]--

-- REPL and command loop
function libinvent.RunCommandLoop(inventoryModem, interfacePeripheralName, virtualInventory, inventoryCache, commandSwitch, helpSwitch)
    
    commandSwitch = commandSwitch or {
        -- pull items from the virtual inventory into the interface
        ["pull"] = function(args) -- pull <itemName> <amount>
            libinvent.PullItems(virtualInventory, args[2], args[3])
        end,       
        -- push items from the interface into the virtual inventory, has wildcard support
        ["push"] = function(args) -- push <itemName> <amount>
            libinvent.PushItems(virtualInventory, args[2], args[3])
        end,          
        ["print"] = function(args) -- print cache
            pretty.pretty_print(inventoryCache.items)
        end,        
        ["quit"] = function(args)
            os.queueEvent("terminate")
        end,
    }
    
    helpSwitch = helpSwitch or {}
    
    helpSwitch["help"] = helpSwitch["help"] or "help <commandName>\nShows help for a given command. If <commandName> is not given then it will print help for all commands."
    commandSwitch["help"] = commandSwitch["help"] or function(args)
        if not args[2] then
            libinvent.PrintHelpText(helpSwitch)
            return
        end
        
        print("")
        print(helpSwitch[args[2]] or string.format("Command '%s' not found.", tostring(args[2])))
    end

    -- command loop
    while true do

        io.input(io.stdin)
        local commandArgs = inventutils.SplitStringWithTypeCoercion(io.read("l"))

        local commandFunc = rawget(commandSwitch, commandArgs[1])
        
        if commandFunc then
            if commandFunc(commandArgs) then
                print("")
                print(helpSwitch[commandArgs[1]])
            end
        else
            if commandArgs[1] ~= nil then
                print(string.format("Error: no command '%s'.\nType 'help' for a list of commands.", commandArgs[1]))
            end
        end
        
        libinvent.ValidateInventoryCache(inventoryCache)

    end
end


return libinvent