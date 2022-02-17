/*******************************************************************************
* Title: First stage regressions
* Created by: Alex Hoagland
* Created on: 4/21/2021
* Last modified on: 
* Last modified by: Alex Hoagland

* Purpose: 
		   
* Notes: 
		
* Key edits: 
   -  
*******************************************************************************/

***** 0. Directories & Packages
* ssc install psmatch2 

global sarah "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD\Sarah\Sarah Datasets"
global working "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD\Alex\Hoagland_WorkingData\Paper2"
global output "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD\Alex\Hoagland_Output\4.HealthOutcomesPaper"
********************************************************************************


***** 0. Specify what you want to run
local reg = 3 // Type of outcome you want run: 1=utilization counts, 2=utilization binary, ///
											// 3=person-level costs, 4=visit-level costs
local skew = 3 // Type of transformation: 1=asinh^{-1}(y), 2=log(y+1), 3=negative binomial
********************************************************************************


***** 1. Generate regression variables
use "$working/RestrictedSample_20210929.dta", clear

// Added 1/10/2022: change to 2020 USD using *medical services* component of CPI
// Source: https://www.statista.com/statistics/187228/consumer-price-index-for-medical-care-services-in-the-us-since-1960/
gen service_year = year(dob)
foreach v of varlist oop tc p_tc_* p_oop_* { 
	replace `v' = `v' / 1.0903 * (564.2/468.4) if service_year == 2014
	replace `v' = `v' / 1.0890 * (564.2/482) if service_year == 2015
	replace `v' = `v' / 1.0754 * (564.2/500.8) if service_year == 2016
	replace `v' = `v' / 1.0530 * (564.2/509) if service_year == 2017
	replace `v' = `v' / 1.0261 * (564.2/522.5) if service_year == 2018
	replace `v' = `v' / 1.0123 * (564.2/549.1) if service_year == 2019
}

// topcode # of visits too
replace ho_op = 50 if ho_op > 50
replace ho_pcp = 20 if ho_pcp > 20
replace ho_ed = 10 if ho_ed > 10

// Added 9/15/2021: Use unconditional means
replace p_tc_op = 0 if ho_op == 0
replace p_oop_op = 0 if ho_op == 0
replace p_tc_pcp = 0 if ho_pcp == 0 
replace p_oop_pcp = 0 if ho_pcp == 0
replace p_tc_prev = 0 if ho_prev == 0
replace p_oop_prev = 0 if ho_prev == 0
replace p_tc_ed = 0 if ho_ed == 0
replace p_oop_ed = 0 if ho_ed == 0
replace p_tc_ip = 0 if ho_ip == 0 
replace p_oop_ip = 0 if ho_ip == 0

// Aggregate to person level 
replace p_tc_op = p_tc_op * ho_op
replace p_oop_op = p_oop_op * ho_op
replace p_tc_pcp = p_tc_pcp * ho_pcp 
replace p_oop_pcp = p_oop_pcp * ho_pcp
replace p_tc_prev = p_tc_prev * ho_prev
replace p_oop_prev = p_oop_prev * ho_prev
replace p_tc_ed = p_tc_ed * ho_ed
replace p_oop_ed = p_oop_ed * ho_ed
replace p_tc_ip = p_tc_ip * ho_ip
replace p_oop_ip = p_oop_ip * ho_ip

local myvars age2 age3 mc_white mc_matblack mc_matasian mc_mathisp mc_bornoutside mc_mat_married mc_mat_hs mc_mat_coll mc_chronic mc_pnv mc_firstcare mc_complications mc_csec income2 income3 income4 income5 income6
		
local myouts_p ho_op ho_pcp ho_ed ho_ip
local myouts_n p_tc_prev p_oop_prev //  p_tc_ed p_tc_ip p_oop_ed p_oop_ip
local myouts_personweighted p_oop_ed p_oop_ip  // tc p_tc_op p_tc_pcp p_tc_ed p_tc_ip //  oop p_oop_op p_oop_pcp p_oop_ed p_oop_ip 

gen age1 = (inrange(mc_matage,18,27))
gen age2 = (inrange(mc_matage,30,39))
gen age3 = mc_matage >= 40

