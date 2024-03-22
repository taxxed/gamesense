local get_classname = entity.get_classname
local get_local_player = entity.get_local_player
local entity_get_all = entity.get_all
local entity_get_prop = entity.get_prop
local entity_get_player_weapon = entity.get_player_weapon
local entity_is_alive = entity.is_alive
local string_format = string.format
local min, abs, sqrt, floor = math.min, math.abs, math.sqrt, math.floor
local ui_get, ui_set = ui.get, ui.set
local ui_is_menu_open = ui.is_menu_open
local draw_text = renderer.text
local draw_indicator = renderer.indicator
local ui_set_visible = ui.set_visible
local client_draw_hitboxes = client.draw_hitboxes
local client_trace_line = client.trace_line
local client_trace_bullet = client.trace_bullet
local client_scale_damage = client.scale_damage
local client_set_event_callback = client.set_event_callback
local client_userid_to_entindex = client.userid_to_entindex
local entity_hitbox_position = entity.hitbox_position
local entity_get_players = entity.get_players
local renderer_circle = renderer.circle
local renderer_world_to_screen = renderer.world_to_screen
local renderer_line = renderer.line
local renderer_rectangle = renderer.rectangle
local renderer_circle_outline = renderer.circle_outline
local entity_get_player_name = entity.get_player_name
local client_color_log = client.color_log
local table_concat = table.concat
local string_gsub, string_len, string_sub, string_upper = string.gsub, string.len, string.sub, string.upper
local client_exec = client.exec
local ui_set_callback = ui.set_callback
local math_max, math_min, math_floor, math_random = math.max, math.min, math.floor, math.random
local globals_realtime, globals_absoluteframetime, globals_tickinterval = globals.realtime, globals.absoluteframetime, globals.tickinterval
local table_insert, table_remove = table.insert, table.remove
local client_latency = client.latency
local entity_get_bounding_box = entity.get_bounding_box
local client_visible = client.visible
local client_eye_position = client.eye_position
local client_timestamp = client.timestamp
local unpack = table.unpack
local plist_set = plist.set
local surface = require 'gamesense/surface'
local ffi = require 'ffi'

---------------------------------
-- foreign function interface
---------------------------------
local veclient = client.create_interface('engine.dll', 'VEngineClient014')
local ivengineclient = ffi.cast(ffi.typeof('void***'), veclient)
local is_voice_recording = ffi.cast(ffi.typeof('bool(__thiscall*)(void*)'), ivengineclient[0][224])

---------------------------------
-- references
---------------------------------
local aimbot, aimbotmode = ui.reference("RAGE", "Aimbot", "Enabled")
local a = ui.reference("RAGE", "Aimbot", "Target selection")
local b = ui.reference("RAGE", "Aimbot", "Target hitbox")
local e = ui.reference("RAGE", "Aimbot", "Multi-point")
local f = ui.reference("RAGE", "Aimbot", "Multi-point scale")
local i = ui.reference("RAGE", "other", "Automatic Fire")
local j = ui.reference("RAGE", "other", "Automatic Penetration")
local k = ui.reference("RAGE", "other", "Silent Aim")
local l = ui.reference("RAGE", "Aimbot", "Minimum hit chance")
local m = ui.reference("RAGE", "Aimbot", "Minimum damage")
local o = ui.reference("RAGE", "Aimbot", "Automatic Scope")
local q = ui.reference("RAGE", "other", "Reduce aim step")
local r = ui.reference("RAGE", "other", "Maximum FOV")
local t = ui.reference("RAGE", "Other", "Remove recoil")
local u = ui.reference("RAGE", "Other", "Accuracy boost")
local w, wmode = ui.reference("RAGE", "aimbot", "Quick stop")
local x = ui.reference("RAGE", "Other", "Anti-aim correction")
local pbaim = ui.reference("RAGE", "aimbot", "Prefer body aim")
local safepoint = ui.reference("RAGE", "Aimbot", "Force safe point")
--local safepoint_libs = ui.reference("RAGE", "Aimbot", "Force safe point on limbs")
local qpa, qpa_hotkey = ui.reference("RAGE", "Other", "Quick peek assist")


local aaMasterSwitch = ui.reference("AA", "anti-aimbot angles", "Enabled")
local yaw, yaw_slider = ui.reference("AA", "anti-aimbot angles", "yaw")
local body_yaw, body_yaw_slider = ui.reference("aa", "anti-aimbot angles", "body yaw")
local freestanding = ui.reference("aa", "anti-aimbot angles", "Freestanding body yaw")
local flag_limit = ui.reference("AA", "fake lag", "Limit")
local fakelag, flagkey = ui.reference("AA", "Fake lag", "Enabled")

local chams, chamscp, chamsmode, chams2cp = ui.reference("Visuals", "Colored models", "Local player fake")
local inacc, inacc_color = ui.reference("Visuals", "Other ESP", "Inaccuracy overlay")
local ref_visual_recoil = ui.reference("Visuals", "Effects", "Visual recoil adjustment")
local ref_remove_scope = ui.reference("Visuals", "Effects", "Remove scope overlay")
local visuals_master, visuals_master_hk = ui.reference("Visuals", "Player ESP", "Activation type")
local nightmode = ui.reference("Visuals", "Effects", "Brightness adjustment")

local ref_pingspike = ui.reference("Misc", "Miscellaneous", "Ping spike")

local plist = ui.reference("PLAYERS", "Players", "Player list")
local correction = ui.reference("PLAYERS", "Adjustments", "Correction active")
local high_priority = ui.reference("PLAYERS", "Adjustments", "High priority")

---------------------------------
-- creation of necessary variables
---------------------------------

local mx, my = client.screen_size()
local timefired = 0
local indicators = {}
local indicators_clr = {}

local debugtext = {}
local debugtext_clr = {}

local fov_factor_awp_ref, fov_factor_ssg_ref, fov_factor_deagle_ref, fov_factor_else_ref
local dynamicfov = 0

local g_color = {255,255,255,255}

local animation_start = 0

local whitelist = {}

local sx, sy
sx = floor(mx*0.5 + 0.5)
sy = floor(my*0.5 + 0.5)

local sw, sh
sw = floor(mx*0.5 + 0.5)
sh = my - 20

local fontik = nil

