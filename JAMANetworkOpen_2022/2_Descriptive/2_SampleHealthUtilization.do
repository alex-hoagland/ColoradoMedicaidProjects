/*******************************************************************************
* Title: Identfy health outcomes
* Created by: Alex Hoagland
* Created on: 4/9/2021
* Last modified on: 6/7/2021
* Last modified by: Alex Hoagland

* Purpose: Identifies health outcomes for births/women in our sample.
		   
* Notes: 
		
* Key edits: 
   -  
*******************************************************************************/

***** 0. Directories & Packages 
global head "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD"
global apcd "$head\raw\20.59_BU_Continuity_of_Medicaid\Medical_Claims_Header"
global apcdline "$head\raw\20.59_BU_Continuity_of_Medicaid\Medical_Claims_Line"
global sarah "$head\Sarah\Sarah Datasets"
global working "$head\Alex\Hoagland_WorkingData\Paper2"
global output "$head\Alex\Hoagland_Output\4.HealthOutcomesPaper"

// ssc install icd9, replace // icd-9 diagnoses
// ssc install icd9p, replace // icd-9 procedures
// ssc install icd10cm, replace // US icd-10-CM (not ICD-10-WHO) diagnoses
// ssc install icd10pcs, replace  // US icd-10 (not WHO) procedures
********************************************************************************


***** 1. Load medical claims data for our sample
* First, transform sample into list of member_composite_id's and DOBs to keep
use "$working\RestrictedSample_20210622.dta", clear
keep member_c dob group
cap drop flag
rename group group_
bysort member_c (dob): gen j = _n
reshape wide dob group_, i(member_c) j(j)
save "$working\RestrictedSample_AllBirths.dta", replace

* Merge in all claims to filter
merge 1:m member_composite_id using ///
	"$apcd\Medical_Claims_Header.dta", ///	
	keep(3) nogenerate
	
* Drop claims associated with delivery
gen new_admit = date(admit_dt , "YMD")
gen new_discharge = date(discharge_dt , "YMD")
gen new_svcstart = date(service_start_dt , "YMD")
gen new_svcend= date(service_end_dt , "YMD")
// forvalues i = 1/4 { 
// 	drop if !missing(dob`i') & ///
// 	((!missing(new_dis) & inrange(dob`i',new_adm,new_dis)) | ///
// 	dob`i' == new_adm | ///
// 	(!missing(new_svcend) & inrange(dob`i',new_svcstart, new_svcend)))
// }

* Keep only claims from 61-365 days postpartum (rough way -- prior to reshaping later)
gen tokeep = 0 
forvalues i = 1/4 { 
	replace tokeep = 1 if inrange(new_svcstart,dob`i'+61,dob`i'+365) & !missing(dob`i')
}
keep if tokeep == 1

* Now reshape to associate claims with specific births
//drop service_qty units _merge line_no ndc_cd
duplicates drop
//egen id = group(member_composite_id claim_id billing* new_* cpt* revenue_cd service* place*), missing
egen id = group(member_composite_id claim_id billing* new_* service*), missing
reshape long dob group_, i(id) j(birth_no)
drop if missing(dob) 
keep if inrange(new_svcstart, dob+61, dob+365)
drop id

* Need to merge variables from line file (at visit level):
* place_of_service, cpt, revenue_cd 
merge 1:m member_c claim_id billing* service* using  ///
	"$head/raw/20.59_BU_Continuity_of_Medicaid\Medical_Claims_Line/Medical_Claims_Line.dta", ///
	keep(1 3) nogenerate keepusing(place_* cpt* revenue_cd)

compress
save "$working\HO_inprogress_20210622.dta", replace
********************************************************************************


***** 2. Outcomes: Health costs
use "$working\HO_inprogress_20210622.dta", clear
merge m:1 claim_id using "$working\tomerge_allpreventivedx.dta", nogenerate
	// merge in preventive dx's using 2a_ID_Preventive.do
replace any = 0 if missing(any)

merge m:1 claim_id using "$working\tomerge_allpcpdx.dta", nogenerate
replace anypcp = 0 if missing(anypcp)

gen oop = coinsurance + copay + deductible
replace oop = . if oop < 0
gen tc = oop + plan_paid 
replace tc = . if plan_paid < 0

* Correct to 2020 USD
cap gen service_year = year(new_svcstart)
foreach v of varlist oop tc { 
	replace `v' = `v' * 1.0903 if service_year == 2014
	replace `v' = `v' * 1.0890 if service_year == 2015
	replace `v' = `v' * 1.0754 if service_year == 2016
	replace `v' = `v' * 1.0530 if service_year == 2017
	replace `v' = `v' * 1.0261 if service_year == 2018
	replace `v' = `v' * 1.0123 if service_year == 2019
}

* Calculate total spending for each group
// bysort member_c dob time_group: egen tot_oop = total(oop)
// bysort member_c dob time_group: egen tot_spend = total(tc)
********************************************************************************


