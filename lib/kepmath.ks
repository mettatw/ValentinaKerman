// Kepler orbit functions
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

runoncepath("lib/math").

// ====== Coordinate Axises ======

// Get periapsis position vector, relative to body
function getVecOrbitPeri { // (lan, aop, inc, pe)
  parameter parLan.
  parameter parAop.
  parameter parInc.
  parameter parPe.

  // Rotate to find periapsis position on equator
  local vecANDir is vrot(solarprimevector, V(0,-1,0), parLan).
  local vecPeriEq is vrot(solarprimevector, V(0,-1,0), parLan + parAop).

  // Then rotate down the resulting vector to find its actual position on the orbiting plane
  // Also, multiply it by the correct vector size
  return vrot(vecPeriEq, vecANDir, -parInc):normalized * parPe.
}

// Get the normal vector of orbit plane, relative to body
function getVecOrbitPlane { // (lan, inc)
  parameter parLan.
  parameter parInc.

  local vecANDir is vrot(solarprimevector, V(0,-1,0), parLan).

  return vrot(V(0,-1,0), vecANDir, -parInc).
}

// Convert a vector into an orbit's perifocal frame coordinates
// PQW: p=periapsis, q=90-degree, w=plane vector
function convertToOrbitFrame { // (lan, aop, inc, vector_to_convert)
  parameter parLan.
  parameter parAop.
  parameter parInc.
  parameter parVec.

  local vecANDir is vrot(solarprimevector, V(0,-1,0), parLan).
  local vecPeriEq is vrot(solarprimevector, V(0,-1,0), parLan + parAop).
  local axisPeri is vrot(vecPeriEq, vecANDir, -parInc):normalized. // p
  local axisPlane is vrot(V(0,-1,0), vecANDir, -parInc):normalized. // w
  local axisThird is vcrs(axisPlane, axisPeri):normalized. // q

  return V(vdot(parVec, axisPeri), vdot(parVec, axisThird), vdot(parVec, axisPlane)).
}

// Convert a vector out from an orbit's perifocal frame coordinates
function convertFromOrbitFrame { // (lan, aop, inc, vector_to_convert)
  parameter parLan.
  parameter parAop.
  parameter parInc.
  parameter parVec.

  local vecANDir is vrot(solarprimevector, V(0,-1,0), parLan).
  local vecPeriEq is vrot(solarprimevector, V(0,-1,0), parLan + parAop).
  local axisPeri is vrot(vecPeriEq, vecANDir, -parInc):normalized. // p
  local axisPlane is vrot(V(0,-1,0), vecANDir, -parInc):normalized. // w
  local axisThird is vcrs(axisPlane, axisPeri):normalized. // q

  return axisPeri*parVec:x + axisThird*parVec:y + axisPlane*parVec:z.
}

// ====== Plain Numbers ======

// https://en.wikipedia.org/wiki/True_anomaly#Radius_from_true_anomaly
function getOrbitRadiusFromTA { // (sma, ecc, ta)
  parameter parSma.
  parameter parEcc.
  parameter parTA.

  return parSma * (1 - parEcc^2) / (1 + parEcc * cos(parTA)).
}

// https://en.wikipedia.org/wiki/Orbital_speed
// basically from vis-viva equation
function getOrbitSpeedFromTA { // (sma, ecc, mu, ta)
  parameter parSma.
  parameter parEcc.
  parameter parMu.
  parameter parTA.

  local radius is getOrbitRadiusFromTA(parSma, parEcc, parTA).

  return sqrt(parMu * (2/radius - 1/parSma)).
}

// ====== Vectors ======

