%let debug=N;

proc format;
  invalue sev
      'Intermittent'         = 1
      'Mild Persistent'      = 2
      'Moderate Persistent'  = 3;

  value $vlabel
      'COPDSEV' = 'Asthma Severity n (%)'
      'COPDDUR' = 'Duration of Asthma (yrs)'

run;

proc freq data=anadata.adsl;
  tables astmsevn*asthmsev/list missing;
run;

%macro gtable;

  data adsl01;
    set anadata.adsl (keep=usubjid mitt0: mittfl ittfl saffl trt0: asdur ASTHMSEV ASTMSEVN randfl);
    where &pop='Y';  
    %assigntrt;
    drop trt0:;
  run;
  
  data adsl99;
    set anadata.adsl (keep=usubjid mitt0: mittfl ittfl saffl trt0: asdur ASTHMSEV ASTMSEVN randfl);
    where &pop='Y';    
    trtn = 99;
  run;
  
  data adsl;
    set adsl01
        adsl99;
  run;
  
  proc sort data=adsl nodupkey; by usubjid trtn; run;

  *** Get column header;
  %trtn(popdsn=adsl);

  data summary;
    set adsl;
  run;

  *** Obtain summary statistics for continuous variabls;
  %gset(meanfmt=6.1, sdfmt=6.1, medfmt=6.1, minfmt=6.1, maxfmt=6.1, psign=%str());
  %statcon(indsn=summary, var=asdur);

  *** Obtain summary statistics for categorical variables;
  %statcat(indsn=summary,  var=asthmsev, varfmt=sev);

  data all;
    set asdur
        asthmsev;

    length parameter $ 50;

    parameter = put(var, vlabel.);

    array cvar  [*] _character_;

    do i=1 to dim(cvar);
       cvar[i]=strip(cvar[i]);
    end;

  run;
  
  data primds;
    set qcdata.&qcoutput;
    if ^missing(_break_) or ord=0 then delete;
    keep trt1-trt7 PARMTXT;
  run;
  
  proc print; run;
    
  %compds(table=&tabnum);
  %compds(valdata=all, table=&tabnum, var= statc c1 c2 c3 c4 c5 c6 c7 , compress='@' ); 
 
  proc datasets library=work mtype=data nodetails nolist;
    delete adsl summary all primds;
  quit;

%mend gtable;

/***   Table 1.6.1 - MITT Population   ***/
%let trtvar=trtn;
%let pop=mittfl;
%let qcoutput=t010601;
%let tabnum  = Table 1.6.1;

title "Table 1.6.1 - MITT Population";
%gtable;

/***   Table 1.6.2 - ITT Population   ***/
%let trtvar=trtn;
%let pop=ittfl;
%let qcoutput=t010602;
%let tabnum = Table 1.6.2;
title "Table 1.6.2 - ITT Population";
%gtable;

/***   Table 1.6.3 - Safety Population   ***/
%let trtvar=trtn;
%let pop=saffl;
%let qcoutput=t010603;
%let tabnum = Table 1.6.3;

title "Table 1.6.3 - Safety Population";
%gtable;