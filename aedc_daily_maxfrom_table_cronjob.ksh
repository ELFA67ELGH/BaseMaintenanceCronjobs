#!/bin/ksh
#-------------------------------------------------------------------------------
# TITLE   : aedc_daily_maxfrom_table_cronjob.ksh
# PURPOSE : Automatically save data of account in  SCCacc_HMAX_in_SS_AMP.dat
# and save it in /home/sis/REPORTS/DAILY_MAX_VALUE with file name by date
# PURPOSE : to save data of account in  SCCacc_HMAX_in_SS_AMP.dat
# GROUP   : IS
# AUTHOR  : Alaa Nagy , Abeer Elsayed ( SCC S/W )
# DATE    : 11 june 2003 
##########################################################
echo "starting aedc_daily_maxfrom_table_crontab.ksh"
. /aedc/etc/work/aedc/SCC/aedc_SCC_functions
dba_init_file=/usr/local/sybase/dba/maint/setdbaenv.ksh
/usr/local/sybase/dba/maint/setdbafct.ksh
SCCTMP=/aedc/tmp/scc/aedc/cronjob
export SCCTMP=/aedc/tmp/scc/aedc/cronjob

if [ ! -d ${SCCTMP} ]
then
mkdir ${SCCTMP}
fi
export UN_BIN=/bin
export SCC_BIN=/aedc/etc/work/aedc/SCC/bin
export SYB_DIR=/usr/local/sybase/sybase1002/bin
sybase_path="/usr/local/sybase/sybase10/interfaces"
cp /dev/null  ${SCCTMP}/total_lst   
cp /dev/null  ${SCCTMP}/tot_dt 
offset="Jan  1 1970 02:00AM"  
DAY_LIM="substring(convert(char(10),dateadd(second,C0434_date,'${offset}'),08),1,2)"

