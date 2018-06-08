missinglink = missinglink or {}
local getDispatch = require './dispatchers/missinglink'
local BaseCallback = torch.class('missinglink.BaseCallback')
local SEND_EPOCH_CANDIDATES = false
missinglink.DISPATCH_INTERVAl = 5
missinglink.MAX_BATCHES_PER_EPOCH = 1000
local prevSocket = socket
local gettime = require('socket').gettime
socket = prevSocket

local function updateTable(params, kwargs)
    kwargs = kwargs or {}
    for key, val in pairs(kwargs) do
        params[key] = val
    end
end

local function getIso()
    return os.date("!%Y-%m-%dT%TZ")
end

local function generateTag()
    local chars = 'abcdefghijklmnopqrstuvwxyz1234567890_-'
    local s = ''
    for n = 1, 4 do
        local i = math.random(1, #chars)
        --noinspection StringConcatenationInLoops
        s = s .. chars:sub(i, i)
    end
    return s
end


function BaseCallback:__init(host)
    if not missinglink.ownerID or not missinglink.projectToken then
        missinglink.logger.error('Missing owner id or project token. Did you call missinglink.init()?')
    end
    self.host = host
    self.batches_queue = {}
    self.points_candidate_indices = {}
    self.iteration = 0
    self.ts_start = 0
    self.epochAddition = 0
    if SEND_EPOCH_CANDIDATES then
        self.epoch_candidate_indices = {}
    end
end

function BaseCallback:newExperiment()
    self.dispatch = getDispatch(missinglink.ownerID, missinglink.projectToken, self.host)
    self.batches_queue = {}
    self.iteration = 0
    self.ts_start = 0
    self.epochAddition = 0
    self.points_candidate_indices = {}
    if SEND_EPOCH_CANDIDATES then
        self.epoch_candidate_indices = {}
    end
end

function BaseCallback:batchCommand(event, data, flush)
    if not self.dispatch then
        missinglink.logger.warning('MissingLink callback cannot send data before train_begin is called.\n' ..
                'Please advice the instruction page for proper use')
        return
    end

    flush = flush or false
    local command = { event, data, getIso() }

    if event == 'BATCH_END' then
        local i
        if SEND_EPOCH_CANDIDATES and
                self.epoch_candidate_indices[data['epoch_candidate']] then
            i = self.epoch_candidate_indices[data['epoch_candidate']]
        elseif self.points_candidate_indices[data['points_candidate']] then
            i = self.points_candidate_indices[data['points_candidate']]
        else
            i = #self.batches_queue + 1
        end
        self.batches_queue[i] = command

        if SEND_EPOCH_CANDIDATES and data['epoch_candidate'] then
            self.epoch_candidate_indices[data['epoch_candidate']] = i
        end

        if data['points_candidate'] then
            self.points_candidate_indices[data['points_candidate']] = i
        end
    else
        table.insert(self.batches_queue, command)
    end

    if #self.batches_queue == 1 then
        self.ts_start = gettime()  -- timestamp is in 3rd index
    end

    local ts_end = gettime()
    local queue_duration = ts_end - self.ts_start

    if queue_duration >= missinglink.DISPATCH_INTERVAl or flush then
        self.dispatch(self.batches_queue)
        self.batches_queue = {}
        self.points_candidate_indices = {}
        if SEND_EPOCH_CANDIDATES then
            self.epoch_candidate_indices = {}
        end
    end
end

function BaseCallback:trainBegin(model, params, kwargs)
    self:newExperiment()
    params = params or {}
    self.iteration = 1
    local data = {
        ['params'] = params,
        ['model'] = model
    }
    updateTable(data, kwargs)
    self:batchCommand('TRAIN_BEGIN', data, true)
end

function BaseCallback:trainEnd(kwargs)
    local data = {['iterations'] = self.iteration}
    updateTable(data, kwargs)
    self:batchCommand('TRAIN_END', data, true)
end

function BaseCallback:epochBegin(epoch, params, kwargs)
    if epoch == 0 then
            self.epochAddition = 1
    end
end

function BaseCallback:epochEnd(epoch, results, params, kwargs)
    results = results or {}
    params = params or {}

    local length = 0
    for _ in pairs(results) do length = length + 1 end

    if length > 0 then
        local data = {
            ['epoch'] = epoch + self.epochAddition,
            ['params'] = params,
            ['results'] = results
        }
        updateTable(data, kwargs)
        self:batchCommand('EPOCH_END', data, data.epoch == 1)
    end
end

function BaseCallback:batchBegin(batch, epoch, kwargs) end

function BaseCallback:batchEnd(batch, epoch, metricData, kwargs)
    local data = {
        ['batch'] = batch,
        ['epoch'] = epoch,
        ['iteration'] = self.iteration,
        ['metricData'] = metricData
    }
    local send = false

    -- Filter batch
    if self.iteration < missinglink.MAX_BATCHES_PER_EPOCH then
        if SEND_EPOCH_CANDIDATES then
            data['epoch_candidate'] = batch
        end
        data['points_candidate'] = self.iteration
        send = true
    else
        -- Conserve initial location
        local points_candidate = math.random(1, self.iteration - 1)
        if points_candidate < missinglink.MAX_BATCHES_PER_EPOCH then
            data['points_candidate'] = points_candidate
            send = true
        end

        if SEND_EPOCH_CANDIDATES then
            if batch < missinglink.MAX_BATCHES_PER_EPOCH then
                data['epoch_candidate'] = batch
                send = true
            else
                local epoch_candidate = math.random(0, batch - 1)
                if epoch_candidate < missinglink.MAX_BATCHES_PER_EPOCH then
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