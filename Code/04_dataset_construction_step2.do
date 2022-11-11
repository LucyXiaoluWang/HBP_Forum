* creating the datasets for the regression analyses
* the datasets used here are anonymized and the follwing steps were taken to create the dataset 
/*
- the raw data of the posts and replies was cleaned
- the user data was compiled
- each post was reviewed and its solving status determined
- each post was reviewed whether it was forwarded to JIRA
- the original dataset containing the posts and replies in wide format was converted 
 into long format in which each observation is one reply of a post
 - the user databank and the post data was merged and anonymized and saved as hbp_forum_uqu_2agg_step3.dta
*/


*----------------------------------------------------------------------------
*----------------------------------------------------------------------------
**# creating dataset containing aggregated variables (post-quarter-level)
/*
prepare post-quarter-level regression dataset
	- hbp-platform relevant
	- # countries
	- # users per quarter
	- # replies per quarter
	- # admins per quarter
	- # questions per quarter
	add-on
	- solved in the quarter?
subset of all posts but using only the first question
*/

* Starting with the preparing the categorical variable and the time variable
use hbp_forum_2agg_step3, clear

li id_post id_repl msg_yqu id_user if id_user==75 | id_user==217
replace id_user=217 if id_user==75

gen cat_all = 0
replace cat_all = 1 if cat_g_neuromorphic == 1
replace cat_all = 2 if cat_g_brain_sim_model ==1 
replace cat_all = 3 if cat_g_neurorobotics==1
replace cat_all = 4 if cat_g_tech_support==1
replace cat_all = 5 if cat_g_organization==1
replace cat_all = 6 if cat_g_others==1
label define cat_alllab 1 "Neuromorphic" 2 "Brain Sim/Model" 3 "Neurorobotics" 4 "Tech Support" 5 "Organization" 6 "Others"

label values cat_all cat_alllab
tab cat_all

* checking and correcting the date variable for the solving time
des date_sol_form
des time_solved
generate date_text = string(date_sol_form, "%td")
tostring time_solved, g(time_text2) format(%tcHH:MM:SS) force
gen double datetime_solved = clock(date_text + time_text2, "DMY hms")
format datetime_solved %tc
li date_text time_text2 datetime_solved in 20/40

* drop variables that are not needed anymore or copies of existing ones
drop name_real ny_post topic_id cat cat_multi cat_sum n_cat date_sol n_views code_exist topic /// 
	msg_text tm hm doubleU time_solved_old m qu msg_ymo cat_g_*

* Determine the number of questions that are being asked within a post and assign a question-id. 
* For this, we sort the data by post and then within post by the solving time. 	
bysort id_post (id_repl datetime_solved) : gen id_qu = sum(datetime_solved != datetime_solved[_n-1]) 
* generate a variable containing the solving time of the first question per post 
by id_post (id_repl datetime_solved), sort: gen double date_sol_1=datetime_solved[1]
*if the first post is unsolved, we use the second question within that post that has been solved
by id_post (id_repl datetime_solved), sort: replace date_sol_1=datetime_solved if id_qu==1
* format the solving date 
format date_sol_1 %tcDD/NN/CCYY_HH:MM:SS
gen day_sol_1=dofC(date_sol_1)
format day_sol_1 %td

* make sure that we do not have empty lines
drop if id_repl==.

* now drop the follow-up questions of each post (442 observations are dropped)
drop if id_qu > 1 

*-------------------------
* checking the data before aggregating to make sure that within each post we have homogenous info

* 1. verifying that there is no observation for which the datetime_solved variable (so the 
* solving time assigned to the individual reply) is not later than the solving time of the first 
* question)
gen x=1
bysort id_post : replace x=0 if datetime_solved > date_sol_1 

* 2. checking whether any entry has no datetime_solved at all
li id_post id_repl status_re id_qu datetime_solved if datetime_solved==.

* 3. checking whether any first reply has an datetime_solved that is larger than the date_sol_1
li id_post datetime_solved date_sol_1 id_repl if x==0 & id_repl==1
* 4. checking whether any first or second reply has an datetime_solved that is larger than the date_sol_1
li id_post datetime_solved date_sol_1 id_repl if x==0 & id_repl<=2
*not the case - therefore no need to drop if x==0 
gen check=1

* check that for each post we have the same status_detail
bysort id_post (id_repl): replace check=0 if status_detail!=status_detail[1] 
drop if check==0
*414 observations deleted
tab id_repl

