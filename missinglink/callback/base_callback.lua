missinglink = missinglink or {}
local getDispatch = require './dispatchers/missinglink'
local BaseCallback = torch.class('missinglink.BaseCallback')
local DISPATCH_INTERVAl = 5
local MAX_BATCHES_PER_EPOCH = 1000
local SEND_EPOCH_CANDIDATES = false

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
    self.points_candidate_indices = {}
    self.iteration = 1
    self.ts_start = 0
    if SEND_EPOCH_CANDIDATES then
        self.epoch_candidate_indices = {}
    end
end

function BaseCallback:batchCommand(event, data, flush)
    local command = { event, data, getIso() }
    flush = flush or false

    if event == 'BATCH_END' then
        local i
        if SEND_EPOCH_CANDIDATES and
                not self.epoch_candidate_indices[data['epoch_candidate']] == nil then
            i = self.epoch_candidate_indices[data['epoch_candidate']]
        elseif not self.points_candidate_indices[data['points_candidate']] == nil then
            i = self.points_candidate_indices[data['points_candidate']]
        else
            i = #self.batches_queue + 1
        end

        self.batches_queue[i] = command

        if SEND_EPOCH_CANDIDATES and not data['epoch_candidate'] == nil then
            self.epoch_candidate_indices[data['epoch_candidate']] = i
        end

        if not data['points_candidate'] == nil then
            self.points_candidate_indices[data['points_candidate']] = i
        end
    else
        table.insert(self.batches_queue, command)
    end

    if #self.batches_queue == 1 then
        self.ts_start = isoToSeconds(getIso())  -- timestamp is in 3rd index
    end

    local ts_end = isoToSeconds(getIso())
    local queue_duration = ts_end - self.ts_start

    if queue_duration > DISPATCH_INTERVAl or flush then
        self.dispatch(self.batches_queue)
        self.batches_queue = {}
    end
end

function BaseCallback:trainBegin(model, params, kwargs)
    params = params or {}
    self.iteration = 0
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
    --[[params = params or {}
    local data = {
        ['epoch'] = epoch,
        ['params'] = params
    }
    updateTable(data, kwargs)
    self:batchCommand('EPOCH_BEGIN', data)]]--
end

function BaseCallback:epochEnd(epoch, results, params, kwargs)
    --[[results = results or {}
    params = params or {}
    local data = {
        ['epoch'] = epoch,
        ['params'] = params,
        ['results'] = results
    }
    updateTable(data, kwargs)
    self:batchCommand('EPOCH_END', data)]]--
end

function BaseCallback:batchBegin(batch, epoch, kwargs)
    --[[local data = {
        ['batch'] = batch,
        ['epoch'] = epoch,
        ['iteration'] = self.iteration
    }
    updateTable(data, kwargs)
    self:batchCommand('BATCH_BEGIN', data)]]--
end

function BaseCallback:batchEnd(batch, epoch, metricData, kwargs)
    local data = {
        ['batch'] = batch,
        ['epoch'] = epoch,
        ['iteration'] = self.iteration,
        ['metricData'] = metricData
    }
    local send = false

    -- Filter batch
    if self.iteration < MAX_BATCHES_PER_EPOCH then
        if SEND_EPOCH_CANDIDATES then
            data['epoch_candidate'] = batch
        end
        data['points_candidate'] = self.iteration
        send = true
    else
        -- Conserve initial location
        local points_candidate = math.random(1, self.iteration - 1)
        if points_candidate < MAX_BATCHES_PER_EPOCH then
            data['points_candidate'] = points_candidate
            send = true
        end

        if SEND_EPOCH_CANDIDATES then
            if batch < MAX_BATCHES_PER_EPOCH then
                data['epoch_candidate'] = batch
                send = true
            else
                local epoch_candidate = math.random(0, batch - 1)
                if epoch_candidate < MAX_BATCHES_PER_EPOCH then
                    data['epoch_candidate'] = epoch_candidate
                    send = true
                end
            end
        end
    end

    if send then
        updateTable(data, kwargs)
        self:batchCommand('BATCH_END', data, self.iteration == 0)
    end

    self.iteration = self.iteration + 1
end


return BaseCallback.__init