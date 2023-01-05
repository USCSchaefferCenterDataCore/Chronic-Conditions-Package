/*********************************************************************************************/
TITLE1 'Chronic Conditions Macro';

* AUTHOR: Patricia Ferido;

* DATE: 3/26/2018;

* PURPOSE: Identify all the codes in the prepared claims data sets;

* INPUT: Claims data sets;
* OUTPUT: - Claims data sets with diagnosis flags
					- Yearly beneficiary level files with monthly condition flags;

options compress=yes nocenter ls=150 ps=200 errors=5 errorabend errorcheck=strict mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

***** First getting full month length of analytical period for use later and first/last years of data;
%macro datayears;
%let filecnt=1;
%let claimsfile=%scan("&claims_data",&filecnt," ");
	
%do %while(%length(&claimsfile)>0);
	
		data clmyr;
			set &claimsfile.;
			yr=year(claim_dt);
		run;
		
		proc freq data=clmyr noprint;
			table yr / out=yr_&filecnt;
		run;
		
		%let filecnt=%eval(&filecnt+1);
		%let claimsfile=%scan("&claims_data",&filecnt," ");
		
%end;

%mend;

%datayears;

data yr;
	set yr_:;
run;

proc sql noprint;
		select min(yr) into :mindatayear
		from yr;
		
		select max(yr) into :maxdatayear
		from yr;
quit;

%put &mindatayear;
%put &maxdatayear;

* Checking that years of data and years specified in macro line up - issuing warnings if not;
data _null_;
	if &minyear.<&mindatayear. then do;
			put "WARNING: MINIMUM YEAR REQUESTED IS EARLIER THAN YEAR PROVIDED IN DATA, REQUESTED YEARS OUTSIDE OF PROVIDED YEARS WILL NOT BE OUTPUT";
	end;
	if &maxyear.>&maxdatayear. then do;
			put "WARNING: MAXIMUM YEAR REQUESTED IS LATER THAN YEAR PROVIDED IN DATA, REQUESTED YEARS OUTSIDE OF PROVIDED YEARS WILL NOT BE OUTPUT";
	end;
run;

* In case output years and data years do not line up, then creating values that will always ensure
  that only years are output that overlap between the two;
%let maxofminyears=%sysfunc(max(&mindatayear,&minyear));
%let minofmaxyears=%sysfunc(min(&maxdatayear,&maxyear));

data _null_;
	mo=intck("month",mdy(1,1,&mindatayear),mdy(1,1,&maxdatayear+1));
	call symputx("total_mo",mo);
run;

%put &total_mo;

***** Macro that sets up conditions to list;

%macro overcond;
		
	***** 1) Getting all relevant condition information into macro variables for later use;
	* This macro gets all the relevant information for the condition including:
		- List of all relevant codes
		- List of all locations to find codes (primary diagnosis only, all diagnoses, etc.)
		- List of all reference periods
		- List of all min days apart and max days apart requirement;
	 %getcodes;
	
	* This portion of code gets the total number of qualifying claim groups and qualifying number of claims by condtion;
	proc sql noprint;
		%do i=1 %to &nclmgrps;
		
			select claim_type&i into :qualclmgrps&i separated by ' | '
			from cc_desc
			order by condition;
			
			select num_dx&i into :qualnumdx&i separated by '|'
			from cc_desc
			order by condition;
		
		%end;
	quit;

	%put &qualclmgrps1;
	%put &&qualclmgrps&nclmgrps;	
	%put &qualnumdx1;
	%put &&qualnumdx&nclmgrps;
		
	***** 2) Cycle through all claims data sets and separating out each claim by presence of condition.
					 Creates stacked data sets of all the claims by condition. For example, a data set called ALZHE will be
					 created containing all the alzheimer claims from the input data sets;
					 	
	%let filecnt=1;
	%let claimsfile=%scan("&claims_data",&filecnt," ");
	
	%do %while(%length(&claimsfile)>0);
	
		* Macro for finding claims by condition;
		%tagcond;
		
		%let filecnt=%eval(&filecnt+1);
		%let claimsfile=%scan("&claims_data",&filecnt," ");
		
	%end;
	
	* appending all the conditions together pulled from each file;
	%let filecnt=%eval(&filecnt-1); * subtracting 1 to get true file count value;
	%do p=1 %to &ncondlist;
		%let condname=%scan(&condlist,&p,'|');
		%if &filecnt.=1 %then %do;
			proc datasets library=work noprint;
				change claims_&condname.1=&condname;
			run;
		%end;
		%else %if &filecnt.>1 %then %do;
		data &condname.;
			set claims_&condname.1-claims_&condname.&filecnt.;
			by &id. claim_dt;
		run;
		%end;
	%end;
		
	***** 3) Cycle through all conditions and check against algorithm requirements
				   Output a yearly beneficiary file with 1/0 flags for each month if beneficiary meets requirements;
	%do p=1 %to &Ncondlist;
				
	 %cc_flags; 
	 
	%end;
	
	***** 4) Merges to enrollment data and creates final flag with 5 variables:
					 .I - incomplete years of data, if reference period is 3 years and data starts in 2002, then 2002-2004 will have .I
					  0 - no qualifying coverage and claims
					  1 - qualifying claims but no qualifying coverage
					  2 - qualifying coverage but no qualifying claims
					  3 - qualifying claims and qualifying coverage; 
	%enrollment;
	
%mend;

