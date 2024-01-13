
-- load all needed modules
local pretty = require("cc.pretty")
local libinvent = require("libinvent")
local autocomplete = require("autocomplete")
local serial = require("serialization")

function ProcessPushPullArguments(args, possibleAutocomplete)
    if type(args[2]) == "string" then
        return possibleAutocomplete, args[3] or 1
    else
        return possibleAutocomplete, args[2] or 1
    end
end

-- MAIN SETUP
-- Assumes a wired modem, will not work with wireless modems.

local configFilePath = shell.resolve("/virtinv.cfg")

local configData = serial.LoadConfig(configFilePath)

local interfacePeripheralName = configData.interface
local inventoryModem = peripheral.wrap(configData.modemside) or peripheral.find("modem")

local virtualInventory = libinvent.CreateVirtualInventory(inventoryModem, interfacePeripheralName)
local inventoryCache = libinvent.CreateInventoryCache(virtualInventory)

local helpSwitch = {
    ["pull"] = "pull [<itemName>] <amount>\nitemName can be '*' for wildcard or absent to use last given itemName.\nAmount can be -1 for all.",
    ["push"] = "push [<itemName>] <amount>\nitemName can be absent to use last given itemName.\nAmount can be -1 for all.",
    ["print"] = "print [<subString>]\nIf subString is absent then last given item name is used, unless it is invalid.",
    ["quit"] = "quit\nExit the program.",
    ["cfgsave"] = "cfgsave\nSave the config data",
    ["cfgset"] = "cfgset <key> <value>\nSet a key-value pair of the config table, remember to use 'cfgsave' to save your changes.",
    ["cfgget"] = "cfgget <key>\nShows the value for the given key in the config table.",
    ["cfgprint"] = "cfgprint\nPrints all keys and values of the config table.",
}

-- a better command switch
-- if amount is less than zero then it tries to push all of that item
local lastItemName = nil
local commandSwitch = {
    -- pull items from the virtual inventory into the interface
    ["pull"] = function(args) -- pull <itemName> <amount>
        if not args[2] and not lastItemName then return true end
    
        local inputName = type(args[2]) == "string" and args[2] or lastItemName
    
        local itemName, amount = ProcessPushPullArguments(args, autocomplete.ItemNameFromCache(inputName, inventoryCache)) 
        lastItemName = itemName or lastItemName
        
        if not itemName then print("Invalid sub string.") return true end
        
        print("Attempting to pull item: "..itemName)
        libinvent.PullItems(virtualInventory, itemName, amount)
    end,       
    -- push items from the interface into the virtual inventory, has wildcard support
    ["push"] = function(args) -- push <itemName> <amount>
        if not args[2] and not lastItemName then return true end
        
        local inputName = type(args[2]) == "string" and args[2] or lastItemName
        
        local itemName, amount = ProcessPushPullArguments(args, autocomplete.ItemNameFromInterface(inputName, inventoryModem, interfacePeripheralName))
        lastItemName = itemName or lastItemName
        
        if not itemName then print("Invalid sub string.") return true end
        
        print("Attempting to push item: "..itemName)
        libinvent.PushItems(virtualInventory, itemName, amount)
    end,          
    ["print"] = function(args) -- print cache      
        if not args[2] and not lastItemName then return true end
    
        local nameMatches = {autocomplete.ItemNameFromCache(args[2] or lastItemName, inventoryCache)}
        
        lastItemName = nameMatches[1] or lastItemName or args[2]
        
        if #nameMatches == 0 or nameMatches[1] == "*" then
            print(string.format("Could not find any items with sub string '%s'", args[2] or lastItemName))
        end
        
        for i = #nameMatches, 1, -1 do
            if inventoryCache.items[nameMatches[i]] then
                print(string.format("[\"%s\"] = %i", nameMatches[i], inventoryCache.items[nameMatches[i]]))
            end
        end
    end,        
    ["quit"] = function(args)
        os.queueEvent("terminate")
    end,
    
    ["cfgsave"] = function(args)
        serial.SaveConfig(configFilePath, configData)
    end,    
    ["cfgset"] = function(args)
        if not args[2] then return true end
        configData[tostring(args[2])] = args[3]
    end,    
    ["cfgget"] = function(args)
        if not args[2] then return true end
        
        local key = tostring(args[2])
        if not configData[key] then 
            print(string.format("Key '%s' not found.", key))
            return
        end
        
        print(string.format("%s = %s", key, configData[key]))
    end,    
    ["cfgprint"] = function(args)
        for k, v in pairs(configData) do
            print(string.format("%s = %s", k, v))
        end
    end,
}

term.clear()
libinvent.RunCommandLoop(inventoryModem, interfacePeripheralName, virtualInventory, inventoryCache, commandSwitch, helpSwitch)
