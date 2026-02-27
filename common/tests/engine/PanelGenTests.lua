local LegacyPanelGenerator = require("common.compatibility.LegacyPanelGenerator")
local GameModes = require("common.data.GameModes")
local Stack = require("common.engine.Stack")
local LevelPresets = require("common.data.LevelPresets")
local StackBehaviours = require("common.data.StackBehaviours")
local LegacyPanelSource = require("common.compatibility.LegacyPanelSource")
require("common.lib.util")
local logger = require("common.lib.logger")
local tableUtils = require("common.lib.tableUtils")
local PanelGenerator = require("common.engine.PanelGenerator")

local function checkPanels(panels, rowWidth)
  assert(string.len(panels) % rowWidth == 0)
  for i = rowWidth + 1, string.len(panels) do
    local color = LegacyPanelGenerator.PANEL_COLOR_TO_NUMBER[string.sub(panels, i, i)]
    if color ~= 0 and color == LegacyPanelGenerator.PANEL_COLOR_TO_NUMBER[string.sub(panels, i - rowWidth, i - rowWidth)] then
      error("invalid panels: " .. panels)
    end
  end
end

local function testLegacyPanelGenForGarbage1()
  LegacyPanelGenerator:setSeed(1)
  local panelbuffer = LegacyPanelGenerator.privateGeneratePanels(20, 6, 6, "", true)
  checkPanels(panelbuffer, 6)
  assert(panelbuffer == "123624354235541356256135534246123164452652261534436416143654326141464535125612654356413561525232252356624214265623324561")
end

testLegacyPanelGenForGarbage1()

local function testLegacyPanelGenForGarbage2()
  LegacyPanelGenerator:setSeed(2)
  local panelbuffer = LegacyPanelGenerator.privateGeneratePanels(20, 6, 5, "", false)
  checkPanels(panelbuffer, 6)
  assert(panelbuffer == "434133551424345232231321415545122411314534442342321125245242532315353252215143543315252554121343254532431155123232552441")
end

testLegacyPanelGenForGarbage2()

local function  testLegacyPanelGenForStartingBoard1()
  LegacyPanelGenerator:setSeed(3)
  local panelbuffer = LegacyPanelGenerator.privateGeneratePanels(7, 6, 6, "", true)
  checkPanels(panelbuffer, 6)
  assert(panelbuffer == "163625451214636135424264342531164654525236")
  panelbuffer = LegacyPanelGenerator.assignMetalLocations(panelbuffer, 6)
  checkPanels(panelbuffer, 6)
  assert(panelbuffer == "aF3625451Ba4f3613E4B42f434B53a1F4f5452E2c6")
end

testLegacyPanelGenForStartingBoard1()

local function  testLegacyPanelGenForStartingBoard2()
  LegacyPanelGenerator:setSeed(4)
  local panelbuffer = LegacyPanelGenerator.privateGeneratePanels(7, 6, 5, "", false)
  checkPanels(panelbuffer, 6)
  assert(panelbuffer == "213125551342142153554322312431223144435532")
  panelbuffer = LegacyPanelGenerator.assignMetalLocations(panelbuffer, 6)
  checkPanels(panelbuffer, 6)
  assert(panelbuffer == "bA312555Ac42A4215c5Ed322C12d312b31D4435E3b")
end

testLegacyPanelGenForStartingBoard2()

