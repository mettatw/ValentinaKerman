// Convenient actions for ship-related things
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

// Do part testing contract on a part
function doPartTesting { // (tag)
  parameter parTag.
  ship:partsdubbed(parTag)[0]:getmodule("ModuleTestSubject"):doevent("Run Test").
}

function waitActive { // wait cpu vessel became active one
  if ship <> kuniverse:activevessel {
    print "Waiting until we became the active vessel...".
    wait until ship <> kuniverse:activevessel.
  }
}
