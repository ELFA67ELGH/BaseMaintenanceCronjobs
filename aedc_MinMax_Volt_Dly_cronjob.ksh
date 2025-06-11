#!/bin/ksh
# PURPOSE : to save  Daily AVG value for outgoing & incoming SS
# GROUP   : Alex. SCC IS
# AUTHOR  :  Alaa Nagy , Abeer M. Elsayed ( SCC SW )
# DATE    : 26 Sep 2011
##########################################################
. /aedc/etc/work/aedc/SCC/aedc_SCC_functions
/usr/local/sybase/dba/maint/setdbafct.ksh
dba_init_file=/usr/local/sybase/dba/maint/setdbaenv.ksh
export UN_BIN=/bin
export SCC_BIN=/aedc/etc/work/aedc/SCC/bin
export SYB_DIR=/usr/local/sybase/sybase1002/bin
sybase_path="/usr/local/sybase/sybase10/interfaces"
export BIN_ASCTIME=/aedc/bin
sub_outdir=/home/sis/REPORTS/Dly_MinMaxVOLT
sub_outdir2=/SYBASE/sub_home/REPORTS/Dly_MinMaxVOLT
tmpdir=/tmp/scc/Dly_Vlt


createDir ${sub_outdir}
createDir ${sub_outdir2}
createDir ${tmpdir}


offset="Jan 1 1970 02:00AM"
#offset="Jan 1 1970 03:00AM"
rm -f ${tmpdir}/PtLst

day_form="substring(convert(char(10),dateadd (second, C0432_date,'${offset}'),103),1,10)"
time_form="substring(convert(char(8),dateadd (second, C0432_date,'${offset}'),108),1,5)"
min_time="substring(convert(char(8),dateadd (second, max(C0432_date) ,'${offset}'),108),1,5)"
#IN_FILE1=/aedc/data/dbgen/SCC/SCC_ACC/SCCacc_15MIN_in_SS_VOLT.dat
#IN_FILE2=/aedc/data/dbgen/SCC/SCC_ACC/SCCacc_15MIN_in_DP_VOLT.dat

function main {
#grep -w NAME $IN_FILE1|grep -v ! |awk ' {printf ("%s@O_SS\n", $3 )}'  >${tmpdir}/PtLst
#grep -w NAME $IN_FILE2|grep -v ! |awk ' {printf ("%s@O_DP\n", $3 )}' >>${tmpdir}/PtLst
echo "
declare @alex_acc_id         int
declare @pk_time             time_t
declare @morning_pk_time     time_t
select  @alex_acc_id   = (select C0401_aid from T0401_accounts where C0401_name ='ALEX.TOTAL_MWA<HMAX' )
select  @pk_time	      = (select C0434_date from T0434_peak_data
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
select C0401_name from T0401_accounts where C0411_accnt_type=1 and C0401_state='A'
go"|$SYB_DIR/isql -I ${sybase_path} -S AEDC_SYSTEM -Udbu -Pdbudbu -w 200|
grep 15MIN| grep PT|awk '{print $1}'>${tmpdir}/PtInsAcc

grep "\-SS" ${tmpdir}/PtInsAcc|awk '{if(substr($1,1,2)=="P:")
{print $1"@O_SS"}else{print $1"@I_SS"}}'>${tmpdir}/PtLst
grep -v -e "\-SS" -e "\-DP"  ${tmpdir}/PtInsAcc|awk '{if(substr($1,1,2)=="P:")
{print $1"@O_SS"}else{print $1"@I_SS"}}'>>${tmpdir}/PtLst
grep "\-DP" ${tmpdir}/PtInsAcc|awk '{if(substr($1,1,2)=="P:")
{print $1"@O_DP"}else{print $1"@I_DP"}}'>>${tmpdir}/PtLst

sort -u  ${tmpdir}/PtLst  > ${tmpdir}/PtLst1
mv ${tmpdir}/PtLst1 ${tmpdir}/PtLst

if [[ -s  $OUT_DIR/${FILE_NAME}.Vlt.Z ]]
then
echo $OUT_DIR/${FILE_NAME}.Vlt.Z  already exist  it will moved to ${FILE_NAME}.Vlt-found
mv $OUT_DIR/${FILE_NAME}.Vlt.Z $OUT_DIR/${FILE_NAME}.Vlt.Z-found
fi

cat ${tmpdir}/PtLst |
while read name1 
do
echo ${name1} |awk ' FS="@" {print $1 }'|read name
echo ${name1} |awk ' FS="@" {print $2 }'|read typ
echo "
use aedcdb
go
set nocount on
set rowcount 1
declare @acc_id         int
declare @src_id         int
declare @des_name       varchar(50)
declare @min_time       varchar(5)
declare @max_value      float
declare @avg_value      float
declare @min_value      float
declare @pk_value              float	/* acc. value at the time of Alex peak */
declare @morning_pk_value      float	/* acc. value at the time of Alex morning peak */
declare @src_nm         varchar(30)
declare @src_desc       varchar(35)
declare @TXT            varchar(35)
declare @times          int

