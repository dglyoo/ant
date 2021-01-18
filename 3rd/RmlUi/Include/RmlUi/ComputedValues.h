/*
 * This source file is part of RmlUi, the HTML/CSS Interface Middleware
 *
 * For the latest information, see http://github.com/mikke89/RmlUi
 *
 * Copyright (c) 2019 The RmlUi Team, and contributors
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */

#ifndef RMLUI_CORE_COMPUTEDVALUES_H
#define RMLUI_CORE_COMPUTEDVALUES_H

#include "Types.h"
#include "Animation.h"
#include "TextEffect.h"
#include <optional>

namespace Rml {

namespace Style
{

struct LengthPercentage {
	enum Type { Length, Percentage } type = Length;
	float value = 0;
	LengthPercentage() {}
	LengthPercentage(Type type, float value = 0) : type(type), value(value) {}
};

enum class FontStyle : uint8_t { Normal, Italic };
enum class FontWeight : uint8_t { Normal, Bold };
enum class TextAlign : uint8_t { Left, Right, Center, Justify };
enum class TextDecorationLine : uint8_t { None, Underline, Overline, LineThrough };
enum class TextTransform : uint8_t { None, Capitalize, Uppercase, Lowercase };
enum class WhiteSpace : uint8_t { Normal, Pre, Nowrap, Prewrap, Preline };
enum class WordBreak : uint8_t { Normal, BreakAll, BreakWord };
enum class Drag : uint8_t { None, Drag, DragDrop, Block, Clone };

using PerspectiveOrigin = LengthPercentage;
using TransformOrigin = LengthPercentage;

enum class OriginX : uint8_t { Left, Center, Right };
enum class OriginY : uint8_t { Top, Center, Bottom };

/* 
	A computed value is a value resolved as far as possible :before: introducing layouting. See CSS specs for details of each property.

	Note: Enums and default values must correspond to the keywords and defaults in `StyleSheetSpecification.cpp`.
*/

struct ComputedValues {
	float perspective = 0;
	PerspectiveOrigin perspective_origin_x = { PerspectiveOrigin::Percentage, 50.f };
	PerspectiveOrigin perspective_origin_y = { PerspectiveOrigin::Percentage, 50.f };

	TransformPtr transform;
	TransformOrigin transform_origin_x = { TransformOrigin::Percentage, 50.f };
	TransformOrigin transform_origin_y = { TransformOrigin::Percentage, 50.f };
	float transform_origin_z = 0.0f;

	TransitionList transition;
	AnimationList animation;

	EdgeInsets<Colourb> border_color;
	CornerInsets<float> border_radius{};

	Colourb background_color = Colourb(255, 255, 255, 0);
	String background_image;
};
}

using ComputedValues = Style::ComputedValues;

} // namespace Rml
#endif
