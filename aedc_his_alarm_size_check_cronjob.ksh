#!/bin/ksh


. /aedc/etc/work/aedc/SCC/aedc_SCC_functions
dba_init_file=/usr/local/sybase/dba/maint/setdbaenv.ksh
/usr/local/sybase/dba/maint/setdbafct.ksh

export UN_BIN=/bin
export PTH=/aedc/data/nfs/historical
export SCC_BIN=/aedc/etc/work/aedc/SCC/bin
export SCC_ERR=/aedc/err/scc
export SYB_DIR=/usr/local/sybase/sybase1002/bin
sybase_path="/usr/local/sybase/sybase10/interfaces"

#$UN_BIN/echo "`date`	starting aedc_his_alarm_size_check_cronjob.ksh"

today=`$UN_BIN/date +"%Y/%m/%d:00:00:00"`
today_sec=`$SCC_BIN/var_mktime $today '%Y/%m/%d'`
now_hr=`$UN_BIN/date +"%H"`

case $now_hr in
07) alarm_thr=7000	; out_fl="/aedc/data/morning.his"
;;
13) alarm_thr=14000	; out_fl="/aedc/data/afternoon.his"
;;
19) alarm_thr=21000	; out_fl="/aedc/data/evening.his"
;;
esac
$UN_BIN/echo "`date`	starting aedc_his_alarm_size_check_cronjob.ksh	w.r.t. alarm_thr=$alarm_thr" >> /aedc/err/scc/his_alarm_size_check.log
rm -f $out_fl

echo "select count(*) from T0439_almhc
where C0438_date > $today_sec
go" | $SYB_DIR/isql -I $sybase_path -S AEDC_SYSTEM -Udbu -Pdbudbu |
     head -3 | tail -1 | read alarms

if [ "$alarms" -ge "$alarm_thr" ]
then
echo "
select  C0438_date,C0438_microsec,rtrim(C0439_alm_text) from T0439_almhc
where C0438_date > $today_sec
go" | $SYB_DIR/isql -I $sybase_path -S AEDC_SYSTEM -Udbu -Pdbudbu  > $out_fl
fi
