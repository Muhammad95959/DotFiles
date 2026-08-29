local start_time = nil
local mp = mp
local utils = require("mp.utils")

local function mark_start()
	start_time = mp.get_property_number("time-pos")
	mp.osd_message(string.format("Start marked: %.2fs", start_time))
end

local function mark_end()
	local end_time = mp.get_property_number("time-pos")
	local path = mp.get_property("path")

	if not start_time then
		mp.osd_message("No start time marked (press c first)")
		return
	end
	if end_time <= start_time then
		mp.osd_message("End time must be after start time")
		return
	end
	if not path then
		mp.osd_message("No file loaded")
		return
	end

	local dir, filename = utils.split_path(path)
	local ext = filename:match("%.%w+$") or ".mp4"
	ext = ext:lower()
	local name = filename:gsub("%.%w+$", "")
	local out = utils.join_path(dir, name .. "_clip_" .. os.time() .. ext)

	mp.osd_message("Exporting clip...", 9999) -- stays until replaced

	local vcodec, acodec
	if ext == ".webm" then
		vcodec = { "-c:v", "libvpx-vp9", "-crf", "30", "-b:v", "0" }
		acodec = { "-c:a", "libopus" }
	elseif ext == ".mp3" then
		vcodec = {}
		acodec = { "-c:a", "libmp3lame", "-q:a", "2" }
	elseif ext == ".m4a" or ext == ".aac" then
		vcodec = {}
		acodec = { "-c:a", "aac", "-b:a", "192k" }
	elseif ext == ".opus" then
		vcodec = {}
		acodec = { "-c:a", "libopus", "-b:a", "128k" }
	elseif ext == ".ogg" or ext == ".oga" then
		vcodec = {}
		acodec = { "-c:a", "libvorbis", "-q:a", "5" }
	elseif ext == ".flac" then
		vcodec = {}
		acodec = { "-c:a", "flac" }
	elseif ext == ".wav" then
		vcodec = {}
		acodec = { "-c:a", "pcm_s16le" }
	elseif ext == ".mp4" or ext == ".m4v" or ext == ".mov" then
		vcodec = { "-c:v", "libx264", "-crf", "18", "-preset", "veryfast" }
		acodec = { "-c:a", "aac" }
	else
		-- mkv, avi etc support h264+aac fine; mkv is most flexible
		vcodec = { "-c:v", "libx264", "-crf", "18", "-preset", "veryfast" }
		acodec = { "-c:a", "aac" }
	end

	local args = {
		"ffmpeg",
		"-y",
		"-ss",
		string.format("%.3f", start_time),
		"-to",
		string.format("%.3f", end_time),
		"-i",
		path,
	}
	for _, v in ipairs(vcodec) do
		table.insert(args, v)
	end
	for _, v in ipairs(acodec) do
		table.insert(args, v)
	end
	table.insert(args, "-avoid_negative_ts")
	table.insert(args, "make_zero")
	table.insert(args, out)

	mp.command_native_async({
		name = "subprocess",
		args = args,
		capture_stderr = true,
		playback_only = false, -- keeps running if playback ends
	}, function(success, result, err)
		if not success then
			mp.osd_message("Process error: " .. (err or "unknown"), 5)
		elseif result.status ~= 0 then
			local msg = (result.stderr or ""):match("([^\n]+)$") or "unknown"
			mp.osd_message("ffmpeg failed: " .. msg, 5)
		else
			start_time = nil -- only clear on success
			mp.osd_message("Saved: " .. out, 5)
		end
	end)
end

mp.add_key_binding("c", "mark_start", mark_start)
mp.add_key_binding("C", "mark_end", mark_end)
