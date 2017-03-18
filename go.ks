// Call a function
@lazyglobal off.

local tagReal is core:part:tag.
if tagReal:startswith("INACTIVE") {
  set tagReal to tagReal:replace("INACTIVE:", "").
}
if tagReal:length > 0 {
  runpath("mission/" + tagReal).
} else {
  print "Go: no part tag specified, exiting".
}
