// Various functions for kepler orbit elements
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
function kepAP {
  parameter parBody.
  parameter parAp.
  parameter parPe.
  parameter parInc.
  parameter parLan.
  parameter parAop.

  local apReal is parAp + parBody:radius.
  local peReal is parPe + parBody:radius.
  local sma is (parAp + parPe)/2 + parBody:radius.

  local rslt is lexicon("body", parBody, "inc", parInc, "lan", parLan, "aop", parAop,
    "ap", apReal,
    "pe", peReal,
    "sma", sma,
    "ecc", 1 - (2 / (1 + apReal / peReal)),
    "period", 2 * constant:pi * sqrt(sma^3 / parBody:mu)
  ).
  return __kepAddSuffix(rslt).
}

// Get the values from an actual orbit object
function kepKSP {
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
  set kepRaw[".posOfTA"] to {
    parameter parTA.
    set parTA to angNorm(parTA).
    local radius is kepRaw[".rOfTA"](parTA).
    return kepRaw[".pqwTo"](V(cos(parTA)*radius, sin(parTA)*radius, 0)).
  }.
  set kepRaw[".velOfTA"] to {
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
