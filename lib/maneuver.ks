// Various functions for kepler orbit elements
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
runoncepath("lib/node").

// Plan a maneuver to change altitude at specific true anomaly
// This will treat that point as one *apsis, and given altitude as another
function planChangeAltitude {
  parameter parTA. // True anomaly at burn point, 0 for periapsis
  parameter parAlt.

  local kepShip is kepKSP(ship:orbit).
  local kepNew is kepModChangeAlt(kepShip, parTA, parAlt).
  local taNew is kepNew[".taOfPos"](kepShip[".posOfTA"](parTA)).

  local velDelta is kepNew[".velOfTA"](taNew) - kepShip[".velOfTA"](parTA).
  print "----> CHALT alt=" + round(parAlt/1000, 1) + "km @ " + round(parTA, 1).
  addNode(makeNodeFromVec(parTA, velDelta)).
}

function planChangeInc {
  parameter parTA. // True anomaly at burn point, 0 for periapsis
  parameter parDeltaInc.

  local kepShip is kepKSP(ship:orbit).
  local kepNew is kepModChangeInc(kepShip, parTA, parDeltaInc).
  local taNew is kepNew[".taOfPos"](kepShip[".posOfTA"](parTA)).

  local velDelta is kepNew[".velOfTA"](taNew) - kepShip[".velOfTA"](parTA).
  print "----> CHINC dinc=" + round(parDeltaInc, 1) + " @ " + round(parTA, 1).
  addNode(makeNodeFromVec(parTA, velDelta)).
}

// ====== Based on other orbit ======

function planMatchInc {
  parameter parOrbitTarget.

  local orbitShip is extractOrbit(ship:orbit).
  local taNow is ship:orbit:trueanomaly.

  local relInclination is getInclination(orbitShip, parOrbitTarget).
  local posAN is getAscPos(orbitShip, parOrbitTarget).
  local posDN is getDescPos(orbitShip, parOrbitTarget).

  local velNow is getVelFromTA(orbitShip, taNow).
  if vdot(velNow, posAN) > 0 { // next node is AN
    planChangeInc(getTAFromPos(orbitShip, posAN), relInclination).
  } else {
    planChangeInc(getTAFromPos(orbitShip, posDN), -relInclination).
  }
}

function planMatchAltitudeSpecial {
  parameter parOrbitTarget.
  parameter parOrient. // "DN", "AN", "AN/DN", "Apo", "Peri"
  parameter parAltitude is -1. // not specified = compute from target orbit

  local orbitShip is extractOrbit(ship:orbit).

  local taTarget is 0.
  if parOrient = "Apo" {
    set taTarget to 180.
  } else if parOrient = "Peri" {
    set taTarget to 0.
  } else if parOrient = "AN/DN" or parOrient = "AN" or parOrient = "DN" {

    if parOrient = "AN/DN" {
      local posOurAN is getAscPos(orbitShip, parOrbitTarget).
      local taNow is ship:orbit:trueanomaly.
      local velNow is getVelFromTA(orbitShip, taNow).
      if vdot(velNow, posOurAN) > 0 { // our next node is AN, push THEIR AN (which is on opposite side)
        set parOrient to "AN".
      } else {
        set parOrient to "DN".
      }
    }

    if parOrient = "AN" {
      local posTheirAN is getAscPos(parOrbitTarget, orbitShip).
      set taTarget to getTAFromPos(parOrbitTarget, posTheirAN).
    } else if parOrient = "DN" {
      local posTheirDN is getDescPos(parOrbitTarget, orbitShip).
      set taTarget to getTAFromPos(parOrbitTarget, posTheirDN).
    }

  } else {
    print "Error planMatchAltitudeSpecial: parOrient " + parOrient + " seems incorrect.".
    return.
  }
  planMatchAltitude(parOrbitTarget, taTarget, parAltitude).
}

function planMatchAltitude {
  parameter parOrbitTarget.
  parameter parTATarget.
  parameter parAltitude is -1. // not specified = compute from target orbit

  local orbitShip is extractOrbit(ship:orbit).
  local taNow is ship:orbit:trueanomaly.

  if parAltitude = -1 {
    // minus body radius
    set parAltitude to getRadiusFromTA(parOrbitTarget, parTATarget) - parOrbitTarget[0]:radius.
  }

  planChangeAltitude(convertTA(180-parTATarget, parOrbitTarget, orbitShip), parAltitude).
}
