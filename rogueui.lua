local mui = include("mui/mui")
local util = require( "modules/util" )
local serverdefs = include( "modules/serverdefs" )
local metadefs = include( "sim/metadefs" )
local cdefs = include("client_defs")
local modalDialog = include( "states/state-modal-dialog" )

local teamPreview = include("states/state-team-preview")
local options_dialog = include("hud/options_dialog")
local mainMenu = include("states/state-main-menu")
local mission_panel = include("hud/mission_panel")
local alarm_states = include("sim/alarm_states")
local mapScreen = include ("states/state-map-screen")
local loading = include ("states/state-loading")

local rogueui = {
   version = "0.1",
   -- Saved overridden function definitions.
   originals = {},
   -- Saved agents/programs selection.
   selected_agency = {},
   -- features
   settings = {
      disable_i_am_ready_screen = {
	 name = "Disable \"I am ready\" screen",
	 -- Tooltip
	 tip = "Skips the screen immediately following the agency selection.", 
	 -- Menu order
	 ordinal = 10,
	 -- Current value
	 value = true,
	 -- Optional enable/disable function
	 apply = nil
      },
      disable_intro_video = {
	 name = "Disable intro video",
	 tip = "Whether to play the intro movie.",
	 ordinal = 20,
	 value = true
      },
      disable_alarm_tip_popup = {
	 name = "Disable first alarm tip pop-up",
	 tip = "Whether to pop-up the begginer alarm tip in the first mission.",
	 ordinal = 25,
	 value = true
      },
      disable_confirm_mission_start = {
	 name = "Disable mission start confirmatiton",
	 tip = "Whether a mouse-click is required in-order to start the mission.",
	 ordinal = 27,
	 value = true
      },
      disable_mission_objectives = {
	 name = "Disable mission objectives popup",
	 tip = "Whether to pop-up the objectives at the start of a mission.",
	 ordinal = 30,
	 value = false
      },
      disable_mission_modal_conversations = {
	 name = "Disable mission dialog pop-ups",
	 tip = "Whether to display conversation pop-ups when on a mission.",
	 ordinal = 40,
	 value = false
      },
      disable_agent_voice_over = {
	 name = "Disable agency screen voice-over",
	 tip = "Whether to play central's agent narrations on the agency-screen.",
	 ordinal = 50,
	 value = false
      },
      disable_ingame_voice_over = {
	 name = "Disable all ingame voice-over",
	 tip = "Whether to play any voice-over.",
	 ordinal = 60,
	 value = false
      },
      disable_map_scripts = {
	 name = "Disable map scripts",
	 tip = "Whether to run campaign-scripts on the map-screen.",
	 ordinal = 70,
	 value = false
      },
      enable_save_selected_agency = {
	 name = "Remember selected agency",
	 tip = "Whether to save the selected agents/programs across games.",
	 ordinal = 120,
	 value = true
      }
   }
}

function rogueui:log (fmt, ...)
   log:write("[rogueui] " .. fmt, ...)
end

function rogueui.init ()
   rogueui:log("Initializing")
   local settingsFile = savefiles.getSettings ("settings")
   local saved = settingsFile.data.rogueui

   if not saved then
      settingsFile.data.rogueui = {}
      saved = settingsFile.data.rogueui

      for s, info in pairs (rogueui.settings) do
	 saved[s] = rogueui.settings[s].value
      end
      settingsFile:save ()
   end

   for s, info in pairs (rogueui.settings) do
      info.value = saved[s]
      if info.apply then
	 info.apply (info.value)
      end
   end
   rogueui.selected_agency = saved.selected_agency
end


-----------------------
-- UTILITY FUNCTIONS --
-----------------------

-- Return an active screen which was created from resource, or nil.
local function find_active_screen (resource)
   for i, screen in ipairs (mui.internals._activeScreens) do
      if screen:getLayer():getDebugName() == resource then
	 return screen
      end
   end
   return nil
end