***** 3. Outcomes : Utilization measures
replace place_of_service_cd = "" if strpos(place_of_service_cd , "U")
destring place_of_service_cd, gen(pos)

cap drop ho* 

* Identifying IP hospitalizations (progressively imposing restrictions)
// gen crit1 = (claim_type_cd == 3) // Inpatient claim type
// bysort member_id member_composite_id claim_id: ereplace crit1 = max(crit1)
gen crit2 = (!missing(new_discharge) & !missing(new_admit) & new_discharge > new_admit) // need to be kept >= 24 hours
bysort member_id member_composite_id claim_id: ereplace crit2 = max(crit2)
gen crit3 = (inlist(pos,21,51,56,61) | ///
		substr(revenue_cd, 1, 2) == "01" | inlist(substr(revenue_cd,1,3),"020","021")) // appropriate POS or revenue codes
bysort member_id dob member_composite_id claim_id new_admit: ereplace crit3 = max(crit3)
gen ho_ip = (crit2 == 1 & crit3 == 1)
label var ho_ip "Health outcome: Any inpatient stay"

* Any ED use 
gen ho_ed = (er_flag == "Y" | place_of_s == "23")
replace ho_ed = 0 if revenue_cd != "0981" & substr(revenue_cd,1,3) != "045"
bysort member_composite_id dob member_id claim_id new_admit: ereplace ho_ed = max(ho_ed) 
label var ho_ed "Health outcome: Any ED Use"

* Identify all outpatient visits
// all non-IP and non-ED visits
gen ho_op = (ho_ed == 0 & ho_ip == 0)
destring place_of_service_cd, replace
replace ho_op = 0 if place_of_s > 73 & !missing(place_of_s) // Exclude labs and other POS's, keep unassigned
bysort member_composite_id dob member_id claim_id new_svcstart: ereplace ho_op = max(ho_op) 
label var ho_op "Health outcome: Any outpatient visit"

* Identify all preventive visits based on dx/cpt codes
gen ho_prev = 0 
destring cpt4_cd , gen(test) force
replace ho_prev = 1 if inrange(test, 99381, 99397) & !missing(test)
replace ho_prev = 1 if anyprev == 1| /// 
	inlist(principal, "Z0000", "Z0001", "Z01411", "Z01419", "Z391", "Z392") | ///
	inlist(principal,"V700", "V7231", "V241", "V242") | ///
	inlist(admit_diag, "Z0000", "Z0001", "Z01411", "Z01419", "Z391", "Z392") | ///
	inlist(admit_diag,"V700", "V7231", "V241", "V242")
drop test

replace ho_prev = 0 if ho_op != 1
bysort member_composite_id dob member_id claim_id new_svcstart: ereplace ho_prev = max(ho_prev)

