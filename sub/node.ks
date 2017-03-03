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

// Basic manuever node
function runNode {
  parameter parMode is 0. // 0=just wait, 1=warp, "string"=KAC alarm
  parameter parNode is 0.

  if parNode = 0 {
    set parNode to getNode().
  }

  if parNode:deltav:mag = 0 {
    return.
  }

  if ship:availablethrust = 0 {
    print "Error: no thurst, cannot execute node.".
    return.
  }

  // how long we need to burn BEFORE the maneuver point
  local eIsp is getEffIsp().
  local tBefore to getBurnTime(ship:availablethrust, ship:mass, eIsp, parNode:deltav:mag/2).

  print "----> NODE eISP=" + round(eIsp, 2) + " pre " + round(tBefore, 2) + "s".
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
    wait until parNode:eta <= tBefore + 300.
    if parNode:eta < tBefore+300 and parNode:eta > tBefore+30 {
      set kuniverse:timewarp:mode to "RAILS".
      kuniverse:timewarp:warpto(time:seconds + parNode:eta - (tBefore+30)).
    }
  }

  // make sure we kill any remaining time warp
  wait until parNode:eta <= tBefore + 30 or
    (kuniverse:timewarp:rate >= 100 and parNode:eta <= tBefore + 60).
  set kuniverse:timewarp:warp to 0.
  wait until parNode:eta <= tBefore.

  // START DOING THE NODE
  local dv0 to parNode:deltav. // record the original deltaV, mainly for its direction

  local currentThrottle is 0.
  lock throttle to currentThrottle.
  until vang(dv0, parNode:deltav) > 5 {
    local aNow is ship:availablethrust/ship:mass.

    // This is copied from KOS tutorial
    // throttle is 100% until there is less than 0.5 second of time left to burn
    // when there is less than 1 second - decrease the throttle linearly
    // also with arbitrary limit, avoid burn too long being inaccurate
    set currentThrottle to min(max(0.3, parNode:deltav:mag/aNow*2), 1).
  }

  print "End burn, remain dv " + round(parNode:deltav:mag,1) + "m/s".
  set ship:control:pilotmainthrottle to 0.
  set throttle to 0.
  unlock steering.
  unlock throttle.
  remove parNode.
}
