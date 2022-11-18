* creating the dataset for the survival analyses
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
**# creating dataset containing aggregated variables for the survival analysis
/*
prepare survival analysis dataset by aggregating the information to the post-level (not the post-quarter level!)
	- generate indicator for the questions asked within the post
	- determine the solving time of the first question asked and solved 
	- subset the data by keeping only the first question and its solution
	- adding the anonymized user data 
	- generate indicators for the seniority level, solving status and hbp-partnership-status during the phases in which the post/reply was sent
Using the datasets created before:
	- databank hbp_forum_user_databank_anonym.dta
	- poster information created in the data_construction_post_quarter.do: hbp_forum_pq_2reshape_poster.dta
Then we reshape the dataset to wide with the post-id as identifiying variable
*/




*xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
* starting with the aggregation process 

use hbp_forum_data2agg, clear

* Adding user data by merging with the user databank
merge m:1 id_user using hbp_forum_user_databank_anonym, keepusing(gender i_admin country_ph0 country_ph1 country_ph2 gender i_hbppartner_0 i_hbppartner_1 i_hbppartner_2 seniority_ph0 seniority_ph1 seniority_ph2)
drop if _merge==2
*keep if _merge==3
drop _merge
des

* generate an categorical variable whether the user was senior/junior etc. when posting/replying to a thread
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


* generate summarizing indicator whether user was in the project phase during whe he/she replied affiliated with an HBP partner. 
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
li id_user if missing(country) & i_sen!=0
tab country i_sen, missing


sort id_post id_msg

* -----------------------------------------------------
* checking and correcting the format of the date variable for the solving time of the question
generate date_text = string(date_solved, "%td")
tostring time_solved, g(time_text2) format(%tcHH:MM:SS) force
li time_solved time_text2 date_solved date_solved in 1/20
gen double datetime_solved = clock(date_text + time_text2, "DMY hms")
format datetime_solved %tc
li date_text time_solved datetime_solved in 20/40
li time_solved in 1/10
li date_solved in 1/30

* Determine the number of questions that are being asked within a post and assign a question-id. 
* For this, we sort the data by post and then within post by the solving time. 	
bysort id_post (id_msg datetime_solved) : gen id_qu = sum(datetime_solved != datetime_solved[_n-1]) 

* generate a variable containing the solving time of the first question per post 
by id_post (id_msg datetime_solved), sort: gen double date_sol_1=datetime_solved[1]

*if the first post is unsolved, we use the second question within that post that has been solved
by id_post (id_msg datetime_solved), sort: replace date_sol_1=datetime_solved if id_qu==1

* format the time variable 
format date_sol_1 %tcDD/NN/CCYY_HH:MM:SS
gen day_sol_1=dofC(date_sol_1)
format day_sol_1 %td
label variable day_sol_1 "Solving date of the first question within the thread (MM/DD/YYYY)"

* make sure that we do not have empty lines
drop if id_msg==.

* now drop the follow-up questions of each post (442 observations are dropped)
drop if id_qu > 1 

***-------------------------
*** Conducting plausibility checks with respect to solving time and solving status before aggregating.
* Thereby, we want to ensure that within each post we have homogenous info.

* 1. verifying that there is no observation where the datetime_solved variable (i.e., the 
* solving time assigned to the individual message) is not later than the solving time of the first 
* question (this is most relevant for multi-question posts, where we mainly focus on the initial Q)
gen x=1
bysort id_post : replace x=0 if datetime_solved > date_sol_1 

* 2. Additionally, checking whether any entry has no datetime_solved at all - not the case
li id_post id_msg status_sol id_qu datetime_solved if datetime_solved==.

* 3. Additionally, checking whether any of the initial messages has an datetime_solved that is larger than the date_sol_1
li id_post datetime_solved date_sol_1 id_msg if x==0 & id_msg==1

* 4. checking whether any first or second reply has an datetime_solved that is larger than the date_sol_1
li id_post datetime_solved date_sol_1 id_msg if x==0 & id_msg<=2
*not the case - therefore no need to drop if x=

* 5. Lastly, we verify that for each thread has the same value for the status_detail and thus belongs to the same question
gen check=1
* for this we sort the data by post and message and create an indicator if the status is different
bysort id_post (id_msg): replace check=0 if status_detail!=status_detail[1] 
li id_post id_msg status_sol date_sol_1 if check==0
drop if check==0
*indeed there where some remaining follow-up questions left (414 observations deleted) and which were caught now by the status
* verifying that we still have all initial questions in the dataset
tab id_msg


