---------------
---- DEBUG ----
---------------

hl.config({
  debug = {
    disable_logs  = false,
    error_position = 1,
    -- suppress_errors = true,
  },
})

------------------
---- MONITORS ----
------------------

hl.monitor({ output = "eDP-1", mode = "1920x1080@60", position = "auto", scale = 1 })
hl.monitor({ output = "HDMI-A-1", mirror = "eDP-1" })

----------------------
---- MY VARIABLES ----
----------------------

local mod = "SUPER"

local reset         = "hyprctl dispatch 'hl.dsp.submap(\"reset\")' && "
local unmute        = "wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 && "
local brightnessGet = "$(brightnessctl info | awk -F '[%(]' '/%/ {print $2}')"

local scratchpad_window    = nil
local last_tiled_window    = {}
local last_floating_window = {}
local wshowkeys_active     = false
local smart_gaps           = true

-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
  hl.exec_cmd("mako")
  hl.exec_cmd("waybar")
  hl.exec_cmd("udiskie")
  hl.exec_cmd("hypridle")
  hl.exec_cmd("awww-daemon")
  hl.exec_cmd("nwg-drawer -r")
  hl.exec_cmd("swayosd-server")
  hl.exec_cmd("xhost +si:localuser:$USER")
  hl.exec_cmd("sleep 1 && /usr/bin/albert")
  hl.exec_cmd("~/Scripts/backup_zsh_history.sh")
  hl.exec_cmd("wl-clip-persist --clipboard regular")
  hl.exec_cmd("wl-paste --type text --watch cliphist store")
  hl.exec_cmd("wl-paste --type image --watch cliphist store")
  hl.exec_cmd('pactl set-source-volume "rnnoise_source" 100%')
  hl.exec_cmd("python ~/Scripts/panel_shadow/panel-shadow.py")
  hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
  hl.exec_cmd("pactl set-source-volume alsa_input.pci-0000_00_1f.3.analog-stereo 30%")
  hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
  hl.exec_cmd("brave-origin --test-type --app=file:///home/muhammad/Projects/new-tab-page/index.html")
  hl.exec_cmd("aria2c -d '/home/muhammad/Downloads' --enable-rpc --rpc-listen-all --rpc-allow-origin-all --rpc-listen-port=6800")
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_THEME",                "Dracula-cursors")
hl.env("XCURSOR_SIZE",                 "24")
hl.env("HYPRCURSOR_THEME",             "hyprcursor_Dracula")
hl.env("HYPRCURSOR_SIZE",              "24")

hl.env("QT_QPA_PLATFORMTHEME",         "qt5ct")
hl.env("QT_QPA_PLATFORM",              "wayland")
hl.env("GTK_THEME",                    "Tokyonight-Dark")

hl.env("LIBVA_DRIVER_NAME",            "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME",    "nvidia")
hl.env("NVD_BACKEND",                  "direct")
hl.env("XDG_SESSION_TYPE",             "wayland")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
  general = {
    layout           = "master",
    gaps_in          = 4,
    gaps_out         = 8,
    border_size      = 2,
    resize_on_border = false,
    allow_tearing    = false,
    col = {
      active_border   = "rgba(C0CAF5EE)",
      inactive_border = "rgba(595959EE)",
    },
  },

  decoration = {
    rounding         = 4,
    active_opacity   = 1.0,
    inactive_opacity = 1.0,
    shadow = {
      enabled      = false,
      range        = 4,
      render_power = 3,
      color        = "rgba(1A1A1AEE)",
    },
    blur = {
      enabled = true,
    },
  },

  animations = {
    enabled = true,
  },

  dwindle = {
    force_split                  = 2,
    preserve_split               = true,
    permanent_direction_override = true,
  },

  master = {
    mfact      = 0.5,
    new_on_top = true,
    new_status = "master",
  },

  group = {
    col = {
      border_active   = "rgba(C0CAF5EE)",
      border_inactive = "rgba(595959AA)",
    },
    groupbar = {
      gradients         = true,
      gradient_rounding = 4,
      indicator_gap     = 1,
      indicator_height  = 0,
      font_size         = 10,
      text_color        = 0xff24273a,
      col = {
        active          = "rgba(C0CAF5EE)",
        inactive        = "rgba(595959AA)",
        locked_active   = "rgba(E9E9EAEE)",
        locked_inactive = "rgba(595959AA)",
      },
    },
  },

  misc = {
    disable_hyprland_logo      = true,
    enable_anr_dialog          = false,
    enable_swallow             = true,
    initial_workspace_tracking = 0,
    layers_hog_keyboard_focus  = false,
    swallow_exception_regex    = "^(.*)(Yazi|nvim|tmux|gopreload)(.*)$",
    swallow_regex              = "^(kitty)$",
  },

  cursor = {
    no_hardware_cursors = 2,
    hotspot_padding     = 2,
    no_warps            = true,
    inactive_timeout    = 5,
  },

  input = {
    kb_layout                   = "us,eg",
    kb_options                  = "lv3:ralt_alt,grp:alt_shift_toggle",
    follow_mouse                = 2,
    float_switch_override_focus = 0,
    sensitivity                 = 0.6,
    repeat_delay                = 240,
    repeat_rate                 = 42,
    touchpad = {
      natural_scroll = true,
      scroll_factor  = 3,
    },
  },
})

