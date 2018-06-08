missinglink = missinglink or {}
if not missinglink.wrapCallbacks then
    require './callback_wrap'
end
local wrapCallbacks = missinglink.wrapCallbacks
local baseInit
if missinglink.BaseCallback then
    baseInit = missinglink.BaseCallback.__init
else
    baseInit = require './base_callback'
end
local DPCallback = torch.class('missinglink.DPCallback', 'missinglink.BaseCallback')

function DPCallback:__init(experiment, optimizer, host)
    --baseInit(host)

    -- Callbacks setup
    local callbacks = {
        'epochCallback',
        'callback',
    }

    -- Monkey patch
    wrapCallbacks(experiment, self, 'run', callbacks, optimizer)
end

function DPCallback:run(ds)
    print ('run')
end

function DPCallback:epochCallback(model, report)
    print ('epoch')
end

function DPCallback:callback(model, report)
    print ('batch')
end