-- Permanently modify a screen resource by side-effect using a
-- function with arguments.
local function modify_screen_resource (resource, fn, ...)
   -- Load and cache the resource if necessary.
   if not mui.internals._files[resource] then
      mui.internals._files[resource] = mui.loadUI(resource)
   end

   local ui = mui.internals._files[resource]
   assert (ui)
   fn (ui, ...)
   mui.parseUI (resource, ui)
end


------------------------------
-- OPTIONS MENU INTEGRATION --
------------------------------

rogueui.originals.options_dialog = {init = options_dialog.init}

local options_menu_modified = false

-- Wrapper for options_dialog.init
local function options_dialog_init (dialog, game)
   rogueui:log("Initializing options menu")

   if not options_menu_modified then
      modify_screen_resource ("options_dialog_screen.lua", modify_options_menu)
      options_menu_modified = true
   end

   rogueui.originals.options_dialog.init(dialog, game)

   -- Init menu from saved/default setting.
   for s, info in pairs (rogueui.settings) do
      dialog._screen.binder[s]:setChecked (info.value)
   end

   -- Set-up button handler
   local accept_button = dialog._screen.binder.acceptBtn.binder.btn
   local accept_callback = accept_button.onClick._fn

   -- FIXME: If the user cancels the accept, our settings are applied
   -- anyway.
   accept_button.onClick._fn =
      function (dialog)
	 accept_callback (dialog)

	 local settingsFile = savefiles.getSettings ("settings")
	 settingsFile.data.rogueui = {}
	 for s, info in pairs (rogueui.settings) do
	    info.value =  dialog._screen.binder[s]:isChecked()
	    settingsFile.data.rogueui[s] = info.value
	    if info.apply then
	       info.apply (info.value)
	    end
	 end
	 -- Reset agency, because the data field is cleared in
	 -- the original function.
	 settingsFile.data.rogueui.selected_agency = rogueui.selected_agency
	 settingsFile:save ()
      end
   
   local cancel_button = dialog._screen.binder.cancelBtn.binder.btn
   local cancel_callback = cancel_button.onClick._fn

   cancel_button.onClick._fn =
      function (dialog)
	 for s, info in pairs (rogueui.settings) do
	    dialog._screen.binder[s]:setChecked (info.value)
	 end
	 cancel_callback (dialog)
      end
end

options_dialog.init = options_dialog_init

local menu_tab =
   {
      {
	 name = "New Widget", isVisible = true, noInput = false,
	 anchor = 1, rotation = 0, x = 0, y = 0, w = 0, h = 0,
	 sx = 1, sy = 1, ctor = "group",
	 children = {
	    {
	       name = "tabButton", isVisible = true, noInput = false, anchor = 1,
	       rotation = 0, x = 82, xpx = true, y = 0, ypx = true, w = 160, wpx = true,
	       h = 28, hpx = true, sx = 1, sy = 1, ctor = "button",
	       clickSound = "SpySociety/HUD/menu/click",
	       hoverSound = "SpySociety/HUD/menu/rollover",
	       hoverScale = 1.1, str = "ROGUEUI",
	       halign = MOAITextBox.CENTER_JUSTIFY, valign = MOAITextBox.CENTER_JUSTIFY,
	       text_style = "font1_16_r",
	       images = {
		  {file = "tab.png", name = "inactive",},
		  {file = "tab_hover.png", name = "hover",},
		  {file = "tab_active.png", name = "active",},
		  {file = "tab_selected.png", name = "selected_inactive",},
		  {file = "tab_selected_hover.png", name = "selected_hover",},
		  {file = "tab_selected_active.png", name = "selected_active",},
	       },
	    },
	 },
      },
      {
	 name = "New Widget", isVisible = true, noInput = false, anchor = 1,
	 rotation = 0, x = 0, y = 0, w = 0, h = 0, sx = 1, sy = 1, ctor = "group",
	 children = {}
      },
   }