local function testLegacyPanelGenForRegularBoard1()
  LegacyPanelGenerator:setSeed(5)
  local panelbuffer = LegacyPanelGenerator.privateGeneratePanels(100, 6, 6, "", true)
  checkPanels(panelbuffer, 6)
  assert(panelbuffer == "654324321251632562264313656452423131215252532543421625565262343613412156636415463561636414452141345235621513536242254626163532654146526562342141651526365143143526321645264161652632145154623536312145631323352515525642142351323642141535434326262414534541646254521416213262654126315235162463235141146525535313651524536315125124316356121561532153623461212513435421514146161614234261425452352141125434641313123265514643263465312351243136354363415646652431534612463565516231134316612432154651323236152315461452134346212615423146345412252346564651215246353532415243351621123253432612561464324141432453645121")
  panelbuffer = LegacyPanelGenerator.assignMetalLocations(panelbuffer, 6)
  checkPanels(panelbuffer, 6)
  assert(panelbuffer == "6e43B432aB51Fc2562264cA365f45BD231c12a5B525325DcD21f2556e2F23d3F1341b1E6fC6415463eF1Fc641445B1d1C45b356bA513e3624B2e46B6a6353B6e4A4652F5f2c4214A6E15b636eA43A435b63b1F45b6416A65b6C2a4515D623eC6cA2145631cB33e251Ee2E6421D235a32C6d2A41e354C432f26b4A45C4e4164f2E4521d1F2Ac262F541b63a5B351624fCbC514114f5B5e3531C65a5B45C6c15a2E1243a6C5612A56a532Ae3f2346A212eA3d3542A51Da46a616A42c4B614254eBc52A411254cDfD1313123b6EeA464326C4f5c12C512431cF3Ed363415F4f6E24c1E34f1246C56e5A6b3113d3A6f1243B1e4F513232cF15Bc154614eBa34C462aB615423aD6cD5412252c4F56D6e1b1524F3eC532d15B4335A62aa23B534Cb612561D6d3Bd141d32D536D51b1")
end

testLegacyPanelGenForRegularBoard1()

local function testLegacyPanelGenForRegularBoard2()
  LegacyPanelGenerator:setSeed(6)
  local panelbuffer = LegacyPanelGenerator.privateGeneratePanels(100, 6, 5, "", false)
  checkPanels(panelbuffer, 6)
  assert(panelbuffer == "145351332145523213115122252545445452221343433432312521455343144124413531554454345223423131115425344234431141125415332244224535141253322145154411321145155231511522352445411522342315511221425515531442344515513321144153425512334433245252112144224552442323153155425324153231325123143312552554135142442251233512525145451523233415124323215215531154155325421531153124422331143415424534533215151422242141354335211523545414422551314414535522353254215521552342135433213225345354254513421324244113112535355443144324331453453345544232433521551435342213554131435225313443132154553232341124232253443315152231533543")
  panelbuffer = LegacyPanelGenerator.assignMetalLocations(panelbuffer, 6)
  checkPanels(panelbuffer, 6)
  assert(panelbuffer == "A453e133b14Ee23B1311e1B2b5254E4dE452221c4Cd3C432312eB1d5534C1d4A24d135C15E4d5434E2b3dB3131115Db53d423DD3a1411b5D15C3224d224Ec51D125c32bA451E441ac21A451Ee231e115B235b44E4a1E22C4b3155A122aD255a5531D4b3Dd515e133B114dA534255Abc34D332d525B11B1d4224E5bdD2323153a5E4B53b415C23a325aB3A4c312552E5dAc514244B25ab33E125B514e45a5B3233D1e1Bd3232152AeEc11541553Be4Ba5311531bDD2b3311d3D15d2453D53C2a5151D2b2dB1413543CeB1a5235d54A4422e5A3aD4145355bBC53b5421E52a5e2C42a354C3213b2EC4e354254eA34bA324244A1c1Ab535C5544c1D4c24c3145C4E3c4554D2c24C3e2155a4C53d221C55D1c1Dc5225313Dd31Cb154E5323b3D1a24b3B2534d331E15Bb31eC3543")
end

testLegacyPanelGenForRegularBoard2()

