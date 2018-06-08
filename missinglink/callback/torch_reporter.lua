missinglink = missinglink or {}
local baseInit
if missinglink.BaseCallback then
    baseInit = missinglink.BaseCallback.__init
else
    baseInit = require './base_callback'
end
local Reporter = torch.class('missinglink.Reporter', 'missinglink.BaseCallback')

function Reporter:__init(model, total_epochs, host)
    baseInit(self, host)
    self.currentBatch = 0
    self.currentEpoch = 0
    local params = {['framework'] = 'torch' }
    if total_epochs then
        params['nb_epoch'] = total_epochs
    end
    self:trainBegin(tostring(model), params)
    self:epochBegin(self.currentEpoch, {})
end

function Reporter:report(epoch, metrics)
    -- Infer current batch
    if epoch == self.current_epoch then
        self.currentBatch = self.currentBatch + 1
    else
        self:epochEnd(self.currentEpoch)
        self:epochBegin(epoch, {})
        self.currentEpoch = epoch
        self.currentBatch = 1
    end

    self:batchBegin(self.currentBatch, self.currentEpoch)
    self:batchEnd(self.currentBatch, self.currentEpoch, metrics)
end

function Reporter:endExperiment()
    self:epochEnd(self.currentEpoch)
    self:trainEnd()
end