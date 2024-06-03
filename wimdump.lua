local lfs = require("lfs")

-- When called with lua -l WIM, the WIM data will already be imported and available in WIM3_Data

DUMP_DIR="WIM_Dump"

function dump(o)

    for k, v in pairs(o) do
        print(tostring(k)..": "..tostring(v))
    end
    --[[
    if type(o) == 'table' then
       local s = '{ '
       for k,v in pairs(o) do
          if type(k) ~= 'number' then k = '"'..k..'"' end
          s = s .. '['..k..'] = ' .. dump(v) .. ','
       end
       return s .. '} '
    else
       return tostring(o)
    end]]--
end

local function mkdirp(dir)
    if lfs.attributes(dir, 'mode') == 'directory' then
        return true
    end

    local r, m = lfs.mkdir(dir)
    if not r then
        print("Error creating directory: "..m)
        os.exit(1)
    end
end

local function chdir(dir)
    local r, m = lfs.chdir(dir)
    if not r then
        print("Unable to change to directory: "..m)
        os.exit(1)
    end
end

local function badname(dir)
    return string.find(dir, "/") or string.find(dir, "\\")
end

local function format_message(msg)
    if msg.type ~= 1 then
        print("Unknown message type of "..msg.type)
        os.exit(1)
    end
    return string.format("%s %s: %s", os.date("%Y-%m-%d %H:%M:%S", msg.time), msg.from, msg.msg)
end

function day(timestamp)
    local ret = os.date("*t", timestamp)
    ret.hour = 0
    ret.min = 0
    ret.sec = 0
    return os.time(ret)
end

function write_file(name, messages)
    for _, message in ipairs(messages) do
        print(format_message(message))
    end
end


mkdirp(DUMP_DIR)
chdir(DUMP_DIR)

local files_written = 0
local messages_written = 0
local files_skipped = 0
-- Set a cutoff of midnight UTC a day ago. This way if the file was copied within the last day the messages will be complete.
cutoff = day() - 24*60*60
print(os.date("Dumping messages up to %Y-%m-%d", cutoff))
for realm, chars in pairs(WIM3_History) do
    if badname(realm) then
        print("Corrupt realm name: "..realm)
        os.exit(1)
    end
    mkdirp(realm)
    chdir(realm)
    for character, char_history in pairs(chars) do
        if badname(character) then
            print("Corrupt character name: "..character)
            os.exit(1)
        end
        mkdirp(character)
        chdir(character)
        for sender, msgs in pairs(char_history) do
            if badname(sender) then
                print("Corrupt sender name: "..sender)
                os.exit(1)
            end
            mkdirp(sender)
            chdir(sender)
            local last_date = 0
            local conversations = {}

            -- Split the messages up by day
            for _, msg in ipairs(msgs) do
                if msg.time >= cutoff then
                    break
                end
                msg_date = day(msg.time)
                filename = os.date("%Y-%m-%d.txt", msg_date)
                if msg_date > last_date then
                    -- This is the first message in a new file
                    last_date = msg_date
                    conversations[filename] = {}
                end
                table.insert(conversations[filename], msg)
            end
            for filename, messages in pairs(conversations) do
                if not lfs.attributes(filename) then
                    files_written = files_written + 1
                    local f = assert(io.open(filename, "w"))
                    for _, message in ipairs(messages) do
                        messages_written = messages_written + 1
                        f:write(string.format("%s\n", format_message(message)))
                    end
                    f:close()
                else
                    files_skipped = files_skipped + 1
                end
            end
            chdir("../")
        end
        chdir("../")
    end
    chdir("../")
end

print(string.format("%d files written, %d files already exist, %d messages written.",
    files_written, files_skipped, messages_written))