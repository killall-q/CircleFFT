function Initialize()
  mFFT = {}
  bands = tonumber(SKIN:GetVariable('Bands')) -- number of FFT bands
  dispR = tonumber(SKIN:GetVariable('DispR')) -- half of display width
  local travel = tonumber(SKIN:GetVariable('Travel')) -- percentage length of travel range, a cylinder circumscribing render sphere
  travelLen = math.sin(travel * math.pi / 2) * 2
  concavity = tonumber(SKIN:GetVariable('Concavity')) -- percentage concavity of travel range
  local r = { Min = tonumber(SKIN:GetVariable('RadiusMin')), Max = tonumber(SKIN:GetVariable('RadiusMax')) }
  rMin = math.cos(travel * math.pi / 2) * r.Min
  rRange = math.cos(travel * math.pi / 2) * r.Max - rMin
  theta = tonumber(SKIN:GetVariable('Theta')) -- pitch angle
  phi = tonumber(SKIN:GetVariable('Phi')) -- roll angle
  color = { SetColor(nil, SKIN:GetVariable('Color1')), SetColor(nil, SKIN:GetVariable('Color2')) }
  isAxial = SKIN:GetVariable('IsAxial') == '1' -- sort colors radially or axially
  isLocked = false -- lock hiding of mouseover controls
  if bands > 1 and not SKIN:GetMeasure('mFFT1') then
    GenMeasures()
    SKIN:Bang('!Refresh')
    return
  end
  for b = 0, bands - 1 do
    mFFT[b] = SKIN:GetMeasure('mFFT'..b)
  end
  os.remove(SKIN:GetVariable('@')..'Measures.inc')
  SetChannel(SKIN:GetVariable('Channel'))
  SKIN:Bang('[!SetOption AttackSlider X '..(tonumber(SKIN:GetVariable('Attack')) * 0.09)..'r][!SetOption DecaySlider X '..(tonumber(SKIN:GetVariable('Decay')) * 0.09)..'r][!SetOption SensSlider X '..(tonumber(SKIN:GetVariable('Sens')) * 0.9)..'r][!SetOption TravelSlider X '..(travel * 100 - 5)..'r][!SetOption TravelVal Text "'..(travel * 100)..'%"][!SetOption ConcavitySlider X '..(concavity * 100)..'r][!SetOption ConcavityVal Text "'..(concavity * 100)..'%"][!SetOption RadiusRange X '..(r.Min * 100)..'r][!SetOption RadiusRange W '..((r.Max - r.Min) * 100)..'][!SetOption RadiusMaxSlider X '..((r.Max - r.Min) * 100)..'r][!SetOption RadiusMinVal Text "'..(r.Min * 100)..'%"][!SetOption RadiusMaxVal Text "'..(r.Max * 100)..'%"][!SetOption ThickSlider X '..(tonumber(SKIN:GetVariable('Thick')) * 5 - 5)..'r][!SetOption Sort'..(isAxial and 1 or 0)..' SolidColor FF0000][!SetOption Sort'..(isAxial and 1 or 0)..' MouseLeaveAction "!SetOption #*CURRENTSECTION*# SolidColor FF0000"]')
  if SKIN:GetVariable('ShowSet') == '1' then
    SKIN:Bang('[!SetOption Render Shape "Rectangle 0,0,'..math.max(dispR * 2, 250)..','..math.max(dispR * 2, 430)..'|StrokeWidth 0|Extend Hover"][!ShowMeterGroup Set][!WriteKeyValue Variables ShowSet 0 "#@#Settings.inc"]')
  end
end

