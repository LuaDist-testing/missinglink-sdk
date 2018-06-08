local jsonEncode = require 'json.encode'.encode
local jsonDecode = require 'json.decode'.decode

local function newClient()
    local function script_path()
        local str = debug.getinfo(2, "S").source:sub(2)
        return str:match("(.*/)")
    end

    local params = {
        mode = 'client',
        protocol = 'tlsv1_2',
        cafile = script_path() .. '../../cacert.pem.lua'
    }

    local client = require('httpclient').new()

    client:set_default('cafile', params.cafile)
    client:set_default('protocol', params.protocol)
    client.client.defaults.ssl_opts.cafile = params.cafile
    client.client.defaults.ssl_opts.protocol = params.protocol

    return client
end

local function getDummyDispatcher(ownerId, projectToken, host)
    local function dispatch(commands)
        print(commands)
    end
    return dispatch
end

local function getMissinglinkDispatcher(ownerId, projectToken, host)
    local host = host or "https://missinglinkai.appspot.com"
    local httpClient = newClient()

    local function postJson(endpoint, params)
        local data = jsonEncode(params)

        local options = {
            ['content_type'] = 'application/json'
        }

        return httpClient:post(
            host .. endpoint,
            data,
            options
        )
    end

    local function create_new_experiment()
        local params = {
            ['owner_id'] = ownerId,
            ['token'] = projectToken
        }

        local res = postJson("/callback/step/begin", params)

        if res.err or res.code >= 400 then
            local error_str
            if res.status_line then
                local _, _, e = res.status_line:match('([^ ]+) ([^ ]+) ([^\n]+)')
                error_str = e
                if not error_str then
                    error_str = tostring(res.code)
                end
            end
            local bad_request = error_str or tostring(res.err)
            error(string.format('HTTP Error (%s): %s', bad_request, res.body))
        end

        return jsonDecode(res.body)["token"]
    end

    local experiment_token = create_new_experiment()

    local function dispatch(commands)
        local params = {
            ['cmds'] = commands,
            ['token'] = experiment_token,
        }

        return postJson("/callback/step", params)
    end

    return dispatch
end

return getMissinglinkDispatcher