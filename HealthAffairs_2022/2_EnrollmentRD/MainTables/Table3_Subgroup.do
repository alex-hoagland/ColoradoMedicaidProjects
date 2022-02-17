/*******************************************************************************
* Title: Enrollment RD (Paper 2): Local linear RD table
* Created by: Alex Hoagland
* Created on: 3/22/2021
* Last modified on: 
* Last modified by: Alex Hoagland

* Purpose: 
		   
* Notes:
		
* Key edits: 
 
*******************************************************************************/


***** 0. Packages and directories, load data
* ssc install estout, replace
* ssc install rdrobust
* ssc install rd

global head "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD"
global sarah "$head\Sarah\Sarah Datasets"
global working "$head\Alex\Hoagland_WorkingData"
global output "$head\Alex\Hoagland_Output\3.EnrollmentPaper\"

cd "$head\Alex\"
use "$working\EnrollmentRD.dta", clear
drop if inrange(income_re,133.01,137.99)

* List covariates
local covar "mc_mathisp mc_matblack mc_white mc_mat_hs mc_mat_coll mc_complications mc_mat_married mc_pnv mc_chronic mc_matage mc_csec mc_preterm" 

* If you want to run this for a single variable
// local myvar "mc_mat_hs"
// gen group = 0 if `myvar' == 0
// replace group = 1 if `myvar' == 1
********************************************************************************


***** Reorder/rename outcome variables
rename outcome2 out_1anycomm
rename outcome8 out_2anymarket
rename outcome7 out_3onlymed

rename outcome3 out_4enroldur
rename outcome4 out_5disrupt
egen out_6countdisrupt = rowtotal(gap switch)
rename outcome5 out_7countgaps 
rename outcome6 out_8gapdur 
gen out_9countswitch = switch
gen out_10anyswitch = (switch > 0 & !missing(switch))
gen out_11anygap = (out_7countgaps > 0 & !missing(out_7))

// change this one from fraction of year to months 
replace out_8gapdur = out_8gapdur/100*(365/30)

* Order variables
order out_1a out_2 out_3 out_4 out_5 out_6 out_7 out_8 out_9 out_10 out_11

// Make sure you're only looking at the sample with enrollment info
foreach v of var out_* { 
    replace `v' = . if missing(out_3)
} 
********************************************************************************


***** Loop for all groups
local mygroups "mc_mat_hs mc_mat_married mc_complications"
local gcount = 0
foreach g of local mygroups { 
    local gcount = `gcount' + 1
	cap drop group 
    gen group = 0 if `g' == 0
	replace group = 1 if `g' == 1
	
	***** Summarize for either group 
	eststo full_low`gcount': qui estpost ci out_* if group == 0
	eststo full_high`gcount': qui estpost ci out_* if group == 1

	***** Run full parametric subgroup RD
	** Prepare the RD variables
	quietly{
		cap drop treated centered *_inter quad cub inter_main
		* Treatment dummy
		gen treated = (income_re >= 138)

		* Center the cut variable
		gen centered = income_re - 138

		* Create appropriate interactions/quadratic terms
		* Create variables for any of the desired models here
		gen lin_inter = centered * treated
		gen quad = centered * centered
		gen quad_inter = quad * treated
		gen cub = centered * quad
		gen cub_inter = cub * treated
		
		* Interact treatment dummy with main group
		gen inter_main = treated * group
	}

	foreach v of var out_* {
		reg `v' treated group inter_main centered quad cub ///
			lin_inter quad_inter cub_inter `covar', ///
			vce(cluster member_composite_id)
		eststo rd`gcount'_`v'
	}
	
	***** Build table (2 pieces?)
	cd "$output"
	esttab full_low`gcount' full_high`gcount' ///
		using Tab3a_Group`gcount'_FRAG.csv, /// 
		cells("b(pattern(1 1) fmt(2)) se(pattern(1 1) par fmt(2))") replace
		
	esttab rd`gcount'_out_1a* rd`gcount'_out_2* rd`gcount'_out_3* ///
		rd`gcount'_out_4* rd`gcount'_out_5* rd`gcount'_out_6* ///
		rd`gcount'_out_7* rd`gcount'_out_8* rd`gcount'_out_9* ///
		rd`gcount'_out_10* rd`gcount'_out_11* ///
		using Tab3b_Group`gcount'_FRAG.csv, replace ///
		cells(b(fmt(2) star) ci(fmt(2) par) p(fmt(3) par))	
}
********************************************************************************