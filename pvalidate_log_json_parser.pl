#!/usr/bin/perl
=begin README
This scripts MAIN goal is to:
1. Convert the log created by patch_validate.sh to json. 
2. Script will accept patch_validate.sh(tee) log and coverts it to json file.
=cut README

=begin REGEX
The script will use a lot of regex to easily capture pertinent information in the log. 
removing the color information on files:
s/\e\[[0-9;]*m(?:\e\[K)?//g
db[?] and the unique name #This will be the top value in root hash. 
^(db\[\d+\])\s=\s(\w+)$
Local instance
Local\sinstance\sfor\s[\w]+\s=\s([\w]+)
Database role
Database\srole\sfor\s'."$root_hash{$_}{name}".'\s+=\s([A-Z]+)
FAL_SERVER
FAL_SERVER\sfor\s'."$root_hash{$_}{name}".'\s+=\s([\w]+)
is_CDB
Is\s'."$root_hash{$_}{name}".'\sa\scontainer\sDB\s+=\s([\w]+)
PDBS
PDBs\sfor\s' ."$root_hash{$_}{name}". '\s+=\s([\w,]+)
Database Instance Status.
(Instance\s[\w]+\sup)\s.+\s(PASSED|FAILED[\w\s\-.]+|WARNING|INTERMEDIATE)
=cut REGEX

=begin TODO
Second layer done. 
Find way to disable the warning on null hash. done
Try to print the top_layer as JSON. 
Set the parameters that can be null to null like FAL_SERVER and DATABASE ROLE.
=cut TODO
use strict;
use warnings;

my $input_log=$ARGV[0];

#Global Variable for json.
my %root_hash; #This hash will contain all the information captured from the logfile. 
my (@db_name,@test_array);#test_array contains the log. 
my @top_layer=qw/name Local_instance Database_role FAL_SERVER is_CDB PDBS/;
my @second_layer=('Database Instance Status','Instance Pre-checks','Database Restore Points','Tablespace Checks','Database components','Database objects','PDB Validation',
'Backup Validation','Database Parameter Checks','Some components have FAILED');#I need the space in the string
my @third_layer=('Cluster Status','Correct patches applied to DB Home (local node)','Upgrade Pre-Checks','Space Checks (OS)','Free Space in ASM','OPC User Setup','Server Checks');
my ($regex,$stg_regex); #regex and regex staging variable. 
#Global variable for json print. 
my $begin_j='FALSE'; #Will be set to true once the json print starts. 

#Procedure section
sub search_info {
	my @stg_array=@{$_[0]};
	my $stg_regex=$_[1];
	my $regex=qr/$stg_regex/;
	my ($y1,$y2);
	foreach my $i (@stg_array) {
		my $x=$i;
		$x=~s/\e\[[0-9;]*m(?:\e\[K)?//g;
		if ($x =~ /$regex/ ) {
			$y1=$1;chomp($y1);
			if ( $2 ) {$y2=$2;chomp($y2);}
		}
	}
	if ( ! $y1 or $y1 eq "ERROR" ) {
		return 'NULL';
	} else {return $y1;}
}

sub search_info2 { #for array. I will not compress it right now.
	my @stg_array_in=@{$_[0]};
	my @stg_array_out;
	my $stg_regex=$_[1];
	my $regex=qr/$stg_regex/;
	my ($y1,$y2);
	foreach my $i (@stg_array_in) {
		my $x=$i;
		$x=~s/\e\[[0-9;]*m(?:\e\[K)?//g;
		if ($x =~ /$regex/ ) {
			$y1=$1;chomp($y1);
			push(@stg_array_out,$y1);
		}
	}
	return @stg_array_out;
}

sub print_to_json {
	my @input_keys=@_;
	#first argument is for the amout of tab.
	my $input_num=$input_keys[0];
	if ($begin_j eq 'FALSE') {#begin will be true only on the first execute. This signal to start the json start string which is the curly brackets.
		$begin_j='TRUE';
		print "\{\n\t";
		print "\"$input_keys[1]\":\{\n";
	} else {
		for my $i (1..$input_num) {
			print "\t";
		}
		print "\"$input_keys[1]\":\"$input_keys[2]\"";
		if ( $input_keys[$#input_keys] eq 'END_LINE' or $input_keys[$#input_keys] eq 'START_NEW'){
			print "\},\n";
		} else { print ",\n"; }
	}
}

############MAIN############

open (INPUT_LOG,'<',$input_log) or die "print $!"; #Put all the log inside the array test_array.
	foreach (<INPUT_LOG>) {
		my $x=$_;
		$x=~s/\e\[[0-9;]*m(?:\e\[K)?//g; #Perl does not like seeing color information, so I have to remove it. 
		push(@test_array,$x);
	}
close (INPUT_LOG);

foreach (@test_array) {
	if ( $_ =~ /^(db\[\d+\])\s=\s(\w+)$/ ) { # Top layer object:
			push(@db_name,$1);
			$root_hash{$1}{name}=$2;
	}
}

foreach (@db_name) {#Start gathering information on top layer which is the keywords in top_layer.
	$stg_regex='Local\sinstance\sfor\s'."$root_hash{$_}{name}".'\s=\s([\w]+)';
	$root_hash{$_}{Local_instance}=search_info(\@test_array , "$stg_regex" );
	$stg_regex='Database\srole\sfor\s'."$root_hash{$_}{name}".'\s+=\s([A-Z]+)';
	$root_hash{$_}{Database_role}=search_info(\@test_array , "$stg_regex" );
	$stg_regex='FAL_SERVER\sfor\s'."$root_hash{$_}{name}".'\s+=\s([\w]+)';
	$root_hash{$_}{FAL_SERVER}=search_info(\@test_array , "$stg_regex" );
	$stg_regex='Is\s'."$root_hash{$_}{name}".'\sa\scontainer\sDB\s+=\s([\w]+)';
	$root_hash{$_}{is_CDB}=search_info(\@test_array , "$stg_regex" );
	$stg_regex='PDBs\sfor\s' ."$root_hash{$_}{name}". '\s+=\s([\w,]+)';
	$root_hash{$_}{PDBS}=search_info(\@test_array , "$stg_regex" );
}

#Check value section:
foreach (@db_name) {
	for my $i (0..$#top_layer) {
		print "$_:$top_layer[$i] : $root_hash{$_}{$top_layer[$i]} \n";
	}
}

print "PRINTING ONLY VALID DB\n";
foreach (@db_name) {
	next if (  $root_hash{$_}{Local_instance} eq 'NULL' );
	for my $i (0..$#top_layer) {
		print "$_:$top_layer[$i] : $root_hash{$_}{$top_layer[$i]} \n";
	}
}

foreach (@db_name) {
	next if ( $root_hash{$_}{Local_instance} eq 'NULL' );
	print_to_json("1" , "$root_hash{$_}{name}");
	for my $i (0..$#top_layer) {
		print_to_json("2","$top_layer[$i]","$root_hash{$_}{$top_layer[$i]}");
	}
}

print "Working here \n";
$stg_regex='Database\sInstance\sStatus';
$regex=qr/$stg_regex/;

foreach my $i (0..$#test_array) {
	if ( $test_array[$i]=~ /$regex/ ) {
		print "$i - index of the regex \n";
		for my $j ($i..$#test_array) {
			if ( $test_array[$j]=~ /^$/ ) {
					print "$j - is the line of the next white line \n";
					last;
			}
		}
	}
}

#Try using block read. 
{
open (INPUT_LOG,'<',$input_log) or die "print $!"; #Put all the log inside the array test_array.
	local $/ = "\n\n";
	while (<INPUT_LOG>) {
		if ( $_ =~ /Database Instance Status/ ) {
			$root_hash{block}{'Database Instance Status'}=$_;
		}
	}
close (INPUT_LOG);
}

print "$root_hash{block}{'Database Instance Status'} \n";

{		
	open (TEMP_LOG,'<',\$root_hash{block}{'Database Instance Status'}) or die "print $!"; #Put all the log inside the array test_array.
	local $/="\n"; #just make sure that the operation is by line not by block. 
	my @test;
	my $signal='NO';
	while (<TEMP_LOG>) {
		my $x=$_;
		$x=~s/\e\[[0-9;]*m(?:\e\[K)?//g;
		if ($ x =~ /p00trj0_fra248/) { 
			$signal = 'YES';
		} else {
			$signal = 'NO';
		}
		if ( $signal eq 'YES' ) { 
			print "$x \n"; 
		}
	}
	close (TEMP_LOG);
	print "$#test - count of array \n";
	print "Caught this - $_ \n" for @test;
	foreach (@test) {
		print "$_ \n" if (/[.]+/);
	}
	my $stg_regex='(Instance\s[\w]+\sup)\s.+\s';
	my @xx=search_info2(\@test,"$stg_regex");
	print "input regex: $stg_regex \n";
	print "$_ \n" for @xx;
	#push(@stg_info,$_) for @xx;
	$stg_regex='(Instance\s[\w]+\sup)\s.+\s';
	
}
		
		
#Try to print via JSON. 


=begin

$root_hash{dbnum}
$root_hash{dbnum}{name}
$root_hash{dbnum}{Local_instance}
$root_hash{dbnum}{Database_role}
$root_hash{dbnum}{FAL_SERVER}
$root_hash{dbnum}{is_CDB}
$root_hash{dbnum}{PDBS}
$root_hash{dbnum}{'Database Instance Status'}:This will one or more 
$root_hash{dbnum}{'Database Instance Status'}{Instace 1 is up}
$root_hash{dbnum}{'Database Instance Status'}{Instace 2 is up}
$root_hash{dbnum}{'Database Instance Status'}{Instace 2 is up}



=cut 