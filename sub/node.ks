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
function addWaitNode { // (ta, [round=0])
  parameter parTA.
  parameter parRound is 0.

  local nd is makeNode(parTA, V(1e-3, 1e-3, 1e-3), parRound).
  addNode(nd).
  print "new clock node added: -" + round(nd:eta, 1) + "s".
}
function addEmptyNode { // ()
  waitActive().
  add node(time:seconds+30, 0.00001, 0, 0).
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
  parameter parFrontRatio is 0.5.

  waitActive().

  if parNode = 0 {
    set parNode to getNode().
  }

  if ship:availablethrust = 0 {
    print "Error: no thurst, cannot execute node.".
    return.
  }

  // how long we need to burn BEFORE the maneuver point
  local eIsp is getEffIsp().
  local dv is parNode:deltav.
  local tBefore is getBurnTime(ship:availablethrust, ship:mass, eIsp, dv:mag*parFrontRatio).
  local tFull is getBurnTime(ship:availablethrust, ship:mass, eIsp, dv:mag).

  print "----> NODE eISP=" + round(eIsp, 2) + " pre " + round(tBefore, 2) + "s/" + round(tFull, 2) + "s".
  sas off.
  rcs off.

  // Throttle reset
  set ship:control:pilotmainthrottle to 0.

  // Pre-turning
  lock steering to lookdirup(dv, ship:facing:topvector).
  wait until vang(ship:facing:vector, dv) < 1.

  print "eta: " + round(parNode:eta, 2) + "s".
  // Warp a little bit to kill rotation
  set kuniverse:timewarp:mode to "RAILS".
  kuniverse:timewarp:warpto(time:seconds + 2).
  if parMode = 1 { // WARP mode
    if parNode:eta > tBefore+30 {
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
  if dv:mag <= 0.1 {
    print "Skipping empty node.".
    remove parNode.
    return.
  }
  set kuniverse:timewarp:warp to 0.
  wait until parNode:eta <= tBefore.

  // START DOING THE NODE
  set dv to parNode:deltav. // update node, just in case
  local currentThrottle is 1.
  local tStart is time:seconds.
  local tPrev is time:seconds.
  local mPrev is ship:mass. // current ship mass
  local dvDone is 0.
  lock throttle to currentThrottle.
  until dvDone >= dv:mag {
    local aPrev is ship:availablethrust*currentThrottle/mPrev.
    local aNow is ship:availablethrust*currentThrottle/ship:mass.
    set dvDone to dvDone + (time:seconds-tPrev)*((aNow+aPrev)/2).

    set mPrev to ship:mass.
    set tPrev to time:seconds.

    // This is copied from KOS tutorial
    // throttle is 100% until there is less than 0.66 second of time left to burn
    set currentThrottle to min((dv:mag - dvDone)/aNow*1.5, 1).
    wait 0.
  }

  print "End burn, dt=" + round(time:seconds-tStart,2) + "s err=" + round(dv:mag-dvDone,1) + "m/s".
  set ship:control:pilotmainthrottle to 0.
  set throttle to 0.
  unlock steering.
  unlock throttle.
  remove parNode.
}