local menu_entry_template =
   {
      name = "",
      isVisible = true, noInput = false, anchor = 1, rotation = 0, x = 0,
      xpx = true, y = -50, ypx = true, w = 600, wpx = true, h = 32, hpx = true, sx = 1, sy = 1,
      tooltip = {str = "",},
      tooltipHeader = {str = "",},
      ctor = "checkbox",
      str = "",
      check_size = 32,
      halign = MOAITextBox.LEFT_JUSTIFY,
      valign = MOAITextBox.LEFT_JUSTIFY,
      text_style = "font1_16_r",
      color = {0.549019634723663, 1, 1, 1,},
      images = {
	 {file = "checkbox_no2.png", name = "no",},
	 {file = "checkbox_yes2.png", name = "yes",},
	 {file = "", name = "maybe",},
      },
   }

local menu_entry_header_template =
   {
      name = "header box", isVisible = true, noInput = false, anchor = 1,
      rotation = 0, x = 0, xpx = true, y = -60, ypx = true, w = 600, wpx = true,
      h = 1, hpx = true, sx = 1, sy = 1, ctor = "image",
      color = {0.219607844948769, 0.376470595598221, 0.376470595598221, 1,},
      images =
	 {{file = "white.png", name = "",
	   color = {0.219607844948769, 0.376470595598221, 0.376470595598221, 1,},},}
   }

function modify_options_menu(menu)
   -- Add a new tab and make the other ones less wide.
   local tabs = menu.widgets[5].tabs
   table.insert (tabs, menu_tab)
   local x = -246
   local w = 123
   for i = 1, 5 do
      local tabwidget = tabs[i][1].children[1]
      tabwidget.x = x
      tabwidget.w = w
      x = x + w
   end

   -- Sort settings for the menu
   local keys = {}
   for k, s in pairs (rogueui.settings) do
      table.insert(keys, k)
   end
   table.sort(
      keys,
      function (a, b) return rogueui.settings[a].ordinal < rogueui.settings[b].ordinal end)

   local y = -50
   local menu = tabs[5][2]
   assert (menu.ctor == "group" 
	      and menu.name == "New Widget")


   -- Create entries for all settings
   for i, s in ipairs (keys) do
      info = rogueui.settings[s]
      local entry = util.tcopy (menu_entry_template)
      local sep = util.tcopy (menu_entry_header_template)

      entry.name = s
      entry.str = info.name
      entry.tooltip.str = info.tip 
      entry.tooltipHeader.str = info.name

      if i == #keys then	-- Offset enable_save_selected_agency option
	 y = y - 16
      end
      entry.y = y
      table.insert (menu.children, entry)
      sep.y = y - 12
      table.insert (menu.children, sep)
      y = y - entry.h
   end   
end


---------------------------------
-- DISABLE_I_AM_READY_SCREEN   --
-- ENABLE_SAVE_SELECTED_AGENCY --
---------------------------------

-- Remember selected agency.
-- FIXME: Returning to the campaign screen does not save it.
local function save_selected_agency (dialog)
   local settingsFile = savefiles.getSettings ("settings")
   rogueui.selected_agency = { agents = dialog._selectedAgents,
			       loadouts = dialog._selectedLoadouts,
			       programs = dialog._selectedPrograms }
   settingsFile.data.rogueui.selected_agency = rogueui.selected_agency
   settingsFile:save()
end

rogueui.originals.teamPreview = {onLoad = teamPreview.onLoad}

teamPreview.onLoad = function (self)
   rogueui.originals.teamPreview.onLoad(self)

   local accept_callback = self._panel.binder.acceptBtn.onClick._fn
   self._panel.binder.acceptBtn.onClick._fn =
      function ()
	 if rogueui.settings.enable_save_selected_agency.value then
	    save_selected_agency (self)
	 end
	 local secs = cdefs.SECONDS
	 -- Speed-up fade in/out
	 cdefs.SECONDS = 1
	 accept_callback (self)
	 if rogueui.settings.disable_i_am_ready_screen.value then
	    local screen = find_active_screen ("modal-posttutorial.lua")
	    if screen then
	       screen.binder.closeBtn.onClick ()
	    end
	 end
	 cdefs.SECONDS = secs
      end
   
   if rogueui.settings.enable_save_selected_agency.value then
      -- Restore the saved agency.
      local agents = rogueui.selected_agency.agents
      local loadouts = rogueui.selected_agency.loadouts
      local progs = rogueui.selected_agency.programs
      local select_agent = self.screen:findWidget("agentListbox").onItemClicked._fn
      local select_loadout = self._panel.binder.agent1.binder.loadoutBtn1.binder.btn.onClick._fn
      local next_prog = self._panel.binder.program1.binder.arrowRight.binder.btn.onClick._fn

      for i = 1, 2 do
	 -- Select i'th program
	 local cur = self._selectedPrograms[i]
	 local first = cur
	 if cur ~= progs[i] then
	    repeat
	       next_prog (self, 1, i)
	       cur = self._selectedPrograms[i]
	    until cur == progs[i] or cur == first
	 end
	 -- Select i'th agent
	 select_agent (self, agents[i])
	 select_loadout (self, i, loadouts[i])
      end
   end