// Get true anomaly from position vector
// This one can tolerate wrong magnitude on direction vector
function getOrbitTAFromPos { // (lan, aop, inc, vec)
  parameter parLan.
  parameter parAop.
  parameter parInc.
  parameter parPos.

  local vecPeri is getVecOrbitPeri(parLan, parAop, parInc, 1).
  // Normal direction orbit: inclination-90 < 0
  // TA < 180 degree: cross(periapsis, position) will point downward (y<0)
  if (parInc-90) * vcrs(vecPeri, parPos):y > 0 {
    return vang(vecPeri, parPos).
  } else {
    return 360 - vang(vecPeri, parPos).
  }
}

// ====== MA and TA ======

// Get mean anomaly from TA
function getOrbitMAFromTA { // (ecc, ta)
  parameter parEcc.
  parameter parTA.

  // Input value normalization
  if parTA >= 360 { set parTA to mod(parTA, 360). }.
  if parTA < 0 { set parTA to mod(parTA, 360) + 360. }.

  // Special cases, just return the answer
  if parTA = 0 { return 0. }
  if parTA = 180 { return 180. }

  // https://www.reddit.com/r/Kos/comments/4tm0wq/two_common_mistakes_people_make_when_calculating/
  local ea is 2*arctan2(sqrt((1-parEcc)/(1+parEcc))*sin(parTA/2), cos(parTA/2)).
  return ea - constant:radtodeg * parEcc * sin(ea).
}

// get TA from mean anomaly
function getOrbitTAFromMA { // (ecc, ma)
  parameter parEcc.
  parameter parMA.

  // Input value normalization & known answers
  set parMA to angNorm(parMA).
  if parMA = 0 { return 0. }
  if parMA = 180 { return 180. }

  local radMA is constant:degtorad * parMA.
  local currentEA is radMA. // very bad initial guess
  local correctionEA is 0.

  // Halley's method
  from {local itr is 0.} until itr > 20 step {set itr to itr+1.} do {
    local f is currentEA - parEcc * sin(constant:radtodeg*currentEA) - radMA.
    local ff is 1 - parEcc * cos(constant:radtodeg*currentEA).
    local fff is parEcc * sin(constant:radtodeg*currentEA).
    set correctionEA to 2*f*ff/(2*ff^2 - f*fff).
    if abs(correctionEA) < 1e-6 { break. }.
    set currentEA to currentEA - correctionEA.
  }
  set currentEA to constant:radtodeg * currentEA.
  return 2*arctan2(sqrt(1+parEcc)*sin(currentEA/2), sqrt(1-parEcc)*cos(currentEA/2)).
}


// Get elapsed time between two TAs
function getOrbitTimeThroughTA { // (period, ecc, ta1, ta2)
  parameter parPeriod.
  parameter parEcc.
  parameter parTA1.
  parameter parTA2.

  if parTA2 < parTA1 {
    set parTA2 to parTA2 + 360.
  }
  local periodAdditional is floor((parTA2-parTA1)/360).

  local ma1 is getOrbitMAFromTA(parEcc, parTA1).
  local ma2 is getOrbitMAFromTA(parEcc, parTA2).

  if ma2 >= ma1 {
    return parPeriod * ((ma2-ma1) / 360 + periodAdditional).
  } else {
    return parPeriod * ((360 - (ma1-ma2)) / 360 + periodAdditional).
  }
}

// Get TA after given time period and current TA
function getOrbitTAAfterTime { // (period, ecc, ta, delta-time)
  parameter parPeriod.
  parameter parEcc.
  parameter parTA.
  parameter parTime.

  local ma1 is getOrbitMAFromTA(parEcc, parTA).
  local ma2 is ma1 + 360/parPeriod*mod(parTime,parPeriod).
  if ma2 > 360 {
    set ma2 to ma2 - 360.
  }

  return getOrbitTAFromMA(parEcc, ma2).
}

// ====== Simple Calculations ======

// Find SMA according to period and gravitational constant
function getOrbitSMAFromPeriod { // (mu, period)
  parameter parMu.
  parameter parPeriod.

  return (parMu * parPeriod^2 / 4 / constant:pi^2)^(1.0/3.0).
}