// OLD PREVENTIVE CODES
// replace ho_prev = 1 if inlist(principal_diagnosis, "V6542", "V6549", "V791", "Z7189", "Z1389", "Z7141") & ///
// 	(inlist(cpt4_cd, "99401", "99402", "99403", "99404", "99408", "99409", "99411") | ///
// 	inlist(cpt4_c, "99412", "G0396", "G0397", "G0442"))
// replace ho_prev = 1 if (inlist(principal_diagnosis, "V220", "V221", "V222", "V230", "V231", "V232", "V233", "V2341", "V2342") | inlist(principal_diagnosis, "V2386", "V2387", "V2389", "V239", "V9100", "V9101", "V9102", "V9103") | inlist(principal_diagnosis, "V9109", "V9110", "V9111", "V9112", "V9119", "V9120", "V9121") | inlist(principal_diagnosis, "V9122", "V9129", "V9190", "V9191", "V9192", "V9199", "Z331", "Z3400") | inlist(principal_diagnosis, "Z3401", "Z3402", "Z3403", "Z3480", "Z3481", "Z3482", "Z3483", "Z3490", "Z3491") | inlist(principal_diagnosis, "Z3492", "Z3493", "Z36", "O0900", "O0901", "O0902", "O0903", "O0910") | inlist(principal_diagnosis, "O0911", "O0912", "O0913", "O09211", "O09212", "O09213", "O09219", "O09291") | inlist(principal_diagnosis, "O09292", "O09293", "O09299", "O0930", "O0931", "O0932", "O0933", "O0940") | inlist(principal_diagnosis, "O0941", "O0942", "O0943", "O09511", "O09512", "O09513", "O09519", "O09521") | inlist(principal_diagnosis, "O09522", "O09523", "O09529", "O09611", "O09612", "O09613", "O09619", "O09621") | inlist(principal_diagnosis, "O09622", "O09623", "O09629", "O0970", "O0971", "O0972", "O0973", "O09811") | inlist(principal_diagnosis, "O09812", "O09813", "O09819", "O09821", "O09822", "O09823", "O09829", "O09891", "O09892") | inlist(principal_diagnosis, "O09893", "O09899", "O0990", "O0991", "O0992", "O0993", "O3680X0", "O3680X1") | inlist(principal_diagnosis, "O3680X2", "O3680X3", "O3680X4", "O3680X5", "O3680X9", "O30001", "O30002", "O30003", "O30009") | inlist(principal_diagnosis, "O30011", "O30012", "O30013", "O30019", "O30021", "O30022", "O30023", "O30031", "O30032") | inlist(principal_diagnosis, "O30033", "O30039", "O30041", "O30042", "O30043", "O30049", "O30091", "O30092", "O30093") | inlist(principal_diagnosis, "O30099", "O30101", "O30102", "O30103", "O30109", "O30111", "O30112", "O30113") | inlist(principal_diagnosis, "O30119", "O30121", "O30122", "O30123", "O30129", "O30191", "O30192", "O30193") | inlist(principal_diagnosis, "O30199", "O30201", "O30202", "O30203", "O30209", "O30211", "O30212", "O30213", "O30219") | inlist(principal_diagnosis, "O30221", "O30222", "O30223", "O30229", "O30291", "O30292", "O30293", "O30299", "O30801") | inlist(principal_diagnosis, "O30802", "O30803", "O30809", "O30811", "O30812", "O30813", "O30819", "O30821", "O30822") | inlist(principal_diagnosis, "O30823", "O30829", "O30891", "O30892", "O30893", "O30899", "O3090") | inlist(principal_diagnosis, "O3091", "O3092", "O3093")) & (inlist(cpt4_cd, "36415", "36416", "85013", "85014", "85018") | inlist(cpt4_cd,"85041","36415", "36416", "87340", "87341","36415", "36416", "86900") | inlist(cpt4_cd, "86901", "82947", "82948", "82950", "82951", "82952", "83036","81007"))
// replace ho_prev = 1 if (inlist(principal_diagnosis,"V103", "V1043", "V163", "V1641") | inlist(principal_diagnosis, "Z803", "Z8041", "Z1501", "Z1502", "Z853", "Z8543")) & (inlist(cpt4_cd, "99201", "99202", "99203", "99204", "99205", "99211", "99212", "99213") | inlist(cpt4_cd, "99214", "99215", "99385", "99386", "99387", "99395", "99396") | inlist(cpt4_cd, "99397", "96040", "S0265"))
// replace ho_prev = 1 if inlist(cpt4_cd, "77057", "77052", "G0202", "77067", "77065", "77066", "76083", "76092")
// replace ho_prev = 1 if inlist(principal_diagnosis,"V241", "Z391") & (inlist(cpt4_cd, "99201", "99202", "9203", "99211", "99212", "99213", "99214", "99241", "99242") | inlist(cpt4_cd, "99243", "99244", "99245", "99341", "99342", "99343", "99344", "99345") | inlist(cpt4_cd, "99347", "99348", "99349", "99350", "99401", "99402", "99403", "99404") | inlist(cpt4_cd, "99411", "99412", "A4281", "A4282", "A4283", "A4284", "A4285", "A4286") | inlist(cpt4_cd, "E0602", "E0603", "E0604", "S9443"))
// replace ho_prev = 1 if inlist(principal_diagnosis, "V700", "V7231", "V7232", "V762", "Z0000", "Z0001", "Z01419", "Z124") & (inlist(cpt4_cd, "88141", "88142", "88143", "88147", "88148", "88150", "88152", "88153", "88154") | inlist(cpt4_cd, "88155", "88164", "88165", "88166", "88167", "88174", "88175", "G0101", "G0123") | inlist(cpt4_cd, "G0124", "G0141", "G0143", "G0144") | inlist(cpt4_cd, "G0145", "G0147", "G0148", "P3000", "P3001", "Q0091"))
// replace ho_prev = 1 if (inlist(principal_diagnosis,"V700", "V7791", "Z0000", "Z0001", "Z13220", "24900", "24901", "24910", "24911") | inlist(principal_diagnosis, "24920", "24921", "24930", "24931", "24940", "24941","24950", "24951", "24960") | inlist(principal_diagnosis, "24961", "24970", "24971", "24980", "24981", "24990", "24991", "25000") | inlist(principal_diagnosis, "25001", "25002", "25003", "25010", "25011", "25012", "25013", "25020") | inlist(principal_diagnosis, "25021", "25022", "25023", "25030", "25031", "25032", "25033", "25040") | inlist(principal_diagnosis, "25041", "25042", "25043", "25050", "25051", "25052", "25053", "25060") | inlist(principal_diagnosis, "25061", "25062", "25063", "25070", "25071", "25072", "25073", "25080") | inlist(principal_diagnosis, "25081", "25082", "25083", "25090", "25091", "25092", "25093", "E0800") | inlist(principal_diagnosis, "E0801", "E0810", "E0811", "E0821", "E0822", "E0829", "E08311", "E08319") | inlist(principal_diagnosis, "E08321", "E08329", "E08331", "E08339", "E08341", "E08349", "E08351", "E08359") | inlist(principal_diagnosis, "E0836", "E0839", "E0840", "E0841", "E0842", "E0843", "E0844", "E0849", "E0851") | inlist(principal_diagnosis, "E0852", "E0859", "E08610", "E08618", "E08620", "E08621", "E08622", "E08628", "E08630") | inlist(principal_diagnosis, "E08638", "E08641", "E08649", "E0865", "E0869", "E088", "E089", "E0900") | inlist(principal_diagnosis, "E0901", "E0910", "E0911", "E0921", "E0922", "E0929", "E09311", "E09319", "E09321") | inlist(principal_diagnosis, "E09329", "E09331", "E09339", "E09341", "E09349", "E09351", "E09359", "E0936", "E0939") | inlist(principal_diagnosis, "E0940", "E0941", "E0942", "E0943", "E0944", "E0949", "E0951", "E0952", "E0959") | inlist(principal_diagnosis, "E09610", "E09618", "E09620", "E09621", "E09622", "E09628", "E09630", "E09638") | inlist(principal_diagnosis, "E09641", "E09649", "E0965", "E0969", "E098", "E099", "E1010", "E1011") | inlist(principal_diagnosis,"E1021", "E1022", "E1029", "E10311", "E10319", "E10321", "E10329", "E10331") | inlist(principal_diagnosis, "E10339", "E10341", "E10349", "E10351", "E10359", "E1036", "E1039", "E1040") | inlist(principal_diagnosis, "E1041", "E1042", "E1043", "E1044", "E1049", "E1051", "E1052", "E1059") | inlist(principal_diagnosis, "E10610", "E10618", "E10620", "E10621", "E10628", "E10630", "E10638", "E10641") | inlist(principal_diagnosis, "E10649", "E1065", "E1069", "E108", "E109", "E1100", "E1101", "E1121") | inlist(principal_diagnosis, "E1122", "E1129", "E11311", "E11319", "E11321", "E11329", "E11331", "E11339") | inlist(principal_diagnosis, "E11341", "E11349", "E11351", "E11359", "E1136", "E1139", "E1140", "E1141") | inlist(principal_diagnosis, "E1142", "E1143", "E1144", "E1149", "E1151", "E1152", "E1159", "E11610") | inlist(principal_diagnosis, "E11618", "E11620", "E11621", "E11622", "E11628", "E11630", "E11638", "E11641") | inlist(principal_diagnosis, "E11649", "E1165", "E1169", "E118", "E119", "E1300", "E1301", "E1310") | inlist(principal_diagnosis, "E1311", "E1321", "E1322", "E1329", "E13311", "E13319", "E13321", "E13329") | inlist(principal_diagnosis, "E13331", "E13339", "E13341", "E13349", "E13351", "E13359", "E1336", "E1339") | inlist(principal_diagnosis, "E1340", "E1341", "E1342", "E1343", "E1344", "E1349", "E1351") | inlist(principal_diagnosis, "E1352", "E1359", "E13610", "E13618", "E13620", "E13621", "E13622", "E13628") | inlist(principal_diagnosis, "E13630", "E13638", "E13641", "E13649", "E1365", "E1369", "E138", "E139") | inlist(principal_diagnosis, "4010", "4011", "4019", "I10", "40200", "40201", "40210") | inlist(principal_diagnosis, "40211", "40290", "40291", "I110", "I119", "40300", "40301", "40310", "40311") | inlist(principal_diagnosis, "40390", "49391", "I120", "I129","40400", "40401", "40402", "40403") | inlist(principal_diagnosis, "40410", "40411", "40412", "40413", "40490", "40491", "40492", "40493") | inlist(principal_diagnosis, "I130", "I1310", "I1311", "I132", "40501", "40509", "40511", "40519") | inlist(principal_diagnosis, "40591", "40599", "I150", "I151", "I152", "I158", "I159", "N262") | inlist(principal_diagnosis, "64201", "64203", "64204", "64211", "64213", "64214", "64221", "64223") | inlist(principal_diagnosis, "64224", "64230", "64231", "64233", "64234", "64291", "64293", "94294", "O10011") | inlist(principal_diagnosis, "O10012", "O10013", "O10019", "O1002", "O1003", "O10111","O10112", "O10113", "O10119") | inlist(principal_diagnosis, "O1012", "O1013", "O10211", "O10212", "O10213", "O10219", "O1022", "O1023", "O10311") | inlist(principal_diagnosis, "O10312", "O10313", "O10319", "O1032", "O1033", "O10411", "O10412", "O10413", "O10419") | inlist(principal_diagnosis, "O1042", "O1043", "O10911", "O10912", "O10913", "O10919", "O1092", "O1093", "O111") | inlist(principal_diagnosis, "O112", "O113", "O119", "O131", "O132", "O139", "O161", "O162") | inlist(principal_diagnosis, "O163", "O169")) & inlist(cpt4_cd, "36415", "36416", "80061", "82465", "83718", "83719", "83721", "84478")
// replace ho_prev = 1 if inlist(principal_diagnosis,"V790", "Z1389") & inlist(cpt4_cd, "96127", "96160", "96161", "99420", "G0444")
// replace ho_prev = 1 if (inlist(principal_diagnosis,"V8530", "V8531", "V8532", "V8533", "V8534", "V8535", "V8536", "V8537", "V8538") | inlist(principal_diagnosis, "V8539", "V8541", "V8542", "V8543", "V8544", "V8545", "27800", "27801") | inlist(principal_diagnosis, "Z6830", "Z6831", "Z6832", "Z6833", "Z6834", "Z6835", "Z6836", "Z6837") | inlist(principal_diagnosis, "Z6838", "Z6839", "Z6841", "Z6842", "Z6843", "Z6844", "Z6845", "E6601") | inlist(principal_diagnosis, "E6609", "E661", "E668", "E66", "4010", "4011", "4019", "I10", "40200") | inlist(principal_diagnosis, "40201", "40210", "40211", "40290", "40291", "I110", "I119", "40300", "40301") | inlist(principal_diagnosis, "40310", "40311", "40390", "49391", "I120", "I129", "40400", "40401") | inlist(principal_diagnosis, "40402", "40403", "40410", "40411", "40412", "40413", "40490", "40491") | inlist(principal_diagnosis, "40492", "40493", "I130", "I1310", "I1311", "I132", "40501", "40509") | inlist(principal_diagnosis, "40511", "40519", "40591", "40599", "I150", "I151", "I152", "I158") | inlist(principal_diagnosis, "I159", "N262", "64201", "64203", "64204", "64211", "64213", "64214", "64221") | inlist(principal_diagnosis, "64223", "64224", "64230", "64231", "64233", "64234", "64291", "64293", "94294") | inlist(principal_diagnosis, "O10011", "O10012", "O10013", "O10019", "O1002", "O1003", "O10111", "O10112") | inlist(principal_diagnosis, "O10113", "O10119", "O1012", "O1013", "O10211", "O10212", "O10213", "O10219") | inlist(principal_diagnosis, "O1022", "O1023", "O10311", "O10312", "O10313", "O10319", "O1032", "O1033") | inlist(principal_diagnosis, "O10411", "O10412", "O10413", "O10419", "O1042", "O1043", "O10911", "O10912", "O10913") | inlist(principal_diagnosis, "O10919", "O1092", "O1093", "O111", "O112", "O113", "O119", "O131", "O132") | inlist(principal_diagnosis, "O139", "O161", "O162", "O163", "O169", "24900", "24901", "24910") | inlist(principal_diagnosis, "24911", "24920", "24921", "24930", "24931", "24940", "24941", "24950") | inlist(principal_diagnosis, "24951", "24960", "24961", "24970", "24971", "24980", "24981", "24990") | inlist(principal_diagnosis, "24991", "25000", "25001", "25002", "25003", "25010", "25011", "25012") | inlist(principal_diagnosis, "25013", "25020", "25021", "25022", "25023", "25030", "25031", "25032") | inlist(principal_diagnosis, "25033", "25040", "25041", "25042", "25043", "25050", "25051", "25052") | inlist(principal_diagnosis, "25053", "25060", "25061", "25062", "25063", "25070", "25071") | inlist(principal_diagnosis,"25072", "25073", "25080", "25081", "25082", "25083", "25090", "25091", "25092") | inlist(principal_diagnosis, "25093", "E0800", "E0801", "E0810", "E0811", "E0821", "E0822", "E0829") | inlist(principal_diagnosis, "E08311", "E08319", "E08321", "E08329", "E08331", "E08339", "E08341") | inlist(principal_diagnosis, "E08349", "E08351", "E08359", "E0836", "E0839", "E0840", "E0841") | inlist(principal_diagnosis, "E0842", "E0843", "E0844", "E0849", "E0851", "E0852", "E0859", "E08610", "E08618") | inlist(principal_diagnosis, "E08620", "E08621", "E08622", "E08628", "E08630", "E08638", "E08641", "E08649") | inlist(principal_diagnosis, "E0865", "E0869", "E088", "E089", "E0900", "E0901", "E0910", "E0911") | inlist(principal_diagnosis, "E0921", "E0922", "E0929", "E09311", "E09319", "E09321", "E09329", "E09331", "E09339") | inlist(principal_diagnosis, "E09341", "E09349", "E09351", "E09359", "E0936", "E0939", "E0940", "E0941", "E0942") | inlist(principal_diagnosis, "E0943", "E0944", "E0949", "E0951", "E0952", "E0959", "E09610", "E09618", "E09620") | inlist(principal_diagnosis, "E09621", "E09622", "E09628", "E09630", "E09638", "E09641", "E09649", "E0965", "E0969") | inlist(principal_diagnosis, "E098", "E099", "E1010", "E1011","E1021", "E1022", "E1029", "E10311") | inlist(principal_diagnosis, "E10319", "E10321", "E10329", "E10331", "E10339", "E10341", "E10349") | inlist(principal_diagnosis, "E10351", "E10359", "E1036", "E1039", "E1040", "E1041", "E1042", "E1043") | inlist(principal_diagnosis, "E1044", "E1049", "E1051", "E1052", "E1059", "E10610", "E10618", "E10620") | inlist(principal_diagnosis, "E10621", "E10628", "E10630", "E10638", "E10641", "E10649", "E1065") | inlist(principal_diagnosis, "E1069", "E108", "E109", "E1100", "E1101", "E1121", "E1122", "E1129") | inlist(principal_diagnosis, "E11311", "E11319", "E11321", "E11329", "E11331", "E11339", "E11341", "E11349") | inlist(principal_diagnosis, "E11351", "E11359", "E1136", "E1139", "E1140", "E1141", "E1142", "E1143") | inlist(principal_diagnosis, "E1144", "E1149", "E1151", "E1152", "E1159", "E11610", "E11618", "E11620") | inlist(principal_diagnosis, "E11621", "E11622", "E11628", "E11630", "E11638", "E11641", "E11649", "E1165") | inlist(principal_diagnosis, "E1169", "E118", "E119", "E1300", "E1301", "E1310", "E1311", "E1321") | inlist(principal_diagnosis, "E1322", "E1329", "E13311", "E13319", "E13321", "E13329", "E13331", "E13339", "E13341") | inlist(principal_diagnosis, "E13349", "E13351", "E13359", "E1336", "E1339", "E1340", "E1341","E1342", "E1343") | inlist(principal_diagnosis, "E1344", "E1349", "E1351", "E1352", "E1359", "E13610", "E13618", "E13620", "E13621") | inlist(principal_diagnosis, "E13622", "E13628", "E13630", "E13638", "E13641", "E13649", "E1365", "E1369", "E138") | inlist(principal_diagnosis, "E139")) & (inlist(cpt4_cd, "97802", "97803", "97804", "99401", "99402", "99403", "99404", "G0446", "G0447") | inlist(cpt4_cd, "99411", "99412", "G0270", "G0271", "G0449", "S9470"))
// replace ho_prev = 1 if inlist(cpt4_cd, "99401", "99402", "99403", "99404", "99406", "99407", "C9801", "C9802") | inlist(cpt4_cd, "G0436", "G0437", "S9075", "S9453")
// replace ho_prev = 1 if (inlist(principal_diagnosis, "V030", "V031", "V032", "V033", "V034", "V035", "V036", "V037", "V038") | inlist(principal_diagnosis, "V0381", "V0382", "V0389", "V039", "V040", "V041", "V042", "V043", "V044") | inlist(principal_diagnosis, "V045", "V046", "V047", "V048", "V0481", "V0482", "V0489", "V049", "V050") | inlist(principal_diagnosis, "V051", "V052", "V053", "V054", "V058", "V059", "V060", "V061", "V062") | inlist(principal_diagnosis, "V063", "V064", "V065", "V066", "V068", "V069", "V200", "V201", "V202") | inlist(principal_diagnosis, "V203", "V2031", "V2032", "V700", "V242", "V723", "V7231", "V762", "V7646") | inlist(principal_diagnosis, "V7647", "V8402", "V8404", "Z761", "Z762", "Z00121", "Z00129", "Z00110") | inlist(principal_diagnosis, "Z00111", "Z7681", "Z0000", "Z0001", "Z008", "Z01411", "Z01419", "Z134", "Z136") | inlist(principal_diagnosis, "Z0130", "Z0133", "Z003", "V653", "V6542", "V6544", "V6545", "Z713", "Z717") | inlist(principal_diagnosis, "Z7141", "Z713", "Z7141", "Z1389", "Z1331", "Z1332", "Z23", "Z392", "Z124") | inlist(principal_diagnosis, "Z1273", "Z1272", "Z1502", "Z1504")) & (inlist(cpt4_cd, "99201", "99202", "99203", "99204", "99205", "99211", "99212", "99213", "99214") | inlist(cpt4_cd, "99215", "99385", "99386", "99387", " 99395", "99396", "99397", "99401", "99402") | inlist(cpt4_cd, "99403", "99404", "99411", "99412", "G0101", "G0344", "G0402", "G0438", "G0439") | inlist(cpt4_cd, "G0445", "S0610", "S0612", "S0613"))
//

