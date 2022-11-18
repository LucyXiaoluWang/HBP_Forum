* creating the dataset for the post-quarter regression analyses
* the datasets used here are anonymized and the follwing steps were taken to create the dataset 
/*
- the raw data of the posts and replies were cleaned
- the user data were compiled
- each post was reviewed and its solving status was determined
- each post was reviewed and coded on whether it was forwarded to JIRA
- the original dataset containing the posts and replies in wide format was converted 
  into long format in which each observation is one reply of a post
- the user databank and the post data were anonymized 
- Forum data was saved as hbp_forum_data2agg.dta and the user data as hbp_forum_user_databank_anonym.dta
*/


*----------------------------------------------------------------------------
*----------------------------------------------------------------------------
**# creating dataset containing aggregated variables (post-quarter-level)
/*
prepare post-quarter-level regression dataset
	- generate indicator for the questions asked within the post
	- determine the solving time of the first question asked and solved 
	- subset the data by keeping only the first question and its solution
	- adding the anonymized user data 
	- generate indicators for the seniority level, solving status and hbp-partnership-status during the phases in which the post/reply was sent
	- 

*/

*** Starting with preparing the categorical variables and the time-relevant variables 
use hbp_forum_data2agg, clear

* generate categorical variable for the topic categories 
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
drop cat_g_*

*** checking and correcting the format of the date variable for the solving time of the question
des date_solved
des time_solved
generate date_text = string(date_solved, "%td")
tostring time_solved, g(time_text2) format(%tcHH:MM:SS) force
gen double datetime_solved = clock(date_text + time_text2, "DMY hms")
format datetime_solved %tc
li date_text time_text2 datetime_solved in 20/40



*** Determining the number of questions that were being asked within a post and assigning a question-id. 
* For this, we sort the data by post and then within post by the solving time. 
bysort id_post (id_msg datetime_solved) : gen id_qu = sum(datetime_solved != datetime_solved[_n-1])
 
* generate a variable containing the solving time of the first question per post 
by id_post (id_msg datetime_solved), sort: gen double date_sol_1=datetime_solved[1]

*if the first post is unsolved, we use the second question within that post that has been solved
by id_post (id_msg datetime_solved), sort: replace date_sol_1=datetime_solved if id_qu==1

* format the solving date 
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
*not the case - therefore no need to drop if x==0 


* 5. Lastly, we verify that for each thread has the same value for the status_detail and thus belongs to the same question
gen check=1
* for this we sort the data by post and message and create an indicator if the status is different
bysort id_post (id_msg): replace check=0 if status_detail!=status_detail[1] 
drop if check==0
*indeed there where some remaining follow-up questions left (414 observations deleted) and which were caught now by the status
* verifying that we still have all initial questions in the dataset
tab id_msg

// @ACK: the steps 4-5 logic is not exactly clear - we need to add some explanation (let's discuss)


***-------------------------------------------
*** create separate indicator variables for each solving status, summarizing the different user- 
* solved categories or admin solved categories
tab status_sol 

gen stat_admin_sol=.
replace stat_admin_sol=1 if status_sol=="admin_solved" | ///
	status_sol=="admin_solved; co_user_solved" | status_sol=="admin_solved; user_solved"
	
gen stat_user_sol=.
replace stat_user_sol=1 if status_sol=="user_solved" | ///
	status_sol=="co_user_solved" | status_sol=="co_user_solved; user_solved"

gen stat_info=.
replace stat_info=1 if status_sol=="information"

gen stat_unclear=.
replace stat_unclear=1 if status_sol=="unclear"

gen stat_unsolved=.
replace stat_unsolved=1 if status_sol=="unsolved"


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
gen status=1
replace status=0 if topic_status==4 | topic_status==5
label variable status "0=open, 1=solved"

tab status
save hbp_forum_pqu_2agg_step1, replace 

// @ACK: ok, now I see where "step 3" comes - the order feels flipped,
// we'd better assign better names, or (easier) define at the very beginning block
// what are the steps involved and why we number them in this particular way 
// Or, we rename the orders to align them well with the order they show up in our code 
// @LXW: I renamed the file - it was actually easier ;-)

*-------------------------------------------------------------------------------
**# Adding the user data to the forum data
* add the user data information (country, gender, hpb partner, seniority)
use hbp_forum_pqu_2agg_step1, clear
merge m:1 id_user using hbp_forum_user_databank_anonym, keepusing(country_ph0 country_ph1 country_ph2 gender i_hbppartner_0 i_hbppartner_1 i_hbppartner_2  seniority_ph0 seniority_ph1 seniority_ph2)
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

