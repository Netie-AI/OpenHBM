* xor2 -- domino-logic XOR2, sweep + Monte-Carlo
* Loads the netlist exported from xschem; adapt to PDK as needed.

.title  xor2 corner sweep + MC

.include build/${PDK}/${CELL}/${CELL}.spice

* PDK device libs
.lib '${PDK_LIB}' tt
.option scale=1u

* Power
Vdd vdd 0 dc 0.8

* Inputs
Va a 0 PULSE(0 0.8 0 50p 50p 1n 2n)
Vb b 0 PULSE(0 0.8 0 50p 50p 0.5n 1n)

* Load
Cl out 0 1f

X1 a b out vdd 0 xor2

* Analyses
.tran 1p 10n
.measure tran tphl_a TRIG v(a) val=0.4 RISE=1 TARG v(out) val=0.4 FALL=1
.measure tran tplh_a TRIG v(a) val=0.4 FALL=1 TARG v(out) val=0.4 RISE=1

.control
* corner sweep over (tt, ss, ff)
foreach corner tt ss ff
  altermod 'simulator lang=spice .lib '${PDK_LIB}' $corner'
  run
end

* Monte-Carlo, 100 runs
mc_runs 100
mc_savecurrents = 0
mc_runtype gauss
mc seed 42 100
.endc

.end
