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

function getNode {
  if hasnode {
    return nextnode.
  } else {
    return node(time:seconds+3, 0, 0, 0).
  }
}

function combineNode {
  if allnodes:length < 2 { return 0. }.
  local nd1 is allnodes[0].
  local nd2 is allnodes[1].
  if abs(nd1:eta - nd2:eta) > 10 { return 0. }.
  remove nd1.
  remove nd2.
  set nd1:prograde to nd1:prograde + nd2:prograde.
  set nd1:normal to nd1:normal + nd2:normal.
  set nd1:radialout to nd1:radialout + nd2:radialout.
  add nd1.
}

function makeNode {
  parameter parTA.
  parameter parRadialOut.
  parameter parNormal.
  parameter parPrograde.
  parameter parRound is 0.

  // Find the time to burn point
  local kepShip is kepKSP(ship:orbit).
  local taNow is ship:orbit:trueanomaly.
  local timeToBurn is time:seconds + kepShip[".timeThruTA"](taNow, parTA) + parRound*kepShip["period"].

  return node(timeToBurn, parRadialOut, parNormal, parPrograde).
}

function addNode {
  parameter parNode.
  add parNode.
  print "new node dv=" + round(parNode:deltav:mag, 2) + " ("
    + round(parNode:radialout, 2) + ", "
    + round(parNode:normal, 2) + ", "
    + round(parNode:prograde, 2) + ")".
}