***** 1) Macro that creates all condition information macro variables to be used in other programs;
%macro getcodes;

	proc contents data=cc_desc out=contents_cc_desc noprint; run;
	
	%global nclmgrps condlist ncondlist refperiod mindaysapart maxdaysapart;
	
	* Counting the number of claim types there are in CC_Desc;
	proc sql noprint;
	
		select count(name) into :nclmgrps trimmed
		from contents_cc_desc
		where find(upcase(name),"CLAIM_TYPE");
	
	quit;
	
	proc sort data=cc_desc out=cc_desc; by condition; run;
	
	proc sql noprint;
		
		* Put all conditions into a list;
		select distinct condition into :CondList separated by '|'
		from cc_desc
		order by condition;
		
		* Counting total number of conditions;
		select count(condition) into :NCondList
		from cc_desc;
		
		* Putting all reference periods into a list;
		select ref_months into :refperiod separated by '|'
		from cc_desc
		order by condition;
		
		* Putting all minimum days apart into a list;
		select min_days_apart into :mindaysapart separated by '|'
		from cc_desc
		order by condition;
		
		* Putting all maximum days apart into a list;
		select max_days_apart into :maxdaysapart separated by '|'
		from cc_desc
		order by condition;
			
	quit;  

	title1 "LIST OF CONDITIONS TO PROCESS";
	%put &CondList;
	%put &NCondList;
	%put &refperiod;
	%put &mindaysapart;
	%put &maxdaysapart;
	
	%global icd9dx icd9dxloc icd9ndx icd9dxexcl icd9dxexclloc icd9ndxexcl
					icd10dx icd10dxloc icd10ndx icd10dxexcl icd10dxexclloc  icd10ndxexcl  
					hcpcs	hcpcsloc hcpcsn hcpcsexcl hcpcsexclloc hcpcsnexcl
					icd9prcdr icd9prcdrloc icd9nprcdr icd9prcdrexcl icd9prcdrexclloc icd9nprcdrexcl
					icd10prcdr icd10prcdrloc icd10nprcdr icd10prcdrexcl icd10prcdrexclloc icd10nprcdrexcl
					codename;
		
		/* The section of code below puts all the codes into lists by code type. Not all of the
			 code types may be used in each analysis (e.g. analysis is before September 2015 and only uses
			 ICD-9 Codes).	The lists created below are dependent on all the information ordered by condition
			 and separated by '|'. If any information is not present for a condition, the 
	  	 data set 'cc_desc1' below is created to fill in the gaps and put in a black place-holder. 
	  	 The code also assumes that each condition looks at the same diagnoses location for 
	  	 every code. (e.g. all codes for atrial fibrillation must be the first or second dx 
	  	 on claim).  */
						
		data cc_desc1;
			format codetype $10.;
			set cc_desc (keep=condition in=a)
				  cc_desc (keep=condition in=b)
				  cc_desc (keep=condition in=c)
				  cc_desc (keep=condition in=d)
				  cc_desc (keep=condition in=e);
			if a then codetype="ICD9DX";
			if b then codetype="ICD10DX";
			if c then codetype="ICD9PRCDR";
			if d then codetype="ICD10PRCDR";
			if e then codetype="HCPCS";
		run;
		
		proc sort data=cc_desc1; by condition codetype; run;
			
		proc sort data=cc_codes out=condcodes; by condition codetype; run;
			
		data condcodes1;
			merge condcodes cc_desc1;
			by condition codetype;
			format dxcode2 $8.;
			period=index(trim(left(dxcode)),".");
			dxcode2=upcase(trim(left(compress(dxcode,"."))));
			* Adjusting to compensate for any incorrectly formatted numeric codes due to CSV format;
			if length(trim(left(dxcode2)))=4 & CodeType="ICD9DX" & period=4 then dxcode2=trim(left(dxcode2))||"0";
			if length(trim(left(dxcode2)))=3 & CodeType="ICD9DX" & period=4 then dxcode2=trim(left(dxcode2))||"00";
			if length(trim(left(dxcode2)))=3 & CodeType="ICD9DX" & period=2 then dxcode2="0"||trim(left(dxcode2))||"0";
			if length(trim(left(dxcode2)))=3 & CodeType="ICD9DX" & period=0 then dxcode2=trim(left(dxcode2))||"00";
			if length(trim(left(dxcode2)))=2 & CodeType="ICD9DX" & period=0 then dxcode2="0"||trim(left(dxcode2))||"00";
			if length(trim(left(dxcode2)))=3 & CodeType="ICD9PRCDR" & period=2 then  dxcode2="0"||trim(left(dxcode2));
			if length(trim(left(dxcode2)))=3 & CodeType="ICD9PRCDR" & period=3 then dxcode2=trim(left(dxcode2))||"0";
			if codetype="HCPCS" and dxcode ne "" then do;
				if length(dxcode2)=1 then dxcode2="0000"||dxcode2;
				if length(dxcode2)=2 then dxcode2="000"||dxcode2;
				if length(dxcode2)=3 then dxcode2="00"||dxcode2;
				if length(dxcode2)=4 then dxcode2="0"||dxcode2;
			end;
			last=last.codetype;
		run;
		
		/* To create macro with code lists 
			 - Loop through each codetype - initialize macro variable
			 - Loop through each condition - create list of codes separated by comma
			 - Concatenate new codes to old codes using | */
		
		%let sep=%nrstr( | );
		proc sql noprint;
						
		%do i=1 %to &Ncondlist;
			%let cond=%scan(&condlist,&i,"|");
			
			* Pulls all codes and locations for ICD9 DX;
			select dxcode2 into:icd9dx_temp separated by '","'
			from condcodes1
			where CodeType="ICD9DX" and condition="&cond";
			
			%if &i=1 %then %let icd9dx=&icd9dx_temp.;
			%else %let icd9dx=&icd9dx.&sep.&icd9dx_temp.;
				
			select dxcodelocation into:icd9dxloc_temp separated by '","'
			from condcodes1
			where CodeType="ICD9DX" and condition="&cond" and last;
			
			%if &i=1 %then %let icd9dxloc=&icd9dxloc_temp.;
			%else %let icd9dxloc=&icd9dxloc.&sep.&icd9dxloc_temp.;
			
			* Pulls all codes and locations for ICD10 DX;
			title2 "List of ICD10DX Codes and Count";
			select dxcode2 into:icd10dx_temp separated by '","'
			from condcodes1
			where CodeType="ICD10DX" and condition="&cond";
			
			%if &i=1 %then %let icd10dx=&icd10dx_temp.;
			%else %let icd10dx=&icd10dx.&sep.&icd10dx_temp.;

			select dxcodelocation into:icd10dxloc_temp separated by '","'
			from condcodes1
			where CodeType="ICD10DX" and condition="&cond" and last;
			
			%if &i=1 %then %let icd10dxloc=&icd10dxloc_temp.;
			%else %let icd10dxloc=&icd10dxloc.&sep.&icd10dxloc_temp.;
	
			* Pulls all codes and locations for HCPCS;
			title2 "List of HCPCS Procedure Codes and Count";
			select dxcode2 into:hcpcs_temp separated by '","'
			from condcodes1
			where CodeType="HCPCS" and condition="&cond";	
			
			%if &i=1 %then %let hcpcs=&hcpcs_temp.;
			%else %let hcpcs=&hcpcs.&sep.&hcpcs_temp.;
		
			select dxcodelocation into: hcpcsloc_temp separated by '","'
			from condcodes1 
			where CodeType="HCPCS" and condition="&cond" and last;
			
			%if &i=1 %then %let hcpcsloc=&hcpcsloc_temp.;
			%else %let hcpcsloc=&hcpcsloc.&sep.&hcpcsloc_temp.;
			
			* Pulls all codes and locations for ICD9 Procedure Codes;
			title2 "List of ICD 9 Procedure Codes and Count";
			select dxcode2 into:ICD9PRCDR_temp separated by '","'
			from condcodes1
			where CodeType="ICD9PRCDR" and condition="&cond";	
		
			%if &i=1 %then %let icd9prcdr=&icd9prcdr_temp.;
			%else %let icd9prcdr=&icd9prcdr.&sep.&icd9prcdr_temp.;
			
			select dxcodelocation into: ICD9PRCDRloc_temp separated by '","'
			from condcodes1
			where CodeType="ICD9PRCDR" and condition="&cond" and last;
			
			%if &i=1 %then %let icd9prcdrloc=&icd9prcdrloc_temp.;
			%else %let icd9prcdrloc=&icd9prcdrloc.&sep.&icd9prcdrloc_temp.;
			
			* Pulls all codes and locations for ICD10 Procedure Codes;
			title2 "List of ICD 10 Procedure Codes and Count";
			select dxcode2 into:icd10prcdr_temp separated by '","'
			from condcodes1
			where CodeType="ICD10PRCDR" and condition="&cond";	
		
			%if &i=1 %then %let icd10prcdr=&icd10prcdr_temp.;
			%else %let icd10prcdr=&icd10prcdr.&sep.&icd10prcdr_temp.;
			
			select dxcodelocation into: ICD10PRCDRloc_temp separated by '","'
			from condcodes1
			where CodeType="ICD10PRCDR" and condition="&cond" and last;
			
			%if &i=1 %then %let icd10prcdrloc=&icd10prcdrloc_temp.;
			%else %let icd10prcdrloc=&icd10prcdrloc.&sep.&icd10prcdrloc_temp.;
				
		%end;
		
		quit;
		
		* Codes to exclude;
		proc sort data=cc_exclude out=exclude; by condition codetype; run;
			 
		data exclude1;
			merge exclude cc_desc1;
			by condition codetype;
			format dxcode2 $8.;
			period=index(trim(left(dxcode)),".");
			dxcode2=upcase(trim(left(compress(dxcode,"."))));
			* Adjusting to compensate for any incorrectly formatted numeric codes due to CSV format;
			if length(trim(left(dxcode2)))=4 & CodeType="ICD9DX" & period=4 then dxcode2=trim(left(dxcode2))||"0";
			if length(trim(left(dxcode2)))=3 & CodeType="ICD9DX" & period=4 then dxcode2=trim(left(dxcode2))||"00";
			if length(trim(left(dxcode2)))=3 & CodeType="ICD9DX" & period=2 then dxcode2="0"||trim(left(dxcode2))||"0";
			if length(trim(left(dxcode2)))=3 & CodeType="ICD9DX" & period=0 then dxcode2=trim(left(dxcode2))||"00";
			if length(trim(left(dxcode2)))=2 & CodeType="ICD9DX" & period=0 then dxcode2="0"||trim(left(dxcode2))||"00";
			if length(trim(left(dxcode2)))=3 & CodeType="ICD9PRCDR" & period=2 then  dxcode2="0"||trim(left(dxcode2));
			if length(trim(left(dxcode2)))=3 & CodeType="ICD9PRCDR" & period=3 then dxcode2=trim(left(dxcode2))||"0";
			if codetype="HCPCS" and dxcode2 ne "" then do;
				if length(dxcode2)=1 then dxcode2="0000"||dxcode2;
				if length(dxcode2)=2 then dxcode2="000"||dxcode2;
				if length(dxcode2)=3 then dxcode2="00"||dxcode2;
				if length(dxcode2)=4 then dxcode2="0"||dxcode2;
			end;
			last=last.codetype;
		run;
			
		proc sql noprint;
		
			%do i=1 %to &Ncondlist;
			%let cond=%scan(&condlist,&i,"|");
			
		 * Pulls all codes and locations for ICD9 dxexcl;
		 title2 "List of ICD9dxexcl Codes and Count";		 
		 select dxcode2 into:icd9dxexcl_temp separated by '","'
		 from exclude1
		 where CodeType="ICD9DX" and condition="&cond.";
		 
		 %if &i=1 %then %let icd9dxexcl=&icd9dxexcl_temp.;
		 %else %let icd9dxexcl=&icd9dxexcl.&sep.&icd9dxexcl_temp.;
		 
		 select dxcodelocation into:icd9dxexclloc_temp separated by '","'
		 from exclude1
		 where CodeType="ICD9DX" and condition="&cond." and last;
		 
		 %if &i=1 %then %let icd9dxexclloc=&icd9dxexclloc_temp.;
		 %else %let icd9dxexclloc=&icd9dxexclloc.&sep.&icd9dxexclloc_temp.;
		 
		 * Pulls all codes and locations for ICD10 dxexcl;
		 title2 "List of ICD10dxexcl Codes and Count";
		 select dxcode2 into:icd10dxexcl_temp separated by '","'
		 from exclude1
		 where CodeType="ICD10DX" and condition="&cond.";
		 
		 %if &i=1 %then %let icd10dxexcl=&icd10dxexcl_temp.;
		 %else %let icd10dxexcl=&icd10dxexcl.&sep.&icd10dxexcl_temp.;
		 
		 select dxcodelocation into:icd10dxexclloc_temp separated by '","'
		 from exclude1
		 where CodeType="ICD10DX" and condition="&cond." and last;
		 
		 %if &i=1 %then %let icd10dxexclloc=&icd10dxexclloc_temp.;
		 %else %let icd10dxexclloc=&icd10dxexclloc.&sep.&icd10dxexclloc_temp.;
		 
		 * Pulls all codes and locations for HCPCS;
		 title2 "List of HCPCS Procedure Codes and Count";
		 select dxcode2 into:hcpcsexcl_temp separated by '","'
		 from exclude1
		 where CodeType="HCPCS" and condition="&cond.";
		 
		 %if &i=1 %then %let hcpcsexcl=&hcpcsexcl_temp.;
		 %else %let hcpcsexcl=&hcpcsexcl.&sep.&hcpcsexcl_temp.;
		 
		 select dxcodelocation into:hcpcsexclloc_temp separated by '","'
		 from exclude1
		 where CodeType="HCPCS" and condition="&cond." and last;
		 
		 %if &i=1 %then %let hcpcsexclloc=&hcpcsexclloc_temp.;
		 %else %let hcpcsexclloc=&hcpcsexclloc.&sep.&hcpcsexclloc_temp.;
		 
		 * Pulls all codes and locations for ICD9 Procedure Codes;
		 title2 "List of ICD 9 Procedure Codes and Count";
		 select dxcode2 into:icd9prcdrexcl_temp separated by '","'
		 from exclude1
		 where CodeType="ICD9PRCDR" and condition="&cond.";
		 
		 %if &i=1 %then %let icd9prcdrexcl=&icd9prcdrexcl_temp.;
		 %else %let icd9prcdrexcl=&icd9prcdrexcl.&sep.&icd9prcdrexcl_temp.;
		 
		 select dxcodelocation into:icd9prcdrexclloc_temp separated by '","'
		 from exclude1
		 where CodeType="ICD9PRCDR" and condition="&cond." and last;
		 
		 %if &i=1 %then %let icd9prcdrexclloc=&icd9prcdrexclloc_temp.;
		 %else %let icd9prcdrexclloc=&icd9prcdrexclloc.&sep.&icd9prcdrexclloc_temp.;
		 
		 * Pulls all codes and locations for ICD10 Procedure Codes;
		 title2 "List of ICD 10 Procedure Codes and Count";
		 select dxcode2 into:icd10prcdrexcl_temp separated by '","'
		 from exclude1
		 where CodeType="ICD10PRCDR" and condition="&cond.";
		 
		 %if &i=1 %then %let icd10prcdrexcl=&icd10prcdrexcl_temp.;
		 %else %let icd10prcdrexcl=&icd10prcdrexcl.&sep.&icd10prcdrexcl_temp.;
		 
		 select dxcodelocation into:icd10prcdrexclloc_temp separated by '","'
		 from exclude1
		 where CodeType="ICD10PRCDR" and condition="&cond." and last;
		 
		 %if &i=1 %then %let icd10prcdrexclloc=&icd10prcdrexclloc_temp.;
		 %else %let icd10prcdrexclloc=&icd10prcdrexclloc.&sep.&icd10prcdrexclloc_temp.;
		 
		%end;
		
		quit;
		
