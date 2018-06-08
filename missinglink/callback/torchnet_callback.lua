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
local TorchnetCallback = torch.class('missinglink.TorchnetCallback', 'missinglink.BaseCallback')

local function isArray(t)
    if #t == 0 then return false end
    local i = 0
    for _ in pairs(t) do
        i = i + 1
        if t[i] == nil then return false end
    end
    return true
end

function TorchnetCallback:__init(engine, host)
    baseInit(self, host)
    self.samplesCounter = 0
    self.meters = {}

    -- Callbacks setup
    local callbacks = {
        'onStart',
        'onStartEpoch',
        'onSample',
        'onUpdate',
        'onEndEpoch',
        'onEnd'
    }

    -- Monkey patch
    wrapCallbacks(engine, self, 'train', callbacks, engine.hooks)
end

function TorchnetCallback:setMeters(meters)
    self.meters = {}
    if isArray(meters) then
        print ('Meters are in an array - indices will appear in graph')
    end
    for key, value in pairs(meters) do
        local result
        -- Allowing input args for ClassErrorMeter, PrecisionMeter, PrecisionAtKMeter, RecallMeter and NDCGMeter
        if pcall(function() result = isArray(value) end) then
            if not result then
                error ('Values in meters are not arrays nor meters')
            end
            -- Saving meter in format {meter, input args}
            local meter = {value[1], value[2]}
            self.meters[key] = meter
        else
            local meter = {value, nil}
            self.meters[key] = meter
        end
    end
end

function TorchnetCallback:onStart(state)
    if state.training then
    self:trainBegin(tostring(state.network), {
        criterion = tostring(state.criterion),
        maxepoch = state.maxepoch,
    })
    end
end

function TorchnetCallback:onStartEpoch(state)
    if state.training then
    self:epochBegin(state.epoch)
    end
end

function TorchnetCallback:onSample(state)
    if state.training then
    self:batchBegin(state.t - self.samplesCounter, state.epoch)
    end
end

function TorchnetCallback:onUpdate(state)
    if state.training then
    local metricData = {}
    for key, meter in pairs(self.meters) do
        -- Use args if exist
        local meterObject, args = meter[1], meter[2]
        if args then
            metricData[key] = meterObject:value(args)
        else
            metricData[key] = meterObject:value()
        end
    end
    self:batchEnd(state.t - self.samplesCounter, state.epoch, metricData)
    end
end

function TorchnetCallback:onEndEpoch(state)
    if state.training then
    self.samplesCounter = state.t
    self:epochEnd(state.epoch)
    end
end

function TorchnetCallback:onEnd(state)
    if state.training then
    self:trainEnd()
    end
end