local interfaceabstraction = {}

-- basically what list() does on an inventory peripheral
function interfaceabstraction.ListItems(modem, interfaceName)
    if not turtle then
        return modem.callRemote(interfaceName, "list")
    else
        local items = {}
        for i = 1, 16 do
            local itemDetail = turtle.getItemDetail(i)
            if itemDetail then
                items[i] = itemDetail
            end
        end
        return items
    end
end

function interfaceabstraction.GetItemCount(modem, interfaceName, itemName)
    local count = 0

    if itemName == "*" then
        for k, v in pairs(interfaceabstraction.ListItems(modem, interfaceName)) do
            count = count + v.count
        end
    else
        for k, v in pairs(interfaceabstraction.ListItems(modem, interfaceName)) do
            if v.name == itemName then
                count = count + v.count
            end
        end
    end
    
    return count
end


return interfaceabstraction