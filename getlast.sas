data dat1;
  set sashelp.vcolumn;
  where libname='RAWDATA' and prxmatch('m/(DAT_YYYY|DAT_MM|DAT_DD)$/io', strip(name));
  
  length var $ 20;
  
  var = compress(scan(name, 1, '_'));
  keep memname name var label;
run;
  
proc sort data=dat1 out=dat2 nodupkey;
  by memname var;
run;

proc sql noprint;
  select var into :varlist
  separated by ' ' 
  from   dat2
quit;

%macro getlast(indsn, varname);
  
  data _temp1;
    set rawdata.&indsn (encoding=any keep=subject &varname.:);
    %getdate2(crfdt=&varname, isodt=isodtc);
    if ^missing(isodtc);
  run;
  
  proc sort data=_temp1;
    by subject isodtc;
  run;

  data &varname;
    set _temp1;
    by  subject isodtc;
    
    length source $ 30;
    
    source = upcase("&varname");
    
    if  last.subject;
    
    keep subject source isodtc;
  run;
  
  proc datasets library=work nodetails nolist;
    delete _temp1;
  quit;
  
%mend getlast;

data _null_;
  set dat2;
  call execute('%nrstr(%getlast(' || strip(memname) ||', '||'%str('||compress(var)||')));');
run;
