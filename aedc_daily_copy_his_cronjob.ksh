#!/bin/ksh
echo "starting aedc_daily_copy_his_cronjob.ksh"
. /aedc/etc/work/aedc/SCC/aedc_SCC_functions
dba_init_file=/usr/local/sybase/dba/maint/setdbaenv.ksh
/usr/local/sybase/dba/maint/setdbafct.ksh

export UN_BIN=/bin
export PTH=/aedc/data/nfs/historical
export SCC_BIN=/aedc/etc/work/aedc/SCC/bin
export SCC_ERR=/aedc/err/scc
export SYB_DIR=/usr/local/sybase/sybase1002/bin
sybase_path="/usr/local/sybase/sybase10/interfaces"




function create_file {
$UN_BIN/echo "\n >>>>  creating $HIS/${ZFILE} <<<<<"

case $type in

his)
echo "
select  C0438_date,C0438_microsec,rtrim(C0439_alm_text) from T0439_almhc
where C0438_date between $strt_tm and $end_tm
go" | $SYB_DIR/isql -I $sybase_path -S AEDC_SYSTEM -Udbu -Pdbudbu  > $HIS/${FILE}
$UN_BIN/compress $HIS/${FILE}
$UN_BIN/echo "\n <<<<  file $HIS/${ZFILE} done >>>>> \n"
$SCC_BIN/var_asctime $wanted_day_sec '%d/%m/%Y'|read tag_date
$UN_BIN/echo "Update CableFail tables .... log file : $SCC_ERR/CableFail_log"
$SCCROOT/aedc_CableFail_FillInTab.ksh $tag_date >>  $SCC_ERR/CableFail_log
$SCCROOT/aedc_OutagesNotes_FillInTab.ksh $tag_date >>  $SCC_ERR/OutagesNotes_log
;;

acc)
echo "
select * from ${T0432_d}
where C0432_date between $strt_tm and $end_tm
go" | $SYB_DIR/isql -I $sybase_path -S AEDC_SYSTEM -Udbu -Pdbudbu > $HIS/${FILE}
$UN_BIN/compress $HIS/${FILE}
$UN_BIN/echo "\n <<<<  file $HIS/${ZFILE} done >>>>> \n"
;;

pkacc)
echo "
select aid=str(C0401_aid,6,0) , date=C0434_date , value=str(C0434_value,10,4) ,
ass_val=str(C0434_assoc_value,10,4) , occ_tm=C0434_time_of_occurrence ,
sts=C0434_status , ass_sts=C0434_assoc_status
from ${T0434_p_d}
where C0434_date between $strt_tm and $end_tm
go"|$SYB_DIR/isql -I $sybase_path -S AEDC_SYSTEM -Udbu -Pdbudbu > $HIS/${FILE}
$UN_BIN/compress $HIS/${FILE}
$UN_BIN/echo "\n <<<<  file $HIS/${ZFILE} done >>>>> \n"
;;

nam)
echo "
select 'aid'=C0401_aid,'name'=substring(C0401_name,1,35),
'stat'=C0401_state,'last_op'=C0401_last_operation,'accnt_type'=C0411_accnt_type
from T0401_accounts
go"|$SYB_DIR/isql -I $sybase_path -S AEDC_SYSTEM -Udbu -Pdbudbu > $HIS/${FILE}
$UN_BIN/compress $HIS/${FILE}
$UN_BIN/echo "\n <<<<  file $HIS/${ZFILE} done >>>>> \n"
;;

esac
$UN_BIN/cp $HIS/${ZFILE} $SCCROOT/sub_his/
#$UN_BIN/uncompress $SCCROOT/sub_his/${ZFILE}
}

function check_file {
    $UN_BIN/echo "${dd}_${mm}_${yyyy}.${type}" | read FILE
    $UN_BIN/echo "${dd}_${mm}_${yyyy}.${type}.Z" | read ZFILE
    $UN_BIN/find /aedc/data/nfs/historical/ -name $ZFILE|read exist_file
    if [[ ! -z ${exist_file} ]]
    then
      
      if [[ -s /aedc/data/nfs/historical/$ZFILE ]]
      then
        $UN_BIN/echo "The $ZFILE is already exist "
$UN_BIN/mv /aedc/data/nfs/historical/${ZFILE} /aedc/data/nfs/historical/${ZFILE}_found

      else
	$UN_BIN/echo "	There is a zero size file with the name : $ZFILE
	This file will be recreated ..."
      fi
    fi
create_file 
}