function Update()
  local sinTheta, cosTheta, sinPhi, cosPhi, degPhi, circle = math.sin(theta), math.cos(theta), math.sin(phi), math.cos(phi), math.deg(phi), {}
  for b = 1, bands do
    local FFT = mFFT[b - 1]:GetValue()
    local r = (bands - b - 1) / (bands - 1) * rRange + rMin
    local axialPos = (FFT - 0.5) * (travelLen + math.cos(r * 1.5708) * concavity)
    -- Find distance of circle center from POV using law of cosines
    local centerDist = (axialPos^2 + 4 - axialPos * cosTheta * 4)^0.5
    local hypo = sinTheta * axialPos
    local rX = r * 2 / centerDist * dispR
    circle[b] = { axialPos, FFT, b, (sinPhi * hypo + 1) * dispR, (-cosPhi * hypo + 1) * dispR, rX, math.cos(3.1416 - math.asin(sinTheta / centerDist * 2)) * rX }
  end
  table.sort(circle, function(c, d) return c[1] < d[1] end)
  for b = 1, bands do
    local val = isAxial and b / bands or circle[b][3] / bands
    SKIN:Bang('!SetOption Render Shape'..(0 < cosTheta and b + 1 or bands - b + 2)..' "Ellipse '..circle[b][4]..','..circle[b][5]..','..circle[b][6]..','..circle[b][7]..'|Rotate '..degPhi..'|Extend Attr|Stroke Color '..BlendColor(circle[b][2] < 0.1 and (1 - (1 - circle[b][2] * 10)^2) * val or val)..'"')
  end
end

function Pitch(n, reset)
  theta = reset and 0 or math.floor((theta + n) % 6.3 * 10 + 0.5) * 0.1
  SKIN:Bang('!WriteKeyValue Variables Theta '..theta..' "#@#Settings.inc"')
end

function Roll(n, reset)
  phi = reset and 0 or math.floor((phi + n) % 6.3 * 10 + 0.5) * 0.1
  SKIN:Bang('!WriteKeyValue Variables Phi '..phi..' "#@#Settings.inc"')
end

function Scale(n)
  if dispR + n < 70 or tonumber(SKIN:GetVariable('SCREENAREAWIDTH')) / 2 < dispR + n then return end
  dispR = dispR + n
  local showSet = SKIN:GetMeter('AttackLabel'):GetW() ~= 0
  SKIN:Bang('[!SetOption Render Shape "Rectangle 0,0,'..math.max(dispR * 2, (showSet and 250 or 0))..','..math.max(dispR * 2, (showSet and 430 or 0))..'|StrokeWidth 0|Extend Hover"][!UpdateMeter Render][!WriteKeyValue Variables DispR '..dispR..' "#@#Settings.inc"]')
end

function HideControls()
  if isLocked then return end
  SKIN:Bang('[!HideMeterGroup Control][!HideMeterGroup Set][!SetOption Render Hover "Fill Color 00000001"]')
  Scale(0)
end

function ToggleSettings()
  SKIN:Bang('!ToggleMeterGroup Set')
  Scale(0)
end

function GenMeasures()
  local file = io.open(SKIN:GetVariable('@')..'Measures.inc', 'w')
  for b = 1, bands - 1 do
    file:write('[mFFT'..b..']\nMeasure=Plugin\nPlugin=AudioLevel\nParent=mFFT0\nType=Band\nBandIdx='..b..'\nGroup=mFFT\n')
  end
  file:close()
end

function SetAttack(n, m)
  local attack = tonumber(SKIN:GetVariable('Attack'))
  if m then
    attack = math.floor(m * 0.11) * 100
  elseif 0 <= attack + n and attack + n <= 1000 then
    attack = math.floor((attack + n) * 0.01 + 0.5) * 100
  else return end
  SKIN:Bang('[!SetOption mFFT0 FFTAttack '..attack..'][!SetOption AttackSlider X '..(attack * 0.09)..'r][!SetOption AttackVal Text '..attack..'][!SetVariable Attack '..attack..'][!WriteKeyValue Variables Attack '..attack..' "#@#Settings.inc"]')
end

