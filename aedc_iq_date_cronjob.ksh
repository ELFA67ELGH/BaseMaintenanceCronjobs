#!/bin/ksh
. /aedc/etc/work/aedc/SCC/aedc_SCC_functions

export UN_BIN=/bin
export PTH=/aedc/data/nfs/historical
export SCC_BIN=/aedc/etc/work/aedc/SCC/bin



/aedc/bin/mktime `$UN_BIN/date +"%Y/%m/%d:11:00:00"`|awk '{ printf("%s\n", $1-86400)}'|{ read yesterday ; } 
$SCC_BIN/var_asctime $yesterday   "%A %d %B %Y" |read aut
/bin/sed "s/AUTHOR/AUTHOR '${aut}'/" /aedc/data/nfs/reports/alex_chart.p >/aedc/data/nfs/reports/06050836.p45
/bin/sed "s/AUTHOR/AUTHOR '${aut}'/" /aedc/data/nfs/reports/mvar >/aedc/data/nfs/reports/09211337.p43
/bin/sed "s/AUTHOR/AUTHOR '${aut}'/" /aedc/data/nfs/reports/mvar_real >/aedc/data/nfs/reports/09211323.p49
if [ `$UN_BIN/date +"%d"` -eq 1 ]
then
$SCC_BIN/var_asctime ${yesterday}   "%B" |read m
$UN_BIN/date +"%m %Y"|awk '{if($1==1){printf ("%d\n", $2-1)}else{printf ("%d\n", $2)}}'|read Y
/bin/sed "s/AUTHOR/AUTHOR '${m} ${Y}'/" /aedc/data/nfs/reports/alex_chart_m.p >/aedc/data/nfs/reports/08020909.p49
fi



