missinglink = missinglink or {}
local getDispatch = require './dispatchers/missinglink'
local BaseCallback = torch.class('missinglink.BaseCallback')
local DISPATCH_INTERVAl = 5


local function updateTable(params, kwargs)
    kwargs = kwargs or {}
    for key, val in pairs(kwargs) do
        params[key] = val
    end
end

local function getIso()
    return os.date("!%Y-%m-%dT%TZ")
end

local function isoToSeconds(iso)
    local pattern = "(%d+)%-(%d+)%-(%d+)%a(%d+)%:(%d+)%:([%d%.]+)%a"
    local year, month, day, hour, minute, second = iso:match(pattern)
    local date = {
        ['year'] = year,
        ['month'] = month,
        ['day'] = day,
        ['hour'] = hour,
        ['min'] = minute,
        ['sec'] = second,
    }
    return os.time(date)
end


function BaseCallback:__init(host)
    if not missinglink.ownerID or not missinglink.projectToken then
        error ('Missing owner id or project token. Did you call missinglink.init()?')
    end
    self.dispatch = getDispatch(missinglink.ownerID, missinglink.projectToken, host)
    self.batches_queue = {}
    self.iteration = 1
end

function BaseCallback:batchCommand(event, data, flush)
    flush = flush or false
    table.insert(self.batches_queue, {event, data, getIso()})

    local ts_start = isoToSeconds(self.batches_queue[1][3])  -- timestamp is in 3rd index
    local ts_end = isoToSeconds(self.batches_queue[#self.batches_queue][3])
    local queue_duration = ts_end - ts_start

    if queue_duration > DISPATCH_INTERVAl or flush then
        self.dispatch(self.batches_queue)
        self.batches_queue = {}
    end
end

function BaseCallback:trainBegin(model, params, kwargs)
    params = params or {}
    self.iteration = 1
    local data = {
        ['params'] = params,
        ['model'] = model
    }
    updateTable(data, kwargs)
    self:batchCommand('TRAIN_BEGIN', data)
end

function BaseCallback:trainEnd(kwargs)
    local data = {['iterations'] = self.iteration}
    updateTable(data, kwargs)
    self:batchCommand('TRAIN_END', data, true)
end

function BaseCallback:epochBegin(epoch, params, kwargs)
    params = params or {}
    local data = {
        ['epoch'] = epoch,
        ['params'] = params
    }
    updateTable(data, kwargs)
    self:batchCommand('EPOCH_BEGIN', data)
end

function BaseCallback:epochEnd(epoch, results, params, kwargs)
    results = results or {}
    params = params or {}
    local data = {
        ['epoch'] = epoch,
        ['params'] = params,
        ['results'] = results
    }
    updateTable(data, kwargs)
    self:batchCommand('EPOCH_END', data)
end

function BaseCallback:batchBegin(batch, epoch, kwargs)
    local data = {
        ['batch'] = batch,
        ['epoch'] = epoch,
        ['iteration'] = self.iteration
    }
    updateTable(data, kwargs)
    self:batchCommand('BATCH_BEGIN', data)
end

function BaseCallback:batchEnd(batch, epoch, metricData, kwargs)
    local data = {
        ['batch'] = batch,
        ['epoch'] = epoch,
        ['iteration'] = self.iteration,
        ['metricData'] = metricData
    }
    updateTable(data, kwargs)
    self:batchCommand('BATCH_END', data)
    self.iteration = self.iteration + 1
end


return BaseCallback.__init