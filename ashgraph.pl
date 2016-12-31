#!/usr/bin/perl
###############################################################################
# Active Session Grapher for Oracle EE v1.1 
#   Copyright 2016 Mukojima Hidaki
###############################################################################
use GD::Graph::mixed;
use File::Basename;
use Cwd 'realpath';
use Getopt::Std;
use strict;
my $version=1.1;
my $bindir=realpath(dirname($0));

#command line parameters and default value ####################################
#-c core      : CPU core for Oracle10g #
					my $_core=1;
#-d hour      : duration #
					my $_dur=1;
#-f filename  : output file name#
					my $_fname;
#-p directory : output directory #
					my $_outdir='./';
#-i inst_id   : inst_id for RAC #
					my $_iid=1;
#-s skip      : x_label_skip
					my $_xskip=15;
#-h pixel     : height #        
					my $_hpx=135; 
#-w pixel     : width #
					my $_wpx=500;
#-y value     : Y max value #
					my $_ymax=0; #AUTO
#-L           : No Legends #
#-T           : No Title #
					my $_title;
#-v           : Debug #

my $_y_tick_number = 5; #1..5 AUTO

my %opt = ();
getopts("c:d:h:i:f:s:vw:y:p:LT?",\%opt);
&print_help if $opt{'?'};                 #-?
$_core=$opt{'c'}   if defined($opt{'c'}); #-c
$_dur=$opt{'d'}    if defined($opt{'d'}); #-d
$_outdir=$opt{'p'} if defined($opt{'p'}); #-p
$_iid=$opt{'i'}    if defined($opt{'i'}); #-i
$_xskip=$opt{'s'}  if defined($opt{'s'}); #-s
$_hpx=$opt{'h'}    if defined($opt{'h'}); #-h
$_wpx=$opt{'w'}    if defined($opt{'w'}); #-w
$_ymax=$opt{'y'}   if defined($opt{'y'}); #-y

#Create convert wait_class strings to number hash #############################
my %wc = (
	'ON CPU'        , 0, 'Scheduler'     , 1,
	'User I/O'      , 2, 'System I/O'    , 3,
	'Concurrency'   , 4, 'Application'   , 5,
	'Commit'        , 6, 'Configuration' , 7,
	'Administrative', 8, 'Network '      , 9,
	'Queueing'      ,10, 'Cluster'       ,11,
	'Other'         ,12, 'CPUCore'       ,13
);

#Query ########################################################################
#create sql
&create_sql();
#graph data
# $data[ 0][0..] : Time Label
# $data[ 1][0..] : ON CPU
#  :     ^[$wc{'ON CPU'}+1]
# $data[13][0..] : Other
# $data[14][0..] : CPU Core (red border line)
my @data;
#header
my %hd;

#work
my $flag=0;
my @wclass_sum=(); 
my $old_ymd=0;
my $old_hms=0; 
my $old_sample_id=0;
my $sample_id_count=0;

open (my $ora,'-|','sqlplus -S '.$ARGV[1].'/'.$ARGV[2].'@'.$ARGV[0].' @'.${bindir}.'/ashgraph.sql '.${_iid}.' '.${_dur}) or die $!;
#open (my $ora, '<','testdata.txt');

while(<$ora>) {
	printf(STDERR "READ: %s",$_) if $opt{'v'};
	chomp;
        if (/^DATA--/) {
		$flag=1;
#DATA
	} elsif($flag) {
		my ($date,$sample_id,$wclass,$wcount)=split(/\t/,$_);
		my ($ymd,$hms)=split(/\s/,$date);
		if($old_sample_id != $sample_id && $old_sample_id != 0) {
			$sample_id_count++;
		}
		if($old_hms ne $hms && $old_hms || /^END---/) {
			push(@{$data[0]},$old_hms);
			my $total; #total
			for(my $i=0;$i<13;$i++) {
				push(@{$data[$i+1]},$wclass_sum[$i]/$sample_id_count);
				$total+=$wclass_sum[$i];
			}
			$_ymax = ($total/$sample_id_count) if ($total/$sample_id_count) > $_ymax;
			push(@{$data[14]},$hd{'CPU_CORE'});
                        printf(STDERR "=> PUSH: %s (%s)/%d %d\n",$old_hms,join(',',@wclass_sum),$sample_id_count,$hd{'CPU_CORE'}) if $opt{'v'};
			@wclass_sum=();
			$sample_id_count=0;
			last if /^END---/;
		}	
		$wclass_sum[$wc{$wclass}]+=$wcount;
		$old_ymd=$ymd;
		$old_hms=$hms;
		$old_sample_id=$sample_id;
#HEADER
	} else { #header into $hd hush
		my ($idx,$val)=split(/:/,$_);
		$idx=~s/\s//g;
		$val=~s/\s//g;
		$hd{$idx}=$val;
		if ($idx eq 'CPU_CORE' && $val < 1) {
			$hd{'CPU_CORE'} = $_core;  #-c 
		}
	}
}
close $ora;