-- Animations
hl.curve("easeOut",   { type = "bezier", points = { {0.46, 1.0}, {0.29, 1} } })
hl.curve("easeClose", { type = "bezier", points = { {0.08, 0.92}, {0, 1}   } })

hl.animation({ leaf = "windows",    enabled = true, speed = 3, bezier = "easeOut",   style = "slide" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 6, bezier = "easeClose", style = "slide" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2, bezier = "default",   style = "fade" })
hl.animation({ leaf = "layers",     enabled = true, speed = 2, bezier = "default",   style = "fade" })
hl.animation({ leaf = "layersOut",  enabled = true, speed = 2, bezier = "default",   style = "fade" })
hl.animation({ leaf = "border",     enabled = true, speed = 2, bezier = "easeOut" })
hl.animation({ leaf = "fade",       enabled = true, speed = 2, bezier = "easeOut" })

-- Gesture
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

------------------------------
---- WINDOWS & WORKSPACES ----
------------------------------

hl.window_rule({
  name  = "suppress-maximize-events",
  match = { class = ".*" },
  suppress_event = "maximize",
})

hl.window_rule({
  name  = "fix-xwayland-drags",
  match = {
    class      = "^$",
    title      = "^$",
    xwayland   = true,
    float      = true,
    fullscreen = false,
    pin        = false,
  },
  no_focus = true,
})

hl.window_rule({
  name  = "move-hyprland-run",
  match = { class = "hyprland-run" },
  move  = "20 monitor_h-120",
  float = true,
})

-- Smart gaps (ignoring special workspaces)
hl.workspace_rule({ workspace = "w[tv1]s[false]", gaps_out = 0, gaps_in = 0 })
hl.workspace_rule({ workspace = "f[1]s[false]", gaps_out = 0, gaps_in = 0 })
hl.window_rule({ match = { float = false, workspace = "w[tv1]s[false]" }, border_size = 0 })
hl.window_rule({ match = { float = false, workspace = "w[tv1]s[false]" }, rounding = 0 })
hl.window_rule({ match = { float = false, workspace = "f[1]s[false]" }, border_size = 0 })
hl.window_rule({ match = { float = false, workspace = "f[1]s[false]" }, rounding = 0 })

-- General window rules
hl.window_rule({ match = { class = ".*" }, no_blur = true })
hl.window_rule({ match = { float = true }, animation = "fade" })

hl.window_rule({ match = { class = "^arandr$" }, float = true })
hl.window_rule({ match = { class = "^timeshift-gtk$" }, float = true })
hl.window_rule({ match = { class = "^nl.hjdskes.gcolor3$" }, float = true })
hl.window_rule({ match = { class = "^nl%.hjdskes%.gcolor3$" }, float = true })
hl.window_rule({ match = { class = "^hyprland-share-picker$" }, float = true })
hl.window_rule({ match = { class = "^thunar$", title = "^Rename.*$" }, float = true })
hl.window_rule({ match = { class = "^thunar$", title = "^File Operation Progress$" }, float = true })

hl.window_rule({ match = { class = "^com-jetbrains-toolbox-entry-ToolboxEntry$" }, tile = true })
hl.window_rule({ match = { title = "^WhatsApp Web$" }, tile = true })

hl.window_rule({ match = { class = "^yt-dlp$" }, workspace = 9 })
hl.window_rule({ match = { title = "^meet.google.com is sharing your screen.$" }, workspace = "9 silent" })
hl.window_rule({ match = { class = "^brave-__home_muhammad_Projects_new-tab-page_index.html-Default$" }, workspace = "special:hidden silent" })
hl.window_rule({ match = { class = "^chrome-__home_muhammad_Projects_new-tab-page_index.html-Default$" }, workspace = "special:hidden silent" })

hl.window_rule({ match = { title = "^Albert$" }, float = true, border_size = 0 })
hl.window_rule({ match = { class = "^flameshot$" }, float = true, border_size = 0 })
hl.window_rule({ match = { class = "^octave-cli.*$" }, float = true, size = "1600 900" })
hl.window_rule({ match = { class = "^xdg-desktop-portal-gtk$" }, float = true, size = "960 600" })
hl.window_rule({ match = { class = "^net%.sapples%.LiveCaptions$" }, float = true, move = "500 900" })
hl.window_rule({ match = { class = "^Waydroid$" }, float = true, size = "468 1014", move = "1428 45" })
hl.window_rule({ match = { class = "^termfilechooser$" }, float = true, center = true, size = "1280 720" })
hl.window_rule({ match = { class = "^hiddenkitty.*$" }, float = true, no_initial_focus = true, move = "3000 3000" })
hl.window_rule({ match = { class = "^org%.telegram%.desktop$", title = "^Media viewer$" }, float = true, fullscreen = true })
hl.window_rule({ match = { class = "^explorer.exe$", title = "^WineDesktop - Wine Desktop$" }, float = true, center = true })
hl.window_rule({ match = { class = "^brave-translate.google.com.eg__-Default$" }, float = true, size = "740 960", opacity = 0.8 })
hl.window_rule({ match = { class = "^chrome-translate.google.com.eg__-Default$" }, float = true, size = "740 960", opacity = 0.8 })

