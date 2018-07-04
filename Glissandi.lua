reaper.ShowConsoleMsg("") -- TODO disable

-- Helper Functions
local function Msg(param)
  -- reaper.ShowConsoleMsg(tostring(param).."\n")
end

local function round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0)
  return math.floor(num * mult + 0.5) / mult
end

------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------ Lokasenna_GUI starts from here.... ----------------------------------
--loadfile("C:/Users/J/Documents/REAPER Media/Scripts/Lokasenna_GUI-master/Core.lua")()
--[[

	Lokasenna_GUI 2.0

	Core functionality

]]--

local function GUI_table ()

local GUI = {}

GUI.version = "2.0"




------------------------------------
-------- Error handling ------------
------------------------------------


-- A basic crash handler, just to add some helpful detail
-- to the Reaper error message.
GUI.crash = function (errObject)

    local by_line = "([^\r\n]*)\r?\n?"
    local trim_path = "[\\/]([^\\/]-:%d+:.+)$"
    local err = string.match(errObject, trim_path) or "Couldn't get error message."

    local trace = debug.traceback()
    local tmp = {}
    for line in string.gmatch(trace, by_line) do

        local str = string.match(line, trim_path) or line

        tmp[#tmp + 1] = str

    end

    local name = ({reaper.get_action_context()})[2]:match("([^/\\_]+)$")

    local ret = reaper.ShowMessageBox(name.." has crashed!\n\n"..
                                      "Would you like to have a crash report printed "..
                                      "to the Reaper console?",
                                      "Oops", 4)

    if ret == 6 then

        reaper.ShowConsoleMsg(  "Error: "..err.."\n"..
                                (GUI.error_message and tostring(GUI.error_message).."\n\n" or "\n") ..
                                "Stack traceback:\n\t"..table.concat(tmp, "\n\t", 2).."\n\n")
    end

    gfx.quit()
end



------------------------------------
-------- Main functions ------------
------------------------------------


-- All elements are stored here. Don't put them anywhere else, or
-- Main will never find them.
GUI.elms = {}

-- On each draw loop, only layers that are set to true in this table
-- will be redrawn; if false, it will just copy them from the buffer
-- Set [0] = true to redraw everything.
GUI.redraw_z = {}

-- Maintain a list of all GUI elements, sorted by their z order
-- Also removes any elements with z = -1, for automatically
-- cleaning things up.
GUI.elms_list = {}
GUI.z_max = 0
GUI.update_elms_list = function (init)

	local z_table = {}
	GUI.z_max = 0

	for key, __ in pairs(GUI.elms) do

		local z = GUI.elms[key].z or 5

		-- Delete elements if the script asked to
		if z == -1 then

			GUI.elms[key]:ondelete()
			GUI.elms[key] = nil

		else

			if z_table[z] then
				table.insert(z_table[z], key)

			else
				z_table[z] = {key}

			end

		end

		if init then

			GUI.elms[key]:init()

		end

		GUI.z_max = math.max(z, GUI.z_max)

	end

	GUI.elms_list = z_table

end

GUI.elms_hide = {}
GUI.elms_freeze = {}




GUI.Init = function ()
    xpcall( function()


        -- Create the window
        gfx.clear = reaper.ColorToNative(table.unpack(GUI.colors.wnd_bg))

        if not GUI.x then GUI.x = 0 end
        if not GUI.y then GUI.y = 0 end
        if not GUI.w then GUI.w = 640 end
        if not GUI.h then GUI.h = 480 end

        if GUI.anchor and GUI.corner then
            GUI.x, GUI.y = GUI.get_window_pos(  GUI.x, GUI.y, GUI.w, GUI.h,
                                                GUI.anchor, GUI.corner)
        end

        gfx.init(GUI.name, GUI.w, GUI.h, GUI.dock or 0, GUI.x, GUI.y)


        GUI.cur_w, GUI.cur_h = gfx.w, gfx.h

        -- Measure the window's title bar, in case we need it
        local __, __, wnd_y, __, __ = gfx.dock(-1, 0, 0, 0, 0)
        local __, gui_y = gfx.clienttoscreen(0, 0)
        GUI.title_height = gui_y - wnd_y


        -- Initialize a few values
        GUI.last_time = 0
        GUI.mouse = {

            x = 0,
            y = 0,
            cap = 0,
            down = false,
            wheel = 0,
            lwheel = 0

        }

        -- Store which element the mouse was clicked on.
        -- This is essential for allowing drag behaviour where dragging affects
        -- the element position.
        GUI.mouse_down_elm = nil
        GUI.rmouse_down_elm = nil
        GUI.mmouse_down_elm = nil

        -- Convert color presets from 0..255 to 0..1
        for i, col in pairs(GUI.colors) do
            col[1], col[2], col[3], col[4] =    col[1] / 255, col[2] / 255,
                                                col[3] / 255, col[4] / 255
        end

        -- Initialize the tables for our z-order functions
        GUI.update_elms_list(true)

        if GUI.exit then reaper.atexit(GUI.exit) end

        GUI.gfx_open = true

    end, GUI.crash)
end

GUI.Main = function ()
    xpcall( function ()

        if GUI.Main_Update_State() == 0 then return end

        GUI.Main_Update_Elms()

        -- If the user gave us a function to run, check to see if it needs to be
        -- run again, and do so.
        if GUI.func then

            local new_time = reaper.time_precise()
            if new_time - GUI.last_time >= (GUI.freq or 1) then
                GUI.func()
                GUI.last_time = new_time

            end
        end


        -- Maintain a list of elms and zs in case any have been moved or deleted
        GUI.update_elms_list()


        GUI.Main_Draw()

    end, GUI.crash)
end


GUI.Main_Update_State = function()

	-- Update mouse and keyboard state, window dimensions
    if GUI.mouse.x ~= gfx.mouse_x or GUI.mouse.y ~= gfx.mouse_y then

        GUI.mouse.lx, GUI.mouse.ly = GUI.mouse.x, GUI.mouse.y
        GUI.mouse.x, GUI.mouse.y = gfx.mouse_x, gfx.mouse_y

        -- Hook for user code
        if GUI.onmousemove then GUI.onmousemove() end

    else

        GUI.mouse.lx, GUI.mouse.ly = GUI.mouse.x, GUI.mouse.y

    end
	GUI.mouse.wheel = gfx.mouse_wheel
	GUI.mouse.cap = gfx.mouse_cap
	GUI.char = gfx.getchar()

	if GUI.cur_w ~= gfx.w or GUI.cur_h ~= gfx.h then
		GUI.cur_w, GUI.cur_h = gfx.w, gfx.h

		GUI.resized = true

        -- Hook for user code
        if GUI.onresize then GUI.onresize() end

	else
		GUI.resized = false
	end

	--	(Escape key)	(Window closed)		(User function says to close)
	--if GUI.char == 27 or GUI.char == -1 or GUI.quit == true then
	if (GUI.char == 27 and not (	GUI.mouse.cap & 4 == 4
								or 	GUI.mouse.cap & 8 == 8
								or 	GUI.mouse.cap & 16 == 16
                                or  GUI.escape_bypass))
			or GUI.char == -1
			or GUI.quit == true then

		return 0
	else
        if GUI.char == 27 and GUI.escape_bypass then GUI.escape_bypass = "close" end
		reaper.defer(GUI.Main)
	end

end


--[[
	Update each element's state, starting from the top down.

	This is very important, so that lower elements don't
	"steal" the mouse.


	This function will also delete any elements that have their z set to -1

	Handy for something like Label:fade if you just want to remove
	the faded element entirely

	***Don't try to remove elements in the middle of the Update
	loop; use this instead to have them automatically cleaned up***

]]--
GUI.Main_Update_Elms = function ()

    -- Disabled May 2/2018 to see if it was actually necessary
	-- GUI.update_elms_list()

	-- We'll use this to shorten each elm's update loop if the user did something
	-- Slightly more efficient, and averts any bugs from false positives
	GUI.elm_updated = false

	-- Check for the dev mode toggle before we get too excited about updating elms
	if  GUI.char == 282         and GUI.mouse.cap & 4 ~= 0
    and GUI.mouse.cap & 8 ~= 0  and GUI.mouse.cap & 16 ~= 0 then

		GUI.dev_mode = not GUI.dev_mode
		GUI.elm_updated = true
		GUI.redraw_z[0] = true

	end


    -- Mouse was moved? Clear the tooltip
    if GUI.tooltip and (GUI.mouse.x - GUI.mouse.lx > 0 or GUI.mouse.y - GUI.mouse.ly > 0) then

        GUI.mouseover_elm = nil
        GUI.cleartooltip()

    end


    -- Bypass for some skip logic to allow tabbing between elements (GUI.tab_to_next)
    if GUI.newfocus then
        GUI.newfocus.focus = true
        GUI.newfocus = nil
    end

	for i = 0, GUI.z_max do
		if  GUI.elms_list[i] and #GUI.elms_list[i] > 0
        and not (GUI.elms_hide[i] or GUI.elms_freeze[i]) then
			for __, elm in pairs(GUI.elms_list[i]) do

				if elm and GUI.elms[elm] then GUI.Update(GUI.elms[elm]) end

			end
		end

	end

	-- Just in case any user functions want to know...
	GUI.mouse.last_down = GUI.mouse.down
	GUI.mouse.last_r_down = GUI.mouse.r_down

end


GUI.Main_Draw = function ()

	-- Redraw all of the elements, starting from the bottom up.
	local w, h = GUI.cur_w, GUI.cur_h

	local need_redraw, global_redraw
	if GUI.redraw_z[0] then
		global_redraw = true
        GUI.redraw_z[0] = false
	else
		for z, b in pairs(GUI.redraw_z) do
			if b == true then
				need_redraw = true
				break
			end
		end
	end

	if need_redraw or global_redraw then

		-- All of the layers will be drawn to their own buffer (dest = z), then
		-- composited in buffer 0. This allows buffer 0 to be blitted as a whole
		-- when none of the layers need to be redrawn.

		gfx.dest = 0
		gfx.setimgdim(0, -1, -1)
		gfx.setimgdim(0, w, h)

		GUI.color("wnd_bg")
		gfx.rect(0, 0, w, h, 1)

		for i = GUI.z_max, 0, -1 do
			if  GUI.elms_list[i] and #GUI.elms_list[i] > 0
            and not GUI.elms_hide[i] then

				if global_redraw or GUI.redraw_z[i] then

					-- Set this before we redraw, so that elms can call a redraw
                    -- from their own :draw method. e.g. Labels fading out
					GUI.redraw_z[i] = false

					gfx.setimgdim(i, -1, -1)
					gfx.setimgdim(i, w, h)
					gfx.dest = i

					for __, elm in pairs(GUI.elms_list[i]) do
						if not GUI.elms[elm] then
                            reaper.MB(  "Error: Tried to update a GUI element that doesn't exist:"..
                                        "\nGUI.elms." .. tostring(elm), "Whoops!", 0)
                        end

                        -- Reset these just in case an element or some user code forgot to,
                        -- otherwise we get things like the whole buffer being blitted with a=0.2
                        gfx.mode = 0
                        gfx.set(0, 0, 0, 1)

						GUI.elms[elm]:draw()
					end

					gfx.dest = 0
				end

				gfx.blit(i, 1, 0, 0, 0, w, h, 0, 0, w, h, 0, 0)
			end
		end

        -- Draw developer hints if necessary
        if GUI.dev_mode then
            GUI.Draw_Dev()
        else
            GUI.Draw_Version()
        end

	end


    -- Reset them again, to be extra sure
	gfx.mode = 0
	gfx.set(0, 0, 0, 1)

	gfx.dest = -1
	gfx.blit(0, 1, 0, 0, 0, w, h, 0, 0, w, h, 0, 0)

	gfx.update()

end



-- Display the GUI version number
-- Set GUI.version = 0 to hide this
GUI.Draw_Version = function ()

	if not GUI.version then return 0 end

	local str = "Lokasenna_GUI "..GUI.version

	GUI.font("version")
	GUI.color("txt")

	local str_w, str_h = gfx.measurestr(str)

	--gfx.x = GUI.w - str_w - 4
	--gfx.y = GUI.h - str_h - 4
	gfx.x = gfx.w - str_w - 6
	gfx.y = gfx.h - str_h - 4

	gfx.drawstr(str)

end




------------------------------------
-------- Buffer functions ----------
------------------------------------


--[[
	We'll use this to let elements have their own graphics buffers
	to do whatever they want in.

	num	=	How many buffers you want, or 1 if not specified.

	Returns a table of buffers, or just a buffer number if num = 1

	i.e.

	-- Assign this element's buffer
	function GUI.my_element:new(.......)

	   ...new stuff...

	   my_element.buffers = GUI.GetBuffer(4)
	   -- or
	   my_element.buffer = GUI.GetBuffer()

	end

	-- Draw to the buffer
	function GUI.my_element:init()

		gfx.dest = self.buffers[1]
		-- or
		gfx.dest = self.buffer
		...draw stuff...

	end

	-- Copy from the buffer
	function GUI.my_element:draw()
		gfx.blit(self.buffers[1], 1, 0)
		-- or
		gfx.blit(self.buffer, 1, 0)
	end

]]--

-- Any used buffers will be marked as True here
GUI.buffers = {}

-- When deleting elements, their buffer numbers
-- will be added here for easy access.
GUI.freed_buffers = {}

GUI.GetBuffer = function (num)

	local ret = {}
	local prev

	for i = 1, (num or 1) do

		if #GUI.freed_buffers > 0 then

			ret[i] = table.remove(GUI.freed_buffers)

		else

			for j = (not prev and 1023 or prev - 1), 0, -1 do

				if not GUI.buffers[j] then
					ret[i] = j
					GUI.buffers[j] = true
					break
				end

			end

		end

	end

	return (#ret == 1) and ret[1] or ret

end

-- Elements should pass their buffer (or buffer table) to this
-- when being deleted
GUI.FreeBuffer = function (num)

	if type(num) == "number" then
		table.insert(GUI.freed_buffers, num)
	else
		for k, v in pairs(num) do
			table.insert(GUI.freed_buffers, v)
		end
	end

end




------------------------------------
-------- Element functions ---------
------------------------------------


--[[
    Wrapper for creating new elements, allows them to know their own name
    If called after the script window has opened, will also run their :init
    method.
    Can be given a user class directly by passing the class itself as 'elm',
    or if 'elm' is a string will look for a class in GUI[elm]

    Elements can be created in two ways:

        ex. Label:  name, z, x, y, caption[, shadow, font, color, bg]

    1. Function arguments

                name        type
        GUI.New("my_label", "Label", 1, 16, 16, "Hello!", true, 1, "red", "white")


    2. Keyed tables

        GUI.New({
            name = "my_label",
            type = "Label",
            z = 1,
            x = 16,
            y = 16,
            caption = "Hello!",
            shadow = true,
            font = 1,
            color = "red",
            bg = "white"
        })

    The only functional difference is that, when using a keyed table, additional parameters can
    be specified beyond the basic creation parameters given for that class. When using method 1,
    any additional parameters simply have to be specified afterward via:

        GUI.elms.my_label.shadow = false

    See the class documentation for more detail.
]]--
GUI.New = function (name, elm, ...)

    -- Support for passing all of the element params as a single keyed table
    local name = name
    local elm = elm
    local params
    if not elm and type(name) == "table" then

        -- Copy the table so we can pass it on
        params = name

        -- Grab the name and type
        elm = name.type
        name = name.name

    end


    -- Support for passing element classes directly as a table
    local elm = type(elm) == "string"   and GUI[elm]
                                        or  elm

    -- If we don't have an elm at this point there's a problem
    if not elm or type(elm) ~= "table" then
		reaper.ShowMessageBox(  "Unable to create element '"..tostring(name)..
                                "'.\nClass '"..tostring(elm).."' isn't available.",
                                "GUI Error", 0)
		GUI.quit = true
		return nil
	end

    -- If we're overwriting a previous elm, make sure it frees its buffers, etc
    if GUI.elms[name] and GUI.elms.type then GUI.elms[name]:delete() end

    GUI.elms[name] = params and elm:new(name, params) or elm:new(name, ...)
	--GUI.elms[name] = elm:new(name, params or ...)

	if GUI.gfx_open then GUI.elms[name]:init() end

    -- Return this so (I think) a bunch of new elements could be created
    -- within a table that would end up holding their names for easy bulk
    -- processing.

    return name

end


--  Create multiple elms at once
--[[
    Pass a table of keyed tables for each element:

    local elms = {}
    elms.my_label = {
        type = "Label"
        x = 16
        ...
    }
    elms.my_button = {
        type = "Button"
        ...
    }

    GUI.CreateElms(elms)


]]--
function GUI.CreateElms(elms)

    for name, params in pairs(elms) do
        params.name = name
        GUI.New(params)
    end

end


--	See if the any of the given element's methods need to be called
GUI.Update = function (elm)

	local x, y = GUI.mouse.x, GUI.mouse.y
	local x_delta, y_delta = x-GUI.mouse.lx, y-GUI.mouse.ly
	local wheel = GUI.mouse.wheel
	local inside = GUI.IsInside(elm, x, y)

	local skip = elm:onupdate() or false

    if GUI.resized then elm:onresize() end

	if GUI.elm_updated then
		if elm.focus then
			elm.focus = false
			elm:lostfocus()
		end
		skip = true
	end


	if skip then return end

    -- Left button
    if GUI.mouse.cap&1==1 then

        -- If it wasn't down already...
        if not GUI.mouse.last_down then


            -- Was a different element clicked?
            if not inside then
                if GUI.mouse_down_elm == elm then
                    -- Should already have been reset by the mouse-up, but safeguard...
                    GUI.mouse_down_elm = nil
                end
                if elm.focus then
                    elm.focus = false
                    elm:lostfocus()
                end
                return 0
            else
                if GUI.mouse_down_elm == nil then -- Prevent click-through

                    GUI.mouse_down_elm = elm

                    -- Double clicked?
                    if GUI.mouse.downtime
                    and reaper.time_precise() - GUI.mouse.downtime < 0.10
                    then

                        GUI.mouse.downtime = nil
                        GUI.mouse.dbl_clicked = true
                        elm:ondoubleclick()

                    elseif not GUI.mouse.dbl_clicked then

                        elm.focus = true
                        elm:onmousedown()

                    end

                    GUI.elm_updated = true
                end

                GUI.mouse.down = true
                GUI.mouse.ox, GUI.mouse.oy = x, y

                -- Where in the elm the mouse was clicked. For dragging stuff
                -- and keeping it in the place relative to the cursor.
                GUI.mouse.off_x, GUI.mouse.off_y = x - elm.x, y - elm.y

            end

        -- 		Dragging? Did the mouse start out in this element?
        elseif (x_delta ~= 0 or y_delta ~= 0)
        and     GUI.mouse_down_elm == elm then

            if elm.focus ~= false then

                GUI.elm_updated = true
                elm:ondrag(x_delta, y_delta)

            end
        end

    -- If it was originally clicked in this element and has been released
    elseif GUI.mouse.down and GUI.mouse_down_elm == elm then

            GUI.mouse_down_elm = nil

            if not GUI.mouse.dbl_clicked then elm:onmouseup() end

            GUI.elm_updated = true
            GUI.mouse.down = false
            GUI.mouse.dbl_clicked = false
            GUI.mouse.ox, GUI.mouse.oy = -1, -1
            GUI.mouse.off_x, GUI.mouse.off_y = -1, -1
            GUI.mouse.lx, GUI.mouse.ly = -1, -1
            GUI.mouse.downtime = reaper.time_precise()


    end


    -- Right button
    if GUI.mouse.cap&2==2 then

        -- If it wasn't down already...
        if not GUI.mouse.last_r_down then

            -- Was a different element clicked?
            if not inside then
                if GUI.rmouse_down_elm == elm then
                    -- Should have been reset by the mouse-up, but in case...
                    GUI.rmouse_down_elm = nil
                end
                --elm.focus = false
            else

                -- Prevent click-through
                if GUI.rmouse_down_elm == nil then

                    GUI.rmouse_down_elm = elm

                        -- Double clicked?
                    if GUI.mouse.r_downtime
                    and reaper.time_precise() - GUI.mouse.r_downtime < 0.20
                    then

                        GUI.mouse.r_downtime = nil
                        GUI.mouse.r_dbl_clicked = true
                        elm:onr_doubleclick()

                    elseif not GUI.mouse.r_dbl_clicked then

                        elm:onmouser_down()

                    end

                    GUI.elm_updated = true

                end

                GUI.mouse.r_down = true
                GUI.mouse.r_ox, GUI.mouse.r_oy = x, y
                -- Where in the elm the mouse was clicked. For dragging stuff
                -- and keeping it in the place relative to the cursor.
                GUI.mouse.r_off_x, GUI.mouse.r_off_y = x - elm.x, y - elm.y

            end


        -- 		Dragging? Did the mouse start out in this element?
        elseif (x_delta ~= 0 or y_delta ~= 0)
        and     GUI.rmouse_down_elm == elm then

            if elm.focus ~= false then

                elm:onr_drag(x_delta, y_delta)
                GUI.elm_updated = true

            end

        end

    -- If it was originally clicked in this element and has been released
    elseif GUI.mouse.r_down and GUI.rmouse_down_elm == elm then

        GUI.rmouse_down_elm = nil

        if not GUI.mouse.r_dbl_clicked then elm:onmouser_up() end

        GUI.elm_updated = true
        GUI.mouse.r_down = false
        GUI.mouse.r_dbl_clicked = false
        GUI.mouse.r_ox, GUI.mouse.r_oy = -1, -1
        GUI.mouse.r_off_x, GUI.mouse.r_off_y = -1, -1
        GUI.mouse.r_lx, GUI.mouse.r_ly = -1, -1
        GUI.mouse.r_downtime = reaper.time_precise()

    end



    -- Middle button
    if GUI.mouse.cap&64==64 then


        -- If it wasn't down already...
        if not GUI.mouse.last_m_down then


            -- Was a different element clicked?
            if not inside then
                if GUI.mmouse_down_elm == elm then
                    -- Should have been reset by the mouse-up, but in case...
                    GUI.mmouse_down_elm = nil
                end
            else
                -- Prevent click-through
                if GUI.mmouse_down_elm == nil then

                    GUI.mmouse_down_elm = elm

                    -- Double clicked?
                    if GUI.mouse.m_downtime
                    and reaper.time_precise() - GUI.mouse.m_downtime < 0.20
                    then

                        GUI.mouse.m_downtime = nil
                        GUI.mouse.m_dbl_clicked = true
                        elm:onm_doubleclick()

                    else

                        elm:onmousem_down()

                    end

                    GUI.elm_updated = true

              end

                GUI.mouse.m_down = true
                GUI.mouse.m_ox, GUI.mouse.m_oy = x, y
                GUI.mouse.m_off_x, GUI.mouse.m_off_y = x - elm.x, y - elm.y

            end



        -- 		Dragging? Did the mouse start out in this element?
        elseif (x_delta ~= 0 or y_delta ~= 0)
        and     GUI.mmouse_down_elm == elm then

            if elm.focus ~= false then

                elm:onm_drag(x_delta, y_delta)
                GUI.elm_updated = true

            end

        end

    -- If it was originally clicked in this element and has been released
    elseif GUI.mouse.m_down and GUI.mmouse_down_elm == elm then

        GUI.mmouse_down_elm = nil

        if not GUI.mouse.m_dbl_clicked then elm:onmousem_up() end

        GUI.elm_updated = true
        GUI.mouse.m_down = false
        GUI.mouse.m_dbl_clicked = false
        GUI.mouse.m_ox, GUI.mouse.m_oy = -1, -1
        GUI.mouse.m_off_x, GUI.mouse.m_off_y = -1, -1
        GUI.mouse.m_lx, GUI.mouse.m_ly = -1, -1
        GUI.mouse.m_downtime = reaper.time_precise()

    end



	-- If the mouse is hovering over the element
	if inside and not GUI.mouse.down and not GUI.mouse.r_down then
		elm:onmouseover()

        -- Initial mouseover an element
        if GUI.mouseover_elm ~= elm then
            GUI.mouseover_elm = elm
            GUI.mouseover_time = reaper.time_precise()

        -- Mouse was moved; reset the timer
        elseif x_delta > 0 or y_delta > 0 then

            GUI.mouseover_time = reaper.time_precise()

        -- Display a tooltip
        elseif (reaper.time_precise() - GUI.mouseover_time) >= GUI.tooltip_time then

            GUI.settooltip(elm.tooltip)

        end
		--elm.mouseover = true
	else
		--elm.mouseover = false

	end


	-- If the mousewheel's state has changed
	if inside and GUI.mouse.wheel ~= GUI.mouse.lwheel then

		GUI.mouse.inc = (GUI.mouse.wheel - GUI.mouse.lwheel) / 120

		elm:onwheel(GUI.mouse.inc)
		GUI.elm_updated = true
		GUI.mouse.lwheel = GUI.mouse.wheel

	end

	-- If the element is in focus and the user typed something
	if elm.focus and GUI.char ~= 0 then
		elm:ontype()
		GUI.elm_updated = true
	end

end


--[[	Return or change an element's value

	For use with external user functions. Returns the given element's current
	value or, if specified, sets a new one.	Changing values with this is often
	preferable to setting them directly, as most :val methods will also update
	some internal parameters and redraw the element when called.
]]--
GUI.Val = function (elm, newval)

	if not GUI.elms[elm] then return nil end

	if newval then
		GUI.elms[elm]:val(newval)
	else
		return GUI.elms[elm]:val()
	end

end


-- Are these coordinates inside the given element?
-- If no coords are given, will use the mouse cursor
GUI.IsInside = function (elm, x, y)

	if not elm then return false end

	local x, y = x or GUI.mouse.x, y or GUI.mouse.y

	return	(	x >= (elm.x or 0) and x < ((elm.x or 0) + (elm.w or 0)) and
				y >= (elm.y or 0) and y < ((elm.y or 0) + (elm.h or 0))	)

end


-- Returns the x,y that would center elm1 within elm2.
-- Axis can be "x", "y", or "xy".
GUI.center = function (elm1, elm2)

    local elm2 = elm2   and elm2
                        or  {x = 0, y = 0, w = GUI.cur_w, h = GUI.cur_h}

    if not (    elm2.x and elm2.y and elm2.w and elm2.h
            and elm1.x and elm1.y and elm1.w and elm1.h) then return end

    return (elm2.x + (elm2.w - elm1.w) / 2), (elm2.y + (elm2.h - elm1.h) / 2)


end




------------------------------------
-------- Prototype element ---------
----- + all default methods --------
------------------------------------


--[[
	All classes will use this as their template, so that
	elements are initialized with every method available.
]]--
GUI.Element = {}
function GUI.Element:new(name)

	local elm = {}
	if name then elm.name = name end
    self.z = 1

	setmetatable(elm, self)
	self.__index = self
	return elm

end

-- Called a) when the script window is first opened
-- 		  b) when any element is created via GUI.New after that
-- i.e. Elements can draw themselves to a buffer once on :init()
-- and then just blit/rotate/etc as needed afterward
function GUI.Element:init() end

