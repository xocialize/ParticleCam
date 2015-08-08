//
//  Particles.metal
//  MetalParticles
//
//  Created by Simon Gladman on 17/01/2015.
//  Copyright (c) 2015 Simon Gladman. All rights reserved.
//
//  Thanks to: http://memkite.com/blog/2014/12/15/data-parallel-programming-with-metal-and-swift-for-iphoneipad-gpu/
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.

//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>

#include <metal_stdlib>
using namespace metal;

float rand(int x, int y, int z);

// Generate a random float in the range [0.0f, 1.0f] using x, y, and z (based on the xor128 algorithm)
float rand(int x, int y, int z)
{
    int seed = x + y * 57 + z * 241;
    seed= (seed<< 13) ^ seed;
    return (( 1.0 - ( (seed * (seed * seed * 15731 + 789221) + 1376312589) & 2147483647) / 1073741824.0f) + 1.0f) / 2.0f;
}

float clip(float value);

float clip(float value)
{
    const float max = 1;
    
    if (value < 0 - max)
    {
        return 0 - max;
    }
    else if (value > max)
    {
        return max;
    }
    else
    {
        return value;
    }
    
}

kernel void particleRendererShader(texture2d<float, access::write> outTexture [[texture(0)]],
                                   
                                   texture2d<float, access::read> cameraTexture [[texture(1)]],
                                   
                                   const device float4 *inParticles [[ buffer(0) ]],
                                   device float4 *outParticles [[ buffer(1) ]],
               
                                   constant float3 &particleColor [[ buffer(3) ]],
                                   
                                   constant float &imageWidth [[ buffer(4) ]],
                                   constant float &imageHeight [[ buffer(5) ]],
                                   
                                   constant float &dragFactor [[ buffer(6) ]],
                                   
                                   constant bool &respawnOutOfBoundsParticles [[ buffer(7) ]],
                                   
                                   uint id [[thread_position_in_grid]])
{
    const float4 inParticle = inParticles[id];
    
    const float spawnSpeedMultipler = 1.0;
    
    const uint2 particlePositionA(inParticle.x, inParticle.y);

    const uint2 northIndex(particlePositionA.x, particlePositionA.y - 2);
    const uint2 southIndex(particlePositionA.x, particlePositionA.y + 2);
    const uint2 westIndex(particlePositionA.x - 1, particlePositionA.y);
    const uint2 eastIndex(particlePositionA.x + 1, particlePositionA.y);
    
    const uint2 northEastIndex(particlePositionA.x + 2, particlePositionA.y - 2);
    const uint2 southEastIndex(particlePositionA.x + 2, particlePositionA.y + 2);
    const uint2 northWestIndex(particlePositionA.x - 2, particlePositionA.y - 2);
    const uint2 southWestIndex(particlePositionA.x - 2, particlePositionA.y + 2);
    
    const float cameraPixelValue = cameraTexture.read(particlePositionA).r;
    
    const float topLine = (cameraTexture.read(northIndex).r + cameraTexture.read(northIndex).r +cameraTexture.read(northEastIndex).r + cameraTexture.read(northWestIndex).r) / 4.0;
    const float bottomLine = (cameraTexture.read(southIndex).r + cameraTexture.read(southIndex).r + cameraTexture.read(southEastIndex).r + cameraTexture.read(southWestIndex).r) / 4.0;
    
    const float leftLine = (cameraTexture.read(westIndex).r + cameraTexture.read(westIndex).r + cameraTexture.read(northWestIndex).r + cameraTexture.read(southWestIndex).r) / 4.0;
    const float rightLine = (cameraTexture.read(eastIndex).r + cameraTexture.read(eastIndex).r + cameraTexture.read(northEastIndex).r + cameraTexture.read(southEastIndex).r) / 4.0;
    
    // const float verticalModifier = (cameraPixelValue - (topLine > bottomLine ? topLine : 0 - bottomLine));
    // const float horizontalModifier = (cameraPixelValue - (leftLine > rightLine ? leftLine : 0 - rightLine));
    
    const float northPixel = cameraTexture.read(northIndex).r;
    const float southPixel = cameraTexture.read(southIndex).r;
    const float westPixel = cameraTexture.read(westIndex).r;
    const float eastPixel = cameraTexture.read(eastIndex).r;
    
    const float northEastPixel = cameraTexture.read(northEastIndex).r;
    const float southEastPixel = cameraTexture.read(southEastIndex).r;
    const float northWestPixel = cameraTexture.read(northWestIndex).r;
    const float southWestPixel = cameraTexture.read(southWestIndex).r;
    
    const float horizontalModifier = (-northWestPixel + -westPixel + -westPixel + -southWestPixel + northEastPixel + eastPixel + eastPixel + southEastPixel + cameraPixelValue + cameraPixelValue) / 10.0;
    
    const float verticalModifier = (-northWestPixel + -northPixel + -northPixel + -northEastPixel + southWestPixel + southPixel + southPixel + southEastPixel + cameraPixelValue + cameraPixelValue) / 10.0;
    
    if (particlePositionA.x > 1 && particlePositionA.y > 1 && particlePositionA.x < imageWidth - 1 && particlePositionA.y < imageHeight - 1)
    {
        outTexture.write(float4(1,1,1,1), particlePositionA);
    }
    else if (respawnOutOfBoundsParticles)
    {
        inParticle.z = rand(inParticle.w, inParticle.x, inParticle.y) * 2.0 - 1.0;
        inParticle.w = rand(inParticle.z, inParticle.y, inParticle.x) * 2.0 - 1.0;
        
        inParticle.x = rand(inParticle.x, inParticle.y, inParticle.z) * imageWidth;
        inParticle.y = rand(inParticle.y, inParticle.x, inParticle.w) * imageHeight;
    }
    
    if (abs(inParticle.z) < 0.05)
    {
        inParticle.z = rand(inParticle.w, inParticle.x, inParticle.y) * 2.0 - 1.0;
    }
    
    if (abs(inParticle.w) < 0.05)
    {
        inParticle.w = rand(inParticle.z, inParticle.y, inParticle.x) * 2.0 - 1.0;
    }

    const float speedLimit = 5;
    
    float newZ = inParticle.z * (1 + horizontalModifier * 2) * (dragFactor);
    float newW = inParticle.w * (1 + verticalModifier * 2) * (dragFactor);
    
    float speedSquared = newZ * newZ + newW * newW;
    
    if (speedSquared > speedLimit)
    {
        float scale = speedLimit / sqrt(speedSquared);
        
        newZ = newZ * scale;
        newW = newW * scale;
    }
    
    outParticles[id] = {
        inParticle.x + inParticle.z * cameraPixelValue,
        inParticle.y + inParticle.w * cameraPixelValue,
        newZ,
        newW
    };
}