*-------------------------------------------------------------------------------
* similarly, we need an indicator on whether the affiliation of the user was an HBP Partner in the respective phase
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


cou if id_post==.
drop if id_post==.
save hbp_forum_pq_2agg_step2, replace


*------------------------------ 
use hbp_forum_pq_2agg_step2, clear

/* next steps_
	- calculate the overall number of solved posts (and type of solving status) per quarter 
	- calculate the number of tags per message (to then aggregate it on post level in the next step)
*/
sort msg_yqu id_post
	
*total number of posts quarter within a status category over all posts  
bys msg_yqu: egen nyqu_status_admin = total(stat_admin_sol) if stat_admin_sol==1 
bys msg_yqu: egen nyqu_status_user = total(stat_user_sol) if stat_user_sol==1 
bys msg_yqu: egen nyqu_status_info = total(stat_info) if stat_info==1 
bys msg_yqu: egen nyqu_unclear = total(stat_unclear) if stat_unclear==1 
bys msg_yqu: egen nyqu_unsolved = total(stat_unsolved) if stat_unsolved==1 


*number of tags per post
gen n_tag = 0
replace n_tag=1 if !missing(tagged_user_id1)& missing(tagged_user_id2) & missing(tagged_user_id3)
replace n_tag=2 if !missing(tagged_user_id1)& !missing(tagged_user_id2) & missing(tagged_user_id3)
replace n_tag=3 if !missing(tagged_user_id1)& missing(tagged_user_id2) & !missing(tagged_user_id3)
tab tagged_user_id3
li id_post tagged_user_id1 tagged_user_id2 tagged_user_id3 n_tag if n_tag!=0
tab id_post if n_tag!=0

save hbp_forum_pq_2reshape_1, replace




*-----------------------------------------------------------------------------
use hbp_forum_pq_2reshape_1, clear

/* next steps:
generate the indicator variables for the first post characteristics and save it 
in a seperate file. As the initial post characteristics do not change within the thread
we do not aggregate this data but simply add it later to the aggregated data.
We obtain now indicators 
	- whether the poster was female, hbp-affiliated, senior or junior
	- whether the first post contained code 
*/

keep id_post id_msg gender i_hbppartner code_msg i_sen
keep if id_msg==1
tab i_sen, sort

*dummy whether initial poster is hbp affilaited or which gender
bys id_post: gen poster_female=1 if gender==1
bys id_post: gen poster_hbp=1 if i_hbppartner==1
bys id_post: gen poster_code=1 if code_msg==1
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

save hbp_forum_pq_2reshape_poster, clear

// @ACK: hi, here I think we use this for the poster at MPI, correct?
// we can keep and just add a note this is the version used for an MPI poser
// (which we can also release after PLOS ONE got accepted.) @LXW: no, we actually 
// use it here in the aggregation: with "poster" I am referring to the initial post characteristics as I have written in the comments :-)


*--------------------------------------------------------------------------
*--------------------------------------------------------------------------
**# Aggregating the data to post-quarter level 
* as we are looping through all 534 posts, we have to split the aggregation into
* several steps 

use hbp_forum_pq_2agg_step2, clear

/* steps: 
aggregate the informtion for the replies (id_msg>1) to post-quarter level
for this we create tags per post for 
	- individual users replying 
	- indvidiual users with hbp affiliation
	- individual users without hbp affiliation
	- individual users without affiliation information 
we then loop through each post using the post-id to calculate the 
	- number of individual users replying 
	- number of indvidiual users with hbp affiliation
	- number of individual users without hbp affiliation
	- number of individual users without affiliation information 
per post and quarter 
*/

egen tag_duserpp = tag(id_user id_post) if id_msg!=1
egen tag_duserpp_hbp = tag(id_user id_post) if i_hbppartner==1 & id_msg!=1
egen tag_duserpp_nohbp = tag(id_user id_post) if i_hbppartner==0 & id_msg!=1
egen tag_duserpp_noaff = tag(id_user id_post) if i_hbppartner==2 & id_msg!=1