---@return Stack stack
---@return LegacyPanelSource panelSource
local function createStackWithLegacySource(gameMode, difficulty, level, colorCount, seed)
  local args = {
    which = 1,
    is_local = false,
    stackInteraction = gameMode.stackInteraction,
    gameOverConditions = gameMode.gameOverConditions,
    stackOverConditions = gameMode.matchRules.stackOverConditions,
    gameWinConditions = gameMode.gameWinConditions,
    stackWinConditions = gameMode.matchRules.stackWinConditions,
    inputMethod = "controller",
    panelSource = LegacyPanelSource(seed, gameMode.stackInteraction ~= GameModes.StackInteractions.NONE),
    behaviours = StackBehaviours.getV048Default(),
    stackSetupModifications = {},
  }

  if level then
    args.levelData = LevelPresets.getModern(level)
    if level < 8 then
      args.levelData:setAdjacentDenialFrequency(0)
    else
      args.levelData:setAdjacentDenialFrequency(1)
    end
  else
    args.levelData = LevelPresets.getClassic(difficulty)
    args.levelData:setColorCount(colorCount)
    args.levelData:setAdjacentDenialFrequency(0)
  end

  local stack = Stack(args)

---@diagnostic disable-next-line: return-type-mismatch
  return stack, stack.panelSource
end

local function testLegacyStartingBoard1()
  local seed = 7
  local difficulty = "easy"
  -- endless easy deviates by 1 color from time attack easy which is the default easy preset
  local colorCount = 5
  local stack, panelSource = createStackWithLegacySource(GameModes.getPreset(GameModes.IDs.ONE_PLAYER_ENDLESS), difficulty, nil, colorCount, seed)
  panelSource:setAllowAdjacentColorsOnStartingBoard(true)

  panelSource.panelBuffer = panelSource:generateStartingBoard(stack)
  checkPanels(panelSource.panelBuffer, 6)
  assert(panelSource.panelBuffer == "0400000bC00201240a0D3305e32E114D535d21aD12")
  -- simulate the first row being applied properly
  panelSource.panelBuffer = panelSource.panelBuffer:sub(stack.width + 1)
  panelSource.panelBuffer = panelSource:generatePanels(stack)
  checkPanels(panelSource.panelBuffer, 6)
  assert(panelSource.panelBuffer == "0bC00201240a0D3305e32E114D535d21aD123B21c3453b4EB115c135eA53aC1315344Eb142b44E5C4b11c1E5424234EeC14b232b15D4c1241B2c5E3341a34B545Ec1a3132E41bA313515dDe13D214e41A3B21b354d24D3E1425d1eE331332dE4A1e2322e33D3421b2EAe213233dE53e5113B1A3d4555b5E12d432C43e1C4b54D125Ca355453eA4e3432C24E5a2A24d2353B2c1d4332E25bD515c523B21bA551d35A2b3213E4b3B41b315A25d314D415bB55Ec453a311B12dE2155533Bd2B5b113525cE5B5a5235C4a31D122dC224a35e322AD35a551E422dB45d334221Bb5dA241b23E1414e4C1dC22435134cB15Ea255144Edb42E1351D4e43d513Cb533E433d51B423aD55d421A153aE2Cd132155B25eb353B1544b4B2A15c3E54b214aB143c54C214b213DB5e3455311eB4D3b14E2233b41Db213C15c252E14d114Eb3")
end

testLegacyStartingBoard1()


