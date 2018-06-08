if not torch then require ('torch') end
local argcheck = require 'argcheck'

missinglink = {}

-- Load classes
require ('./callback/torch_sg_callback')
--require ('./callback/torch_dp_callback')
require ('./callback/torch_reporter')
require ('./callback/torchnet_callback')

-- Remove private classes
missinglink['BaseCallback'] = nil
missinglink['wrapCallbacks'] = nil


function missinglink.init(args)
    if not args.ownerID or not args.projectToken then
        error('Expected ownerID and projectToken')
    end
    missinglink.ownerID = args.ownerID
    missinglink.projectToken = args.projectToken
end

return missinglink
