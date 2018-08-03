options errorabend nocenter;;

%let lib=anadata;

data keys;
  infile "keys.csv" delimiter = ',' MISSOVER DSD lrecl=32767 firstobs=1 ;
  length dom $ 8 key1 $ 100;
  input dom $ key1 $;
run;

%macro chkdup(dom, key1);
  
  %let key=%sysfunc(compress("&key1", ","));
  %let lastkey=%scan(&key, -1);

  proc sort data=&lib..&dom out=&dom._out;
    by &key;
  run;
  
  data &dom._dup;
    set &dom._out end=eof;
    by  &key;
    
    retain count 0;
    
    if  ^(first.&lastkey and last.&lastkey) then do;
        count+1;
        output;      
    end;
    
    if eof and count>0 then put "WARNING1: %upcase(&dom) has " count+(-1) " duplicates using keys %sysfunc(compbl(&key1))";
    if eof and count=0 then put "INFO0: %upcase(&dom) has no duplicates using keys: %sysfunc(compbl(&key1))";  
  run;

   %if %sysfunc(exist(&dom._dup)) %then %do;
    title "&dom: <=50 records of duplicate records";
    proc print data=&dom._dup (obs=50); 
      by usubjid;
      id usubjid;
    run;
   %end;

  %exit:
  
%mend chkdup;

data _null_;
  set keys;
  call execute('%nrstr(%chkdup(' || strip(dom) ||', ' || '%str(' || key1 ||' )));');
run;