* check for issues in earliest time and correct for it 
* 3 posts have the wrong year for the earliest date 
li id_post msg_time id_msg datetime_solved date_sol_1 date_earl date_solved if id_post==14 | id_post==35 | id_post==211

* clean date-time raw format (tm=time)
	gen tim = subinstr(msg_time," AM","AM",.) 
	replace tim = subinstr(tim," PM","PM",.) 
	
	* separate out and save date info 
	gen day = substr(tim,1,strlen(tim)-strlen("12:00AM"))
	replace day = strtrim(day)

gen d_check=date(day,"MDY")
	format d_check %td 
	* hour-minutes


li id_post msg_time day d_check id_msg datetime_solved date_sol_1 date_earl date_earl_cor date_solved if id_post==14 | id_post==35 | id_post==211, sepby(id_post)
* correct the 3 posts
replace date_earl=

by id_post (id_msg), sort: gen double date_earl_cor=d_check[1]
format date_earl_cor %td
li id_post msg_time day d_check id_msg datetime_solved date_earl date_earl_cor date_solved if date_earl_cor!=date_earl, sepby(id_post)



***-------------------------------------------
*** create separate indicator variables for each solving status, summarizing the different user- 
* solved categories or admin solved categories
tab status_sol 

gen stat_admin_sol=.
replace stat_admin_sol=1 if status_sol=="admin_solved"
gen stat_user_sol=.
replace stat_user_sol=1 if status_sol=="user_solved"
gen stat_admin_co_user_sol=.
replace stat_admin_co_user_sol=1 if status_sol=="admin_solved; co_user_solved"
gen stat_admin_user_sol=.
replace stat_admin_user_sol=1 if status_sol=="admin_solved; user_solved"
gen stat_co_user_sol=.
replace stat_co_user_sol=1 if status_sol=="co_user_solved"
gen stat_user_co_user_sol=.
replace stat_user_co_user_sol=1 if status_sol=="co_user_solved; user_solved"
gen stat_info=.
replace stat_info=1 if status_sol=="information"
gen stat_unclear=.
replace stat_unclear=1 if status_sol=="unclear"
gen stat_unsolved=.
replace stat_unsolved=1 if status_sol=="unsolved"

* generate categorical variable for each individual solving status 
gen topic_status=0
replace topic_status = 1 if stat_admin_sol == 1
replace topic_status = 2 if stat_user_sol ==1 
replace topic_status = 3 if stat_admin_co_user_sol==1
replace topic_status = 4 if stat_admin_user_sol==1
replace topic_status = 5 if stat_co_user_sol==1
replace topic_status = 6 if stat_user_co_user_sol==1
replace topic_status = 7 if stat_info==1
replace topic_status = 8 if stat_unclear==1
replace topic_status = 9 if stat_unsolved==1

label define topic_statuslab 1 "admin solved" 2 "user solved" 3 "admin solved & co-user solved" 4 "admin solved & user solved" 5 "co-user solved" 6 "co-user solved & user solved" 7 "information" 8 "unclear" 9 "unsolved"

label values topic_status topic_statuslab
tab topic_status
drop if id_post==.
drop if topic_status==7

*generate a general status indicator 
gen status=1
replace status=0 if topic_status==8 | topic_status==9
replace status=2 if topic_status==7
label variable status "0=open, 1=solved, 2=information"
tab status


* generate categorical variable for the status by summarizing the admin_solved, user_solved, unsolved and informational posts
gen status_cum=0
replace status_cum=1 if topic_status==1 | topic_status==3 | topic_status==4
replace status_cum=2 if topic_status==2  | topic_status==5 | topic_status==6 
replace status_cum=3 if topic_status==8 | topic_status==9
replace status_cum=4 if topic_status==7
label define statuscumlab 1 "admin solved" 2 "user solved" 3 "unsolved" 4 "information"

label values status_cum statuscumlab
tab status_cum

save hbp_forum_surv_2agg_step1, replace 

*-------------------------------------------------------------------------------
use hbp_forum_surv_2agg_step1, clear 

/* aggregate the following variables to post-level:
	- # individual users replying 
	- # individual users w/ HBP-affiliation replying
	- # individual users w/o HBP-affiliation replying
	- # individual users w/o known affiliation replying
	- # individual junior users replying
	- # individual senior users replying
	- # individual non-academic users replying
	- # replies w/ code & % of replies w/ code
	- # replies by admin
*/

*  # individual users replying
egen tag_duserpp = tag(id_user id_post) if id_msg!=1
egen n_userpp = total(tag_duserpp), by(id_post)
tab n_userpp