%mend;

%getcodes;

***** 2) Identify Condition dx in the medical claims data ;
%macro tagcond;	

		* Check what kinds of diagnosis/procedure codes exist in claims data set and will only
			check for kinds of diagnosis codes that exist in the data set. If there are no HCPCS codes,
			will not cycle through the HCPCS array;
		proc contents data=&claimsfile. out=contents_claims noprint; run;
		
		proc sql noprint;
		
			select name
			into :clmvars
			separated by '|'
			from contents_claims;
			
		quit;
		
		%put &icd9ndx &icd10ndx &hcpcsn &icd9nprcdr &icd10nprcdr;
		
		* Sort by id and claim_dt;
		proc sort data=&claimsfile. out=claims_s; by &id claim_dt; run;
		
		* The following data step cycles through all the conditions and outputs a data set for condition
			only keeping the id, the claim date and the claim type;	
			
		data
				%do p=1 %to &Ncondlist;
					%let condname=%scan(&condlist,&p,'|');
					
					claims_&condname.&filecnt. (keep=&id claim_dt claim_type)
				
				%end;;
			
			set claims_s;
			by &id claim_dt ;
		
				%do p=1 %to &Ncondlist;
					%let condname=%scan(&condlist,&p,'|');
					
					* setting condition diagnosis flag to 0 and condition exclude flag to 0;
					&condname.dx=0;
					&condname.excl=0;
			
				%end;
			
				* Setting up arrays based on what diagnosis & procedure codes exist in the claims data;
				
				/************************************* ICD 9 DX **************************************/
				  %if %index(&clmvars,icd9dx) %then %do;
				  
				  	array icd9dx_ [*] $ icd9dx:;
				  	
				  * Cycling through all codes for the condition and flagging if find diagnosis;
				  	do i=1 to dim(icd9dx_);
				  	
				  		* Format - removing period and left adjusting;
				  		icd9dx_[i]=trim(left(compress(icd9dx_[i],".")));
							if length(icd9dx_[i])=3 then icd9dx_[i]=cats(icd9dx_[i],"00");
							if length(icd9dx_[i])=4 then icd9dx_[i]=cats(icd9dx_[i],"0");
						
							%do p=1 %to &ncondlist;
								%let condname=%scan(&condlist,&p,'|');
								%let ccode=%scan(%bquote(&icd9dx),&p,'|');
								%let ccodeloc=%scan(%bquote(&icd9dxloc),&p,'|');
					  			
					  			%if "&ccodeloc"="ANY" %then %do;
					  				if icd9dx_[i] in("&ccode") and &condname.dx in(0,.) then &condname.dx=1;
				  				%end;
				  				%else %if "&ccodeloc"="DX1" %then %do;
				  					if i=1 and icd9dx_[i] in("&ccode") and &condname.dx in(0,.) then &condname.dx=1;
				  				%end;
				  				%else %if "&ccodeloc"="DX1 DX2" %then %do;
				  					if i in(1,2) and icd9dx_[i] in("&ccode") and &condname.dx in(0,.) then &condname.dx=1;
				  				%end;
				  		
				  		* Cycling through exclusion variables;
				  	 		%let excode=%scan(%bquote(&icd9dxexcl),&p,'|');
				  	 		%let excodeloc=%scan(%bquote(&icd9dxexclloc),&p,'|');
				  	 		
				  	 			%if "&excodeloc"="ANY" %then %do;
					  				if icd9dx_[i] in("&excode") and &condname.excl in(0,.) then &condname.excl=1;
				  				%end;
				  				%else %if "&excodeloc"="DX1" %then %do;
				  					if i=1 and icd9dx_[i] in("&excode") and &condname.excl in(0,.) then &condname.excl=1;
				  				%end;
				  				%else %if "&excodeloc"="DX1 DX2" %then %do;
				  					if i in(1,2) and icd9dx_[i] in("&excode") and &condname.excl in(0,.) then &condname.excl=1;
				  				%end;
				  				
				  		%end;
				  		
				  	end;
				  	 	
				  %end;
					
				  /************************************* ICD 10 DX **************************************/
				  %if %index(&clmvars,icd10dx) %then %do;
				  
				  	array icd10dx_ [*] $ icd10dx:;
				  	
				  	* Cycling through all codes for the condition and flagging if find diagnosis;
				  	do i=1 to dim(icd10dx_);
				  	
				  		* Format - removing period and left adjusting;
				  		icd10dx_[i]=upcase(trim(left(compress(icd10dx_[i],"."))));
							
							%do p=1 %to &ncondlist;
								%let condname=%scan(&condlist,&p,'|');
								%let ccode=%scan(%bquote(&icd10dx),&p,'|');
								%let ccodeloc=%scan(%bquote(&icd10dxloc),&p,'|');
					  			
					  			%if "&ccodeloc"="ANY" %then %do;
					  				if icd10dx_[i] in("&ccode") and &condname.dx in(0,.) then &condname.dx=1;
				  				%end;
				  				%else %if "&ccodeloc"="DX1" %then %do;
				  					if i=1 and icd10dx_[i] in("&ccode") and &condname.dx in(0,.) then &condname.dx=1;
				  				%end;
				  				%else %if "&ccodeloc"="DX1 DX2" %then %do;
				  					if i in(1,2) and icd10dx_[i] in("&ccode") and &condname.dx in(0,.) then &condname.dx=1;
				  				%end;
				  		
				  		* Cycling through exclusion variables;
				  	 		%let excode=%scan(%bquote(&icd10dxexcl),&p,'|');
				  	 		%let excodeloc=%scan(%bquote(&icd10dxexclloc),&p,'|');
				  	 		
				  	 			%if "&excodeloc"="ANY" %then %do;
					  				if icd10dx_[i] in("&excode") and &condname.excl in(0,.) then &condname.excl=1;
				  				%end;
				  				%else %if "&excodeloc"="DX1" %then %do;
				  					if i=1 and icd10dx_[i] in("&excode") and &condname.excl in(0,.) then &condname.excl=1;
				  				%end;
				  				%else %if "&excodeloc"="DX1 DX2" %then %do;
				  					if i in(1,2) and icd10dx_[i] in("&excode") and &condname.excl in(0,.) then &condname.excl=1;
				  				%end;
				  				
				  		%end;
				  		
				  	end;
				  	
				  %end;
				  
				  /************************************* HCPCS **************************************/
				  %if %index(&clmvars,hcpcs) %then %do;
				  
				  	array hcpcs_ [*] $ hcpcs:;
				  	
				  	* Cycling through all codes for the condition and flagging if find diagnosis;
				  	do i=1 to dim(hcpcs_);
				  		
				  		* Format - upcasing;
				  		hcpcs_[i]=upcase(hcpcs_[i]);
							
							%do p=1 %to &ncondlist;
								%let condname=%scan(&condlist,&p,'|');
								%let ccode=%scan(%bquote(&hcpcs),&p,'|');
								%let ccodeloc=%scan(%bquote(&hcpcsloc),&p,'|');
					  			
					  			%if "&ccodeloc"="ANY" %then %do;
					  				if hcpcs_[i] in("&ccode") and &condname.dx in(0,.) then &condname.dx=1;
				  				%end;
				  				%else %if "&ccodeloc"="DX1" %then %do;
				  					if i=1 and hcpcs_[i] in("&ccode") and &condname.dx in(0,.) then &condname.dx=1;
				  				%end;
				  				%else %if "&ccodeloc"="DX1 DX2" %then %do;
				  					if i in(1,2) and hcpcs_[i] in("&ccode") and &condname.dx in(0,.) then &condname.dx=1;
				  				%end;
				  		
				  		* Cycling through exclusion variables;
				  	 		%let excode=%scan(%bquote(&hcpcsexcl),&p,'|');
				  	 		%let excodeloc=%scan(%bquote(&hcpcsexclloc),&p,'|');
				  	 		
				  	 			%if "&excodeloc"="ANY" %then %do;
					  				if hcpcs_[i] in("&excode") and &condname.excl in(0,.) then &condname.excl=1;
				  				%end;
				  				%else %if "&excodeloc"="DX1" %then %do;
				  					if i=1 and hcpcs_[i] in("&excode") and &condname.excl in(0,.) then &condname.excl=1;
				  				%end;
				  				%else %if "&excodeloc"="DX1 DX2" %then %do;
				  					if i in(1,2) and hcpcs_[i] in("&excode") and &condname.excl in(0,.) then &condname.excl=1;
				  				%end;
				  				
				  		%end;
				  		
				  	end;
				  	
				  %end;
				  
				  /*************************** ICD 9 PROCEDURE CODES ********************************/
				  %if %index(&clmvars,icd9prcdr) %then %do;
				  
				  	array icd9prcdr_ [*] $ icd9prcdr:;
				  	
				  	* Cycling through all codes for the condition and flagging if find diagnosis;
				  	do i=1 to dim(icd9prcdr_);
				  	
				  		* Format - removing period and left adjusting;
				  		icd9prcdr_[i]=trim(left(compress(icd9prcdr_[i],".")));
							if length(icd9prcdr_[i])=3 then icd9prcdr_[i]=cats(icd9prcdr_[i],"0");
							
							%do p=1 %to &ncondlist;
								%let condname=%scan(&condlist,&p,'|');
								%let ccode=%scan(%bquote(&icd9prcdr),&p,'|');
								%let ccodeloc=%scan(%bquote(&icd9prcdrloc),&p,'|');
					  			
					  			%if "&ccodeloc"="ANY" %then %do;
					  				if icd9prcdr_[i] in("&ccode") and &condname.dx in(0,.) then &condname.dx=1;
				  				%end;
				  				%else %if "&ccodeloc"="DX1" %then %do;
				  					if i=1 and icd9prcdr_[i] in("&ccode") and &condname.dx in(0,.) then &condname.dx=1;
				  				%end;
				  				%else %if "&ccodeloc"="DX1 DX2" %then %do;
				  					if i in(1,2) and icd9prcdr_[i] in("&ccode") and &condname.dx in(0,.) then &condname.dx=1;
				  				%end;
				  		
				  		* Cycling through exclusion variables;
				  	 		%let excode=%scan(%bquote(&icd9prcdrexcl),&p,'|');
				  	 		%let excodeloc=%scan(%bquote(&icd9prcdrexclloc),&p,'|');
				  	 		
				  	 			%if "&excodeloc"="ANY" %then %do;
					  				if icd9prcdr_[i] in("&excode") and &condname.excl in(0,.) then &condname.excl=1;
				  				%end;
				  				%else %if "&excodeloc"="DX1" %then %do;
				  					if i=1 and icd9prcdr_[i] in("&excode") and &condname.excl in(0,.) then &condname.excl=1;
				  				%end;
				  				%else %if "&excodeloc"="DX1 DX2" %then %do;
				  					if i in(1,2) and icd9prcdr_[i] in("&excode") and &condname.excl in(0,.) then &condname.excl=1;
				  				%end;
				  				
				  		%end;
				  		
				  	end;
				  	
				  %end;
				  
				  
				  /*************************** ICD 10 PROCEDURE CODES ********************************/
				  %if %index(&clmvars,icd10prcdr) %then %do;
				  
				  	array icd10prcdr_ [*] $ icd10prcdr:;
				  		
				  	* Cycling through all codes for the condition and flagging if find diagnosis;
				  	do i=1 to dim(icd10prcdr_);
				  		
				  		* Format - removing period and left adjusting;
				  		icd10prcdr_[i]=upcase(icd10prcdr_[i]);
				  	
							%do p=1 %to &ncondlist;
								%let condname=%scan(&condlist,&p,'|');
								%let ccode=%scan(%bquote(&icd10prcdr),&p,'|');
								%let ccodeloc=%scan(%bquote(&icd10prcdrloc),&p,'|');
					  			
					  			%if "&ccodeloc"="ANY" %then %do;
					  				if icd10prcdr_[i] in("&ccode") and &condname.dx in(0,.) then &condname.dx=1;
				  				%end;
				  				%else %if "&ccodeloc"="DX1" %then %do;
				  					if i=1 and icd10prcdr_[i] in("&ccode") and &condname.dx in(0,.) then &condname.dx=1;
				  				%end;
				  				%else %if "&ccodeloc"="DX1 DX2" %then %do;
				  					if i in(1,2) and icd10prcdr_[i] in("&ccode") and &condname.dx in(0,.) then &condname.dx=1;
				  				%end;
				  		
				  		* Cycling through exclusion variables;
				  	 		%let excode=%scan(%bquote(&icd10prcdrexcl),&p,'|');
				  	 		%let excodeloc=%scan(%bquote(&icd10prcdrexclloc),&p,'|');
				  	 		
				  	 			%if "&excodeloc"="ANY" %then %do;
					  				if icd10prcdr_[i] in("&excode") and &condname.excl in(0,.) then &condname.excl=1;
				  				%end;
				  				%else %if "&excodeloc"="DX1" %then %do;
				  					if i=1 and icd10prcdr_[i] in("&excode") and &condname.excl in(0,.) then &condname.excl=1;
				  				%end;
				  				%else %if "&excodeloc"="DX1 DX2" %then %do;
				  					if i in(1,2) and icd10prcdr_[i] in("&excode") and &condname.excl in(0,.) then &condname.excl=1;
				  				%end;
				  				
				  		%end;
				  		
				  	end;
				  	
				  %end;
				  
				
				/*************************** Cancelling out claims if exclusion code exists ********************************/
				%do p=1 %to &Ncondlist;
					%let condname=%scan(&condlist,&p,'|');
					
					%do i=1 %to &nclmgrps;
						%let qualclms&i=%scan("&&qualclmgrps&i",&p,"|");
						%let qualnum&i=%scan(&&qualnumdx&i,&p,"|");
					%end;
		
					%do m=1 %to &nclmgrps;
						%if "&&qualclms&m" ne "" %then %let max=&m;
					%end;
			
					if &condname.excl=1 then &condname.dx=0;
					
					* Only outputting claims with diagnoses and claim types of interest;
					if &condname.dx=1 and (
							%do z=1 %to %eval(&max-1);
								find("&&qualclms&z",strip(claim_type)) or
							%end;
							find("&&qualclms&max",strip(claim_type)))then output claims_&condname.&filecnt.;
				
				%end;
			
		run;
		
