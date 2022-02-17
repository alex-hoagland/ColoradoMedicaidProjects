insheet using \\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD\Alex\Hoagland_Output\2.RDGraphs\Donut\/Binscatter_outcome4_data.csv

twoway (scatter outcome4 income_re, mcolor(navy) lcolor(maroon)) (function 7.29029693444e-06*x^2+-.0005066243484883*x+.0700476260799091, range(0 138) lcolor(maroon)) (function -8.22371116085e-07*x^2+.0009241545433517*x+.067380690902927, range(138 424.0855308449399) lcolor(maroon)), graphregion(fcolor(white)) xline(138, lpattern(dash) lcolor(gs8)) xtitle(income_re) ytitle(outcome4) legend(off order()) ytitle("Probability") ylab(, angle(0)) xtitle("Income (% FPL)")
