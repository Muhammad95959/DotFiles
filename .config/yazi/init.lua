Status:children_add(function()
	local h = cx.active.current.hovered
	if not h or ya.target_family() ~= "unix" then
		return ""
	end

	return ui.Line {
		ui.Span(ya.user_name(h.cha.uid) or tostring(h.cha.uid)):fg("magenta"),
		":",
		ui.Span(ya.group_name(h.cha.gid) or tostring(h.cha.gid)):fg("magenta"),
		" ",
	}
end, 500, Status.RIGHT)

require("zoxide"):setup { update_db = true }

require("relative-motions"):setup({ show_numbers = "relative_absolute", show_motion = true })

require("bookmarks"):setup({
	last_directory = { enable = true, persist = true },
	persist = "all",
	desc_format = "parent",
	file_pick_mode = "parent",
	notify = {
		enable = true,
		timeout = 1,
		message = {
			new = "New bookmark '<key>' -> '<folder>'",
			delete = "Deleted bookmark in '<key>'",
			delete_all = "Deleted all bookmarks",
		},
	},
})

require("full-border"):setup({
	-- Available values: ui.Border.PLAIN, ui.Border.ROUNDED
	type = ui.Border.ROUNDED,
})

require("smart-enter"):setup({
	open_multi = true,
})

require("simple-tag"):setup({
  ui_mode = "icon",
  hints_disabled = false,
  linemode_order = 500,
  colors = {
	  reversed = true,
    ["1"] = "",
    ["2"] = "yellow",
    ["3"] = "red",
	  ["$"] = "green",
    ["*"] = "magenta",
  },
  icons = {
    ["1"] = " ",
		["2"] = "󰚋 ",
    ["3"] = " ",
    ["$"] = " ",
		["*"] = "* ",
  },

})

require("git"):setup()
