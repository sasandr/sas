%let key1=STUDYID, USUBJID, VISITNUM, LBTPTNUM, LBDTC, LBCAT, LBSCAT, LBTESTCD, LBSTRESC, LBSEQ;
%let key=%sysfunc(compress("&key1", ","));
%let lastkey=%scan(&key, -1);
%let dom=lb;

%put WARNING: &key &lastkey;

proc sort data=tabdata.&dom out=&dom._out;
  by &key;
run;

data dup;
  set &dom._out end=eof;
  by  &key;
  
  retain count 0;
  
  if  ^(first.&lastkey and last.&lastkey) then do;
      count+1;
      output;      
  end;
  
  if eof and count>0 then put "WARNING: Keys &key1 contain " count+(-1) " duplicates in %upcase(&dom).";
  if eof and count=0 then put "WARNING: %upcase(&dom) has no duplicates using keys: &key1..";  
run;

proc print; 
run;
