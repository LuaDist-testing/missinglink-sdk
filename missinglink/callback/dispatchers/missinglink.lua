missinglink = missinglink or {}
local jsonEncode = require 'json.encode'.encode
local jsonDecode = require 'json.decode'.decode

local SAVE_LOGS = false

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

local function getMissinglinkDispatcher(ownerID, projectToken, host)
    local host = host or "https://missinglinkai.appspot.com"
    local httpClient = newClient()
    local deadDispatcher = false

    local logsDir
    local counter
    local order

    if SAVE_LOGS then
        logsDir = 'logs'
        paths.mkdir(logsDir)
        counter = 0

        order = function(a, b)
            if (a[1] == b[1]) and (a[1] == 'BATCH_END') then
                return a[2]['iteration'] < b[2]['iteration']
            end
            return b[1] == 'BATCH_END'
        end
    end

    local function postJson(endpoint, json_table)
        local data = jsonEncode(json_table)

        if SAVE_LOGS then
            local path = paths.concat(logsDir, 'commands' .. counter .. '.json')
            missinglink.logger.warning('Saving %d bytes to %s', #data, path)
            local file, errorMsg = io.open(path, 'w')
            if file then
                file:write(data)
                file:close()
            else
                missinglink.logger.error('Failed writing to file %s:\n%s', path, errorMsg)
            end

            counter = counter + 1
        end

        local options = {
            ['content_type'] = 'application/json',
            params = {
                ['owner_id'] = ownerID,
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
            if not res.err and (res.code < 400) then
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
            ['owner_id'] = ownerID,
            ['token'] = projectToken
        }

        local res = postJson("/callback/step/begin", params)

        if res then
            return jsonDecode(res.body)["token"]
        else
            return nil
        end
    end

    local experiment_token = create_new_experiment()

    local function dispatch(commands)
        if not deadDispatcher then
            if SAVE_LOGS then
                table.sort(commands, order)
            end

            local params = {
                ['token'] = experiment_token,
                ['cmds'] = commands,
            }

            return postJson("/callback/step", params)
        end
    end

    return dispatch
end

return getMissinglinkDispatcher