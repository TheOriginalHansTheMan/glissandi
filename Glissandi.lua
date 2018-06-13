loadfile("C:/Users/J/Documents/REAPER Media/Scripts/Lokasenna_GUI-master/Core.lua")()
loadfile("C:/Users/J/Documents/REAPER Media/Scripts/Lokasenna_GUI-master/Classes/Class - Slider.lua")()
loadfile("C:/Users/J/Documents/REAPER Media/Scripts/Lokasenna_GUI-master/Classes/Class - Button.lua")()
loadfile("C:/Users/J/Documents/REAPER Media/Scripts/Lokasenna_GUI-master/Classes/Class - Label.lua")()
loadfile("C:/Users/J/Documents/REAPER Media/Scripts/Lokasenna_GUI-master/Classes/Class - Options.lua")()
loadfile("C:/Users/J/Documents/REAPER Media/Scripts/Lokasenna_GUI-master/Classes/Class - Knob.lua")()

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

-- Helper Functions
local function Msg(param)
  reaper.ShowConsoleMsg(tostring(param).."\n")
end

local function round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0)
  return math.floor(num * mult + 0.5) / mult
end

local function arraySize(array) -- TODO delete and use #
  local size = 0
  for i, v in ipairs(array) do
    size = size + 1
  end
  return size
end

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
      finalMap[pitchScaleListSize-i+1] = finalMap[pitchScaleListSize-i+1] - (expTickMap[i] * scaleFactor)
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
  Msg("Size of New tickMap : ".. arraySize(tickMap))
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

local function InitializeGUI() -- M1
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
  GUI.New("btn_createScale", "Button",  1, 160,  544, 84, 24, "Create Scale", Btn_CreateScale)
  GUI.color("elm_fill")
  GUI.elms.btn_createScale.color = "cyan"
  GUI.New("btn_preview", "Button",  1, 260,  544, 84, 24, "Preview Mode", Btn_Preview)
  -- INI GUI
  GUI.Init()
  GUI.Main()
end

-- Starting script
reaper.ShowConsoleMsg("") -- TODO disable
InitializeGUI()
Main()