---------------------------------
-- creation of menu elements
---------------------------------
local menu = {
	tap = ui.new_checkbox("LEGIT", "Other", "Jeff's RBOT"), -- masterswitch / all of the callback setting unsetting is bound to this checkbox
	hotkey = ui.new_hotkey("LEGIT", "Other", "Ragebot toggle"), -- set this to on hotkey or toggle mode, if enabled it activates ragebot and all the fuckery around that
	triggermagnet = ui.new_hotkey("LEGIT", "Other", "Triggermagnet key"), -- if ^ is enabled then this turns on ragebot autofire ( triggerbot + aimbot )
	awall = ui.new_hotkey("LEGIT", "Other", "Autowall override", false), -- enables automatic penetration

	weapons_presets = ui.new_combobox("LEGIT", "Other", "Configure", "-", "Awp", "Scout", "Deagle", "Other"), -- Yaaaa

	pbaim_switch = ui.new_checkbox("LEGIT", "Other", "Manual bodyaim"), -- body aim toggle switch
	pbaim_global = ui.new_hotkey("LEGIT", "Other", "Prefer body aim GLOBAL"), -- prefer body aim key

	fsp_awp = ui.new_hotkey("LEGIT", "Other", "Force safe point AWP"), -- force safepoints
	fsp_ssg = ui.new_hotkey("LEGIT", "Other", "Force safe point SSG"),
	fsp_deagle = ui.new_hotkey("LEGIT", "Other", "Force safe point DEAGLE"),
	fsp_else = ui.new_hotkey("LEGIT", "Other", "Force safe point OTHER"),

	max_fov_switch = ui.new_checkbox("LEGIT", "Other", "Limit fov"), -- fov limit toggle
	max_fov = ui.new_slider("LEGIT", "Other", "Maximum fov", 1, 60, 30, true, '°'), -- global dynamic fov cap

	fov_180 = ui.new_checkbox("LEGIT", "Other", "Fov 180"), -- fuck dynamic fov, set it to 180

	fov_factor_awp = ui.new_slider("LEGIT", "Other", "Dynamic FOV factor AWP", 0, 250, 50, true), -- dynamic fov factor
	fov_factor_ssg = ui.new_slider("LEGIT", "Other", "Dynamic FOV factor SSG", 0, 250, 50, true),
	fov_factor_deagle = ui.new_slider("LEGIT", "Other", "Dynamic FOV factor DEAGLE", 0, 250, 50, true),
	fov_factor_else = ui.new_slider("LEGIT", "Other", "Dynamic FOV factor OTHER", 0, 250, 50, true),

	min_damage_awp = ui.new_slider("LEGIT", "Other", "Minimum damage AWP", 0, 126, 50, true), -- minimum damage shid
	min_damage_ssg = ui.new_slider("LEGIT", "Other", "Minimum damage SSG", 0, 126, 50, true),
	min_damage_deagle = ui.new_slider("LEGIT", "Other", "Minimum damage DEAGLE",0, 126, 50, true),
	min_damage_else = ui.new_slider("LEGIT", "Other", "Minimum damage OTHER", 0, 126, 50, true),

	hit_chance_awp = ui.new_slider("LEGIT", "Other", "Hit chance AWP", 0, 100, 50, true), -- hc shid
	hit_chance_ssg = ui.new_slider("LEGIT", "Other", "Hit chance SSG", 0, 100, 50, true),
	hit_chance_deagle = ui.new_slider("LEGIT", "Other", "Hit chance DEAGLE", 0, 100, 50, true),
	hit_chance_else = ui.new_slider("LEGIT", "Other", "Hit chance OTHER", 0, 100, 50, true),

	multi_point_awp = ui.new_slider("LEGIT", "Other", "Multi-point AWP", 25, 100, 50, true), -- mp shid why am I commenting this just read the variable name
	multi_point_ssg = ui.new_slider("LEGIT", "Other", "Multi-point SSG", 25, 100, 50, true),
	multi_point_deagle = ui.new_slider("LEGIT", "Other", "Multi-point DEAGLE", 25, 100, 50, true),
	multi_point_else = ui.new_slider("LEGIT", "Other", "Multi-point OTHER", 25, 100, 50, true),


	legitaa = ui.new_checkbox("LEGIT", "Other", "Anti-aim"), -- legit aa main checkbox
	swap_sides = ui.new_hotkey("LEGIT", "Other", "Swap sides", true), -- set to toggle, switches between right or left side if manual aa is enabled
	manualaa = ui.new_combobox("LEGIT", "Other", "Anti-aim type", "Manual", "Dynamic", "Wall detection"), -- switches between auto and manual aa
	vel_treshold = ui.new_slider("LEGIT", "Other", "Speed treshold", 10, 300, 80, true, '', 1,{[10]="Minimum", [300]="No limit"}), -- velocity at which the anti aim turns off
	fakelag_amount = ui.new_slider("LEGIT", "Other", "Choke ticks", 1, 6, 3, true, '', 1,{[1]="Minimum", [6]="Maximum"}), -- fakelag, to achieve desync you need at least 3
	hvhmode = ui.new_checkbox("LEGIT", "Other", "HvH mode"), -- it overrides bunch of settings and enables resolver
	custom_resolver = ui.new_checkbox("LEGIT", "Other", "Custom resolver"), -- works on the base of reversed wall detection ( still in testing phase )
	custom_resolver_disable = ui.new_checkbox("LEGIT", "Other", "Disable on player after miss"), -- on miss due to '?' it will stop using custom resolver for that specific player
	peeker = ui.new_checkbox("LEGIT", "Other", "Peek assist"), -- vanilla quick peek assist, only bound to triggermagnet / awall
	visual_recoil = ui.new_checkbox("LEGIT", "Other", "Visual recoil"),
	display_targeting = ui.new_checkbox("LEGIT", "Other", "Jeff's FLIR"), -- flirvision ( still needs to be finished )
	targeting_color = ui.new_color_picker("LEGIT", "Other", "FLIR color", 255,0,0,255),
	targeting_style = ui.new_combobox("LEGIT", "Other", "FLIR style", "Custom", "Actual FLIR"), -- flir-like visuals
	targeting_x = ui.new_slider("LEGIT", "Other", "FLIR border x", 0, mx, 800, true), -- this should be draggable or scalable whatever, fuck sliders
	targeting_y = ui.new_slider("LEGIT", "Other", "FLIR border y", 0, my, 600, true),
	jumpcheck = ui.new_checkbox("LEGIT", "Other", "Advanced indicators"), -- shows if enemy can be noscoped, jumpscouted, and some other fucky things
	jumpcheck_cp = ui.new_color_picker("LEGIT", "Other", "Jumpscout color", 23,109,166,150), -- uhm ye ^
	scope_lines = ui.new_checkbox("LEGIT", "Other", "Improved scope overlay"), -- removes scope overlay and draws circle where the edge of the scope would be
	display_corrections = ui.new_checkbox("LEGIT", "Other", "Display corrections and priority"), -- visual indicator whether enemy is corrected or prioritized or jeffsolved

	deathsay = ui.new_checkbox("LEGIT", "Other", "Announce killer's info"), -- announces location/hp/name in teamchat after you die ( radas asked me to do this )
	deathsay_delay = ui.new_slider("LEGIT", "Other", '\n delay', 0, 5000, 1000, true, 'ms', 1,{[0]="Instant"}), -- delay to the above
	drawdebug = ui.new_checkbox("LEGIT", "Other", "Draw debug info"), -- probably dont wanna touch this

	custom_indicator = ui.new_checkbox("LEGIT", "Other", "Customized indicators"), -- override style of indicators ( colors et cetera )
	indicator_shadow = ui.new_checkbox("LEGIT", "Other", "Indicators shadow"), -- background shadow
	indicator_size = ui.new_slider("LEGIT", "Other", "Indicator size", 10, 150, 50, true, 'px'), -- gap between indicator arrows
	indicator_style = ui.new_combobox("LEGIT", "Other", "Indicator style", "Arrows", "Triangles"), -- just fuggin shoot me
	trigger_color_l = ui.new_label("LEGIT", "Other", "Triggermagnet color"),
	trigger_color = ui.new_color_picker("LEGIT", "Other", "Trigger color", 2,244,244,255),
	awall_color_l = ui.new_label("LEGIT", "Other", "Autowall color"),
	awall_color = ui.new_color_picker("LEGIT", "Other", "awall color", 198,25,5,255),
	default_color_l = ui.new_label("LEGIT", "Other", "Default color"),
	default_color = ui.new_color_picker("LEGIT", "Other", "def color", 234,161,2,255),

	--[[
	fontstyle = ui.new_combobox("LEGIT", "Other", "Font", "Constantia", "Impact"),
	fontsize = ui.new_slider("LEGIT", "Other", "Font size", 1, 70, 15, true),
	fontweight = ui.new_combobox("LEGIT", "Other", "Font weight", "100", "400", "900"),
	fontflags = ui.new_multiselect("LEGIT", "Other", "Font flags", "0x010", "0x020", "0x080", "0x200"),
	]]
}
--[[
local function createFont()
	local name = ui_get(menu.fontstyle)
	local size = ui_get(menu.fontsize)
	local weight = ui_get(menu.fontweight)
	--local flags = {0x001, 0x002}
	local flags = ui_get(menu.fontflags)
	fontik = surface.create_font(name, size, 900, flags)
end
local function flushFont()
	fontik = nil 
	client.log('Font has been flushed')
end

local createfont = ui.new_button("LEGIT", "Other", "Create font", createFont)
local flushfont = ui.new_button("LEGIT", "Other", "Flush font", flushFont)
]]

local function round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0)
  return math.floor(num * mult + 0.5) / mult
end

local function say(team_chat, ...)
  local command = team_chat and "say_team " or "say "
  local message = table_concat({...}, "")
  message = string_gsub(message, ";", ";")
  client_exec(command, message)
end