function main {
cat /aedc/data/dbgen/SCC/SCC_ACC/SCCacc_HMAX_in_SS_AMP.dat \
    /aedc/data/dbgen/SCC/SCC_ACC/SCCacc_HMAX_in_NT_SS_AMP.dat \
    /aedc/data/dbgen/SCC/SCC_ACC/SCCacc_HMAX_in_NT_SS_sumAMP.dat \
    /aedc/data/dbgen/SCC/SCC_ACC/SCCacc_HMAX_in_SS_sumAMP.dat \
    /aedc/data/dbgen/SCC/SCC_ACC/SCCacc_HMAX_in_SS_KW.dat  \
    /aedc/data/dbgen/SCC/SCC_ACC/SCCacc_HMAX_in_NT_SS_KW.dat  \
    /aedc/data/dbgen/SCC/SCC_ACC/SCCacc_HMAX_in_SS_sumMW.dat \
    /aedc/data/dbgen/SCC/SCC_ACC/SCCacc_HMAX_in_NT_SS_sumMW.dat \
    /aedc/data/dbgen/SCC/SCC_ACC/SCCacc_HMAX_in_SS_MVA.dat  \
    /aedc/data/dbgen/SCC/SCC_ACC/SCCacc_HMAX_in_NT_SS_MVA.dat  \
    /aedc/data/dbgen/SCC/SCC_ACC/SCCacc_HMAX_in_SS_sumMVA.dat \
    /aedc/data/dbgen/SCC/SCC_ACC/SCCacc_HMAX_in_NT_SS_sumMVA.dat|
    grep -w NAME | grep -v "!" | awk '{printf ("%s\n", $3 )}' | sort -u > ${SCCTMP}/acc_list

grep  "ALEX.TOTAL"  ${SCCTMP}/acc_list > ${SCCTMP}/acc_list1
grep -e "EAST.TOTAL" -e "MIDDLE.TOTAL" -e "WEST.TOTAL" ${SCCTMP}/acc_list|
grep -v -e "EAST.TOTAL_MWA<HMAX" -e  "MIDDLE.TOTAL_MWA" -e "WEST.TOTAL_MWA<HMAX" >> ${SCCTMP}/acc_list1
print "EAST.TOTAL_MWA<HMAX\nMIDDLE.TOTAL_MWA<HMAX\nWEST.TOTAL_MWA<HMAX" >>${SCCTMP}/acc_list1
grep -v -e "ALEX.TOTAL" -e "EAST.TOTAL" -e "MIDDLE.TOTAL" -e "WEST.TOTAL" ${SCCTMP}/acc_list >> ${SCCTMP}/acc_list1
mv ${SCCTMP}/acc_list1 ${SCCTMP}/acc_list
grep "\.TOTAL"  ${SCCTMP}/acc_list  > ${SCCTMP}/total_lst

cat ${SCCTMP}/total_lst|while read tot
do
echo ${tot}|awk 'FS="."{print $1}'|read nm

echo "
declare @id_tot		int
declare @max_value	float
declare @At_Max		int

declare @max_value_DAY	float
declare @At_Max_DAY	int

select  @id_tot=(select C0401_aid from T0401_accounts where C0401_name ='${tot}')
select  @max_value=(select max(C0434_value)  from T0434_peak_data where C0401_aid=@id_tot
		    and C0434_time_of_occurrence between $from1 and $to1 and C0434_status&8=8)

select  @max_value_DAY=(select max(C0434_value)  from T0434_peak_data where C0401_aid=@id_tot
			and C0434_time_of_occurrence between $from1 and $to1 and C0434_status&8=8 and ${DAY_LIM} 
			in ( '08' ,'09','10','11','12','13' ,'14'))

select @At_Max=(select max(C0434_date) from T0434_peak_data where
		C0401_aid=@id_tot and C0434_value=@max_value
		and C0434_time_of_occurrence between $from1 and $to1)

select @At_Max_DAY=(select max(C0434_date) from T0434_peak_data where
		    C0401_aid=@id_tot and C0434_value=@max_value_DAY and $DAY_LIM
		    in ( '08' ,'09','10','11','12','13' ,'14') 
		   and C0434_time_of_occurrence between $from1 and $to1 )

select substring('${tot}',1, patindex('%.%','${tot}')-1) , str(@max_value,10,2) , @At_Max ,
str(@max_value_DAY,10,2) , @At_Max_DAY
go"|$SYB_DIR/isql -I $sybase_path -S AEDC_SYSTEM -Udbu -Pdbudbu|grep "${nm}"  
done >  ${SCCTMP}/tot_dt


if [[ -s  ${OUT_DIR}/${FILE_NAME}.ld.Z ]]
then
if [[ -s  ${OUT_DIR}/${FILE_NAME}-found.ld.Z ]]
then
echo ${OUT_DIR}/${FILE_NAME}-found.ld.Z is exist
else 
echo " $OUT_DIR/${FILE_NAME}.ld.Z  already exist . 
It will moved to ${FILE_NAME}.ld-found.Z"

mv $OUT_DIR/${FILE_NAME}.ld.Z $OUT_DIR/${FILE_NAME}.ld-found.Z
fi
fi

frst=on
echo "ALEX.TOTAL_MWA<HMAX" >${SCCTMP}/acc_list1
grep -v "ALEX.TOTAL_MWA<HMAX" ${SCCTMP}/acc_list >>${SCCTMP}/acc_list1
mv     ${SCCTMP}/acc_list1 ${SCCTMP}/acc_list
                                              
cat ${SCCTMP}/acc_list |while read name
do
if [[ ! -z "`echo ${name} |grep CT`" || ! -z "`echo $name |grep TOTAL_AMP|grep -v "-"`" ]]
then
PF=YES
else 
PF=NO
fi
echo $name |awk 'FS="<"{print $1 }'|read point
echo  $point|sed 's/P://'|read pnt
echo $point|sed 's/NN\./\./;s/3E\./3\./;s/8E\./8\./;s/P://'|sed 's/N\./\./'|sed "s/W-SS1/W-SS1N/"|awk 'FS="."{print $1}' |read SS
grep -w "${SS}" ${SCCTMP}/tot_dt |awk '{print $3-3600}'|read SS_max_Date
grep -w "${SS}" ${SCCTMP}/tot_dt |awk '{print $5-3600}'|read SS_max_Date_DAY
echo $SS_max_Date |awk '{print $1+2700}'|read  SS_max_Date_ins
echo $SS_max_Date_DAY|awk '{print $1+2700}'|read SS_max_Date_DAY_ins

#echo ${SS_max_Date} .........here the date  for $SS SS

if [ ${frst} = "on" ]
then
#echo $name 
echo "
set nocount on
declare @acc_id    	int 		/* The ID of current account */
declare @max_value   	float		/* Max good value for current account during the report period */
declare @min_value   	float		/* Min good value for current account during the report period  */

select @acc_id  = (select C0401_aid from T0401_accounts where C0401_name ='$name' )
  if exists ( select * from T0434_peak_data
  where C0401_aid = @acc_id
  and C0434_time_of_occurrence between $from1 and $to1) 

begin
select @max_value = max(C0434_value)  , @min_value = min(C0434_value) from T0434_peak_data where C0401_aid = @acc_id 
and C0434_time_of_occurrence between ${from1} and ${to1} and C0434_status&8=8 

select C0434_date ,C0434_value from T0434_peak_data where C0401_aid =@acc_id
and C0434_value in (@max_value , @min_value) and C0434_time_of_occurrence between ${from1} and ${to1} and C0434_status&8=8 
order by C0434_value desc
end
go"|$SYB_DIR/isql -I $sybase_path -S AEDC_SYSTEM -Udbu -Pdbudbu -w 150 |
  head -4 | tail -2 | awk '{print $1}' | { read AlexMax_at ; read AlexMin_at ;} 
fi



echo ${AlexMax_at}|awk '{print $1-3600}'|read AlexMax_at_prev

echo "
set rowcount 1
go
declare @des_name  	varchar(30)	/* The description of current account */
declare @ass_name  	varchar(30)	/* The associated_point name of current account */
declare @acc_id    	int 		/* The ID of current account */
declare @rec_cnt   	int		/* Number of recorded data for current account during the report period */
declare @max_value   	float		/* Max good value for current account during the report period */
declare @min_value   	float		/* Min good value for current account during the report period  */
declare @max_cou   	int		/* Number of repetations of Max. value */
declare @min_cou   	int		/* Number of repetations of Min. value */
declare @nxt_hr    	int		/* Hour of Max. value for current account */
declare @min_nxt_hr    	int		/* Hour of Min. value for current account */
declare @mva_value   	float		/* Corresponding MVA value at Hour of Max. value for current account */
declare @min_mva_value  float		/* Corresponding MVA value at Hour of Min. value for current account */
declare @val_atMaxAlex	float		/* Current account value at Alex Max peak */
declare @val_atMinAlex	float		/* Current account value at Alex Min peak */
declare @ins_acc_id    	int 		/* The ID of HINS account */
declare @ins_value   	float		/* INS good value for current account during the report period  */
declare @ins_atMaxAlex	float		/* Inst. account value at Alex Max peak */
declare @ins_atMinAlex	float		/* Inst.  account value at Alex Min peak */
declare @avg_value   	float		/* AVGERGE good value for current account  */

declare @max_occ_t	int
declare @min_occ_t	int
declare @max_st		int
declare @min_st		int
declare @max_ass_st	int
declare @min_ass_st	int

declare @hmax_Atssmax   float		/* HMAX Value At max SS TOTAl load  current account  */
declare @ins_Atssmax   	float		/* Value At max SS TOTAl load  current account  */

declare @hmax_Atssmax_DAY float		/* HMAX Value At max SS TOTAl load  current account from 8-14  mornning */
declare @ins_Atssmax_DAY  float		/* Value At max SS TOTAl load  current account  from 8-14 mornning */

declare @acc_PF_NM	varchar(30)
declare @acc_PF_id	int
declare	@PF_value 	float
  
if exists ( select C0401_name   from T0401_accounts where C0401_name like '${name}' )
  begin 

select @acc_id	= C0401_aid , @des_name = C0401_description from T0401_accounts where C0401_name ='$name'
select @ins_acc_id  = (select C0401_aid from T0401_accounts where C0401_name ='${pnt}<INST' )

if exists ( select C0434_time_of_occurrence from T0434_peak_data where C0401_aid = @acc_id
and C0434_time_of_occurrence between $from1 and $to1) 

begin
select @ass_name = rtrim((select C0007_point_name from T0007_point where
C0007_point_id in (select C0402_assoc_pid from T0402_peak_account where C0401_aid =@acc_id )))

select @rec_cnt = count(*),@max_value=max(C0434_value),@min_value=min(C0434_value),
@avg_value = avg(C0434_value) 
from T0434_peak_data where C0401_aid = @acc_id and C0434_value >0 
and C0434_time_of_occurrence between ${from1} and ${to1} and C0434_status&8=8

select @max_cou = count(*) ,@nxt_hr=(max(C0434_time_of_occurrence)/3600+1)*3600
from T0434_peak_data where C0401_aid = @acc_id 
and C0434_time_of_occurrence between ${from1} and ${to1} and C0434_value=@max_value

select @max_occ_t= C0434_time_of_occurrence ,@max_ass_st = C0434_assoc_status,
@max_st=C0434_status from T0434_peak_data where C0401_aid = @acc_id 
and C0434_time_of_occurrence between ${from1} and ${to1} and C0434_value=@max_value

select @min_cou=count(*) , @min_nxt_hr=(max(C0434_time_of_occurrence)/3600+1)*3600 
from T0434_peak_data where C0401_aid = @acc_id
and C0434_time_of_occurrence between ${from1} and ${to1} and C0434_value = @min_value

select @min_occ_t = C0434_time_of_occurrence ,
@min_ass_st = C0434_assoc_status,@min_st= C0434_status from T0434_peak_data where C0401_aid = @acc_id
and C0434_time_of_occurrence between ${from1} and ${to1} and C0434_value = @min_value

select @mva_value=(select C0434_value from T0434_peak_data where C0401_aid in (select C0401_aid  from T0401_accounts 
where C0401_name =substring('$name',patindex('%:%','$name')+1,patindex('%.%','$name')-patindex('%:%','$name'))+rtrim(@ass_name)+'<HMAX' )
and C0434_date=@nxt_hr)

select @min_mva_value=(select C0434_value from T0434_peak_data 
where C0401_aid in (select C0401_aid  from T0401_accounts 
where C0401_name =substring('$name',patindex('%:%','$name')+1,patindex('%.%','$name')-patindex('%:%','$name'))+rtrim(@ass_name)+'<HMAX' )
and C0434_date=@min_nxt_hr)

select @val_atMaxAlex=(select C0434_value from T0434_peak_data  
where C0401_aid = @acc_id and C0434_date = $AlexMax_at )

select @val_atMinAlex=(select C0434_value from T0434_peak_data  
where C0401_aid = @acc_id and C0434_date = $AlexMin_at )

select @ins_atMaxAlex=(select max(C0432_value_r) from T0432_data  
where C0401_aid = @ins_acc_id and C0432_date in ( ${AlexMax_at} ,${AlexMax_at_prev} )  )

select @ins_atMinAlex=(select C0432_value_r from T0432_data  
where C0401_aid = @ins_acc_id and C0432_date = $AlexMin_at )

select @hmax_Atssmax=(select C0434_value from T0434_peak_data  
where C0401_aid = @acc_id and C0434_date = ${SS_max_Date} )

select @ins_Atssmax=(select C0432_value_r from T0432_data  
where C0401_aid = @ins_acc_id and C0432_date = ${SS_max_Date_ins} )

select @hmax_Atssmax_DAY =(select C0434_value from T0434_peak_data  
where C0401_aid = @acc_id and C0434_date = ${SS_max_Date_DAY})

select @ins_Atssmax_DAY =(select C0432_value_r from T0432_data  
where C0401_aid = @ins_acc_id and C0432_date = ${SS_max_Date_DAY_ins} )

/* select ${SS_max_Date}   ,@hmax_Atssmax   , @ins_Atssmax */
 
/* select  @PF_value = 00 */
if exists ( select * where '${PF}'='YES')
begin
select @acc_PF_NM  = (select substring('$name',patindex('%:%','$name')+1,patindex('%.%','$name')-patindex('%:%','$name'))+stuff(@ass_name,patindex('%MVA%',@ass_name),3,'PF')+'<INST' )
select @acc_PF_id  = (select C0401_aid from T0401_accounts where C0401_name = @acc_PF_NM )
select @PF_value   = (select avg(C0432_value_r) from T0432_data where 
C0401_aid = @acc_PF_id and C0432_date between ${from1} and ${to1}  and C0432_status&8=8  and C0432_value_r <> 0 )
end

select 						/* >>> Max. record <<< */
rtrim(ltrim(str(@acc_id,5)))+'@'+		/* 1)  account ID */
'${name}'+'@'+					/* 2)  account name */
rtrim(@des_name)+'@'+				/* 3)  account description */
ltrim(str(@max_value,8,2))+'@'+			/* 4)  account max value */
ltrim(str(@max_occ_t,12))+'@'+			/* 5)  occurance time of max value */
rtrim(@ass_name)+'@'+				/* 6)  associated point name */
ltrim(str(@mva_value,8,2))+'@'+			/* 7)  MVA value (value from max acc of associated point at @nxt_hr */
ltrim(str(@max_cou,3))+'@'+			/* 8)  Number of repetations of Max. value */
'${mm}'+'@'+					/* 9)  mounth */
'${yyyy}'+'@'+					/* 10) year */
ltrim(str(@rec_cnt,5))+'@'+			/* 11) Number of recorded data for current account during the report period */
ltrim(str(@max_st,3))+'@'+			/* 12) status of max. acc. value */
ltrim(str(@max_ass_st,3))+'@@'+			/* 13) status of accociated point value */
						/* 14) .. reserved place for Min record .. */
ltrim(str(@val_atMaxAlex,8,2))+'@'+		/* 15) Current account value at Alex Max peak */
ltrim(str(@ins_atMaxAlex,8,2))+'@'+		/* 16) Inst. account value at Alex Max peak */
ltrim(str(@avg_value,8,2))+'@'+			/* 17) AVGERGE good value for current account  */
ltrim(str(@hmax_Atssmax,8,2))+'@'+		/* 18) HMAX Value At max SS TOTAl load  current account  */
ltrim(str(@ins_Atssmax,8,2))+'@'+		/* 19) Value At max SS TOTAl load  current account  */
ltrim(str(@hmax_Atssmax_DAY,8,2))+'@'+		/* 20) HMAX Value At max SS TOTAl load  current account from 8-14  mornning */
ltrim(str(@ins_Atssmax_DAY,8,2))+'@'+		/* 21) Value At max SS TOTAl load  current account  from 8-14 mornning */
ltrim(str(${SS_max_Date_DAY},10,0))+'@'+	/* 22)  */
ltrim(str(@PF_value,10,4))			/* 23)  */


select 						/* >>> Min. record <<< */
rtrim(ltrim(str(@acc_id,5)))+'@'+		/* 1)  account ID */
'$name'+'@'+					/* 2)  account name */
rtrim(@des_name)+'@'+				/* 3)  account description */
ltrim(str(@min_value,8,2))+'@'+			/* 4)  account min value */
ltrim(str(@min_occ_t,12))+'@'+			/* 5)  occurance time of min value */
rtrim(@ass_name)+'@'+				/* 6)  associated point name */
ltrim(str(@min_mva_value,8,2))+'@'+		/* 7)  min.MVA value (value from max acc of associated point at @min_nxt_hr */
ltrim(str(@min_cou,3))+'@'+			/* 8)  Number of repetations of Min. value */
'${mm}'+'@'+					/* 9)  mounth */
'${yyyy}'+'@'+					/* 10) year */
ltrim(str(@rec_cnt,5))+'@'+			/* 11) Number of recorded data for current account during the report period */
ltrim(str(@min_st,3))+'@'+			/* 12) status of min. acc. value */
ltrim(str(@min_ass_st,3))+			/* 13) status of accociated point value (assocciated with min.) */
'@MINIMUM'+'@'+					/* 14) .. 'MINIMUM' .. */
ltrim(str(@val_atMinAlex,8,2))+'@'+		/* 15) Current account value at Alex Min peak */
ltrim(str(@ins_atMinAlex,8,2))			/* 16) Inst. account value at Alex Min peak */

end  
	else
	print '@${name}@The date out of range '
	end
else
print ' @${name}@has NO HMAX acct ' 
go"|$SYB_DIR/isql -I $sybase_path -S AEDC_SYSTEM -Udbu -Pdbudbu -w 250 |grep -v -e \
 "date" -e "-----" -e "row"|grep -i [a-z]|sed 's/	//g'|sed 's/   //g' >  $SCCTMP/record
if [[ ! -s $SCCTMP/record ]]
then
echo " 
declare @ass_name  	varchar(30)	
declare @acc_id    	int 	

select @acc_id  = (select C0401_aid from T0401_accounts where C0401_name ='$name' )
select @ass_name = rtrim((select C0007_point_name from T0007_point where
C0007_point_id in (select C0402_assoc_pid from T0402_peak_account where C0401_aid =@acc_id )))

select  str(@acc_id,6,0)+'@'+'${name}'+'@'+rtrim(C0401_description)+'@'+'May has BAD Status'+'@@'+rtrim(@ass_name)+'@'
from T0401_accounts where C0401_name ='$name'
go"|$SYB_DIR/isql -I $sybase_path -S AEDC_SYSTEM -Udbu -Pdbudbu -w 200 |grep "${name}"|sed 's/	//g'|sed 's/   //g'>> ${OUT_DIR}/${FILE_NAME}.ld
else
cat $SCCTMP/record >> ${OUT_DIR}/${FILE_NAME}.ld
fi


frst=off
done
compress ${OUT_DIR}/${FILE_NAME}.ld
cp ${OUT_DIR}/${FILE_NAME}.ld.Z ${OUT_DIR2}
}

