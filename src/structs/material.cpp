#include "material.hpp"

Material::Material(glm::vec3 color, float diffuse, float specular, float shininess) : color(color),
	diffuse(diffuse), specular(specular), shininess(shininess) { }
