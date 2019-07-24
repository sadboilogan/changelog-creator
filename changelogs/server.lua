local Config = {
	Webhook = GetConvar("changelog_webhook", "false") == "false" and false or GetConvar("changelog_webhook", "false"), -- Native complains if you pass false as non-string, hacky fix
	FileName = GetConvar("changelog_filename", "changelog.json"),
	DumpFolderName = GetConvar("changelog_dumpfoldername", "dump")
}

local function IsFilePresent(filename)
	local f = LoadResourceFile(GetCurrentResourceName(), filename)
	return f and true or false
end

local function GetDate()
	return os.date('%H-%M_%d-%m-%Y', os.time())
end

Citizen.CreateThread(function()
	if not Config.Webhook or not IsFilePresent(Config.FileName) then
		print("^1Could not find Webhook and/or Config. Ensure they are both present in your cfg!^7") -- Also ensure the folder for dumping old changelogs exists
		return
	else
		print("^2Webhook and config found! Checking changelog info...^7")
	end

	-- MAIN CODE

	local Changelog = json.decode(LoadResourceFile(GetCurrentResourceName(), Config.FileName)) -- Convert the JSON into a lua table
	
	if Changelog.Version == Changelog.DO_NOT_CHANGE_VER then -- If versions match, kill the thread - no point running code past here
		print("^3No changelog difference, not posting.^7")
		return
	end

	-- Code past here will only run if there is a version diff

	local Changes = {
		Additions = {},
		Removals = {},
		Modifications = {},
		Misc = {}
	}

	for i=1, #Changelog.Changes do
		local Change = Changelog.Changes[i]
		local FirstChar = string.sub(Change, 1, 1)
		local NewChange = string.gsub(Change, FirstChar.." ", "")

		if FirstChar == "+" then
			table.insert(Changes.Additions, NewChange)
		elseif FirstChar == "-" then
			table.insert(Changes.Removals, NewChange)
		elseif FirstChar == "*" then
			table.insert(Changes.Modifications, NewChange)
		else
			table.insert(Changes.Misc, Change)
		end
	end

	local DiscordEmbed = {
		{
			title = "Changelog for version "..Changelog.Version,
			color = 16335900,
			fields = {},
			footer = {
				text = "Server Changelogs"
			}
		}
	}

	if #Changes.Additions > 0 then
		local str = ""
		for i=1, #Changes.Additions do 
			str = str.."• "..Changes.Additions[i].."\n"
		end
		table.insert(DiscordEmbed[1].fields, {name = "Additions", value = str})
	end
	if #Changes.Removals > 0 then
		local str = ""
		for i=1, #Changes.Removals do 
			str = str.."• "..Changes.Removals[i].."\n"
		end
		table.insert(DiscordEmbed[1].fields, {name = "Removals", value = str})
	end
	if #Changes.Modifications > 0 then
		local str = ""
		for i=1, #Changes.Modifications do 
			str = str.."• "..Changes.Modifications[i].."\n"
		end
		table.insert(DiscordEmbed[1].fields, {name = "Modifications", value = str})
	end
	if #Changes.Misc > 0 then
		local str = ""
		for i=1, #Changes.Misc do 
			str = str.."• "..Changes.Misc[i].."\n"
		end
		table.insert(DiscordEmbed[1].fields, {name = "Misc", value = str})
	end


	PerformHttpRequest(Config.Webhook, function(errorCode, resultData, resultHeaders) end, "POST", json.encode({embeds = DiscordEmbed}), {["Content-Type"] = "application/json"})

	--Create a .txt file containing the now to be previous changelog
	OldChangelog = io.open("resources/"..GetCurrentResourceName().."/"..Config.FileName, "r")
	OldChangelogStr = OldChangelog:read("*a")
	text = OldChangelogStr
	OldChangelog:close()

	ChangelogDump = io.open("resources/"..GetCurrentResourceName().."/"..Config.DumpFolderName.."/Changelog"..Changelog.Version.."_"..GetDate()..".txt", "w")
	ChangelogDump:write(text)
	ChangelogDump:close()

	-- Now we've done the changelog, its time to change the ver so it doesnt repeatably send

	Changelog.DO_NOT_CHANGE_VER = Changelog.Version
	SaveResourceFile(GetCurrentResourceName(), Config.FileName, json.encode(Changelog, {indent = true}), -1)
	print("^2Changed Config Version!^7")
end)
