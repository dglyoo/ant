#include <core/ElementBackgroundImage.h>
#include <core/Texture.h>
#include <core/Element.h>
#include <core/Geometry.h>
#include <core/Document.h>
#include <core/Interface.h>
#include <core/Core.h>

namespace Rml {

void ElementBackgroundImage::GenerateGeometry(Element* element, Geometry& geometry, Geometry::Path const& paddingEdge) {
	geometry.Release();

	auto image = element->GetComputedProperty(PropertyId::BackgroundImage);
	if (!image->Has<std::string>()) {
		// "none"
		return;
	}

	const auto& bounds = element->GetBounds();
	const auto& border = element->GetBorder();
	const auto& padding = element->GetPadding();

	Style::BoxType origin = (Style::BoxType)element->GetComputedProperty(PropertyId::BackgroundOrigin)->Get<PropertyKeyword>();

	Rect surface = Rect{ {0, 0}, bounds.size };
	if (surface.size.IsEmpty()) {
		return;
	}

	switch (origin) {
	case Style::BoxType::PaddingBox:
		surface = surface - border;
		break;
	case Style::BoxType::BorderBox:
		break;
	case Style::BoxType::ContentBox:
		surface = surface - border - padding;
		break;
	}
	if (surface.size.IsEmpty()) {
		return;
	}

	SamplerFlag repeat = (SamplerFlag)element->GetComputedProperty(PropertyId::BackgroundRepeat)->Get<PropertyKeyword>();
	Style::BackgroundSize backgroundSize = (Style::BackgroundSize)element->GetComputedProperty(PropertyId::BackgroundSize)->Get<PropertyKeyword>();
	Size texSize {
		element->GetComputedProperty(PropertyId::BackgroundSizeX)->Get<PropertyFloat>().ComputeW(element),
		element->GetComputedProperty(PropertyId::BackgroundSizeY)->Get<PropertyFloat>().ComputeH(element)
	};
	Point texPosition {
		element->GetComputedProperty(PropertyId::BackgroundPositionX)->Get<PropertyFloat>().ComputeW(element),
		element->GetComputedProperty(PropertyId::BackgroundPositionY)->Get<PropertyFloat>().ComputeH(element)
	};

	std::string path = image->Get<std::string>();
	auto const& texture = Texture::Fetch(path);
	auto material = GetRenderInterface()->CreateTextureMaterial(texture.handle, repeat);
	geometry.SetMaterial(material);

	Color color = Color::FromSRGB(255, 255, 255, 255);
	color.ApplyOpacity(element->GetOpacity());

	if (!color.IsVisible())
		return;

	if (texSize.IsEmpty()) {
		texSize = texture.dimensions;
	}
	Size scale{
		surface.size.w / texSize.w,
		surface.size.h / texSize.h
	};
	Rect uv { {
		texPosition.x / texSize.w,
		texPosition.y / texSize.h
	}, {} };
	float aspectRatio = scale.w / scale.h;
	switch (backgroundSize) {
	case Style::BackgroundSize::Auto:
		uv.size.w = scale.w;
		uv.size.h = scale.h;
		break;
	case Style::BackgroundSize::Contain:
		if (aspectRatio < 1.f) {
			uv.size.w = 1.f;
			uv.size.h = 1.f / aspectRatio;
		}
		else {
			uv.size.w = aspectRatio;
			uv.size.h = 1.f;
		}
		break;
	case Style::BackgroundSize::Cover:
		if (aspectRatio > 1.f) {
			uv.size.w = 1.f;
			uv.size.h = 1.f / aspectRatio;
		}
		else {
			uv.size.w = aspectRatio;
			uv.size.h = 1.f;
		}
		break;
	}

	if (paddingEdge.size() == 0 
		|| (origin == Style::BoxType::ContentBox && padding != EdgeInsets<float>{})
	) {
		geometry.AddRectFilled(surface, color);
		geometry.UpdateUV(4, surface, uv);
	}
	else {
		geometry.AddPolygon(paddingEdge, color);
		geometry.UpdateUV(paddingEdge.size(), surface, uv);
	}
}

}
