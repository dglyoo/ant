#pragma once

#include <core/Geometry.h>

namespace Rml {

class Element;

struct ElementBackgroundImage {
	static void GenerateGeometry(Element* element, Geometry& geometry, Geometry::Path const& paddingEdge);
};

}