%mend;

***** 3) The following macro then cycles through all of the condition data sets and loops through each month of the year,
	taking a running count of each diagnosis if it falls in the reference period and the rules for min and max days apart.
	The final counts will be compared against the rules stated in CC_desc defining how many of each type of claim
	qualifies for that person having the chronic condition in that month. If they meet the criteria, they are flagged with a 1.; 
	
%macro cc_flags;
		
* Getting information for each specific condition from the macro variable list;
%let condname=%scan(&condlist,&p,"|");
%let refmo=%scan(&refperiod,&p,"|");
%let mindays=%scan(&mindaysapart,&p,"|");
%let maxdays=%scan(&maxdaysapart,&p,"|");
%do i=1 %to &nclmgrps;
	%let qualclms&i=%scan("&&qualclmgrps&i",&p,"|");
	%let qualnum&i=%scan(&&qualnumdx&i,&p,"|");
%end;
%put &condname;
%put &refmo &mindays &maxdays;
%put &&qualclmgrps&nclmgrps &&qualclms&nclmgrps &&qualnum&nclmgrps;

* Counting the number of observations in the final condition data sets. If there are no observations,
  then creating a data set with placeholder blanks for all the necessary monthly flags;
%let dsid=%sysfunc(open(&condname));
%put &dsid;
%if &dsid %then %do;
	%let nobs=%sysfunc(attrn(&dsid,nobs));
	%let rc=%sysfunc(close(&dsid));
