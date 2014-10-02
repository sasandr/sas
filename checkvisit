/* Select a list of SDTM domains that use VISITNUM/VISIT */
proc sql;
 select distinct(memname) into :gdmlist
 separated by '*'
 from   sashelp.vcolumn
 where  upcase(libname)="GDMDATA" and upcase(name)="VISIT";
quit;
  
%macro check;
  %let i = 1 ;
  
  %do %while(%scan(&gdmlist,&i,*) ^= %str( )) ;
    %let indsn = %scan(&gdmlist,&i,*) ;
    title "gdmdata.&indsn";
    proc freq data=gdmdata.&indsn noprint;
      tables visitnum*visit/list missing out=test(where=(visitnum>.z and ^missing(visit)));
    run;
    
    proc transpose data=test out=vtest prefix=v;
      var visit;
      id  visitnum;
    run;
     
    data out;
      set vtest;
      length source $ 2;
       
      source=%upcase("&indsn");
    run;
     
    proc append base=final data=out force;
    run;
     
    %let i = %eval(&i + 1 ) ;
  %end ;
%mend check;
  
%check;