end



-------------------------
-- DISABLE_INTRO_VIDEO --
-------------------------

rogueui.originals.mainMenu = {onLoad = mainMenu.onLoad}

mainMenu.onLoad =
   function (self)
      -- Enabled here so revert to our setting
      rogueui.originals.mainMenu.onLoad (self)
      config.SHOW_MOVIE = not rogueui.settings.disable_intro_video.value
   end

rogueui.settings.disable_intro_video.apply =
   function (value)
      config.SHOW_MOVIE = not value
   end



------------------------------------
-- DISABLE_AGENT_VOICE_OVER --
------------------------------------

rogueui.originals.MOAIFmodDesigner = {playSound = MOAIFmodDesigner.playSound}

MOAIFmodDesigner.playSound =
   function (resource, category)
      if rogueui.settings.disable_ingame_voice_over.value and
	 string.match (resource, "/VoiceOver/")
      then return
      elseif rogueui.settings.disable_agent_voice_over.value and
	 category == "voice"
      then return
      end
      return rogueui.originals.MOAIFmodDesigner.playSound (resource, category)
   end



-----------------------------------
-- DISABLE_MISSION_MODAL_CONVERSATIONS --
-- DISABLE_MISSION_OBJECTIVES	 --
-- DISABLE_ALARM_TIP_POPUP	 --
-----------------------------------


rogueui.originals.mission_panel = { processEvent = mission_panel.processEvent }

mission_panel.processEvent =
   function (self, event)
      if type(event) == "table" then
	 if rogueui.settings.disable_mission_modal_conversations.value and
	    event.type == "modalConversation"
	 then return
	 elseif rogueui.settings.disable_mission_objectives.value and
	    event.type == "showMissionObjectives"
	 then return
	 elseif rogueui.settings.disable_alarm_tip_popup.value and
	    event.type == "showAlarmFirst"
	 then return
	 end
      end
      return rogueui.originals.mission_panel.processEvent (self, event)
   end


-------------------------
-- DISABLE_MAP_SCRIPTS --
-------------------------

rogueui.originals.mapScreen = { PlayIntroScript = mapScreen.PlayIntroScript }

mapScreen.PlayIntroScript =
   function (self)
      if rogueui.settings.disable_map_scripts.value then
	 return
      end
      return rogueui.originals.mapScreen.PlayIntroScript (self)
   end


----------------------------------
-- DISABLE_CONFIRM_MISSION_START --
----------------------------------

rogueui.originals.loading = {
   onLoad = loading.onLoad
}

loading.onLoad =
   function (self, fn, ...)
      rogueui.originals.loading.onLoad (self, fn, ...)

      if not rogueui.settings.disable_confirm_mission_start.value then
	 return
      end
      local t = self.loadThread
      while coroutine.status (t) ~= "dead"
	 and (not debug.getinfo (t, 1, "n")
		 or debug.getinfo (t, 1, "n").name ~= "waitForClick"
	      or debug.getlocal (t, 1, 1) ~= "done") do
	    coroutine.yield ()
      end
      -- state-loading.waitForClick.done = true
      if coroutine.status (t) ~= "dead" then
	 debug.setlocal(t, 1, 1, true)
      end
   end

return rogueui
