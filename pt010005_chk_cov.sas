data cov0;
input efficacy $ 1-51
      covlist_orig  $ 52 - 110;
 covlist_orig=compress(covlist_orig);
datalines;      
Rate of COPD Exacerbation	                          FEV1POST, LBASEEOS, BASEEXAC, REGION, ICSUSE
Time to first COPD Exacerbation	                    FEV1POST, LBASEEOS, BASEEXAC, REGION, ICSUSE
TDI Focal Score	                                    AVISIT, REGION, ICSUSE, LBASEEOS, BASE, FEV1POST, PBREV
TDI Responder	                                      BASE, LBASEEOS, FEV1POST, PBREV, ICSUSE
Rescue Ventolin Use	                                AVISIT, ICSUSE, FEV1POST, BASE, LBASEEOS, PBREV
SGRQ Total Score	                                  AVISIT, REGION, ICSUSE, LBASEEOS, BASE, FEV1POST, PBREV
SGRQ Responder	                                    BASE, LBASEEOS, FEV1POST, PBREV, ICSUSE
EXACT Total Score	                                  AVISIT, REGION, ICSUSE, LBASEEOS, BASE, FEV1POST, PBREV
Time to Death	                                      FEV1POST, AGE
Time to Treatment Failure	                          FEV1POST, BASEEXAC, LBASEEOS, REGION, ICSUSE
Percentage of Days with No Rescue Ventolin HFA Use	BASEMED, LBASEEOS, FEV1POST, PBREV, ICSUSE
EQ-5D-5L VAS Score                                  AVISIT, REGION, ICSUSE, LBASEEOS, BASE, FEV1POST, PBREV
Morning Pre-dose Trough FEV1	                      BASE, LBASEEOS, PBREV, ICSUSE
FEV1 AUC0-4 	                                      BASE, LBASEEOS, PBREV, ICSUSE
;
run;

data cov1 (drop=i);
  set cov0;
  
  analysis=_n_;

  i=1;
  
  do while(scan(covlist_orig, i, ',') ^= ' ');
     cov = strip(scan(covlist_orig, i, ','));
     
     if cov in ('BASEEXAC' 'ICSUSE' 'REGION') then type=2;
     else type=1;
     
     i+1;
     output;
  end;
run;

proc sort data=cov1;
  by analysis type cov;
run;

proc freq data=cov1;
  tables cov;
run;

data covlist;
  set cov1;
  by  analysis;
  length covlist $ 100;
  
  retain covlist;
  
  if  first.analysis then call missing(covlist);
  covlist=catx(', ', covlist, cov);
  
  if last.analysis;
run;

proc print data=covlist;
  var analysis covlist;
run;

proc freq data=covlist; 
  tables covlist*analysis*efficacy/list missing nopercent;
run;    
