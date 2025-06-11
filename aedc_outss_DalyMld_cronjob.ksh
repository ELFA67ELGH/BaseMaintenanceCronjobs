#!/bin/ksh
# PURPOSE : to save  Daily AVG value for outgoing & incoming SS
# GROUP   : Alex. SCC IS
# AUTHOR  :  Alaa Nagy
# DATE    : 
##########################################################
/aedc/etc/work/aedc/SCC/aedc_SCC_functions
/usr/local/sybase/dba/maint/setdbafct.ksh
dba_init_file=/usr/local/sybase/dba/maint/setdbaenv.ksh
export UN_BIN=/bin
export SCC_BIN=/aedc/etc/work/aedc/SCC/bin
export SYB_DIR=/usr/local/sybase/sybase1002/bin
sybase_path="/usr/local/sybase/sybase10/interfaces"
export BIN_ASCTIME=/aedc/bin

sub_outdir=/home/sis/REPORTS/Wednesday_OUTSS_max_value

offset="Jan 1 1970 02:00AM"
#offset="Jan 1 1970 03:00AM"

rm -f /aedc/tmp/scc/pointlist1
day_form="substring(convert(char(10),dateadd (second, C0432_date,'${offset}'),103),1,10)"
time_form="substring(convert(char(8),dateadd (second, C0432_date,'${offset}'),108),1,5)"
min_time="substring(convert(char(8),dateadd (second, max(C0432_date) ,'${offset}'),108),1,5)"
IN_FILE1=/aedc/data/dbgen/SCC/SCC_ACC/SCCacc_HAVG_out_SS_AMP.dat
IN_FILE2=/aedc/data/dbgen/SCC/SCC_ACC/SCCacc_HAVG_out_DP_AMP.dat
IN_FILE3=/aedc/data/dbgen/SCC/SCC_ACC/SCCacc_HAVG_in_DP_AMP.dat
IN_FILE4=/aedc/data/dbgen/SCC/SCC_ACC/SCCacc_HAVG_in_SS_AMP.dat

function main {

echo "
declare @alex_acc_id         int
declare @pk_time             time_t
declare @morning_pk_time     time_t
select @alex_acc_id   = (select C0401_aid from T0401_accounts where C0401_name ='ALEX.TOTAL_MWA<HMAX' )
select @pk_time	      = (select C0434_date from T0434_peak_data
			where C0401_aid = @alex_acc_id
			and C0434_value = (select max(C0434_value) from T0434_peak_data
					  where C0401_aid = @alex_acc_id
					  and C0434_date between $from1 and $to1))
select @morning_pk_time	= (select C0434_date from T0434_peak_data
			  where C0401_aid = @alex_acc_id
			  and C0434_value = (select max(C0434_value) from T0434_peak_data
					  where C0401_aid = @alex_acc_id
					  and C0434_date between ($from1 + 28800) and ($from1 + 50400)))
			/* 28800 = 60*60*8 */
			/* 50400 = 60*60*14 */
			
select @pk_time, @morning_pk_time
go"|$SYB_DIR/isql -I $sybase_path -S AEDC_SYSTEM -Udbu -Pdbudbu | tail -3 | head -1 |
awk 'OFS="\n"{print $1,$2}' | { read pk_time ; read morning_pk_time ; }
echo "
select C0401_name from T0401_accounts where C0411_accnt_type=3 and C0401_state='A'
go"|$SYB_DIR/isql -I $sybase_path -S AEDC_SYSTEM -Udbu -Pdbudbu -w 200|
grep HAVG| awk '{print $1}'>/aedc/tmp/scc/havg_acc

grep "\-SS" /aedc/tmp/scc/havg_acc|awk '{if(substr($1,1,2)=="P:")
{print $1"@O_SS"}else{print $1"@I_SS"}}'>/aedc/tmp/scc/pointlist1
grep "\-DP" /aedc/tmp/scc/havg_acc|awk '{if(substr($1,1,2)=="P:")
{print $1"@O_DP"}else{print $1"@I_DP"}}'>>/aedc/tmp/scc/pointlist1

grep -v -e "\-SS" -e "\-DP"  /aedc/tmp/scc/havg_acc|awk '{if(substr($1,1,2)=="P:")
{print $1"@O_SS"}else{print $1"@I_SS"}}'>>/aedc/tmp/scc/pointlist1

sort -u  /aedc/tmp/scc/pointlist1  > /aedc/tmp/scc/pointlist
if [[ -s  $OUT_DIR/${FILE_NAME}.ld.Z ]]
then
echo $OUT_DIR/${FILE_NAME}.ld.Z  already exist  it will moved to ${FILE_NAME}.ld-found
mv $OUT_DIR/${FILE_NAME}.ld.Z $OUT_DIR/${FILE_NAME}.ld.Z-found
fi

cat /aedc/tmp/scc/pointlist |
while read name1 
do
echo ${name1} |awk ' FS="@" {print $1 }'|read name
echo ${name1} |awk ' FS="@" {print $2 }'|read typ
echo "
use aedcdb
go
set rowcount 1
declare @acc_id         int
declare @des_name       varchar(30)
declare @min_time       varchar(5)
declare @max_value      float
declare @avg_value      float
declare @min_value      float
declare @pk_value              float	/* acc. value at the time of Alex peak */
declare @morning_pk_value      float	/* acc. value at the time of Alex morning peak */
declare @src_id         int
declare @src_nm         varchar(30)
declare @src_desc       varchar(30)
declare @cable_cs       varchar(30)	/* Limit set name */
declare @limit_id       int
declare @limit          float
declare @times          int

