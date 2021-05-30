/*
Minetest
Copyright (C) 2021 Liso <anlismon@gmail.com>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation; either version 2.1 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public License along
with this program; if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
*/

#pragma once
#include "irrlichttypes_extrabloated.h"
#include <IMaterialRendererServices.h>
#include <IShaderConstantSetCallBack.h>

class shadowScreenQuad
{
public:
	shadowScreenQuad();

	void render(video::IVideoDriver *driver);
	video::SMaterial &getMaterial() { return Material; }

	video::ITexture *textures[3];

private:
	video::S3DVertex Vertices[6];
	video::SMaterial Material;
};

class shadowScreenQuadCB : public video::IShaderConstantSetCallBack
{
public:
	shadowScreenQuadCB(){};

	virtual void OnSetConstants(video::IMaterialRendererServices *services,
			s32 userData);
};
