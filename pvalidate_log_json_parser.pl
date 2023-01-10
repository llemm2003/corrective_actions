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
(Instance\s[\w]+\sup\s).+\s(PASSED|FAILED[\w\s\-.]+|WARNING|INTERMEDIATE)
Instance Pre-checks
(Spfile\sin\suse|AMM\ssize|SGA\ssize)\s\.+\s(PASSED|FAILED[\w\s\-.]+|WARNING|INTERMEDIATE)
=cut REGEX

=begin TODO
Instance pre-checks: inprogress. 
=cut TODO
use strict;
use warnings;

my $input_log=$ARGV[0];

#Global Variable for json.
my %root_hash; #This hash will contain all the information captured from the logfile. 
my (@db_name,@test_array,@db_instance_status,@instance_precheck);#test_array contains the log. 
my @top_layer=qw/name Local_instance Database_role FAL_SERVER is_CDB PDBS/;
my @second_layer=('Database Instance Status','Instance Pre-checks','Database Restore Points','Tablespace Checks','Database components','PDB Validation','Backup Validation','Database Parameter Checks','Server Checks','Cluster Status','Correct patches applied to DB Home (local node)',);
=begin
,,'Database objects'
,'Some components have FAILED');#I need the space in the string
=cut
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
		print "\"$input_keys[2]\":\{\n";
	} else {
		for my $i (1..$input_num) {
			print "\t";
		}
		if ( $input_keys[1] eq 'START_NEW'){
			print "\"$input_keys[2]\":\{\n";
			#print "\},\n";
		} elsif ($input_keys[1] eq 'LINE') {
			print "\"$input_keys[2]\":\"$input_keys[3]\",\n";
		} elsif ($input_keys[1] eq 'END_LINE') {
			print "\"$input_keys[2]\":\"$input_keys[3]\"\},\n";
		}
	}
}

