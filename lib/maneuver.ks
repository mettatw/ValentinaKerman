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
runoncepath("lib/lambert").

// ====== The maneuver object ======

function manuTaDvv { // (kep, taNow, ta, dvv, [round=0])
  parameter parKep.
  parameter parTANow.
  parameter parTA.
  parameter parDvv.
  parameter parRound is 0.

  local rslt is lexicon("kep", parKep, "ta", parTA, "dvv", parDvv,
    "ut", time:seconds + parKep[".timeThruTA"](parTANow, parTA) + parRound*parKep["period"]
    ).
  return rslt.
}

// ====== Simple orbit changes ======

// Make an orbit with a TA as one *apsis, and some altitude as another
function kepModChangeAlt { // (ta, [alt=current], [kep])
  parameter parTA.
  parameter parAlt is -1.
  parameter parKep is -1.

  if parKep = -1 {
    set parKep to kepKSP(ship:orbit).
  }
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
function getManuChangeAlt { // (ta, [alt=current], [kep], [taNow], [round=0])
  parameter parTA. // True anomaly at burn point
  parameter parAlt is -1.
  parameter parKep is -1.
  parameter parTANow is -1. // True anomaly now
  parameter parRound is 0.

  if parKep = -1 {
    set parKep to kepKSP(ship:orbit).
  }
  if parTANow = -1 {
    set parTANow to ship:orbit:trueanomaly.
  }
  local dvvBurn is parKep[".dvvAt"](kepModChangeAlt(parTA, parAlt, parKep), parTA).
  return manuTaDvv(parKep, parTANow, parTA, dvvBurn, parRound).
}

// Make an orbit changing inclination at TA
function kepModChangeInc { // (ta, d-inc, [kep])
  parameter parTA.
  parameter parDeltaInc.
  parameter parKep is -1.

  if parKep = -1 {
    set parKep to kepKSP(ship:orbit).
  }

  local velBefore is parKep[".velOfTA"](parTA).
  local velAfter is vrot(velBefore, parKep[".posOfTA"](parTA), -parDeltaInc).

  return kepState(parKep["body"], parKep[".posOfTA"](parTA), velAfter).
}
function getManuChangeInc { // (ta, dinc, [kep], [taNow], [round=0])
  parameter parTA. // True anomaly at burn point
  parameter parDeltaInc.
  parameter parKep is -1.
  parameter parTANow is -1.
  parameter parRound is 0.

  if parKep = -1 {
    set parKep to kepKSP(ship:orbit).
  }
  if parTANow = -1 {
    set parTANow to ship:orbit:trueanomaly.
  }

  // Not using the kep object here, just compute the appropriate velocity change
  local velBefore is parKep[".velpqwOfTA"](parTA).
  local velAfter is vrot(velBefore, parKep[".pqwOfTA"](parTA), -parDeltaInc).

  local dvvBurn is parKep[".dvvFromPqw"](parTA, velAfter-velBefore).

  return manuTaDvv(parKep, parTANow, parTA, dvvBurn, parRound).
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

function kepModMatchInc { // (kep2, [kep])
  parameter parKepTarget.
  parameter parKep is -1.

  if parKep = -1 {
    set parKep to kepKSP(ship:orbit).
  }

  return kepAPRaw(parKep["body"], parKep["ap"], parKep["pe"],
    parKepTarget["inc"], parKepTarget["lan"],
    parKep["aop"] + parKep["lan"] - parKepTarget["lan"]
    ).
}
function getManuMatchInc { // (kep2, [kep], [taNow], [round=0])
  parameter parKepTarget.
  parameter parKep is -1.
  parameter parTANow is -1.
  parameter parRound is 0.

  if parKep = -1 {
    set parKep to kepKSP(ship:orbit).
  }
  if parTANow = -1 {
    set parTANow to ship:orbit:trueanomaly.
  }

  // Implement this by computing the inclination, instead of directly use new orbit
  // No idea why the latter case produces inaccurate maneuver... (changed ap/pe)
  local relInc is parKep[".relInc"](parKepTarget).
  local taAN is parKep[".taAtRelAsc"](parKepTarget).
  local taNode is parKep[".taAtNextNode"](parKepTarget, parTANow).

  if abs(taAN - taNode) < 1 {
    return getManuChangeInc(taNode, -relInc, parKep, parTANow, parRound).
  } else { // at DN
    return getManuChangeInc(taNode, relInc, parKep, parTANow, parRound).
  }
}

function kepModMatchAlt { // (kep2, ta, [kep])
  parameter parKepTarget.
  parameter parTATarget.
  parameter parKep is -1.

  if parKep = -1 {
    set parKep to kepKSP(ship:orbit).
  }

  local altBurn is parKepTarget[".altOfTA"](parTATarget).
  local taOur is parKepTarget[".convTA"](parKep, 180+parTATarget).
  return kepModChangeAlt(taOur, altBurn, parKep).
}
function getManuMatchAlt { // (kep2, ta, [kep], [taNow], [round=0])
  parameter parKepTarget.
  parameter parTATarget. // special value: can also be string "AN/DN"
  parameter parKep is -1.
  parameter parTANow is -1. // Our True anomaly now
  parameter parRound is 0.

  if parKep = -1 {
    set parKep to kepKSP(ship:orbit).
  }
  if parTANow = -1 {
    set parTANow to ship:orbit:trueanomaly.
  }
  
  if parTATarget = "AN/DN" {
    set parTATarget to parKep[".convTA"](parKepTarget, parKep[".taAtNextNode"](parKepTarget, parTANow, -1)).
  }

  local taOur is parKepTarget[".convTA"](parKep, 180+parTATarget).
  local dvvBurn is parKep[".dvvAt"](kepModMatchAlt(parKepTarget, parTATarget, parKep), taOur).
  return manuTaDvv(parKep, parTANow, taOur, dvvBurn, parRound).
}

function getManuMatchOrbit { // (kep2, ta, [kep], [taNow], [round=0])
  parameter parKepTarget.
  parameter parTATarget. // special value: can also be string "AN/DN"
  parameter parKep is -1.
  parameter parTANow is -1. // Our True anomaly now
  parameter parRound is 0.

  if parKep = -1 {
    set parKep to kepKSP(ship:orbit).
  }
  if parTANow = -1 {
    set parTANow to ship:orbit:trueanomaly.
  }
  if parTATarget = "AN/DN" {
    set parTATarget to parKep[".convTA"](parKepTarget, parKep[".taAtNextNode"](parKepTarget, parTANow)).
  }

  local taOur is parKepTarget[".convTA"](parKep, parTATarget).
  local dvvBurn is parKep[".dvvAt"](parKepTarget, taOur).
  return manuTaDvv(parKep, parTANow, taOur, dvvBurn, parRound).
}

// Do small course correction to some destination point on some other orbit
// Will be very errornous if used on large corrections
function getManuCorrectionOrbit { // (kep2, ta2, [kep], [taNow])
  parameter parKepTarget.
  parameter parTATarget. // special value: can also be string "AN/DN"
  parameter parKep is -1.
  parameter parTANow is -1. // Our True anomaly now

  if parKep = -1 {
    set parKep to kepKSP(ship:orbit).
  }
  if parTANow = -1 {
    set parTANow to ship:orbit:trueanomaly.
  }
  if parTATarget = "AN/DN" {
    set parTATarget to parKep[".convTA"](parKepTarget, parKep[".taAtNextNode"](parKepTarget, parTANow)).
  }

  // Do the correction 3 minutes later
  local taBurn is parKep[".taAfterTime"](parTANow, 180).

  local pqwEnd is parKep[".pqwFrom"](parKepTarget[".posOfTA"](parTATarget)).
  local pqwStart is parKep[".pqwOfTA"](taBurn).
  // Assume time is approximately proportional to straight-line distance
  local taTargetOur is parKepTarget[".convTA"](parKep, parTATarget).
  local dt is parKep[".timeThruTA"](taBurn, taTargetOur)
    / (parKep[".pqwOfTA"](taTargetOur) - pqwStart):mag * (pqwEnd - pqwStart):mag.

  local velpqwStart is parKep[".velpqwOfTA"](taBurn).
  local path is solveLambertLBPrograde(velpqwStart, pqwStart, pqwEnd, dt, parKep["mu"]).
  return manuTaDvv(parKep, parTANow, taBurn, parKep[".dvvFromPqw"](taBurn, path[0] - velpqwStart)).
}