local function testLegacyStartingBoard2()
  local seed = 8
  local level = 10
  local stack, panelSource = createStackWithLegacySource(GameModes.getPreset(GameModes.IDs.ONE_PLAYER_VS_SELF), nil, level, nil, seed)
  panelSource:setAllowAdjacentColorsOnStartingBoard(false)

  -- expected starting 7 rows (unprocessed):    312132464356316131624643241456614364463521
  -- expected starting 7 rows (shock assigned): c12A324643EfCa6131624Fd32D145f614Cf446c52A
  -- expected starting 7 rows (cut down):       0000004043E0C06130604Fd320145f614Cf446c52A
  panelSource.panelBuffer = panelSource:generateStartingBoard(stack)
  checkPanels(panelSource.panelBuffer, 6)
  assert(panelSource.panelBuffer == "0000004043E0C06130604Fd320145f614Cf446c52A")
  -- simulate the first row being applied properly
  panelSource.panelBuffer = panelSource.panelBuffer:sub(stack.width + 1)
  -- expected 6+100 rows (unprocessed):   4043E0C06130604Fd320145f614Cf446c52A324212646461165316423125356436235151563515146246363634435425542652653264541613462461536146361534125451256532615421534263461542324165131216346354521463253241341536464343245656162515243642362356426535641621432436643165236513653431512342161514214623436254364316132623561216354153423465161531246465362514435131121314436136324214646451351514634246265635141264353132624641351526234131462565234621526434643562526131161316615464126212432356126434453265321432156343313632262521636134514321325253563461621345545161412612124143632526216463462156615613253454435623512362124536643452132534353253615642164531625652
  -- expected 6+100 rows (shock assigned: 40D3E0C06130604Fd320145f614Cf446c52A3B4b1264f4F1Af531642c12E3E64c6B35a5156c5A5a46B463f36C4D35d2554B65bfE32645416aC4Fb461e36A463F15c412E45aB56e326154bA5Cd263d6154B3Bd165a3121F3Df354521dF325c24A3D15c6D6d3432D56e6A6b5152436Db3f2C5642f5C5F4162a432Dc6fD316523fE136E343aE1b3421f15A4B1462c4Cf2543643aFaC262356a21FcE415342Cd65aF153124F4f5362e1D4c51C1A2a3144C613f32d2A4fD6451351e1D63d2D6B6563e1d12F435cA32F2464a35Ae26b3413A4f2E652346BaE26d346D35f252F13a1f13A6615d6DA2f2124C235fA2f434453Bf532a43BAe634331Cf32B625b16Cf134514Cb1c2525C56c4F1621C4e5d51F1d1B6121B4a4363b5B62a646C462aE661e61CB534e4435f2CEa236212D5c6643D5b1c25C4353B5cFa5642164Ec1f2565B
  panelSource.panelBuffer = panelSource:generatePanels(stack)
  checkPanels(panelSource.panelBuffer, 6)
  assert(panelSource.panelBuffer == "40D3E0C06130604Fd320145f614Cf446c52A3B4b1264f4F1Af531642c12E3E64c6B35a5156c5A5a46B463f36C4D35d2554B65bfE32645416aC4Fb461e36A463F15c412E45aB56e326154bA5Cd263d6154B3Bd165a3121F3Df354521dF325c24A3D15c6D6d3432D56e6A6b5152436Db3f2C5642f5C5F4162a432Dc6fD316523fE136E343aE1b3421f15A4B1462c4Cf2543643aFaC262356a21FcE415342Cd65aF153124F4f5362e1D4c51C1A2a3144C613f32d2A4fD6451351e1D63d2D6B6563e1d12F435cA32F2464a35Ae26b3413A4f2E652346BaE26d346D35f252F13a1f13A6615d6DA2f2124C235fA2f434453Bf532a43BAe634331Cf32B625b16Cf134514Cb1c2525C56c4F1621C4e5d51F1d1B6121B4a4363b5B62a646C462aE661e61CB534e4435f2CEa236212D5c6643D5b1c25C4353B5cFa5642164Ec1f2565B")
  -- why is the already processed row 4043E0 changing here again even though it already has an upper case letter?
  local thisIsANumber = tonumber("4043E0")
  assert(thisIsANumber)
  -- hurray for scientific notation, surely nothing can go wrong converting numbers to alphabet
  -- for compatibility with seeds in replays, these rows being reprocessed for metal has to be considered correct behaviour
end

testLegacyStartingBoard2()

local function testLegacyStartingBoard3()
  -- this seed tests for a certain bug that occured when the first character was a possible metal location for generating the starting board
  local seed = 351545
  local level = 10
  local stack, panelSource = createStackWithLegacySource(GameModes.getPreset(GameModes.IDs.ONE_PLAYER_VS_SELF), nil, level, nil, seed)
  panelSource:setAllowAdjacentColorsOnStartingBoard(false)
  panelSource.panelBuffer = panelSource:generateStartingBoard(stack)
  checkPanels(panelSource.panelBuffer, 6)
  assert(panelSource.panelBuffer == "c0D000505000D0f4005F310115D21e3d23F4e6462A")
end

testLegacyStartingBoard3()

local function testLegacyStartingBoard4()
  -- this seed tests for a certain bug that occured when a starting board row had no shock assignments left:
  local seed = 4530333
  local level = 8
  local stack, panelSource = createStackWithLegacySource(GameModes.getPreset(GameModes.IDs.ONE_PLAYER_VS_SELF), nil, level, nil, seed)
  panelSource:setAllowAdjacentColorsOnStartingBoard(false)

  panelSource.panelBuffer = panelSource:generateStartingBoard(stack)
  checkPanels(panelSource.panelBuffer, 6)
  -- the second line is 430000 which is a number and therefore gets its shock panels reassigned again on the first run of makePanels (thus advancing rng)
  assert(panelSource.panelBuffer == "C00000430000Be405154A03dbC401352cE321E12e1")
  -- simulate the first row being applied properly
  panelSource.panelBuffer = panelSource.panelBuffer:sub(stack.width + 1)
  panelSource.panelBuffer = panelSource:generatePanels(stack)
  checkPanels(panelSource.panelBuffer, 6)
  assert(panelSource.panelBuffer == "D30000Be405154A03dbC401352cE321E12e1425d3Ec4A5245B3b411415Ce5Ce452d13E415c212Ea54C1254B12eaB4231353e1Da451B545c21DC25d211421Ebd35D1451C53bd21C433A51b153Ae13D151d135D53e4B54b1c12E1554e3B44B154eA5d1235434aBAe25245154eAA5a5144a3B53b315A41eB453235bD5Cd132423E41e513aB31e251BB151c5323e4Cb451C435a41C1d5A524542dEEd152432d3E3Bd214213Ac53E2414a312dE42e432C425Bd5E1213a454cE4b4514E1Eb513d35D543431bCa2E4522e1B435143bA13Ea32eD342132a2A4e1252C451dE1B3e3455B415c35bD252415dC1c5C5425A42e3d21C1d21B131dB131231Be2eD242435Ce134a432Ae23D531C21d5B1d3514B15b4145D5bcB124145cD24Bd25435252aBCd235453a5C2a25A533d252Aa3E4153131eAD54e433214bDE43a3115B5d3Ca3135")
end

testLegacyStartingBoard4()

--[[
  Why LegacyPanelSource cannot be touched or get called without losing backward compatibility for replays:
  The big big issue is how shock panels are assigned.
  The general outline is:
  1. A seed is set on the pseudo random number generator (PRNG)
  2. The panels are being generated while backreferencing the last row of the existing panel buffer
     (everything still okay here)
  3. The shock position assignment runs through the ENTIRE panel buffer, including parts that already ran through it on an earlier panel gen
     In this run it processes every line that doesn't return `nil` when thrown into `tonumber()`.
     This is a major issue when it comes to starting boards.
     Starting boards are generated from a 7 line high board that then has panels eliminated from top to bottom (still using the same PRNG)
     Elimination is represented by replacing the respective character with a 0.
     This can also hit the assigned shock locations so that a row may end up as something that returns a number when thrown into `tonumber()`
     e.g. as verified in testStackStartingBoard2
     raw color generation yields
     312132464356316131624643241456614364463521
     shock assignments transform this into
     c12A324643EfCa6131624Fd32D145f614Cf446c52A
     then the starting board routine cuts it down by 12 panels into this
     0000004043E0C06130604Fd320145f614Cf446c52A
     the rows 000000 and 4043E0 both evaluate to numbers (E being interpreted as an exponent)
     that means in the panel gen process that follows the starting board, we get extra calls to random to reprocess these 2 rows in shock assignment
     What is important in regards to the historical implementation is the following:
     The first row got processed and cut out always, that means the first row of the starting board never got reprocessed by the next one (so not advancing the PRNG)
     The second one however will get processed and advance the PRNG.
     The trick is really to process in the exact same way so that the PRNG was advanced the correct number of times from the seed to get the same results

     Beyond the starting board having this shitty interaction:
     all following panel gens should easily be consistent as these 0 "corrupted" lines are no longer in the panel buffer by that time 
     (and I'm not aware of any lines with 2 letters being interpreted as a number)
]]--

local GeneratorSource = require("common.engine.GeneratorSource")

---@param seed integer
---@param shockEnabled boolean
---@param levelData LevelData
---@return Stack
---@return GeneratorSource
local function createStackWithGeneratorSource(seed, shockEnabled, levelData)
  local sourceTemplate = GeneratorSource(seed, shockEnabled)
  local stack = Stack({levelData = levelData, stackSetupModifications = {}, panelSource = sourceTemplate, inputMethod = "controller", is_local = false, stackOverConditions = {}, stackWinConditions = {}})
---@diagnostic disable-next-line: return-type-mismatch
  return stack, stack.panelSource
end

local function testPanelGenForStartingBoard()
  local stack, source = createStackWithGeneratorSource(1, true, LevelPresets.getModern(10))
  checkPanels(source.panelBuffer, stack.width)
  assert(source.panelBuffer == "0000200020E025A010C4602d4e2F5261E34cE416a4")

  stack, source = createStackWithGeneratorSource(1, true, LevelPresets.getModern(5))
  checkPanels(source.panelBuffer, stack.width)
  assert(source.panelBuffer == "0b000003200004A0533520cAaD4323423B5daD2513")

  stack, source = createStackWithGeneratorSource(1, true, LevelPresets.getModern(1))
  checkPanels(source.panelBuffer, stack.width)
  assert(source.panelBuffer == "0000000020400254Eb013C231b41E4e4323B42bE44")
end

local function testPanelGenForRegularBoard()
  local stack, source = createStackWithGeneratorSource(1, true, LevelPresets.getModern(10))
  for i = 1, 30 do
    source:growPanelBuffer(stack)
  end

  checkPanels(source.panelBuffer, stack.width)
  --assert(source.panelBuffer == "0000200020E025A010C4602d4e2F5261E34cE416a44A535a126bD33Ea5251252Eb6D2a4636d5F1f21F322E63a4a6C1452c2F12D6a3246c243F35fE651d24A465Cb42B4541e51bF36d6412A2eC2426161cFE4b461131c5B54E2d3F5642e145aC46bA451156b4B5F54e1F52c451d321F")

  stack, source = createStackWithGeneratorSource(1, true, LevelPresets.getModern(5))
  for i = 1, 30 do
    source:growPanelBuffer(stack)
  end

  checkPanels(source.panelBuffer, stack.width)
  --assert(source.panelBuffer == "0b000003200004A0533520cAaD4323423B5daD2513251bE23Db4141242Db5E1c14B352d53eA152a452A35eC134b41B433Eb1315332dBB54e334414eBc23B431A415d32C5d5eE443121C51bE441c51b1B52C3453e1d3A543143Aa1C1e344142dE3D3a54E1142c1Db342451d2Ec1E532")

  stack, source = createStackWithGeneratorSource(1, true, LevelPresets.getModern(1))
  for i = 1, 30 do
    source:growPanelBuffer(stack)
  end

  checkPanels(source.panelBuffer, stack.width)
  --assert(source.panelBuffer == "0000000020400254Eb013C231b41E4e4323B42bE44c553A22D1a253554Ab1Db2313551aD2B3b35d5142C5Dc135d523B21dE113B24b445Ac1313223dB2e3D54c151D24E2e34b242D311e41Bb34E341B53e1c3412B512bC5b3E511313d2B44E1c3e5325A3d1C35a1545A454Bd41d552E")
end

local function testPanelGenForGarbage()
  local stack, source = createStackWithGeneratorSource(1, true, LevelPresets.getModern(10))
  local garbageColors = ""
  for i = 1, 30 do
    garbageColors = garbageColors .. source:getGarbagePanelRowString(stack)
  end
  checkPanels(garbageColors, stack.width)
  --assert(garbageColors == "163625451214636135424264342531164654525236214561523234352463464512312624164263531642625263131426546243465615351362242513316346425234642625231453523635152453343216152524426436654525")

  stack, source = createStackWithGeneratorSource(1, true, LevelPresets.getModern(5))
  garbageColors = ""
  for i = 1, 30 do
    garbageColors = garbageColors .. source:getGarbagePanelRowString(stack)
  end
  checkPanels(garbageColors, stack.width)
  --assert(garbageColors == "153524412135351343232524345432153514235135142324323453454121231515425343153252545313213251145313523434451341135412413251234315353124235432512521321434243541414324151542535434424153")

  stack, source = createStackWithGeneratorSource(1, true, LevelPresets.getModern(1))
  garbageColors = ""
  for i = 1, 30 do
    garbageColors = garbageColors .. source:getGarbagePanelRowString(stack)
  end
  checkPanels(garbageColors, stack.width)
  --assert(garbageColors == "153524412135351343232524345432153514235135142324323453454121231515425343153252545313213251145313523434451341135412413251234315353124235432512521321434243541414324151542535434424153")
end

testPanelGenForStartingBoard()
testPanelGenForRegularBoard()
testPanelGenForGarbage()

local cache = table.new(6, 0)
local function getColorCounts(row, counts)
  for i = 1, row:len() do
    cache[i] = row:sub(i, i)
  end

  if counts then
    for i = 1, #counts do
      counts[i] = 0
    end
  else
    counts = {0, 0, 0, 0, 0, 0, 0, 0, 0}
  end

  for i, color in ipairs(cache) do
    counts[tonumber(color)] = counts[tonumber(color)] + 1
  end

  return counts
end

local function isBadRow(colorCountArray)
  for i, count in ipairs(colorCountArray) do
    if count ~= 0 and count ~= 2 then
      return false
    end
  end

  return true
end

local function isSadRow(colorCountArray)
  local twoCount = 0
  for i, count in ipairs(colorCountArray) do
    if count == 2 then
      twoCount = twoCount + 1
    end
  end

  return twoCount == 2
end

local function hasHorizontalMatch(colorCount)
  return colorCount >= 3
end

local function testStatisticalProperties(stack, source)
  local badRowCount = 0
  local lastWasBad = false
  local doubleBadCount = 0
  local sadRowCount = 0
  local lastWasSad = false
  local doubleSadCount = 0
  local badSadCount = 0
  local sadBadCount = 0
  local horizontalMatchCount = 0
  local goodRowCount = 0
  local uniqueColorCount = 0
  local N = 1000000
  source:growPanelBuffer(stack)
  -- skim off the starting board as that has color 0 to taint results
  source.panelBuffer = source.panelBuffer:sub(37)
  local colorCounts
  for i = 1, N do
    source:growPanelBuffer(stack)
    local newRow = source.panelBuffer:sub(1, stack.width)
    colorCounts = getColorCounts(newRow, colorCounts)
    if tableUtils.trueForAny(colorCounts, hasHorizontalMatch) then
      horizontalMatchCount = horizontalMatchCount + 1
      goodRowCount = goodRowCount + 1
      lastWasBad = false
      lastWasSad = false
    elseif isBadRow(colorCounts) then
      badRowCount = badRowCount + 1
      if lastWasBad then
        doubleBadCount = doubleBadCount + 1
      elseif lastWasSad then
        sadBadCount = sadBadCount + 1
      end
      lastWasBad = true
      lastWasSad = false
    elseif isSadRow(colorCounts) then
      sadRowCount = sadRowCount + 1
      if lastWasBad then
        badSadCount = badSadCount + 1
      elseif lastWasSad then
        doubleSadCount = doubleSadCount + 1
      end
      lastWasBad = false
      lastWasSad = true
    else
      lastWasBad = false
      lastWasSad = false
      goodRowCount = goodRowCount + 1
    end

    for _, colorCount in ipairs(colorCounts) do
      if colorCount > 0 then
        uniqueColorCount = uniqueColorCount + 1
      end
    end

    source.panelBuffer = source.panelBuffer:sub(stack.width + 1)
  end

  logger.info(badRowCount .. " bad rows (~" .. (math.round(badRowCount/N, 3) * 100) .. "%)")
  logger.info(sadRowCount .. " sad rows (~" .. (math.round(sadRowCount/N, 3) * 100) .. "%)")
  logger.info(goodRowCount .. " good rows (~" .. (math.round(goodRowCount/N, 3) * 100) .. "%)")
  logger.info(horizontalMatchCount .. " had a horizontal match (~" .. (math.round(horizontalMatchCount/N, 3) * 100) .. "%; ~" .. (math.round(horizontalMatchCount/goodRowCount, 3) * 100) .. "% of all good rows)")
  logger.info(doubleBadCount .. " times two bad rows followed right after each other (~" .. (math.round(doubleBadCount/N, 4) * 100) .. "%)")
  logger.info(sadBadCount + badSadCount .. " times a bad row followed on a sad row or vice versa (~" .. (math.round((badSadCount + sadBadCount)/N, 3) * 100) .. "%)")
  logger.info(doubleSadCount .. " times two sad rows followed right after each other (~" .. (math.round(doubleSadCount/N, 3) * 100) .. "%)")
  logger.info(math.round(uniqueColorCount / N, 2) .. " unique colors per row on average")
end

-- local testSeed = 2328743

-- local stack, source = createStackWithGeneratorSource(testSeed, false, LevelPresets.getModern(1))
-- logger.debug("Testing statistical properties of panel gen for 5 colors, adjacents, no shock")
-- testStatisticalProperties(stack, source)

-- stack, source = createStackWithGeneratorSource(testSeed, false, LevelPresets.getModern(3))
-- logger.debug("Testing statistical properties of panel gen for 5 colors, adjacent denial frequency of 2/7, no shock")
-- testStatisticalProperties(stack, source)

-- stack, source = createStackWithGeneratorSource(testSeed, false, LevelPresets.getModern(5))
-- logger.debug("Testing statistical properties of panel gen for 5 colors, adjacent denial frequency of 4/7, no shock")
-- testStatisticalProperties(stack, source)

-- stack, source = createStackWithGeneratorSource(testSeed, false, LevelPresets.getModern(7))
-- logger.debug("Testing statistical properties of panel gen for 5 colors, adjacent denial frequency of 6/7, no shock")
-- testStatisticalProperties(stack, source)

-- stack, source = createStackWithGeneratorSource(testSeed, false, LevelPresets.getModern(8))
-- logger.debug("Testing statistical properties of panel gen for 5 colors, adjacent denial frequency of 1, no shock")
-- testStatisticalProperties(stack, source)

-- stack, source = createStackWithGeneratorSource(1, false, LevelPresets.getModern(10))
-- logger.debug("Testing statistical properties of panel gen for 6 colors, adjacent denial frequency of 1, no shock")
-- testStatisticalProperties(stack, source)

-- local adjacent6Colors = LevelPresets.getModern(10)
-- adjacent6Colors:setAdjacentDenialFrequency(0)
-- stack, source = createStackWithGeneratorSource(testSeed, false, adjacent6Colors)
-- logger.debug("Testing statistical properties of panel gen for 6 colors, adjacents, no shock")
-- testStatisticalProperties(stack, source)