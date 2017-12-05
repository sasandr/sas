/**SOH***********************************************************************************
Study #:                        PT010006 Dryrun2
Program Name:                   checkrev1.sas
Purpose:                        To check reversibility derived from FEV1 with FEV1REV
Original Author:                Chelsea Chen
Date Initiated:                 01DEC2017
Responsibility Taken Over by:   
Date Last Modified:             
Reason for Modification:        
Input data:                     
Output data:                    
External macro referenced:      
SAS Version:                    V9.3
Program Version #:              1.0
***EOH**********************************************************************************/

%let id=PT010006-004016;

proc print data=tabdata.re;
  where usubjid="&id" and visitnum in (2) and retestcd in ('FEV1' 'FEV1REV');
  var usubjid retestcd visit retpt restresn redtc rerftdtc;
run;

data re;
  set tabdata.re (keep=usubjid retestcd visitnum restresn redtc retpt retptnum);
  where visitnum in (2, 3) and retestcd in ('FEV1' 'FEV1REV' 'FEV1REVM');
  
  format redt yymmdd10.;
  redt = datepart(input(redtc, E8601DT.));

run;

*** Reversibility to Ventolin (REV2V);
data rev1;
  set re;
  where retestcd in ('FEV1') and visitnum in (2,3) and retptnum in (-1, -0.5, 0.5);
  
  length tpt $ 4;
  
  if retptnum in (-1, -0.5) then tpt='PRE';
  else if retptnum in (0.5) then tpt='POST';
run;

proc sort data=rev1; by usubjid visitnum redt retestcd retptnum descending restresn; run;

*** For each test day, take all average of all pre-B values;  
proc means data=rev1 noprint nway;
  where tpt='PRE';
  var restresn;
  class usubjid visitnum redt;
  output out=rev2_pre mean=pre;
run;

*** For each test day, take max of post-B values;  
proc means data=rev1 noprint nway;
  where tpt='POST';
  var restresn;
  class usubjid visitnum redt;
  output out=rev2_post max=post;
run;

data rev3;
  merge rev2_pre
        rev2_post;
  by    usubjid visitnum redt;
  
  fev1revp = 100*(post-pre)/pre;
  fev1revm = 1000*(post-pre);  
run;

*** If multiple records for a visit, take the one with max FEV1 value;
proc sort data=rev3;
  by usubjid visitnum post;
run;

data rev4;
  set rev3;
  by  usubjid visitnum post;
  
  if  last.visitnum;
   
  if fev1revp>= 12 and fev1revm>=200 then copdrev='Y';
  else if ^missing(fev1revm) then copdrev='N';
  
  keep usubjid fev1revp fev1revm visitnum copdrev;
run;

data revall;
  merge rev4 (where=(visitnum=2) rename=(fev1revp=pvrev fev1revm=vrevm) keep=visitnum usubjid fev1: copdrev)
        rev4 (where=(visitnum=3) rename=(fev1revp=parev fev1revm=arevm) keep=visitnum usubjid fev1:);
  by    usubjid;
  
  drop visitnum;
run;

proc print data=revall;
  where usubjid="&id";
run;

*** Reversibility to Ventolin (REV2V);
data fev1rev;
  set re;
  where retestcd in ('FEV1', 'FEV1REV', 'FEV1REVM') and visitnum=2 and retptnum=0.5;
run;

proc sort data=fev1rev nodupkey; by usubjid visitnum redtc retestcd; run;
  
proc transpose data=fev1rev out=t_rev (drop=_:);
  var restresn;
  by  usubjid visitnum redtc;
  id  retestcd;
run;

proc sort data=t_rev;
  by usubjid visitnum fev1;
run;

proc print data=t_rev;
  where usubjid="&id";
run;

data rev2v;
  set   t_rev;
  by    usubjid visitnum;

  if    last.visitnum;
    
  if FEV1REV >= 12 and FEV1REVm>=200 then copdrev='Y';
  else if ^missing(fev1revm) then copdrev='N';
  
  rename fev1rev = pvrev;
  
  keep usubjid fev1rev copdrev fev1revm;
run;

proc compare data=revall comp=rev2v listall;
  where ^missing(pvrev);
  var pvrev     vrevm;
  with pvrev    fev1revm;
  id  usubjid   ;
run;