%end;
%put &nobs;

%if &nobs>0 %then %do;

* Getting all the claim types in the condition, e.g. IP, SNF, HHA;	
proc freq data=&condname. noprint;
	table claim_type / out=clmtypes (drop=count percent);
run;

data _null_;
	set clmtypes nobs=obs;
	do i=1 to obs;
		if _n_=i then call symputx(compress("clmtyp"||i),claim_type);
	end;
	if _n_=obs then call symputx("max_clmtyp",obs);
run;

%put &clmtyp1 &&clmtyp&max_clmtyp;

data &condname.1;
	set &condname.;
	by &id claim_dt ;
	
			if first.&id then do;
				lag_&condname.dt=.;
				first_&condname.dx=.;
			end;
			format lag_&condname.dt first_&condname.dx mmddyy10.;
			retain lag_&condname.dt first_&condname.dx;
			
			* Creating a temporary array for every condition claim type month between the min and max years;
			%do t=1 %to &max_clmtyp;	
				array &&clmtyp&t.._&condname. [&total_mo] _temporary_;
			%end;
			
		  * Creating an array for every condition month;
		  array &condname._mo [*] 
		  	%do year=&mindatayear %to &maxdatayear;
		  		&condname._&year._1-&condname._&year._12
		  	%end;;
				
			* Restting at 0 for the first record of every beneficiary;
			if first.&id then do;
				%do t=1 %to &max_clmtyp;
					do i=1 to &total_mo;
						&&clmtyp&t.._&condname.[i]=0;
						&&clmtyp&t.=.;
					end;
				%end;
			end;
			
			/* The following piece of code will look at each claim date and first identify the reference period
				 months for which the claim might qualify for the algorithm. If a claim is in 1/1/2011 and the 
				 reference period is 1 year, then the claim will start to contribute to the 12 months between
				 January 2011 and December 2011. January 2011 will be used as the start of every loop and December 2011
				 will be used as the end of every loop for which this claim will then be tested for the other 
				 requirements; the claim must be greater than specified min days apart from previous claim,
				 the claim must be less than specified max days apart from previous claim, and claim must be 
				 of specific claim type. Running counts will be taken and algorithm will produce a 1 flag 
				 for when the required number of claims are found */
				 
				* First getting difference between date and start of analytical period;
				diff=intck("month",mdy(1,1,&mindatayear),claim_dt);
				
				* Then finding the start for when this claim would fit the reference period, have to add 1 to compensate for diff;
				* Maxes with 1 so that the array will not go out of range if period start is before start of analytical period;
				start=max(1,diff+1); 
				
				* Then finding end of reference period, which is either the difference between
					the date and the start of analytical period or the max reference period so that
					the array does not go out of range;
				end=min(diff+&refmo,&total_mo);
				
				* Then in order to count, checking that the claim qualifies min and max days apart scenarios;
				if ((claim_dt-lag_&condname.dt)>=&mindays or claim_dt-lag_&condname.dt=.) then do;
					
					* Looping through each claim type;
					%do t=1 %to &max_clmtyp;
						
							/* Since we are using the lag of a claim to check for maximum days apart, a claim will not
							  be counted until if finds the second claim. If this is the first time a claim is found,
							  or if there have been a series of non-qualifying claims before this one, then the first
							  claim will not be flagged. To compensate for these scenarios, the claims described
							  above will contribute two to count for both that claim and the one prior. */
							%if &maxdays>0 %then %do;
								if claim_dt-lag_&condname.dt>&maxdays then add2=1;
								lagadd2=lag(add2);
								if first.&id then lagadd2=.;
								if lagadd2=1 and .<(claim_dt-lag_&condname.dt)<=&maxdays then do mo=start to end;
									if claim_type="&&clmtyp&t" then &&clmtyp&t.._&condname.[mo]+2; 
								end;
								else if .<(claim_dt-lag_&condname.dt)<=&maxdays then do mo=start to end;
									if claim_type="&&clmtyp&t" then &&clmtyp&t.._&condname.[mo]+1; 
								end;
							%end;
							%else %do;
								do mo=start to end;
									if claim_type="&&clmtyp&t" then &&clmtyp&t.._&condname.[mo]+1;
								end;
							%end;
					%end;
					
					* Creating lag of claim for comparison to previous claim;
					lag_&condname.dt=claim_dt;
				
				end;
					
				***** Check to see if the person qualifies for condition in that month;
				
				/* Loop through each month and pull information from temporary array about number of 
				  claims by claim type. For understanding, below code outside of macro may look like
				  this:
				  * Macro variables set:
				  	max=2;
				  	qualclms1=IP,SNF,HHA
				  	qualnum1=1
				  	qualclms2=OP,CAR
				  	qualnum2=2;
				  
				  do mo=1 to 144;
				  	IP=IP_ATF[mo];
				  	OP=OP_ATF[mo];
				  	SNF=SNF_ATF[mo];
				  	HHA=HHA_ATF[mo];
				  	CAR=CAR_ATF[mo];
				  
				 		if sum(IP,SNF,HHA)>=1 or sum(OP,CAR)>=2 then do;
				  		ATF_mo[mo]=1;
				  		if first_ATFdx=1 then first_ATFdx=claim_dt;
				  	end;
				  end; */
				  		
				do mo=1 to &total_mo;			
					%do t=1 %to &max_clmtyp;
						&&clmtyp&t=&&clmtyp&t.._&condname.[mo];
					%end;
					
					%do m=1 %to &nclmgrps;
						%if "&&qualclms&m" ne "" %then %let max=&m;
					%end;
					
					if 
						%do z=1 %to %eval(&max-1);
							sum(&&qualclms&z)>=&&qualnum&z or 
						%end;
					sum(&&qualclms&max)>=&&qualnum&max then do;
						&condname._mo[mo]=1;
						if first_&condname.dx=. then first_&condname.dx=claim_dt; 
					end;
				end;
				
		***** Keeping last record for each patient;
		if last.&id;
		
		keep &id. first_&condname.dx %do yr=&maxofminyears. %to &minofmaxyears.; &condname._&yr.: %end;;

		
