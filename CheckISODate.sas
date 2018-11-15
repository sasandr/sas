%macro CheckISODate(indsn=, isodate=);
  data _null_;
    length isoregex $200;
    set &indsn. (keep=&isodate);

    where ^missing(&isodate);
    retain re;

    Select (length(&isodate.));
    	when (4) 	isoregex ="/(\d{4})/";
    	when (7) 	isoregex ="/(\d{4})-[0-1][0-9]/";
    	when (10)	isoregex ="/(\d{4})-[0-1][0-9]-[0-3][0-9]/";
    	when (16) isoregex ="/(\d{4})-[0-1][0-9]-[0-3][0-9]T(0[0-9]|1[0-9]|2[0-3]):[0-5][0-9]/";
    	when (19) isoregex ="/(\d{4})-[0-1][0-9]-[0-3][0-9]T(0[0-9]|1[0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]/";
    	Otherwise isoregex ="/AAAAAAAAAAAA/";
    end;

    re = prxparse(isoregex); 
    if ^prxmatch(re, compress(&isodate.)) then
    	put "WARNING: Invalid SDTM ISO8601 DATE FOUND: " &isodate.= " in dataset &indsn.";
  run;
%mend CheckISODate;

data dsnlist;
  set sashelp.vcolumn;
  where upcase(libname)='TABDATA' and memtype='DATA' and length(memname)=2;
  
  if prxmatch('/DTC$/', strip(name));
  
  keep memname name;
run;

data _null_;
  set dsnlist;
  call execute('%nrstr(%checkisodate(indsn=tabdata.' || strip(memname) ||', isodate='||strip(name)||'));');
run;