local function menuHandle() -- menu handle :DDDD ( disaster ) 
    masterswitch = ui_get(menu.tap)
	ui_set_visible(menu.hotkey,masterswitch)
	ui_set_visible(menu.triggermagnet,masterswitch)
	ui_set_visible(menu.indicator_size,masterswitch)

	ui_set_visible(menu.legitaa,masterswitch)
	ui_set_visible(menu.weapons_presets,masterswitch)
	ui_set_visible(menu.jumpcheck,masterswitch)
	ui_set_visible(menu.hvhmode,masterswitch)
	ui_set_visible(menu.display_targeting,masterswitch)
	ui_set_visible(menu.deathsay,masterswitch)
	ui_set_visible(menu.max_fov_switch,masterswitch)
	ui_set_visible(menu.custom_indicator,masterswitch)
	ui_set_visible(menu.drawdebug,masterswitch)
	ui_set_visible(menu.peeker,masterswitch)
	ui_set_visible(menu.visual_recoil,masterswitch)

	if not masterswitch then
		ui_set_visible(menu.swap_sides,false)
		ui_set_visible(menu.manualaa,false)
		ui_set_visible(menu.fakelag_amount,false)
		ui_set_visible(menu.vel_treshold,false)
		-----
		ui_set_visible(menu.max_fov,false)
		ui_set_visible(menu.fov_180,false)
		--
		ui_set_visible(menu.fov_factor_awp,false)
		ui_set_visible(menu.fov_factor_ssg,false)
		ui_set_visible(menu.fov_factor_deagle,false)
		ui_set_visible(menu.fov_factor_else,false)
		ui_set_visible(menu.fsp_awp,false)
		ui_set_visible(menu.fsp_ssg,false)
		ui_set_visible(menu.fsp_deagle,false)
		ui_set_visible(menu.fsp_else,false)
		ui_set_visible(menu.min_damage_awp,false)
		ui_set_visible(menu.min_damage_ssg,false)
		ui_set_visible(menu.min_damage_deagle,false)
		ui_set_visible(menu.min_damage_else,false)
		ui_set_visible(menu.hit_chance_awp,false)
		ui_set_visible(menu.hit_chance_ssg,false)
		ui_set_visible(menu.hit_chance_deagle,false)
		ui_set_visible(menu.hit_chance_else,false)
		ui_set_visible(menu.multi_point_awp,false)
		ui_set_visible(menu.multi_point_ssg,false)
		ui_set_visible(menu.multi_point_deagle,false)
		ui_set_visible(menu.multi_point_else,false)
		-----
		ui_set_visible(menu.jumpcheck_cp,false)
		-----
		ui_set_visible(menu.targeting_x,false)
		ui_set_visible(menu.targeting_y,false)
		ui_set_visible(menu.targeting_style,false)
		-----
		ui_set_visible(menu.deathsay_delay,false)
		ui_set_visible(menu.targeting_color,false)
		----
		ui_set_visible(menu.indicator_size,false)
		ui_set_visible(menu.indicator_shadow,false)
		ui_set_visible(menu.indicator_style,false)
		ui_set_visible(menu.trigger_color_l,false)
		ui_set_visible(menu.trigger_color,false)
		ui_set_visible(menu.awall_color_l,false)
		ui_set_visible(menu.awall_color,false)
		ui_set_visible(menu.default_color_l,false)
		ui_set_visible(menu.default_color,false)
		ui_set_visible(menu.pbaim_global,false)
		ui_set_visible(menu.pbaim_switch,false)
		ui_set_visible(menu.custom_resolver,false)
		ui_set_visible(menu.custom_resolver_disable,false)
	else
		if ui_get(menu.manualaa) == 'Manual' then
			ui_set_visible(menu.swap_sides,ui_get(menu.legitaa))
			ui_set_visible(menu.fakelag_amount,ui_get(menu.legitaa))
			ui_set_visible(menu.vel_treshold,ui_get(menu.legitaa))
			ui_set_visible(menu.manualaa,ui_get(menu.legitaa))
		else
			ui_set_visible(menu.swap_sides,ui_get(menu.manualaa) == 'Freestand')
			ui_set_visible(menu.fakelag_amount,ui_get(menu.legitaa))
			ui_set_visible(menu.vel_treshold,ui_get(menu.legitaa))
			ui_set_visible(menu.manualaa,ui_get(menu.legitaa))
		end
		-----
		ui_set_visible(menu.fov_180,ui_get(menu.weapons_presets) ~= '-')
		ui_set_visible(menu.max_fov_switch,ui_get(menu.weapons_presets) ~= '-' and not ui_get(menu.fov_180))
		if ui_get(menu.weapons_presets) ~= '-' then
			ui_set_visible(menu.max_fov,ui_get(menu.max_fov_switch) and not ui_get(menu.fov_180))
		else
			ui_set_visible(menu.max_fov,false)
		end

		ui_set_visible(menu.pbaim_switch,ui_get(menu.weapons_presets) ~= '-')
		if ui_get(menu.weapons_presets) ~= '-' then
			ui_set_visible(menu.pbaim_global,ui_get(menu.pbaim_switch))
		else
			ui_set_visible(menu.pbaim_global,false)
		end


		ui_set_visible(menu.custom_resolver,ui_get(menu.hvhmode))
		ui_set_visible(menu.custom_resolver_disable,ui_get(menu.custom_resolver) and ui_get(menu.hvhmode))

		ui_set_visible(menu.fov_factor_awp,ui_get(menu.weapons_presets) == 'Awp' and not ui_get(menu.fov_180))
		ui_set_visible(menu.fov_factor_ssg,ui_get(menu.weapons_presets) == 'Scout' and not ui_get(menu.fov_180))
		ui_set_visible(menu.fov_factor_deagle,ui_get(menu.weapons_presets) == 'Deagle' and not ui_get(menu.fov_180))
		ui_set_visible(menu.fov_factor_else,ui_get(menu.weapons_presets) == 'Other' and not ui_get(menu.fov_180))
		ui_set_visible(menu.fsp_awp,ui_get(menu.weapons_presets) == 'Awp')
		ui_set_visible(menu.fsp_ssg,ui_get(menu.weapons_presets) == 'Scout')
		ui_set_visible(menu.fsp_deagle,ui_get(menu.weapons_presets) == 'Deagle')
		ui_set_visible(menu.fsp_else,ui_get(menu.weapons_presets) == 'Other')
		ui_set_visible(menu.min_damage_awp,ui_get(menu.weapons_presets) == 'Awp')
		ui_set_visible(menu.min_damage_ssg,ui_get(menu.weapons_presets) == 'Scout')
		ui_set_visible(menu.min_damage_deagle,ui_get(menu.weapons_presets) == 'Deagle')
		ui_set_visible(menu.min_damage_else,ui_get(menu.weapons_presets) == 'Other')
		ui_set_visible(menu.hit_chance_awp,ui_get(menu.weapons_presets) == 'Awp')
		ui_set_visible(menu.hit_chance_ssg,ui_get(menu.weapons_presets) == 'Scout')
		ui_set_visible(menu.hit_chance_deagle,ui_get(menu.weapons_presets) == 'Deagle')
		ui_set_visible(menu.hit_chance_else,ui_get(menu.weapons_presets) == 'Other')
		ui_set_visible(menu.multi_point_awp,ui_get(menu.weapons_presets) == 'Awp')
		ui_set_visible(menu.multi_point_ssg,ui_get(menu.weapons_presets) == 'Scout')
		ui_set_visible(menu.multi_point_deagle,ui_get(menu.weapons_presets) == 'Deagle')
		ui_set_visible(menu.multi_point_else,ui_get(menu.weapons_presets) == 'Other')
		-----
		ui_set_visible(menu.jumpcheck_cp,ui_get(menu.jumpcheck))
		-----
		ui_set_visible(menu.targeting_x,ui_get(menu.display_targeting))
		ui_set_visible(menu.targeting_y,ui_get(menu.display_targeting))
		ui_set_visible(menu.targeting_style,ui_get(menu.display_targeting))
		ui_set_visible(menu.targeting_color,ui_get(menu.display_targeting))
		-----
		ui_set_visible(menu.deathsay_delay,ui_get(menu.deathsay))
		-----
		ui_set_visible(menu.indicator_size,ui_get(menu.custom_indicator))
		ui_set_visible(menu.indicator_shadow,ui_get(menu.custom_indicator))
		ui_set_visible(menu.indicator_style,ui_get(menu.custom_indicator))
		ui_set_visible(menu.trigger_color_l,ui_get(menu.custom_indicator))
		ui_set_visible(menu.trigger_color,ui_get(menu.custom_indicator))
		ui_set_visible(menu.awall_color_l,ui_get(menu.custom_indicator))
		ui_set_visible(menu.awall_color,ui_get(menu.custom_indicator))
		ui_set_visible(menu.default_color_l,ui_get(menu.custom_indicator))
		ui_set_visible(menu.default_color,ui_get(menu.custom_indicator))

	end
	ui_set_visible(menu.display_corrections,masterswitch)
	ui_set_visible(menu.awall,masterswitch)
	ui_set_visible(menu.scope_lines,masterswitch)
end

local function setRageBotValues(aimbot_active, aimbot_mode, autofire, fov, safepoint_mode, selection, hitboxes, multipoint_scale, hitchance, min_damage, prefer_baim, no_recoil, resolver, autowall, fsplimbs)
	if aimbot_active ~= nil then ui_set(aimbot, aimbot_active) end
	if aimbot_mode ~= nil then ui_set(aimbotmode, aimbot_mode) end
	if autofire ~= nil then ui_set(i, autofire) end
	if fov ~= nil then ui_set(r, fov) end
	if safepoint_mode ~= nil then ui_set(safepoint, safepoint_mode) end
	if selection ~= nil then ui_set(a, selection) end
	if hitboxes ~= nil then ui_set(b, unpack(hitboxes)) end
	if multipoint_scale ~= nil then ui_set(f, multipoint_scale) end
	if hitchance ~= nil then ui_set(l, hitchance) end
	if min_damage ~= nil then ui_set(m, min_damage) end
	if prefer_baim ~= nil then ui_set(pbaim, prefer_baim) end
	if no_recoil ~= nil then ui_set(t, no_recoil) end
	if resolver ~= nil then ui_set(x, resolver) end
	if autowall ~= nil then ui_set(j, autowall) end
	--if fsplimbs ~= nil then ui_set(safepoint_libs, fsplimbs) end
end
local function setAntiAimValues(aa_checkbox, aa_yaw, aa_body_yaw, aa_body_yaw_slider, aa_freestanding, aa_fakelag_amount, aa_fakelag_mode)
	if aa_checkbox ~= nil then ui_set(aaMasterSwitch, aa_checkbox) end
	if aa_yaw ~= nil then ui_set(yaw, aa_yaw) end
	if aa_body_yaw ~= nil then ui_set(body_yaw, aa_body_yaw) end
	if aa_body_yaw_slider ~= nil then ui_set(body_yaw_slider, aa_body_yaw_slider) end
	if aa_freestanding ~= nil then ui_set(freestanding, aa_freestanding) end
	if aa_fakelag_amount ~= nil then ui_set(flag_limit, aa_fakelag_amount) end
	if aa_fakelag_mode ~= nil then ui_set(flagkey, aa_fakelag_mode) end
end
local function setVisuals(vis_recoil, vis_scope, misc_ping)
	if vis_recoil ~= nil then ui_set(ref_visual_recoil, vis_recoil) end
	if vis_scope ~= nil then ui_set(ref_remove_scope, vis_scope) end
	--if misc_ping ~= nil then ui_set(ref_pingspike, misc_ping) end