run;

%end;
%else %do;
		data &condname.1;
			set &condname;
			first_&condname.dx=.;
			%do yr=&maxofminyears. %to &minofmaxyears.;
				%do mo=1 %to 12;
					&condname._&yr._&mo=0;
				%end;
			%end;
			
			keep &id. first_&condname.dx %do yr=&maxofminyears. %to &minofmaxyears.; &condname._&yr.: %end;;

		run;
%end;
%mend;

***** 4) Merge to enrollment;
%macro enrollment;
	
***** Merging together all of the condition data sets and splitting it out into yearly data sets,
			keeping only monthly variables for that year;
data 
	%do yr=&maxofminyears. %to &minofmaxyears.;
		chronic_conditions_&yr (keep=&id year
		
		%do i=1 %to &ncondlist;
			%let condname=%scan(&condlist,&i,'|');
			
			first_&condname.dx
			&condname._&yr:
		
		%end;
		
		rename=(
			%do i=1 %to &ncondlist;
				%let condname=%scan(&condlist,&i,'|');
				
				%do j=1 %to 12;
					&condname._&yr._&j=a_&condname._mo&j
				%end;
				
			%end;)
				
		)
	%end;;
	
	format &id year;
	
	merge 
		%do i=1 %to &ncondlist;
			%let condname=%scan(&condlist,&i,'|');
			&condname.1
		%end;; 
		
	by &id;
	
	%do yr=&maxofminyears. %to &minofmaxyears.;
	year=&yr;
	output chronic_conditions_&yr;
	%end;	
	
