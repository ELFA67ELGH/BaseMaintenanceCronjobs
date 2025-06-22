#!/bin/ksh
# PURPOSE : to Daily accumilate HAVGaccs for each shabakat accounts
#		according to T0008_ai.C0008_threshold & iutddb..TSCC13_shabakat
# DATE    :  Sep 2020
##########################################################
/aedc/etc/work/aedc/SCC/aedc_SCC_functions

export UN_BIN=/bin
export SCC_BIN=/aedc/etc/work/aedc/SCC/bin
export SYB_DIR=/usr/local/sybase/sybase1002/bin
sybase_path="/usr/local/sybase/sybase10/interfaces"

offset="Jan  1 1970 02:00AM"
sub_outdir=/home/sis/REPORTS/Shabakat
sub_outdir2=/SYBASE/sub_home/REPORTS/Shabakat



function main {
for KV in 6 11 20 22
do
echo "working with $KV ...."
  case $KV in
  6)  fact=90 ;;
  11) fact=58 ;;
  20) fact=33 ;;
  22) fact=30 ;;
  esac
echo  "select 'Data',C0008_threshold_shab_id,CSCC13_shabakat_name
        from iutddb..TSCC13_shabakat
        where CSCC13_shabakat_volt=$KV
go"|$SYB_DIR/isql -I $sybase_path -S AEDC_SYSTEM -Udbu -Pdbudbu 

  echo "select 'Data',C0008_threshold_shab_id,CSCC13_shabakat_name
        from iutddb..TSCC13_shabakat
        where CSCC13_shabakat_volt=$KV
go"|$SYB_DIR/isql -I $sybase_path -S AEDC_SYSTEM -Udbu -Pdbudbu |
        grep Data | awk 'FS="Data"{print $2}' |
	while read ln
 	    do
	    echo "	working with $ln ...."
	    echo "$ln" |awk 'OFS="\n"{print $1,$2}' | { read ShaId ; read Shab ; }
	    echo "select 'Data',
	    convert(char(10),dateadd(second,C0432_date,'${offset}'),102),
	    convert(char(10),dateadd(second,C0432_date,'${offset}'),8),
	    str(sum(C0432_value_r),9,2),str(sum(C0432_value_r)/$fact,9,2)
	    from $DataTable
	    where C0401_aid in (select C0401_aid from T0401_accounts
	          where C0401_source_id_int in (select C0007_point_id from T0008_ai
		        where C0008_threshold=$ShaId)
		  and C0401_name like '%<HAVG')
	    and C0432_date between $from1 and $to1
	    group by C0432_date
go"|$SYB_DIR/isql -I $sybase_path -S AEDC_SYSTEM -Udbu -Pdbudbu |
                 grep Data | sed "s/Data/$ShaId $Shab $KV/" |
		 awk 'OFS="\t"{print $1,$2,$3,$4,$5,$6,$7}' >> 	${OUT_DIR}/${FILE_NAME}    	  	
	    done      

done
compress ${OUT_DIR}/${FILE_NAME}
cp -p ${OUT_DIR}/${FILE_NAME}.Z ${OUT_DIR2} 
#sed "s@.${mm}.@/${mm}/@" ${OUT_DIR}/${FILE_NAME} ${OUT_DIR}/${FILE_NAME}1
#mv ${OUT_DIR}/${FILE_NAME}1 ${OUT_DIR}/${FILE_NAME}

}

function usage {
echo "
Usage : $1 [ -f <day> ]
	-f : to work from historical file of <day>
        day : on the form yyyy/mm/dd "
exit
}

function prepare {
to=`$SCC_BIN/var_mktime ${today} '%Y/%m/%d:00:00:00'`
to1=`expr $to - 1`
from1=`expr $to1 - 86399`

$SCC_BIN/var_asctime $from1 "%Y %m %d" |
        awk '{printf("%s\n%s\n%s",$1,$2,$3)}' | { read yyyy ; read mm ; read dd ; }
FILE_NAME=CollectShabakat_${yyyy}_${mm}_${dd}
OUT_DIR=${sub_outdir}/${yyyy}_${mm}
OUT_DIR2=${sub_outdir2}/${yyyy}_${mm}

if [ ! -d ${OUT_DIR} ]
then
mkdir ${OUT_DIR}
fi

if [ ! -d ${OUT_DIR2} ]
then
mkdir ${OUT_DIR2}
fi

if [ -s ${OUT_DIR}/${FILE_NAME} ]
then
echo "${OUT_DIR}/${FILE_NAME} already exist  it will moved to ${OUT_DIR}/${FILE_NAME}_found "
mv ${OUT_DIR}/${FILE_NAME} ${OUT_DIR}/${FILE_NAME}_found
fi
print -n "" > ${OUT_DIR}/${FILE_NAME}

}
#=======================
#  Start Point
#=======================

case v$1 in
v)
today=`$UN_BIN/date +"%Y/%m/%d:00:00:00"`
prepare
DataTable="T0432_data"
main
;;
v-f)
if [ -z "$2" ] 
then 
usage $0
fi

today="$2:00:00:00"
prepare

echo "
if exists (select name from sysobjects where name = 'T0432_data_tmp')
drop table T0432_data_tmp
go

 create table T0432_data_tmp (
  C0401_aid             int     not null        references T0401_accounts(C0401_aid),
  C0432_date            time_t  not null,
  C0432_value_r         real    null,
  C0432_value_i         int     null,
  C0432_status          tinyint not null
)
go

if not exists (
select name from sysobjects where name = 'T0432_data_tmp_I1')
 create unique index T0432_data_tmp_I1
  on T0432_data_tmp( C0401_aid, C0432_date )
  with ignore_dup_key
go

if not exists (
select name from sysobjects where name = 'T0432_data_tmp_I2')
 create clustered index T0432_data_tmp_I2
  on T0432_data_tmp( C0432_date )
  with ignore_dup_row

go"|$SYB_DIR/isql -I $sybase_path -S AEDC_SYSTEM -Udbu -Pdbudbu 

zcat $HIS/${dd}_${mm}_${yyyy}.acc.Z | grep [0-9] | grep -v [a-z] |
     awk 'OFS="\t"{print $1,$2,$3,$4,$5}' | sed 's/NULL//'   > $SCCTMP/temp_separated
     
eval bcp $aedcdb..T0432_data_tmp in $SCCTMP/temp_separated -c  -U dbu -P dbudbu

DataTable="T0432_data_tmp"
main
;;
*) usage $0
;;
esac