*-------------------------------------------
* create separate indicator variables for each solving status, summarizing the different user 
* solved categories or admin solved categories
tab status_re

gen stat_admin_sol=.
replace stat_admin_sol=1 if status_re=="admin_solved" | ///
	status_re=="admin_solved; co_user_solved" | status_re=="admin_solved; user_solved"
	
gen stat_user_sol=.
replace stat_user_sol=1 if status_re=="user_solved" | ///
	status_re=="co_user_solved" | status_re=="co_user_solved; user_solved"

gen stat_info=.
replace stat_info=1 if status_re=="information"

gen stat_unclear=.
replace stat_unclear=1 if status_re=="unclear"

gen stat_unsolved=.
replace stat_unsolved=1 if status_re=="unsolved"


gen topic_status=0
replace topic_status = 1 if stat_admin_sol == 1
replace topic_status = 2 if stat_user_sol ==1 
replace topic_status = 3 if stat_info==1
replace topic_status = 4 if stat_unclear==1
replace topic_status = 5 if stat_unsolved==1

label define topic_statuslab 1 "admin solved" 2 "user solved" /// 
	3 "information" 4 "unclear" 5 "unsolved"

label values topic_status topic_statuslab
tab topic_status

*generate a general status indicator
rename status stat_old
drop stat_old

gen status=1
replace status=0 if topic_status==4 | topic_status==5
label variable status "0=open, 1=solved"

tab status
save hbp_forum_pqu_2agg_step1, replace 
*-------------------------------------------------------------------------------
**# Adding the user data to the forum data
* add the user data information (country, gender, hpb partner, seniority)
use hbp_forum_pqu_2agg_step1, clear
merge m:1 id_user using hbp_forum_user_databank_anonym, keepusing(country_ph0 country_ph1 country_ph2 gender i_hbppartner_0 i_hbppartner_1 i_hbppartner_2 ptr_code_sen0 ptr_code_sen1 ptr_code_sen2 seniority_ph0 seniority_ph1 seniority_ph2)
* drop those observations that only appear in the user databank 
drop if _merge==2
drop _merge
des

* currently we have for each user the overview of his/her seniority status for each phase 
* now we need an indicator to know which seniority level the user had when during the phase in which he replied/posted 
 
tab seniority_ph0
tab seniority_ph1
tab seniority_ph2
gen sen_0=0
gen sen_1=0
gen sen_2=0

