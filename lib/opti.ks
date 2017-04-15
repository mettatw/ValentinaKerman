// Numerical optimizations
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

// Brent method for minimization (unconstrained)
// No check on parameter ordering, assuming Xmin<Xguess<Xmax
// adapted from https://github.com/TriggerAu/TransferWindowPlanner/blob/master/TransferWindowPlanner/SharedStuff/LambertSolver.cs
// by TriggerAu, MIT licensed
function optiBrentFree { // (func, xmin, xmax, [tol], [guess], [val=identity]) return [x, fxReal]
  parameter parFunc.
  parameter parXMin.
  parameter parXMax.
  parameter parTol is 1e-5.
  parameter parXGuess is "guess". // can be "guess" to auto derive from golden sect
  parameter parValFunc is {parameter x. return x.}. // from function result to 1-dim "value", default to identity function

  local cgold is 0.38196601125.
  local a is parXmin. // for easier writing
  local b is parXmax. // for easier writing
  if parXGuess = "guess" {
    set parXGuess to a + cgold * (b-a).
  }
  local x is parXGuess. // point with least function value so far
  local fxReal is parFunc(x).  local fx is parValFunc(fxReal).

  // Try to evaluate a and b, see if that's better solution than x
  local faReal is parFunc(a).  local fa is parValFunc(faReal).
  local fbReal is parFunc(b).  local fb is parValFunc(fbReal).
  if fa < fx or fb < fx {
    if fa < fb {
      set x to a.
      set fxReal to faReal. set fx to fa.
    } else {
      set x to b.
      set fxReal to fbReal. set fx to fb.
    }
  }

  local xu is x. // point evaluated most recently
  local fu is fx.
  local xw is x. // point with second least function value
  local fw is fx.
  local xv is x. // previous value of w
  local fv is fx.
  local delta2 is 0. // distance moved on step before previous
  local delta1 is 0. // distance moved on previous step, d in paper

  print "init: "+ x +" => "+ fx.

  from {local itr is 1.} until itr > 100 step {set itr to itr+1.} do {
    local xm is (a+b)/2. // midpoint, for convergence checking
    local tol is abs(x)*parTol + 1e-7. // 1e-7 is to prevent zero problems when x is zero
    if abs(x-xm) <= 2*tol-(b-a)/2 {
      return list(x, fxReal).
    }
    if itr >= 100 {
      print "optiBrentFree: does not seem to converge".
      return list(x, fxReal).
    }

    local xr is 0. local xq is 0. local xp is 0.
    local delta3 is 0. // just a temporary variable
    if abs(delta2) > tol { // attempt to do parabolic fit
      set xr to (x-xw)*(fx-fv).
      set xq to (x-xv)*(fx-fw).
      set xp to (x-xv)*xq - (x-xw)*xr.
      set xq to 2*(xq-xr).
      if xq > 0 { set xp to -xp. }
      set xq to abs(xq).

      set delta3 to delta2. // just a temporary variable
      set delta2 to delta1.
    }

    if abs(xp) < abs(xq*delta3/2) and xp > xq*(a-x) and xp < xq*(b-x) { // accept this parabola
      set delta1 to xp/xq.
      set xu to x + delta1.

      // We don't want to evaluate f for x within 2 * tol of a or b
      if (xu - a) < 2*tol or (b - xu) < 2*tol {
        if x < xm {
          set delta1 to tol.
        } else {
          set delta1 to -tol.
        }
      } // end if lower than tol check
    } else { // end if accepting parabolic fit, else use golden section
      if x < xm {
        set delta2 to b-x.
      } else {
        set delta2 to a-x.
      }
      set delta1 to cgold*delta2.

      if abs(delta1) >= tol {
        set xu to x + delta1.
      } else if delta1 > 0 { // meaning >0 but <tol
        set xu to x + tol.
      } else {
        set xu to x - tol.
      }
    } // end fallback to golden section

    local fuReal is parFunc(xu).
    set fu to parValFunc(fuReal).

    if fu <= fx { // got new lowest point
      if xu < x { // set old lowest point as new bound
        set b to x.
      } else {
        set a to x.
      }
      set xv to xw. set fv to fw.
      set xw to x. set fw to fx.
      set x to xu. set fx to fu. set fxReal to fuReal.
      
    } else { // not actually new lowest point
      if xu < x {
        set a to xu.
      } else {
        set b to xu.
      }

      if fu <= fw or xw = x {
        set xv to xw. set fv to fw.
        set xw to xu. set fw to fu.
      } else if fu <= fv or xv = x or xv = xw {
        set xv to xu. set fv to fu.
      }
    } // end point updating

  } // end main loop

}

// Powell's method for minimization (unconstrained)
//function optiPowellFree { // (func(taking a list), xmin(list), xmax(list), [tol], [guess(list)], [val=identity]) return [x(list), fxReal]
//  parameter parFunc.
//  parameter parXMin.
//  parameter parXMax.
//  parameter parTol is 1e-5.
//  parameter parXGuess is "guess". // can be "guess" to auto derive
//  parameter parValFunc is {parameter x. return x.}. // from function result to 1-dim "value", default to identity function
//
//  local nDim is parXmin:length.
//  local cgold is 0.38196601125.
//  if parXGuess = "guess" {
//    set parXGuess to list().
//    from {local d is 0.} until d >= nDim step {set d to d+1.} do {
//      parXGuess:insert(d, parXMin[d] + cgold*(parXMax[d]-parXMin[d])).
//    }
//  }
//  local x is parXGuess:copy. // point with least function value so far
//  local fxReal is parFunc(x).  local fx is parValFunc(fxReal).
//
//  print "init: "+ x +" => "+ fx.
//
//  from {local itr is 1.} until itr > 100 step {set itr to itr+1.} do {
//    if SOME CONVERGE TEST {
//      return list(x, fxReal).
//    }
//    if itr >= 100 {
//      print "optiPowellFree: does not seem to converge".
//      return list(x, fxReal).
//    }
//  }
//}
