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

// ====== Vector Math ======

// Rotate a vector along another, using Rodrigues' rotation formula
// https://en.wikipedia.org/wiki/Rodrigues'_rotation_formula
function vrot {
  parameter parVecVictim. // rotate this
  parameter parVecRef. // ... with this as rotation axis
  parameter parAngle. // ... by this angle

  return parVecVictim * cos(parAngle)
    + vcrs(parVecRef:normalized, parVecVictim) * sin(parAngle)
    + parVecRef:normalized * vdot(parVecRef:normalized, parVecVictim) * (1 - cos(parAngle))
    .
}

// Rotate a vector toward another
// TODO test this one
function vrott {
  parameter parVecVictim. // rotate this
  parameter parVecToward. // ... toward this one
  parameter parAngle. // ... by this angle

  local vecAxis is vcrs(parVecVictim, parVecToward).
  return vrot(parVecVictim, vecAxis, parAngle).
}

// Projection of a vector onto another vector
// TODO test this one
function vprj {
  parameter parVecVictim. // project this
  parameter parVecDir. // ... onto this direction

  local vecUnitDir is parVecDir:normalized.
  return vecUnitDir * vdot(parVecVictim, vecUnitDir).
}

// Normalize an angle to [0, 360)
function angNorm {
  parameter parAng.
  if parAng < 0 {
    return mod(parAng, -360)+360.
  } else if parAng >= 360 {
    return mod(parAng, 360).
  }
  return parAng.
}

// Get opposite direction, normalized angle
function angOppo {
  parameter parAng.
  return angNorm(parAng + 180).
}