forvalues i=1/534{	
	*total number of users per post with hbp affiliaton or not 
	*  0 "No HBP partner" 1 "HBP partner" 2 "No information" 
	bys msg_yqu: egen nyqu_user_`i'=total(tag_duserpp) if id_post==`i'
	bys msg_yqu: egen nyqu_upphbp_`i'= total(tag_duserpp_hbp) if id_post==`i'
	bys msg_yqu: egen nyqu_uppnohbp_`i'= total(tag_duserpp_nohbp) if id_post==`i'
	bys msg_yqu: egen nyqu_uppnoAffln_`i' = total(tag_duserpp_noaff) if id_post==`i'
	bys msg_yqu: egen nyqu_newQ_`i' = total(re_op_msg) if id_post==`i'
}

* we keep only the newly generated variables and the id_post and msg_yqu for reshaping later
keep id_post msg_yqu nyqu_user_*  /// 
	nyqu_upphbp_* nyqu_uppnohbp_* nyqu_uppnoAffln_* nyqu_newQ_*
cou if id_post==.	 
save hbp_forum_pq_2reshape_2, replace


*---------------------------------------
use hbp_forum_pq_2agg_step2, clear

/* steps
aggregate the informtion for the replies (id_msg>1) to post-quarter level
first we recover the information whether the user was admin from the databank 
for this we create tags per post for 
	- individual users replying 
	- indvidiual admin users 
	- individual female users 
	- individual male users  
we then loop through each post using the post-id to calculate the 
	- number of individual users replying 
	- number of indvidiual admin users 
	- number of individual female/male users 
	- number of replies (to the first question)
	- number of replies containing code 
per post and quarter 
*/

merge m:1 id_user using hbp_forum_user_databank_anonym, keepusing(i_admin i_jira)
keep if _merge==3
drop _merge
des
	

* number of code per post
egen tag_user = tag(id_user id_post) if id_msg!=1 
egen tag_admin = tag(id_user id_post) if i_admin==1 & id_msg!=1
egen tag_fem = tag(id_user id_post) if gender==1 & id_msg!=1
egen tag_male = tag(id_user id_post) if gender==0 & id_msg!=1


forvalues i=1/534{	
	*total number of users per post with hbp affiliaton or not 
	*  0 "No HBP partner" 1 "HBP partner" 2 "No information" 
	bys msg_yqu: egen nyqu_users_`i' = total(tag_user) if id_post==`i' 
	bys msg_yqu: egen nyqu_code_`i'=total(code_msg) if id_post==`i' & id_msg!=1
	bys msg_yqu: egen nyqu_replies_`i'=total(x) if id_post==`i' & id_msg!=1
	bys msg_yqu: egen nyqu_admin_`i'=total(tag_admin) if id_post==`i'
	bys msg_yqu: egen nyqu_female_`i'=total(tag_fem) if id_post==`i' 
	

}

keep id_post msg_yqu nyqu_code_* nyqu_replies_* /// 
	nyqu_admin_* nyqu_female_* nyqu_users_* 



*--------------------------------------- seniority
use hbp_forum_pq_2agg_step2, clear

/* steps
aggregate the informtion for the replies (id_msg>1) to post-quarter level
for this we create tags per post for 
	- individual users who are juniors 
	- indvidiual users who are seniors
	- individual users who are non-academic
we then loop through each post using the post-id to calculate the 
	- number of individual junior users replying 
	- number of indvidiual senior users replying 
	- number of individual non-academic users replying  
per post and quarter 
*/


des
* number of seniority levels per post
egen tag_junior = tag(id_user id_post) if i_sen==1| i_sen==2 | i_sen==3
egen tag_senior = tag(id_user id_post) if i_sen==4| i_sen==5
egen tag_nonacad = tag(id_user id_post) if i_sen==6


forvalues i=1/534{	
	bys msg_yqu: egen nyqu_re_junior_`i' = total(tag_junior) if id_post==`i' & id_msg!=1
	bys msg_yqu: egen nyqu_senior_`i'=total(tag_senior) if id_post==`i' & id_msg!=1
	bys msg_yqu: egen nyqu_re_nonacad_`i'=total(tag_nonacad) if id_post==`i' & id_msg!=1


}

keep id_post msg_yqu nyqu_re_junior_* nyqu_senior_* /// 
	nyqu_re_nonacad_* 
	
save hbp_forum_pq_2reshape_4, replace


*---------------
use hbp_forum_pq_2agg_step2, clear

* calculate the number of distinct countries per post and quarter 

keep id_post msg_yqu country

bysort id_post country (msg_yqu) : gen wanted = _n == 1
bysort id_post (msg_yqu country): replace wanted = sum(wanted)
by id_post msg_yqu: replace wanted = wanted[_N]