# set values ##################################################################

if (defined($opt{'f'})) {
	$_fname=$opt{'f'} if defined($opt{'f'}); # -f
} else {
	$_fname="ashgraph_$hd{'DBID'}_$hd{'NAME'}_$hd{'INSTANCE_NAME'}.png";
}

 #-T
$_title=$hd{'NAME'}.':'.$hd{'INSTANCE_NAME'}.' '.$old_ymd unless($opt{'T'});  #-T

$_ymax=$hd{'CPU_CORE'} if $_ymax < $hd{'CPU_CORE'};
$_ymax=$opt{'y'} if defined($opt{'y'}); # -y
$_y_tick_number=$_ymax if $_ymax < 5;

#print Dumper \@data;

# setup legend labels #########################################################
my @legend = qw(
	CPU         Scheduler UserIO        SystemIO       Concurrency 
	Application Commmit   Configuration Administrative Network 
	Queueing    Cluster   Other         CPUCore
);

# get graph object             W      H
my $graph = GD::Graph::mixed->new($_wpx, $_hpx); #-w -h

# set graph legend
$graph->set_legend(@legend) unless $opt{'L'};  #  -L

# set graph options 
$graph->set(
	'types' => [ qw( area area area area area area area area area area
			 area area area lines )],
#color
	'dclrs'            => [ qw(#00cc00 #ccffcc #004ae7 #0094e7 #8b1a00 
			  	   #c02800 #e46800 #5c440b #717354 #9f9371
				   #c2b79b #c9c2af #f06eaa red ) ],
	'borderclrs'       => [ qw(#00cc00 #ccffcc #004ae7 #0094e7 #8b1a00 
				   #c02800 #e46800 #5c440b #717354 #9f9371 
				   #c2b79b #c9c2af #a0a0a0 red ) ],
	'fgclr'            => 'lgray',
	'title'            => $_title,
	'y_label'          => 'Act.Sess.',
	'x_label_skip'     => $_xskip,
	'long_ticks'       => 1, 
	'cumulate'         => 1,
	'bgclr'            => 'white',
	'transparent'      => 0,
	'y_tick_number'    => $_y_tick_number,
	'y_number_format'  => '%d',
	'y_max_value'      => $_ymax,  
	'x_labels_vertical'=> 1,
	'zero_axis'        => 1,
	'lg_cols'          => 7,
	'legend_placement' => 'RB',
	'legend_spacing' => 0.8,
	'legend_height' => '5',
	'lg_cols'          => 0,
);

$graph->plot(\@data);

# draw graph file #############################################################
open(my $png,'>',${_outdir}.'/'.${_fname}) or die "Cannot open ${_outdir}/${_fname} for write: $!";
binmode $png;
print $png $graph->gd->png();
close $png;

exit 0;
#Subroutins ###################################################################
sub create_sql {
return if -f ${bindir}.'/ashgraph.sql'; 
open(my $sql,'>',${bindir}.'/ashgraph.sql') or die $!;
print $sql <<EOS;
rem Usage: ashgraph.sql Inst_ID Duration
set heading off
set lines 2000
set pages 0
set trimspool on
set colsep '	'
set feedback off
set verify off
col cpu_core_count_current for 999
select 'DBID:' || '	' || dbid from v\$database;
select 'NAME:' || '	' || name from v\$database;
select 'INSTANCE_NAME:' || '	' || instance_name from v\$instance;
select 'VERSION:' || '	' || version from v\$instance;
select 'CPU_CORE:' || '	' || cpu_core_count_current from v\$license;
select 'CPU:' || '	' || cpu_count_current from v\$license;
select 'DATA------' from dual;
col sample_time for A22
col sample_id for 9999999
col wait_class for A30
col wcount for 99999

select to_char(sample_time,'YYYY/MM/DD HH24:MI') || '	' || sample_id || '	' || nvl(wait_class,'ON CPU') || '	' || count(1)
from gv\$active_session_history
where session_type = 'FOREGROUND' and
sample_time > (sysdate - &2/24) and
inst_id = &1
group by sample_time,sample_id,wait_class
order by sample_time;
select 'END-------' from dual;
quit;
EOS
close $sql;
}

sub print_help {
	print STDERR <<EOH;
Usage: ashgraph.pl [-options]  DBServiceName User Password;
Output file name: 
	ashgraph_DBID_DBNAME_INSTANCENAME.png
Options:
	-c core      : CPU core for Oracle10g 
	-d hour      : duration  
	-f filename  : output file name 
	-p directory : output directory 
	-i inst_id   : inst_id for RAC 
	-s skip      : X label skip
	-h pixel     : height         
	-w pixel     : width 
	-y value     : Y max value 
	-L           : No Legends 
	-T           : No Title 
	-?           : Help 
EOH
exit 1;
}