* Identify general primary care visits
gen ho_pcp = anypcp 
replace ho_pcp = 1 if inlist(substr(principal_diagnosis, 1, 3), "Z00", "Z01", "Z39", "V70", "V72", "V24")
replace ho_pcp = 1 if ho_prev == 1
replace ho_pcp = 0 if ho_op != 1
bysort member_composite_id dob member_id claim_id new_svcstart: ereplace ho_pcp = max(ho_pcp) 
label var ho_pcp "Health outcome: General Primary Care Visit"

* Any postpartum severe maternal morbidity (see attached list of codes)
// gen psmm = 0 
//
// // DIAGNOSIS CODES
// foreach v of var admit_diagnosis principal_diagnosis { 
// 	* Three-string codes
// 	replace psmm = 1 if inlist(substr(`v',1,3),"410","I21","I22", /// AMI
// 											   "411","I71","I79") | /// Aneurysm
// 						inlist(substr(`v',1,3),"N17", /// Acute renal failure
// 												"J80", /// Adult respiratory distress
// 												"I46", /// Cardiac arrest
// 												"D65", /// Disseminated intravascular...
// 												"O15") | /// Eclampsia
// 						inlist(substr(`v',1,3),"430","431","432","433","434","436","437") | /// cerebrovascular disorders
// 						inlist(substr(`v',1,3),"I60","I61","I62","I63","I64","I65","I66","I67","I68") | /// cerebrovascular disorders
// 						inlist(substr(`v',1,3),"038", "O85","A40","A41", /// sepsis
// 												"R57", /// shock
// 												"I26") // embolism
//												
// 	* Four-string codes
// 	replace psmm = 1 if inlist(substr(`v',1,4),"5845","5486","5847","5848","5849","6693","O904") | /// Acute renal failure
// 						inlist(substr(`v',1,4),"5185","7991","J951","J952","J953","J960","J962","R092") | /// Adult respiratory distress
// 						inlist(substr(`v',1,4),"6731","O881", /// Amniotic fluid embolism
// 												"4275","I490") | /// Cardiac arrest
// 						inlist(substr(`v',1,4),"2866","2869","6663","D688","D689","O723") | /// Disseminated intravascular...
// 						inlist(substr(`v',1,4),"6426", /// Eclampsia
// 												"9971", /// heart failure
// 												"6715","6740","O873") | /// cerebrovascular disorders
// 						inlist(substr(`v',1,4),"5184","4281","4280","J810","I501","I509") | /// AHF
// 						inlist(substr(`v',1,4),"6680","6681","6682") | /// Anesthesia complications 
// 						inlist(substr(`v',1,4),"O740","O741","O742","O743","O890","O891","O892") | /// Anesthesia complications
// 						inlist(substr(`v',1,4),"6702","A327", /// sepsis
// 												"6691","7855","9950","9954","9980","O751") | /// shock
// 						inlist(substr(`v',1,4),"D570") | /// sickle cell
// 						inlist(substr(`v',1,4),"4151","6730","6732","6733","6738","O880","O882","O883","O888") // embolism
//												
// 	* 5-string codes
// 	replace psmm = 1 if inlist(substr(`v',1,5),"51881","51882","51884","J9582") | /// Adult respiratory distress
// 						inlist(substr(`v',1,5),"42741","42742","I490", /// Cardiac arrest
// 												"I9712","I9713") | /// heart failure 
// 						inlist(substr(`v',1,5),"99702","O2251","O2252","O2253","I9781","I9782") | /// cerebrovascular disorders
// 						inlist(substr(`v',1,5),"42821","42823","42831","42833","42841","42843") | /// AHF
// 						inlist(substr(`v',1,5),"I5020","I5021","I5023","I5030","I5031","I5033","I5040","I5041","I5043") | /// AHF
// 						inlist(substr(`v',1,5),"99591","99592","O8604","R6520", /// sepsis
// 												"R6521") | /// shock
// 						inlist(substr(`v',1,5),"28242","28262","28264","28269","D5721","D5741","D5781") // sickle cell
//						
// 	* All others
// 	replace psmm = 1 if inlist(`v', "I97710", "I97711", "T80211A", "T814XXA", "T8144XX","T782XXA") | ///
// 						inlist(`v',"T882XXA", "T886XXA", "T8110XA" , "T8111XA", "T8119XA")
// }
//
// // PROCEDURE CODES
// replace psmm = 1 if inlist(substr(icd_primary_p,1,3),"996","990","683","684","685","686") | ///
// 					inlist(substr(icd_primary_p,1,3),"687","688","689","311")
// replace psmm = 1 if inlist(icd_primary_p,"9390","9601","9602","9603","9605")
// replace psmm = 1 if inlist(icd_primary_p,"5A2204Z","5A12012","30233H1","30233L1", "30233K1", "30233M1") | ///
// 	inlist(icd_primary_p,"30233N1","30233P1","30233R1","30233T1","30233H0","30233L0", "30233K0", "30233M0") | ///
// 	inlist(icd_primary_p,"30233N0","30233P0","30233R0","30233T0","30230H1","30230L1", "30230K1", "30230M1") | ///
// 	inlist(icd_primary_p,"30230N1","30230P1","30230R1","30230T1","30230H0","30230L0", "30230K0", "30230M0") | ///
// 	inlist(icd_primary_p,"30230N0","30230P0","30230R0","30230T0","30240H1","30240L1", "30240K1", "30240M1") | ///
// 	inlist(icd_primary_p,"30240N1","30240P1","30240R1","30240T1","30240H0","30240L0", "30240K0", "30240M0") | ///
// 	inlist(icd_primary_p,"30240N0","30240P0","30240R0","30240T0","30243H1","30243L1", "30243K1", "30243M1") |  ///
// 	inlist(icd_primary_p,"30243N1","30243P1","30243R1","30243T1","30243H0","30243L0", "30243K0", "30243M0") | ///
// 	inlist(icd_primary_p,"30243N0","30243P0","30243R0","30243T0","30250H1","30250L1", "30250K1", "30250M1") | ///
// 	inlist(icd_primary_p,"30250N1","30250P1","30250R1","30250T1","30250H0","30250L0", "30250K0", "30250M0") | ///
// 	inlist(icd_primary_p,"30250N0","30250P0","30250R0","30250T0","30253H1","30253L1", "30253K1", "30253M1") | ///
// 	inlist(icd_primary_p,"30253N1","30253P1","30253R1","30253T1","30253H0","30253L0", "30253K0", "30253M0") | ///
// 	inlist(icd_primary_p,"30253N0","30253P0","30253R0","30253T0","30260H1","30260L1", "30260K1", "30260M1") | ///
// 	inlist(icd_primary_p,"30260N1","30260P1","30260R1","30260T1","30260H0","30260L0", "30260K0", "30260M0") | ///
// 	inlist(icd_primary_p,"30260N0","30260P0","30260R0","30260T0","30263H1","30263L1", "30263K1", "30263M1") | ///
// 	inlist(icd_primary_p,"30263N1","30263P1","30263R1","30263T1","30263H0","30263L0", "30263K0", "30263M0") | ///
// 	inlist(icd_primary_p,"30263N0","30263P0","30263R0","30263T0","0UT90ZZ", "0UT94ZZ", "0UT97ZZ", "0UT98ZZ") | ///
// 	inlist(icd_primary_p,"0UT9FZZ","0B110Z", "0B110F", "0B113", "0B114","5A1935Z", "5A1945Z","5A1955Z")
//	
// // Require PSMM codes to be inpatient/ED POS
// gen ho_psmm = (psmm == 1 & (ho_ip == 1 | ho_ed == 1))
// bysort member_c dob member_id claim_id new_svcstart: ereplace ho_psmm = max(ho_psmm)
// label var ho_psmm "Health Outcome: PSMM"
********************************************************************************


