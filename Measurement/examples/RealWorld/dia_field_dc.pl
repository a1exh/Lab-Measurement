#!/usr/bin/perl -w

# Daniel Schmid, July 2010, composed following Markus'  & David's perl-scripts
 
use strict;
use Lab::Instrument::Yokogawa7651;
use Lab::Instrument::HP3458A;
use Lab::Instrument::SR830;
use Lab::Instrument::OI_IPS;
use Time::HiRes qw/usleep/;
use Time::HiRes qw/sleep/;
use Time::HiRes qw/tv_interval/;
use Time::HiRes qw/time/;
use Time::HiRes qw/gettimeofday/;

use Lab::Measurement;

use warnings "all";

#general information
my $t = 0;			      # fürs Stoppen der Messzeit
my $temperature = '30';      # Temperatur in milli-Kelvin!
my $temperatureunit = 'mK';
my $sample = "CB3442";

my @starttime = localtime(time);
my $startstring=sprintf("%04u-%02u-%02u_%02u-%02u-%02u",$starttime[5]+1900,$starttime[4]+1,$starttime[3],$starttime[2],$starttime[1],$starttime[0]);



# measurement constants
#---ac sample1---
my $DividerDC = 0.001;

my $yok1protect = 1;		# 0 oder 1 für an / aus, analog gateprotect
my $Yok1DcRange = 5;		# Handbuch S.6-22:R2=10mV,R3=100mV,R4=1V,R5=10V,R6=30V
my $Vdcmax1 = 12;	        # wird unten fürs biasprotect verwendet, on 470 MOhm corresponds to about 32 nA  

my $ampI = 1e-11;         
my $risetime = 100;		# rise time Ithaco Zeit in ms


my $multitime=2;  # multimeter integration time in line power cycles


#---gate---
############################## !!!!!!!!!!!!!!
my $Vgatestart = 0.665;
my $Vgatestop = 0.695;
my $stepgate = 0.00005;
##############################!!!!!!!!!!!!!!

my $Vgatemax = 5;				# wird unten fürs gateprotect verwendet

#---bias---

############################## !!!!!!!!!!!!!!
my $Vbiasstart = -10;  #ACHTUNG!!! 1/1000 Teiler für dc-bias! -->1V=10mV
my $Vbiasstop = 10;    #ACHTUNG!!! 1/1000 Teiler für dc-bias! -->1V=10mV
my $stepbias = 0.02;   #ACHTUNG!!! 1/1000 Teiler für dc-bias! -->1mV=1µV
##############################

#---field---

############################## !!!!!!!!!!!!!!
my @Bfieldlist = (5);
##############################

# all gpib addresses

my $gpib_hp2 = 13;			# Spannung output Ithaco für Strommessung durch Probe		


####################################################################

#	<---------- set Instruments

#---init Yokogawa--- Gatespannung
my $type_gate="Lab::Instrument::Yokogawa7651";
my $YokGate=new $type_gate({
	'connection_type' =>'VISA_GPIB',
	'gpib_board'    => 0,
    'gpib_address'  => 3,
    'gate_protect'  => 1,
    'gp_max_units_per_second' => 0.05,
    'gp_max_step_per_second' => 10,
    'gp_max_units_per_step' => 0.01,
    'gp_min_units' => -$Vgatemax, 	# gate equipped with 5 Hz filter from Leonid 
    'gp_max_units'  => $Vgatemax,
});



#--- init Yoko dc bias sample 1 ----
my $type_bias="Lab::Instrument::Yokogawa7651";
my $Yok=new $type_bias({
	'connection_type' =>'VISA_GPIB',
    'gpib_board'    => 0,
    'gpib_address'  => 2,
    'gate_protect'  => 1,
    'gp_max_units_per_second' => 5,
    'gp_max_step_per_second' => 10,
    'gp_max_units_per_step' => 0.5,
    'gp_min_units' => -5, 	
    'gp_max_units'  => 5,
});
          
my $magnet=new Lab::Instrument::OI_IPS(
        connection_type=>'VISA_GPIB',
        gpib_address => 24,
		max_current => 123.8,    # A
		max_sweeprate => 0.0167, # A/s
		soft_fieldconstant => 0.13731588, # T/A
		can_reverse => 1,
		can_use_negative_current => 1,
);
		  
print "setting up Agilent for dc current through sample \n";
my $hp2=new Lab::Instrument::HP3458A({
	'connection_type' =>'VISA_GPIB',
	'gpib_board' => 0,
	'gpib_address' => 15,
	});

	
$hp2->write("TARM AUTO");
$hp2->write("NPLC $multitime");