run;

%do yr=&maxofminyears. %to &minofmaxyears.;

	data &claims_out_prefix.&yr;
		merge chronic_conditions_&yr (in=a) &enr_prefix.&yr (in=b);
		by &id;
		if b;
		
		* Only creating flag for periods where we have full data. E.g. if the reference period
			is 3 years, then we only start to have the full enrollment period in 2005;
			
		%do i=1 %to &ncondlist;
			%let condname=%scan(&condlist,&i,'|');
			%let refmonth=%scan(&refperiod,&i,'|');
			
			%do j=1 %to 9;
				if intnx('month',mdy(&j,1,year),-&refmonth+1)<mdy(1,1,&mindatayear) then &condname._mo&j=.I;
				else if a_&condname._mo&j=1 and &enr_var._pre_0&j>=&refmonth then &condname._mo&j=3;
				else if &enr_var._pre_0&j>=&refmonth then &condname._mo&j=2;
				else if a_&condname._mo&j=1 then &condname._mo&j=1;
				else &condname._mo&j=0;
			%end;
			%do j=10 %to 12;
				if intnx('month',mdy(&j,1,year),-&refmonth+1)<mdy(1,1,&mindatayear) then &condname._mo&j=.I;
				else if a_&condname._mo&j=1 and &enr_var._pre_&j>=&refmonth then &condname._mo&j=3;
				else if &enr_var._pre_&j>=&refmonth then &condname._mo&j=2;
				else if a_&condname._mo&j=1 then &condname._mo&j=1;
				else &condname._mo&j=0;
			%end;

		%end;
		
		drop a_:;
	
	run;
	
%end;

%mend;

%overcond;

			
				
			