-- Layer rules
hl.layer_rule({ match = { namespace = "nwg-drawer" },   blur = true })
hl.layer_rule({ match = { namespace = "logout_dialog" }, blur = true })
hl.layer_rule({ match = { namespace = "waybar" },        blur = true })

-------------------
---- FUNCTIONS ----
-------------------

local function roalbert()
  local w = hl.get_active_window()
  if w ~= nil and w.title == "Albert" then
    hl.dispatch(hl.dsp.exec_cmd("rofi -show drun -theme ~/.config/rofi/launcher.rasi"))
  else
    hl.dispatch(hl.dsp.exec_cmd("/usr/bin/albert toggle || /usr/bin/albert"))
  end
end

local function wshowkeys()
  if wshowkeys_active then
    wshowkeys_active = false
    hl.dispatch(hl.dsp.exec_cmd("killall wshowkeys"))
    hl.dispatch(hl.dsp.exec_cmd("notify-send -t 1500 'wshowkeys' '󱎘   Disabled'"))
  else
    wshowkeys_active = true
    hl.dispatch(hl.dsp.exec_cmd("killall wshowkeys; wshowkeys -a bottom -t 1000 -f '#e1e2e7ff' -b '#1a1b26aa'"))
    hl.dispatch(hl.dsp.exec_cmd("notify-send -t 1500 'wshowkeys' '   Enabled'"))
  end
end

local function brave_translate()
  local w = hl.get_active_window()
  if w ~= nil and (w.class == "brave-translate.google.com.eg__-Default" or w.class == "chrome-translate.google.com.eg__-Default") then
    hl.exec_cmd("hyprminimizer minimize " .. w.address)
  else
    local found = false
    local ws = hl.get_active_workspace()
    for _, win in ipairs(hl.get_windows()) do
      if win.class == "brave-translate.google.com.eg__-Default" or win.class == "chrome-translate.google.com.eg__-Default" then
        found = true
        hl.dispatch(hl.dsp.window.move({ workspace = ws, window = win, follow = true }))
        hl.dispatch(hl.dsp.window.bring_to_top({ window = win }))
        hl.dispatch(hl.dsp.focus({ window = win }))
        break
      end
    end
    if not found then
      hl.exec_cmd("~/Scripts/brave_translate.sh")
    end
    hl.exec_cmd("hyprminimizer cleanup")
  end
end