forvalues i=0/2 {
	replace sen_`i'=1 if seniority_ph`i'=="undergraduate"
	replace sen_`i'=2 if seniority_ph`i'=="graduate"
	replace sen_`i'=3 if seniority_ph`i'=="junior"
	replace sen_`i'=4 if seniority_ph`i'=="senior"
	replace sen_`i'=5 if seniority_ph`i'=="senior_software"
	replace sen_`i'=6 if seniority_ph`i'=="non_academic"
	tab sen_`i'
}
gen i_sen=0
replace i_sen = sen_0 if i_pph0==1
replace i_sen = sen_1 if i_pph1==1
replace i_sen = sen_2 if i_pph2==1
replace i_sen = sen_2 if i_pph3==1


label define sen_label 0 "unknown" 1 "undergraduate" 2 "graduate" 3 "junior" 4 "senior" 5 "senior software" 6 "non_academic" 
label values i_sen sen_label
tab i_sen


* generate summarizing indicator whether user was hbp_partner when posting/replying 
gen i_hbppartner=0
replace i_hbppartner=i_hbppartner_0 if i_pph0==1
replace i_hbppartner=i_hbppartner_1 if i_pph1==1
replace i_hbppartner=i_hbppartner_2 if i_pph2==1
replace i_hbppartner=i_hbppartner_2 if i_pph3==1

label define hbplab 0 "No HBP partner" 1 "HBP partner" 2 "No information" 
label values i_hbppartner hbplab
tab i_hbppartner


* generate summarizing indicator for country of user affil when posting/replying 
gen country=""
des country 

replace country=country_ph0 if i_pph0==1
replace country=country_ph1 if i_pph1==1
replace country=country_ph2 if i_pph2==1
replace country=country_ph2 if i_pph3==1
tab country
assert missing(country) if i_sen==0
li id_user if missing(country) & i_sen!=0
tab country i_sen, missing

/*
*local vars1 "Algeria Austria Belgium Czech Denmark Finland France Germany Hungary Ireland Italy Netherlands Norway Spain Sweden Switzerland Kingdom"
*local vars2 "Canada China Cyprus Japan Egypt India Nigeria USA Taiwan" 
*one Q and no info
local vars1 "Austria Belgium Czech Denmark Finland France Germany Hungary Ireland Italy Netherlands Norway Spain Sweden Switzerland Kingdom unknown"
local vars2 "Algeria Canada China Japan Egypt India USA Taiwan Nigeria" 

local vars "`vars1' `vars2'"

foreach var of local vars {
	gen i_`var' = (strmatch(country,"*`var'*")==1)
	gen n_`var' = (strlen(country)-strlen(subinstr(country,"`var'","",.)))/strlen("`var'")
}

* count the unique countries per post
*/
cou if id_post==.
drop if id_post==.
save hbp_forum_post_quarter_2agg, replace

/*

use hbp_forum_user_databank_Oct21_fin_plusHBP_fin, clear

merge 1:m id_user using hbp_forum_post_quarter_2agg, keepusing(id_user)
keep if _merge==3
duplicates drop
save hbp_postReg_user_databank, replace
use hbp_forum_post_quarter_2agg, clear
keep id_post id_user i_code id_repl topic_status status i_hbpplatform re_opened jira_posted solv_jira user_tag seniority_ph0 seniority_ph1 seniority_ph2 sen_0 sen_1 sen_2 i_sen
duplicates drop
save hbp_postReg_codeStatusRelevance_table, replace
*/
*save hbp_forum_post_quarter_2agg_wo_multi, replace
*-----------------------
*------------------------------ 
use hbp_forum_post_quarter_2agg, clear
*use hbp_forum_post_quarter_2agg_wo_multi, clear

sort msg_yqu id_post
*create dummies for the solving categories



	
*total number of posts quarter within a status category 
bys msg_yqu: egen nyqu_status_admin = total(stat_admin_sol) if stat_admin_sol==1 
bys msg_yqu: egen nyqu_status_user = total(stat_user_sol) if stat_user_sol==1 
bys msg_yqu: egen nyqu_status_info = total(stat_info) if stat_info==1 
bys msg_yqu: egen nyqu_unclear = total(stat_unclear) if stat_unclear==1 
bys msg_yqu: egen nyqu_unsolved = total(stat_unsolved) if stat_unsolved==1 


*number of tags per post
**# Bookmark #1

gen n_tag = 0
replace n_tag=1 if !missing(tagged_user_id1)& missing(tagged_user_id2) & missing(tagged_user_id3)
replace n_tag=2 if !missing(tagged_user_id1)& !missing(tagged_user_id2) & missing(tagged_user_id3)
replace n_tag=3 if !missing(tagged_user_id1)& missing(tagged_user_id2) & !missing(tagged_user_id3)
tab tagged_user_id3
li id_post tagged_user_id1 tagged_user_id2 tagged_user_id3 n_tag if n_tag!=0
tab id_post if n_tag!=0
save data_postyqu_2reshape_status_1, replace

use data_postyqu_2reshape_status_1, clear
keep id_post id_repl gender i_hbppartner code_post i_sen
keep if id_repl==1
tab i_sen, sort
*dummy whether initial poster is hbp affilaited or which gender
bys id_post: gen poster_female=1 if gender==1
bys id_post: gen poster_hbp=1 if i_hbppartner==1
bys id_post: gen poster_code=1 if code_post==1
bys id_post: gen poster_junior=1 if i_sen==1 | i_sen==2 | i_sen==3
bys id_post: gen poster_senior=1 if i_sen==4 | i_sen==5 
label variable poster_female "Initial post posted by female"
label variable poster_hbp "Initial post by user affil. w/ HBP partner"
label variable poster_code "Initial post contains code"
label variable poster_junior "Initial post by junior"
label variable poster_senior "Initial post by senior"
*label define partner_label 0 "No HBP partner" 1 "HBP partner" 2 "No information" 

replace poster_female=0 if poster_female==.
replace poster_hbp=0 if poster_hbp==.
replace poster_code=0 if poster_code==.
replace poster_junior=0 if poster_junior==.
replace poster_senior=0 if poster_senior==.
keep id_post poster_female poster_hbp poster_code poster_junior poster_senior
save data_postyqu_2reshape_poster, replace

	 
*save data_postyqu_2reshape_oneQ_1, replace