list in 1/100, sepby(id_post msg_yqu)
rename wanted nyqu_ctry
*variation in geographic differences over time irrespective of post-id 
egen tag = tag(country msg_yqu)
egen distinct = total(tag), by(msg_yqu) 
sort msg_yqu
list, sepby(msg_yqu)
rename distinct country_yqu

label variable country_yqu "# countries per quarter"
label variable nyqu_ctry "# countries per post per quarter"
drop country tag
duplicates drop
save hbp_forum_pq_country, replace 


* ----------------------------------------------------------------------------
*-------------------------------------------------------------------------------
***# Collapsing and reshaping the data 

/* Currently the data is wide. We have each variable 534 times (e.g. nyqu_senior_332)
We will therefore first collaps the dataset by summing the variables up over msg_yqu and id_post and then collapse it again
over the quarter-level 

In a second step we will then reshape the data from wide to long using the msg_yqu as 
existing id and creating the post identificator from the variable names.

In each round of reshaping we also label the variables. 

For the variables female/admin users replying and number of messages containing code_exist
we also calculate the share of these variables per post. 

After the reshaping, the newly created datasets are merged with the post-id and the msg_yqu as keys.
*/
*---------------------------------------------------------------------------
* First round of reshaping

use hbp_forum_pq_2reshape_2, clear 

cou if msg_yqu==.
unique id_post 
* making sure that there are no duplicates 
duplicates report
duplicates drop
des

collapse nyqu_user_* nyqu_upphbp_* /// 
	nyqu_uppnohbp_* nyqu_uppnoAffln_* nyqu_newQ_*  , by(msg_yqu id_post)	

collapse nyqu_user_* nyqu_upphbp_* /// 
	nyqu_uppnohbp_* nyqu_uppnoAffln_* nyqu_newQ_* ,  by(msg_yqu)



reshape long nyqu_user_ nyqu_upphbp_ nyqu_uppnohbp_ nyqu_uppnoAffln_  nyqu_newQ_, i(msg_yqu) j(postid) 
		
rename *_ *
rename postid id_post

* variable labeling 
label variable nyqu_user "# user replying per topic/quarter"
label variable nyqu_newQ "# new questions per topic/quarter"
label variable nyqu_upphbp "# user replying per topic/quarter w/ HBP affil."
label variable nyqu_uppnohbp "# user replying per topic/quarter w/o HBP affil."
label variable nyqu_uppnoAffln "# user replying per topic/quarter w/o known affil."


save HBP_forum_postquarter_long_1, replace


*-------------------------------------------------------------------------------
* 2nd round of reshaping 
use hbp_forum_pq_2reshape_3, clear 

cou if msg_yqu==.
unique id_post 
duplicates report
duplicates drop
des

collapse nyqu_code_* nyqu_replies_* /// 
	nyqu_admin_* nyqu_female_* nyqu_users_*  , by(msg_yqu id_post)	

collapse nyqu_code_* nyqu_replies_* /// 
	nyqu_admin_* nyqu_female_* nyqu_users_*  ,  by(msg_yqu)

reshape long nyqu_code_ nyqu_replies_ /// 
	nyqu_admin_ nyqu_female_ nyqu_users_  , i(msg_yqu) j(postid) 
		
rename *_ *
rename postid id_post

* calculating the share of female/admin users replying in the respective quarter compared to the overall number 
* of users replying to the post in that quarter
gen pyq_female= nyqu_female/nyqu_user
gen pyq_code= nyqu_code/(nyqu_replies) 
gen pyq_admin= nyqu_admin/nyqu_users	

label variable pyq_female "% female users replying per topic/quarter"
label variable pyq_code "% replies with code per topic/quarter"
label variable pyq_admin "% admin users replying per topic/quarter"
label variable nyqu_female "# female users replying per topic/quarter"
label variable nyqu_admin "# admins replying per topic/quarter"
label variable nyqu_code "# replies with code per topic/quarter"

save HBP_forum_postquarter_long_2, replace



*-------------------------------------------------------------------------------
* 3rd round of reshaping 
use hbp_forum_pq_2reshape_4, clear 


keep id_post msg_yqu nyqu_re_junior_* nyqu_senior_* /// 
	nyqu_re_nonacad_* 


cou if msg_yqu==.
unique id_post 
duplicates report
duplicates drop
des

collapse nyqu_re_junior_* nyqu_senior_* /// 
	nyqu_re_nonacad_*  , by(msg_yqu id_post)	

