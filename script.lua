-- ============================================
--  Russian Dictionary Autocomplete (GitHub Version)
-- ============================================

if getgenv and getgenv().RusDictMenu then
    pcall(function() getgenv().RusDictMenu:Destroy() end)
    if getgenv().RusDictUnload then pcall(getgenv().RusDictUnload) end
    getgenv().RusDictMenu = nil
    getgenv().RusDictUnload = nil
end

local UserInputService = game:GetService("UserInputService")

-- == НАСТРОЙКИ ==
local TOGGLE_KEY = Enum.KeyCode.RightShift
local PAGE_SIZE = 100
local HARD_CAP = 2000

-- == ВСТРОЕННЫЙ СЛОВАРЬ (БЕЗ ЗАПЯТЫХ, ЧИСТЫЕ СЛОВА) ==
local embedded_words = [[
и в не на я что быть с он а это как то этот по к но они мы она который из у свой вы весь за для от о так мочь все ты же год человек один такой тот или если только его бы себя время когда еще уже другой сказать до мой наш чтобы говорить самый знать вот очень нет кто при да стать день первый даже можно жизнь во ни сам дело два новый раз хотеть должен ли какой со там их много работа иметь после где вопрос рука город ее под каждый слово место без ну ребенок просто более друг большой надо чем ваш сделать идти здесь делать сейчас россия видеть потом ничто через мир теперь несколько думать потому случай сторона хороший тоже глаз тогда тут дом страна об сила последний работать также лицо жить часть хотя женщина система всегда являться вид голова проблема конец ведь между конечно смотреть пока отношение получить дать русский три второй именно перед лишь образ понять деньги поэтому почему понимать москва любой однако хорошо никто час начать найти считать взять над земля сегодня вообще книга пойти возможность некоторый оказаться прийти компания история любить высокий нужно почти остаться твой результат больше например право группа писать сидеть путь машина находиться увидеть война казаться стоять имя решить никогда стоить маленький ответ вода решение бог совсем язык далеко нужный давать ответить полный российский народ власть сразу уровень выйти ночь пора часто спросить развитие программа начало никакой оно главный дверь вместе момент закон число цель принять следующий написать отец правда нога старый помощь информация тысяча про подобный разный общий месяц пройти кроме минута мало процесс ситуация автор начинать форма голос многий собственный мысль свет качество школа всякий действие мужчина область внимание следовать использовать дорога связь взгляд условие молодой скоро снова любовь основной становиться важный ждать вдруг игра читать статья организация средство существовать душа пытаться тело посмотреть общество жена государство оставаться совершенно письмо состояние вечер настоящий назад смысл мера семья простой вещь вернуться затем причина утро мать рынок действительно происходить данный девушка вести сколько тема стол проект улица государственный помнить называть точка появиться нельзя белый центр опять равный против куда неделя идея особенно комната иной цена наконец известный среди сын деятельность узнать играть правило советский лучший движение заниматься точно огромный мама задача великий количество чувство иногда слишком смерть достаточно лежать помочь мнение труд пять третий бывать заметить готовый быстро черный сильный порядок чувствовать создать пример положение век продолжать подумать муж поскольку уйти хоть военный речь план совет политический стена представлять слышать ходить окно рядом прежде показать опыт тип оба около отвечать интерес современный плохой сердце управление данные наука сообщение значит просить немного газета интересный живой поставить необходимый материал роль открыть представить вполне будто рассказать выходить рано оставить получать давно армия рабочий четыре бояться различный долго привести президент либо событие менее красный социальный искать большинство бизнес пусть легко правительство прямо глава член суд возможно принимать рубль миллион целый приходить фильм обычно счет спать небольшой культура текст брать документ принцип разговор телефон произойти правый способ течение провести пол вокруг проходить купить родитель ряд ещё единственный метр сайт партия позволять образование зачем наверное период кстати пара
]]

