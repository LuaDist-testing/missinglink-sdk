missinglink = missinglink or {}
local baseInit
if missinglink.BaseCallback then
    baseInit = missinglink.BaseCallback.__init
else
    baseInit = require './base_callback'
end
local Reporter = torch.class('missinglink.Reporter', 'missinglink.BaseCallback')
local setPropertiesCheck = require 'argcheck'{
    {name='totalEpochs', type='number', default=nil},
    {name='batchSize', type='number', default=nil},
    {name='epochSize', type='number', default=nil},
    {name='description', type='string', default=nil},
}

function Reporter:__init(model, host)
    baseInit(self, host)
    self.hasStarted = false
    self.currentBatch = 0
    self.currentEpoch = 0
    self.model = model
    self.properties = {['framework'] = 'torch' }
    self.latestResults = nil
end

function Reporter:setProperties(...)
    local totalEpochs, batchSize, epochSize, description = setPropertiesCheck()
    self.properties.nb_epoch = totalEpochs or self.properties.nb_epoch
    self.properties.batch_size = batchSize or self.properties.batch_size
    self.properties.nb_sample = epochSize or self.properties.nb_sample
    self.properties.description = description or self.properties.description
end

function Reporter:trainBeginIfNeeded()
    if not self.hasStarted then
        self:trainBegin(tostring(self.model), self.properties)
        self:epochBegin(self.currentEpoch, {})
    end
end

function Reporter:endBatch(epoch, metrics)
    self:trainBeginIfNeeded()

    -- Infer current batch
    if epoch == self.currentEpoch then
        self.currentBatch = self.currentBatch + 1
    else
        self:epochEnd(self.currentEpoch)
        self:epochBegin(epoch, {})
        self.currentEpoch = epoch
        self.currentBatch = 1
    end

    self:batchBegin(self.currentBatch, self.currentEpoch)
    self:batchEnd(self.currentBatch, self.currentEpoch, metrics)
    self.latestResults = metrics
end

function Reporter:endEpoch(epoch, metrics)
    metrics = metrics or {}
    self.latestResults = self.latestResults or {}

    for key, val in pairs(metrics) do
        self.latestResults['val_' .. key] = val
    end
    self:epochEnd(epoch, self.latestResults)
end

function Reporter:endExperiment()
    self:epochEnd(self.currentEpoch)
    self:trainEnd()
end