function SetDecay(n, m)
  local decay = tonumber(SKIN:GetVariable('Decay'))
  if m then
    decay = math.floor(m * 0.11) * 100
  elseif 0 <= decay + n and decay + n <= 1000 then
    decay = math.floor((decay + n) * 0.01 + 0.5) * 100
  else return end
  SKIN:Bang('[!SetOption mFFT0 FFTDecay '..decay..'][!SetOption DecaySlider X '..(decay * 0.09)..'r][!SetOption DecayVal Text '..decay..'][!SetVariable Decay '..decay..'][!WriteKeyValue Variables Decay '..decay..' "#@#Settings.inc"]')
end

function SetSens(n, m)
  local sens = tonumber(SKIN:GetVariable('Sens'))
  if m then
    sens = math.floor(m * 0.11) * 10
  elseif 0 <= sens + n and sens + n <= 100 then
    sens = math.floor((sens + n) * 0.1 + 0.5) * 10
  else return end
  SKIN:Bang('[!SetOption mFFT0 Sensitivity '..sens..'][!SetOption SensSlider X '..(sens * 0.9)..'r][!SetOption SensVal Text '..sens..'][!SetVariable Sens '..sens..'][!WriteKeyValue Variables Sens '..sens..' "#@#Settings.inc"]')
end

function SetChannel(n)
  local name = {[0]='Left','Right','Center','Subwoofer','Back Left','Back Right','Side Left','Side Right'}
  SKIN:Bang('[!SetOptionGroup mFFT Channel '..n..'][!SetOption ChannelSet Text "'..(name[tonumber(n)] or n)..'"][!SetVariable Channel '..n..'][!WriteKeyValue Variables Channel '..n..' "#@#Settings.inc"]')
end

function SetBands()
  isLocked = false
  local set = math.floor(tonumber(SKIN:GetVariable('Set')) or 0)
  if set <= 0 then return end
  SKIN:Bang('[!WriteKeyValue Variables Bands '..set..' "#@#Settings.inc"][!WriteKeyValue Variables ShowSet 1 "#@#Settings.inc"][!Refresh]')
end

function SetTravel(n, m)
  local travel = tonumber(SKIN:GetVariable('Travel'))
  if m then
    travel = math.min(math.max(math.floor(m * 0.21) * 0.05, 0.05), 0.95)
  elseif 0 < travel + n and travel + n < 1 then
    travel = math.floor((travel + n) * 20 + 0.5) * 0.05
  else return end
  travelLen = math.sin(travel * math.pi / 2) * 2
  rMin = math.cos(travel * math.pi / 2) * tonumber(SKIN:GetVariable('RadiusMin'))
  rRange = math.cos(travel * math.pi / 2) * tonumber(SKIN:GetVariable('RadiusMax')) - rMin
  SKIN:Bang('[!SetOption TravelSlider X '..(travel * 100 - 5)..'r][!SetOption TravelVal Text "'..(travel * 100)..'%"][!SetVariable Travel '..travel..'][!WriteKeyValue Variables Travel '..travel..' "#@#Settings.inc"]')
end

function SetConcavity(n, m)
  if m then
    concavity = math.min(math.floor(m * 0.11) * 0.1, 1)
  elseif 0 <= concavity + n and concavity + n <= 1 then
    concavity = math.floor((concavity + n) * 10 + 0.5) * 0.1
  else return end
  SKIN:Bang('[!SetOption ConcavitySlider X '..(concavity * 100)..'r][!SetOption ConcavityVal Text "'..(concavity * 100)..'%"][!SetVariable Concavity '..concavity..'][!WriteKeyValue Variables Concavity '..concavity..' "#@#Settings.inc"]')
end

