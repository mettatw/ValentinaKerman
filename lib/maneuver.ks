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
function planChangeAltitude { // (ta, alt)
  parameter parTA. // True anomaly at burn point, 0 for periapsis
  parameter parAlt.

  local kepShip is kepKSP(ship:orbit).
  local kepNew is kepModChangeAlt(kepShip, parTA, parAlt).
  local taNew is kepNew[".taOfPos"](kepShip[".posOfTA"](parTA)).

  local velDelta is kepNew[".velOfTA"](taNew) - kepShip[".velOfTA"](parTA).
  print "----> CHALT alt=" + round(parAlt/1000, 1) + "km @ " + round(parTA, 1).
  addNode(makeNodeFromVec(parTA, velDelta)).
}

// Just a convenient warpper around planChangeAltitude
function planChangePeriod { // (ta, period)
  parameter parTA. // True anomaly at burn point, 0 for periapsis
  parameter parPeriod.

  local kepShip is kepKSP(ship:orbit).
  local smaNew is getOrbitSMAFromPeriod(kepShip["mu"], parPeriod).
  local radiusHere is kepShip[".rOfTA"](parTA).

  local radiusThere is smaNew*2 - radiusHere.
  planChangeAltitude(parTA, radiusThere - kepShip["brad"]).
}

function planChangeInc { // (ta, dinc)
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

function planMatchInc { // (kep)
  parameter parKep.

  local kepShip is kepKSP(ship:orbit).
  local taNow is ship:orbit:trueanomaly.

  local relInc is kepShip[".relInc"](parKep).
  local taAN is kepShip[".taAtRelAsc"](parKep).
  local posAN is kepShip[".posOfTA"](taAN).
  local posDN is -posAN.

  local velNow is kepShip[".velOfTA"](taNow).
  if vdot(velNow, posAN) > 0 { // next node is AN
    planChangeInc(taAN, -relInc).
  } else {
    planChangeInc(angNorm(taAN+180), relInc).
  }
}

function planMatchAltitudeSpecial { // {kep, orient, [alt=-1])
  parameter parKep.
  parameter parOrient. // "DN", "AN", "AN/DN", "Apo", "Peri"
  parameter parAltitude is -1. // not specified = compute from target orbit, "peri" or "apo" also work

  local kepShip is kepKSP(ship:orbit).
  local taNow is ship:orbit:trueanomaly.

  local taTarget is 0.
  if parOrient = "Apo" {
    set taTarget to 180.
  } else if parOrient = "Peri" {
    set taTarget to 0.
  } else if parOrient = "AN/DN" or parOrient = "AN" or parOrient = "DN" {

    local taOurAN is kepShip[".taAtRelAsc"](parKep).
    local taOurDN is angNorm(taOurAN+180).

    if parOrient = "AN/DN" {
      local velNow is kepShip[".velOfTA"](taNow).
      if vdot(velNow, kepShip[".posOfTA"](taOurAN)) > 0 { // our next node is AN, push THEIR AN (which is on opposite side)
        set parOrient to "AN".
      } else {
        set parOrient to "DN".
      }
    }

    if parOrient = "AN" {
      set taTarget to parKep[".taAtRelAsc"](kepShip).
    } else if parOrient = "DN" {
      set taTarget to angNorm(180+parKep[".taAtRelAsc"](kepShip)).
    }

  } else {
    print "Error planMatchAltitudeSpecial: parOrient " + parOrient + " seems incorrect.".
    return.
  }

  if parAltitude = "peri" {
    set parAltitude to parKep[".altOfTA"](0).
  } else if parAltitude = "apo" {
    set parAltitude to parKep[".altOfTA"](180).
  }

  planMatchAltitude(parKep, taTarget, parAltitude).
}

function planMatchAltitude { // (kep, ta, [alt=-1])
  parameter parKep.
  parameter parTATarget.
  parameter parAltitude is -1. // not specified = compute from target orbit

  local kepShip is kepKSP(ship:orbit).
  local taNow is ship:orbit:trueanomaly.

  if parAltitude = -1 {
    set parAltitude to parKep[".altOfTA"](parTATarget).
  }

  //print "====". // DEBUG
  //print parTATarget. // DEBUG
  //print parTATarget+180.
  //print parKep[".convTA"](kepShip, 180+parTATarget).

  planChangeAltitude(parKep[".convTA"](kepShip, 180+parTATarget), parAltitude).
}