if not  exists ( select C0401_name   from T0401_accounts where C0401_name  like '$name' )
begin
select '@'+'$name'+'@Does Not Exist'
end

else
begin
select @acc_id   = (select C0401_aid from T0401_accounts where C0401_name ='$name' )
select @src_id   = (select C0401_source_id_int from T0401_accounts where C0401_name ='$name' )
select @des_name = (select C0401_description from T0401_accounts where C0401_name ='$name')
select @src_nm   = (select rtrim(C0003_group_name)+'.'+rtrim(C0007_point_name) 
from T0007_point where C0007_point_id =@src_id )

if not exists ( select C0432_value_r from T0432_data 
where C0401_aid = @acc_id and C0432_date between $from1 and $to1 and C0432_status&8=8 )
begin
select '@@@'+ltrim(str(@acc_id,5,0))+'@'+'$name'+'@'+rtrim(@des_name)+'@Bad@'
end

else
begin
if not exists ( select C0432_value_r from T0432_data 
where C0401_aid = @acc_id and C0432_date between $from1 and $to1 and C0432_status&8=8 and C0432_value_r > 1  )
begin
select '@@@'+ltrim(str(@acc_id,5,0))+'@'+'$name'+'@'+rtrim(@des_name)+'@Zero@'
end
else
begin
select @max_value = (select max(C0432_value_r)  from T0432_data where C0401_aid = @acc_id
and C0432_date between ${from1} and ${to1} and C0432_status&8=8 )

select @avg_value = (select avg(C0432_value_r)  from T0432_data where C0401_aid = @acc_id
and C0432_date between ${from1} and ${to1} and C0432_value_r > 5 and C0432_status&8=8  )

select @min_value = (select min(C0432_value_r)  from T0432_data where C0401_aid = @acc_id
and C0432_date between ${from1} and ${to1} and C0432_status &8=8 and C0432_value_r >5 )

select @pk_value = (select C0432_value_r from T0432_data where C0401_aid = @acc_id
and C0432_date = ${pk_time}     )

select @morning_pk_value = ( select C0432_value_r from T0432_data where C0401_aid = @acc_id
and C0432_date = ${morning_pk_time} )

select @min_time = (select ${min_time}  from T0432_data where C0401_aid = @acc_id
and C0432_date between ${from1} and ${to1} and C0432_value_r=@min_value )

select @times = (select count(*) from  T0432_data where C0401_aid = @acc_id  
and C0432_date between ${from1} and ${to1} and C0432_value_r > @max_value-.05   and C0432_status&8=8 ) 


select @TXT = (
select ltrim(str(C0432_status,4,0))+'@'+${day_form}+'@'+${time_form}+
'@'+ltrim(str(@times,5,0))+'@'+'${typ}'+'@'
from T0432_data where C0401_aid = @acc_id and C0432_value_r = @max_value and
C0432_date between ${from1} and ${to1} and C0432_status&8=8 

and C0432_date =( select max(C0432_date) from T0432_data where 
C0401_aid = @acc_id and C0432_value_r = @max_value and
C0432_date between ${from1} and ${to1} )
) 

select '@@@'+ltrim(str(@acc_id,5,0))+'@'+'$name'+'@'+rtrim(@des_name)+'@'+ltrim(str(@max_value,8,2))+'@'+
rtrim(@src_nm)+'@'+ltrim(rtrim(@src_desc))+@TXT+ltrim(str(@avg_value,8,2))+
'@'+ltrim(str(@min_value,8,2))+'@'+@min_time+'@'+
ltrim(str(@pk_value,8,2))
+'@'+ltrim(str(@morning_pk_value,8,2))
end 
end
end
go"|$SYB_DIR/isql -I ${sybase_path} -S AEDC_SYSTEM -Udbu -Pdbudbu |grep -e  "@" |
grep -i [a-z]|sed 's/@INST_VOLTAGE FOR /@/g'|head -1 |awk 'FS="@@@"{print substr($2,1,120)}'
done>${OUT_DIR}/${FILE_NAME}.Vlt

compress ${OUT_DIR}/${FILE_NAME}.Vlt
cp -p ${OUT_DIR}/${FILE_NAME}.Vlt.Z  ${OUT_DIR2}
}


#read  today?" Read today  %Y/%m/%d:00:00:00  >> "
today=`$UN_BIN/date +"%Y/%m/%d:00:00:00"`
to1=`$SCC_BIN/var_mktime ${today} '%Y/%m/%d:00:00:00'`
from1=`expr $to1 - 86400`
${SCC_BIN}/var_asctime $from1 "%Y %m %d" | awk '{printf("%s\n%s\n%s",$1,$2,$3)}' | { read yyyy ; read mm ; read dd ; }
FILE_NAME=${yyyy}_${mm}_${dd}
OUT_DIR=${sub_outdir}/${yyyy}_${mm}
OUT_DIR2=${sub_outdir2}/${yyyy}_${mm}
createDir ${OUT_DIR}
createDir ${OUT_DIR2}

$SCC_BIN/var_asctime $to1 "%Y %m %d" | awk '{printf("%s",$3)}' |  read dd1 
main






