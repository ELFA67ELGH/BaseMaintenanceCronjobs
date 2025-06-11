#!/bin/ksh
echo "starting aedc_daily_spaceused_cronjob.ksh"
. /aedc/etc/work/aedc/SCC/aedc_SCC_functions
export UN_BIN=/bin
export SCC_BIN=/aedc/etc/work/aedc/SCC/bin
export SYB_DIR=/usr/local/sybase/sybase1002/bin
sybase_path="/usr/local/sybase/sybase10/interfaces"

cp -p /aedc/err/scc/spaceused.log /aedc/err/scc/prev_spaceused.log
$UN_BIN/echo "
 name                		used(KB)	unused(KB)
 ------------------------------ --------	---------" > /aedc/err/scc/spaceused.log

$UN_BIN/grep "^T0" /aedc/cnf/scc/aedc_HIS_tables |{
while read table
do
echo "sp_spaceused $table
go"| $SYB_DIR/isql -I $sybase_path -S AEDC_SYSTEM -Udbu -Pdbudbu -w150 | grep "^ T0"|awk 'OFS="\t\t"{printf("%-30s\t",$1);print $5+$7,$9}' >> /aedc/err/scc/spaceused.log
done
}