function SetRadius(n, m)
  local r = { Min = tonumber(SKIN:GetVariable('RadiusMin')), Max = tonumber(SKIN:GetVariable('RadiusMax')) }
  local limit = m * 0.02 < r.Min + r.Max and 'Min' or 'Max'
  local val = 0
  if n == 0 then
    val = math.min(math.floor(m * 0.21) * 0.05, 1)
  elseif 0 <= r[limit] + n and r[limit] + n <= 1 then
    val = math.floor((r[limit] + n) * 20 + 0.5) * 0.05
  end
  if (limit == 'Min' and r.Max <= val) or (limit == 'Max' and val <= r.Min) then return end
  local travel = tonumber(SKIN:GetVariable('Travel'))
  if limit == 'Min' then
    r.Min = val
    rMin = math.cos(travel * math.pi / 2) * val
  else
    r.Max = val
  end
  rRange = math.cos(travel * math.pi / 2) * r.Max - rMin
  SKIN:Bang('[!SetOption RadiusRange X '..(r.Min * 100)..'r][!SetOption RadiusRange W '..((r.Max - r.Min) * 100)..'][!SetOption RadiusMaxSlider X '..((r.Max - r.Min) * 100)..'r][!SetOption Radius'..limit..'Val Text "'..(val * 100)..'%"][!SetVariable Radius'..limit..' '..val..'][!WriteKeyValue Variables Radius'..limit..' '..val..' "#@#Settings.inc"]')
end

function SetThick(n, m)
  local thick = tonumber(SKIN:GetVariable('Thick'))
  if m then
    thick = math.min(math.max(math.floor((m + 2) * 0.2), 1), 20)
  elseif 1 <= thick + n and thick + n <= 20 then
    thick = thick + n
  else return end
  SKIN:Bang('[!SetOption Render Attr "Fill Color 0,0,0,0|StrokeWidth '..thick..'"][!SetOption ThickSlider X '..(thick * 5 - 5)..'r][!SetOption ThickVal Text "'..thick..' px"][!SetVariable Thick '..thick..'][!WriteKeyValue Variables Thick '..thick..' "#@#Settings.inc"]')
end

function SetColor(n, set)
  if n then
    set = SKIN:GetVariable('Set')
    if set == '' then return end
  end
  -- Split color into RGBA components
  local RGBA, isHex = {}, not set:find(',')
  for val in set:gmatch(isHex and '%x%x' or '%d+') do
    if val then
      RGBA[#RGBA + 1] = isHex and tonumber(val, 16) or val
    end
  end
  RGBA[4] = RGBA[4] or 255
  if not n then
    return RGBA
  end
  color[n] = RGBA
  SKIN:Bang('[!SetOption Color'..n..'Set Text "#Set#"][!SetVariable Color'..n..' "#Set#"][!WriteKeyValue Variables Color'..n..' "#Set#" "#@#Settings.inc"]')
  isLocked = false
end

function SwapColor()
  color[1], color[2] = color[2], color[1]
  SKIN:Bang('[!SetOption Color1Set Text "#Color2#"][!SetOption Color2Set Text "#Color1#"][!SetVariable Color1 "#Color2#"][!SetVariable Color2 "#Color1#"][!WriteKeyValue Variables Color1 "#Color2#" "#@#Settings.inc"][!WriteKeyValue Variables Color2 "#Color1#" "#@#Settings.inc"]')
end

function BlendColor(n)
  return (color[2][1] + (color[1][1] - color[2][1]) * n)..','..(color[2][2] + (color[1][2] - color[2][2]) * n)..','..(color[2][3] + (color[1][3] - color[2][3]) * n)..','..(color[2][4] + (color[1][4] - color[2][4]) * n)
end

function SetSort(n)
  if isAxial == (n == 1) then return end
  SKIN:Bang('[!SetOption Sort'..(isAxial and 1 or 0)..' SolidColor 505050E0][!SetOption Sort'..(isAxial and 1 or 0)..' MouseLeaveAction "!SetOption #*CURRENTSECTION*# SolidColor 505050E0"][!SetOption Sort'..(n or 0)..' SolidColor FF0000][!SetOption Sort'..(n or 0)..' MouseLeaveAction "!SetOption #*CURRENTSECTION*# SolidColor FF0000"][!WriteKeyValue Variables IsAxial '..(n or 0)..' "#@#Settings.inc"]')
  isAxial = n == 1
end
