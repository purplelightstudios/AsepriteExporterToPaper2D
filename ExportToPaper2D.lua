function GeneratePaper2DFile(filePath, fileName, extension, width, height)
    local separator = app.fs.pathSeparator
    local destinationFile = filePath .. separator .. "T_" .. fileName .. ".paper2dsprites"    
    file = io.open(destinationFile,'w')

    local sprite = app.activeSprite
    if not sprite then 
        return app.alert("There is no active sprite, not able to generate the file")
    end
    
    local spriteSheetWidth = sprite.width    
    local spriteSheetHeight = sprite.height    
    local frames = spriteSheetWidth / width    
    local x = 0

    file:write("{\"frames\":{")    
    for i = 0, frames - 1, 1 do
        file:write("\"T_" .. fileName .. "_" .. string.format("%04i", i) .. "_D" .. extension .. "\":{")
        file:write("\"frame\":{\"x\":" .. x .. ",\"y\":0,\"w\":" .. width .. ",\"h\":" .. height .. "},")
        file:write("\"rotated\":false,\"trimmed\":false,")
        file:write("\"spriteSourceSize\":{\"x\":0,\"y\":0,\"w\":" .. width .. ",\"h\":" .. height .. "},")
        file:write("\"sourceSize\":{\"w\":" .. width .. ",\"h\":" .. height .. "},")
        file:write("\"pivot\":{\"x\":0.5,\"y\":0.5}")
        file:write("}")

        if i < frames - 1 then
            file:write(",")
        end

        x = x + width
    end

    file:write("},")
    file:write("\"meta\":{")
    file:write("\"app\":\"Equilaterus Aseprite Exporter\",")
    file:write("\"version\":\"0.0.1\",")
    file:write("\"image\":\"T_" .. fileName .. "_D" .. extension .. "\",")
    file:write("\"format\":\"RGBA8888\",")
    file:write("\"size\":{\"w\":" .. spriteSheetWidth ..",\"h\":" .. spriteSheetHeight .. "},")
    file:write("\"scale\":1,")
    file:write("\"target\":\"paper2d\"")
    file:write("}}")

    file:close()
end

function AdjustInsideLayers(GroupLayer, LayerName)
    if GroupLayer == nil or not GroupLayer.isGroup then  
        return false
    end
    for i,layer in ipairs(GroupLayer.layers) do
        layer.isVisible = false
        if layer.name == LayerName then
            layer.isVisible = true
        end
    end
    return true
end

function Export(sprite, tag)
    local separator = app.fs.pathSeparator
    local extension = ".PNG"
    local fileName = app.fs.fileTitle(sprite.filename)
    local filePath = app.fs.filePath(sprite.filename)

    -- Tag processing
    if tag == nil then
        tag = ""
    else
        local jokerTagIndex = string.find(fileName, "#")
        if jokerTagIndex == nil then
            app.alert(sprite.filename .. " - Error: To process tags, the file needs the joker symbol #")
            return
        end
        
        fileName = string.sub(fileName, 1, jokerTagIndex - 1) .. tag .. string.sub(fileName, jokerTagIndex + 1, - 1)
    end

    -- Direction processing
    local inverseDirectionFileName = nil
    local jokerDirectionIndex = string.find(fileName, "@")
    if jokerDirectionIndex then
        inverseDirectionFileName = fileName
        fileName = string.sub(fileName, 1, jokerDirectionIndex - 1) .. "Right" .. string.sub(fileName, jokerDirectionIndex + 1, - 1)
        inverseDirectionFileName = string.sub(inverseDirectionFileName, 1, jokerDirectionIndex - 1) .. "Left" .. string.sub(inverseDirectionFileName, jokerDirectionIndex + 1, - 1)
    end

    local width = sprite.width
    local height = sprite.height
        
    app.command.ExportSpriteSheet {
        ui=false,
        askOverwrite=false,
        type=SpriteSheetType.HORIZONTAL,
        columns=0,
        rows=0,
        width=0,
        height=0,
        bestFit=false,
        textureFilename="",
        dataFilename="",
        dataFormat=SpriteSheetDataFormat.JSON_HASH,
        borderPadding=0,
        shapePadding=0,
        innerPadding=0,
        trim=false,
        extrude=false,
        openGenerated=true,
        layer="",
        tag=tag,
        splitLayers=false,
        listLayers=true,
        listTags=true,
        listSlices=true
      }

      
    local destinationFile = filePath .. separator .. "T_" .. fileName .. "_D" .. extension
    app.command.SaveFileAs { filename = destinationFile, filenameFormat = "png" }
    GeneratePaper2DFile(filePath, fileName, extension, width, height)

    -- If is needed to process the inverse direction
    if inverseDirectionFileName then
        destinationFile = filePath .. separator .. "T_" .. inverseDirectionFileName .. "_D" .. extension
        app.command.Flip { target = "", orientation = "horizontal" }
        app.command.SaveFileAs { filename = destinationFile, filenameFormat = "png" }
        GeneratePaper2DFile(filePath, inverseDirectionFileName, extension, width, height)
    end

    app.command.CloseFile { quitting = false }
