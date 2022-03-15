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

#include "StyleSheetFactory.h"
#include "../Include/RmlUi/StyleSheet.h"
#include "../Include/RmlUi/StringUtilities.h"
#include "../Include/RmlUi/Stream.h"
#include "StyleSheetNode.h"
#include "StyleSheetNodeSelectorNthChild.h"
#include "StyleSheetNodeSelectorNthLastChild.h"
#include "StyleSheetNodeSelectorNthOfType.h"
#include "StyleSheetNodeSelectorNthLastOfType.h"
#include "StyleSheetNodeSelectorFirstChild.h"
#include "StyleSheetNodeSelectorLastChild.h"
#include "StyleSheetNodeSelectorFirstOfType.h"
#include "StyleSheetNodeSelectorLastOfType.h"
#include "StyleSheetNodeSelectorOnlyChild.h"
#include "StyleSheetNodeSelectorOnlyOfType.h"
#include "StyleSheetNodeSelectorEmpty.h"
#include "../Include/RmlUi/Log.h"

namespace Rml {

static StyleSheetFactory* instance = nullptr;

StyleSheetFactory::StyleSheetFactory()
{
	assert(instance == nullptr);
	instance = this;
}

StyleSheetFactory::~StyleSheetFactory()
{
	instance = nullptr;
}

bool StyleSheetFactory::Initialise()
{
	new StyleSheetFactory();

	instance->selectors["nth-child"] = new StyleSheetNodeSelectorNthChild();
	instance->selectors["nth-last-child"] = new StyleSheetNodeSelectorNthLastChild();
	instance->selectors["nth-of-type"] = new StyleSheetNodeSelectorNthOfType();
	instance->selectors["nth-last-of-type"] = new StyleSheetNodeSelectorNthLastOfType();
	instance->selectors["first-child"] = new StyleSheetNodeSelectorFirstChild();
	instance->selectors["last-child"] = new StyleSheetNodeSelectorLastChild();
	instance->selectors["first-of-type"] = new StyleSheetNodeSelectorFirstOfType();
	instance->selectors["last-of-type"] = new StyleSheetNodeSelectorLastOfType();
	instance->selectors["only-child"] = new StyleSheetNodeSelectorOnlyChild();
	instance->selectors["only-of-type"] = new StyleSheetNodeSelectorOnlyOfType();
	instance->selectors["empty"] = new StyleSheetNodeSelectorEmpty();

	return true;
}

void StyleSheetFactory::Shutdown()
{
	if (instance != nullptr)
	{
		ClearStyleSheetCache();

		for (SelectorMap::iterator i = instance->selectors.begin(); i != instance->selectors.end(); ++i)
			delete (*i).second;

		delete instance;
	}
}

std::shared_ptr<StyleSheet> StyleSheetFactory::LoadStyleSheet(const std::string& source_path) {
	StyleSheets::iterator itr = instance->stylesheets.find(source_path);
	if (itr != instance->stylesheets.end()) {
		return (*itr).second;
	}
	Stream stream(source_path);
	std::shared_ptr<StyleSheet> sheet = std::make_shared<StyleSheet>();
	if (!sheet->LoadStyleSheet(&stream)) {
		return nullptr;
	}
	instance->stylesheets.emplace(source_path, sheet);
	return sheet;
}

std::shared_ptr<StyleSheet> StyleSheetFactory::LoadStyleSheet(const std::string& content, const std::string& source_path, int line) {
	Stream stream(source_path, (const uint8_t*)content.data(), content.size());
	std::shared_ptr<StyleSheet> sheet = std::make_shared<StyleSheet>();
	if (!sheet->LoadStyleSheet(&stream, line)) {
		return nullptr;
	}
	return sheet;
}

void StyleSheetFactory::CombineStyleSheet(std::shared_ptr<StyleSheet>& sheet, std::shared_ptr<StyleSheet> subsheet) {
	if (subsheet) {
		if (sheet) {
			sheet->CombineStyleSheet(*subsheet);
		}
		else {
			sheet = subsheet;
		}
	}
}

void StyleSheetFactory::CombineStyleSheet(std::shared_ptr<StyleSheet>& sheet, const std::string& source_path) {
	CombineStyleSheet(sheet, LoadStyleSheet(source_path));
}

void StyleSheetFactory::CombineStyleSheet(std::shared_ptr<StyleSheet>& sheet, const std::string& content, const std::string& source_path, int line) {
	CombineStyleSheet(sheet, LoadStyleSheet(content, source_path, line));
}

// Clear the style sheet cache.
void StyleSheetFactory::ClearStyleSheetCache()
{
	instance->stylesheets.clear();
	instance->stylesheet_cache.clear();
}

// Returns one of the available node selectors.
StructuralSelector StyleSheetFactory::GetSelector(const std::string& name)
{
	SelectorMap::const_iterator it;
	const size_t parameter_start = name.find('(');

	if (parameter_start == std::string::npos)
		it = instance->selectors.find(name);
	else
		it = instance->selectors.find(name.substr(0, parameter_start));

	if (it == instance->selectors.end())
		return StructuralSelector(nullptr, 0, 0);

	// Parse the 'a' and 'b' values.
	int a = 1;
	int b = 0;

	const size_t parameter_end = name.find(')', parameter_start + 1);
	if (parameter_start != std::string::npos &&
		parameter_end != std::string::npos)
	{
		std::string parameters = StringUtilities::StripWhitespace(name.substr(parameter_start + 1, parameter_end - (parameter_start + 1)));

		// Check for 'even' or 'odd' first.
		if (parameters == "even")
		{
			a = 2;
			b = 0;
		}
		else if (parameters == "odd")
		{
			a = 2;
			b = 1;
		}
		else
		{
			// Alrighty; we've got an equation in the form of [[+/-]an][(+/-)b]. So, foist up, we split on 'n'.
			const size_t n_index = parameters.find('n');
			if (n_index == std::string::npos)
			{
				// The equation is 0n + b. So a = 0, and we only have to parse b.
				a = 0;
				b = atoi(parameters.c_str());
			}
			else
			{
				if (n_index == 0)
					a = 1;
				else
				{
					const std::string a_parameter = parameters.substr(0, n_index);
					if (StringUtilities::StripWhitespace(a_parameter) == "-")
						a = -1;
					else
						a = atoi(a_parameter.c_str());
				}

				size_t pm_index = parameters.find('+', n_index + 1);
				if (pm_index != std::string::npos)
					b = 1;
				else
				{
					pm_index = parameters.find('-', n_index + 1);
					if (pm_index != std::string::npos)
						b = -1;
				}

				if (n_index == parameters.size() - 1 || pm_index == std::string::npos)
					b = 0;
				else
					b = b * atoi(parameters.data() + pm_index + 1);
			}
		}
	}

	return StructuralSelector(it->second, a, b);
}

} // namespace Rml