collapse nyqu_re_junior_* nyqu_senior_* /// 
	nyqu_re_nonacad_*  ,  by(msg_yqu)

reshape long nyqu_re_junior_ nyqu_senior_ /// 
	nyqu_re_nonacad_  , i(msg_yqu) j(postid) 
		
rename *_ *
rename postid id_post



save HBP_forum_postquarter_long_3, replace





*-------------------------------------------------------------------------------
*-------------- combine the datasets and generate additional share variables

use HBP_forum_postquarter_long_2, clear

merge 1:1 id_post msg_yqu using HBP_forum_postquarter_long_1

merge 1:1 id_post msg_yqu using HBP_forum_postquarter_long_3
drop _merge 
* we drop observations if they contain no entries in any of the variables
drop if nyqu_code==. & nyqu_replies==. & ///
	nyqu_admin==. & nyqu_female==. & nyqu_users==. & /// 
	nyqu_user==. & nyqu_upphbp==. & nyqu_uppnohbp==. & ///
	nyqu_uppnoAffln==. & nyqu_newQ==. & nyqu_re_nonacad==. & nyqu_senior==. & nyqu_re_junior==.

*generate additional shares 
gen pyq_hbp= nyqu_upphbp/nyqu_user
label variable pyq_hbp "% unique users affiliated with HBP partners"
gen pyq_senior= nyqu_senior/nyqu_user
gen pyq_re_junior= nyqu_re_junior/nyqu_user
gen pyq_re_nonacad= nyqu_re_nonacad/nyqu_user

label variable pyq_senior "% senior users replying per post/quarter"
label variable pyq_re_junior "% junior users replying per post/quarter"
label variable pyq_re_nonacad "% non-academic users replying per post/quarter"

label data "long Forum data, post-quarter level, no meta-data, intermediate"	
save HBP_forum_postquarter_long_int, replace


*-------------------------------------------------------------------------------
**# Adding the meta-level data 

/* Steps
In the now generated dataset we have only the variables which were aggregated to the post-quarter level.
But not the variables on post-level or quarter-level only are not included and we can recover them by merging the intermediate 
dataset with a dataset containing the meta-level information.
*/

use hbp_forum_pq_2reshape_1, clear 

des
replace solv_jira=1 if id_post==202 | id_post==138
keep id_post cat_all re_opened status_sol status i_hbpplatform y i_code ///
	nyqu_status_admin nyqu_status_user nyqu_status_info /// 
	nyqu_unclear nyqu_unsolved msg_yqu jira_posted solv_jira status_sol 
duplicates report
duplicates drop
save hbp_forum_pq_metalevel


*-------------------------------------------------------------------------------
*Combine the meta-level with the intermediate dataset 
use HBP_forum_postquarter_long_int, clear 

merge 1:m id_post msg_yqu using hbp_forum_pq_metalevel
drop _merge
des

label variable nyqu_status_user "# total user-solved posts per quarter"
label variable nyqu_status_admin  "# total admin-solved posts per quarter"
label variable nyqu_status_info "# total info posts per quarter"
label variable nyqu_unclear "# total posts per quarter w/ unclear status"
label variable nyqu_unsolved "# total posts unsolved posts per quarter"


save HBP_forum_postquarter_long_int2, replace
*------------------------------------------------------------------------------
* adding the data on the poster and first post and the country and replacing missing data by 0
use HBP_forum_postquarter_long_int2, clear

merge m:1 id_post using data_postyqu_2reshape_poster
drop _merge
local varlist poster_female poster_hbp pyq_hbp nyqu_code nyqu_replies nyqu_admin nyqu_female nyqu_users pyq_admin pyq_female pyq_code nyqu_user nyqu_upphbp nyqu_uppnohbp nyqu_uppnoAffln nyqu_newQ n_replies i_code i_hbpplatform re_opened status nyqu_status_admin nyqu_status_user nyqu_status_info nyqu_unclear nyqu_unsolved poster_junior poster_senior poster_code poster_hbp pyq_re_nonacad pyq_re_junior pyq_senior nyqu_re_nonacad nyqu_senior nyqu_re_junior
foreach var of local varlist {
	replace `var'=0 if `var'==.
}
duplicates report id_post msg_yqu

merge 1:1 id_post msg_yqu using hbp_forum_post_quarter_country
drop _merge

label data "Long, agg. Forum data, post-quarter-level"
save HBP_forum_postquarter_long, replace
