local discordia = require('discordia')
local client = discordia.Client()

client:on('ready', function()
    print('Logged in as '.. client.user.username)
end)

client:on('messageCreate', function(message)
    if message.author.bot then return end -- Ignore messages from bots

    -- Split the message into the command and its arguments
    local args = {}
    for word in message.content:gmatch("%S+") do
        table.insert(args, word)
    end

    if message.content == '!ping' then
        message.channel:send('Pong!')
    end


    if message.author.bot then return end -- Ignore messages from bots

    -- Split the message into the command and its arguments
    local args = {}
    for word in message.content:gmatch("%S+") do
        table.insert(args, word)
    end

    -- Announce command
    if args[1] == '!announce' then
        -- Check if the member has the required permissions to use the command
        if not message.member:hasPermission('administrator') then
            message.channel:send('You don\'t have permission to use this command.')
            return
        end

        -- Remove the command from the arguments
        table.remove(args, 1)

        -- Join the remaining arguments into a single string
        local announcement = table.concat(args, ' ')

        -- Send the announcement to the server's default channel
        message.guild.defaultChannel:send(announcement)
    end

    -- Rules command
    if args[1] == '!rules' then
        -- Send the server rules to the member
        message.author:send('Here are the server rules:\n\n1. Be respectful\n2. No spamming\n3. No NSFW content')
    end
end)

client:run('')
