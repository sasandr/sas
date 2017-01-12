
data datlist;
  set sashelp.vcolumn;
  where libname='RAWDATA' and 
        find(memname, 'plate', 'i') and 
        find(label, 'date', 'i') and 
        find(name, 'SDV')=0 and
        memname ^in ('PLATE501' 'PLATE510' 'PLATE511');
  keep memname varnum name label;
run;

data datlist2;
  set datlist;
  by  memname;

  retain list;
  length list $ 400;
  
  if  first.memname then list=' ';
  list = catx(' ', list, name);

  if  last.memname;
  
  keep memname list;
  
run;

proc print; run;
