options errorabend;

data keys;
  infile "keys.csv" delimiter = ',' MISSOVER DSD lrecl=32767 firstobs=2 ;
  length dom $ 8 key1 $ 100;
  input dom $ key1 $;
run;

%macro chkdup(dom, key1);
  
  %let key=%sysfunc(compress("&key1", ","));
  %let lastkey=%scan(&key, -1);

  proc sort data=anadata.&dom out=&dom._out;
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
    
    if eof and count>0 then put "WARNING: Keys %sysfunc(compress(&key1)) contain " count+(-1) " duplicates in %upcase(&dom).";
    if eof and count=0 then put "WARNING: %upcase(&dom) has no duplicates using keys: &key1..";  
  run;
  
  options obs=100;
  title "&dom: 100 records of duplicate records";
  proc print; 
    by usubjid;
    id usubjid;
  run;
  %exit:
  
%mend chkdup;

data _null_;
  set keys;
  call execute('%nrstr(%chkdup(' || strip(dom) ||', ' || '%str(' || key1 ||' )));');
run;
