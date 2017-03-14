// Kepler orbit object
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

runoncepath("lib/kepmath").

// ====== The Kep Object ======

// Basically a lexicon of orbital elements, not including state variables (anomaly etc.). Keys:
// body: the central body this is orbiting
// ap/pe: apoapsis/periapsis radius in meter (not the altitude used in ksp)
// inc: inclination
// lan/aop: longtitude of ascending node / argument of periapsis
// sma/ecc: semi-major axis / eccentricity
// period: orbiting period
// + Other convenient constants
// brad/arad/mu: body:radius/atmospheric radius/body:mu

// Basic constructor: input body/ap/pe/inc/lan/aop
// AP/PE in the input here is altitude above sea level, not radius as used in the lexicon
function kepAP { // (body, ap, pe, inc, lan, aop)
  parameter parBody.
  parameter parAp.
  parameter parPe.
  parameter parInc.
  parameter parLan.
  parameter parAop.

  local apReal is parAp + parBody:radius.
  local peReal is parPe + parBody:radius.

  local rslt is lexicon("body", parBody, "inc", parInc, "lan", parLan, "aop", parAop,
    "ap", apReal, "pe", peReal).
  return __kepAddSuffix(rslt).
}

// Get the values from an actual orbit object
function kepKSP { // (orbit, patch)
  parameter parOrbit.
  parameter parPatch is 0. // -1 for last patch

  if parPatch = -1 {
    until not parOrbit:hasNextPatch {
      set parOrbit to parOrbit:nextpatch.
    }
  } else if parPatch > 0 {
    local idx is 0.
    for idx in range(parPatch) {
      set parOrbit to parOrbit:nextpatch.
    }
  }

  local bodyParent is parOrbit:body.
  local apReal is parOrbit:apoapsis + bodyParent:radius.
  local peReal is parOrbit:periapsis + bodyParent:radius.

  local rslt is lexicon("body", bodyParent, "inc", parOrbit:inclination,
    "lan", parOrbit:lan, "aop", parOrbit:argumentofperiapsis,
    "ap", apReal, "pe", peReal,
    "sma", parOrbit:semimajoraxis, "ecc", parOrbit:eccentricity,
    "period", parOrbit:period
  ).
  return __kepAddSuffix(rslt).
}

