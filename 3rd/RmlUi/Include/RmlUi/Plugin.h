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

#ifndef RMLUI_CORE_PLUGIN_H
#define RMLUI_CORE_PLUGIN_H

#include "Header.h"
#include "Types.h"

namespace Rml {

class Element;
class Document;
class Context;

class RMLUICORE_API Plugin {
public:
	virtual ~Plugin();
	enum EventClasses {
		EVT_BASIC		= (1 << 0),		// Initialise, Shutdown, ContextCreate, ContextDestroy
		EVT_DOCUMENT	= (1 << 1),		// DocumentOpen, DocumentLoad, DocumentUnload
		EVT_ELEMENT		= (1 << 2),		// ElementCreate, ElementDestroy
		EVT_ALL			= EVT_BASIC | EVT_DOCUMENT | EVT_ELEMENT
	};
	virtual int GetEventClasses();
	virtual void OnInitialise();
	virtual void OnShutdown();
	virtual void OnDocumentCreate(Document* document);
	virtual void OnDocumentDestroy(Document* document);
	virtual void OnLoadInlineScript(Document* document, const std::string& content, const std::string& source_path, int source_line);
	virtual void OnLoadExternalScript(Document* document, const std::string& source_path);
	virtual void OnElementCreate(Element* element);
	virtual void OnElementDestroy(Element* element);
};

} // namespace Rml
#endif
