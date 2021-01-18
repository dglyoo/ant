/*
 * This source file is part of RmlUi, the HTML/CSS Interface Middleware
 *
 * For the latest information, see http://github.com/mikke89/RmlUi
 *
 * Copyright (c) 2008-2010 CodePoint Ltd, Shift Technology Ltd
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

#include "XMLNodeHandlerDefault.h"
#include "XMLParseTools.h"
#include "../Include/RmlUi/Log.h"
#include "../Include/RmlUi/Element.h"
#include "../Include/RmlUi/Factory.h"
#include "../Include/RmlUi/XMLParser.h"
#include "../Include/RmlUi/ElementUtilities.h"


namespace Rml {

XMLNodeHandlerDefault::XMLNodeHandlerDefault()
{
}

XMLNodeHandlerDefault::~XMLNodeHandlerDefault()
{
}

Element* XMLNodeHandlerDefault::ElementStart(XMLParser* parser, const String& name, const XMLAttributes& attributes)
{
	Element* parent = parser->GetParseFrame()->element;
	ElementPtr element(new Element(parent->GetOwnerDocument(), name));
	element->SetAttributes(attributes);
	return parent->AppendChild(std::move(element));
}

bool XMLNodeHandlerDefault::ElementEnd(XMLParser* RMLUI_UNUSED_PARAMETER(parser), const String& RMLUI_UNUSED_PARAMETER(name))
{
	RMLUI_UNUSED(parser);
	RMLUI_UNUSED(name);

	return true;
}

bool XMLNodeHandlerDefault::ElementData(XMLParser* parser, const String& data, XMLDataType type)
{
	// Determine the parent
	Element* parent = parser->GetParseFrame()->element;
	RMLUI_ASSERT(parent);

	if (type == XMLDataType::InnerXML)
	{
		// Structural data views use the raw inner xml contents of the node, submit them now.
		if (ElementUtilities::ApplyStructuralDataViews(parent, data))
			return true;
	}

	// Parse the text into the element
	return Factory::InstanceElementText(parent, data);
}


} // namespace Rml