-- Called whenever the element's z layer is told to redraw
function GUI.Element:draw() end

-- Ask for a redraw on the next update
function GUI.Element:redraw()
    GUI.redraw_z[self.z] = true
end

-- Called on every update loop, unless the element is hidden or frozen
function GUI.Element:onupdate() end

function GUI.Element:delete()

    self.ondelete(self)
    GUI.elms[self.name] = nil

end

-- Called when the element is deleted by GUI.update_elms_list() or :delete.
-- Use it for freeing up buffers and anything else memorywise that this
-- element was doing
function GUI.Element:ondelete() end


-- Set or return the element's value
-- Can be useful for something like a Slider that doesn't have the same
-- value internally as what it's displaying
function GUI.Element:val() end

-- Called on every update loop if the mouse is over this element.
function GUI.Element:onmouseover() end

-- Only called once; won't repeat if the button is held
function GUI.Element:onmousedown() end

function GUI.Element:onmouseup() end
function GUI.Element:ondoubleclick() end

-- Will continue being called even if you drag outside the element
function GUI.Element:ondrag() end

-- Right-click
function GUI.Element:onmouser_down() end
function GUI.Element:onmouser_up() end
function GUI.Element:onr_doubleclick() end
function GUI.Element:onr_drag() end

-- Middle-click
function GUI.Element:onmousem_down() end
function GUI.Element:onmousem_up() end
function GUI.Element:onm_doubleclick() end
function GUI.Element:onm_drag() end

function GUI.Element:onwheel() end
function GUI.Element:ontype() end


-- Elements like a Textbox that need to keep track of their focus
-- state will use this to e.g. update the text somewhere else
-- when the user clicks out of the box.
function GUI.Element:lostfocus() end

-- Called when the script window has been resized
function GUI.Element:onresize() end


------------------------------------
-------- Developer stuff -----------
------------------------------------


-- Print a string to the Reaper console.
GUI.Msg = function (str)
	reaper.ShowConsoleMsg(tostring(str).."\n")
end