end

local function make_even(x)
	return bit.band(x + 1, bit.bnot(1))
end

local function isJumpScouting(weapon, my_vel, onground)
	if onground == 0 and (weapon == 'CWeaponSSG08') and my_vel < 30 then return true else return false end
end

local function contains(tbl, val) for i=1,#tbl do if tbl[i] == val then return true end end return false end

local function hotkeyHandler(reference)
	if reference == nil then return end
	if reference then
		return 'Always on'
	else
		return 'On hotkey'
	end
end

local function insertIndicator(isDebug, text, color)
	if text == nil then return end
	if color == nil then color = {255,255,255,255} end
	if isDebug then
		if not contains(debugtext, text) then
			table_insert(debugtext, text)
			table_insert(debugtext_clr, color)
		end
	else
		if not contains(indicators, text) then
			table_insert(indicators, text)
			table_insert(indicators_clr, color)
		end
	end
end

local function drawIndicators()
	if #indicators > 0 and #indicators_clr > 0 then
		local iterator = 0
		for k, v in pairs(indicators) do
			iterator = iterator + 1
			if ui_get(menu.indicator_shadow) then 
				local wi, he = renderer.measure_text('c+', v)
				local wii = make_even(wi) / 2
				local gx, gy = sw - (wi / 2), sh - (he / 2) + 2
				renderer.gradient(gx-wii, ((gy + 10) - (iterator * 30)), wii, he, 0, 0, 0, 0, 0, 0, 0, 40, true)
				renderer_rectangle(gx, ((gy + 10) - (iterator * 30)), wi, he, 0,0,0,40)
				renderer.gradient(gx+wi, ((gy + 10) - (iterator * 30)), wii, he, 0, 0, 0, 40, 0, 0, 0, 0, true)
			end
			draw_text(sw, ((sh + 10) - (iterator * 30)), indicators_clr[iterator][1], indicators_clr[iterator][2], indicators_clr[iterator][3], indicators_clr[iterator][4], 'c+', 0, v)
		end
	end
	if #debugtext > 0 and #debugtext_clr > 0 then
		local iterator2 = 0
		for k, v in pairs(debugtext) do
			iterator2 = iterator2 + 1
			local myx = iterator2 > 20 and 650 or 300
			local myy = iterator2 > 20 and -100 or 300
			draw_text(myx, (myy + (iterator2 * 20)), debugtext_clr[iterator2][1], debugtext_clr[iterator2][2], debugtext_clr[iterator2][3], debugtext_clr[iterator2][4], '+', 0, v)
		end
	end
end

local function antiaimArrow(velocity, size)
	local angle = ui_get(body_yaw_slider)
	local aaColor = {255,255,255,255}
	local alpha = 0
	if not ui_get(menu.tap) or not ui_get(menu.hotkey) then return end

	-- color handle
	alpha = ui_get(menu.vel_treshold) < velocity and 85 or 255
	
	if not ui_get(menu.legitaa) then
		aaColor = {153,153,153,alpha}
	end

	if not ui_get(menu.custom_indicator) then
		if ui_get(menu.triggermagnet) then
			aaColor = {2,244,244,alpha}
		elseif ui_get(menu.awall) then
			aaColor = {198,25,5,alpha}
		elseif ui_get(menu.legitaa) then
			aaColor = {234,161,2,alpha}
		end
	else
		local tr = {ui_get(menu.trigger_color)}
		local aw = {ui_get(menu.awall_color)}
		local de = {ui_get(menu.default_color)}
		if ui_get(menu.triggermagnet) then
			aaColor = {tr[1], tr[2], tr[3], alpha}
		elseif ui_get(menu.awall) then
			aaColor = {aw[1], aw[2], aw[3], alpha}
		elseif ui_get(menu.legitaa) then
			aaColor = {de[1], de[2], de[3], alpha}
		end
	end
	g_color = aaColor
	if not entity_is_alive(get_local_player()) then return end
	
	local x, y = sx, sy
	if ui_get(menu.indicator_style) == 'Arrows' then
		if angle == -180 then
			draw_text(x - size, y, aaColor[1], aaColor[2], aaColor[3], aaColor[4], "c+", 0, "<")
			draw_text(x + size, y, 153,153,153,alpha, "c+", 0, ">")
		elseif angle == 180 then
			draw_text(x - size, y, 153,153,153,alpha, "c+", 0, "<")
			draw_text(x + size, y, aaColor[1], aaColor[2], aaColor[3], aaColor[4], "c+", 0, ">")
		else
			draw_text(x - size, y, aaColor[1], aaColor[2], aaColor[3], aaColor[4], "c+", 0, "<")
			draw_text(x + size, y, aaColor[1], aaColor[2], aaColor[3], aaColor[4], "c+", 0, ">")
		end
	elseif ui_get(menu.indicator_style) == 'Triangles' then
		-- somebody shoot me
		size = size + 25
		if angle == -180 then
			renderer.triangle(x - size, y, x + 20 - size, y - 10, x + 20 - size, y + 10, aaColor[1], aaColor[2], aaColor[3], aaColor[4])
			renderer.triangle(x + size, y, x - 20 + size, y - 10, x - 20 + size, y + 10, 153,153,153,alpha)
		elseif angle == 180 then
			renderer.triangle(x - size, y, x + 20 - size, y - 10, x + 20 - size, y + 10, 153,153,153,alpha)
			renderer.triangle(x + size, y, x - 20 + size, y - 10, x - 20 + size, y + 10, aaColor[1], aaColor[2], aaColor[3], aaColor[4])
		else
			renderer.triangle(x - size, y, x + 20 - size, y - 10, x + 20 - size, y + 10, aaColor[1], aaColor[2], aaColor[3], aaColor[4])
			renderer.triangle(x + size, y, x - 20 + size, y - 10, x - 20 + size, y + 10, aaColor[1], aaColor[2], aaColor[3], aaColor[4])
		end
	end
end

local function distance3d(x1, y1, z1, x2, y2, z2)
    local x, y, z = abs(x1-x2), abs(y1-y2), abs(z1-z2)
    return sqrt(x*x+y*y+z*z)
