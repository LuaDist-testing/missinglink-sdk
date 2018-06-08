missinglink = missinglink or {}
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
    local deadDispatcher = false

    local function postJson(endpoint, json_table)
        local data = jsonEncode(json_table)

        local options = {
            ['content_type'] = 'application/json',
            params = {
                ['owner_id'] = ownerId,
                ['project_token'] = projectToken
            }
        }

        local res
        for i=1, 3 do
            res = httpClient:post(
                host .. endpoint,
                data,
                options
            )
            if (res.err == nil) or (res.code < 400) then
                return res
            end
        end

        local error_str
        if res.status_line then
            local _, _, e = res.status_line:match('([^ ]+) ([^ ]+) ([^\n]+)')
            error_str = e
            if not error_str then
                error_str = tostring(res.code)
            end
        end
        local bad_request = error_str or tostring(res.err)
        missinglink.logger.warning('Failed to communicate with missinglink server:\n%s - %s\n' ..
                                'This experiment will not be available or will have missing data',
                                bad_request, res.body)
        deadDispatcher = true
    end

    local function create_new_experiment()
        local params = {
            ['owner_id'] = ownerId,
            ['token'] = projectToken
        }

        local res = postJson("/callback/step/begin", params)

        if not res == nil then
            return jsonDecode(res.body)["token"]
        else
            return nil
        end
    end

    local experiment_token = create_new_experiment()

    local function dispatch(commands)
        if not deadDispatcher then
            local params = {
                ['cmds'] = commands,
                ['token'] = experiment_token,
            }

            return postJson("/callback/step", params)
        end
    end

    return dispatch
end

return getMissinglinkDispatcher