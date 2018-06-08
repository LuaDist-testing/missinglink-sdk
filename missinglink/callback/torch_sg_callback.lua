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
local StochasticGradientCallback = torch.class('missinglink.StochasticGradientCallback', 'missinglink.BaseCallback')

function StochasticGradientCallback:__init(trainer, host)
    baseInit(self, host)
    self.currentBatch = 1
    self.currentEpoch = 1
    self.epochSize = 0

    wrapCallbacks(trainer, self, 'train', {'hookIteration', 'hookExample'})
end

function StochasticGradientCallback:train(trainer, dataset)
    self:trainBegin(tostring(trainer.module))
    if self.iteration == 1 then
        self.currentBatch = 1
        self.currentEpoch = 1
        self:epochBegin(1, {})
        self:batchBegin(1, 1, {})
    end
    self.epochSize = dataset:size()
    if trainer.maxIteration <= 0 then
        error("maxIteration is not a positive integer - endless training not allowed")
    end
end

function StochasticGradientCallback:hookExample(trainer, input)
    --self:batchEnd(self.currentBatch, self.currentEpoch, {})
    --if self.currentBatch < self.epochSize then
    --    self.currentBatch = self.currentBatch + 1
    --    self:batchBegin(self.currentBatch, self.currentEpoch, {})
    --end
end

function StochasticGradientCallback:hookIteration(trainer, epoch, loss)
    self.currentBatch = 1
    self:batchEnd(1, epoch, {['loss'] = loss})
    self:epochEnd(epoch)

    if trainer.maxIteration <= 0 then
        error("maxIteration is not a positive integer - endless training not allowed")
        self:trainEnd()
    elseif epoch >= trainer.maxIteration then
        self:trainEnd()
    else
        self.currentEpoch = self.currentEpoch + 1
        self:epochBegin(self.currentEpoch, {})
        self:batchBegin(1, self.currentEpoch, {})
    end
end
