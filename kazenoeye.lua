addon.name      = 'kazenoeye';
addon.author    = 'kazenohito';
addon.version   = '1.4.4';
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
    -- Parse the command arguments..
    local args = e.command:args();
    if (#args == 0 or not args[1]:any('/kazenoeye')) then
        return;
    end

    -- Block all related commands..
    e.blocked = true;

    if table.contains({'/kazenoeye'}, args[1]) then
		-- Toggle the config menu
		showConfig[1] = not showConfig[1];
		return;
	end
end);
