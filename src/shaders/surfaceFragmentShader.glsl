#version 330 core

#define SPOT_LIGHTS_COUNT 18
#define DIRECTIONAL_LIGHTS_COUNT 1

// ... ? vector in global coordinate system
// pseudoColor = color/material.color

struct GlobalShading {
	vec3 backgroundColor;
	float ambient;
	float fogGradient;
	float fogDensity;
};

struct Material {
	vec3 color;
	float diffuse;
	float specular;
	float shininess;
};

struct SpotLight {
	mat4 meshMatrix;
	mat4 modelMatrix;
	float cutoffInnerRad;
	float cutoffOuterRad;
	vec3 color;
	float attenuationQuadratic;
	float attenuationLinear;
	float attenuationConstant;
};

struct DirectionalLight {
	mat4 modelMatrix;
	vec3 color;
	float attenuationQuadratic;
	float attenuationLinear;
	float attenuationConstant;
};

in vec4 position;
in vec2 texturePosition;
in vec4 normalVector;

uniform vec3 cameraPosition;
uniform GlobalShading globalShading;
uniform Material material;
uniform bool isTextureEnabled;
uniform sampler2D textureSampler;
uniform SpotLight spotLights[SPOT_LIGHTS_COUNT];
uniform DirectionalLight directionalLights[DIRECTIONAL_LIGHTS_COUNT];

out vec4 outColor;

vec3 calcViewVector();

vec3 calcPseudoColorSpotLight(int i, vec3 viewVector);
vec3 calcPseudoColorDirectionalLight(int i, vec3 viewVector);

float calcBrightness(vec3 viewVector, vec3 lightVector);
float calcAttenuation(float attenuationQuadratic, float attenuationLinear, float attenuationConstant,
	vec3 position, vec3 lightPosition);
float calcCutoffCoef(float cutoffInnerRad, float cutoffOuterRad, vec3 lightVector, vec3 lightDirection);
vec3 applyFog(vec3 color);

void main() {
	vec3 pseudoColor = vec3(globalShading.ambient, globalShading.ambient, globalShading.ambient);
	vec3 viewVector = calcViewVector();
	for(int i = 0; i < SPOT_LIGHTS_COUNT; i++) {
		pseudoColor += calcPseudoColorSpotLight(i, viewVector);
	}
	for(int i = 0; i < DIRECTIONAL_LIGHTS_COUNT; i++) {
		pseudoColor += calcPseudoColorDirectionalLight(i, viewVector);
	}

	vec3 surfaceColor;
	if(isTextureEnabled) {
		surfaceColor = texture(textureSampler, texturePosition).xyz;
	} else {
		surfaceColor = material.color;
	}

	outColor = vec4(
		pseudoColor.x*surfaceColor.x,
		pseudoColor.y*surfaceColor.y,
		pseudoColor.z*surfaceColor.z,
		1
	);
	outColor = vec4(applyFog(outColor.xyz), 1);
}

vec3 calcViewVector() {
	return normalize(cameraPosition - position.xyz);
}

vec3 calcPseudoColorSpotLight(int i, vec3 viewVector) {
	vec4 lightPosition = spotLights[i].modelMatrix*spotLights[i].meshMatrix*vec4(0, 0, 0, 1);
	vec3 lightDirection = normalize(vec3(spotLights[i].modelMatrix*spotLights[i].meshMatrix*vec4(0, 0, 1, 0)));
	vec3 lightVector = normalize(lightPosition.xyz - position.xyz);

	float cutoffCoef = calcCutoffCoef(spotLights[i].cutoffInnerRad, spotLights[i].cutoffOuterRad,
		lightVector, lightDirection);
	if(cutoffCoef < 1e-9) return vec3(0, 0, 0);

	float brightness = calcBrightness(viewVector, lightVector);
	float attenuation = calcAttenuation(spotLights[i].attenuationQuadratic, spotLights[i].attenuationLinear,
		spotLights[i].attenuationConstant, position.xyz, lightPosition.xyz);

	return attenuation*cutoffCoef*brightness*vec3(
		spotLights[i].color.x,
		spotLights[i].color.y,
		spotLights[i].color.z
	);
}

vec3 calcPseudoColorDirectionalLight(int i, vec3 viewVector) {
	vec3 lightVector = normalize(vec3(directionalLights[i].modelMatrix*vec4(0, 0, 1, 0)));

	float brightness = calcBrightness(viewVector, lightVector);

	return brightness*vec3(
		directionalLights[i].color.x,
		directionalLights[i].color.y,
		directionalLights[i].color.z
	);
}

float calcBrightness(vec3 viewVector, vec3 lightVector) {
	float cosNormalLight = dot(normalVector.xyz, lightVector);
	vec3 reflectionVector = normalize(2*cosNormalLight*normalVector.xyz - lightVector);
	float cosViewReflection = dot(viewVector, reflectionVector);

	if(cosNormalLight < 0) cosNormalLight = 0;
	if(cosViewReflection < 0) cosViewReflection = 0;

	return material.diffuse*cosNormalLight + material.specular*pow(cosViewReflection, material.shininess);
}

float calcAttenuation(float attenuationQuadratic, float attenuationLinear, float attenuationConstant,
	vec3 position, vec3 lightPosition) {
	float distance = length(position - lightPosition);
	return 1/(attenuationQuadratic*distance*distance +
		attenuationLinear*distance + attenuationConstant);
}

float calcCutoffCoef(float cutoffInnerRad, float cutoffOuterRad, vec3 lightVector, vec3 lightDirection) {
	float cosLightDirection = dot(lightVector, lightDirection);
	if(cosLightDirection < cos(cutoffOuterRad)) {
		return 0;
	}
	if(cosLightDirection < cos(cutoffInnerRad)) {
		return (cosLightDirection - cos(cutoffOuterRad))/
			(cos(cutoffInnerRad) - cos(cutoffOuterRad));
	}
	return 1;
}

vec3 applyFog(vec3 color) {
	float distance = length(position.xyz - cameraPosition);
	float fogCoef = exp(-pow((globalShading.fogDensity*distance), globalShading.fogGradient));
	return fogCoef*color + (1 - fogCoef)*globalShading.backgroundColor;
}