local function waydroid()
  local handle = io.popen("waydroid status 2>/dev/null")
  if not handle then
    hl.exec_cmd("notify-send 'waydroid' 'failed to run waydroid status'")
    return
  end
  local output = handle:read("*a")
  handle:close()
  local session_running = output ~= nil and output:match("Session:%s*RUNNING") ~= nil
  if session_running then
    hl.exec_cmd("waydroid session stop")
    hl.exec_cmd("notify-send 'waydroid' 'session stopped'")
    return
  end
  hl.exec_cmd("waydroid session start")
  hl.exec_cmd([[sh -c '
    notify-send -r 91231 -t 10000 "waydroid" "starting session..."
    for i in $(seq 1 10); do
      if waydroid status 2>/dev/null | grep -q "Session:.*RUNNING"; then
        waydroid show-full-ui &
        exit 0
      fi
      sleep 1
    done
    notify-send -r 91231 -t 3000 "waydroid" "session did not start within 10s"
  ' &]])
end

local function move_window(direction)
  local w = hl.get_active_window()
  if w == nil then return end
  if w.floating then
    local dirs = {
      l = { x = -20, y = 0 },
      r = { x = 20,  y = 0 },
      u = { x = 0,   y = -20 },
      d = { x = 0,   y = 20 },
    }
    local d = dirs[direction]
    hl.dispatch(hl.dsp.window.move({ x = d.x, y = d.y, relative = true }))
  else
    hl.dispatch(hl.dsp.window.move({ direction = direction, group_aware = true }))
  end
end

local function restore_minimized()
  local minimized = {}
  for _, win in ipairs(hl.get_windows()) do
    if win.workspace ~= nil and win.workspace.name == "special:minimized" then
      table.insert(minimized, win)
    end
  end
  if #minimized > 1 then
    hl.dispatch(hl.dsp.exec_cmd("hyprminimizer menu"))
  else
    hl.dispatch(hl.dsp.exec_cmd("hyprminimizer restore-last"))
  end
end

local function set_gaps(delta)
  local gaps_out = hl.get_config("general.gaps_out")
  local current_out = gaps_out.top or gaps_out
  local new_out = math.max(0, current_out + delta)
  local new_in = math.max(0, math.floor(new_out / 2))
  hl.config({
    general = {
      gaps_in = new_in,
      gaps_out = new_out,
    }
  })
end

local function toggle_gaps()
  local gaps_out = hl.get_config("general.gaps_out")
  local current_out = gaps_out.top or gaps_out
  local current_in = hl.get_config("general.gaps_in")
  local current_in_val = current_in.top or current_in
  if current_out > 0 or current_in_val > 0 then
    hl.config({
      general = {
        gaps_in = 0,
        gaps_out = 0,
      }
    })
  else
    hl.config({
      general = {
        gaps_in = 4,
        gaps_out = 8,
      }
    })
  end
end

local function toggle_smart_gaps()
  smart_gaps = not smart_gaps
  if smart_gaps then
    hl.workspace_rule({ workspace = "w[tv1]s[false]", gaps_out = 0, gaps_in = 0 })
    hl.workspace_rule({ workspace = "f[1]s[false]",   gaps_out = 0, gaps_in = 0 })
    hl.window_rule({ match = { float = false, workspace = "w[tv1]s[false]" }, border_size = 0, rounding = 0 })
    hl.window_rule({ match = { float = false, workspace = "f[1]s[false]"   }, border_size = 0, rounding = 0 })
  else
    hl.workspace_rule({ workspace = "w[tv1]s[false]", gaps_out = 8, gaps_in = 4 })
    hl.workspace_rule({ workspace = "f[1]s[false]",   gaps_out = 8, gaps_in = 4 })
    hl.window_rule({ match = { float = false, workspace = "w[tv1]s[false]" }, border_size = 2, rounding = 4 })
    hl.window_rule({ match = { float = false, workspace = "f[1]s[false]"   }, border_size = 2, rounding = 4 })
  end
end

local function toggle_floating()
  local w = hl.get_active_window()
  if scratchpad_window == w then scratchpad_window = nil end
  hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
  w = hl.get_active_window()
  if w == nil or not w.floating then return end
  hl.dispatch(hl.dsp.window.center())
  hl.dispatch(hl.dsp.window.bring_to_top())
  local resizeClasses = { kitty = true, helium = true, ["brave-origin"] = true }
  if resizeClasses[w.class] then
    hl.dispatch(hl.dsp.window.resize({ x = 1600, y = 900, relative = false }))
    hl.dispatch(hl.dsp.window.center())
  end
end

local function toggle_focus_float()
  local function is_window_valid(saved, floating)
    if saved == nil then return false end
    for _, win in ipairs(hl.get_windows()) do
      if win.address == saved.address then
        return win.floating == floating
      end
    end
    return false
  end
  local w = hl.get_active_window()
  if w == nil then return end
  local ws = hl.get_active_workspace()
  if ws == nil or ws.id < 0 then return end
  local id = ws.id
  if w.floating then
    last_floating_window[id] = w
    if is_window_valid(last_tiled_window[id], false) then
      hl.dispatch(hl.dsp.focus({ window = last_tiled_window[id] }))
    else
      last_tiled_window[id] = nil
      hl.dispatch(hl.dsp.focus({ window = "tiled" }))
    end
  else
    last_tiled_window[id] = w
    if is_window_valid(last_floating_window[id], true) then
      hl.dispatch(hl.dsp.focus({ window = last_floating_window[id] }))
    else
      last_floating_window[id] = nil
      hl.dispatch(hl.dsp.focus({ window = "floating" }))
    end
    hl.dispatch(hl.dsp.window.bring_to_top())
  end
end

local function scratchpad()
  local SCRATCH_WIDTH = 1600
  local SCRATCH_HEIGHT = 900
  local w = hl.get_active_window()
  -- check if saved window still exists
  if scratchpad_window ~= nil then
    local exists = false
    for _, win in ipairs(hl.get_windows()) do
      if win.address == scratchpad_window.address then
        exists = true
        break
      end
    end
    if not exists then
      scratchpad_window = nil
    end
  end
  if scratchpad_window ~= nil then
    if w ~= nil and w.address == scratchpad_window.address then
      -- current window is scratchpad, toggle away
      hl.dispatch(hl.dsp.window.move({ workspace = "special:scratchpad", follow = false }))
    else
      -- pull into current workspace
      local ws = hl.get_active_workspace()
      if ws == nil or ws.id < 0 then return end
      hl.dispatch(hl.dsp.window.move({ workspace = ws.id, window = scratchpad_window, follow = false }))
      hl.dispatch(hl.dsp.focus({ window = scratchpad_window }))
      hl.dispatch(hl.dsp.window.bring_to_top())
    end
    return
  end
  -- no tracked scratchpad; check for any windows in special:scratchpad
  local ws = hl.get_active_workspace()
  if ws ~= nil and ws.id >= 0 then
    local orphans = {}
    for _, win in ipairs(hl.get_windows()) do
      if win.workspace ~= nil and win.workspace.name == "special:scratchpad" then
        table.insert(orphans, win)
      end
    end
    if #orphans > 0 then
      for _, win in ipairs(orphans) do
        hl.dispatch(hl.dsp.window.move({ workspace = ws.id, window = win, follow = false }))
      end
      hl.dispatch(hl.dsp.focus({ window = orphans[#orphans] }))
      return
    end
  end
  -- no scratchpad, promote active window
  if w == nil then return end
  if not w.floating then
    hl.dispatch(hl.dsp.window.float({ action = "set" }))
    hl.dispatch(hl.dsp.window.resize({ x = SCRATCH_WIDTH, y = SCRATCH_HEIGHT, relative = false }))
    hl.dispatch(hl.dsp.window.center())
  end
  scratchpad_window = w
  hl.dispatch(hl.dsp.window.move({ workspace = "special:scratchpad", follow = false }))
end

-----------------
---- SUBMAPS ----
-----------------

-- Passthrough submap
hl.define_submap("passthrough", function()
  hl.bind(mod .. " + CTRL + q", hl.dsp.submap("reset"))
end)

-- Hyprsunset submap
hl.define_submap("hyprsunset", function()
  local temps = { ["1"]=5000, ["2"]=4000, ["3"]=3500, ["4"]=3000, ["5"]=2500,
                  ["6"]=2000, ["7"]=1750, ["8"]=1500, ["9"]=1250, ["0"]=1000 }
  for key, temp in pairs(temps) do
      hl.bind(key, hl.dsp.exec_cmd(reset .. "killall hyprsunset; sleep 0.1; hyprsunset -t " .. temp))
  end
  hl.bind("r", hl.dsp.exec_cmd(reset .. "killall hyprsunset"))

  hl.bind("ESCAPE",             hl.dsp.submap("reset"))
  hl.bind(mod .. " + CTRL + q", hl.dsp.submap("reset"))
end)

-- Apps submap
hl.define_submap("apps", function()
  hl.bind("a", hl.dsp.exec_cmd(reset .. "audacious"))
  hl.bind("b", hl.dsp.exec_cmd(reset .. "/usr/bin/brave-origin --test-type --incognito"))
  hl.bind("c", hl.dsp.exec_cmd(reset .. "qalculate-gtk"))
  hl.bind("h", hl.dsp.exec_cmd(reset .. "kitty --hold -e nvim ~/.config/hypr/hyprland.lua"))
  hl.bind("k", hl.dsp.exec_cmd(reset .. "prime-run kdenlive"))
  hl.bind("l", hl.dsp.exec_cmd(reset .. "flatpak run net.sapples.LiveCaptions"))
  hl.bind("m", hl.dsp.exec_cmd(reset .. "mpv --player-operation-mode=pseudo-gui"))
  hl.bind("n", hl.dsp.exec_cmd(reset .. "kitty --class nvim --hold -e nvim"))
  hl.bind("o", hl.dsp.exec_cmd(reset .. "kitty -o font_size=18 --class octave-cli --hold -e octave-cli --silent"))
  hl.bind("q", hl.dsp.exec_cmd(reset .. "flatpak run io.github._0xzer0x.qurancompanion"))
  hl.bind("s", hl.dsp.exec_cmd(reset .. "libreoffice /mnt/Disk_D/Muhammad/swears.odt"))
  hl.bind("t", hl.dsp.exec_cmd(reset .. "telegram-desktop"))
  hl.bind("w", hl.dsp.exec_cmd(reset .. "/usr/bin/brave-origin --test-type --app-id=hnpfjngllnobngcgfapefoaidbinmjnm"))
  hl.bind("SHIFT + b", hl.dsp.exec_cmd(reset .. "notify-send -t 5000 \"$(acpi)\""))
  hl.bind("SHIFT + c", hl.dsp.exec_cmd(reset .. "hyprpicker -a"))
  hl.bind("SHIFT + k", wshowkeys) hl.bind("SHIFT + k", hl.dsp.submap("reset"))
  hl.bind("SHIFT + m", hl.dsp.exec_cmd(reset .. "kitty --class pulsemixer --hold -e pulsemixer"))
  hl.bind("SHIFT + n", hl.dsp.exec_cmd(reset .. "~/Scripts/wallpaper.sh"))
  hl.bind("SHIFT + s", hl.dsp.exec_cmd(reset .. "notify-send -t 30000 \"$(~/Scripts/bilal.sh -a)\""))
  hl.bind("SHIFT + t", hl.dsp.exec_cmd(reset .. "blanket"))

  hl.bind("ESCAPE",             hl.dsp.submap("reset"))
  hl.bind(mod .. " + CTRL + q", hl.dsp.submap("reset"))
end)

-- Scripts submap
hl.define_submap("scripts", function()
  hl.bind("c", hl.dsp.exec_cmd(reset .. "~/Scripts/hyprland_move_to_corners.sh"))
  hl.bind("d", hl.dsp.exec_cmd(reset .. "~/Scripts/rofi_todo/todo.sh"))
  hl.bind("g", hl.dsp.exec_cmd(reset .. "~/Scripts/google_translate.sh"))
  hl.bind("h", hl.dsp.exec_cmd(reset .. "~/Scripts/brave_history.sh"))
  hl.bind("i", hl.dsp.exec_cmd(reset .. "~/Scripts/cliphist_rofi_img.sh"))
  hl.bind("k", hl.dsp.exec_cmd(reset .. "~/Scripts/app_kill.sh"))
  hl.bind("l", hl.dsp.exec_cmd(reset .. "~/Scripts/livewall.sh -f"))
  hl.bind("m", hl.dsp.exec_cmd(reset .. "~/Scripts/mpv_history.sh"))
  hl.bind("r", hl.dsp.exec_cmd(reset .. "~/Scripts/hyprland_resize.sh"))
  hl.bind("s", toggle_smart_gaps) hl.bind("s", hl.dsp.submap("reset"))
  hl.bind("v", hl.dsp.exec_cmd(reset .. "~/Scripts/virt_opener.sh"))
  hl.bind("w", hl.dsp.exec_cmd(reset .. "~/Scripts/brave_bookmarks.sh"))
  hl.bind("y", hl.dsp.exec_cmd(reset .. "kitty --class yt-dlp -e ~/Scripts/yt-dlp_script.sh"))
  hl.bind("z", hl.dsp.exec_cmd(reset .. "~/Scripts/zathura_history.sh"))
  hl.bind("SHIFT + l", hl.dsp.exec_cmd(reset .. "~/Scripts/livewall_select.sh"))
  hl.bind("SHIFT + m", hl.dsp.exec_cmd(reset .. "~/Scripts/url_to_mpv.sh"))

  hl.bind("ESCAPE",             hl.dsp.submap("reset"))
  hl.bind(mod .. " + CTRL + q", hl.dsp.submap("reset"))
end)

-- Mouse submap
hl.define_submap("mouse", function()
  hl.bind("a",         hl.dsp.exec_cmd(reset .. " wl-kbptr && hyprctl dispatch 'hl.dsp.submap(\"mouse\")'"))
  hl.bind("g",         hl.dsp.exec_cmd(reset .. " wl-kbptr -o modes=floating,click -o mode_floating.source=detect -o mode_floating.label_font_size='14 50% 100'"))
  hl.bind("SEMICOLON", hl.dsp.exec_cmd(reset .. " wl-kbptr -o modes=split && hyprctl dispatch 'hl.dsp.submap(\"mouse\")'"))

  hl.bind("h",           hl.dsp.exec_cmd("wlrctl pointer move -30  0"), { repeating = true })
  hl.bind("j",           hl.dsp.exec_cmd("wlrctl pointer move  0  30"), { repeating = true })
  hl.bind("k",           hl.dsp.exec_cmd("wlrctl pointer move  0 -30"), { repeating = true })
  hl.bind("l",           hl.dsp.exec_cmd("wlrctl pointer move  30  0"), { repeating = true })
  hl.bind(mod .. " + h", hl.dsp.exec_cmd("wlrctl pointer move -5  0"),  { repeating = true })
  hl.bind(mod .. " + j", hl.dsp.exec_cmd("wlrctl pointer move  0  5"),  { repeating = true })
  hl.bind(mod .. " + k", hl.dsp.exec_cmd("wlrctl pointer move  0 -5"),  { repeating = true })
  hl.bind(mod .. " + l", hl.dsp.exec_cmd("wlrctl pointer move  5  0"),  { repeating = true })
  hl.bind("SHIFT + h",   hl.dsp.exec_cmd("wlrctl pointer move -60  0"), { repeating = true })
  hl.bind("SHIFT + j",   hl.dsp.exec_cmd("wlrctl pointer move  0  60"), { repeating = true })
  hl.bind("SHIFT + k",   hl.dsp.exec_cmd("wlrctl pointer move  0 -60"), { repeating = true })
  hl.bind("SHIFT + l",   hl.dsp.exec_cmd("wlrctl pointer move  60  0"), { repeating = true })

  hl.bind("f", hl.dsp.exec_cmd("wlrctl pointer click left"),   { repeating = true })
  hl.bind("d", hl.dsp.exec_cmd("wlrctl pointer click middle"), { repeating = true })
  hl.bind("s", hl.dsp.exec_cmd("wlrctl pointer click right"),  { repeating = true })

  hl.bind("ALT + k", hl.dsp.exec_cmd("sudo ydotool mousemove -w -- 0  1"), { repeating = true }) -- wheel up
  hl.bind("ALT + j", hl.dsp.exec_cmd("sudo ydotool mousemove -w -- 0 -1"), { repeating = true }) -- wheel down

  hl.bind("1", hl.dsp.cursor.move({ x = 0,    y = 0 }))
  hl.bind("2", hl.dsp.cursor.move({ x = 1920, y = 0 }))
  hl.bind("3", hl.dsp.cursor.move({ x = 0,    y = 1080 }))
  hl.bind("4", hl.dsp.cursor.move({ x = 1920, y = 1080 }))
  hl.bind("5", hl.dsp.cursor.move({ x = 960,  y = 540 }))
  hl.bind("6", hl.dsp.cursor.move({ x = 480,  y = 270 }))
  hl.bind("7", hl.dsp.cursor.move({ x = 1440, y = 270 }))
  hl.bind("8", hl.dsp.cursor.move({ x = 480,  y = 810 }))
  hl.bind("9", hl.dsp.cursor.move({ x = 1440, y = 810 }))

  hl.bind(mod .. " + CTRL + q", hl.dsp.submap("reset"))
end)

---------------------
---- KEYBINDINGS ----
---------------------

-- General
hl.bind(mod .. " + RETURN",         hl.dsp.exec_cmd("kitty"))
hl.bind(mod .. " + SPACE",          toggle_focus_float)
hl.bind(mod .. " + COMMA",          hl.dsp.group.prev())
hl.bind(mod .. " + PERIOD",         hl.dsp.group.next())
hl.bind(mod .. " + a",              hl.dsp.submap("apps"))
hl.bind(mod .. " + b",              hl.dsp.exec_cmd("/usr/bin/brave-origin --test-type"))
hl.bind(mod .. " + c",              hl.dsp.exec_cmd("cliphist list | rofi -dmenu -i -p Clipboard: | cliphist decode | wl-copy"))
hl.bind(mod .. " + d",              hl.dsp.exec_cmd("hyprminimizer"))
hl.bind(mod .. " + e",              hl.dsp.group.lock_active())
hl.bind(mod .. " + f",              hl.dsp.window.fullscreen())
hl.bind(mod .. " + g",              function() set_gaps(10) end, { repeating = true })
hl.bind(mod .. " + i",              hl.dsp.exec_cmd([[rofimoji --action clipboard --selector-args="-theme ~/.config/rofi/emoji_dropdown.rasi -theme-str 'window {y-offset: -24px;}'"]]))
hl.bind(mod .. " + m",              hl.dsp.submap("mouse"))
hl.bind(mod .. " + n",              hl.dsp.submap("hyprsunset"))
hl.bind(mod .. " + o",              hl.dsp.submap("scripts"))
hl.bind(mod .. " + p",              hl.dsp.exec_cmd("rofi-pass"))
hl.bind(mod .. " + q",              hl.dsp.window.close())
hl.bind(mod .. " + r",              hl.dsp.exec_cmd("kitty --hold -e yazi"))
hl.bind(mod .. " + s",              scratchpad)
hl.bind(mod .. " + t",              brave_translate)
hl.bind(mod .. " + w",              hl.dsp.group.toggle())
hl.bind(mod .. " + y",              waydroid)

-- hl.bind(mod .. " + SHIFT + RETURN", hl.dsp.exec_cmd("/usr/bin/albert toggle || /usr/bin/albert"))
hl.bind(mod .. " + SHIFT + RETURN", roalbert)
hl.bind(mod .. " + SHIFT + SPACE",  toggle_floating)
hl.bind(mod .. " + SHIFT + COMMA",  hl.dsp.group.move_window({ forward = false }))
hl.bind(mod .. " + SHIFT + PERIOD", hl.dsp.group.move_window({ forward = true }))
hl.bind(mod .. " + SHIFT + c",      hl.dsp.exec_cmd("makoctl dismiss -a"))
hl.bind(mod .. " + SHIFT + d",      restore_minimized)
hl.bind(mod .. " + SHIFT + f",      toggle_gaps)
hl.bind(mod .. " + SHIFT + g",      function() set_gaps(-10) end, { repeating = true })
hl.bind(mod .. " + SHIFT + n",      hl.dsp.exec_cmd("rofi -modi nerdy -show nerdy -theme ~/.config/rofi/emoji_dropdown.rasi -theme-str 'window {y-offset: -24px;}'"))
hl.bind(mod .. " + SHIFT + p",      hl.dsp.exec_cmd("rofi -show window -theme-str 'window {y-offset: -24px;}'"))
hl.bind(mod .. " + SHIFT + q",      hl.dsp.exec_cmd("~/.config/rofi/scripts/powermenu/type-1/powermenu.sh"))
hl.bind(mod .. " + SHIFT + r",      hl.dsp.exec_cmd("hyprctl reload && killall waybar; waybar"))
hl.bind(mod .. " + SHIFT + t",      hl.dsp.exec_cmd("confetti"))
hl.bind(mod .. " + SHIFT + v",      hl.dsp.submap("passthrough"))
hl.bind(mod .. " + SHIFT + w",      hl.dsp.exec_cmd([[awww img "$(find "/mnt/Disk_D/Backgrounds" -maxdepth 1 -name '*.jpg' -o -name '*.png' | shuf -n1)" --transition-type "none" --transition-duration 0]]), { repeating = true })

hl.bind(mod .. " + CTRL + a",       hl.dsp.exec_cmd("~/Scripts/new_english.sh"))

-- Switch workspaces with mod + [1-9]
for i = 1, 9 do
  hl.bind(mod .. " + " .. i,         hl.dsp.focus({ workspace = i }))
  hl.bind(mod .. " + CTRL + " .. i,  hl.dsp.window.move({ workspace = i, follow = false }))
  hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end

-- Move focus
hl.bind(mod .. " + h", hl.dsp.focus({ direction = "left" }),  { repeating = true })
hl.bind(mod .. " + h", hl.dsp.window.bring_to_top(),          { repeating = true })
hl.bind(mod .. " + l", hl.dsp.focus({ direction = "right" }), { repeating = true })
hl.bind(mod .. " + l", hl.dsp.window.bring_to_top(),          { repeating = true })
hl.bind(mod .. " + j", hl.dsp.layout("cyclenext"),            { repeating = true })
hl.bind(mod .. " + k", hl.dsp.layout("cycleprev"),            { repeating = true })

-- Move windows
hl.bind(mod .. " + SHIFT + h", function() move_window("l") end, { repeating = true })
hl.bind(mod .. " + SHIFT + l", function() move_window("r") end, { repeating = true })
hl.bind(mod .. " + SHIFT + k", function() move_window("u") end, { repeating = true })
hl.bind(mod .. " + SHIFT + j", function() move_window("d") end, { repeating = true })

-- Resize windows
hl.bind(mod .. " + CTRL + h", hl.dsp.window.resize({ x = -50, y = 0, relative = true }), { repeating = true })
hl.bind(mod .. " + CTRL + l", hl.dsp.window.resize({ x = 50,  y = 0, relative = true }), { repeating = true })
hl.bind(mod .. " + CTRL + k", hl.dsp.window.resize({ x = 0, y = -50, relative = true }), { repeating = true })
hl.bind(mod .. " + CTRL + j", hl.dsp.window.resize({ x = 0, y = 50,  relative = true }), { repeating = true })

-- Volume controls
hl.bind("XF86AudioRaiseVolume",         hl.dsp.exec_cmd(unmute .. "swayosd-client --output-volume +5 --max-volume 150"),                            { repeating = true })
hl.bind("XF86AudioLowerVolume",         hl.dsp.exec_cmd(unmute .. "swayosd-client --output-volume -5 --max-volume 150"),                            { repeating = true })
hl.bind("SHIFT + XF86AudioRaiseVolume", hl.dsp.exec_cmd(unmute .. "swayosd-client --output-volume +1 --max-volume 150"),                            { repeating = true })
hl.bind("SHIFT + XF86AudioLowerVolume", hl.dsp.exec_cmd(unmute .. "swayosd-client --output-volume -1 --max-volume 150"),                            { repeating = true })
hl.bind("XF86AudioMute",                hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle --max-volume 150"),                             { repeating = true })
hl.bind("XF86AudioMicMute",             hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle; swayosd-client --input-volume mute-toggle"), { repeating = true })

-- Brightness controls
hl.bind("XF86MonBrightnessUp",           hl.dsp.exec_cmd("swayosd-client --brightness $(( " .. brightnessGet .. " + 5 ))"), { repeating = true })
hl.bind("XF86MonBrightnessDown",         hl.dsp.exec_cmd("swayosd-client --brightness $(( " .. brightnessGet .. " - 5 ))"), { repeating = true })
hl.bind("SHIFT + XF86MonBrightnessUp",   hl.dsp.exec_cmd("swayosd-client --brightness $(( " .. brightnessGet .. " + 1 ))"), { repeating = true })
hl.bind("SHIFT + XF86MonBrightnessDown", hl.dsp.exec_cmd("swayosd-client --brightness $(( " .. brightnessGet .. " - 1 ))"), { repeating = true })

-- Media player controls
hl.bind("XF86AudioPlay",         hl.dsp.exec_cmd("playerctl play-pause"),  { repeating = true })
hl.bind("XF86AudioPause",        hl.dsp.exec_cmd("playerctl play-pause"),  { repeating = true })
hl.bind("XF86AudioNext",         hl.dsp.exec_cmd("playerctl position 5+"), { repeating = true })
hl.bind("XF86AudioPrev",         hl.dsp.exec_cmd("playerctl position 5-"), { repeating = true })
hl.bind("SHIFT + XF86AudioNext", hl.dsp.exec_cmd("playerctl next"),        { repeating = true })
hl.bind("SHIFT + XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"),    { repeating = true })

-- Screenshots
hl.bind("Print",         hl.dsp.exec_cmd("flameshot gui"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("flameshot gui --region 1920x1080+0+0"))
hl.bind("CTRL + Print",  hl.dsp.exec_cmd("~/Scripts/flameshotwindows.sh"))

-- Mouse workspace scroll
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mouse
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Lid switch
hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("hyprlock"), { locked = true })