* # individual users w/ HBP-affiliation and % of users w/ HBP-affiliation
*  0 "No HBP partner" 1 "HBP partner" 2 "No information" 
egen tag_duserpp_hbp = tag(id_user id_post) if i_hbppartner==1 & id_msg!=1
egen n_userpp_hbp= total(tag_duserpp_hbp) , by(id_post)
tab n_userpp_hbp
gen p_userhbp = n_userpp_hbp/n_userpp

*# individual users w/o HBP-affiliation replying
egen tag_duserpp_nohbp = tag(id_user id_post) if i_hbppartner==0 & id_msg!=1
egen n_userpp_nohbp= total(tag_duserpp_nohbp) , by(id_post)
tab n_userpp_nohbp

*# individual users w/o known affiliation replying
gen n_userpp_noAffln = n_userpp-n_userpp_hbp-n_userpp_nohbp
tab n_userpp_noAffln

*# & % of individual junior/senior/non-academic users replying
egen tag_junior = tag(id_user id_post) if id_msg!=1 & (i_sen==1| i_sen==2 | i_sen==3)
egen tag_senior = tag(id_user id_post) if id_msg!=1 &  (i_sen==4| i_sen==5)
egen tag_nonacad = tag(id_user id_post) if i_sen==6 & id_msg!=1 
egen n_re_junior = total(tag_junior), by(id_post)
egen n_re_senior=total(tag_senior) , by(id_post)
egen n_re_nonacad=total(tag_nonacad) , by(id_post)
gen p_junior = n_re_junior/n_userpp
gen p_senior = n_re_senior/n_userpp
gen p_nonacad = n_re_nonacad/n_userpp

* # replies w/ code & % of replies w/ code
egen n_code_msg=total(code_msg), by(id_post)
tab n_code_msg
replace n_code_msg=n_code_msg-1 if poster_code==1
gen p_code = n_code_msg/(n_replies)

* # replies by admin & % of replies by admin 
egen tag_admin = tag(id_user id_post) if i_admin==1 & id_msg!=1
egen n_admin=total(tag_admin), by(id_post)
tab n_admin
gen p_admin = n_admin/n_userpp

* # and % of replies by female/male 
egen tag_fem = tag(id_user id_post) if gender==1 & id_msg!=1
egen n_female=total(tag_fem), by(id_post) 
tab n_female
egen tag_male = tag(id_user id_post) if gender==0 & id_msg!=1
egen n_male=total(tag_male), by(id_post) 
tab n_male
gen p_female = n_female/n_userpp
gen p_male = n_male/n_userpp


* labeling the variables 
label variable p_code "% messages w/ code per post"
label variable p_userhbp "% user w/ HBP affil."
label variable p_admin "% admin users per post"
label variable p_female "% female users per post"
label variable p_male "% male users per post"
label variable p_junior "% junior users per post"
label variable p_senior "% senior users per post"
label variable p_nonacad "% non-academic users per post"
label variable n_male "# male users per post"
label variable n_female "# female users per post"
label variable n_re_junior "# junior users per post"
label variable n_re_senior "# senior users per post"
label variable n_re_nonacad "# non-academic users per post"
label variable n_admin "# admins per post"
label variable n_userpp "# user per post"
label variable n_userpp_hbp "# user per post with HBP affiliation"
label variable n_userpp_nohbp "# user per post w/o HBP affiliation"
label variable n_userpp_noAffln "# user per post w/o known affiliation"
label variable n_code_msg "# messages with code per post"

des

save hbp_forum_surv_2agg_step2, replace 

*-------------------------------------------------------------------------------
* add the poster information 
use hbp_forum_surv_2agg_step2, clear
merge m:1 id_post using hbp_forum_pq_2reshape_poster
li id_post id_msg poster_code if _merge==2
drop if _merge==2
drop _merge
save hbp_forum_surv_2agg_step3, replace

*---------------------------------------------------------------------------------
* Reshaping the data to wide 

