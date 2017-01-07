#!/usr/bin/perl
###############################################################################
# Active Session Grapher for Oracle EE v1.2
#   Copyright 2016-2017 Mukojima Hideaki    twitter:@hideaki_zfs
#
#	v1.1:	1st release
#	v1.2:	add new option -b
#		bug fixed
#			-f
#			v$ -> gv$
#
#	https://github.com/HideZima/ashgraph
###############################################################################
use GD::Graph::mixed;
use File::Basename;
use Cwd 'realpath';
use Getopt::Std;
use strict;
my $script_ver=1.2;
my $bindir=realpath(dirname($0));              #/home/user/ashgraph
my $fullpath=realpath($0);                     #/home/user/ashgraph/ashgraph.pl
my $basename=basename($0);                     #
$basename=~s/(.*)\..*$/$1/;                    #ashgraph
my $sqlfile=${bindir}.'/'.$basename.'.sql';    #/home/user/ashgraph/ashgraph.sql

#command line parameters and default value ####################################
#-b           : Include background process (default; only fg process)
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
getopts("bc:d:h:i:f:s:vw:y:p:LT?",\%opt);
&print_help if $opt{'?'};                 #-?
$_core=$opt{'c'}   if defined($opt{'c'}); #-c
$_dur=$opt{'d'}    if defined($opt{'d'}); #-d
$_fname=$opt{'f'}  if defined($opt{'f'}); #-f
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
my $old_hm=0; 
my $old_sample_id=0;
my $sample_id_count=0;

$_dur.='/24'; #ash
my $iid_column='inst_id';
my $view_name='gv\$active_session_history';

open (my $ora,'-|','sqlplus -S '.$ARGV[1].'/'.$ARGV[2].'@'.$ARGV[0].' @'.${sqlfile}.' '.${_iid}.' '.${_dur}.' '.${iid_column}.' '.${view_name}) or die $!;
#open (my $ora, '<','testdata.txt');

while(<$ora>) {
	printf(STDERR "READ: %s",$_) if $opt{'v'};
	chomp;
        if (/^DATA--/) {
		$flag=1;
#DATA
	} elsif($flag) {
		my ($date,$sample_id,$wclass,$wcount,$sestype)=split(/\t/,$_);
		$wcount=0 if $sestype=~/BACKGROUND/ && ! $opt{'b'}; # default: foreground only

		my ($ymd,$hm)=split(/\s/,$date);
#		$hm=~s/:.*$//; #HH:MM(ash) -> HH (hash)
		if($old_sample_id != $sample_id && $old_sample_id != 0) {
			$sample_id_count++;
	 	}
		if($old_hm ne $hm && $old_hm || /^END---/) { #push to @data
			my ($yyyy,$mm,$dd)=split(/\//,$old_ymd); #hash
			push(@{$data[0]},$old_hm); #x-label "HH:MI"(ash)
			my $total; #total
			for(my $i=0;$i<13;$i++) {
				push(@{$data[$i+1]},$wclass_sum[$i]/$sample_id_count);
				$total+=$wclass_sum[$i];
			}
			$_ymax = ($total/$sample_id_count) if ($total/$sample_id_count) > $_ymax;
			push(@{$data[14]},$hd{'CPU_CORE'});
                        printf(STDERR "=> PUSH: %s (%s)/%d %d\n",$old_hm,join(',',@wclass_sum),$sample_id_count,$hd{'CPU_CORE'}) if $opt{'v'};
			@wclass_sum=();
			$sample_id_count=0;
			last if /^END---/;
		}	
		$wclass_sum[$wc{$wclass}]+=$wcount;
		$old_ymd=$ymd;
		$old_hm=$hm;
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
	$_fname="${basename}_$hd{'DBID'}_$hd{'NAME'}_$hd{'INSTANCE_NAME'}.png";
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
	return if -f ${sqlfile} && (stat(${sqlfile}))[9] > (stat(${fullpath}))[9];
	printf(STDERR "=> CREATE:%s %s > %s\n",${sqlfile},(stat(${sqlfile}))[9],(stat(${fullpath}))[9]) if $opt{'v'};
	open(my $sql,'>',${sqlfile}) or die $!;
	print $sql <<EOS;
rem version: ${script_ver}
set heading off
set lines 2000
set pages 0
set trimspool on
set colsep '	'
set feedback off
set verify off
col cpu_core_count_current for 999
select 'DBID:' || '	' || dbid from gv\$database;
select 'NAME:' || '	' || name from gv\$database;
select 'INSTANCE_NAME:' || '	' || instance_name from gv\$instance where inst_id = &1;
select 'VERSION:' || '	' || version from gv\$instance where inst_id = &1;
select 'CPU_CORE:' || '	' || cpu_core_count_current from gv\$license where inst_id = &1;
select 'CPU:' || '	' || cpu_count_current from gv\$license where inst_id = 61;
select 'DATA------' from dual;
col sample_time for A22
col sample_id for 9999999
col wait_class for A30
col wcount for 99999

select to_char(sample_time,'YYYY/MM/DD HH24:MI') || '	' || sample_id || '	' || nvl(wait_class,'ON CPU') || '	' || count(1) || '	' || session_type
from &4
where sample_time > (sysdate - &2) and
&3 = &1 
group by sample_time,sample_id,wait_class,session_type
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
        -b           : Include background process 
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