-- == UTF-8 ==
local function utf8Lower(s)
    local parts, b, i = {}, {s:byte(1, -1)}, 1
    while i <= #b do
        local c1 = b[i]
        if c1 == 0xD0 and i < #b then
            local c2 = b[i+1]
            if c2 >= 0x90 and c2 <= 0x9F then parts[#parts+1] = string.char(0xD0, c2 + 0x20)
            elseif c2 >= 0xA0 and c2 <= 0xAF then parts[#parts+1] = string.char(0xD1, c2 - 0x20)
            elseif c2 == 0x81 then parts[#parts+1] = string.char(0xD1, 0x91)
            else parts[#parts+1] = string.char(c1, c2) end
            i = i + 2
        elseif c1 >= 0x41 and c1 <= 0x5A then
            parts[#parts+1] = string.char(c1 + 0x20); i = i + 1
        else
            parts[#parts+1] = string.char(c1); i = i + 1
        end
    end
    return table.concat(parts)
end

local function utf8Chars(s)
    local out, i = {}, 1
    while i <= #s do
        local b = s:byte(i)
        local len = (b >= 0xF0 and 4) or (b >= 0xE0 and 3) or (b >= 0xC0 and 2) or 1
        out[#out+1] = s:sub(i, i+len-1)
        i = i + len
    end
    return out
end

-- == ТРЕКЕР ==
local connections = {}
local function track(c) connections[#connections+1] = c; return c end
local isUnloaded = false

-- == GUI ==
local parent = (gethui and gethui()) or game:GetService("CoreGui")
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RusDictMenu_" .. math.random(1e6, 9e6)
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 999
screenGui.Parent = parent

local main = Instance.new("Frame", screenGui)
main.Size = UDim2.new(0, 540, 0, 500)
main.Position = UDim2.new(0.5, -270, 0.5, -250)
main.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke", main)
stroke.Color = Color3.fromRGB(90, 90, 130)
stroke.Thickness = 1
stroke.Transparency = 0.3

local title = Instance.new("TextLabel", main)
title.Size = UDim2.new(1, -260, 0, 30)
title.Position = UDim2.new(0, 10, 0, 6)
title.BackgroundTransparency = 1
title.Text = "🇷🇺 Русский словарь"
title.TextColor3 = Color3.fromRGB(230, 230, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left

local unloadBtn = Instance.new("TextButton", main)
unloadBtn.Size = UDim2.new(0, 70, 0, 26)
unloadBtn.Position = UDim2.new(1, -106, 0, 8)
unloadBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
unloadBtn.Text = "Unload"
unloadBtn.TextColor3 = Color3.new(1,1,1)
unloadBtn.Font = Enum.Font.GothamBold
unloadBtn.TextSize = 13
Instance.new("UICorner", unloadBtn).CornerRadius = UDim.new(0, 6)

local closeBtn = Instance.new("TextButton", main)
closeBtn.Size = UDim2.new(0, 26, 0, 26)
closeBtn.Position = UDim2.new(1, -32, 0, 8)
closeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
closeBtn.Text = "×"
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 18
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

local textBox = Instance.new("TextBox", main)
textBox.Size = UDim2.new(1, -110, 0, 40)
textBox.Position = UDim2.new(0, 10, 0, 44)
textBox.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
textBox.TextColor3 = Color3.new(1,1,1)
textBox.PlaceholderText = "Нажми сюда или ФОКУС и печатай..."
textBox.PlaceholderColor3 = Color3.fromRGB(140, 140, 170)
textBox.Text = ""
textBox.Font = Enum.Font.Gotham
textBox.TextSize = 18
textBox.ClearTextOnFocus = false
textBox.TextXAlignment = Enum.TextXAlignment.Left
Instance.new("UICorner", textBox).CornerRadius = UDim.new(0, 8)
Instance.new("UIPadding", textBox).PaddingLeft = UDim.new(0, 10)

local focusBtn = Instance.new("TextButton", main)
focusBtn.Size = UDim2.new(0, 90, 0, 40)
focusBtn.Position = UDim2.new(1, -100, 0, 44)
focusBtn.BackgroundColor3 = Color3.fromRGB(70, 110, 200)
focusBtn.Text = "⌨ ФОКУС"
focusBtn.TextColor3 = Color3.new(1,1,1)
focusBtn.Font = Enum.Font.GothamBold
focusBtn.TextSize = 14
Instance.new("UICorner", focusBtn).CornerRadius = UDim.new(0, 8)

local status = Instance.new("TextLabel", main)
status.Size = UDim2.new(1, -20, 0, 32)
status.Position = UDim2.new(0, 10, 0, 88)
status.BackgroundTransparency = 1
status.Text = "✅ Словарь готов к работе!"
status.TextColor3 = Color3.fromRGB(130, 220, 130)
status.Font = Enum.Font.Gotham
status.TextSize = 12
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextWrapped = true

local listFrame = Instance.new("ScrollingFrame", main)
listFrame.Size = UDim2.new(1, -20, 1, -170)
listFrame.Position = UDim2.new(0, 10, 0, 124)
listFrame.BackgroundTransparency = 1
listFrame.BorderSizePixel = 0
listFrame.ScrollBarThickness = 6
listFrame.ScrollBarImageColor3 = Color3.fromRGB(120, 120, 160)
listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
local layout = Instance.new("UIListLayout", listFrame)
layout.Padding = UDim.new(0, 4)
layout.SortOrder = Enum.SortOrder.LayoutOrder

local footer = Instance.new("TextLabel", main)
footer.Size = UDim2.new(1, -20, 0, 16)
footer.Position = UDim2.new(0, 10, 1, -22)
footer.BackgroundTransparency = 1
footer.Text = ("%s — тоггл | клик по слову — авто-набор"):format(TOGGLE_KEY.Name)
footer.TextColor3 = Color3.fromRGB(120, 120, 150)
footer.Font = Enum.Font.Gotham
footer.TextSize = 12
footer.TextXAlignment = Enum.TextXAlignment.Left

-- == ФОКУС ==
local function forceFocus()
    if isUnloaded or not textBox.Parent then return end
    pcall(function() textBox:CaptureFocus() end)
end
local function setModal(on) pcall(function() UserInputService.ModalEnabled = on end) end
track(textBox.Focused:Connect(function() setModal(true) end))
track(textBox.FocusLost:Connect(function() setModal(false) end))
track(textBox.MouseButton1Down:Connect(forceFocus))
track(focusBtn.MouseButton1Click:Connect(forceFocus))

-- == ЛОГИКА ==
local dictionary = {}
local isReady = false
local allResults = {}
local displayedCount = 0
local isTyping = false

-- Парсим словарь по пробелам!
for word in embedded_words:gmatch("%S+") do
    word = utf8Lower(word)
    if #word >= 1 then
        table.insert(dictionary, word)
    end
end
table.sort(dictionary)
isReady = true

local function clearList()
    for _, c in ipairs(listFrame:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
end

local doSearch

local function typeWordAnimated(word)
    if isTyping or isUnloaded then return end
    isTyping = true
    textBox.Text = ""
    for _, ch in ipairs(utf8Chars(word)) do
        if isUnloaded then isTyping = false; return end
        textBox.Text = textBox.Text .. ch
        task.wait(0.05)
    end
    isTyping = false
    task.wait(0.05)
    if not isUnloaded and doSearch then doSearch() end
end

local function makeWordButton(word, order)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 30)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    btn.TextColor3 = Color3.fromRGB(220, 220, 240)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 15
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Text = "  • " .. word
    btn.LayoutOrder = order
    btn.Parent = listFrame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    track(btn.MouseButton1Click:Connect(function()
        if isTyping then return end
        pcall(function() textBox:ReleaseFocus() end)
        typeWordAnimated(word)
    end))
end

local function makeMoreButton(remaining)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 30)
    btn.BackgroundColor3 = Color3.fromRGB(70, 70, 100)
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.Text = ("+ Показать ещё %d"):format(math.min(PAGE_SIZE, remaining))
    btn.LayoutOrder = displayedCount + 1
    btn.Parent = listFrame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    track(btn.MouseButton1Click:Connect(function()
        btn:Destroy()
        local target = math.min(displayedCount + PAGE_SIZE, #allResults)
        for i = displayedCount + 1, target do
            makeWordButton(allResults[i], i)
            displayedCount = i
        end
        if displayedCount < #allResults then
            makeMoreButton(#allResults - displayedCount)
        end
        status.Text = ("Найдено: %d | Показано: %d"):format(#allResults, displayedCount)
    end))
end

local function findByPrefix(prefix)
    if not isReady or prefix == "" then return {} end
    local lp = #prefix
    local lo, hi = 1, #dictionary
    while lo <= hi do
        local mid = math.floor((lo + hi) / 2)
        if dictionary[mid] < prefix then lo = mid + 1 else hi = mid - 1 end
    end
    if lo > #dictionary or string.sub(dictionary[lo], 1, lp) ~= prefix then return {} end
    local out = {}
    for i = lo, #dictionary do
        local w = dictionary[i]
        if string.sub(w, 1, lp) == prefix then
            out[#out+1] = w
            if #out >= HARD_CAP then break end
        else
            break
        end
    end
    return out
end

doSearch = function()
    if isUnloaded or isTyping then return end
    clearList()
    allResults, displayedCount = {}, 0
    local prefix = utf8Lower(textBox.Text)
    if prefix == "" then
        if isReady then status.Text = ("✅ Словарь готов (%d слов)"):format(#dictionary) end
        return
    end
    allResults = findByPrefix(prefix)
    if #allResults == 0 then
        status.Text = ("По запросу «%s» — ничего не найдено"):format(prefix); return
    end
    local target = math.min(PAGE_SIZE, #allResults)
    for i = 1, target do makeWordButton(allResults[i], i); displayedCount = i end
    if displayedCount < #allResults then makeMoreButton(#allResults - displayedCount) end
    status.Text = ("Найдено: %d | Показано: %d"):format(#allResults, displayedCount)
end

-- Дебаунс поиска
local lastRun = 0
track(textBox:GetPropertyChangedSignal("Text"):Connect(function()
    if isUnloaded or isTyping then return end
    local now = tick()
    if now - lastRun < 0.1 then
        task.delay(0.1, function()
            if not isUnloaded and not isTyping and tick() - lastRun >= 0.1 then
                lastRun = tick(); doSearch()
            end
        end)
    else
        lastRun = now; doSearch()
    end
end))

track(closeBtn.MouseButton1Click:Connect(function() screenGui.Enabled = false; setModal(false) end))
track(UserInputService.InputBegan:Connect(function(input, gp)
    if gp or isUnloaded then return end
    if input.KeyCode == TOGGLE_KEY then
        screenGui.Enabled = not screenGui.Enabled
        if screenGui.Enabled then task.wait(0.05); forceFocus() else setModal(false) end
    end
end))

-- == UNLOAD ==
local function unload()
    if isUnloaded then return end
    isUnloaded = true
    setModal(false)
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    connections = {}
    dictionary = {}; allResults = {}; isReady = false
    pcall(function() screenGui:Destroy() end)
    if getgenv then getgenv().RusDictMenu = nil; getgenv().RusDictUnload = nil end
    print("[RusDictMenu] Unloaded.")
end
getgenv().RusDictMenu = screenGui
getgenv().RusDictUnload = unload
track(unloadBtn.MouseButton1Click:Connect(unload))
