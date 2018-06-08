missinglink = missinglink or {}

function missinglink.wrapCallbacks(caller, callee, callerFuncName, callbackNames, callbacksTable)
    callbacksTable = callbacksTable or caller
    local oldCallbacks = {}
    local newCallbacks = {}

    -- Callbacks setup
    for _, callbackName in pairs(callbackNames) do
        local function f(...)
            callee[callbackName](callee, ...)
            if oldCallbacks[callbackName] then
                oldCallbacks[callbackName](...)
            end
        end

        newCallbacks[callbackName] = f
    end

    -- Wrap function
    local function wrapIfNeeded(_callbacksTable)
        for _, callbackName in pairs(callbackNames) do
            if _callbacksTable[callbackName] ~= newCallbacks[callbackName] then
                oldCallbacks[callbackName] = _callbacksTable[callbackName]
                _callbacksTable[callbackName] = newCallbacks[callbackName]
            end
        end
    end

    -- Monkey patch
    local callerFunc = caller[callerFuncName]
    local function patchedFunc(_caller, ...)
        wrapIfNeeded(callbacksTable)
        if callee[callerFuncName] then
            callee[callerFuncName](callee, _caller, ...)
        end
        callerFunc(_caller, ...)
    end
    caller[callerFuncName] = patchedFunc
end