function daily_prep {
$SCC_BIN/var_asctime $from1 "%Y %m %d" | awk '{printf("%s\n%s\n%s",$1,$2,$3)}' | { read yyyy ; read mm ; read dd ; }
FILE_NAME=${yyyy}_${mm}_${dd}
echo "Working on $FILE_NAME ... "
sub_outdir=/home/sis/REPORTS/DAILY_MAX_VALUE
OUT_DIR=${sub_outdir}/${yyyy}_${mm}
OUT_DIR2=`echo "$OUT_DIR"|sed "s@/home/sis/@/SYBASE/sub_home/@" `

for Dir in $OUT_DIR $OUT_DIR2
do
  if [ ! -d $Dir ]
  then
   mkdir $Dir
  fi
done

}

function monthly_prep {
OUT_DIR=/home/sis/REPORTS/MONTHLY_MAX_VALUE/${yyyy}
/aedc/etc/work/aedc/SCC/bin/var_mktime ${yyyy}/${mm}/01:00:00:01 '%Y/%m/%d:%H:%M:%S'|read from1
FILE_NAME=${yyyy}_${mm}
echo "Working on $FILE_NAME ... "
OUT_DIR2=`echo "$OUT_DIR"|sed "s@/home/sis/@/SYBASE/sub_home/@" `

for Dir in $OUT_DIR $OUT_DIR2
do
  if [ ! -d $Dir ]
  then
    mkdir $Dir
  fi
done

}

