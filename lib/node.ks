// Various functions for node manipulation
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


runoncepath("lib/kep").

// Create a node based on radialout,normal,prograde value
function makeNode { // (ta, V(radialout,normal,prograde), [round=0])
  parameter parTA.
  parameter parDvv.
  parameter parRound is 0.

  // Find the time to burn point
  local kepShip is kepKSP(ship:orbit).
  local taNow is ship:orbit:trueanomaly.
  local timeToBurn is time:seconds + kepShip[".timeThruTA"](taNow, parTA) + parRound*kepShip["period"].

  return node(timeToBurn, parDvv:x, parDvv:y, parDvv:z).
}