end
local function getDist()
	local nearestDist -- 2D distance from center of screen
	local smallestFrac -- fraction from localplayer to the entity closest to crosshair
	local bestDistance -- 3D distance paired to nearest 2D distance
	local bestEntity -- selected entity index
	local visible -- if entity is visible (could've been handled by fraction)
	local eyex, eyey, eyez = client_eye_position()

	for _, player in ipairs(entity_get_players(true)) do
		local ex, ey, ez = entity_hitbox_position(player, 4)
		local distance = distance3d(eyex, eyey, eyez, ex, ey, ez)
		local fraction, ent = client_trace_line(get_local_player(), eyex, eyey, eyez, ex, ey, ez + 30)
		local is_visible = client_visible(ex, ey, ez + 30)

		if ex ~= nil then
			local ddx, ddy = renderer_world_to_screen(ex, ey, ez)
			if ddx ~= nil and ddy ~= nil then
				local dist = floor(sqrt((sx - ddx) * (sx - ddx) + (sy - ddy) * (sy - ddy)))
				if (nearestDist == nil or dist < nearestDist) then
					nearestDist = dist
					bestDistance = distance
					bestEntity = player
					smallestFrac = fraction
					visible = is_visible
				end
			end
		end
	end

	if (nearestDist ~= nil and smallestFrac ~= nil and bestDistance ~= nil and visible ~= nil) then
		return nearestDist, smallestFrac, bestDistance, bestEntity, visible
	end
end
local function createFOV(basefov, factor)
	local cap = ui_get(menu.max_fov_switch) and ui_get(menu.max_fov) or 180
	if not entity_is_alive(get_local_player()) then return 1 end
	if ui_get(menu.fov_180) then return 180 end
	if basefov == 0 then
		return 1
	elseif (floor(basefov * (factor * 0.01) + 0.5)) > cap then
		return cap
	elseif (floor(basefov * (factor * 0.01) + 0.5)) > 180 then
		return 180
	elseif (floor(basefov * (factor * 0.01) + 0.5)) < 1 then
		return 1
	else
		return floor(basefov * (factor * 0.01) + 0.5)
	end
end

local function handleAntiaimSettings(my_vel, threshold, manualaa_ref, swapsides_ref, triggermag_ref, fakelag_amount_ref, awall_ref, spacing, angle, mode)
	if ui_get(menu.legitaa) then
		if my_vel < threshold  then
			if manualaa_ref then
				if swapsides_ref then
					setAntiAimValues(true, '180', 'Static', 180, false, fakelag_amount_ref)
				else
					setAntiAimValues(true, '180', 'Static', -180, false, fakelag_amount_ref)
				end
				insertIndicator(false, 'AA: ' .. string_upper(mode), g_color)
			elseif not manualaa_ref then
				setAntiAimValues(true, '180', 'Static', angle, false, fakelag_amount_ref)
				insertIndicator(false, 'AA: ' .. string_upper(mode), g_color)
			end
		else
			if manualaa_ref then
				insertIndicator(false, 'AA: ' .. string_upper(mode), g_color)
				if swapsides_ref then
					setAntiAimValues(false, nil, nil, 180, nil, 1)
				else
					setAntiAimValues(false, nil, nil, -180, nil, 1)
				end
			else
				insertIndicator(false, 'AA: ' .. string_upper(mode), g_color)
				setAntiAimValues(false, nil, nil, angle, nil, 1)
			end
		end
	else
		setAntiAimValues(false, nil, nil, 0, nil, 1)
	end
end

local function handleAimbotSetting(awall, hvh, weapon, noscope)

	-- its late but please shoot me
	local baim
	if ui_get(menu.pbaim_switch) then
		baim = ui_get(menu.pbaim_global)
	else
		if weapon == 'CWeaponAWP' then
			baim = true
		elseif weapon == 'CWeaponSSG08' then
			baim = true
		elseif weapon == 'CDEagle' and hvh then
			baim = true
		elseif weapon == 'CDEagle' and not hvh then
			baim = false
		else
			baim = false
		end
	end

	if awall then
		if weapon == "CWeaponAWP" then
			setRageBotValues(nil, 'Always on', true, (createFOV(dynamicfov, fov_factor_awp_ref)), 'On hotkey', 'Near crosshair', {'Head', 'Chest', 'Stomach'}, 80, 60, 102, false, false, true, true)
		elseif weapon == 'CWeaponSSG08' then
			setRageBotValues(nil, 'Always on', true, (createFOV(dynamicfov, fov_factor_ssg_ref)), 'On hotkey', 'Near crosshair', {'Head', 'Chest', 'Stomach'}, 85, 60, 102, false, false, true, true)
		elseif weapon == 'CDEagle' then
			setRageBotValues(nil, 'Always on', true, (createFOV(dynamicfov, fov_factor_deagle_ref)), 'On hotkey', 'Near crosshair', {'Head', 'Chest', 'Stomach'}, 90, 65, 35, false, true, true, true)
		else
			setRageBotValues(nil, 'Always on', true, (createFOV(dynamicfov, fov_factor_else_ref)), 'On hotkey', 'Near crosshair', {'Head'}, 80, 50, 10, false, false, true, true)
		end
		insertIndicator(false, 'AWALL', g_color)
		insertIndicator(false, 'FOV: ' .. tostring(ui_get(r)) .. '°', g_color)
	else
		if hvh then
			if noscope then
				if weapon == "CWeaponAWP" then
					setRageBotValues(nil, nil, true, (createFOV(dynamicfov, fov_factor_awp_ref)), 'On hotkey', 'Near crosshair', {'Head', 'Chest', 'Stomach', 'Arms', 'Legs'}, 100, 40, 100, true, false, false, false)
				elseif weapon == 'CWeaponSSG08' then
					setRageBotValues(nil, nil, true, (createFOV(dynamicfov, fov_factor_ssg_ref)), 'On hotkey', 'Near crosshair', {'Head', 'Chest', 'Stomach'}, 100, 40, 60, true, false, false, false)
				end
			else
				if weapon == "CWeaponAWP" then
					setRageBotValues(nil, nil, true, (createFOV(dynamicfov, fov_factor_awp_ref)), hotkeyHandler(ui_get(menu.fsp_awp)), 'Near crosshair', {'Head', 'Chest', 'Stomach', 'Arms'}, 85, 70, 101, baim, false, true, false, true)
				elseif weapon == 'CWeaponSSG08' then
					setRageBotValues(nil, nil, true, (createFOV(dynamicfov, fov_factor_ssg_ref)), hotkeyHandler(ui_get(menu.fsp_ssg)), 'Near crosshair', {'Head', 'Chest', 'Stomach', 'Legs'}, 90, 75, 65, baim, false, true, false, true)
				elseif weapon == 'CDEagle' then
					setRageBotValues(nil, nil, true, (createFOV(dynamicfov, fov_factor_deagle_ref)), hotkeyHandler(ui_get(menu.fsp_deagle)), 'Near crosshair', {'Head', 'Chest', 'Stomach', 'Arms', 'Legs'}, 85, 70, 30, baim, true, true, false, true)
				else
					setRageBotValues(nil, nil, true, (createFOV(dynamicfov, fov_factor_else_ref)), hotkeyHandler(ui_get(menu.fsp_else)), 'Near crosshair', {'Head', 'Stomach', 'Chest'}, 80, 50, 10, baim, false, true, false)
				end
			end
			insertIndicator(false, 'HVH MODE', g_color)
			insertIndicator(false, 'FOV: ' .. tostring(ui_get(r)) .. '°', g_color)
		else
			if noscope then
				if weapon == "CWeaponAWP" then
					setRageBotValues(nil, nil, true, (createFOV(dynamicfov, fov_factor_awp_ref)), 'On hotkey', 'Near crosshair', {'Head', 'Chest', 'Stomach', 'Arms', 'Legs'}, 100, 40, 100, true, false, false, false)
				elseif weapon == 'CWeaponSSG08' then
					setRageBotValues(nil, nil, true, (createFOV(dynamicfov, fov_factor_ssg_ref)), 'On hotkey', 'Near crosshair', {'Head', 'Chest', 'Stomach', 'Arms'}, 100, 40, 60, true, false, false, false)
				end
			else
				if weapon == "CWeaponAWP" then
					setRageBotValues(nil, nil, true, (createFOV(dynamicfov, fov_factor_awp_ref)), hotkeyHandler(ui_get(menu.fsp_awp)), 'Near crosshair', {'Head', 'Chest', 'Stomach', 'Arms', 'Legs'}, ui_get(menu.multi_point_awp), ui_get(menu.hit_chance_awp), ui_get(menu.min_damage_awp), baim, false, false, false, true)
				elseif weapon == 'CWeaponSSG08' then
					setRageBotValues(nil, nil, true, (createFOV(dynamicfov, fov_factor_ssg_ref)), hotkeyHandler(ui_get(menu.fsp_ssg)), 'Near crosshair', {'Head', 'Chest', 'Stomach', 'Arms'}, ui_get(menu.multi_point_ssg), ui_get(menu.hit_chance_ssg), ui_get(menu.min_damage_ssg), baim, false, false, false, true)
				elseif weapon == 'CDEagle' then
					setRageBotValues(nil, nil, true, (createFOV(dynamicfov, fov_factor_deagle_ref)), hotkeyHandler(ui_get(menu.fsp_deagle)), 'Near crosshair', {'Head', 'Chest', 'Stomach'}, ui_get(menu.multi_point_deagle), ui_get(menu.hit_chance_deagle), ui_get(menu.min_damage_deagle), baim, false, false, false)
				else
					setRageBotValues(nil, nil, true, (createFOV(dynamicfov, fov_factor_else_ref)), hotkeyHandler(ui_get(menu.fsp_else)), 'Near crosshair', {'Head', 'Chest', 'Stomach'}, ui_get(menu.multi_point_else), ui_get(menu.hit_chance_else), ui_get(menu.min_damage_else), baim, false, false, false)
				end
			end
			insertIndicator(false, 'RBOT', g_color)
			insertIndicator(false, 'FOV: ' .. tostring(ui_get(r)) .. '°', g_color)
		end
	end
end
local function calculate_best_angle(target,...)
	-- freestanding angle function, run this if enemy is available alongside wall dtc
    local calc_angle = function(x,y,z,a)
        local relativeyaw = math.atan((y-a)/(x-z))
        return relativeyaw*180 / math.pi
    end
    local angle_vectors = function(x,y)
        local sp,sy,cp,cy = nil
        sy=math.sin(math.rad(y))

        cy=math.cos(math.rad(y))
        sp=math.sin(math.rad(x))
        cp=math.cos(math.rad(x))
        return cp*cy,cp*sy,-sp
    end

    local me = entity.get_local_player()
    local lx, ly, lz = entity.get_prop(me, "m_vecOrigin")

    viewangle_x, viewangle_y = client.camera_angles()
    headx, heady, headz = entity.hitbox_position(me, 0)
    enemyx, enemyy, enemyz = entity.get_prop(target,"m_vecOrigin")

    bestangle = nil
    lowestdmg = math.huge

    if entity_is_alive(target) then
        f_yaw = calc_angle(lx,ly,enemyx,enemyy)

        for k, v in pairs({...}) do
            dir_x,dir_y,dir_z=angle_vectors(0,(f_yaw+v))

			end_x=lx+dir_x*40
            end_y=ly+dir_y*40
            end_z=lz+70
            index, damage = client.trace_bullet(target, enemyx, enemyy, enemyz+70, end_x, end_y, end_z)
            index2, damage2 = client.trace_bullet(target, enemyx, enemyy, enemyz+70, end_x+24, end_y, end_z)
            index3, damage3 = client.trace_bullet(target, enemyx, enemyy, enemyz+70, end_x-24, end_y, end_z)

            if damage < lowestdmg then
				lowestdmg = damage
                if damage2 > damage then
					lowestdmg = damage2
				end
                if damage3 > damage then
					lowestdamage = damage3
				end
                if lx-enemyx > 0 then
                    bestangle = v
                else
                    bestangle = v * -1
                end
            elseif damage == lowestdmg then
                return 0
            end
        end
    end
    return bestangle
end
local function wallDetection()
	-- custom wall detection function / run this as AA
    local me = get_local_player()
    if not me then
        return
    end

    local cx, cy, cz = client.eye_position()
    local pitch, yaw = client.camera_angles()

    local trace_data = {left = 0, right = 0}
	local angle = 0

    for i = yaw - 90, yaw + 90, 30 do
        if i ~= yaw then
            local rad = math.rad(i)
            local px, py, pz = cx + 250 * math.cos(rad), cy + 250 * math.sin(rad), cz

            local frac = client.trace_line(me, cx, cy, cz, px, py, pz)

			if ui_get(menu.drawdebug) then
				local bx, by = renderer_world_to_screen(cx, cy, cz)
				local ex, ey = renderer_world_to_screen(px, py, pz)
				if bx ~= nil and ex ~= nil then
					renderer_line(bx, by, ex, ey, 255,255,255,150)
					renderer_circle(ex, ey, 255, 22, 22, 255, 5, 0, 1)
				end
			end
            local side = i < yaw and "left" or "right"

            trace_data[side] = trace_data[side] + frac
        end
    end
	angle = trace_data.left < trace_data.right and 180 or -180
	return angle
end
local function customResolver()
	if not entity_is_alive(get_local_player()) then return end
	if not ui_get(menu.custom_resolver) or not ui_get(menu.hvhmode) then return end
	local mydist, myfraction, mybestDistance, myBestEntity, my_visible = getDist()
	--local ptch, yaww = client.camera_angles()

	for _, player in ipairs(entity_get_players(true)) do
		local target_vel = 0
		if player ~= nil then
			local vx, vy = entity_get_prop(player, "m_vecVelocity")
			if vx ~= nil and vy ~= nil then
				target_vel = floor(min(10000, sqrt(vx*vx + vy*vy) + 0.5))
			end
		end

		if not ui_is_menu_open() then
			ui_set(plist, player)
		end
		
		if not ui_get(correction) or contains(whitelist, player) or target_vel > 78 then 
			plist_set(player, 'Force body yaw', false)
			goto continue
		end
		
		if player == myBestEntity then
			plist_set(player, 'Force body yaw', true)
		else
			plist_set(player, 'Force body yaw', false)
			goto continue
		end

		local cx, cy, cz = entity_hitbox_position(player, 0)
		local yaww = entity_get_prop(player, 'm_flLowerBodyYawTarget')

		local trace_data = {left = 0, right = 0}
		local angle = 0

		for i = yaww - 90, yaww + 90, 30 do
			if i ~= yaww then
				local rad = math.rad(i)
				local px, py, pz = cx + 150 * math.cos(rad), cy + 150 * math.sin(rad), cz

				local frac = client.trace_line(player, cx, cy, cz, px, py, pz)

				-- draw the wall detection lines in debug mode
				if ui_get(menu.drawdebug) then
					local bx, by = renderer_world_to_screen(cx, cy, cz)
					local ex, ey = renderer_world_to_screen(px, py, pz)
					if bx ~= nil and ex ~= nil then
						renderer_line(bx, by, ex, ey, 255,11,11,222)
						renderer_circle(ex, ey, 255, 255, 255, 222, 4, 0, 1)
					end
				end

				local side = i < yaww and "left" or "right"
				trace_data[side] = trace_data[side] + frac
			end
		end
		angle = trace_data.left < trace_data.right and 180 or -180

		if angle == 180 then
			plist_set(player, 'Force body yaw value', 60)
		else
			plist_set(player, 'Force body yaw value', -60)
		end
		::continue::
	end
end
local function quickPeeker(weapon)
	if not ui_get(menu.peeker) or not ui_get(menu.hotkey) then return end
	if weapon == 'CWeaponAWP' or weapon == 'CWeaponSSG08' then
		if ui_get(menu.triggermagnet) or ui_get(menu.awall) then 
			ui_set(qpa, true)
			ui_set(qpa_hotkey, 'Always on')
		else
			ui_set(qpa_hotkey, 'On hotkey')
		end
	end
end
local function drawScopeOutline()
	local myradius = 0
	local velocity = 0
	local me = get_local_player()
	if me ~= nil then
		local vx, vy = entity_get_prop(me, "m_vecVelocity")

		if vx ~= nil and vy ~= nil then
			velocity = floor(min(10000, sqrt(vx*vx + vy*vy) + 0.5))
		end
	end

	-- hahahaha fucking shoot me for this
	local finalres = mx .. 'x' .. my
	if finalres == '1280x720' then
		myradius = 300
	elseif finalres == '1600x900' then
		myradius = 376
	elseif finalres == '1920x1080' then
		myradius = 451
	elseif finalres == '2560x1440' then
		myradius = 601
	elseif finalres == '3840x2160' then
		myradius = 902
	elseif finalres == '5120x2880' then
		myradius = 1202
	else
		myradius = 0
	end

	if velocity > 3 then
		radius = myradius - (velocity / 3)
	else
		radius = myradius
	end
	surface.draw_outlined_circle(sx, sy, 255, 255, 255, 255, radius, 254)
end
local function draw_custom_flir()
	if ui_get(menu.tap) then
		if ui_get(menu.display_targeting) then
			ui_set(visuals_master, 'On hotkey')
		else
			ui_set(visuals_master, 'Always on')
		end
	end
	if not ui_get(menu.tap) then return end
	if not ui_get(menu.display_targeting) then return end
	if ui_get(menu.targeting_style) ~= 'Custom' then return end
	local mydist, myfraction, mybestDistance, myBestEntity, my_visible = getDist()
	local cx, cy, cz = client_eye_position()
	local alpha
	local flir_width, flir_height = ui_get(menu.targeting_x), ui_get(menu.targeting_y)

	local x_start = sx - (flir_width / 2)
	local x_end = sx + (flir_width / 2)
	local y_start = sy - (flir_height / 2)
	local y_end = sy + (flir_height / 2)

	-- main border
	surface.draw_outlined_rect(x_start, y_start, flir_width, flir_height, 255,255,255,255)
	draw_text(x_start,y_start-13, 198,25,5,255, "b", 0, "Jeff's custom FLIR")

	-- nightmode alpha handle
	if ui_get(nightmode) == 'Off' then
		alpha = 175
	elseif ui_get(nightmode) == 'Night mode' then
		alpha = 100
	else
		alpha = 255
	end
	local r, g, b, a = ui_get(menu.targeting_color)

	for _, player in ipairs(entity_get_players(true)) do
		local ex, ey, ez = entity_hitbox_position(player, 4)
		local is_closest_entity = player == myBestEntity and true or false
		local dx, dy = renderer_world_to_screen(ex, ey, ez)
		local is_visible = client_visible(ex, ey, ez+30)

		local bb = {entity_get_bounding_box(player)}

		if not is_visible then
			a = alpha
		end
		if dx ~= nil and dy ~= nil then
			if dx > x_start and dx < x_end and dy > y_start and dy < y_end then
				if not is_closest_entity then
					surface.draw_outlined_rect(dx - 20, dy - 20, 40, 40, 255,255,255,(a-50))
				else
					if not (dx - 20 > x_start and dx + 20 < x_end and dy - 20 > y_start and dy + 20 < y_end) then
						surface.draw_line(x_start, dy, x_end, dy, r, g, b, a)
						surface.draw_line(dx, y_start, dx, y_end, r, g, b, a)
					else
						surface.draw_line(x_start, dy, dx - 20, dy, r, g, b, a)
						surface.draw_line(dx + 20, dy, x_end, dy, r, g, b, a)

						surface.draw_line(dx, y_start, dx, dy - 20, r, g, b, a)
						surface.draw_line(dx, dy + 20, dx, y_end, r, g, b, a)

						if is_visible then
							surface.draw_outlined_rect(dx - 20, dy - 20, 40, 40, 255,255,255,255)
						else
							surface.draw_outlined_rect(dx - 20, dy - 20, 40, 40, r, g, b, a)
						end
					end
				end
			end
		end
	end
end
----
local function draw_flir_crosshair(x, y, color, scale)
	local flir_size, flir_length = 7, 10
	local flir_width, flir_height = ui_get(menu.targeting_x), ui_get(menu.targeting_y)

	local xx_start = x - ((sx - scale) / flir_size)
	local yy_start = y - ((sx - scale) / flir_size)

	local xxx_start = x + ((sx - scale) / flir_size)
	local yyy_start = y + ((sx - scale) / flir_size)


	surface.draw_line(xx_start, yy_start, xx_start + flir_length, yy_start, unpack(color))
	surface.draw_line(xx_start, yy_start, xx_start, yy_start + flir_length, unpack(color))

	surface.draw_line(xxx_start, yyy_start, xxx_start - flir_length, yyy_start, unpack(color))
	surface.draw_line(xxx_start, yyy_start, xxx_start, yyy_start - flir_length, unpack(color))

	surface.draw_line(xx_start, yyy_start, xx_start + flir_length, yyy_start, unpack(color))
	surface.draw_line(xx_start, yyy_start, xx_start, yyy_start - flir_length, unpack(color))


	surface.draw_line(xxx_start, yy_start, xxx_start - flir_length, yy_start, unpack(color))
	surface.draw_line(xxx_start, yy_start, xxx_start, yy_start + flir_length, unpack(color))

	surface.draw_line(x, y - 15, x, y - 5, unpack(color))
	surface.draw_line(x, y + 15, x, y + 5, unpack(color))
	surface.draw_line(x - 15, y, x - 5, y, unpack(color))
	surface.draw_line(x + 15, y , x + 5, y, unpack(color))
end
local function draw_actual_flir()
	if ui_get(menu.tap) then
		if ui_get(menu.display_targeting) then
			if ui_get(menu.targeting_style) == 'Actual FLIR'	then
				ui_set(visuals_master, 'On hotkey')
				client_exec('crosshair 0')
			else
				ui_set(visuals_master, 'Always on')
				client_exec('crosshair 1')
			end
		else
			client_exec('crosshair 1')
		end
	end
	if not ui_get(menu.tap) then return end
	if not ui_get(menu.display_targeting) then return end
	if ui_get(menu.targeting_style) ~= 'Actual FLIR' then return end
	local mydist, myfraction, mybestDistance, myBestEntity, my_visible = getDist()
	local cx, cy, cz = client_eye_position()
	local alpha
	local flir_width, flir_height = ui_get(menu.targeting_x), ui_get(menu.targeting_y)


	local x_start = sx - (flir_width / 2)
	local x_end = sx + (flir_width / 2)
	local y_start = sy - (flir_height / 2)
	local y_end = sy + (flir_height / 2)


	local colors = {
	["white"] = {255,255,255,255},
	["red"] = {255,0,0,255},
	}

	-- main border
	surface.draw_outlined_rect(x_start, y_start, flir_width, flir_height, 255,255,255,255)
	draw_text(x_start,y_start-13, 15,149,193,255, "b", 0, "Jeff's actual FLIR")

	-- nightmode alpha handle
	if ui_get(nightmode) == 'Off' then
		alpha = 175
	elseif ui_get(nightmode) == 'Night mode' then
		alpha = 100
	else
		alpha = 255
	end

	local scaler = 0
	if mybestDistance ~= nil then
		scaler = (mybestDistance / 2) + 200
		if scaler > 800 then scaler = 800 end
		if scaler < 100 then scaler = 100 end
	end

	local players = {}
	players = entity_get_players(true)
	if #players == 0 then
		draw_flir_crosshair(sx, sy, colors['white'], 0)
	end

	for _, player in ipairs(entity_get_players(true)) do
		local ex, ey, ez = entity_hitbox_position(player, 4)
		local is_closest_entity = player == myBestEntity and true or false
		local dx, dy = renderer_world_to_screen(ex, ey, ez)
		local is_visible = client_visible(ex, ey, ez+27)


		if dx ~= nil and dy ~= nil then
			if is_closest_entity and (mydist < flir_width / 2) then
				draw_flir_crosshair(dx, dy, colors['white'], scaler)
				renderer_circle(sx, sy, 255,255,255,200, 2, 0, 1)
			elseif mydist > (sx - x_start) then
				draw_flir_crosshair(sx, sy, colors['white'], 0)
			end
		end
		if myBestEntity == nil then
			draw_flir_crosshair(sx, sy, colors['white'], 0)
		end
	end
end
local function drawFlir()
	draw_actual_flir()
	draw_custom_flir()
end
local function playerListFuckery()
	local a,b,c,bestEntity = getDist()
	if ui_get(menu.display_corrections) and not ui_is_menu_open() then
		client.update_player_list()
        local players = entity_get_players(true)
		for i = 1, #players do
			local speedo = 0
			if players[i] ~= nil then
				local vx, vy = entity_get_prop(players[i], "m_vecVelocity")
				if vx ~= nil and vy ~= nil then
					speedo = floor(min(10000, sqrt(vx*vx + vy*vy) + 0.5))
				end
			end
            ui_set(plist, players[i])
			local bb = {entity_get_bounding_box(players[i])}
			if not entity_is_alive(get_local_player()) or speedo > 78 then bestEntity = nil end

			if #bb == 5 and bb[5] ~= 0 then
				local center = bb[1]+(bb[3]-bb[1])/2
				if ui_get(correction) then
					if ui_get(high_priority) then
						if ui_get(menu.hvhmode) and ui_get(menu.custom_resolver) and players[i] == bestEntity and not contains(whitelist, players[i]) then
							draw_text(center, bb[2] - 28, 234, 0, 242, 255, "cb", 0, "CORRECTED")
							surface.draw_outlined_rect(bb[1] + 3, bb[2] + 3, (bb[3] - bb[1] - 6), (bb[4] - bb[2] - 6), 234, 0, 242, 150*bb[5])
						else
							draw_text(center, bb[2] - 28, 0, 255, 0, 150, "cb", 0, "CORRECTED")
							surface.draw_outlined_rect(bb[1] + 3, bb[2] + 3, (bb[3] - bb[1] - 6), (bb[4] - bb[2] - 6), 0, 255, 0, 150*bb[5])
						end
					else
						if ui_get(menu.hvhmode) and ui_get(menu.custom_resolver) and players[i] == bestEntity and not contains(whitelist, players[i]) then
							draw_text(center, bb[2] - 16, 234, 0, 242, 255, "cb", 0, "CORRECTED")
							surface.draw_outlined_rect(bb[1] + 2, bb[2] + 2, (bb[3] - bb[1] - 4), (bb[4] - bb[2] - 4), 234, 0, 242, 150*bb[5])
						else
							draw_text(center, bb[2] - 16, 0, 255, 0, 150, "cb", 0, "CORRECTED")
							surface.draw_outlined_rect(bb[1] + 2, bb[2] + 2, (bb[3] - bb[1] - 4), (bb[4] - bb[2] - 4), 0, 255, 0, 150*bb[5])
						end
					end
				end
				if ui_get(high_priority) then
					draw_text(center, bb[2]-18, 255, 255, 0, 255, "cb", 0, "PRIORITY")
					surface.draw_outlined_rect(bb[1] + 2, bb[2] + 2, (bb[3] - bb[1] - 4), (bb[4] - bb[2] - 4), 255, 255, 0, 255*bb[5])
				end
			end
        end
    end
end
local function on_paint()
	local local_entindex = get_local_player()
	local local_weapon = entity_get_player_weapon(local_entindex)
	local weapon_name = get_classname(local_weapon)
	local isscoped = entity_get_prop(local_entindex, "m_bIsScoped")
	local m_flNextAttack = entity_get_prop(local_entindex, "m_flNextAttack")
	local m_flNextPrimaryAttack = entity_get_prop(local_entindex, "m_flNextPrimaryAttack")
	local my_vel = 0
	local onground = 1
	local threshold = ui_get(menu.vel_treshold)
	local spacing = ui_get(menu.indicator_size)
	local mydist, myfraction, mybestDistance, myBestEntity, my_visible = getDist()
	local noscope = false
	local isReadyToFire = false
	local hasFired = false
	local timee = globals.curtime()
	local triggermag_ref = ui_get(menu.triggermagnet)
	local hvhmode_ref = ui_get(menu.hvhmode)
	local awall_ref = ui_get(menu.awall)
	local manualaa_ref = ui_get(menu.manualaa)
	local swapsides_ref = ui_get(menu.swap_sides)
	local fakelag_amount_ref = ui_get(menu.fakelag_amount)
	fov_factor_awp_ref, fov_factor_ssg_ref, fov_factor_deagle_ref, fov_factor_else_ref = ui_get(menu.fov_factor_awp), ui_get(menu.fov_factor_ssg), ui_get(menu.fov_factor_deagle), ui_get(menu.fov_factor_else)
	--dynamicfov = 0
	local angle = 0
	local freeangle = 0
	local mode
	local localtime = floor(client_timestamp()/100)
	local b_manualaa = manualaa_ref == 'Manual' and true or false


	if manualaa_ref == 'Dynamic' then
		if myBestEntity ~= nil then
			if calculate_best_angle(myBestEntity, -90 , 90) > 0 then
				freeangle = 180
			elseif calculate_best_angle(myBestEntity, -90 , 90) < 0 then
				freeangle = -180
			else
				if my_visible then
					if localtime % 2 == 0 then
						freeangle = 180
					else
						freeangle = -180
					end
				else
					freeangle = 0
				end
			end
		end
		if freeangle ~= 0 then
			angle = freeangle
			mode = 'FREESTANDING'
		else
			angle = wallDetection()
			mode = 'WALL DETECTION'
		end
	elseif manualaa_ref == 'Wall detection' then
		angle = wallDetection()
		mode = 'WALL DETECTION'
	elseif manualaa_ref == 'Manual' then 
		mode = 'MANUAL'
	end
	if mybestDistance ~= nil then
		dynamicfov = (4000 / mybestDistance)
	end

	if local_entindex ~= nil then
		onground = bit.band(entity_get_prop(local_entindex, 'm_fFlags'), bit.lshift(1, 0))
		local vx, vy = entity_get_prop(local_entindex, "m_vecVelocity")

		if vx ~= nil and vy ~= nil then
			my_vel = floor(min(10000, sqrt(vx*vx + vy*vy) + 0.5))
		end
	end
	if not (math.max(0, m_flNextPrimaryAttack or 0, m_flNextAttack or 0) - timee > 0) then
		isReadyToFire = true
	end
	if timefired + 1.5 >= timee then
		hasFired = true
	end
	-- noscope setter just fuggin end it XD
	if mydist ~= nil then
		if mybestDistance < 800 and mydist < 250 and myfraction > 0.96 and isReadyToFire and isscoped == 0 and (weapon_name == "CWeaponAWP" or weapon_name == 'CWeaponSSG08') and not hasFired then
			noscope = true
		end
	end

    ---------------------------------
	-- whole ragebot switching logic
	---------------------------------
	if ui_get(menu.tap) then
		if ui_get(menu.hotkey) then
			setRageBotValues(true)
			if triggermag_ref then
				setRageBotValues(nil, 'Always on', true)
			else
				setRageBotValues(nil, 'On hotkey', false)
			end
			handleAntiaimSettings(my_vel, threshold, b_manualaa, swapsides_ref, triggermag_ref, fakelag_amount_ref, awall_ref, spacing, angle, mode)
			handleAimbotSetting(awall_ref,hvhmode_ref,weapon_name, noscope)


			-- drawing indicators ( pass false for normal styled indicator and true for debug style )
			if fakelag_amount_ref > 3 then
				insertIndicator(false, 'FAKELAG: ' .. fakelag_amount_ref, g_color)
			end
			if ui_get(safepoint) then
				insertIndicator(false, 'SAFEPOINT', g_color)
			end
			if triggermag_ref then
				insertIndicator(false, 'TRIGGER', g_color)
			end
			if ui_get(pbaim) and ui_get(menu.pbaim_switch) and ui_get(menu.pbaim_global) then
				insertIndicator(false, 'BODY AIM', g_color)
			end

			-- visual bullshit
			if ui_get(menu.scope_lines) then
				setVisuals(nil, true, nil)
				if isscoped == 1 then
					drawScopeOutline()
				end
			else
				setVisuals(nil, false, nil)
			end
			if ui_get(menu.visual_recoil) then
				setVisuals('Remove all', nil, true)
			else
				setVisuals('Off', nil, false)
			end
			

		else
			setRageBotValues(false)
			setAntiAimValues(false, 'Off', 'Off', 0, false, 1)
			setVisuals('Off', false, false)
		end

	end
	----------------------
	-- jumpscout + noscope -- shoot me
	----------------------
	if ui_get(menu.jumpcheck) then
		if isJumpScouting(weapon_name, my_vel, onground) then
			ui_set(inacc_color, ui_get(menu.jumpcheck_cp))
			insertIndicator(false, 'JUMP SCOUT', g_color)
		elseif noscope == true then
			ui_set(inacc_color, 235,10,5,235)
			insertIndicator(false, 'NO SCOPE', g_color)
		else
			ui_set(inacc_color, 255,255,255,0)
		end
	end


	if ui_get(menu.drawdebug) then
		local aaa = 255
		insertIndicator(true, 'velocity: ' .. tostring(my_vel), {255,111,88,aaa})
		insertIndicator(true, 'weapon name: ' .. tostring(weapon_name), {255,111,88,aaa})
		insertIndicator(true, 'isReadyToFire: ' .. tostring(isReadyToFire), {255,111,88,aaa})
		insertIndicator(true, 'isscoped: ' .. tostring(isscoped), {255,111,88,aaa})
		insertIndicator(true, 'onground: ' .. tostring(onground), {255,111,88,aaa})
		insertIndicator(true, '2D distance: ' .. tostring(mydist), {255,111,88,aaa})
		insertIndicator(true, '3D distance: ' .. tostring(mybestDistance), {255,111,88,aaa})
		insertIndicator(true, 'fraction: ' .. tostring(myfraction), {255,111,88,aaa})
		insertIndicator(true, 'indicator table: ' .. tostring(#indicators), {133,255,0,aaa})
		insertIndicator(true, 'noscope: ' .. tostring(noscope), {133,255,0,aaa})
		insertIndicator(true, 'hasFired: ' .. tostring(hasFired), {133,255,0,aaa})
		insertIndicator(true, 'timefired: ' .. tostring(timefired), {133,255,0,aaa})
		insertIndicator(true, 'server time: ' .. tostring(timee), {133,255,0,aaa})
		insertIndicator(true, 'freestand angle: ' .. tostring(freeangle), {255,0,0,aaa})
		insertIndicator(true, 'final angle: ' .. tostring(angle), {255,0,0,aaa})
		insertIndicator(true, 'aa mode: ' .. tostring(mode), {255,0,0,aaa})
		insertIndicator(true, 'bestEntity: ' .. tostring(myBestEntity), {255,0,0,aaa})
		insertIndicator(true, 'local time: ' .. tostring(localtime), {255,0,0,aaa})
		insertIndicator(true, 'jeffs rbot: ' .. tostring(ui_get(menu.tap)), {134,17,244,aaa})
		if ui_get(menu.tap) then
			insertIndicator(true, 'ragebot enabled: ' .. tostring(ui_get(menu.hotkey)), {134,17,244,aaa})
			if ui_get(menu.hotkey) then
				insertIndicator(true, 'trigger magnet: ' .. tostring(ui_get(menu.triggermagnet)), {134,17,244,aaa})
				insertIndicator(true, 'hvh mode: ' .. tostring(ui_get(menu.hvhmode)), {134,17,244,aaa})
				insertIndicator(true, 'awall override: ' .. tostring(ui_get(menu.awall)), {134,17,244,aaa})
				insertIndicator(true, 'fakelag amount: ' .. tostring(ui_get(menu.fakelag_amount)), {134,17,244,aaa})
				insertIndicator(true, 'anti-aim enabled: ' .. tostring(my_vel < threshold), {134,17,244,aaa})
			end
		end
	end

	customResolver()
	playerListFuckery()
	drawFlir()
	antiaimArrow(my_vel, spacing)
	drawIndicators()
	quickPeeker(weapon_name)

	-- cleanup
	for k in pairs(indicators) do
		indicators[k] = nil
	end
	for k in pairs( indicators_clr) do
		indicators_clr[k] = nil
	end
	for k in pairs(debugtext) do
		debugtext[k] = nil
	end
	for k in pairs(debugtext_clr) do
		debugtext_clr[k] = nil
	end

end

local function fakelagfix(c)
	if ui_get(menu.tap) then
		if is_voice_recording(ivengineclient) then 
			c.allow_send_packet = c.chokedcommands >= 3
		else 
			c.allow_send_packet = c.chokedcommands >= ui_get(flag_limit)
		end
	end
end
local function on_resolver_reset()
	whitelist = {}
end
local function on_aim_fire(e)
	timefired = globals.curtime()
end
local function on_aim_miss(e)
	if ui_get(menu.custom_resolver_disable) and ui_get(menu.custom_resolver) then
		if e.reason ~= '?' then return end
		if not contains(whitelist, e.target) then
			table_insert(whitelist, e.target)
		end
	end
end
local function on_player_death(e)
	if client_userid_to_entindex(e.attacker) == get_local_player() then
		-- attempt at animations ( gave up because I cant do graphics )
		animation_start = globals.realtime()
	end

	if not ui_get(menu.deathsay) then return end
	if e.attacker == nil or e.attacker == get_local_player() or e.attacker == 0 then return end

	if client_userid_to_entindex(e.userid) == get_local_player() then
		local name = string.lower(entity_get_player_name(client_userid_to_entindex(e.attacker)))
		local location = entity_get_prop(client_userid_to_entindex(e.attacker), 'm_szLastPlaceName')
		local health = floor((entity_get_prop(client_userid_to_entindex(e.attacker), 'm_iHealth')) / 10) * 10
		if health <= 20 then health = 'low ' end
		local output = name .. ', ' .. location .. ', ' .. health .. 'hp'
		client.delay_call(ui_get(menu.deathsay_delay)/1000, client_exec, 'say_team ', output)
	end
end
local function player_connect_full(e)
	if client_userid_to_entindex(e.userid) == get_local_player() then
		timefired = 0
		whitelist = {}
	end
end
local function callbackHandle()
	-- menu hanble :DDD
	menuHandle()
	local czechbox = ui_get(menu.tap)

	local update_callback = czechbox and client.set_event_callback or client.unset_event_callback
	update_callback('player_connect_full', player_connect_full)
	update_callback('player_death', on_player_death)
	update_callback('paint', on_paint)
	update_callback('aim_fire', on_aim_fire)
	update_callback('setup_command', fakelagfix)
	update_callback('aim_miss', on_aim_miss)
end

ui_set_callback(menu.tap, callbackHandle)
ui_set_callback(menu.legitaa, menuHandle)
ui_set_callback(menu.weapons_presets, menuHandle)
ui_set_callback(menu.jumpcheck, menuHandle)
ui_set_callback(menu.hvhmode, menuHandle)
ui_set_callback(menu.manualaa, menuHandle)
ui_set_callback(menu.display_targeting, menuHandle)
ui_set_callback(menu.deathsay, menuHandle)
ui_set_callback(menu.max_fov_switch, menuHandle)
ui_set_callback(menu.custom_indicator, menuHandle)
ui_set_callback(menu.drawdebug, menuHandle)
ui_set_callback(menu.pbaim_switch, menuHandle)
ui_set_callback(menu.custom_resolver, menuHandle)
ui_set_callback(menu.fov_180, menuHandle)
ui_set_callback(menu.custom_resolver_disable, on_resolver_reset)
menuHandle()

-- We hate blacks & minorities
-- God, Honor, Homeland
-- Heil white Evropa
-- Heil victory