function Usage {
echo "Usage	: $1 [ -o YYYY/mm/dd ] [ -auto ]
    Where	yyyy/mm/dd : date of required output
    		-auto : run the report automaticaly
		
Note : running the report without parameters 
       let you enter to the user interface mode"

exit       
}

##################
# START OF SCRIPT
##################

#======================================================================================================================================
# Out file will be on the next form for each current account :
#
#  1   @   2    @   3    @   4    @     5     @      6     @    7    @     8         @   9   @     10      @  11  @    12
#acc_id@acc_name@acc_desc@Maxvalue@tm_of_occur@ass_pnt_name@mva_value@numbr_of_MAXval@mm@yyyy@numbr_of_data@status@ass_status
#acc_id@acc_name@acc_desc@Minvalue@tm_of_occur@ass_pnt_name@mva_value@numbr_of_MAXval@mm@yyyy@numbr_of_data@status@ass_status@MINIMUM
#======================================================================================================================================


#select @nxt_hr=(select C0434_time_of_occurrence from T0434_peak_data where C0401_aid = @acc_id
#and C0434_time_of_occurrence between ${from1} and ${to1}  and C0434_status&8=8 order by C0434_value desc , C0434_date desc)
#select @nxt_hr

# usage $0 [yyyy/mm/dd] (required day report)
if [ $# -gt 0 ]
then
 case $1 in
 "-o")
  if [ `mktime ${2}:00:00:00` -gt 883605600 ] && [ `mktime ${2}:00:00:00` -lt 1893448800 ]
   # $2 in the required format between 1998,2030
  then
    dayrep=`echo $2 | cut -c 1-10`
    mktime ${dayrep}:00:00:00 | read from1
    to1=`expr $from1 + 86400 - 3600`
   # /aedc/bin/mktime ${dayrep}:00:00:00 |read asc_dayRepStrt
   # asc_todayStrt=`expr $asc_dayRepStrt + 86400`
   # today=`$SCC_BIN/var_asctime ${asc_todayStrt} '%Y/%m/%d:00:00:00'`
   # /aedc/bin/mktime $today |read asc_today
   # from1=`expr $asc_today - 86400`
   # to=`$SCC_BIN/var_mktime ${today} '%Y/%m/%d:00:00:00'`
   # to1=`expr $to - 3600`
    daily_prep
    main
  else
  Usage $0
  fi		#if $2 in the required format between 1998,2030
 ;;
 "-auto")
  today=`$UN_BIN/date +"%Y/%m/%d:00:00:00"`
  /aedc/bin/mktime $today |read asc_today
  from1=`expr $asc_today - 86400` 
  to1=`expr $from1 + 86400 - 3600`
  daily_prep
  main
  $UN_BIN/date +'%d'| read d0
    if [ ${d0} = 01 ]
    then
    monthly_prep
    main
    fi
  ;;
  *) 
  Usage $0
  ;;
 esac		#case $1
  

