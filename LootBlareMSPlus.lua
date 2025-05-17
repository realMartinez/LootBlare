local f = LootBlareMSPlusFrame
local content = LootBlareMSPlusFrameContent
UIPanelWindows["MSPlusFrame"] = { area = "center", pushable = 1 }

-- Example raid data
LootBlare.msplus = {
    { name = "Martinez", points = 0 },
    { name = "Nenapadna", points = 0 },
    { name = "Martin", points = 0 },
}



-- Create rows dynamically
local function CreateRaidRow(parent, index, name, points)
    local row = CreateFrame("Frame", nil, parent)
    row:SetWidth(220)
    row:SetHeight(35)
    row:SetPoint("TOPLEFT", 40, -30-((index - 1) * 32))
    row:SetBackdrop({
        bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
        tile = true,
        tileSize = 16,
        edgeFile = nil,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    row:SetBackdropColor(0, 0, 0, 0.7)

    local nameText = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    nameText:SetText(name)
    nameText:SetPoint("LEFT", 10, 0)

    local pointsText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    pointsText:SetText(points)
    pointsText:SetPoint("LEFT", 140, 0)

    local function ChangePointsByName(name, value)
        for i, member in pairs(LootBlare.msplus) do 
            if member.name == name then
                member.points = member.points + value
                if member.points < 0 then member.points = 0 end
                pointsText:SetText(member.points)
            end
        end
    end

    -- Create Up Arrow Button (same style as action bar paging)
    local upButton = CreateFrame("Button", nil, row)
    upButton:SetWidth(20)
    upButton:SetHeight(20)
    upButton:SetNormalTexture([[Interface\Buttons\UI-ScrollBar-ScrollUpButton-Up]])
    upButton:SetPushedTexture([[Interface\Buttons\UI-ScrollBar-ScrollUpButton-Down]])
    upButton:SetHighlightTexture([[Interface\Buttons\UI-ScrollBar-ScrollUpButton-Highlight]])
    upButton:SetPoint("RIGHT", -10, 6)

    -- Create Down Arrow Button
    local downButton = CreateFrame("Button", nil, row)
    downButton:SetWidth(20)
    downButton:SetHeight(20)
    downButton:SetNormalTexture([[Interface\Buttons\UI-ScrollBar-ScrollDownButton-Up]])
    downButton:SetPushedTexture([[Interface\Buttons\UI-ScrollBar-ScrollDownButton-Down]])
    downButton:SetHighlightTexture([[Interface\Buttons\UI-ScrollBar-ScrollDownButton-Highlight]])
    downButton:SetPoint("RIGHT", -10, -6)

    -- Optional: Add functionality
    upButton:SetScript("OnClick", function()
        ChangePointsByName(name, 1)
    end)    

    downButton:SetScript("OnClick", function()
        ChangePointsByName(name, -1)
    end)
end

-- Populate list
for i, v in ipairs(LootBlare.msplus) do
    CreateRaidRow(content, i, v.name, v.points)
end
