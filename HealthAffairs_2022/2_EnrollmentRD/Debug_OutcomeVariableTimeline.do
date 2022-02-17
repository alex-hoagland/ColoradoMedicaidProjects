global head "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD"
global sarah "$head\Sarah\Sarah Datasets"
global working "$head\Alex\Hoagland_WorkingData"
global output "$head\Alex\Hoagland_Output\1.CovariateSmoothness"
use "$working\APCD_MedicaidDelivery_Sample_WithIncome_20210304.dta", clear

keep if inrange(income_re,103,163)

// Outcomes for the 0-2 months window
gen outcome1_02 = !missing(in_mdcd02) // any enrollment in the year postpartum
* gen outcome2_02 = in_comm02 // note: all outcomes from here on have missing values for dropouts
gen outcome3_02 = tot_duration02 // duration of coverage (in days)
gen outcome4_02 = disrupt02 // probability of disruptions
gen outcome5_02 = gap02 // count of gaps 
// gen outcome6_02 = gap_length02 // length (in days) of all gaps

// change duration to months, not days
replace outcome3_02 = outcome3_02/30 
// replace outcome6_02 = outcome6_02/90*100 // change to fraction of year 

// Outcomes for the 3-12 months window
gen outcome1_312 = !missing(in_mdcd312) // any enrollment in the year postpartum
* gen outcome2_312 = in_comm312 // note: all outcomes from here on have missing values for dropouts
gen outcome3_312 = tot_duration312 // duration of coverage (in days)
gen outcome4_312 = disrupt312 // probability of disruptions
gen outcome5_312 = gap312 // count of gaps 
// gen outcome6_312 = gap_length312 // length (in days) of all gaps

// change duration to months, not days
replace outcome3_312 = outcome3_312/30 
// replace outcome6_312 = outcome6_312/275*100 // change to fraction of year 

sum outcome* 
sum outcome* if income_re < 133
sum outcome* if income_re >= 133