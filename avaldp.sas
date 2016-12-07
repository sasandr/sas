*** AVALDP ***;
proc freq data=rawdata.labdata;
  tables lbcat * lbscat * lbtestcd / list missing;
run;

data lb;
  set tabdata.lb (keep=lbtestcd lbcat lbtest lborres: lbstres:);
  
  if indexc(lborres, '><+')>0 then spchar ='Y';
  
  length sigvar $ 100;
  
  sigvar = compress(lbstresc, '><+');
  
  resultn = input(sigvar, ?? best.);
  
  siglenvar = length(compress(sigvar));

  if index(sigvar,'.')
  then sigdecvar = length(sigvar) - index(sigvar,'.');
  else sigdecvar = 0;  
run;

proc freq data=lb noprint;
  where ^missing(resultn);
  tables lbcat * lbtestcd * lbtest * sigdecvar / list out=sigdec;
run;

proc sort data=sigdec;
  by lbcat lbtestcd count sigdecvar;
run;

data sigdec;
  set sigdec;
  by  lbcat lbtestcd count sigdecvar;
  
  if  last.lbtestcd;
run;

proc sort data=sigdec;
  by lbcat sigdecvar;
run;

filename csv "adlb_avaldp.csv";

data _null_;
  set sigdec;
  file csv dlm=',';
  
  if _n_=1 then put "LBCAT" ","
                    "LBTESTCD" ","
                    "LBTEST" ","
                    "AVALDP";
                    
  put (lbcat lbtestcd lbtest sigdecvar) (+0);
run;
