// Execute node script
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

runoncepath("lib/node").
runoncepath("lib/ship").
runoncepath("sub/ship"). // for "waitActive"

// Get the next node
function getNode {
  waitActive().
  if hasnode {
    return nextnode.
  } else {
    return node(time:seconds+3, 0, 0, 0).
  }
}

// Add node and show message
function addEmptyNode { // ()
  waitActive().
  add node(time:seconds + 30, 0, 0, 0).
  print "new empty node added".
}
function addNode { // (node)
  parameter parNode.
  waitActive().
  add parNode.
  print "new node dv=" + round(parNode:deltav:mag, 2) + " ("
    + round(parNode:radialout, 2) + ", "
    + round(parNode:normal, 2) + ", "
    + round(parNode:prograde, 2) + ")".
}
function addManu { // (manu)
  parameter parManu.
  addNode(
    node(parManu["ut"], parManu["dvv"]:x, parManu["dvv"]:y, parManu["dvv"]:z)
  ).
}

// Add node and make node in one go
function addMakeNode { // (ta, dvv, [round=0])
  parameter parTA.
  parameter parDvv.
  parameter parRound is 0.

  local nd is makeNode(parTA, parDvv, parRound).
  addNode(nd).
}

// Run Basic manuever node
function runNode {
  parameter parMode is 0. // 0=just wait, 1=warp
  parameter parNode is 0.

  waitActive().

  if parNode = 0 {
    set parNode to getNode().
  }

  if parNode:deltav:mag <= 0.1 {
    print "Skipping empty node.".
    remove parNode.
    return.
  }

  if ship:availablethrust = 0 {
    print "Error: no thurst, cannot execute node.".
    return.
  }

  // how long we need to burn BEFORE the maneuver point
  local eIsp is getEffIsp().
  local tBefore is getBurnTime(ship:availablethrust, ship:mass, eIsp, parNode:deltav:mag/2).
  local tFull is getBurnTime(ship:availablethrust, ship:mass, eIsp, parNode:deltav:mag).

  // If the burn is long, we don't need to low thrust at the end
  // But if the burn is VERY short, it is a better idea to allow lower thrust
  local minThrust is min(0.3, tFull/2).

  print "----> NODE eISP=" + round(eIsp, 2) + " pre " + round(tBefore, 2) + "s/" + round(tFull, 2) + "s".
  sas off.
  rcs off.

  // Throttle reset
  set ship:control:pilotmainthrottle to 0.

  // Pre-turning
  lock steering to lookdirup(parNode:deltav, ship:facing:topvector).
  wait until vang(ship:facing:vector, parNode:deltav) < 1.

  print "eta: " + round(parNode:eta, 2) + "s".
  if parMode = 1 { // WARP mode
    if parNode:eta > tBefore+30 {
      set kuniverse:timewarp:mode to "RAILS".
      kuniverse:timewarp:warpto(time:seconds + parNode:eta - (tBefore+30)).
    }
  } else if parMode = 0 { // WAIT mode, will warp the last 5 minute
    print "wait mode, you may set alarm to T-5 min".
  }

  // Warp the final 5 min no matter what
  wait until parNode:eta <= tBefore + 300.
  if parNode:eta < tBefore+300 and parNode:eta > tBefore+30 {
    set kuniverse:timewarp:mode to "RAILS".
    kuniverse:timewarp:warpto(time:seconds + parNode:eta - (tBefore+30)).
  }

  // Warp the final 2 min after alarm clock
  wait until parNode:eta <= tBefore + 120.
  if parNode:eta < tBefore+120 and parNode:eta > tBefore+30 {
    set kuniverse:timewarp:mode to "RAILS".
    kuniverse:timewarp:warpto(time:seconds + parNode:eta - (tBefore+30)).
  }

  // make sure we kill any remaining time warp
  wait until parNode:eta <= tBefore + 30.
  set kuniverse:timewarp:warp to 0.
  wait until parNode:eta <= tBefore.

  // START DOING THE NODE
  local dv0 to parNode:deltav. // record the original deltaV, mainly for its direction

  local currentThrottle is 1.
  local tStart is time:seconds.
  lock throttle to currentThrottle.
  until vang(dv0, parNode:deltav) > 20 {
    local aNow is ship:availablethrust/ship:mass.

    // This is copied from KOS tutorial
    // throttle is 100% until there is less than 0.5 second of time left to burn
    // when there is less than 1 second - decrease the throttle linearly
    // also with arbitrary limit, avoid burn too long being inaccurate
    set currentThrottle to min(max(minThrust, parNode:deltav:mag/aNow*2), 1).
  }

  print "End burn, dt=" + round(time:seconds-tStart,2) + "s err=" + round(parNode:deltav:mag,1) + "m/s".
  set ship:control:pilotmainthrottle to 0.
  set throttle to 0.
  unlock steering.
  unlock throttle.
  remove parNode.
}