if exists ( select C0401_name   from T0401_accounts where C0401_name like '$name' )
begin
select @acc_id   = (select C0401_aid from T0401_accounts where C0401_name ='$name' )
select @src_id   = (select C0401_source_id_int from T0401_accounts where C0401_name ='$name' )
select @des_name = (select C0401_description from T0401_accounts where C0401_name ='$name')

select @src_nm   = (select rtrim(C0003_group_name)+'.'+rtrim(C0007_point_name) 
from T0007_point where C0007_point_id =@src_id )
select @src_desc = (select C0007_point_desc from T0007_point where C0007_point_id =@src_id )
select @limit_id = (select C0023_lim_set_id from T0008_ai where C0007_point_id =@src_id )
select @cable_cs = (select C0023_lim_set_name from T0023_limit_set where C0023_lim_set_id =@limit_id )
select @limit    = (select C0025_hi_oper
from T0025_ai_point_limits where C0007_point_id=@src_id and  C0071_lim_group_id=1)

if exists ( select C0432_value_r from T0432_data where C0401_aid = @acc_id and C0432_date between $from1 and $to1)
begin

select @max_value = (select max(C0432_value_r)  from T0432_data where C0401_aid = @acc_id
and C0432_date between ${from1} and ${to1} and C0432_status&8=8   and C0432_status&4<>4 )

select @avg_value = (select avg(C0432_value_r)  from T0432_data where C0401_aid = @acc_id
and C0432_date between ${from1} and ${to1} and C0432_status&8=8 and C0432_value_r > 5 )

select @min_value = (select min(C0432_value_r)  from T0432_data where C0401_aid = @acc_id
and C0432_date between ${from1} and ${to1} and C0432_status&8=8 and C0432_value_r > 5 )

select @pk_value = (select C0432_value_r from T0432_data where C0401_aid = @acc_id
and C0432_date = ${pk_time} )

select @morning_pk_value = (select C0432_value_r from T0432_data where C0401_aid = @acc_id
and C0432_date = ${morning_pk_time} )

select @min_time = (select ${min_time}  from T0432_data where C0401_aid = @acc_id
and C0432_date between ${from1} and ${to1} and C0432_status&8=8 and C0432_value_r=@min_value )

select @times = (select count(*) from  T0432_data where C0401_aid = @acc_id  and C0432_date between ${from1} and ${to1} and 
C0432_status&8=8  and C0432_value_r > @max_value-21 ) 

select ltrim(str(@acc_id,5,0))+'@'+'$name'+'@'+rtrim(@des_name)+'@'+ltrim(str(@max_value,8,2))+'@'+
rtrim(@src_nm)+'@'+ltrim(rtrim(@src_desc))+'@'+rtrim(@cable_cs)+'@'+ltrim(rtrim(str(@limit,5,0)))+'@'+
ltrim(str(C0432_status,4,0))+'@'+${day_form}+'@'+${time_form}+'@'+ltrim(str(@times,5,0))+'@'
+'${typ}'+'@'+ltrim(str(@avg_value,8,2))+'@'+ltrim(str(@min_value,8,2))+'@'+@min_time+'@'+ltrim(str(@pk_value,8,2))
+'@'+ltrim(str(@morning_pk_value,8,2))
from T0432_data where C0401_aid = @acc_id and C0432_value_r = @max_value and 
C0432_status&8=8 and C0432_date between ${from1} and ${to1}
 end
end
go"|$SYB_DIR/isql -I $sybase_path -S AEDC_SYSTEM -Udbu -Pdbudbu -w 200 | \
grep -v -e  "date" -e "-----"  -e "row"|grep -i [a-z]|sed 's/	//g'|head -1 >> $OUT_DIR/${FILE_NAME}.ld
done
awk 'FS="@"{print $7}' $OUT_DIR/${FILE_NAME}.ld | grep -v "^$" | sort -u | while read lim_name
 do
 grep -w $lim_name /aedc/cnf/scc/lim_set_cable_type | awk '{print $2}' | read ca_type
 sed "s/@${lim_name}@/@${ca_type}@/" $OUT_DIR/${FILE_NAME}.ld > $OUT_DIR/${FILE_NAME}.ld1
 mv $OUT_DIR/${FILE_NAME}.ld1 $OUT_DIR/${FILE_NAME}.ld
 done

compress $OUT_DIR/${FILE_NAME}.ld
cp $OUT_DIR/${FILE_NAME}.ld.Z $OUT_DIR2
}


#read  today?" Read  date  %Y/%m/%d:00:00:00"
today=`$UN_BIN/date +"%Y/%m/%d:00:00:00"`
to1=`$SCC_BIN/var_mktime ${today} '%Y/%m/%d:00:00:00'`
from1=`expr $to1 - 86400`
$SCC_BIN/var_asctime $from1 "%Y %m %d" | awk '{printf("%s\n%s\n%s",$1,$2,$3)}' | { read yyyy ; read mm ; read dd ; }
FILE_NAME=${yyyy}_${mm}_${dd}
OUT_DIR=${sub_outdir}/${yyyy}_${mm}
OUT_DIR2=`echo "$OUT_DIR"|sed "s@/home/sis/@/SYBASE/sub_home/@" `

for DIR in $OUT_DIR $OUT_DIR2
do
  if [ ! -d ${DIR} ]
  then
  mkdir ${DIR}
  fi
done

$SCC_BIN/var_asctime $to1 "%Y %m %d" | awk '{printf("%s",$3)}' |  read dd1 
main