gen income2 = (inrange(income_re,101,138))
gen income3 = (inrange(income_re,139,200))
gen income4 = (inrange(income_re,201,265))
gen income5 = (inrange(income_re,266,300))
gen income6 = income_re > 300 & !missing(income_re)

gen byear = year(dob)
********************************************************************************


***** Regressions, saving treatment coefficient
*** 1. Person-level utilization counts
if (`reg' == 1) {
	cls
	foreach y of local myouts_p { 
    // poisson `y' group `myvars' i.byear, iterate(100) irr
	ttest `y', by(group) unequal
	glm `y' group `myvars' i.byear, family(nbinomial) link(log) iter(100)
}
}

*** 2. Person-level utilization (binary) 
else if (`reg' == 2) {
	cls
	foreach v of local myouts_p { 
    di "`v'"
    gen test = (`v' > 0 & !missing(`v'))
// 	sum test if group == 0
// 	sum test if group == 1
	ttest test, by(group) unequal
	glm test group `myvars' i.byear, link(logit) iter(100)
	// mfx, predict(pr)
	predict yhat
	replace yhat = yhat*100
	ttest yhat, by(group) unequal
	drop test yhat
}
}

*** 3. Person-level costs
else if (`reg' == 3) {
	cls
// 	// replace group = (group == 0)
// 	replace group = 2 if group == 1
// 	replace group = 1 if group == 0 
// 	replace group = 0 if group == 2
	
	if (`skew' == 1) { // IHS transform; estimates marginal effects using Bellemare & Wichman (2021)
		foreach y of local myouts_personweighted { 
		    
		ttest `y', by(group) unequal
		
		// Average % change for each group
		qui sum `y' if group == 0
		qui gen mean1 = `r(mean)'
		qui sum `y' if group == 1
		qui gen mean2 = `r(mean)'
		qui gen amean = (mean1+mean2)/2
	
		// IHS transform 
		gen ihs = asinh(`y')

		di " "
		di "OUTCOME: `y'"
		reg `y' group `myvars' i.byear
		glm ihs group `myvars' i.byear, iter(50)
	
		// use treatment coefficient to get chnage as % of base (average with each group)
 		matrix A = e(b)
 		matrix B = e(V)
 		
 		di "Marginal effect is " A[1,1] * amean
 		di "Lower Bound is " (A[1,1] - sqrt(B[1,1])*invt(e(df), 0.025))* amean
 		di "Upper Bound is " (A[1,1] + sqrt(B[1,1])*invt(e(df), 0.025))* amean
		drop ihs mean1 mean2 amean
	
		}
	}
	
	else if (`skew' == 2) { // Log transform
// 		replace group = (group == 0)
		foreach y of local myouts_personweighted { 
		   
		 //ttest `y', by(group) unequal
	
		// Log transform 
		gen mylog = log(`y'+1)

		di " "
		di "OUTCOME: `y'"
		glm mylog group `myvars' i.byear, iter(50) // `myvars' i.byear, link(log) iter(100)
		// `myvars' i.byear
		
// 		predict yhat, xb
// 		replace yhat = exp(yhat)
// 		ttest yhat, by(group) unequal
// 		drop yhat mylog
		
		// use treatment coefficient to get chnage as % of base (group == 0)
		matrix A = e(b)
		matrix B = e(V)
		qui sum `y' if group == 1

		di "Marginal effect is " -1*(exp(-1*A[1,1])-1) * `r(mean)'
		di "Lower Bound is " -1*(exp(-1*A[1,1] - sqrt(B[1,1])*invt(e(df), 0.025))-1) * `r(mean)'
		di "Upper Bound is " -1*(exp(-1*A[1,1] + sqrt(B[1,1])*invt(e(df), 0.025))-1) * `r(mean)'

		drop mylog
		}
	}
	
	else if (`skew' == 3) { // Negative binomial 
		foreach y of local myouts_personweighted { 
			di " "
			di "NEGATIVE BINOMIAL: OUTCOME `y'"
			nbreg `y' i.group `myvars' i.byear, iter(30) // , iter(50) link(nbinomial)
			margins group, atmeans
			// test group
		}
	}
}

*** 4. Visit-level costs
else if (`reg' == 4) {
	cls
	// replace group = (group == 0)
	foreach v of var ho_* { 
		replace `v' = 1 if `v' == 0
	}	// replace weights = 1 if weights = 0 (one person with 0 visits counts as one person with 1 visit)
	
	if (`skew' == 1) { // IHS transform; estimates marginal effects using Bellemare & Wichman (2021)
		foreach y of local myouts_n { 
	
		// IHS transform 
		gen ihs = asinh(`y')

		di " "
		di "OUTCOME: `y'"
		if strpos("`y'", "tc") { 
			local suf = substr("`y'", 6, .)
		}
		else if strpos("`y'", "oop") { 
			local suf = substr("`y'", 7, .)
		}
		glm ihs group `myvars' i.byear [fw=ho_`suf'], iter(50)
	
		// use treatment coefficient to get chnage as % of base (group == 0)
		matrix A = e(b)
		matrix B = e(V)
		sum `y' if group == 0
		di "Marginal effect is " A[1,1] * `r(mean)'
		di "Lower Bound is " (A[1,1] - sqrt(B[1,1])*invt(e(df), 0.025))* `r(mean)'
		di "Upper Bound is " (A[1,1] + sqrt(B[1,1])*invt(e(df), 0.025))* `r(mean)'
		drop ihs
	
		// Alternate approach: semi-elasticity of group dummy variable (Bellemare and Wichman)
		// 	predict u, working // using working residuals
		// 	matrix A = e(b) 
		// 	matrix B = e(V)
		// 	gen bhat = A[1,1]
		// 	gen ahat = A[1,27]
		//	
		// 	gen bhat_l = (A[1,1] - sqrt(B[1,1])*invt(e(df), 0.025))
		// 	gen ahat_l = (A[1,27] - sqrt(B[27,27])*invt(e(df), 0.025))
		// 	gen bhat_u = (A[1,1] - sqrt(B[1,1])*invt(e(df), 0.975))
		// 	gen ahat_u = (A[1,27] - sqrt(B[27,27])*invt(e(df), 0.975))
		//	
		// 	gen me = (sinh(ahat+bhat+u)/sinh(ahat+u)-1)*100
		// 	gen me_l = (sinh(ahat_l+bhat_l+u)/sinh(ahat_l+u)-1)*100
		// 	gen me_u = (sinh(ahat_u+bhat_u+u)/sinh(ahat_u+u)-1)*100
		//	
		// 	sum me, d
		// 	sum me_* // High amount of skewness in predictions: if abs(me) < 1e6
		//	
		// 	// Approximation (Bellemare and Wichman eqn 12)
		// 	di "Approximate elasticity: " (exp(A[1,1]-.5*B[1,1])-1)*100
		//	
		// 	drop u ahat bhat me ihs *_l *_u
		}
	}
	
	else if (`skew' == 2) { // Log transform
		foreach y of local myouts_n { 
	
		// Log transform 
		gen mylog = log(`y'+1)

		di " "
		di "OUTCOME: `y'"
		if strpos("`y'", "tc") { 
			local suf = substr("`y'", 6, .)
		}
		else if strpos("`y'", "oop") { 
			local suf = substr("`y'", 7, .)
		}
		glm mylog group `myvars' i.byear [fw=ho_`suf'], iter(50)
	
		// use treatment coefficient to get chnage as % of base (group == 0)
		matrix A = e(b)
		matrix B = e(V)
		qui sum `y' if group == 0
		
		di "Marginal effect is " (exp(A[1,1])-1) * `r(mean)'
		di "Lower Bound is " (exp(A[1,1] - sqrt(B[1,1])*invt(e(df), 0.025))-1) * `r(mean)'
		di "Upper Bound is " (exp(A[1,1] + sqrt(B[1,1])*invt(e(df), 0.025))-1) * `r(mean)'

		drop mylog
		}
	}
}
********************************************************************************


***** Build table
// cd "$output"
// esttab pre_mdcd pre_comm post_mdcd post_comm /// unweighted_diff weighted_mdcd weighted_comm weighted_diff
// 	 using Tab2_FRAG.csv, /// 
// 	cells("mean(pattern(1 1 1 1) fmt(4)) Var(pattern(1 1 1 1) fmt(4))") replace
********************************************************************************