end

function Process(filesToProcess, skinName, headName)    
    for _, file in ipairs(filesToProcess) do        
        app.command.OpenFile { filename = file }

        -- Begin process
        local sprite = app.activeSprite
        if not sprite then 
            return app.alert("There is no active sprite")
        end

        local headsGroup = nil
        local skinsGroup = nil

        for i,layer in ipairs(sprite.layers) do
            if layer.name == "Heads" then
                headsGroup = layer
            end
            if layer.name == "Skins" then
                skinsGroup = layer
            end
        end     

        local error = false

        if skinsGroup == nil or headsGroup == nil then
            app.alert(sprite.filename .. " - Error: There are no skins or heads in this file") error = true          
        end
        
        if not AdjustInsideLayers(headsGroup, headName) then
            app.alert(sprite.filename .. " - Error: Not able to adjust the heads group")     error = true        
        end
        
        if not AdjustInsideLayers(skinsGroup, skinName) then
            app.alert(sprite.filename .. " - Error: Not able to adjust the skins group")     error = true       
        end

        local exportedFiles = false
        if not error then
            if #sprite.tags > 0 then
                for _,tag in ipairs(sprite.tags) do
                    -- Only export the white tags
                    if tag.color.red == 255 and tag.color.blue == 255 and tag.color.green == 255 then
                        Export(sprite, tag.name)
                        exportedFiles = true
                    end 
                end
            end
            if not exportedFiles then
                Export(sprite, nil)
            end    
        end
        --End process
        app.command.CloseFile { quitting = false }
    end
end


app.transaction(
    function()
        local sprite = app.activeSprite
        if not sprite then 
            return app.alert("There is no active sprite")
        end

        local dlg = Dialog()
        dlg:check { id = "AllFiles", label = "Process all aseprite files at the current location"}
            :entry { id = "Skin", label = "Insert the desire skin layer name" }
            :entry { id = "Head", label = "Insert the desire head layer name" }            
            :separator()
            :button{ id="ok", text="Ok" }
            :button{ id="cancel", text="Cancel" }
            :show()

        local data = dlg.data
        if not data.ok then
            return
        end      
        local files = {}        
        if data.AllFiles == true then
            for i, filename in pairs(app.fs.listFiles(app.fs.filePath(sprite.filename))) do
                if app.fs.fileExtension(filename) == "aseprite" then
                    files[i] = app.fs.joinPath(app.fs.filePath(sprite.filename), filename)
                end
            end
        else
            files[1] = app.fs.filePath(sprite.filename) .. app.fs.pathSeparator .. app.fs.fileName(sprite.filename)
        end        

        Process(files, data.Skin, data.Head)
    end
)