***** 4. Collapse and merge with initial data 
gen p_tc_prev = tc if ho_prev == 1
gen p_tc_pcp = tc if ho_pcp == 1
gen p_tc_op = tc if ho_op == 1
gen p_tc_ed = tc if ho_ed == 1
gen p_tc_ip = tc if ho_ip == 1
gen p_oop_prev = oop if ho_prev == 1
gen p_oop_pcp = oop if ho_pcp == 1
gen p_oop_op = oop if ho_op == 1
gen p_oop_ed = oop if ho_ed == 1
gen p_oop_ip = oop if ho_ip == 1

// take means at service level 
// foreach v of var p_* { 
// 	egen meanpriceM_`v' = mean(`v') if group == 0
// 	egen meanpriceC_`v' = mean(`v') if group == 1
// 	egen medpriceM_`v' = median(`v') if group == 0
// 	egen medpriceC_`v' = median(`v') if group == 1
// }

// collapse to visit level for all utilization counts/spending
// first, eliminate repeated payment measures (multiple lines per claim id)
drop cpt4_* 
duplicates drop

// collapse to claim level 
collapse (max) ho* (sum) tc oop p_* , /// (first) meanprice* medprice*, ///
	by(member_composite claim_id dob new_svcstart group) fast
	
replace ho_ed = 0 if ho_ip == 1 & ho_ed == 1 // no double counting
	
