%let key1=STUDYID, USUBJID, AESTDTC, AESPID, AEENDTC, AEDECOD;
%let key=%sysfunc(compress("&key1", ","));
%let lastvar=%scan(&key, -1);
%let dom=ae;

%put WARNING: &key &lastvar;

proc sort data=tabdata.&dom out=&dom._out;
  by &key;
run;

data dup;
  set &dom._out end=eof;
  by  &key;
  
  retain count 0;
  
  if  ^(first.&lastvar and last.&lastvar) then do;
      count+1;
      output;      
  end;
  
  if eof and count>0 then put "WARNING: Keys &key1 contain " count+(-1) " duplicates in %upcase(&dom).";
  if eof and count=0 then put "WARNING: %upcase(&dom) has no duplicates.";  
run;

proc print; 
run;
