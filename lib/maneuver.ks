// Do some pre-defined maneuver, and return the new Kep
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

// Make an orbit with a TA as one *apsis, and some altitude as another
function kepModChangeAlt { // (kep, ta, [alt=current])
  parameter parKep.
  parameter parTA.
  parameter parAlt is -1.

  if parAlt = -1 {
    set parAlt to parKep[".rOfTA"](parTA) - parKep["brad"].
  }

  local altBurn is parKep[".altOfTA"](parTA).
  if (parAlt > altBurn) { // current point will be new periapsis
    return kepAP(parKep["body"], parAlt, altBurn, parKep["inc"], parKep["lan"],
      angNorm(parKep["aop"] + parTA) // new aop
    ).
  } else {
    return kepAP(parKep["body"], altBurn, parAlt, parKep["inc"], parKep["lan"],
      angNorm(parKep["aop"] + parTA + 180) // new aop
    ).
  }
}
function getDvvChangeAltitude { // (kep, ta, [alt=current]) wrapper
  parameter parKep.
  parameter parTA. // True anomaly at burn point
  parameter parAlt is -1.

  return parKep[".dvvAt"](kepModChangeAlt(parKep, parTA, parAlt), parTA).
}

// Make an orbit changing inclination at TA
function kepModChangeInc { // (kep, ta, d-inc)
  parameter parKep.
  parameter parTA.
  parameter parDeltaInc.

  local velBefore is parKep[".velOfTA"](parTA).
  local velAfter is vrot(velBefore, parKep[".posOfTA"](parTA), -parDeltaInc).

  return kepState(parKep["body"], parKep[".posOfTA"](parTA), velAfter).
}
function getDvvChangeInc { // (kep, ta, d-inc)
  parameter parKep.
  parameter parTA.
  parameter parDeltaInc.

  // Not using the kep object here, just compute the appropriate velocity change
  local velBefore is parKep[".velOfTA"](parTA).
  local velAfter is vrot(velBefore, parKep[".posOfTA"](parTA), -parDeltaInc).

  return parKep[".dvvFrom"](parTA, velAfter-velBefore).
}


// Just a convenient warpper around planChangeAltitude
//function planChangePeriod { // (ta, period)
//  parameter parTA. // True anomaly at burn point, 0 for periapsis
//  parameter parPeriod.
//
//  local kepShip is kepKSP(ship:orbit).
//  local smaNew is getOrbitSMAFromPeriod(kepShip["mu"], parPeriod).
//  local radiusHere is kepShip[".rOfTA"](parTA).
//
//  local radiusThere is smaNew*2 - radiusHere.
//  planChangeAltitude(parTA, radiusThere - kepShip["brad"]).
//}

// ====== Based on other orbit ======

function kepModMatchInc { // (kep, kep2)
  parameter parKep.
  parameter parKepTarget.

  return kepAPRaw(parKep["body"], parKep["ap"], parKep["pe"],
    parKepTarget["inc"], parKepTarget["lan"],
    parKep["aop"] + parKep["lan"] - parKepTarget["lan"]
    ).
}
function getDvvMatchInc { // (kep, kep2, taNow)
  parameter parKep.
  parameter parKepTarget.
  parameter parTANow.

  // Implement this by computing the inclination, instead of directly use new orbit
  // No idea why the latter case produces inaccurate maneuver... (changed ap/pe)
  local relInc is parKep[".relInc"](parKepTarget).
  local taAN is parKep[".taAtRelAsc"](parKepTarget).
  local taNode is parKep[".taAtNextNode"](parKepTarget, parTANow).

  if abs(taAN - taNode) < 1 {
    return getDvvChangeInc(parKep, taNode, -relInc).
  } else { // at DN
    return getDvvChangeInc(parKep, taNode, relInc).
  }
}

//function planMatchAltitude { // (kep, ta, [alt=-1]) NOTE: ta is target orbit ta, not ours
//  parameter parKep.
//  parameter parTATarget.
//  parameter parAltitude is -1. // not specified = compute from target orbit
//
//  local kepShip is kepKSP(ship:orbit).
//  local taNow is ship:orbit:trueanomaly.
//
//  if parAltitude = -1 {
//    set parAltitude to parKep[".altOfTA"](parTATarget).
//  }
//
//  planChangeAltitude(parKep[".convTA"](kepShip, 180+parTATarget), parAltitude).
//}
//
//function planMatchOrbit { // (kep, taOur) no check whether actually touch orbit
//  parameter parKep.
//  parameter parTATarget.
//
//  local kepShip is kepKSP(ship:orbit).
//  local taOur is parKep[".convTA"](kepShip, parTATarget).
//  local velTheir is parKep[".velOfTA"](parTATarget).
//  local velOur is kepShip[".velOfTA"](taOur).
//  addNode(makeNodeFromVec(parTA, velTheir-velOur)).
//}
