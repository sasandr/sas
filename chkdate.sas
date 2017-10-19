%macro chkdate(crfdt=);

    length dd $2 mmm $3 yy $4 tempdat $ 9;
    
    call missing(dd, mmm, yy);
    
    if (count(&crfdt, '/')=1) and
       (prxmatch("/\w{3}\/\d{4}/", &crfdt) or prxmatch("/000\/\d{4}/", &crfdt) or prxmatch("/\w{2}\/\d{4}/", &crfdt)) then do;
        dd='00';
        mmm=upcase(scan(&crfdt, 1, '/'));
        yy=scan(&crfdt, 2, '/');
    end;

    else if (count(&crfdt, '/')=1) and
            index(strip(&crfdt), '/')=1 then do;
        dd='00';
        mmm='000';
        yy=scan(&crfdt, 1, '/');
    end;
    
    else if index(strip(&crfdt), '/')=1 and count(&crfdt, '/')=2 and substr(strip(&crfdt), 2,1)^='/' then do;
        dd='00';
        mmm=upcase(scan(&crfdt, 1, '/'));
        yy=scan(&crfdt, 2, '/');
    end;

    else if index(strip(&crfdt), '/')=1 and count(&crfdt, '/')=2 and substr(strip(&crfdt), 2,1)='/' then do;
        dd='00';
        mmm='000';
        yy=scan(&crfdt, 1, '/');
    end;
    
    else do;
        dd=scan(&crfdt, 1, '/');
        mmm=upcase(scan(&crfdt, 2, '/'));
        yy=scan(&crfdt, 3, '/');
    end;
    
    tempdat = cats(dd,mmm,yy);

    if (^missing(mmm) and mmm not in ('JAN' 'FEB' 'MAR' 'APR' 'MAY' 'JUN' 'JUL' 'AUG' 'SEP' 'OCT' 'NOV' 'DEC' '000' 'OOO' 'UNK'))
        then flag=1;
        
    else if dd>'00' and 
            (mmm>'000') and 
            yy>'0000' and input(tempdat, ?? date9.)<=.z then flag=1;

%mend chkdate;

data datlist;
  set sashelp.vcolumn;
  where libname='RAWDATA' and 
        find(memname, 'plate', 'i') and 
        find(label, 'date', 'i') and 
        find(name, 'SDV')=0 and
        memname ^in ('PLATE501' 'PLATE510' 'PLATE511');
  keep memname varnum name label;
run;

title "Invalid CRF date";
data _null_;
  set datlist end=eof;
  
  length source $ 50;
  source=catx('.', 'rawdata', memname);
   
    call execute ("data _"||strip(memname)||';');
    call execute ("  set "||source||';');
    call execute ('  %chkdate(crfdt='||strip(name)||');');
    call execute ('  if flag=1 then output;');
    call execute ('run;');
    
    call execute ("proc print;");
    call execute ("  var dfplate id "|| name ||";"); 
  
  if eof then call execute ("run; ");
  
run;
