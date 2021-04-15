/*********************************************************************************************/
TITLE1 'Chronic Conditions Macro';

* AUTHOR: Patricia Ferido;

* DATE: 12/8/2020;

* PURPOSE: Establish project folders and macro variables for project, all variables following the
	%let statements below need to be changed;

options compress=yes nocenter ls=150 ps=200 errors=5 errorabend errorcheck=strict mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

***** Run all the macro programs based on macro function inputs;

%macro idcond(projhome=,id=,minyear=,maxyear=,claims_data=,create_enr=,create_enr_shape=,create_enr_filein=,enr_prefix=,enr_var=,claims_out_prefix=,
	custom_algorithm=N,custom_suffix=_custom,custom_cond=);
	
	* Macro variable checks;
	data _null_;
	 	if "&projhome"="" then do;
	 		put "ERROR: PUT THE PROJECT FILEPATH WHERE THE MACRO IS BEING RUN. CANNOT BE SOURCE FOLDER";
	 		abort;
	 	end;
	 	if "&claims_data"="" then do;
	 		put "ERROR: PUT THE NAME OF THE CLAIMS DATA SET ABOVE";
	 		abort;
	 	end;
	 	if "&id"="" then do;
	 		put "ERROR: PUT THE NAME OF THE UNIQUE PATIENT IDENTIFIER";
	 		abort;
	 	end;
	 	if "&minyear"="" then do;
	 		put "ERROR: PUT MIN YEAR";
	 	end;
	 	if "&maxyear"="" then do;
	 		put "ERROR: PUT MAX YEAR";
	 	end;
	 	if "&create_enr" not in("Y","N") then do;
	 		put "ERROR: INVALID VALUE FOR CREATE_ENR";
	 		abort;
	 	end;
	 	if "&create_enr_shape" not in("","A","P") then do;
	 		put "ERROR: INVALID VALUE FOR CREATE_ENR_SHAPE";
	 		abort;
	 	end;
	  if "&enr_prefix"="" then do;
	 		put "ERROR: PUT THE PREFIX FOR THE ENROLLMENT FILES IN ENR_PREFIX ABOVE";
	 		abort;
	 	end;
	  if "&enr_var"="" then do;
	 		put "ERROR: PUT THE ENROLLMENT VARIABLE IN THE ENROLLMENT FILES IN ENR ABOVE";
	 		abort;
	 	end;
	  if "&claims_out_prefix"="" then do;
	 		put "ERROR: PUT CLAIMS_OUT_PREFIX";
	 		abort;
	 	end;
	 	IF "&custom_algorithm" not in("Y","N") then do;
	 		put "ERROR: INVALID VALUE FOR CUSTOM_ALGORITHM";
	 		abort;
	 	end;
	run;
	
	* checking for libref in data set names;
	data _null_;
		if find("&claims_data",".")=0 then do;
			put "WARNING: NO LIBREF FOR CLAIMS INPUT DATA";
		end;
		if find("&claims_out_prefix",".")=0 then do;
			put "WARNING: NO LIBREF FOR CLAIMS OUTPUT DATA";
		end;
		if find("&enr_prefix",".")=0 then do;
			put "WARNING: NO LIBREF FOR ENROLLMENT INPUT DATA";
		end;
	run;
	
	libname _ccproj "&projhome.//data";;

	%if "&CUSTOM_ALGORITHM."="Y" %then %do;
		
		%include "readin_input_files.sas";
		
		* create temporary data to be used in the rest of the program and to check against the custom condition list;
		data cc_codes;
			set _ccproj.cc_codes&custom_suffix.;
		run;
		
		data cc_exclude;
			set _ccproj.cc_exclude&custom_suffix.;
		run;
		
		data cc_desc;
			set _ccproj.cc_desc&custom_suffix.;
		run;
	%end;

	%if "&CUSTOM_ALGORITHM."="N" %then %do;
		
		* create temporary data to be used in the rest of the program and to check against the custom condition list;
		data cc_codes;
			set _ccproj.cc_codes_original;
		run;
		
		data cc_exclude;
			set _ccproj.cc_exclude_original;
		run;
		
		data cc_desc;
			set _ccproj.cc_desc_original;
		run;
		
	%end;

	* checking against the list of custom conditions;
	%if "&custom_cond" ne "" %then %do;
		data customcond;
			format condition $10.;
			condlist="&custom_cond.";
			ncond=countw(condlist);
			do i=1 to ncond;
				condition=scan(condlist,i," ");
				output;
			end;
		run;
		
		proc sort data=customcond; by condition; run;
		
		proc sort data=cc_desc; by condition; run;
		
		data custom_cond_ck;
			merge cc_desc (in=a keep=condition) customcond (in=b);
			by condition;
			if b=1 and a=0 then do;
				put "ERROR: THERE ARE CONDITIONS LISTED IN COND THAT ARE NOT SPECIFIED IN ALGORITHM e.g. " condition=/;
				abort abend;
			end;
		run;
		
		* if no errors then limiting to conditions in the list;
		proc sort data=cc_exclude; by condition; run;
		proc sort data=cc_codes; by condition; run;
			
		data cc_desc;
			merge cc_desc (in=a) customcond (in=b keep=condition);
			by condition;
			if a and b;
		run;
		
		data cc_exclude;
			merge cc_exclude (in=a) customcond (in=b keep=condition);
			by condition;
			if a and b;
		run;
		
		data cc_codes;
			merge cc_codes (in=a) customcond (in=b keep=condition);
			by condition;
			if a and b;
		run;
		
	%end;
	
	***** Check Input Claims Data Sets;
	%macro ckinputclms;

	%let v=1;
	%let clms=%scan("&claims_data",&v," ");

		%do %while (%length(&clms)>0);
			proc contents data=&clms out=contents_claim noprint; run;
			
			* Check that there is a claim date variables and claim type variable
				Check that all the diagnosis codes are named
				Check that all other variables are dropped;
			
			data contents_claim1;
				set contents_claim end=_end;
				if upcase(name)=upcase("&id") then do; id=1; id1+1; end;
				else if name="claim_dt" then do; 
					clmdt=1; 
					clmdt1+1; 
					if type=2 then do; put "ERROR: CONVERT CLAIM_DT TO DATE VARIABLE"; abort; end;
				end;
				else if name="claim_type" then do; clmtype=1; clmtype1+1; end;
				else if find(name,"icd9dx") then do; icd9dx=1; icd9dx1+1; end;
				else if find(name,"icd10dx") then do; icd10dx=1; icd10dx1+1; end;
				else if find(name,"hcpcs") then do; hcpcs=1; hcpcs1+1; end;
				else if find(name,"icd9prcdr") then do; icd9prcdr=1; icd9prcdr1+1; end;
				else if find(name,"icd10prcdr") then do; icd10prcdr=1; icd10prcdr1+1; end;
				else do;
					put "ERROR: POTENTIALLY EXTRANEOUS OR MISSPELLED VARIABLE. NEEDS REVIEW " name=/;
					abort;
				end;
				
				if _end then do;
					if id1=0 then do; put "ERROR: NO ID VARIABLE"; abort abend; end;
					if clmdt1=0 then do; put "ERROR: NO CLAIM DATE VARIABLE"; abort abend; end;
					if clmtype1=0 then do; put "ERROR: NO CLAIM TYPE VARIABLE"; abort abend; end;
					if max(icd9dx1,icd10dx1,hcpcs1,icd9prcdr1,icd10prcdr1) in(0,.) then do; put "ERROR: NO DIAGNOSIS OR PROCEDURE CODE VARIABLES"; abort abend; end;
				end;
			run;

		%let v=%eval(&v+1);
		%let clms=%scan("&claims_data",&v," ");
		
		%end;
		
				***** Check and run enrollment files;
		%if "&CREATE_ENR"="Y" %then %do;
			
			data _null_;
				if "&create_enr_shape" not in("A","P") then do;
					put "ERROR: CREATE ENROLLMENT FILES MARKED AS Y, BUT INVALID CREATE_ENR_SHAPE VALUE. MUST BE 'A' OR 'P'";
					abort abend;
				end;
				if "&create_enr_filein"="" then do;
					put "ERROR: CREATE ENROLLMENT FILES MARKED AS Y, BUT NO CREATE_ENR_FILEIN SPECIFIED";
					abort abend;
				end;
			run;
				
			%include "contenr.sas";
			
			%contenr(begyr=&minyear.,endyr=&maxyear.,shape=&create_enr_shape,filein=&create_enr_filein.,fileout=&enr_prefix,id=&id,var=&enr_var.);
	
		%end;
		
	%mend;

	%ckinputclms;

	* Check that all the claim types match the claim types CC_desc;
	data claim_types;
		set cc_desc;
		array clmtyp [*] claim_type:;
		do i=1 to dim(clmtyp);
			if clmtyp[i] ne "" then do; 
				claim_type=clmtyp[i];
				output;
			end;
		end;
		countw=countw(claim_type);
	run;
		
	proc sql noprint;
		select max(countw)
		into :type_max
		from claim_types;
	quit;

	data claim_types1;
		set claim_types;
		do i=1 to countw(claim_type);
			 type=scan(claim_type,i);
			output;
		end;
	run;

	proc freq data=claim_types1 noprint;
		table type / out=cc_desc_clmtyps;
	run;

	%macro ckclmtypes;

	%let v=1;
	%let clms=%scan("&claims_data",&v," ");

		%do %while (%length(&clms)>0);
			
			proc freq data=&clms noprint;
				table claim_type / out=clms_data_clmtyps (rename=claim_type=type);
			run;
			
			data clm_ck;
				merge cc_desc_clmtyps (in=a) clms_data_clmtyps (in=b);
				by type;
				desc=a;
				clms=b;
			run;
		
			data _null_;
				set clm_ck;
				if clms=1 and desc=0 then do;
					put "ERROR: CLAIM TYPE IN &CLMS NOT IN CC_DESC" type=/;
					abort abend;
				end;
				if desc=1 and clms=0 then do;
					put "WARNING: CLAIM TYPE IN CC_DESC NOT FOUND IN &CLMS" type=/;
				end;
			run;
			
		%let v=%eval(&v+1);
		%let clms=%scan("&claims_data",&v," ");

		%end;

	%mend;

	%ckclmtypes;

	%put "SUCCESSFUL RUN. AFTER LOG IS CLEARED OF WARNINGS AND ERRORS, READY FOR 3_IDENTIFY_CONDITIONS.SAS";

	%include "identify_conditions.sas";
	

%mend;






	
	