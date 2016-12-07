*** PARAM ***; 
proc freq data=tabdata.lb noprint;
  tables lbcat * lbtestcd * lbtest * lbstresu / list missing out=unit (drop=count percent);
run;

proc sort data=unit;
  by lbcat lbtestcd lbtest descending lbstresu;
run;

data all;
  set unit;
  
  length param $ 100;
  
  by  lbcat lbtestcd lbtest descending lbstresu;
  retain count;
  if  first.lbtestcd then count=0;
  count+1;
  
  if ^missing(lbstresu) then param = catx(' ', lbtest, cats('(', lbstresu, ')'));
  else if missing(lbstresu) then param=strip(lbtest);
  
  if missing(lbstresu) and count>1 then delete;
  
run;

filename csv "adlb_param.csv";

data _null_;
  set all;
  file csv dlm=',';
  
  if _n_=1 then put "LBCAT" ","
                    "PARAMCD" ","
                    "PARAM" ",";
                    
  put (lbcat lbtestcd param) (+0);
run;
