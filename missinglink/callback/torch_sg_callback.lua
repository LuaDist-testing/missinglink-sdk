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
local setPropertiesCheck = require 'argcheck'{
    {name='description', type='string', default=nil},
}

function StochasticGradientCallback:__init(trainer, host)
    baseInit(self, host)
    self.properties = {['framework'] = 'torch'}
    wrapCallbacks(trainer, self, 'train', {'hookIteration', 'hookExample'})
end

function StochasticGradientCallback:setProperties(...)
    local description = setPropertiesCheck()
    self.properties.description = description or self.properties.description
end

function StochasticGradientCallback:train(trainer, dataset)
    if trainer.maxIteration <= 0 then
        error("maxIteration is not a positive integer - endless training not allowed")
    end

    self.properties.nb_epoch = trainer.maxIteration
    self.properties.nb_sample = dataset:size()

    self:trainBegin(tostring(trainer.module), self.properties)
end

function StochasticGradientCallback:hookExample(trainer, input) end

function StochasticGradientCallback:hookIteration(trainer, epoch, loss)
    self:epochBegin(epoch)
    self:epochEnd(epoch, {error=loss})

    if trainer.maxIteration <= 0 then
        error("maxIteration is not a positive integer - endless training not allowed")
        self:trainEnd()
    elseif epoch >= trainer.maxIteration then
        self:trainEnd()
    end
end
