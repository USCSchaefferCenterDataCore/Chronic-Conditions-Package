/*********************************************************************************************/
TITLE1 'Chronic Conditions Macro';

* AUTHOR: Patricia Ferido;

* DATE: 3/26/2018;

* PURPOSE: - Read In Customized CSV Input files that determine conditions and algorithms, and list
						 all codes of interest
					 - Check that all input files and claims data are formatted correctly 
					 - Please see document titled "For Users - Chronic Conditions Macro Documentation"
					   before running any programs;

* INPUT: Claims Data, CSV files CC_codes, CC_desc, CC_exclude;
* OUTPUT: SAS files CC_codes, CC_desc, CC_exclude;

options compress=yes nocenter ls=150 ps=200 errors=5 errorabend errorcheck=strict mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

***** Read in Input CSV Files ;

* CC Codes;
data cc_codes;
	infile "&projhome./csv_input/CC_Codes.csv" dlm="2c"x dsd lrecl=32767 missover firstobs=2;
	informat
		Condition $10.
		CodeType $10.
		DxCodeLocation $8.
		DxCode $10.;
	format
		Condition $10.
		CodeType $10.
		DxCodeLocation $8.
		DxCode $10.;
	input
		Condition $
		CodeType $
		DxCodeLocation $
		DxCode $;
run;

* CC Desc;
proc import datafile="&projhome./csv_input/CC_Desc.csv" out=cc_desc dbms=dlm;
	delimiter=",";
	getnames=yes;
	guessingrows=max;
run;

* CC Exclude;
data cc_exclude;
	infile "&projhome./csv_input/CC_Exclude.csv" dlm="2c"x dsd lrecl=32767 missover firstobs=2;
	informat
		Condition $10.
		CodeType	$10.
		DxCode $10.
		DxCodeLocation $8.;
	format
		Condition $10.
		CodeType	$10.
		DxCode $10.
		DxCodeLocation $8.;
	input
		Condition $
		CodeType	$
		DxCode $
		DxCodeLocation $;
run;

***** Get contents;

proc contents data=cc_codes out=contents_cc_codes noprint; run;
proc contents data=cc_desc out=contents_cc_desc noprint; run;
proc contents data=cc_exclude out=contents_cc_exclude noprint; run;

***** Standardize and check for values that shouldn't be there, if there are errors, the errors
			will print to log and the program will terminate;

* Standardizing CC_Codes and checking for valid inputs;
data cc_codes;
	set cc_codes;
	condition=upcase(condition);
	codetype=upcase(codetype);
	dxcodelocation=upcase(dxcodelocation);
	if codetype not in("ICD9DX","ICD10DX","ICD9PRCDR","ICD10PRCDR","HCPCS") then do;
		put "ERROR: INVALID CC_Codes Codetype " codetype=/;
		abort abend;
	end;
	if dxcodelocation not in("ANY","DX1","DX1 DX2") then do;
		put "ERROR: INVALID CC_Codes DxCodeLocation " dxcodelocation=/;
		abort abend;
	end;
	if codetype="ICD10PRCDR" and length(dxcode) ne 7 then do;
		put "ERROR: INVALID ICD10PRCDR CODE " dxcode=/;
		abort abend;
	end;
	if codetype="HCPCS" and length(dxcode) ne 5 then do;
		put "ERROR: INVALID HCPCS CODE " dxcode=/;
		abort abend;
	end;
run;

* Standardizing CC_Exclude and checking for valid inputs;
data cc_exclude;
	set cc_exclude;
	condition=upcase(condition);
	codetype=upcase(codetype);
	dxcodelocation=upcase(dxcodelocation);
	if codetype not in("ICD9DX","ICD10DX","ICD9PRCDR","ICD10PRCDR","HCPCS") then do;
		put "ERROR: INVALID CC_Codes Codetype " codetype=/;
		abort abend;
	end;
	if dxcodelocation not in("ANY","DX1","DX1 DX2") then do;
		put "ERROR: INVALID CC_Codes DxCodeLocation " dxcodelocation=/;
		abort abend;
	end;
	if codetype="ICD10PRCDR" and length(dxcode) ne 7 then do;
		put "ERROR: INVALID ICD10PRCDR CODE " dxcode=/;
		abort abend;
	end;
	if codetype="HCPCS" and length(dxcode) ne 5 then do;
		put "ERROR: INVALID HCPCS CODE " dxcode=/;
		abort abend;
	end;
