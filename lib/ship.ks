// Convenient function for ship-related things
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

// a heading function without changing rotation
function headingUp { // (heading, pitch, [vessel])
  parameter parHeading.
  parameter parPitch.
  parameter parVessel is ship.
  return lookdirup(heading(parHeading, parPitch):vector, parVessel:facing:topvector).
}

// get Effective isp for current active engines
function getEffIsp { // ()
  local eIsp is 0.
  local listEngines is 0.
  local eng is 0.
  list engines in listEngines.
  FOR eng IN listEngines {
    if eng:ignition and not eng:flameout {
      set eIsp to eIsp + eng:availablethrust / ship:availablethrust * eng:isp.
    }
  }
  return eIsp.
}

// compute burn time needed for the given delta-v
function getBurnTime { // (thrust, mass, isp, dv)
  parameter parThrust.
  parameter parMass.
  parameter parIsp.
  parameter parDeltav.

  local a0 is parThrust / parMass. // current acceleration
  local ve is parIsp * 9.80665. // exhaust speed
  local m1 is parMass * constant:e ^ (- parDeltav / ve). // mass after we do the deltav
  local a1 is parThrust / m1. // final acceleration

  return parDeltav / ((a0+a1)/2).
}
