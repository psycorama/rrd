#!/usr/bin/perl
#
# RRD script to display cpufreq statistics
# 2007 (c) by Christian Garbs <mitch@cgarbs.de>
# 2011,2012 (c) by Andreas Geisenhainer <psycorama@opensecure.de>
# Licensed under GNU GPL.
#
# This script should be run every minute.
#
use strict;
use warnings;
use RRDs;

# parse configuration file
my %conf;
eval(`cat ~/.rrd-conf.pl`);
die "~/.rrd-conf.pl contains the following erros:\n" . $@ if $@;

# set variables
my $datafile = "$conf{DBPATH}/cpufreq.rrd";
my $picbase  = "$conf{OUTPATH}/cpufreq-";
my $stats = '/sys/devices/system/cpu/cpu0/cpufreq/stats/time_in_state';
my @colors = qw(
                2020F0
                700505
                E0E000
                0FFFBF
                0000FF
                40D030
                AAAAAA
                00FF00
		);

# global error variable
my $ERR;

# whoami?
my $hostname = `/bin/hostname`;
chomp $hostname;

# generate database if absent
if ( ! -e $datafile ) {
    RRDs::create($datafile,
		 '--step=60',
		 'DS:state0:COUNTER:120:0:32000',
		 'DS:state1:COUNTER:120:0:32000',
		 'DS:state2:COUNTER:120:0:32000',
		 'DS:state3:COUNTER:120:0:32000',
		 'DS:state4:COUNTER:120:0:32000',
		 'DS:state5:COUNTER:120:0:32000',
		 "RRA:AVERAGE:0.5:1:70",    # hourly:  1min /w 70values  => 70 min
		 "RRA:AVERAGE:0.5:5:300",   # daily : 5min /w 300values  => 25.83 hours
		 "RRA:AVERAGE:0.5:15:700",  # weekly:  15m /w 700values  => ~7.3 days
		 "RRA:AVERAGE:0.5:60:800",  # monthly: 1h /w 800values   => ~33.3 days
		 "RRA:AVERAGE:0.5:360:1500",# yearly:  6h /w 1500values  => ~1year
		 "RRA:AVERAGE:0.5:900:3000" # 5yearly:  15h /w 3000values => ~5year
	);
    
    $ERR=RRDs::error;
    die "ERROR while creating $datafile: $ERR\n" if $ERR;
    print "created $datafile\n";
}

# get data
open STATS, '<', $stats or die "can't open `$stats': $!";
my @name;
while (my $line = <STATS>) {
    last if $. > 6;
    chomp $line;
    my ($name, $_) = split /\s+/, $line;
    push @name, $name;
}
close STATS or die "can't close `$stats': $!";

# update is done in other file [ cpufreq_1m.pl ]

# draw pictures
foreach ( [3600, 'hour'], [86400, 'day'], [604800, 'week'], [2678400, 'month'], [31536000, 'year'], [157680000, '5year'] ) {
    my ($time, $scale) = @{$_};

    my (@def, @area);

    for my $i (0 .. (scalar @name - 1)) {
	push @def,  "DEF:state${i}=${datafile}:state${i}:AVERAGE";
	push @area, ($i ? 'STACK' : 'AREA') . ":state${i}#${colors[$i]}:${name[$i]}";
    }

    RRDs::graph($picbase . $scale . '.png',
		"--start=-${time}",
		'--lazy',
		'--imgformat=PNG',
		"--title=${hostname} cpu frequencies (last $scale)",
		"--width=$conf{GRAPH_WIDTH}",
		"--height=$conf{GRAPH_HEIGHT}",
		'--upper-limit=100',
		'--lower-limit=0',
                '--rigid',
		
		@def,
		@area,
		
                'COMMENT:\n',

		);
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
}
