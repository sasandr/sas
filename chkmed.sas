%macro chkmed(flag=);
  data copdmed;
    set anadata.adcm;
    where saffl='Y' and copdfl='Y' and &flag='Y';
  run;
  
  data copdexmed;
    set anadata.adcm;
    where saffl='Y' and copdexfl='Y' and &flag='Y';
  run;
  
  proc sort data=copdmed(keep=usubjid) nodupkey; by usubjid; run;
    
  proc sort data=copdexmed(keep=usubjid) nodupkey; by usubjid; run;
    
  data percent;
    merge anadata.adsl(where=(saffl='Y'))
          copdmed(in=a)
          copdexmed (in=b);
    by    usubjid;
    
    if    a then copd='Y'; else copd='N';
    
    if    b then copdex='Y'; else copdex='N';
  run;
  
  title "Check &flag=Y";
  proc freq data=percent;
    tables copd copdex;
  run;
  
%mend chkmed;

%chkmed(flag=cphas2fl);
%chkmed(flag=cphas3fl);
