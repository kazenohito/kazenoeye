addon.name      = 'kazenoeye';
addon.author    = 'kazenohito';
addon.version   = '1.4.5';
addon.desc      = 'Display information about Entity within visible range';
addon.link      = 'https://github.com/kazenohito/kazenoeye';

require('common');

ashita.events.register('load', 'load_cb', function ()
    setting = require('setting');
    targetmarker = require('targetmarker');
    mobhug = require('mobhud');
end);

ashita.events.register('unload', 'unload_cb', function ()
end);

ashita.events.register('command', 'command_cb', function (e)
    local args = e.command:args();
    if (#args == 0) then
        return
    end

    if (args[1] ~= '/kazenoeye') and (args[1] ~= '/ke') then
        return
    end

    e.blocked = true

    if (table.contains({'/kazenoeye'}, args[1]) or table.contains({'/ke'}, args[1])) then
		showConfig[1] = not showConfig[1]
		return
    end
end);