sub open_object {
	my $input_object=$_[0];
	my $obj_direction=$_[1];
	my $terminator; 
	if ( $_[3] ) {
	$terminator=$_[3];
	}
	my $stg_regex;
	my $regex;
	if ( $_[4] ) {
		$stg_regex=$_[4];
		$regex=qr/$stg_regex/;
	}
	my $stg_obj;
	my @stg_array;
	open (INPUT_LOG,$obj_direction,$input_object) or die "print $!"; #Put all the data in an array which is stg_array;
	if ( $terminator ) {
		local $/=$terminator;
	}
		foreach (<INPUT_LOG>) {
			$stg_obj=$_;
			$stg_obj=~s/\e\[[0-9;]*m(?:\e\[K)?//g; #Perl does not like seeing color information, so I have to remove it. 
			if ( $_[4] ) {
				if ($stg_obj=~/$regex/) {
					push(@stg_array,$stg_obj);
				}
			}
			push(@stg_array,$stg_obj);
		}
	close(INPUT_LOG);	
	return @stg_array; #Return the array to be used for array variable
}

sub check_if_exists {
	my $input1=$_[0];
	my @stg_array=@{$_[1]};
	my $output=undef;
	foreach (@stg_array) {
		if ($_ eq $input1) {$output='TRUE';}
	} 
	return $output;
}
############MAIN############

@test_array=open_object("$input_log",'<');
foreach (@test_array) {
	if ( $_ =~ /^(db\[\d+\])\s=\s(\w+)$/ ) { # The DB num and name. This is important since I have seen logs where there are db[1] and db[2].
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
=begin
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
=cut
#Try using block read.
#REGEX declaration and quotation. 
$stg_regex='Database Instance Status';
$root_hash{regex}{'Database Instance Status'}{main}=qr/$stg_regex/;
$stg_regex='(Instance\s[\w]+\sup\s).+\s(PASSED|FAILED[\w\s\-.]+|WARNING|INTERMEDIATE)';
$root_hash{regex}{'Database Instance Status'}{second}=qr/$stg_regex/;

$stg_regex='Instance Pre-checks';
$root_hash{regex}{'Instance Pre-checks'}{main}=qr/$stg_regex/;
$stg_regex='(Spfile\sin\suse|AMM\ssize|SGA\ssize)\s\.+\s(PASSED|FAILED[\w\s\-.]+|WARNING|INTERMEDIATE)';
$root_hash{regex}{'Instance Pre-checks'}{second}=qr/$stg_regex/;

$stg_regex='Database Restore Points';
$root_hash{regex}{'Database Restore Points'}{main}=qr/$stg_regex/;
$stg_regex='(Restore\sPoint\(s\)).+\s(PASSED|FAILED[\w\s\-.]+|WARNING|INTERMEDIATE)';
$root_hash{regex}{'Database Restore Points'}{second}=qr/$stg_regex/;

$stg_regex='Tablespace Checks';
$root_hash{regex}{'Tablespace Checks'}{main}=qr/$stg_regex/;
$stg_regex='^\s+((?:[A-Z][\w\s]+))\.+\s(PASSED|FAILED[\w\s\-.]+|WARNING|INTERMEDIATE)';
$root_hash{regex}{'Tablespace Checks'}{second}=qr/$stg_regex/;

$stg_regex='Database components';
$root_hash{regex}{'Database components'}{main}=qr/$stg_regex/;
$stg_regex='^\s+(Database\scomponents\svalid)\s\.+\s(PASSED|FAILED[\w\s\-.]+|WARNING|INTERMEDIATE)';
$root_hash{regex}{'Database components'}{second}=qr/$stg_regex/;

$stg_regex='Database objects';
$root_hash{regex}{'Database objects'}{main}=qr/$stg_regex/;
$stg_regex='^\s+(Internal\sOracle\sdatabase\sobjects\svalid|Application\sschema\sobjects\svalid)\s\.+\s(PASSED|FAILED[\w\s\-.]+|WARNING[\w\s\-.]+|INTERMEDIATE[\w\s\-.]+)';
$root_hash{regex}{'Database objects'}{second}=qr/$stg_regex/;

$stg_regex='PDB Validation';
$root_hash{regex}{'PDB Validation'}{main}=qr/$stg_regex/;
$stg_regex='^\s+((?:PDBs\sin|PDB\sPlug-In)[\s\w()]+)\.+\s(PASSED|FAILED[\w\s\-.]+|WARNING[\w\s\-.]+|INTERMEDIATE[\w\s\-.]+)';
$root_hash{regex}{'PDB Validation'}{second}=qr/$stg_regex/;

$stg_regex='Backup Validation';
$root_hash{regex}{'Backup Validation'}{main}=qr/$stg_regex/;
$stg_regex='^\s+(RMAN\sBackups)\s\.+\s(PASSED|FAILED[\w\s\-.]+|WARNING[\w\s\-.]+|INFORMATIONAL[\w\s\-.]+)';
$root_hash{regex}{'Backup Validation'}{second}=qr/$stg_regex/;

$stg_regex='Database Parameter Checks';
$root_hash{regex}{'Database Parameter Checks'}{main}=qr/$stg_regex/;
$stg_regex='^\s+([\w]+\sin\sCDB)\s\.+\s(PASSED|FAILED[\w\s\-.]+|WARNING[\w\s\-.]+|INFORMATIONAL[\w\s\-.]+)';
$root_hash{regex}{'Database Parameter Checks'}{second}=qr/$stg_regex/;

$stg_regex='Server Checks';
$root_hash{regex}{'Server Checks'}{main}=qr/$stg_regex/;
$stg_regex='^\s+((?:RAM|Hugepages|Memlock|Server\s(?:up)|NTPD\/CTSS|Screen|Swap)[\s()\w-]+)\s\.+\s(PASSED|FAILED[\w\s\-.]+|WARNING[\w\s\-.:\/,()]+|INFORMATIONAL[\w\s\-.]+)';
$root_hash{regex}{'Server Checks'}{second}=qr/$stg_regex/;

$stg_regex='Cluster Status';
$root_hash{regex}{'Cluster Status'}{main}=qr/$stg_regex/;
$stg_regex='^\s+([\s()\w-]+)\s\.+\s(PASSED|FAILED[\w\s\-.:\/,()]+|WARNING[\w\s\-.:\/,()]+|INFORMATIONAL[\w\s\-.:\/,()]+)';
$root_hash{regex}{'Cluster Status'}{second}=qr/$stg_regex/;

$stg_regex='Correct patches applied to DB Home (local node)';
$root_hash{regex}{'Correct patches applied to DB Home (local node)'}{main}=qr/$stg_regex/;
$stg_regex='^\s+(Patch\s[\d]+)\s\.+\s(PASSED|FAILED[\w\s\-.:\/,()]+|WARNING[\w\s\-.:\/,()]+|INFORMATIONAL[\w\s\-.:\/,()]+)';
$root_hash{regex}{'Correct patches applied to DB Home (local node)'}{second}=qr/$stg_regex/;

foreach my $dbname (@db_name) {
	print "$dbname - working here \n";
	next if (  $root_hash{$dbname}{Local_instance} eq 'NULL' );
	print "$root_hash{$dbname}{name} ----HERE \n";
	my $stg_regex=$root_hash{$dbname}{name};
	my $regex=qr/$stg_regex/;
	my @temp_array;
	foreach my $sl (@second_layer) {
		{
			print "$root_hash{regex}{$sl}{main} ---MAIN REGEX\n ";
			open (INPUT_LOG,'<',$input_log) or die "print $!"; #Put all the log inside the array test_array.
				local $/ = "\n\n";#REGEX per line will not work on some logs due to wrong location. Restore point and Instance pre-check is not on its own block--they are on the same block, if there are multiple DB.  
				while (<INPUT_LOG>) {
					if ( $_ =~ /$root_hash{regex}{$sl}{main}/ ) {
						$root_hash{block}{$sl}=$_;
					} 
				}
			close (INPUT_LOG);
		}
		print "found block for $sl: \n $root_hash{block}{$sl} -- HERE\n";
		
		{
			open (TEMP_LOG,'<',\$root_hash{block}{$sl}) or die "print $!"; #Put all the log inside the array test_array.
			local $/="\n"; #just make sure that the operation is by line not by block. 
			my @test;
			while (<TEMP_LOG>) {
				my $x=$_;
				$x=~s/\e\[[0-9;]*m(?:\e\[K)?//g;
				push(@test,$x);
			}
			close (TEMP_LOG);
			#print "$regex - REGEX USED\n";
			#print "$root_hash{regex}{$sl}{second} \n";
			#print "$_" for @test;
			my $signal='FALSE';
			foreach my $test_var (@test) {
				if ( $test_var=~/$regex/ ) { $signal='TRUE';next;}
				if (check_if_exists("$sl",\@third_layer)) { $signal='TRUE';}
				if ( $signal eq 'TRUE' ) {
					if ( $test_var =~ /$root_hash{regex}{$sl}{second}/ ) {
						push(@temp_array,$1);
						my $temp_var=$2;chomp($temp_var);
						$root_hash{$dbname}{$sl}{$1}=$temp_var;
						print "$1 => $root_hash{$dbname}{$sl}{$1} \n";
					} 
				}
			}
		}
	}
}

=begin
{
open (INPUT_LOG,'<',$input_log) or die "print $!"; #Put all the log inside the array test_array.
	local $/ = "\n\n";#REGEX per line will not work on some logs due to wrong location. Restore point and Instance pre-check is not on its own block--they are on the same block, if there are multiple DB.  
	while (<INPUT_LOG>) {
		if ( $_ =~ /Database Instance Status/ ) {
			$root_hash{block}{'Database Instance Status'}=$_;
		}
	}
close (INPUT_LOG);
}

{		
	open (TEMP_LOG,'<',\$root_hash{block}{'Database Instance Status'}) or die "print $!"; #Put all the log inside the array test_array.
	local $/="\n"; #just make sure that the operation is by line not by block. 
	my @test;
	while (<TEMP_LOG>) {
		my $x=$_;
		$x=~s/\e\[[0-9;]*m(?:\e\[K)?//g;
		push(@test,$x);
	}
	close (TEMP_LOG);

	my $signal='FALSE';
	foreach (@test) {
		if (/p00trj0_fra248/) { $signal='TRUE'; next;}
		if ($signal eq 'TRUE' and ! /-/ and ! /$^/) {
			if ( $_ =~ /(Instance\s[\w]+\sup\s).+\s(PASSED|FAILED[\w\s\-.]+|WARNING|INTERMEDIATE)/) {
				push(@db_instance_status,$1);
				$root_hash{'db[2]'}{'Database Instance Status'}{$1}=$2;
			} 
		}
	}
}
		
foreach (@db_instance_status) {
	print "\"$_\":\"$root_hash{'db[2]'}{'Database Instance Status'}{$_}\"\n";
}


{#The instance pre-check output is not in the correct place if there are multiple DB. So this have to be manual.
	my $input=$_[0];
	open (INPUT_LOG,'<',$input_log) or die "print $!"; 
	local $/ = "\n\n";
	while (<INPUT_LOG>) {
		if ( /p00trj0_fra248/ and /Spfile in use/  ) {
			$root_hash{block}{'Instance Pre-checks'}=$_;
		}
	}
close (INPUT_LOG);
}

{		
	open (TEMP_LOG,'<',\$root_hash{block}{'Instance Pre-checks'}) or die "print $!"; #Put all the log inside the array test_array.
	local $/="\n"; #just make sure that the operation is by line not by block. 
	my @test;
	while (<TEMP_LOG>) {
		my $x=$_;
		$x=~s/\e\[[0-9;]*m(?:\e\[K)?//g;
		push(@test,$x);
	}
	close (TEMP_LOG);

	my $signal='FALSE';
	foreach (@test) {
		if (/p00trj0_fra248/) { $signal='TRUE'; next;}
		if ($signal eq 'TRUE' and ! /-/ and ! /$^/) {
			if ( $_ =~ /(Spfile\sin\suse|AMM\ssize|SGA\ssize)\s\.+\s(PASSED|FAILED[\w\s\-.]+|WARNING|INTERMEDIATE)/) {
				push(@instance_precheck,$1);
				$root_hash{'db[2]'}{'Instance Pre-checks'}{$1}=$2;
			} 
		}
	}
	
}

foreach (@instance_precheck) {
	print "\"$_\":\"$root_hash{'db[2]'}{'Instance Pre-checks'}{$_}\"\n";
}


=cut

foreach (@db_name) {
	next if ( $root_hash{$_}{Local_instance} eq 'NULL' );
	print_to_json("1" , 'LINE', "$root_hash{$_}{name}");
	for my $i (0..$#top_layer) {
		print_to_json("2",'LINE',"$top_layer[$i]","$root_hash{$_}{$top_layer[$i]}");
	}
	foreach my $j (@second_layer) {
		my @temp_arr;
		my $temp_key;
		print_to_json("2",'START_NEW',"$j");
		foreach $temp_key (keys $root_hash{$_}{$j}) {
			push(@temp_arr,$temp_key);
		}
		for my $i (0..$#temp_arr) {
			if ($i == $#temp_arr) {
				print_to_json("3",'END_LINE',"$temp_arr[$i]","$root_hash{$_}{$j}{$temp_arr[$i]}");
			} else {print_to_json("3",'LINE',"$temp_arr[$i]","$root_hash{$_}{$j}{$temp_arr[$i]}");}
			
		}
	}
}
