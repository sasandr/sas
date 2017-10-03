libname rawdata "/data/sasdata/client_04/pt003014/data/rawdata/";

proc freq data=rawdata.spiro;
  tables sptest;
  where ^missing(SPORRESC);
run;

proc freq data=rawdata.spiro;
  tables sptest * visittpt / list missing nopercent nocum;
  where ^missing(SPORRESC);
run;

proc print data=rawdata.spiro (obs=100);
  where find(sptest, 'ALB') and ^missing(sporresc);
run; 

proc compare data=rawdata.spiro (where=(find(sptest, 'ALBSTG')))
             comp=rawdata.spiro (where=(sptest='FEV1'));
run;