print " done!\n";

###################################################################################
# Measurment loop for different B-fields
###################################################################################

foreach my $field(@Bfieldlist){

my $title = "Stability diagram at parallel magnetic field ($field T) in the few electron regime";
my $filename = $startstring."_$sample dia fele par $field";

my $comment=<<COMMENT;
DC stability diagram measurement in the few electron regime for magnetic field $field T.

Ithaco: Verstaerkung $ampI  , Rise Time $risetime ms;
Messen der Ausgangsspannung des Ithaco über Agilent;
Voltage dividers DC: $DividerDC 

Orientation: -23.3°

Multimeter integ. time (PLC) $multitime

Temperatur = $temperature $temperatureunit;

Vgate Vbias Idc t
COMMENT


####################################################################################



my $measurement=new Lab::Measurement(
    sample          => $sample,
    title           => $title,
    filename_base   => $filename,
    description     => $comment,

    live_plot       => 'currentac',
    live_refresh    => '300',

constants       => [
        {
            'name'          => 'ampI',
            'value'         => $ampI,
        },
    ],
    columns         => [
        {
            'unit'          => 'V',
            'label'         => 'Gate voltage',
            'description'   => 'Applied to gate',
        },
		{
            'unit'          => 'V',
            'label'         => 'Vbias',
            'description'   => "Vbias",
        },
		{
			'unit'          => 'A',
            'label'         => 'Idc',
            'description'   => "measured dc current through $sample",
        },
#	----sonstiges---
		{
            'unit'          => 'sec',
            'label'         => 'time',
            'description'   => "Time",
        },
    ],
    axes            => [
        {
            'unit'          => 'V',
            'expression'    => '$C0',
            'label'         => 'gate voltage',
            'description'   => 'Applied to backgate via 5Hz filter.',
        },
		{
            'unit'          => 'V',
            'expression'    => '$C1',
            'label'         => 'dc bias voltage',
            'description'   => 'Applied on sample via $Divider divider',
        },
		{
	        'unit'          => 'A',
            'expression'    => '$C2',
            'label'         => 'Idc',
            'description'   => 'Measured dc current through $sample',
        },
		{
            'unit'          => 'sec',
			'expression'    => '$C3',
            'label'         => 'time',
            'description'   => "Timestamp (seconds since unix epoch)",
        },
    ],
    plots           => {
        'currentac'    => {
            'type'          => 'pm3d',
            'xaxis'         => 0,
            'yaxis'         => 1,
            'cbaxis'        => 2,
            'grid'          => 'xtics ytics',
        },
    },
);

###############################################################################

 
unless (($Vgatestop-$Vgatestart)/$stepgate > 0) { # um das gate in die richtige Richtung laufen zu lassen
    $stepgate = -$stepgate;
}
my $stepsign_gate=$stepgate/abs($stepgate);

unless (($Vbiasstop-$Vbiasstart)/$stepbias > 0) { # um das bias in die richtige Richtung laufen zu lassen
    $stepbias = -$stepbias;
}
my $stepsign_bias=$stepbias/abs($stepbias);

print "Setting magnetic field: $field T\n";
$magnet->set_field($field);

##Start der Messung
for (my $Vgate=$Vgatestart;$stepsign_gate*$Vgate<=$stepsign_gate*$Vgatestop;$Vgate+=$stepgate)	{

	$measurement->start_block();
	
	#print "setting gate voltage ";
	my $measVgate=$YokGate->set_voltage($Vgate);

	#print "done\n setting bias voltage $Vbiasstart ";
	my $measVb=$Yok->set_voltage($Vbiasstart);
        
	#print "done\n entering inner loop\n";
	sleep(3);

	for (my $Vbias=$Vbiasstart;$stepsign_bias*$Vbias<=$stepsign_bias*$Vbiasstop;$Vbias+=$stepbias) {

	    my $Vbias = $Yok->set_voltage($Vbias);
		
		my $t = gettimeofday();
        my $Vithaco = $hp2 -> get_value();			    # lese Strominfo von Ithako
	    chomp $Vithaco;                                 # raw data (remove line feed from string)
		
		#print "ping \n";
		
	    my $Idc = -($Vithaco*$ampI);              # '-' für den Ithako, damit positives G rauskommt
		
        my $VbiasComp = $Vbias * $DividerDC;
            
	    $measurement->log_line($measVgate, $VbiasComp, $Idc, $t);
	    
	}
}    

my $meta=$measurement->finish_measurement();

printf "End of Measurement at magnetic field $field \n";
}

$magnet->set_field(0);