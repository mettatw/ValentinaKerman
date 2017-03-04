// Call a function
@lazyglobal off.

parameter nameFunc.
parameter par1 is -776922818.
parameter par2 is -776922818.
parameter par3 is -776922818.
parameter par4 is -776922818.
parameter par5 is -776922818.

runoncepath("lib/all").
runoncepath("sub/all").

local _exec_str to "global _rtn is " + nameFunc + "(".
if par1 <> -776922818 {
  set _exec_str to _exec_str + par1.
}
if par2 <> -776922818 {
  set _exec_str to _exec_str + ", " + par2.
}
if par3 <> -776922818 {
  set _exec_str to _exec_str + ", " + par3.
}
if par4 <> -776922818 {
  set _exec_str to _exec_str + ", " + par4.
}
if par5 <> -776922818 {
  set _exec_str to _exec_str + ", " + par5.
}
set _exec_str to _exec_str + ").".

deletepath("1:/_exec").
log _exec_str to "1:/_exec".
print "Running function: " + _exec_str.
runpath("1:/_exec").
print _rtn.