// assume all claims of a given type on a given day are a single visit
collapse (sum) tc oop p_* , /// (first) meanprice* medprice*, ///
	by(member_composite ho_* dob new_svcstart group) fast
	
replace p_tc_prev = . if ho_prev != 1
replace p_tc_pcp = . if ho_pcp != 1
replace p_tc_op = . if ho_op != 1
replace p_tc_ed = . if ho_ed != 1
replace p_tc_ip = . if ho_ip != 1
replace p_oop_prev = . if ho_prev != 1
replace p_oop_pcp = . if ho_pcp != 1
replace p_oop_op = . if ho_op != 1
replace p_oop_ed = . if ho_ed != 1
replace p_oop_ip = . if ho_ip != 1

// collapse to person level 
collapse (sum) ho_* tc oop (mean) p_*, /// (first) meanprice* medprice*
	by(member_composite dob group) fast

// merge in with data
merge 1:1 member_c dob using "$working\RestrictedSample_20210929.dta", keep(2 3) nogenerate
foreach v of var ho* tc oop { 
	replace `v' = 0 if missing(`v')
}

compress
save "$working\RestrictedSample_20210929", replace

cls
forvalues g = 0/1 { 
	sum ho_op ho_prev ho_ed ho_ip ho_psmm tc meanprice*tc* medprice*tc* ///
		oop meanprice*oop* medprice*oop* if group == `g', d
}
********************************************************************************