-- Returns the specified parameters for a given element.
-- If nothing is specified, returns all of the element's properties.
-- ex. local str = GUI.elms.my_element:Msg("x", "y", "caption", "col_txt")
function GUI.Element:Msg(...)

    local arg = {...}

    if #arg == 0 then
        arg = {}
        for k in GUI.kpairs(self, "full") do
            arg[#arg+1] = k
        end
    end

    if not self or not self.type then return end
    local pre = tostring(self.name) .. "."
    local strs = {}

    for i = 1, #arg do

        strs[#strs + 1] = pre .. tostring(arg[i]) .. " = "

        if type(self[arg[i]]) == "table" then
            strs[#strs] = strs[#strs] .. "table:"
            strs[#strs + 1] = GUI.table_list(self[arg[i]], nil, 1)
        else
            strs[#strs] = strs[#strs] .. tostring(self[arg[i]])
        end

    end

    --reaper.ShowConsoleMsg( "\n" .. table.concat(strs, "\n") .. "\n")
    return table.concat(strs, "\n")

end


-- Developer mode settings
GUI.dev = {

	-- grid_a must be a multiple of grid_b, or it will
	-- probably never be drawn
	grid_a = 128,
	grid_b = 16

}


-- Draws a grid overlay and some developer hints
-- Toggled via Ctrl+Shift+Alt+Z, or by setting GUI.dev_mode = true
GUI.Draw_Dev = function ()

	-- Draw a grid for placing elements
	GUI.color("magenta")
	gfx.setfont("Courier New", 10)

	for i = 0, GUI.w, GUI.dev.grid_b do

		local a = (i == 0) or (i % GUI.dev.grid_a == 0)
		gfx.a = a and 1 or 0.3
		gfx.line(i, 0, i, GUI.h)
		gfx.line(0, i, GUI.w, i)
		if a then
			gfx.x, gfx.y = i + 4, 4
			gfx.drawstr(i)
			gfx.x, gfx.y = 4, i + 4
			gfx.drawstr(i)
		end

	end

    local str = "Mouse: "..math.modf(GUI.mouse.x)..", "..math.modf(GUI.mouse.y).." "
    local str_w, str_h = gfx.measurestr(str)
    gfx.x, gfx.y = GUI.w - str_w - 2, GUI.h - 2*str_h - 2

    GUI.color("black")
    gfx.rect(gfx.x - 2, gfx.y - 2, str_w + 4, 2*str_h + 4, true)

    GUI.color("white")
    gfx.drawstr(str)

    local snap_x, snap_y = GUI.nearestmultiple(GUI.mouse.x, GUI.dev.grid_b),
                           GUI.nearestmultiple(GUI.mouse.y, GUI.dev.grid_b)

    gfx.x, gfx.y = GUI.w - str_w - 2, GUI.h - str_h - 2
	gfx.drawstr(" Snap: "..snap_x..", "..snap_y)

	gfx.a = 1

    GUI.redraw_z[0] = true

end




------------------------------------
-------- Constants/presets ---------
------------------------------------


GUI.chars = {

	ESCAPE		= 27,
	SPACE		= 32,
	BACKSPACE	= 8,
	TAB			= 9,
	HOME		= 1752132965,
	END			= 6647396,
	INSERT		= 6909555,
	DELETE		= 6579564,
	PGUP		= 1885828464,
	PGDN		= 1885824110,
	RETURN		= 13,
	UP			= 30064,
	DOWN		= 1685026670,
	LEFT		= 1818584692,
	RIGHT		= 1919379572,

	F1			= 26161,
	F2			= 26162,
	F3			= 26163,
	F4			= 26164,
	F5			= 26165,
	F6			= 26166,
	F7			= 26167,
	F8			= 26168,
	F9			= 26169,
	F10			= 6697264,
	F11			= 6697265,
	F12			= 6697266

}


--[[	Font and color presets

	Can be set using the accompanying functions GUI.font
	and GUI.color. i.e.

	GUI.font(2)				applies the Header preset
	GUI.color("elm_fill")	applies the Element Fill color preset

	Colors are converted from 0-255 to 0-1 when GUI.Init() runs,
	so if you need to access the values directly at any point be
	aware of which format you're getting in return.

]]--
GUI.fonts = {

				-- Font, size, bold/italics/underline
				-- 				^ One string: "b", "iu", etc.
				{"Calibri", 32},	-- 1. Title
				{"Calibri", 20},	-- 2. Header
				{"Calibri", 16},	-- 3. Label
				{"Calibri", 16},	-- 4. Value
	version = 	{"Calibri", 12, "i"},

}


GUI.colors = {

	-- Element colors
	wnd_bg = {64, 64, 64, 255},			-- Window BG
	tab_bg = {56, 56, 56, 255},			-- Tabs BG
	elm_bg = {48, 48, 48, 255},			-- Element BG
	elm_frame = {96, 96, 96, 255},		-- Element Frame
	elm_fill = {64, 192, 64, 255},		-- Element Fill
	elm_outline = {32, 32, 32, 255},	-- Element Outline
	txt = {192, 192, 192, 255},			-- Text

	shadow = {0, 0, 0, 48},				-- Element Shadows
	faded = {0, 0, 0, 64},

	-- Standard 16 colors
	black = {0, 0, 0, 255},
	white = {255, 255, 255, 255},
	red = {255, 0, 0, 255},
	lime = {0, 255, 0, 255},
	blue =  {0, 0, 255, 255},
	yellow = {255, 255, 0, 255},
	cyan = {0, 255, 255, 255},
	magenta = {255, 0, 255, 255},
	silver = {192, 192, 192, 255},
	gray = {128, 128, 128, 255},
	maroon = {128, 0, 0, 255},
	olive = {128, 128, 0, 255},
	green = {0, 128, 0, 255},
	purple = {128, 0, 128, 255},
	teal = {0, 128, 128, 255},
	navy = {0, 0, 128, 255},

	none = {0, 0, 0, 0},


}


-- Global shadow size, in pixels
GUI.shadow_dist = 2


--[[
	How fast the caret in textboxes should blink, measured in GUI update loops.

	'16' looks like a fairly typical textbox caret.

	Because each On and Off redraws the textbox's Z layer, this can cause CPU
    issues in scripts with lots of drawing to do. In that case, raising it to
    24 or 32 will still look alright but require less redrawing.
]]--
GUI.txt_blink_rate = 16


-- Odds are you don't need too much precision here
-- If you do, just specify GUI.pi = math.pi() in your code
GUI.pi = 3.14159


-- Delay time when hovering over an element before displaying a tooltip
GUI.tooltip_time = 0.8


------------------------------------
-------- Table functions -----------
------------------------------------


--[[	Copy the contents of one table to another, since Lua can't do it natively

	Provide a second table as 'base' to use it as the basis for copying, only
	bringing over keys from the source table that don't exist in the base

	'depth' only exists to provide indenting for my debug messages, it can
	be left out when calling the function.
]]--
GUI.table_copy = function (source, base, depth)

	-- 'Depth' is only for indenting debug messages
	depth = ((not not depth) and (depth + 1)) or 0



	if type(source) ~= "table" then return source end

	local meta = getmetatable(source)
	local new = base or {}
	for k, v in pairs(source) do



		if type(v) == "table" then

			if base then
				new[k] = GUI.table_copy(v, base[k], depth)
			else
				new[k] = GUI.table_copy(v, nil, depth)
			end

		else
			if not base or (base and new[k] == nil) then

				new[k] = v
			end
		end

	end
	setmetatable(new, meta)

	return new

end


-- (For debugging)
-- Returns a string of the table's contents, indented to show nested tables
-- If 't' contains classes, or a lot of nested tables, etc, be wary of using larger
-- values for max_depth - this function will happily freeze Reaper for ten minutes.
GUI.table_list = function (t, max_depth, cur_depth)

    local ret = {}
    local n,v
    cur_depth = cur_depth or 0

    for n,v in pairs(t) do

                ret[#ret+1] = string.rep("\t", cur_depth) .. n .. " = "

                if type(v) == "table" then

                    ret[#ret] = ret[#ret] .. "table:"
                    if not max_depth or cur_depth <= max_depth then
                        ret[#ret+1] = GUI.table_list(v, max_depth, cur_depth + 1)
                    end

                else

                    ret[#ret] = ret[#ret] .. tostring(v)
                end

    end

    return table.concat(ret, "\n")

end


-- Compare the contents of one table to another, since Lua can't do it natively
-- Returns true if all of t_a's keys + and values match all of t_b's.
GUI.table_compare = function (t_a, t_b)

	if type(t_a) ~= "table" or type(t_b) ~= "table" then return false end

	local key_exists = {}
	for k1, v1 in pairs(t_a) do
		local v2 = t_b[k1]
		if v2 == nil or not GUI.table_compare(v1, v2) then return false end
		key_exists[k1] = true
	end
	for k2, v2 in pairs(t_b) do
		if not key_exists[k2] then return false end
	end

    return true

end


-- 	Sorting function adapted from: http://lua-users.org/wiki/SortedIteration
GUI.full_sort = function (op1, op2)

	-- Sort strings that begin with a number as if they were numbers,
	-- i.e. so that 12 > "6 apples"
	if type(op1) == "string" and string.match(op1, "^(%-?%d+)") then
		op1 = tonumber( string.match(op1, "^(%-?%d+)") )
	end
	if type(op2) == "string" and string.match(op2, "^(%-?%d+)") then
		op2 = tonumber( string.match(op2, "^(%-?%d+)") )
	end

	--if op1 == "0" then op1 = 0 end
	--if op2 == "0" then op2 = 0 end
	local type1, type2 = type(op1), type(op2)
	if type1 ~= type2 then --cmp by type
		return type1 < type2
	elseif type1 == "number" and type2 == "number"
		or type1 == "string" and type2 == "string" then
		return op1 < op2 --comp by default
	elseif type1 == "boolean" and type2 == "boolean" then
		return op1 == true
	else
		return tostring(op1) < tostring(op2) --cmp by address
	end

end


--[[	Allows "for x, y in pairs(z) do" in alphabetical/numerical order

	Copied from Programming In Lua, 19.3

	Call with f = "full" to use the full sorting function above, or
	use f to provide your own sorting function as per pairs() and ipairs()

]]--
GUI.kpairs = function (t, f)


	if f == "full" then
		f = GUI.full_sort
	end

	local a = {}
	for n in pairs(t) do table.insert(a, n) end

	table.sort(a, f)

	local i = 0      -- iterator variable
	local iter = function ()   -- iterator function

		i = i + 1

		if a[i] == nil then return nil
		else return a[i], t[a[i]]
		end

	end


	return iter
end


-- Accepts a table, and returns a table with the keys and values swapped, i.e.
-- {a = 1, b = 2, c = 3} --> {1 = "a", 2 = "b", 3 = "c"}
GUI.table_invert = function(t)

    local tmp = {}

    for k, v in pairs(t) do
        tmp[v] = k
    end

    return tmp

end


-- Looks through a table using ipairs (specify a different function with 'f') and returns
-- the first key whose value matches 'find'. 'find' is checked using string.match, so patterns
-- should be allowable. No (captures) though.

-- If you need to find multiple values in the same table, and each of them only occurs once,
-- it will be more efficient to just copy the table with GUI.table_invert and check by key.
GUI.table_find = function(t, find, f)
    local iter = f or ipairs

    for k, v in iter(t) do
        if string.match(tostring(v), find) then return k end
    end

end


-- Returns the length of a table, counting both indexed and keyed elements
GUI.table_length = function(t)

    local len = 0
    for k in pairs(t) do
        len = len + 1
    end

    return len

end
------------------------------------
-------- Text functions ------------
------------------------------------


--[[	Apply a font preset

	fnt			Font preset number
				or
				A preset table -> GUI.font({"Arial", 10, "i"})

]]--
GUI.font = function (fnt)

	local font, size, str = table.unpack( type(fnt) == "table"
                                            and fnt
                                            or  GUI.fonts[fnt])

	-- Different OSes use different font sizes, for some reason
	-- This should give a roughly equal size on Mac
	if string.find(reaper.GetOS(), "OSX") then
		size = math.floor(size * 0.7)
	end

	-- Cheers to Justin and Schwa for this
	local flags = 0
	if str then
		for i = 1, str:len() do
			flags = flags * 256 + string.byte(str, i)
		end
	end

	gfx.setfont(1, font, size, flags)

end


--[[	Prepares a table of character widths

	Iterates through all of the GUI.fonts[] presets, storing the widths
	of every printable ASCII character in a table.

	Accessable via:		GUI.txt_width[font_num][char_num]

	- Requires a window to have been opened in Reaper

	- 'get_txt_width' and 'word_wrap' will automatically run this
	  if it hasn't been run already; it may be rather clunky to use
	  on demand depending on what your script is doing, so it's
	  probably better to run this immediately after initiliazing
	  the window and then have the width table ready to use.
]]--

GUI.init_txt_width = function ()

	GUI.txt_width = {}
	local arr
	for k in pairs(GUI.fonts) do

		GUI.font(k)
		GUI.txt_width[k] = {}
		arr = {}

		for i = 1, 255 do

			arr[i] = gfx.measurechar(i)

		end

		GUI.txt_width[k] = arr

	end

end


-- Returns the total width (in pixels) for a given string and font
-- (as a GUI.fonts[] preset number or name)
-- Most of the time it's simpler to use gfx.measurestr(), but scripts
-- with a lot of text should use this instead - it's 10-12x faster.
GUI.get_txt_width = function (str, font)

	if not GUI.txt_width then GUI.init_txt_width() end

	local widths = GUI.txt_width[font]
	local w = 0
	for i = 1, string.len(str) do

		w = w + widths[		string.byte(	string.sub(str, i, i)	) ]

	end

	return w

end


-- Measures a string to see how much of it will it in the given width,
-- then returns both the trimmed string and the excess
GUI.fit_txt_width = function (str, font, w)

    local len = string.len(str)

    -- Assuming 'i' is the narrowest character, get an upper limit
    local max_end = math.floor( w / GUI.txt_width[font][string.byte("i")] )

    for i = max_end, 1, -1 do

        if GUI.get_txt_width( string.sub(str, 1, i), font ) < w then

           return string.sub(str, 1, i), string.sub(str, i + 1)

        end

    end

    -- Worst case: not even one character will fit
    -- If this actually happens you should probably rethink your choices in life.
    return "", str

end


--[[	Returns 'str' wrapped to fit a given pixel width

	str		String. Can include line breaks/paragraphs; they should be preserved.
	font	Font preset number
	w		Pixel width
	indent	Number of spaces to indent the first line of each paragraph
			(The algorithm skips tab characters and leading spaces, so
			use this parameter instead)

	i.e.	Blah blah blah blah		-> indent = 2 ->	  Blah blah blah blah
			blah blah blah blah							blah blah blah blah


	pad		Indent wrapped lines by the first __ characters of the paragraph
			(For use with bullet points, etc)

	i.e.	- Blah blah blah blah	-> pad = 2 ->	- Blah blah blah blah
			blah blah blah blah				  	 	  blah blah blah blah


	This function expands on the "greedy" algorithm found here:
	https://en.wikipedia.org/wiki/Line_wrap_and_word_wrap#Algorithm

]]--
GUI.word_wrap = function (str, font, w, indent, pad)

	if not GUI.txt_width then GUI.init_txt_width() end

	local ret_str = {}

	local w_left, w_word
	local space = GUI.txt_width[font][string.byte(" ")]

	local new_para = indent and string.rep(" ", indent) or 0

	local w_pad = pad   and GUI.get_txt_width( string.sub(str, 1, pad), font )
                        or 0
	local new_line = "\n"..string.rep(" ", math.floor(w_pad / space)	)


	for line in string.gmatch(str, "([^\n\r]*)[\n\r]*") do

		table.insert(ret_str, new_para)

		-- Check for leading spaces and tabs
		local leading, line = string.match(line, "^([%s\t]*)(.*)$")
		if leading then table.insert(ret_str, leading) end

		w_left = w
		for word in string.gmatch(line,  "([^%s]+)") do

			w_word = GUI.get_txt_width(word, font)
			if (w_word + space) > w_left then

				table.insert(ret_str, new_line)
				w_left = w - w_word

			else

				w_left = w_left - (w_word + space)

			end

			table.insert(ret_str, word)
			table.insert(ret_str, " ")

		end

		table.insert(ret_str, "\n")

	end

	table.remove(ret_str, #ret_str)
	ret_str = table.concat(ret_str)

	return ret_str

end


-- Draw the given string of the first color with a shadow
-- of the second color (at 45' to the bottom-right)
GUI.shadow = function (str, col1, col2)

	local x, y = gfx.x, gfx.y

	GUI.color(col2 or "shadow")
	for i = 1, GUI.shadow_dist do
		gfx.x, gfx.y = x + i, y + i
		gfx.drawstr(str)
	end

	GUI.color(col1)
	gfx.x, gfx.y = x, y
	gfx.drawstr(str)

end


-- Draws a string using the given text and outline color presets
GUI.outline = function (str, col1, col2)

	local x, y = gfx.x, gfx.y

	GUI.color(col2)

	gfx.x, gfx.y = x + 1, y + 1
	gfx.drawstr(str)
	gfx.x, gfx.y = x - 1, y + 1
	gfx.drawstr(str)
	gfx.x, gfx.y = x - 1, y - 1
	gfx.drawstr(str)
	gfx.x, gfx.y = x + 1, y - 1
	gfx.drawstr(str)

	GUI.color(col1)
	gfx.x, gfx.y = x, y
	gfx.drawstr(str)

end


--[[	Draw a background rectangle for the given string

	A solid background is necessary for blitting z layers
	on their own; antialiased text with a transparent background
	looks like complete shit. This function draws a rectangle 2px
	larger than your text on all sides.

	Call with your position, font, and color already set:

	gfx.x, gfx.y = self.x, self.y
	GUI.font(self.font)
	GUI.color(self.col)

	GUI.text_bg(self.text)

	gfx.drawstr(self.text)

	Also accepts an optional background color:
	GUI.text_bg(self.text, "elm_bg")

]]--
GUI.text_bg = function (str, col)

	local x, y = gfx.x, gfx.y
	local r, g, b, a = gfx.r, gfx.g, gfx.b, gfx.a

	col = col or "wnd_bg"

	GUI.color(col)

	local w, h = gfx.measurestr(str)
	w, h = w + 4, h + 4

	gfx.rect(gfx.x - 2, gfx.y - 2, w, h, true)

	gfx.x, gfx.y = x, y

	gfx.set(r, g, b, a)

end




------------------------------------
-------- Color functions -----------
------------------------------------


--[[	Apply a color preset

	col			Color preset string -> "elm_fill"
				or
				Color table -> {1, 0.5, 0.5[, 1]}
								R  G    B  [  A]
]]--
GUI.color = function (col)

	-- If we're given a table of color values, just pass it right along
	if type(col) == "table" then

		gfx.set(col[1], col[2], col[3], col[4] or 1)
	else
		gfx.set(table.unpack(GUI.colors[col]))
	end

end


-- Convert a hex color RRGGBB to 8-bit values R, G, B
GUI.hex2rgb = function (num)

	if string.sub(num, 1, 2) == "0x" then
		num = string.sub(num, 3)
	end

	local red = string.sub(num, 1, 2)
	local green = string.sub(num, 3, 4)
	local blue = string.sub(num, 5, 6)


	red = tonumber(red, 16) or 0
	green = tonumber(green, 16) or 0
	blue = tonumber(blue, 16) or 0

	return red, green, blue

end


-- Convert rgb[a] to hsv[a]; useful for gradients
-- Arguments/returns are given as 0-1
GUI.rgb2hsv = function (r, g, b, a)

	local max = math.max(r, g, b)
	local min = math.min(r, g, b)
	local chroma = max - min

	-- Dividing by zero is never a good idea
	if chroma == 0 then
		return 0, 0, max, (a or 1)
	end

	local hue
	if max == r then
		hue = ((g - b) / chroma) % 6
	elseif max == g then
		hue = ((b - r) / chroma) + 2
	elseif max == b then
		hue = ((r - g) / chroma) + 4
	else
		hue = -1
	end

	if hue ~= -1 then hue = hue / 6 end

	local sat = (max ~= 0) 	and	((max - min) / max)
							or	0

	return hue, sat, max, (a or 1)


end


-- ...and back the other way
GUI.hsv2rgb = function (h, s, v, a)

	local chroma = v * s

	local hp = h * 6
	local x = chroma * (1 - math.abs(hp % 2 - 1))

	local r, g, b
	if hp <= 1 then
		r, g, b = chroma, x, 0
	elseif hp <= 2 then
		r, g, b = x, chroma, 0
	elseif hp <= 3 then
		r, g, b = 0, chroma, x
	elseif hp <= 4 then
		r, g, b = 0, x, chroma
	elseif hp <= 5 then
		r, g, b = x, 0, chroma
	elseif hp <= 6 then
		r, g, b = chroma, 0, x
	else
		r, g, b = 0, 0, 0
	end

	local min = v - chroma

	return r + min, g + min, b + min, (a or 1)

end


--[[
	Returns the color for a given position on an HSV gradient
	between two color presets

	col_a		Tables of {R, G, B[, A]}, values from 0-1
	col_b

	pos			Position along the gradient, 0 = col_a, 1 = col_b

	returns		r, g, b, a

]]--
GUI.gradient = function (col_a, col_b, pos)

	local col_a = {GUI.rgb2hsv( table.unpack( type(col_a) == "table"
                                                and col_a
                                                or  GUI.colors(col_a) )) }
	local col_b = {GUI.rgb2hsv( table.unpack( type(col_b) == "table"
                                                and col_b
                                                or  GUI.colors(col_b) )) }

	local h = math.abs(col_a[1] + (pos * (col_b[1] - col_a[1])))
	local s = math.abs(col_a[2] + (pos * (col_b[2] - col_a[2])))
	local v = math.abs(col_a[3] + (pos * (col_b[3] - col_a[3])))

	local a = (#col_a == 4)
        and  (math.abs(col_a[4] + (pos * (col_b[4] - col_a[4]))))
        or  1

	return GUI.hsv2rgb(h, s, v, a)

end




------------------------------------
-------- Math/trig functions -------
------------------------------------


-- Round a number to the nearest integer (or optional decimal places)
GUI.round = function (num, places)

	if not places then
		return num > 0 and math.floor(num + 0.5) or math.ceil(num - 0.5)
	else
		places = 10^places
		return num > 0 and math.floor(num * places + 0.5)
                        or math.ceil(num * places - 0.5) / places
	end

end


-- Returns 'val', rounded to the nearest multiple of 'snap'
GUI.nearestmultiple = function (val, snap)

    local int, frac = math.modf(val / snap)
    return (math.floor( frac + 0.5 ) == 1 and int + 1 or int) * snap

end



-- Make sure num is between min and max
-- I think it will return the correct value regardless of what
-- order you provide the values in.
GUI.clamp = function (num, min, max)

	if min > max then min, max = max, min end
	return math.min(math.max(num, min), max)

end


-- Returns an ordinal string (i.e. 30 --> 30th)
GUI.ordinal = function (num)

	rem = num % 10
	num = GUI.round(num)
	if num == 1 then
		str = num.."st"
	elseif rem == 2 then
		str = num.."nd"
	elseif num == 13 then
		str = num.."th"
	elseif rem == 3 then
		str = num.."rd"
	else
		str = num.."th"
	end

	return str

end


--[[
	Takes an angle in radians (omit Pi) and a radius, returns x, y
	Will return coordinates relative to an origin of (0,0), or absolute
	coordinates if an origin point is specified
]]--
GUI.polar2cart = function (angle, radius, ox, oy)

	local angle = angle * GUI.pi
	local x = radius * math.cos(angle)
	local y = radius * math.sin(angle)


	if ox and oy then x, y = x + ox, y + oy end

	return x, y

end


--[[
	Takes cartesian coords, with optional origin coords, and returns
	an angle (in radians) and radius. The angle is given without reference
	to Pi; that is, pi/4 rads would return as simply 0.25
]]--
GUI.cart2polar = function (x, y, ox, oy)

	local dx, dy = x - (ox or 0), y - (oy or 0)

	local angle = math.atan(dy, dx) / GUI.pi
	local r = math.sqrt(dx * dx + dy * dy)

	return angle, r

end




------------------------------------
-------- Drawing functions ---------
------------------------------------


-- Improved roundrect() function with fill, adapted from mwe's EEL example.
GUI.roundrect = function (x, y, w, h, r, antialias, fill)

	local aa = antialias or 1
	fill = fill or 0

	if fill == 0 or false then
		gfx.roundrect(x, y, w, h, r, aa)
	else

		if h >= 2 * r then

			-- Corners
			gfx.circle(x + r, y + r, r, 1, aa)			-- top-left
			gfx.circle(x + w - r, y + r, r, 1, aa)		-- top-right
			gfx.circle(x + w - r, y + h - r, r , 1, aa)	-- bottom-right
			gfx.circle(x + r, y + h - r, r, 1, aa)		-- bottom-left

			-- Ends
			gfx.rect(x, y + r, r, h - r * 2)
			gfx.rect(x + w - r, y + r, r + 1, h - r * 2)

			-- Body + sides
			gfx.rect(x + r, y, w - r * 2, h + 1)

		else

			r = (h / 2 - 1)

			-- Ends
			gfx.circle(x + r, y + r, r, 1, aa)
			gfx.circle(x + w - r, y + r, r, 1, aa)

			-- Body
			gfx.rect(x + r, y, w - (r * 2), h)

		end

	end

end


-- Improved triangle() function with optional non-fill
GUI.triangle = function (fill, ...)

	-- Pass any calls for a filled triangle on to the original function
	if fill then

		gfx.triangle(...)

	else

		-- Store all of the provided coordinates into an array
		local coords = {...}

		-- Duplicate the first pair at the end, so the last line will
		-- be drawn back to the starting point.
		table.insert(coords, coords[1])
		table.insert(coords, coords[2])

		-- Draw a line from each pair of coords to the next pair.
		for i = 1, #coords - 2, 2 do

			gfx.line(coords[i], coords[i+1], coords[i+2], coords[i+3])

		end

	end

end




------------------------------------
-------- File/Storage functions ----
------------------------------------


--[[	Use when working with file paths if you need to add your own /s
    (Borrowed from X-Raym)

        Apr. 22/18 - Further reading leads me to believe that simply using
        '/' as a separator should work just fine on Windows, Mac, and Linux.
]]--
GUI.file_sep = string.match(reaper.GetOS(), "Win") and "\\" or "/"


-- To open files in their default app, or URLs in a browser
-- Copied from Heda; cheers!
GUI.open_file = function (path)

	local OS = reaper.GetOS()

    if OS == "OSX32" or OS == "OSX64" then
		os.execute('open "" "' .. path .. '"')
	else
		os.execute('start "" "' .. path .. '"')
	end

end


-- Saves the current script window parameters to an ExtState under the given section name
-- Returns dock, x, y, w, h
GUI.save_window_state = function (name)

    if not name then return end
    local state = {gfx.dock(-1, 0, 0, 0, 0)}
    reaper.SetExtState(name, "window", table.concat(state, ","), true)

    return table.unpack(state)

end


-- Looks for an ExtState containing saved window parameters and reapplies them
-- Call with noapply = true to just return the values
-- Returns dock, x, y, w, h
GUI.load_window_state = function (name, noapply)

    if not name then return end

    local str = reaper.GetExtState(name, "window")
    if not str or str == "" then return end

    local dock, x, y, w, h = string.match(str, "([^,]+),([^,]+),([^,]+),([^,]+),([^,]+)")
    if not (dock and x and y and w and h) then return end
    GUI.dock, GUI.x, GUI.y, GUI.w, GUI.h = dock, x, y, w, h

    -- Probably don't want these messing up where the user put the window
    GUI.anchor, GUI.corner = nil, nil

    return dock, x, y, w, h

end




------------------------------------
-------- Reaper functions ----------
------------------------------------


-- Checks for Reaper's "restricted permissions" script mode
-- GUI.script_restricted will be true if restrictions are in place
-- Call GUI.error_restricted to display an error message about restricted permissions
-- and exit the script.
if not os then

    GUI.script_restricted = true

    GUI.error_restricted = function()

        reaper.MB(  "This script tried to access a function that isn't available in Reaper's 'restricted permissions' mode." ..
                    "\n\nThe script was NOT necessarily doing something malicious - restricted scripts are unable " ..
                    "to access a number of basic functions such as reading and writing files." ..
                    "\n\nPlease let the script's author know, or consider running the script without restrictions if you feel comfortable.",
                    "Script Error", 0)

        GUI.quit = true
        GUI.error_message = "(Restricted permissions error)"

        return nil, "Error: Restricted permissions"

    end

    os = setmetatable({}, { __index = GUI.error_restricted })
    io = setmetatable({}, { __index = GUI.error_restricted })

end


-- Also might need to know this
GUI.SWS_exists = reaper.APIExists("CF_GetClipboardBig")



--[[
Returns x,y coordinates for a window with the specified anchor position

If no anchor is specified, it will default to the top-left corner of the screen.
	x,y		offset coordinates from the anchor position
	w,h		window dimensions
	anchor	"screen" or "mouse"
	corner	"TL"
			"T"
			"TR"
			"R"
			"BR"
			"B"
			"BL"
			"L"
			"C"
]]--
GUI.get_window_pos = function (x, y, w, h, anchor, corner)

	local ax, ay, aw, ah = 0, 0, 0 ,0

	local __, __, scr_w, scr_h = reaper.my_getViewport(x, y, x + w, y + h,
                                                       x, y, x + w, y + h, 1)

	if anchor == "screen" then
		aw, ah = scr_w, scr_h
	elseif anchor =="mouse" then
		ax, ay = reaper.GetMousePosition()
	end

	local cx, cy = 0, 0
	if corner then
		local corners = {
			TL = 	{0, 				0},
			T =		{(aw - w) / 2, 		0},
			TR = 	{(aw - w) - 16,		0},
			R =		{(aw - w) - 16,		(ah - h) / 2},
			BR = 	{(aw - w) - 16,		(ah - h) - 40},
			B =		{(aw - w) / 2, 		(ah - h) - 40},
			BL = 	{0, 				(ah - h) - 40},
			L =	 	{0, 				(ah - h) / 2},
			C =	 	{(aw - w) / 2,		(ah - h) / 2},
		}

		cx, cy = table.unpack(corners[corner])
	end

	x = x + ax + cx
	y = y + ay + cy

--[[

	Disabled until I can figure out the multi-monitor issue

	-- Make sure the window is entirely on-screen
	local l, t, r, b = x, y, x + w, y + h

	if l < 0 then x = 0 end
	if r > scr_w then x = (scr_w - w - 16) end
	if t < 0 then y = 0 end
	if b > scr_h then y = (scr_h - h - 40) end
]]--

	return x, y

end




------------------------------------
-------- Misc. functions -----------
------------------------------------


-- Why does Lua not have an operator for this?
GUI.xor = function(a, b)

   return (a or b) and not (a and b)

end


-- Display a tooltip
GUI.settooltip = function(str)

    if not str or str == "" then return end

    --Lua: reaper.TrackCtl_SetToolTip(string fmt, integer xpos, integer ypos, boolean topmost)
    --displays tooltip at location, or removes if empty string
    local x, y = gfx.clienttoscreen(0, 0)

    reaper.TrackCtl_SetToolTip(str, x + GUI.mouse.x + 16, y + GUI.mouse.y + 16, true)
    GUI.tooltip = str


end


-- Clear the tooltip
GUI.cleartooltip = function()

    reaper.TrackCtl_SetToolTip("", 0, 0, true)
    GUI.tooltip = nil

end


-- Tab forward (or backward, if Shift is down) to the next element with .tab_idx = number.
-- Removes focus from the given element, and gives it to the new element.
function GUI.tab_to_next(elm)

    if not elm.tab_idx then return end

    local inc = (GUI.mouse.cap & 8 == 8) and -1 or 1

    -- Get a list of all tab_idx elements, and a list of tab_idxs
    local indices, elms = {}, {}
    for _, element in pairs(GUI.elms) do
        if element.tab_idx then
            elms[element.tab_idx] = element
            indices[#indices+1] = element.tab_idx
        end
    end

    -- This is the only element with a tab index
    if #indices == 1 then return end

    -- Find the next element in the appropriate direction
    table.sort(indices)

    local new
    local cur = GUI.table_find(indices, elm.tab_idx)

    if cur == 1 and inc == -1 then
        new = #indices
    elseif cur == #indices and inc == 1 then
        new = 1
    else
        new = cur + inc
    end

    -- Move the focus
    elm.focus = false
    elm:lostfocus()
    elm:redraw()

    -- Can't set focus until the next GUI loop or Update will have problems
    GUI.newfocus = elms[indices[new]]
    elms[indices[new]]:redraw()

end
------------------------------------
-------- The End -------------------
------------------------------------


-- Make our table full of functions available to the parent script
return GUI

end
GUI = GUI_table()

----------------------------------------------------------------
----------------------------To here-----------------------------
----------------------------------------------------------------

--loadfile("C:/Users/J/Documents/REAPER Media/Scripts/Lokasenna_GUI-master/Classes/Class - Slider.lua")()
--[[	Lokasenna_GUI - Slider class

    For documentation, see this class's page on the project wiki:
    https://github.com/jalovatt/Lokasenna_GUI/wiki/Slider

    Creation parameters:
	name, z, x, y, w, caption, min, max, defaults[, inc, dir]

]]--


if not GUI then
	reaper.ShowMessageBox("Couldn't access GUI functions.\n\nLokasenna_GUI - Core.lua must be loaded prior to any classes.", "Library Error", 0)
	missing_lib = true
	return 0
end

GUI.Slider = GUI.Element:new()

function GUI.Slider:new(name, z, x, y, w, caption, min, max, defaults, inc, dir)

	local Slider = (not x and type(z) == "table") and z or {}

	Slider.name = name
	Slider.type = "Slider"

	Slider.z = Slider.z or z

	Slider.x = Slider.x or x
    Slider.y = Slider.y or y

	Slider.dir = Slider.dir or dir or "h"

    Slider.w, Slider.h = table.unpack(Slider.dir ~= "v"
                        and {Slider.w or w, 8}
                        or  {8, Slider.w or w} )

	Slider.caption = Slider.caption or caption
	Slider.bg = Slider.bg or "wnd_bg"

	Slider.font_a = Slider.font_a or 3
	Slider.font_b = Slider.font_b or 4

	Slider.col_txt = Slider.col_txt or "txt"
	Slider.col_hnd = Slider.col_hnd or "elm_frame"
	Slider.col_fill = Slider.col_fill or "elm_fill"



    if Slider.show_handles == nil then
        Slider.show_handles = true
    end
    if Slider.show_values == nil then
        Slider.show_values = true
    end

	Slider.cap_x = Slider.cap_x or 0
	Slider.cap_y = Slider.cap_y or 0

    local min = Slider.min or min
    local max = Slider.max or max

    if min > max then
        min, max = max, min
    elseif min == max then
        max = max + 1
    end

	if Slider.dir == "v" then
		min, max = max, min
	end

	Slider.min, Slider.max = min, max
    Slider.inc = inc or 1

    function Slider:formatretval(val)

        local decimal = tonumber(string.match(val, "%.(.*)") or 0)
        local places = decimal ~= 0 and string.len( decimal) or 0
        return string.format("%." .. places .. "f", val)

    end

    Slider.defaults = Slider.defaults or defaults

	-- If the user only asked for one handle
	if type(Slider.defaults) == "number" then Slider.defaults = {Slider.defaults} end



    function Slider:init_handles()

    	self.steps = math.abs(self.max - self.min) / self.inc

        -- Make sure the handles are all valid
        for i = 1, #self.defaults do
            self.defaults[i] = math.floor( GUI.clamp(0, self.defaults[i], self.steps) )
        end

        self.handles = {}
        local step
        for i = 1, #self.defaults do

            step = self.defaults[i]

            self.handles[i] = {}
            self.handles[i].default = (self.dir ~= "v" and step or (self.steps - step))
            self.handles[i].curstep = step
            self.handles[i].curval = step / self.steps
            self.handles[i].retval = self:formatretval( ((self.max - self.min) / self.steps)
                                                        * step + self.min)

        end

    end

    Slider:init_handles(defaults)

	GUI.redraw_z[Slider.z] = true

	setmetatable(Slider, self)
	self.__index = self
	return Slider

end


function GUI.Slider:init()

	self.buffs = self.buffs or GUI.GetBuffer(2)

    -- In case we were given a new set of handles without involving GUI.Val
    if not self.handles[1].default then self:init_handles() end

    local w, h = self.w, self.h

    -- Track
    gfx.dest = self.buffs[1]
    gfx.setimgdim(self.buffs[1], -1, -1)
    gfx.setimgdim(self.buffs[1], w + 4, h + 4)

	GUI.color("elm_bg")
	GUI.roundrect(2, 2, w, h, 4, 1, 1)
	GUI.color("elm_outline")
	GUI.roundrect(2, 2, w, h, 4, 1, 0)


    -- Handle
	local hw, hh = table.unpack(self.dir == "h" and {8, 16} or {16, 8})

	gfx.dest = self.buffs[2]
	gfx.setimgdim(self.buffs[2], -1, -1)
	gfx.setimgdim(self.buffs[2], 2 * hw + 4, hh + 2)

	GUI.color(self.col_hnd)
	GUI.roundrect(1, 1, hw, hh, 2, 1, 1)
	GUI.color("elm_outline")
	GUI.roundrect(1, 1, hw, hh, 2, 1, 0)

	local r, g, b, a = table.unpack(GUI.colors["shadow"])
	gfx.set(r, g, b, 1)
	GUI.roundrect(hw + 2, 1, hw, hh, 2, 1, 1)
	gfx.muladdrect(hw + 2, 1, hw + 2, hh + 2, 1, 1, 1, a, 0, 0, 0, 0 )

end


function GUI.Slider:ondelete()

	GUI.FreeBuffer(self.buffs)

end


function GUI.Slider:draw()

    local x, y, w, h = self.x, self.y, self.w, self.h

	-- Draw track
    gfx.blit(self.buffs[1], 1, 0, 1, 1, w + 2, h + 2, x - 1, y - 1)

    -- To avoid a LOT of copy/pasting for vertical sliders, we can
    -- just swap x-y and w-h to effectively "rotate" all of the math
    -- 90 degrees. 'horz' is here to help out in a few situations where
    -- the values need to be swapped back for drawing stuff.

    local horz = self.dir ~= "v"
    if not horz then x, y, w, h = y, x, h, w end

    -- Limit everything to be drawn within the square part of the track
    x, w = x + 4, w - 8

    -- Size of the handle
    local handle_w, handle_h = 8, h * 2
    local inc = w / self.steps
    local handle_y = y + (h - handle_h) / 2

    -- Get the handles' coordinates and the ends of the fill bar
    local min, max = self:updatehandlecoords(x, handle_w, handle_y, inc)

    self:drawfill(x, y, h, min, max, inc, horz)

    self:drawsliders(x, y, h, handle_w, handle_h, horz)
    if self.caption and self.caption ~= "" then self:drawcaption() end

end


function GUI.Slider:val(newvals)

	if newvals then

		if type(newvals) == "number" then newvals = {newvals} end

		for i = 1, #self.handles do

            self:setcurstep(i, newvals[i])

		end

		self:redraw()

	else

		local ret = {}
		for i = 1, #self.handles do
			--[[
			table.insert(ret, (self.dir ~= "v" 	and (self.handles[i].curstep + self.min)
												or	(self.steps - self.handles[i].curstep)))
			]]--
            table.insert(ret, tonumber(self.handles[i].retval))

		end

		if #ret == 1 then
			return ret[1]
		else
			table.sort(ret)
			return ret
		end

	end

end




------------------------------------
-------- Input methods -------------
------------------------------------


function GUI.Slider:onmousedown()

	-- Snap the nearest slider to the nearest value

	local mouse_val = self.dir == "h"
					and (GUI.mouse.x - self.x) / self.w
					or  (GUI.mouse.y - self.y) / self.h

    self.cur_handle = self:getnearesthandle(mouse_val)

	self:setcurval(self.cur_handle, GUI.clamp(mouse_val, 0, 1) )

	self:redraw()

end


function GUI.Slider:ondrag()

	local mouse_val, n, ln = table.unpack(self.dir == "h"
					and {(GUI.mouse.x - self.x) / self.w, GUI.mouse.x, GUI.mouse.lx}
					or  {(GUI.mouse.y - self.y) / self.h, GUI.mouse.y, GUI.mouse.ly}
	)

	local cur = self.cur_handle or 1

	-- Ctrl?
	local ctrl = GUI.mouse.cap&4==4

	-- A multiplier for how fast the slider should move. Higher values = slower
	--						Ctrl							Normal
	local adj = ctrl and math.max(1200, (8*self.steps)) or 150
	local adj_scale = (self.dir == "h" and self.w or self.h) / 150
	adj = adj * adj_scale

    self:setcurval(cur, GUI.clamp( self.handles[cur].curval + ((n - ln) / adj) , 0, 1 ) )

	self:redraw()

end


function GUI.Slider:onwheel()

	local mouse_val = self.dir == "h"
					and (GUI.mouse.x - self.x) / self.w
					or  (GUI.mouse.y - self.y) / self.h

	local inc = GUI.round( self.dir == "h" and GUI.mouse.inc
											or -GUI.mouse.inc )

    local cur = self:getnearesthandle(mouse_val)

	local ctrl = GUI.mouse.cap&4==4

	-- How many steps per wheel-step
	local fine = 1
	local coarse = math.max( GUI.round(self.steps / 30), 1)

	local adj = ctrl and fine or coarse

    self:setcurval(cur, GUI.clamp( self.handles[cur].curval + (inc * adj / self.steps) , 0, 1) )

	self:redraw()

end


function GUI.Slider:ondoubleclick()

    -- Ctrl+click - Only reset the closest slider to the mouse
	if GUI.mouse.cap & 4 == 4 then

		local mouse_val = (GUI.mouse.x - self.x) / self.w
		local small_diff, small_idx
		for i = 1, #self.handles do

			local diff = math.abs( self.handles[i].curval - mouse_val )
			if not small_diff or diff < small_diff then
				small_diff = diff
				small_idx = i
			end

		end

        self:setcurstep(small_idx, self.handles[small_idx].default)

    -- Reset all sliders
	else

		for i = 1, #self.handles do

            self:setcurstep(i, self.handles[i].default)

		end

	end

	self:redraw()

end




------------------------------------
-------- Drawing helpers -----------
------------------------------------


function GUI.Slider:updatehandlecoords(x, handle_w, handle_y, inc)

    local min, max

    for i = 1, #self.handles do

        local center = x + inc * self.handles[i].curstep
        self.handles[i].x, self.handles[i].y = center - (handle_w / 2), handle_y

        if not min or center < min then min = center end
        if not max or center > max then max = center end

    end

    return min, max

end


function GUI.Slider:drawfill(x, y, h, min, max, inc, horz)

    -- Get the color
	if (#self.handles > 1)
    or self.handles[1].curstep ~= self.handles[1].default then

        self:setfill()

    end

    -- Cap for the fill bar
    if #self.handles == 1 then
        min = x + inc * self.handles[1].default

        _ = horz and gfx.circle(min, y + (h / 2), h / 2 - 1, 1, 1)
                 or  gfx.circle(y + (h / 2), min, h / 2 - 1, 1, 1)

    end

    if min > max then min, max = max, min end

    _ = horz and gfx.rect(min, y + 1, max - min, h - 1, 1)
             or  gfx.rect(y + 1, min, h - 1, max - min, 1)

end


function GUI.Slider:setfill()

    -- If the user has given us two colors to make a gradient with
    if self.col_fill_a and #self.handles == 1 then

        -- Make a gradient,
        local col_a = GUI.colors[self.col_fill_a]
        local col_b = GUI.colors[self.col_fill_b]
        local grad_step = self.handles[1].curstep / self.steps

        local r, g, b, a = GUI.gradient(col_a, col_b, grad_step)

        gfx.set(r, g, b, a)

    else
        GUI.color(self.col_fill)
    end

end


function GUI.Slider:drawsliders(x, y, h, handle_w, handle_h, horz)

    GUI.color(self.col_txt)
    GUI.font(self.font_b)

    -- Drawing them in reverse order so overlaps match the shadow direction
    for i = #self.handles, 1, -1 do

        local handle_x, handle_y = GUI.round(self.handles[i].x) - 1, GUI.round(self.handles[i].y) - 1

        if self.show_values then

            local x, y =    handle_x,
                            y + h + h

            if horz then
                self:drawslidervalue(x, y, i)
            else
                self:drawslidervalue(y, x - 2, i)
            end

        end

        if self.show_handles then

            if horz then
                self:drawsliderhandle(handle_x, handle_y, handle_w, handle_h)
            else
                self:drawsliderhandle(handle_y, handle_x, handle_h, handle_w)
            end

        end

    end

end


function GUI.Slider:drawslidervalue(x, y, sldr)

    local output = self.handles[sldr].retval

    if self.output then
        local t = type(self.output)

        if t == "string" or t == "number" then
            output = self.output
        elseif t == "table" then
            output = self.output[output]
        elseif t == "function" then
            output = self.output(output)
        end
    end

    gfx.x, gfx.y = x, y

    GUI.text_bg(output, self.bg)
    gfx.drawstr(output, 1)

end


function GUI.Slider:drawsliderhandle(hx, hy, hw, hh)

    for j = 1, GUI.shadow_dist do

        gfx.blit(self.buffs[2], 1, 0, hw + 2, 0, hw + 2, hh + 2, hx + j, hy + j)

    end

    --gfx.blit(source, scale, rotation[, srcx, srcy, srcw, srch, destx, desty, destw, desth, rotxoffs, rotyoffs] )

    gfx.blit(self.buffs[2], 1, 0, 0, 0, hw + 2, hh + 2, hx, hy)

end


function GUI.Slider:drawcaption()

	GUI.font(self.font_a)

	local str_w, str_h = gfx.measurestr(self.caption)

	gfx.x = self.x + (self.w - str_w) / 2 + self.cap_x
	gfx.y = self.y - (self.dir ~= "v" and self.h or self.w) - str_h + self.cap_y
	GUI.text_bg(self.caption, self.bg)
	GUI.shadow(self.caption, self.col_txt, "shadow")

end




------------------------------------
-------- Slider helpers ------------
------------------------------------


function GUI.Slider:getnearesthandle(val)

	local small_diff, small_idx

	for i = 1, #self.handles do

		local diff = math.abs( self.handles[i].curval - val )

		if not small_diff or (diff < small_diff) then
			small_diff = diff
			small_idx = i

		end

	end

    return small_idx

end


function GUI.Slider:setcurstep(sldr, step)

    self.handles[sldr].curstep = step
    self.handles[sldr].curval = self.handles[sldr].curstep / self.steps
    self:setretval(sldr)


end


function GUI.Slider:setcurval(sldr, val)

    self.handles[sldr].curval = val
    self.handles[sldr].curstep = GUI.round(val * self.steps)
    self:setretval(sldr)

end


function GUI.Slider:setretval(sldr)

    local val = self.dir == "h" and self.inc * self.handles[sldr].curstep + self.min
                                or self.min - self.inc * self.handles[sldr].curstep

    self.handles[sldr].retval = self:formatretval(val)

end

--loadfile("C:/Users/J/Documents/REAPER Media/Scripts/Lokasenna_GUI-master/Classes/Class - Button.lua")()
--[[	Lokasenna_GUI - Button class

    For documentation, see this class's page on the project wiki:
    https://github.com/jalovatt/Lokasenna_GUI/wiki/TextEditor

    Creation parameters:
	name, z, x, y, w, h, caption, func[, ...]

]]--

if not GUI then
	reaper.ShowMessageBox("Couldn't access GUI functions.\n\nLokasenna_GUI - Core.lua must be loaded prior to any classes.", "Library Error", 0)
	missing_lib = true
	return 0
end


-- Button - New
GUI.Button = GUI.Element:new()
function GUI.Button:new(name, z, x, y, w, h, caption, func, ...)

	local Button = (not x and type(z) == "table") and z or {}

	Button.name = name
	Button.type = "Button"

	Button.z = Button.z or z

	Button.x = Button.x or x
    Button.y = Button.y or y
    Button.w = Button.w or w
    Button.h = Button.h or h

	Button.caption = Button.caption or caption

	Button.font = Button.font or 3
	Button.col_txt = Button.col_txt or "txt"
	Button.col_fill = Button.col_fill or "elm_frame"

	Button.func = Button.func or func or function () end
	Button.params = Button.params or {...}

	Button.state = 0

	GUI.redraw_z[Button.z] = true

	setmetatable(Button, self)
	self.__index = self
	return Button

end


function GUI.Button:init()

	self.buff = self.buff or GUI.GetBuffer()

	gfx.dest = self.buff
	gfx.setimgdim(self.buff, -1, -1)
	gfx.setimgdim(self.buff, 2*self.w + 4, self.h + 2)

	GUI.color(self.col_fill)
	GUI.roundrect(1, 1, self.w, self.h, 4, 1, 1)
	GUI.color("elm_outline")
	GUI.roundrect(1, 1, self.w, self.h, 4, 1, 0)


	local r, g, b, a = table.unpack(GUI.colors["shadow"])
	gfx.set(r, g, b, 1)
	GUI.roundrect(self.w + 2, 1, self.w, self.h, 4, 1, 1)
	gfx.muladdrect(self.w + 2, 1, self.w + 2, self.h + 2, 1, 1, 1, a, 0, 0, 0, 0 )


end


function GUI.Button:ondelete()

	GUI.FreeBuffer(self.buff)

end



-- Button - Draw.
function GUI.Button:draw()

	local x, y, w, h = self.x, self.y, self.w, self.h
	local state = self.state

	-- Draw the shadow if not pressed
	if state == 0 then

		for i = 1, GUI.shadow_dist do

			gfx.blit(self.buff, 1, 0, w + 2, 0, w + 2, h + 2, x + i - 1, y + i - 1)

		end

	end

	gfx.blit(self.buff, 1, 0, 0, 0, w + 2, h + 2, x + 2 * state - 1, y + 2 * state - 1)

	-- Draw the caption
	GUI.color(self.col_txt)
	GUI.font(self.font)

    local str = self.caption
    str = str:gsub([[\n]],"\n")

	local str_w, str_h = gfx.measurestr(str)
	gfx.x = x + 2 * state + ((w - str_w) / 2)
	gfx.y = y + 2 * state + ((h - str_h) / 2)
	gfx.drawstr(str)

end


-- Button - Mouse down.
function GUI.Button:onmousedown()

	self.state = 1
	self:redraw()

end


-- Button - Mouse up.
function GUI.Button:onmouseup()

	self.state = 0

	-- If the mouse was released on the button, run func
	if GUI.IsInside(self, GUI.mouse.x, GUI.mouse.y) then

		self.func(table.unpack(self.params))

	end
	self:redraw()

end

function GUI.Button:ondoubleclick()

	self.state = 0

	end


-- Button - Right mouse up
function GUI.Button:onmouser_up()

	if GUI.IsInside(self, GUI.mouse.x, GUI.mouse.y) and self.r_func then

		self.r_func(table.unpack(self.r_params))

	end
end


-- Button - Execute (extra method)
-- Used for allowing hotkeys to press a button
function GUI.Button:exec(r)

	if r then
		self.r_func(table.unpack(self.r_params))
	else
		self.func(table.unpack(self.params))
	end

end

--loadfile("C:/Users/J/Documents/REAPER Media/Scripts/Lokasenna_GUI-master/Classes/Class - Label.lua")()
--[[	Lokasenna_GUI - Label class.

    For documentation, see this class's page on the project wiki:
    https://github.com/jalovatt/Lokasenna_GUI/wiki/Label

    Creation parameters:
	name, z, x, y, caption[, shadow, font, color, bg]

]]--

if not GUI then
	reaper.ShowMessageBox("Couldn't access GUI functions.\n\nLokasenna_GUI - Core.lua must be loaded prior to any classes.", "Library Error", 0)
	missing_lib = true
	return 0
end


-- Label - New
GUI.Label = GUI.Element:new()
function GUI.Label:new(name, z, x, y, caption, shadow, font, color, bg)

	local label = (not x and type(z) == "table") and z or {}

	label.name = name
	label.type = "Label"

	label.z = label.z or z
	label.x = label.x or x
    label.y = label.y or y

    -- Placeholders; we'll get these at runtime
	label.w, label.h = 0, 0

	label.caption = label.caption   or caption
	label.shadow =  label.shadow    or shadow   or false
	label.font =    label.font      or font     or 2
	label.color =   label.color     or color    or "txt"
	label.bg =      label.bg        or bg       or "wnd_bg"


	GUI.redraw_z[label.z] = true

	setmetatable(label, self)
    self.__index = self
    return label

end


function GUI.Label:init(open)

    -- We can't do font measurements without an open window
    if gfx.w == 0 then return end

    self.buffs = self.buffs or GUI.GetBuffer(2)

    GUI.font(self.font)
    self.w, self.h = gfx.measurestr(self.caption)

    local w, h = self.w + 4, self.h + 4

    -- Because we might be doing this in mid-draw-loop,
    -- make sure we put this back the way we found it
    local dest = gfx.dest


    -- Keeping the background separate from the text to avoid graphical
    -- issues when the text is faded.
    gfx.dest = self.buffs[1]
    gfx.setimgdim(self.buffs[1], -1, -1)
    gfx.setimgdim(self.buffs[1], w, h)

    GUI.color(self.bg)
    gfx.rect(0, 0, w, h)

    -- Text + shadow
    gfx.dest = self.buffs[2]
    gfx.setimgdim(self.buffs[2], -1, -1)
    gfx.setimgdim(self.buffs[2], w, h)

    -- Text needs a background or the antialiasing will look like shit
    GUI.color(self.bg)
    gfx.rect(0, 0, w, h)

    gfx.x, gfx.y = 2, 2

    GUI.color(self.color)

	if self.shadow then
        GUI.shadow(self.caption, self.color, "shadow")
    else
        gfx.drawstr(self.caption)
    end

    gfx.dest = dest

end


function GUI.Label:fade(len, z_new, z_end, curve)

	self.z = z_new
	self.fade_arr = { len, z_end, reaper.time_precise(), curve or 3 }
	self:redraw()

end


function GUI.Label:draw()

    -- Font stuff doesn't work until we definitely have a gfx window
	if self.w == 0 then self:init() end

    local a = self.fade_arr and self:getalpha() or 1
    if a == 0 then return end

    gfx.x, gfx.y = self.x - 2, self.y - 2

    -- Background
    gfx.blit(self.buffs[1], 1, 0)

    gfx.a = a

    -- Text
    gfx.blit(self.buffs[2], 1, 0)

    gfx.a = 1

end


function GUI.Label:val(newval)

	if newval then
		self.caption = newval
		self:init()
		self:redraw()
	else
		return self.caption
	end

end


function GUI.Label:getalpha()

    local sign = self.fade_arr[4] > 0 and 1 or -1

    local diff = (reaper.time_precise() - self.fade_arr[3]) / self.fade_arr[1]
    diff = math.floor(diff * 100) / 100
    diff = diff^(math.abs(self.fade_arr[4]))

    local a = sign > 0 and (1 - (gfx.a * diff)) or (gfx.a * diff)

    self:redraw()

    -- Terminate the fade loop at some point
    if sign == 1 and a < 0.02 then
        self.z = self.fade_arr[2]
        self.fade_arr = nil
        return 0
    elseif sign == -1 and a > 0.98 then
        self.fade_arr = nil
    end

    return a

end
--loadfile("C:/Users/J/Documents/REAPER Media/Scripts/Lokasenna_GUI-master/Classes/Class - Options.lua")()
--[[	Lokasenna_GUI - Options classes

    This file provides two separate element classes:

    Radio       A list of options from which the user can only choose one at a time.
    Checklist   A list of options from which the user can choose any, all or none.

    Both classes take the same parameters on creation, and offer the same parameters
    afterward - their usage only differs when it comes to their respective :val methods.

    For documentation, see the class pages on the project wiki:
    https://github.com/jalovatt/Lokasenna_GUI/wiki/Checklist
    https://github.com/jalovatt/Lokasenna_GUI/wiki/Radio

    Creation parameters:
	name, z, x, y, w, h, caption, opts[, dir, pad]

]]--

if not GUI then
	reaper.ShowMessageBox("Couldn't access GUI functions.\n\nLokasenna_GUI - Core.lua must be loaded prior to any classes.", "Library Error", 0)
	missing_lib = true
	return 0
end


local Option = GUI.Element:new()

function Option:new(name, z, x, y, w, h, caption, opts, dir, pad)

	local option = (not x and type(z) == "table") and z or {}

	option.name = name
	option.type = "Option"

	option.z = option.z or z

	option.x = option.x or x
    option.y = option.y or y
    option.w = option.w or w
    option.h = option.h or h

	option.caption = option.caption or caption

    if option.frame == nil then
        option.frame = true
    end
	option.bg = option.bg or "wnd_bg"

	option.dir = option.dir or dir or "v"
	option.pad = option.pad or pad or 4

	option.col_txt = option.col_txt or "txt"
	option.col_fill = option.col_fill or "elm_fill"

	option.font_a = option.font_a or 2
	option.font_b = option.font_b or 3

    if option.shadow == nil then
        option.shadow = true
    end

    if option.shadow == nil then
        option.swap = false
    end

	-- Size of the option bubbles
	option.opt_size = option.opt_size or 20

	-- Parse the string of options into a table
    if not option.optarray then
        option.optarray = {}

        local opts = option.opts or opts

        if type(opts) == "table" then

            for i = 1, #opts do
                option.optarray[i] = opts[i]
            end

        else

            local tempidx = 1
            for word in string.gmatch(opts, '([^,]*)') do
                option.optarray[tempidx] = word
                tempidx = tempidx + 1
            end

        end
    end

	GUI.redraw_z[option.z] = true

	setmetatable(option, self)
    self.__index = self
    return option

end


function Option:init()

    -- Make sure we're not trying to use the base class.
    if self.type == "Option" then
        reaper.ShowMessageBox(  "'"..self.name.."' was initialized as an Option element,"..
                                "but Option doesn't do anything on its own!",
                                "GUI Error", 0)

        GUI.quit = true
        return

    end

	self.buff = self.buff or GUI.GetBuffer()

	gfx.dest = self.buff
	gfx.setimgdim(self.buff, -1, -1)
	gfx.setimgdim(self.buff, 2*self.opt_size + 4, 2*self.opt_size + 2)


    self:initoptions()


	if self.caption and self.caption ~= "" then
		GUI.font(self.font_a)
		local str_w, str_h = gfx.measurestr(self.caption)
		self.cap_h = 0.5*str_h
		self.cap_x = self.x + (self.w - str_w) / 2
	else
		self.cap_h = 0
		self.cap_x = 0
	end

end


function Option:draw()

	if self.frame then
		GUI.color("elm_frame")
		gfx.rect(self.x, self.y, self.w, self.h, 0)
	end

    if self.caption and self.caption ~= "" then self:drawcaption() end

    self:drawoptions()

end




------------------------------------
-------- Input helpers -------------
------------------------------------




function Option:getmouseopt()

    local len = #self.optarray

	-- See which option it's on
	local mouseopt = self.dir == "h"
                    and (GUI.mouse.x - (self.x + self.pad))
					or	(GUI.mouse.y - (self.y + self.cap_h + 1.5*self.pad) )

	mouseopt = mouseopt / ((self.opt_size + self.pad) * len)
	mouseopt = GUI.clamp( math.floor(mouseopt * len) + 1 , 1, len )

    return self.optarray[mouseopt] ~= "_" and mouseopt or false

end


------------------------------------
-------- Drawing methods -----------
------------------------------------


function Option:drawcaption()

    GUI.font(self.font_a)

    gfx.x = self.cap_x
    gfx.y = self.y - self.cap_h

    GUI.text_bg(self.caption, self.bg)

    GUI.shadow(self.caption, self.col_txt, "shadow")

end


function Option:drawoptions()

    local x, y, w, h = self.x, self.y, self.w, self.h

    local horz = self.dir == "h"
	local pad = self.pad

    -- Bump everything down for the caption
    y = y + ((self.caption and self.caption ~= "") and self.cap_h or 0) + 1.5 * pad

    -- Bump the options down more for horizontal options
    -- with the text on top
	if horz and self.caption ~= "" and not self.swap then
        y = y + self.cap_h + 2*pad
    end

	local opt_size = self.opt_size

    local adj = opt_size + pad

    local str, opt_x, opt_y

	for i = 1, #self.optarray do

		str = self.optarray[i]
		if str ~= "_" then

            opt_x = x + (horz   and (i - 1) * adj + pad
                                or  (self.swap  and (w - adj - 1)
                                                or   pad))

            opt_y = y + (i - 1) * (horz and 0 or adj)

			-- Draw the option bubble
            self:drawoption(opt_x, opt_y, opt_size, self:isoptselected(i))

            self:drawvalue(opt_x,opt_y, opt_size, str)

		end

	end

end


function Option:drawoption(opt_x, opt_y, size, selected)

    gfx.blit(   self.buff, 1,  0,
                selected and (size + 3) or 1, 1,
                size + 1, size + 1,
                opt_x, opt_y)

end


function Option:drawvalue(opt_x, opt_y, size, str)

    if not str or str == "" then return end

	GUI.font(self.font_b)

    local str_w, str_h = gfx.measurestr(str)

    if self.dir == "h" then

        gfx.x = opt_x + (size - str_w) / 2
        gfx.y = opt_y + (self.swap and (size + 4) or -size)

    else

        gfx.x = opt_x + (self.swap and -(str_w + 8) or 1.5*size)
        gfx.y = opt_y + (size - str_h) / 2

    end

    GUI.text_bg(str, self.bg)
    if #self.optarray == 1 or self.shadow then
        GUI.shadow(str, self.col_txt, "shadow")
    else
        GUI.color(self.col_txt)
        gfx.drawstr(str)
    end

end




------------------------------------
-------- Radio methods -------------
------------------------------------


GUI.Radio = {}
setmetatable(GUI.Radio, {__index = Option})

function GUI.Radio:new(name, z, x, y, w, h, caption, opts, dir, pad)

    local radio = Option:new(name, z, x, y, w, h, caption, opts, dir, pad)

    radio.type = "Radio"

    radio.retval, radio.state = 1, 1

    setmetatable(radio, self)
    self.__index = self
    return radio

end


function GUI.Radio:initoptions()

	local r = self.opt_size / 2

	-- Option bubble
	GUI.color(self.bg)
	gfx.circle(r + 1, r + 1, r + 2, 1, 0)
	gfx.circle(3*r + 3, r + 1, r + 2, 1, 0)
	GUI.color("elm_frame")
	gfx.circle(r + 1, r + 1, r, 0)
	gfx.circle(3*r + 3, r + 1, r, 0)
	GUI.color(self.col_fill)
	gfx.circle(3*r + 3, r + 1, 0.5*r, 1)


end


function GUI.Radio:val(newval)

	if newval then
		self.retval = newval
		self.state = newval
		self:redraw()
	else
		return self.retval
	end

end


function GUI.Radio:onmousedown()

	self.state = self:getmouseopt() or self.state

	self:redraw()

end


function GUI.Radio:onmouseup()

    -- Bypass option for GUI Builder
    if not self.focus then
        self:redraw()
        return
    end

	-- Set the new option, or revert to the original if the cursor
    -- isn't inside the list anymore
	if GUI.IsInside(self, GUI.mouse.x, GUI.mouse.y) then
		self.retval = self.state
	else
		self.state = self.retval
	end

    self.focus = false
	self:redraw()

end


function GUI.Radio:ondrag()

	self:onmousedown()

	self:redraw()

end


function GUI.Radio:onwheel()
--[[
	state = GUI.round(self.state +     (self.dir == "h" and 1 or -1)
                                    *   GUI.mouse.inc)
]]--

    self.state = self:getnextoption(    GUI.xor( GUI.mouse.inc > 0, self.dir == "h" )
                                        and -1
                                        or 1 )

	--if self.state < 1 then self.state = 1 end
	--if self.state > #self.optarray then self.state = #self.optarray end

	self.retval = self.state

	self:redraw()

end


function GUI.Radio:isoptselected(opt)

   return opt == self.state

end


function GUI.Radio:getnextoption(dir)

    local j = dir > 0 and #self.optarray or 1

    for i = self.state + dir, j, dir do

        if self.optarray[i] ~= "_" then
            return i
        end

    end

    return self.state

end




------------------------------------
-------- Checklist methods ---------
------------------------------------


GUI.Checklist = {}
setmetatable(GUI.Checklist, {__index = Option})

function GUI.Checklist:new(name, z, x, y, w, h, caption, opts, dir, pad)

    local checklist = Option:new(name, z, x, y, w, h, caption, opts, dir, pad)

    checklist.type = "Checklist"

    checklist.optsel = {}

    setmetatable(checklist, self)
    self.__index = self
    return checklist

end


function GUI.Checklist:initoptions()

	local size = self.opt_size

	-- Option bubble
	GUI.color("elm_frame")
	gfx.rect(1, 1, size, size, 0)
    gfx.rect(size + 3, 1, size, size, 0)

	GUI.color(self.col_fill)
	gfx.rect(size + 3 + 0.25*size, 1 + 0.25*size, 0.5*size, 0.5*size, 1)

end


function GUI.Checklist:val(newval)

	if newval then
		if type(newval) == "table" then
			for k, v in pairs(newval) do
				self.optsel[tonumber(k)] = v
			end
			self:redraw()
        elseif type(newval) == "boolean" and #self.optarray == 1 then

            self.optsel[1] = newval
            self:redraw()
		end
	else
        if #self.optarray == 1 then
            return self.optsel[1]
        else
            local tmp = {}
            for i = 1, #self.optarray do
                tmp[i] = not not self.optsel[i]
            end
            return tmp
        end
		--return #self.optarray > 1 and self.optsel or self.optsel[1]
	end

end


function GUI.Checklist:onmouseup()

    -- Bypass option for GUI Builder
    if not self.focus then
        self:redraw()
        return
    end

    local mouseopt = self:getmouseopt()

    if not mouseopt then return end

	self.optsel[mouseopt] = not self.optsel[mouseopt]

    self.focus = false
	self:redraw()

end


function GUI.Checklist:isoptselected(opt)

   return self.optsel[opt]

end

--loadfile("C:/Users/J/Documents/REAPER Media/Scripts/Lokasenna_GUI-master/Classes/Class - Knob.lua")()
--[[	Lokasenna_GUI - Knob class.

    For documentation, see this class's page on the project wiki:
    https://github.com/jalovatt/Lokasenna_GUI/wiki/Knob

    Creation parameters:
	name, z, x, y, w, caption, min, max, default,[ inc, vals]

]]--

if not GUI then
	reaper.ShowMessageBox("Couldn't access GUI functions.\n\nLokasenna_GUI - Core.lua must be loaded prior to any classes.", "Library Error", 0)
	missing_lib = true
	return 0
end

-- Knob - New.
GUI.Knob = GUI.Element:new()
function GUI.Knob:new(name, z, x, y, w, caption, min, max, default, inc, vals)

	local Knob = (not x and type(z) == "table") and z or {}

	Knob.name = name
	Knob.type = "Knob"

	Knob.z = Knob.z or z

	Knob.x = Knob.x or x
    Knob.y = Knob.y or y
    Knob.w = Knob.w or w
    Knob.h = Knob.w

	Knob.caption = Knob.caption or caption
	Knob.bg = Knob.bg or "wnd_bg"

    Knob.cap_x = Knob.cap_x or 0
    Knob.cap_y = Knob.cap_y or 0

	Knob.font_a = Knob.font_a or 3
	Knob.font_b = Knob.font_b or 4

	Knob.col_txt = Knob.col_txt or "txt"
	Knob.col_head = Knob.col_head or "elm_fill"
	Knob.col_body = Knob.col_body or "elm_frame"

	Knob.min = Knob.min or min
    Knob.max = Knob.max or max
    Knob.inc = Knob.inc or inc or 1


    Knob.steps = math.abs(Knob.max - Knob.min) / Knob.inc

    function Knob:formatretval(val)

        local decimal = tonumber(string.match(val, "%.(.*)") or 0)
        local places = decimal ~= 0 and string.len( decimal) or 0
        return string.format("%." .. places .. "f", val)

    end

	Knob.vals = Knob.vals or vals

	-- Determine the step angle
	Knob.stepangle = (3 / 2) / Knob.steps

	Knob.default = Knob.default or default
    Knob.curstep = Knob.default

	Knob.curval = Knob.curstep / Knob.steps

    Knob.retval = Knob:formatretval(
                ((Knob.max - Knob.min) / Knob.steps) * Knob.curstep + Knob.min
                                    )


	GUI.redraw_z[Knob.z] = true

	setmetatable(Knob, self)
	self.__index = self
	return Knob

end


function GUI.Knob:init()

	self.buff = self.buff or GUI.GetBuffer()

	gfx.dest = self.buff
	gfx.setimgdim(self.buff, -1, -1)

	-- Figure out the points of the triangle

	local r = self.w / 2
	local rp = r * 1.5
	local curangle = 0
	local o = rp + 1

	local w = 2 * rp + 2

	gfx.setimgdim(self.buff, 2*w, w)

	local side_angle = (math.acos(0.666667) / GUI.pi) * 0.9

	local Ax, Ay = GUI.polar2cart(curangle, rp, o, o)
    local Bx, By = GUI.polar2cart(curangle + side_angle, r - 1, o, o)
	local Cx, Cy = GUI.polar2cart(curangle - side_angle, r - 1, o, o)

	-- Head
	GUI.color(self.col_head)
	GUI.triangle(true, Ax, Ay, Bx, By, Cx, Cy)
	GUI.color("elm_outline")
	GUI.triangle(false, Ax, Ay, Bx, By, Cx, Cy)

	-- Body
	GUI.color(self.col_body)
	gfx.circle(o, o, r, 1)
	GUI.color("elm_outline")
	gfx.circle(o, o, r, 0)

	--gfx.blit(source, scale, rotation[, srcx, srcy, srcw, srch, destx, desty, destw, desth, rotxoffs, rotyoffs] )
	gfx.blit(self.buff, 1, 0, 0, 0, w, w, w + 1, 0)
	gfx.muladdrect(w + 1, 0, w, w, 0, 0, 0, GUI.colors["shadow"][4])

end


function GUI.Knob:ondelete()

	GUI.FreeBuffer(self.buff)

end


-- Knob - Draw
function GUI.Knob:draw()

	local x, y = self.x, self.y

	local r = self.w / 2
	local o = {x = x + r, y = y + r}


	-- Value labels
	if self.vals then self:drawvals(o, r) end

    if self.caption and self.caption ~= "" then self:drawcaption(o, r) end


	-- Figure out where the knob is pointing
	local curangle = (-5 / 4) + (self.curstep * self.stepangle)

	local blit_w = 3 * r + 2
	local blit_x = 1.5 * r

	-- Shadow
	for i = 1, GUI.shadow_dist do

		gfx.blit(   self.buff, 1, curangle * GUI.pi,
                    blit_w + 1, 0, blit_w, blit_w,
                    o.x - blit_x + i - 1, o.y - blit_x + i - 1)

	end

	-- Body
	gfx.blit(   self.buff, 1, curangle * GUI.pi,
                0, 0, blit_w, blit_w,
                o.x - blit_x - 1, o.y - blit_x - 1)

end


-- Knob - Get/set value
function GUI.Knob:val(newval)

	if newval then

        self:setcurstep(newval)

		self:redraw()

	else
		return self.retval
	end

end


-- Knob - Dragging.
function GUI.Knob:ondrag()

	local y = GUI.mouse.y
	local ly = GUI.mouse.ly

	-- Ctrl?
	local ctrl = GUI.mouse.cap&4==4

	-- Multiplier for how fast the knob turns. Higher = slower
	--					Ctrl	Normal
	local adj = ctrl and 1200 or 150

    self:setcurval( GUI.clamp(self.curval + ((ly - y) / adj), 0, 1) )

    --[[
	self.curval = self.curval + ((ly - y) / adj)
	if self.curval > 1 then self.curval = 1 end
	if self.curval < 0 then self.curval = 0 end



	self.curstep = GUI.round(self.curval * self.steps)

	self.retval = GUI.round(((self.max - self.min) / self.steps) * self.curstep + self.min)
    ]]--
	self:redraw()

end


-- Knob - Doubleclick
function GUI.Knob:ondoubleclick()
	--[[
	self.curstep = self.default
	self.curval = self.curstep / self.steps
	self.retval = GUI.round(((self.max - self.min) / self.steps) * self.curstep + self.min)
	]]--

    self:setcurstep(self.default)

	self:redraw()

end


-- Knob - Mousewheel
function GUI.Knob:onwheel()

	local ctrl = GUI.mouse.cap&4==4

	-- How many steps per wheel-step
	local fine = 1
	local coarse = math.max( GUI.round(self.steps / 30), 1)

	local adj = ctrl and fine or coarse

    self:setcurval( GUI.clamp( self.curval + (GUI.mouse.inc * adj / self.steps), 0, 1))

	self:redraw()

end



------------------------------------
-------- Drawing methods -----------
------------------------------------

function GUI.Knob:drawcaption(o, r)

    local str = self.caption

	GUI.font(self.font_a)
	local cx, cy = GUI.polar2cart(1/2, r * 2, o.x, o.y)
	local str_w, str_h = gfx.measurestr(str)
	gfx.x, gfx.y = cx - str_w / 2 + self.cap_x, cy - str_h / 2  + 8 + self.cap_y
	GUI.text_bg(str, self.bg)
	GUI.shadow(str, self.col_txt, "shadow")

end


function GUI.Knob:drawvals(o, r)

    for i = 0, self.steps do

        local angle = (-5 / 4 ) + (i * self.stepangle)

        -- Highlight the current value
        if i == self.curstep then
            GUI.color(self.col_head)
            GUI.font({GUI.fonts[self.font_b][1], GUI.fonts[self.font_b][2] * 1.2, "b"})
        else
            GUI.color(self.col_txt)
            GUI.font(self.font_b)
        end

        --local output = (i * self.inc) + self.min
        local output = self:formatretval( i * self.inc + self.min )

        if self.output then
            local t = type(self.output)

            if t == "string" or t == "number" then
                output = self.output
            elseif t == "table" then
                output = self.output[output]
            elseif t == "function" then
                output = self.output(output)
            end
        end

        -- Avoid any crashes from weird user data
        output = tostring(output)

        if output ~= "" then

            local str_w, str_h = gfx.measurestr(output)
            local cx, cy = GUI.polar2cart(angle, r * 2, o.x, o.y)
            gfx.x, gfx.y = cx - str_w / 2, cy - str_h / 2
            GUI.text_bg(output, self.bg)
            gfx.drawstr(output)
        end

    end

end




------------------------------------
-------- Value helpers -------------
------------------------------------

function GUI.Knob:setcurstep(step)

    self.curstep = step
    self.curval = self.curstep / self.steps
    self:setretval()

end


function GUI.Knob:setcurval(val)

    self.curval = val
    self.curstep = GUI.round(val * self.steps)
    self:setretval()

end


function GUI.Knob:setretval()

    self.retval = self:formatretval(self.inc * self.curstep + self.min)

end


-----------------------------------------------------------------------------------------------
---------------------------------------- Glissandi 0.1 ----------------------------------------
-- Author : Hans The Man, 4th July 2018

-- shared variables
local cur_take
local firstNoteRep, lastNoteRep -- bool
local firstNotePitch, lastNotePitch
local firstNoteStart, lastNoteStart, firstNoteEnd, lastNoteEnd
local firstNoteVel, lastNoteVel
local firstNoteLength
local firstNoteChan
-- from GUI input
local C, CSharp, D, DSharp, E, F, FSharp, G, GSharp, A, ASharp, B -- will cache slider values, num of rep
local sliderValues
local ease -- "easeIn", "easeOut"
-- local easeInType -- "Exponential" or "Power"
local easeInOutRange, easeInOutCurve, curveMax
local preview = false -- bool set from btn
-- from Calculations
local scaleDirection
local pitchScaleList, pitchScaleListSize
local tickMap, tickMapSize

------------------ FUNCTONS --------------------



-- logic functions
local function CreateFullPitchScaleList() -- index will be +1 of pitch (Lua...)
  local fullScale = {} -- from pitch 0 to 127
  local j = 1
  local subtract = 0
  for i = 1, 128 do
    -- check note values
    fullScale[i] = sliderValues[i-subtract]
    if j == 12 then
      subtract = subtract + 12
      j = 0
    end
  j = j + 1
  end
  return fullScale
end --TODO paste into other function!?

local function CreatePitchScaleList() -- will contain pitch duplicates
  pitchScaleList = {}
  local fullScale = CreateFullPitchScaleList() -- scale from 0 to 127
  local cur_pitch = firstNotePitch -- incr this val
  local i = 1 -- index val of last pitch-item added to list
  if firstNoteRep then
    pitchScaleList[1] = firstNotePitch
    i = 2
    Msg("First entry list : "..pitchScaleList[1])
  end
  -- For "up"
  if scaleDirection == "up" then
    cur_pitch = cur_pitch + 1 -- correct midi note
    local z = cur_pitch
    for y = z , (lastNotePitch - 1) do -- incr up til last note
      for b = 1, fullScale[cur_pitch+1] do -- adding rep
        pitchScaleList[i] = cur_pitch
        i = i +  1
      end
      cur_pitch = cur_pitch + 1
    end
    -- For 'down'
  elseif scaleDirection == "down" then
    Msg("Creating downwards scale!")
    -- i counting upwards.. index in list
    cur_pitch = cur_pitch - 1 -- counting downwards
    local z = cur_pitch
    for y = z ,(lastNotePitch + 1), -1 do -- incr down til last note
      for b = 1, fullScale[cur_pitch+1] do -- adding rep, index is +1 of pitch
        pitchScaleList[i] = cur_pitch
        i = i +  1
      end
      cur_pitch = cur_pitch - 1
    end
  end

  if lastNoteRep then pitchScaleList[i] = lastNotePitch
    -- Msg("Last entry list : "..pitchScaleList[i])
  end
  -- iterate pitchScaleList TODO uncomment
  pitchScaleListSize = 0
  for index, value in ipairs(pitchScaleList) do
    -- Msg("Index : "..index.." pitch : "..value)
    pitchScaleListSize = pitchScaleListSize + 1
  end
  Msg("size of scale list : "..pitchScaleListSize)
end -- end CreatePitchScaleList()

-- helper functions for CalckTickMap()
local function CalcPowTickMapEaseInOut()
  local num = 2^1.5
  -- Msg("Test math.pow 2 pow 1.5 ".. num)
end

local function CalcExpTickMapEaseInOut(type, anchorPointNoteEaseIn, anchorPointNoteEaseOut) --
  -- for ease in and out : two range and two curve knobs : add all
  -- terms together and scale!!! Problem : smalltick sizes ?
  -- avg it out, difficult cases when ranges are too close ?
  -- anchorPointNote same length as smallTicks
  -- nth term in Exponential
  local expTickMap = {} -- size of ticks
  local tempMap = {}
  local finalMap = {} -- position of ticks
  -- n = anchorPointNote + 1,
  -- curve def : high number bigger difference size first note and small notes.
  if type == "easeIn" then
    -- scale all terms added and make map :
    -- totalLength = calc exp terms and ad exp terms + nth term * rest of list
    expTickMap[1] = 1 -- map with size of ticks, not tick position
    -- first tick in map is distance from firstNoteStart to start of first note in scale
    for i = 2, anchorPointNoteEaseIn do
      expTickMap[i] = expTickMap[i-1] * (1/easeInOutCurve) -- calc first exp terms
    end
    local val = anchorPointNoteEaseIn + 1
    for i = val, pitchScaleListSize + 1 do -- uniform terms into array
      expTickMap[i] = expTickMap[i-1] --
    end
    local sizeTotal = 0 -- total size of all ticks added
    for i, val in ipairs(expTickMap) do
      sizeTotal = sizeTotal + val
    end
    Msg("Test length expo ticks "..#expTickMap)
    local scaleFactor = (lastNoteStart - firstNoteStart) / sizeTotal
    finalMap[1] = firstNoteStart + (expTickMap[1] * scaleFactor) -- pos first note in scale
    for i = 2, pitchScaleListSize do
      finalMap[i] = finalMap[i-1] + (expTickMap[i] * scaleFactor)
    end
  elseif type == "easeOut" then
    Msg("Exponential tick map generation for easeOut")
    expTickMap[1] = 1 -- map with size of ticks, not tick position
    -- first tick in map is distance from firstNoteStart to start of first note in scale
    for i = 2, anchorPointNoteEaseIn do
      expTickMap[i] = expTickMap[i-1] * (1/easeInOutCurve) -- calc first exp terms
    end
    local val = anchorPointNoteEaseIn + 1
    for i = val, pitchScaleListSize + 1 do -- uniform terms into array
      expTickMap[i] = expTickMap[i-1] --
    end
    local sizeTotal = 0 -- total size of all ticks added
    for i, val in ipairs(expTickMap) do
      sizeTotal = sizeTotal + val
    end
    Msg("Test length expo ticks "..#expTickMap)
    local scaleFactor = (lastNoteStart - firstNoteStart) / sizeTotal
    finalMap[pitchScaleListSize] = lastNoteStart - (expTickMap[1] * scaleFactor) -- pos of last note to be inserted..
    -- local v = pitchScaleListSize - 1
    for i = 2, pitchScaleListSize do
      finalMap[pitchScaleListSize-i+1] = finalMap[pitchScaleListSize-i+2] - (expTickMap[i] * scaleFactor)
    end

  end
  return finalMap
end

local function CalcTickMap() -- data from cached GUI input, M3
  -- calc normal uniform tickMap
  tickMap = {}
  tickMapSize = 0
  local anchorPointNoteEaseIn
  local anchorPointNoteEaseOut
  anchorPointNoteEaseIn = pitchScaleListSize * easeInOutRange
  Msg("Anchor Note ease in Num : "..anchorPointNoteEaseIn)
  anchorPointNoteEaseIn = round(anchorPointNoteEaseIn, 0)
  Msg("Anchor Note ease in Rounded: "..anchorPointNoteEaseIn)

  if anchorPointNoteEaseIn == 0 then
    Msg("gen uniform tickmap")
    local dist = lastNoteStart - firstNoteStart
    local incrVal = dist/(pitchScaleListSize + 1)
    for i = 1, pitchScaleListSize do
      tickMap[i] = firstNoteStart + incrVal * i
    end
    for i, tickStart in ipairs(tickMap) do
      tickMapSize = tickMapSize + 1
    end
  else
      tickMap = CalcExpTickMapEaseInOut(ease, anchorPointNoteEaseIn, anchorPointNoteEaseOut)-- easeIn part of map
  end
end

local function CacheData() -- M2
  cur_take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  -- Get notes from selection
  local firstNoteIdx = reaper.MIDI_EnumSelNotes(cur_take, -2)
  local lastNoteIdx = reaper.MIDI_EnumSelNotes(cur_take, firstNoteIdx)
  Msg("firstNote : "..firstNoteIdx.."\n".."lastNote : "..lastNoteIdx)
   -- caching selected notes data
  local retval, selected, muted, chan -- not used
  retval, selected, muted, firstNoteStart, firstNoteEnd, chan, firstNotePitch, firstNoteVel  =
  reaper.MIDI_GetNote(cur_take, firstNoteIdx)
  retval, selected, muted, lastNoteStart, lastNoteEnd, firstNoteChan, lastNotePitch, lastNoteVel  =
  reaper.MIDI_GetNote(cur_take, lastNoteIdx) -- calculating and caching first note length, will determine length of created notes.
  firstNoteLength = firstNoteEnd - firstNoteStart
  --caching start and end note repetition bools
  local valList = {}
  valList = GUI.Val("chk_rep")
  if valList[1] == nil then valList[1] = false end
  if valList[2] == nil then valList[2] = false end
  firstNoteRep = valList[1]
  lastNoteRep = valList[2]
  local valList2 = {}
  valList2 = GUI.Val("radio_ease")
  Msg(GUI.Val("radio_ease"))
  if GUI.Val("radio_ease") == 1 then ease = "easeIn"
  elseif GUI.Val("radio_ease") == 2 then ease = "easeOut" end
  Msg("ease in or out : "..ease)

  -- caching slider data into array
  sliderValues = {}
  for i = 1, 12 do
    sliderValues[i] = GUI.Val("slider_"..tostring(i))
  end
  -- caching slider data TODO maybe del
  -- C = GUI.Val("slider_1")
  -- CSharp = GUI.Val("slider_2")
  -- D = GUI.Val("slider_3")
  -- DSharp = GUI.Val("slider_4")
  -- E = GUI.Val("slider_5")
  -- F = GUI.Val("slider_6")
  -- FSharp = GUI.Val("slider_7")
  -- G = GUI.Val("slider_8")
  -- GSharp = GUI.Val("slider_9")
  -- A = GUI.Val("slider_10")
  -- ASharp = GUI.Val("slider_11")
  -- B = GUI.Val("slider_12")
  -- Caching and calc easeIn data
  -- Msg()
  -- if GUI.Val("radio_easeInOut_type") == 1 then easeInType = "Exponential"
  -- elseif GUI.Val("radio_easeInOut_type") == 2 then easeInType = "Power"
  -- elseif GUI.Val("radio_easeInOut_type") == 3 then easeInType = "Sine"
  -- end
  easeInType = "Exponential"
  easeOutType = "Exponential"
  easeInOutRange = GUI.Val("knob_easeInOut_range")
  Msg("Ease in amount : "..easeInOutRange)
  easeInOutCurve = GUI.Val("knob_easeInOut_curve") --

  Msg("Ease in curve : "..easeInOutCurve)
  -- Caching and calc scale direction
  if lastNotePitch > firstNotePitch then scaleDirection = "up" else scaleDirection = "down" end
  CreatePitchScaleList()
  CalcTickMap()
end

local function GenerateScale() -- only for inserting notes from map-arrays
  Msg("Generating scale!")
  Msg("First Note Length : "..firstNoteLength)
  Msg("Scale direction : "..scaleDirection)
  for i, pitch in ipairs(pitchScaleList) do
    reaper.MIDI_InsertNote(cur_take, true, false,
      tickMap[i], tickMap[i]+firstNoteLength, firstNoteChan, pitch, firstNoteVel, true)
  end
  reaper.MIDI_Sort(cur_take)
end

-- Buttons
local function Btn_CreateScale()
  reaper.ShowConsoleMsg("") -- Clear console
  Msg("CreateScale() function from btn")
  CacheData() -- and calc, basically doing everything!
  -- need also deselect first and last note from selection notes!
  script_title = "MIDI editor : Create scale direction "..scaleDirection
  reaper.Undo_BeginBlock()
  local item =  reaper.GetMediaItemTake_Item(cur_take)
  reaper.MarkTrackItemsDirty(reaper.GetMediaItemTake_Track(cur_take), item) -- for undo
  -- deselect selection
  reaper.MIDI_SelectAll(cur_take, false)
  GenerateScale() -- and select and sort all created notes
  reaper.Undo_EndBlock(script_title, -1) -- TODO fix, not working!
  Msg("after undo endbloc")
end

local function Btn_Preview()
  Msg("Preview btn pressed!")
  preview = not preview
end

-- Main and GUI functions
local function Main()
  local startTemp
  local char = gfx.getchar()
  if char ~= 27 and char ~= -1 then
    reaper.defer(Main)
  end
  if firstNoteStart and preview then
    Msg("Preview Mode")
    --complicated... can include new notes into selection!, so delete again by re-iterating selection!!
    --and by re-iterating selection generate new noteidx for first and last notes!
    --by choosing first note and changing pos loses selection ?
    -- 1. only from GUI
  end

end

local function InitializeGUI() -- M2
  GUI.name = "Glissandi Scale"
  GUI.x, GUI.y = 860, 20 -- offset from mouse pos when using mouse pos TODO : set 0 0 after debug
  GUI.w, GUI.h = 484, 596

  --TODO : use after debug
  --GUI.anchor, GUI.corner = "mouse", "C" -- open GUI on mouse pos
  -- future : saved options for popup pos

  GUI.New("label_1", "Label", 1, 30, 465, "C")
  GUI.New("label_2", "Label", 1, 30, 425, "C#/Db")
  GUI.New("label_3", "Label", 1, 30, 385, "D")
  GUI.New("label_4", "Label", 1, 30, 345, "D#/Eb")
  GUI.New("label_5", "Label", 1, 30, 305, "E")
  GUI.New("label_6", "Label", 1, 30, 265, "F")
  GUI.New("label_7", "Label", 1, 30, 225, "F#/Gb")
  GUI.New("label_8", "Label", 1, 30, 185, "G")
  GUI.New("label_9", "Label", 1, 30, 145, "G#/Ab")
  GUI.New("label_10", "Label", 1, 30, 105, "A")
  GUI.New("label_11", "Label", 1, 30, 65, "A#/Bb")
  GUI.New("label_12", "Label", 1, 30, 25, "B")

  GUI.New("slider_1", "Slider",  1, 156, 472, 48,     "", 0,   2,  1,    1)
  GUI.New("slider_2", "Slider",  1, 156, 432, 48,      "", 0,   2,  0,    1)
  GUI.New("slider_3", "Slider",  1, 156, 392, 48,     "", 0,   2,  0,    1)
  GUI.New("slider_4", "Slider",  1, 156, 352, 48,     "", 0,   2,  1,    1)
  GUI.New("slider_5", "Slider",  1, 156, 312, 48,     "", 0,   2,  0,    1)
  GUI.New("slider_6", "Slider",  1, 156, 272, 48,     "", 0,   2,  1,    1)
  GUI.New("slider_7", "Slider",  1, 156, 232, 48,     "", 0,   2,  1,    1)
  GUI.New("slider_8", "Slider",  1, 156, 192, 48,     "", 0,   2,  0,    1)
  GUI.New("slider_9", "Slider",  1, 156, 152, 48,     "", 0,   2,  1,    1)
  GUI.New("slider_10", "Slider",  1, 156, 112, 48,    "", 0,   2,  1,    1)
  GUI.New("slider_11", "Slider",  1, 156, 72, 48,    "", 0,   2,  0,    1)
  GUI.New("slider_12", "Slider",  1, 156, 32, 48,    "Repetition", 0,   2,  0,    1)

  local offsetY = -40
  GUI.New("chk_rep", "Checklist", 1, 240, 15 , 160, 80, "Repetitions", "First note repetition, Last note repetition")

  GUI.New("radio_ease", "Radio", 1, 240, 160+ offsetY , 160, 80, "Ease In/Out", "Ease In, Ease Out")
  -- Menu ease in curve type
  -- GUI.New("radio_easeInOut_type", "Radio", 1, 240, 260+ offsetY, 160, 100, "Curve Mode", "Exponential, Power, Sinusoidal")

  -- knobs, z layer 2
  local offsetX = -20
  local knob_offsetY = -90
  GUI.New("knob_easeInOut_range", "Knob", 2, 295+offsetX, 350+ offsetY + knob_offsetY, 30, "Range", 0, 1, 50, 0.01) -- percentage
  curveMax = 1.5 -- Exponential number : 1/curveMax
  GUI.New("knob_easeInOut_curve", "Knob", 2, 350+offsetX, 350+ offsetY+ knob_offsetY, 30, "   Curvature", 1, curveMax, 20, 0.01)
  -- GUI.Val("knob_easeIn_type", 1 )
  -- GUI.elms_hide[2] = false -- to hide z layer 2...
  -- buttons
  GUI.New("btn_createScale", "Button",  1, 180,  544, 84, 24, "Create Scale", Btn_CreateScale)
  GUI.color("elm_fill")
  GUI.elms.btn_createScale.color = "cyan"
  GUI.New("btn_preview", "Button",  10, 260,  544, 84, 24, "Preview Mode", Btn_Preview)
  GUI.elms_hide[10] = true -- to hide z layer 2...
  -- INI GUI
  GUI.Init()
  GUI.Main()
end

-- Starting script

InitializeGUI()
Main()