else		#if [ $# -gt 0 ]
  today=`$UN_BIN/date +"%Y/%m/%d:00:00:00"`
  read rep_type?"  Enter report type that you want
	D ) daily
	M ) monthly
	O ) other range
   your choice >> "

      case `echo $rep_type | awk '{print toupper(substr($0,1,1))}'` in
       D)
       expr `mktime $today` - 86400 | read from1
       sugg=`${SCC_BIN}/var_asctime $from1 '%Y/%m/%d'`
       read from?"    enter the date from like < ${sugg} >  : "
	  if [ -z "$from" ]
	  then
	  from=$sugg
	  fi
       mktime ${from}:00:00:00  |read from1
       mktime ${from}:23:00:00  |read to1
       mktime `$UN_BIN/date +'%Y/%m/%d:00:00:00'` | read today_sec
          if [ "`expr $today_sec - $from1`" -lt 3024000 ]		# 35day = 3024000sec
          then
             echo "Create Daily file `/aedc/etc/work/aedc/SCC/bin/var_asctime $to1 '%Y_%m_%d.ld'`"
             daily_prep
             main
          else
          echo "Sorry ..Retenion Period < 35 Days `/aedc/etc/work/aedc/SCC/bin/var_asctime $to1 '%Y_%m_%d.ld'` .. !!"
          fi
       ;;
       M)
       var_mktime `date +'%Y/%m'`/01:00:00:00 '%Y/%m/%d:%H:%M:%S' |
	        awk '{print $1-1}' | read to1
       var_asctime $to1 '%Y/%m'| 
	        awk 'FS="/",OFS="\n"{print $1,$2}' | { read yyyy ; read mm ; }
          if [ ${d0} -le 05 ]
          then
            echo "Create Monthly file  `/aedc/etc/work/aedc/SCC/bin/var_asctime $to1 '%b %Y'`"
            monthly_prep
            main
          else
            echo "Sorry its too late to prepare the monthly report for `/aedc/etc/work/aedc/SCC/bin/var_asctime $to1 '%Y_%m.ld'` .. !!"
          fi

       ;;
       O)
       read from?"    enter the date from like yyyy/mm/dd  >> "
       read to?"    enter the date to like yyyy/mm/dd  >> "
       mktime ${from}:00:00:00  |read from1
       mktime ${to}:23:00:00    |read to1
       OUT_DIR=$SCCTMP
       FILE_NAME=maxfrom_table_rep
       echo preparing maxfrom_table report to the output file ${OUT_DIR}/${FILE_NAME}.ld
       main
       ;;
      esac

fi		#if [ $# -gt 0 ]




