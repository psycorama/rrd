#!/usr/bin/perl
#
# RRD script to display system load
# 2003 (c) by Christian Garbs <mitch@cgarbs.de>
# 2011 (c) by Andreas Geisenhainer <psycorama@opensecure.de> 
# Licensed under GNU GPL.
#
# This script should be run every 5 minutes.
#
# *ADDITIONALLY* data aquisition is done externally every minute
# with load.sh
# rrdtool update $datafile N:$( PROCS=`echo /proc/[0-9]*|wc -w|tr -d ' '`; read L1 L2 L3 DUMMY < /proc/loadavg ; echo ${L1}:${L2}:${L3}:${PROCS} )
#
use strict;
use warnings;
use RRDs;

# parse configuration file
my %conf;
eval(`cat ~/.rrd-conf.pl`);

# set variables
my $datafile = "$conf{DBPATH}/load.rrd";
my $picbase  = "$conf{OUTPATH}/load-";

# global error variable
my $ERR;

# whoami?
my $hostname = `/bin/hostname`;
chomp $hostname;

# generate database if absent
if ( ! -e $datafile ) {
    # max 70000 for all values
    RRDs::create($datafile,
		 "--step=60",
		 "DS:load1:GAUGE:120:0:70000",
		 "DS:load2:GAUGE:120:0:70000",
		 "DS:load3:GAUGE:120:0:70000",
		 "DS:procs:GAUGE:120:0:70000",
		 "RRA:AVERAGE:0.5:1:25",     # hourly:  5min /w 25values  => 90 min
		 "RRA:AVERAGE:0.5:2:70",     # daily :  10min /w 70values => 29.16 hours
		 "RRA:AVERAGE:0.5:10:350",   # weekly:  30m /w 350values  => ~7.3 days
		 "RRA:AVERAGE:0.5:20:800",   # monthly: 1h /w 800values   => ~33.3 days
		 "RRA:AVERAGE:0.5:360:1500", # yearly:  6h /w 1500values  => ~1year
		 "RRA:MAX:0.5:1:120",
		 "RRA:MAX:0.5:5:600",
		 "RRA:MAX:0.5:6:700",
		 "RRA:MAX:0.5:120:775",
		 "RRA:MAX:0.5:1440:797",
		 "RRA:MIN:0.5:1:120",
		 "RRA:MIN:0.5:5:600",
		 "RRA:MIN:0.5:6:700",
		 "RRA:MIN:0.5:120:775",
		 "RRA:MIN:0.5:1440:797"
		 );
      $ERR=RRDs::error;
      die "ERROR while creating $datafile: $ERR\n" if $ERR;
      print "created $datafile\n";
  }

# draw pictures
foreach ( [3600, "hour"], [86400, "day"], [604800, "week"], [2678400 ,'month'], [31536000, "year"] ) {
    my ($time, $scale) = @{$_};
    RRDs::graph($picbase . $scale . ".png",
		"--start=-${time}",
		'--lazy',
		'--imgformat=PNG',
		"--title=${hostname} system load (last $scale)",
		"--width=$conf{GRAPH_WIDTH}",
		"--height=$conf{GRAPH_HEIGHT}",
		'--slope-mode',
		'--alt-autoscale',

		"DEF:load1=${datafile}:load1:AVERAGE",
		"DEF:load2=${datafile}:load2:AVERAGE",
		"DEF:load3=${datafile}:load3:AVERAGE",
		"DEF:procsx=${datafile}:procs:AVERAGE",
		"DEF:procminx=${datafile}:procs:MIN",
		"DEF:procmaxx=${datafile}:procs:MAX",

		'CDEF:procs=procsx,100,/',
		'CDEF:procmin=procminx,100,/',
		'CDEF:procrange=procmaxx,procminx,-,100,/',

		'AREA:procmin',
		'STACK:procrange#E0E0E0',
		'AREA:load3#000099:loadavg3',
		'LINE2:load2#0000FF:loadavg2',
		'LINE1:load1#9999FF:loadavg1',
		'COMMENT:\n',
		'LINE1:procs#000000:processes/100',
		);
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
}
