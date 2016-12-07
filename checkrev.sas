
***********************************************************************************;
*** This is to check calculation of % reversibility in spirometry data transfer ***;
***********************************************************************************;

%let id=PT010006-007008;

proc sort data=tabdata.re out=re (keep=usubjid reseq retestcd retest restresn restresu visit: retpt: redtc);
  where retestcd in ('FEV1' 'FEV1REV' 'FEV1REVM') and visitnum in (2,3);
  by usubjid visitnum redtc;;
run;

proc sort data=re nodupkey;
  by usubjid visitnum redtc retestcd retpt;
run;

data re;
  set re;
  
  length group $ 20;
  
  if retptnum=-1 then group=cats(retestcd, 'PRE1');
  else if retptnum=-0.5 then group=cats(retestcd, 'PRE2');
  else if retptnum=0.5 then group=retestcd;

run;

proc transpose data=re out=t_re (drop=_:);
  var restresn;
  by  usubjid visitnum redtc;
  id  group;
run;

proc print data=t_re;
  where usubjid="&id";
run;

data t_re;
  set t_re;
  by  usubjid visitnum;
  
  if  first.visitnum then call missing(var1, var2);
  
  retain   var1 var2;
  
  if missing(fev1pre1) then fev1pre1=var1;
  if missing(fev1pre2) then fev1pre2=var2;                                                                    
  var1 = fev1pre1;
  var2 = fev1pre2;
  drop var1 var2;
run;

data check;
  set t_re;
  
  pre = mean(fev1pre1, fev1pre2);
  
  revm = 1000 * (fev1 - pre);
  prev = ((fev1-pre) / pre) * 100;
  
  drop pre;
  
  diff1 = (revm - fev1revm);
  diff2 = (prev - fev1rev);    
run;

proc means data=check min max mean;
  var diff1 diff2;
run;

proc print data=check;
  where diff1 > 0.0001 or diff2 > 0.0001;
run;

proc print data=check;
  where nmiss(revm, fev1revm)=1 or nmiss(prev, fev1rev)=1;
run;

proc compare data=check listall criterion=0.00001;
  id  usubjid;
  var revm       prev;
  with fev1revm  fev1rev;
run;