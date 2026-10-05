local function addBuildOption(builderName, optionName)
    local builder = UnitDefs[builderName]
    if not builder or not builder.buildoptions then
        return
    end

    for i = 1, #builder.buildoptions do
        if builder.buildoptions[i] == optionName then
            return
        end
    end

    builder.buildoptions[#builder.buildoptions + 1] = optionName
end

-- Put the advanced underwater reactor wherever the faction already exposes
-- its normal underwater fusion reactor.
addBuildOption("armhacs", "armuwafus")
addBuildOption("armacsub", "armuwafus")

addBuildOption("corhacs", "coruwafus")
addBuildOption("coracsub", "coruwafus")

addBuildOption("leganavyconsub", "leguwafus")