use hbp_forum_surv_2agg_step3, clear
* drop data that was used for aggregation and is now unnecessary
drop tagged_user_id* tagging_u_id* tagging_user* forward_msg msg_tag time_text2 date_solved z i_admin ny_post msg_text /// 
	date_sol date_text solved_by date_solved i_pph0 i_pph1 i_pph2 i_pph3 seniority_ph0 seniority_ph1 seniority_ph2 ///
	sen_0 sen_1 sen_2 i_sen date day tim d_check x check id_qu re_op_msg status_sol stat_admin_sol stat_user_sol ///
	stat_admin_co_user_sol stat_admin_user_sol stat_co_user_sol stat_user_co_user_sol stat_info stat_unclear ///
	stat_unsolved tag_junior tag_senior tag_nonacad tm msg_date id_user doubleU i_hbppartner gender msg_time ///
	code_msg solving_msg country_ph0 country_ph1 country_ph2 i_hbppartner_0 i_hbppartner_1 i_hbppartner_2 ///
	tag_duserpp tag_duserpp_hbp tag_duserpp_nohbp n_userpp_noAffln tag_admin tag_fem tag_male country
	
drop if id_msg==.
des
* exclude the following variables from being reshaped:
ds  date_earl_cor jira_posted solv_jira user_tag poster_female poster_junior poster_senior poster_hbp poster_code ///
	re_opened status_cum date_sol_1 day_sol_1 n_male n_female n_admin i_hbpplatform n_userpp n_userpp_hbp ///
	n_userpp_nohbp p_code p_male p_userhbp p_female p_admin n_code_msg time_solved status_detail ///
	topic_status status id_post status_detail status datetime_solved id_msg cat n_repl y  cat_g_brain_sim_model ///
	cat_g_neuromorphic cat_g_neurorobotics cat_g_tech_support cat_g_organization cat_g_others date_late date_earl ///
	i_code n_re_junior n_re_senior n_re_nonacad p_junior p_senior p_nonacad, not 
*rename the remaining variable (msg_yqu)
foreach x of varlist `r(varlist)' {
rename `x' `x'_
}

* defining again the variables to be excluded from reshaping
ds  date_earl_cor poster_junior poster_senior jira_posted solv_jira user_tag poster_female poster_hbp poster_code ///
	re_opened status_cum date_sol_1 day_sol_1  n_male n_female n_admin i_hbpplatform n_userpp n_userpp_hbp ///
	n_userpp_nohbp p_code p_male p_userhbp p_female p_admin n_code_msg time_solved status_detail topic_status ///
	status id_post status_detail status datetime_solved id_msg n_userpp_nohbp n_cat cat n_repl y ///
	cat_g_brain_sim_model cat_g_neuromorphic cat_g_neurorobotics cat_g_tech_support cat_g_organization cat_g_others ///
	date_late date_earl i_code n_re_junior n_re_senior n_re_nonacad p_junior p_senior p_nonacad , not 
*reshaping the data to wide using msg_yqu as vehicle
reshape wide `r(varlist)', i(id_post) j(id_msg) 
des
*dropping msg_yqu
drop msg_yqu_1-msg_yqu_30
*generate categorical variable for the topic categories 
gen cat_all = 0
replace cat_all = 1 if cat_g_neuromorphic == 1
replace cat_all = 2 if cat_g_brain_sim_model ==1 
replace cat_all = 3 if cat_g_neurorobotics==1
replace cat_all = 4 if cat_g_tech_support==1
replace cat_all = 5 if cat_g_organization==1
replace cat_all = 6 if cat_g_others==1
label define cat_alllab 1 "Neuromorphic" 2 "Brain Sim/Model" 3 "Neurorobotics" 4 "Tech Support" 5 "Organization" 6 "Others"

label values cat_all cat_alllab
des
drop cat_g_*
save hbp_forum_wide_survival_oneQ_int, replace


*-------------------------------------------------------------------------------
/* add country information per post
   to add the # of different countries to each post, we need to calculate the distinct
   countries per post. For this we use the hbp_forum_survival_prep_2 dataset which is still in long format (id_post & id_msg)
   thus contains the country-info of each user replying 
*/
use hbp_forum_survival_prep_2, clear

keep id_post country
drop if country=="unkown"
bysort id_post country : gen wanted = _n == 1
bysort id_post (country): replace wanted = sum(wanted)
by id_post : replace wanted = wanted[_N]

list in 1/100, sepby(id_post )
rename wanted n_ctry
drop country
duplicates drop
save hbp_forum_survival_oneQ_country, replace 

*---------------------------------------------------------
*Add the country info to the intermediate dataset 
use hbp_forum_wide_survival_oneQ_int, clear

merge 1:1 id_post using hbp_forum_survival_oneQ_country
drop _merge
*replace n_ctry=3 if n_ctry==4
*label define ctry_lab 1 "1 ctry involved" 2 "2 ctrys involved" 3 "3-2 ctrys involved" 
*label values n_ctry ctry_lab
des

save hbp_forum_wide_survival_oneQ, replace



