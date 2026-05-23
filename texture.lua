local texture = {}

-- require('common');
local imgui = require('imgui');
local ffi = require('ffi');
local C = ffi.C;
local d3d = require('d3d8');
local d3d8dev   = d3d.get_device();

local images = {};

-- texture.test = function()
--     print('hoge');
-- end

texture.loadImage = function(element, path)
    -- Only load if the image isn't already loaded
	if(images[element] ~= nil) then
		return
	end

	local width, height = getImageDimensions(path)
	
	images[element] = {}
	images[element]["width"] = width
	images[element]["height"] = height
	images[element]["texture"] = createTexture(path);
end

function getImageDimensions(path)
	-- Credit to https://sites.google.com/site/nullauahdark/getimagewidthheight
	local file = io.open(path)

	if(file == nil) then
		print("File " .. path .. " doesn't exist.")
	end
	
	local width,height=0,0
	
	local function refresh()
		if type(fileinfo)=="number" then
			file:seek("set",fileinfo)
		else
			file:close()
		end
	end
	
	-- PNG
	file:seek("set",1)
	if file:read(3)=="PNG" then
		file:seek("set",16)
		local widthstr,heightstr=file:read(4),file:read(4)
		if type(fileinfo)=="number" then
			file:seek("set",fileinfo)
		else
			file:close()
		end
		width=widthstr:sub(1,1):byte()*16777216+widthstr:sub(2,2):byte()*65536+widthstr:sub(3,3):byte()*256+widthstr:sub(4,4):byte()
		height=heightstr:sub(1,1):byte()*16777216+heightstr:sub(2,2):byte()*65536+heightstr:sub(3,3):byte()*256+heightstr:sub(4,4):byte()
		return width,height
	end
	file:seek("set")
	
	-- BMP
	if file:read(2)=="BM" then
		file:seek("set",18)
		local widthstr,heightstr=file:read(4),file:read(4)
		refresh()
		width=widthstr:sub(4,4):byte()*16777216+widthstr:sub(3,3):byte()*65536+widthstr:sub(2,2):byte()*256+widthstr:sub(1,1):byte()
		height=heightstr:sub(4,4):byte()*16777216+heightstr:sub(3,3):byte()*65536+heightstr:sub(2,2):byte()*256+heightstr:sub(1,1):byte()
		return width,height
	end
	
	-- JPG/JPEG
	file:seek("set")
	if file:read(2)=="\255\216" then
		local lastb,curb=0,0
		local xylist={}
		local sstr=file:read(1)
		while sstr~=nil do
			lastb=curb
			curb=sstr:byte()
			if (curb==194 or curb==192) and lastb==255 then
				file:seek("cur",3)
				local sizestr=file:read(4)
				local h=sizestr:sub(1,1):byte()*256+sizestr:sub(2,2):byte()
				local w=sizestr:sub(3,3):byte()*256+sizestr:sub(4,4):byte()
				if w>width and h>height then
					width=w
					height=h
				end
			end
			sstr=file:read(1)
		end
		if width>0 and height>0 then
			refresh()
			return width,height
		end
	end
end

function createTexture(path)
    local texture_ptr = ffi.new('IDirect3DTexture8*[1]');
    if (C.D3DXCreateTextureFromFileA(d3d8dev, path, texture_ptr) ~= C.S_OK) then
        return nil;
    end

    return d3d.gc_safe_release(ffi.cast('IDirect3DBaseTexture8*', texture_ptr[0]));
end

texture.drawTexture = function(image, size, uv1, uv2, color)
    size = size or {images[image]["width"], images[image]["height"]}
    uv1 = uv1 or {0, 0}
    uv2 = uv2 or {1, 1}
    color = color or {1, 1, 1, 1}

    imgui.Image(tonumber(ffi.cast("uint32_t", images[image]["texture"])),
        size,
        uv1, uv2,
        color
    );
end

return texture