// Internal function: add pseudo suffixes to lexicon
// Warning: this WILL MUTATE the original object
function __kepAddSuffix {
  parameter kepRaw.

  // convenient constants
  set kepRaw["brad"] to kepRaw["body"]:radius.
  set kepRaw["arad"] to kepRaw["body"]:radius + kepRaw["body"]:atm:height.
  set kepRaw["mu"] to kepRaw["body"]:mu.

  // missing elements
  if not kepRaw:haskey("ecc") and kepRaw:haskey("ap") and kepRaw:haskey("pe") {
    set kepRaw["ecc"] to 1 - (2 / (1 + kepRaw["ap"] / kepRaw["pe"])).
  }
  if not kepRaw:haskey("sma") and kepRaw:haskey("ap") and kepRaw:haskey("pe") {
    set kepRaw["sma"] to (kepRaw["ap"] + kepRaw["pe"])/2.
  }
  if not kepRaw:haskey("period") and kepRaw:haskey("sma") {
    set kepRaw["period"] to 2 * constant:pi * sqrt(kepRaw["sma"]^3 / kepRaw["mu"]).
  }

  // coordinates
  set kepRaw[".vecPeri"] to {
    return getVecOrbitPeri(kepRaw["lan"], kepRaw["aop"], kepRaw["inc"], kepRaw["pe"]).
  }.
  set kepRaw[".vecPlane"] to {
    return getVecOrbitPlane(kepRaw["lan"], kepRaw["inc"]).
  }.
  set kepRaw[".pqwFrom"] to {
    parameter parVec.
    return convertToOrbitFrame(kepRaw["lan"], kepRaw["aop"], kepRaw["inc"], parVec).
  }.
  set kepRaw[".pqwTo"] to {
    parameter parVec.
    return convertFromOrbitFrame(kepRaw["lan"], kepRaw["aop"], kepRaw["inc"], parVec).
  }.

  // plain numbers
  set kepRaw[".taAtAsc"] to {
    return 360 - kepRaw["aop"].
  }.
  set kepRaw[".rOfTA"] to {
    parameter parTA.
    return getOrbitRadiusFromTA(kepRaw["sma"], kepRaw["ecc"], parTA).
  }.
  set kepRaw[".altOfTA"] to {
    parameter parTA.
    return getOrbitRadiusFromTA(kepRaw["sma"], kepRaw["ecc"], parTA) - kepRaw["brad"].
  }.
  set kepRaw[".vOfTA"] to {
    parameter parTA.
    return getOrbitSpeedFromTA(kepRaw["sma"], kepRaw["ecc"], kepRaw["mu"], parTA).
  }.
  set kepRaw[".taOfPos"] to {
    parameter parPos.
    return getOrbitTAFromPos(kepRaw["lan"], kepRaw["aop"], kepRaw["inc"], parPos).
  }.

  // vectors
  set kepRaw[".posOfTA"] to { // (ta)
    parameter parTA.
    set parTA to angNorm(parTA).
    local radius is kepRaw[".rOfTA"](parTA).
    return kepRaw[".pqwTo"](V(cos(parTA)*radius, sin(parTA)*radius, 0)).
  }.
  set kepRaw[".velOfTA"] to { // (ta)
    parameter parTA.
    set parTA to angNorm(parTA).
    local ea is 2*arctan2(sqrt((1-kepRaw["ecc"])/(1+kepRaw["ecc"]))*sin(parTA/2), cos(parTA/2)).
    local radius is kepRaw[".rOfTA"](parTA).
    return kepRaw[".pqwTo"](V(-sin(ea), sqrt(1-kepRaw["ecc"]^2)*cos(ea), 0))
      * sqrt(kepRaw["mu"]*kepRaw["sma"])/radius.
  }.

  // between TA and MA
  set kepRaw[".maFromTA"] to { // (ta)
    parameter parTA.
    return getOrbitMAFromTA(kepRaw["ecc"], parTA).
  }.
  set kepRaw[".taFromMA"] to { // (ma)
    parameter parMA.
    return getOrbitTAFromMA(kepRaw["ecc"], parMA).
  }.
  set kepRaw[".timeThruTA"] to { // (ta1, ta2)
    parameter parTA1.
    parameter parTA2.
    return getOrbitTimeThroughTA(kepRaw["period"], kepRaw["ecc"], parTA1, parTA2).
  }.
  set kepRaw[".taAfterTime"] to { // (ta, time)
    parameter parTA.
    parameter parTime.
    return getOrbitTAAfterTime(kepRaw["period"], kepRaw["ecc"], parTA, parTime).
  }.

  // Regarding another orbit...
  // unsigned relative inclination
  set kepRaw[".relInc"] to { // (kep)
    parameter parKep.
    local plane1 is kepRaw[".vecPlane"]().
    local plane2 is parKep[".vecPlane"]().
    return vang(plane1, plane2).
  }.
  set kepRaw[".taAtRelAsc"] to { // (kep)
    parameter parKep.

    local plane1 is kepRaw[".vecPlane"]().
    local plane2 is parKep[".vecPlane"]().
    local vecANDir is vcrs(plane1, plane2).
    return kepRaw[".taOfPos"](vecANDir).
  }.
  set kepRaw[".convTA"] to { // (kep, ta)
    parameter parKep.
    parameter parTA.
    return convertOrbitTA(kepRaw["lan"], kepRaw["aop"], parKep["lan"], parKep["aop"], parTA).
  }.

  return kepRaw.
}

// ====== Advanced Construction of Orbit ======

// Construct from a pair of state vector
// https://downloads.rene-schwarz.com/download/M002-Cartesian_State_Vectors_to_Keplerian_Orbit_Elements.pdf
function kepState { // (body, pos, vel)
  parameter parBody.
  parameter parPos.
  parameter parVel.

  local sam is vcrs(parPos, parVel). // specific angular momentum
  local vecEcc is vcrs(parVel, sam)/parBody:mu - parPos:normalized. // eccentricity vector
  local ecc is vecEcc:mag.

  local vecAN is vcrs(sam, V(0,-1,0)). // ascending node
  local inc is vang(V(0,-1,0), sam). // inclination, will only be positive here
  local lan is vang(solarprimevector, vecAN). // longitude of ascending node
  if vang(vrot(solarprimevector, V(0,-1,0), lan), vecAN) > 0.5 {
    set lan to 360-lan.
  }
  local aop is vang(vecEcc, vecAN). // argument of periapsis
  if vang(vrot(vecAN, sam, aop), vecEcc) > 0.5 {
    set aop to 360-aop.
  }

  local soe is parVel:mag^2/2 - parBody:mu/parPos:mag.
  local sma is -parBody:mu / 2 / soe.
  local ap is sma * (1+ecc) - parBody:radius.
  local pe is sma * (1-ecc) - parBody:radius.
  return kepAP(parBody, ap, pe, inc, lan, aop).
}

// ====== Modify the Kep Object ======

// Make an orbit with a TA as one *apsis, and some altitude as another
function kepModChangeAlt { // (kep, ta, alt)
  parameter parKep.
  parameter parTA.
  parameter parAlt.

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

// Make an orbit changing inclination at TA
function kepModChangeInc { // (kep, ta, d-inc)
  parameter parKep.
  parameter parTA.
  parameter parDeltaInc.

  local velBefore is parKep[".velOfTA"](parTA).
  local velAfter is vrot(velBefore, parKep[".posOfTA"](parTA), -parDeltaInc).

  return kepState(parKep["body"], parKep[".posOfTA"](parTA), velAfter).
}
