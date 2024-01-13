local serial = {}

-- invert tokens table for fast lookups
local function InvertLUT(tab)
    local tempTable = {}
    for i, v in ipairs(tab) do
        tempTable[v] = true
    end
    return tempTable
end

-- SINGLE character symbols
serial.symbols = {
    "=",
}

serial.symbols = InvertLUT(serial.symbols)

-- this may be overengineered
serial.whiteSpace = {
    " ",
    "\t",
    "\r",
    "\n",
}

serial.whiteSpace = InvertLUT(serial.whiteSpace)

-- assumes path is absolute
function serial.LoadConfig(filePath)
    if not fs.exists(filePath) then
        serial.SaveConfig(filePath, {["interface"]="minecraft:chest_1", ["modemside"]="top"})
    end
    
    local file = fs.open(filePath, "r")
    
    local tokens = {}
    
    while true do
        local line = file.readLine()
        if not line then break end
        
        serial.TokenizeLine(line, tokens)
    end
    
    file.close()
    
    local configData = {}
    for i, v in ipairs(tokens) do
        if v == "=" then
            local key, value = serial.ParseToken(tokens, i)
            if key then
                configData[tostring(key)] = value
            end
        end
    end
    
    return configData
end

function serial.SaveConfig(filePath, configData)
    local file = fs.open(filePath, "w")
    
    for k, v in pairs(configData) do
        file.writeLine(string.format("%s = %s", k, tostring(v)))
    end
    
    file.close()
end

-- line is str
function serial.TokenizeLine(line, tokens)
    local curStart = string.find(line, "[^%s]") or 0 
    
    local lineLen = string.len(line)
    local i = curStart

    local prevChar = " "

    while i <= lineLen do
        local curChar = string.sub(line, i, i)
        
        if (not serial.whiteSpace[curChar] and serial.whiteSpace[prevChar]) then
            curStart = i
        end   
        
        if curStart ~= i or i == lineLen then
            if (serial.whiteSpace[curChar] and not serial.whiteSpace[prevChar]) or serial.symbols[curChar] then
                tokens[#tokens+1] = string.sub(line, curStart, i-1)
            elseif (not serial.whiteSpace[curChar] and i == lineLen) then
                tokens[#tokens+1] = string.sub(line, curStart, i)
            end
        end
        
        if serial.symbols[curChar] then
            curStart = i + 1
            tokens[#tokens+1] = curChar
        end
        
        prevChar = curChar
        i = i + 1
    end
end

serial.tokenSwitch = {
    ["="] = function(tokens, index)
        return serial.ParseToken(tokens, index-1), serial.ParseToken(tokens, index+1)
    end,    
}

function serial.ParseToken(tokens, index)
    local tokenFunc = rawget(serial.tokenSwitch, tokens[index])
    if tokenFunc then
        return tokenFunc(tokens, index)
    end
    
    return tonumber(tokens[index]) or tokens[index]
end

return serial