run;

* Standardizing CC_Desc and checking for valid inputs;
data _null_;
	set contents_cc_desc;
	if name="ref_months" and type=2 then do;
		put "ERROR: ALPHABETIC VALUE IN ref_months FOR CC_Desc";
		abort abend;
	end;
	if find(name,'num_dx') and type=2 then do;
		put "ERROR: ALPHABETIC VALUE IN num_dx FOR CC_Desc"; 
		abort abend;
	end;
	if name="min_days_apart" and type=2 then do;
		put "ERROR: ALPHABETIC VALUE IN min_days_apart FOR CC_Desc";
		abort abend;
	end;
run;

data cc_desc;
	set cc_desc;
	condition=upcase(condition);
	
	* Making max_days_apart numeric if it isn't already;
	max_days_apart1=max_days_apart*1;

	array claim_type [*] claim_type:;
	array num_dx [*] num_dx:;
	
	* Upcasing claim_type;
	do i=1 to dim(claim_type);
		claim_type[i]=upcase(claim_type[i]);
	end;
	
	* Checks;
	do i=1 to dim(claim_type);
		if claim_type[i] ne "" and num_dx[i]=. then do;
			put "ERROR: MISSING num_dx FOR CC_Desc";
			abort abend;
		end;
		if claim_type[i]="" and num_dx[i] ne . then do;
			put "ERROR: MISSING claim_type FOR CC_Desc";
			abort abend;
		end;
	end;
	if min_days_apart<=0 then do;
		 put "ERROR: MISSING or NEGATIVE min_days_apart in CC_Desc";
		 abort abend;
	end;
	if ref_months<=0 then do;
		put "ERROR: MISSING or NEGATIVE ref_months in CC_Desc";
		abort abend;
	end;
	drop max_days_apart;
	rename max_days_apart1=max_days_apart;
run;
		
* Checking that all condition codes are the same between the three input files;
proc freq data=cc_codes noprint;
	table condition / out=condition_codes; 
run;

proc freq data=cc_desc noprint;
	table condition / out=condition_desc;
run;

proc freq data=cc_exclude noprint;
	table condition / out=condition_exclude;
run;

data condition_ck;
	length condition $10.;
	merge condition_desc (in=a) condition_codes (in=b) condition_exclude (in=c);
	by condition;
	desc=a;
	codes=b;
	exclude=c;
run;

proc freq data=condition_ck noprint;
	table desc*codes*exclude / out=freq_condition_ck;
run;

data _null_;
	set freq_condition_ck;
	
	if desc=1 and codes=0 then do;
		put "ERROR: THERE ARE CONDITIONS IN CC_Desc BUT NOT IN CC_Codes";
		abort abend;
	end;
	if codes=1 and desc=0 then do;
		put "ERROR: THERER ARE CONDITIONS IN CC_Codes BUT NOT IN CC_Desc";
		abort abend;
	end;
	if exclude=1 and max(desc,codes) ne 1 then do;
		put "ERROR: THERE ARE CONDITIONS IN CC_Exclude not in CC_Desc or CC_Codes";
		abort abend;
	end;
	
run;

***** Create permanents - will only get to this step if there were no errors above;
data _ccproj.cc_codes&custom_suffix.;
	set cc_codes;
run;

data _ccproj.cc_desc&custom_suffix.;
	set cc_desc;
run;

data _ccproj.cc_exclude&custom_suffix.;
	set cc_exclude;
run;