function usage {
echo "Usage : $1 [ -d <report_day> ] [ -t report_type ] [ -u ]
where	report_day  : on the form yyyy/mm/dd 
	report_type : his | acc | pkacc | nam 
	-u	    : update mode : get data from tmp tables created by 
			aedc_restore_oneDayData.ksh
	 	      "
	

exit
}

function get_default_date {
  today=`$UN_BIN/date +"%Y/%m/%d"`
  today_sec=`$SCC_BIN/var_mktime $today '%Y/%m/%d'`
  wanted_day_sec=`expr $today_sec - 86400`
  copydate=`$SCC_BIN/var_asctime $wanted_day_sec %Y/%m/%d`
}

#clear

# start point
###############

dba_init_file=/usr/local/sybase/dba/maint/setdbaenv.ksh

/usr/local/sybase/dba/maint/setdbafct.ksh

export UN_BIN=/binexport UN_BIN=/bin
export PTH=/aedc/data/nfs/historical
export SCC_BIN=/aedc/etc/work/aedc/SCC/bin
export SYB_DIR=/usr/local/sybase/sybase1002/bin
sybase_path1="/usr/local/sybase/sybase10"

  T0434_p_d="T0434_peak_data"
  T0432_d="T0432_data"


  if [[ ! -d /aedc/data/nfs/historical/ ]]
then
echo "\n\n >>>>>>>> NFS is not mounted <<<<<<<<< \n \n"
else
echo " \n >>>>>>>>> NFS  is  mounted <<<<<<<<< \n"


if [ $# -eq 0 ]
then
  get_default_date
  types="his acc pkacc nam"
 
else
  while [ ! -z "$1" ]
  do
    case $1 in
    "-d")
     if [ `mktime ${2}:00:00:00` -gt 883605600 ] && [ `mktime ${2}:00:00:00` -lt 1893448800 ]
     # $2 in the required format between 1998,2030
     then
       copydate=$2
       shift
       shift
     else
     usage $0
     fi
    ;;

    "-t")
    types=`echo "$2"|awk '{print tolower($1)}'`
      case v$types in
      "vhis"|"vacc"|"vpkacc"|"vnam") print -n "" ;;
      *)
      usage $0
      ;;
      esac
    shift
    shift
    ;;
    
    "-u")
    T0434_p_d="T0434_peak_data_tmp"
    T0432_d="T0432_data_tmp"
    echo "select min(C0434_date) from T0434_peak_data_tmp
go"|$SYB_DIR/isql -I $sybase_path -S AEDC_SYSTEM -Udbu -Pdbudbu |
         head -3 | tail -1 | read copydate_sec
    var_asctime $copydate_sec "%Y/%m/%d" | read copydate
    if [ -z "$types" ]
    then
     types="acc pkacc"
    fi
    shift    
    ;;

    *)
    usage $0
    ;;
    esac
  done

fi

if [ -z "$copydate" ]
then
get_default_date
fi

if [ -z "$types" ]
then
types="his acc pkacc nam"
fi


#  if [ $wanted_day_sec -ge  $today_sec ]
#  then
#    $UN_BIN/echo "Wrong input, Please enter a date before today"
#  else  
    /aedc/bin/mktime ${copydate}:00:00:00 |read strt_tm
    /aedc/bin/mktime ${copydate}:23:59:59 |read end_tm
    echo $copydate|cut -b 1-4|read yyyy
    echo $copydate|cut -b 6-7|read mm
    echo $copydate|cut -b 9-10|read dd
    for type in $types
    do
     check_file
    done


$UN_BIN/date
$UN_BIN/ls -al  $PTH/${dd}_${mm}_${yyyy}*

#  fi


fi
