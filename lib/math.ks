// some utility math functions
// ***************************************************************************
//  Copyright 2014-2016, mettatw
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//      http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
// ***************************************************************************
@lazyglobal off.

// Rotate a vector along another, using Rodrigues' rotation formula
// https://en.wikipedia.org/wiki/Rodrigues'_rotation_formula
function vrot {
  parameter parVecVictim.
  parameter parVecRef.
  parameter parAngle.

  return parVecVictim * cos(parAngle)
    + vcrs(parVecRef:normalized, parVecVictim) * sin(parAngle)
    + parVecRef:normalized * vdot(parVecRef:normalized, parVecVictim) * (1 - cos(parAngle))
    .
}

// Get the universal reference vector (First Point of Skybox) by ugly reverse engineering
// Should not be needed once this get released:
// https://github.com/KSP-KOS/KOS/commit/bc7d848cfde3bf2f3a6fb1296f9ca5b2295e95ee
function fpos {
  // If not used in stock solar system, Moho need to be replaced by some celestial body with inclined orbit
  local bodySample is body("Moho").
  local bodyParent is bodySample:body.

  // Get normal vector of orbiting plane
  local planeSample is vcrs(bodySample:position - bodyParent:position, bodySample:velocity:orbit - bodyParent:velocity:orbit).
  // Get vector to ascending node. Only work on counter-clockwise orbit AND counter-clockwise parent rotation
  // AND ksp's left-hand coord. system
  local lineAscending is vcrs(planeSample, V(0,-1,0)).

  // Rotate the ascending node vector -(lan) degrees along parent's rotation vector
  return vrot(lineAscending, V(0,-1,0), -bodySample:orbit:lan).
}
