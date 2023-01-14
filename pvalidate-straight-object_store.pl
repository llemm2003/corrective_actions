#!/usr/bin/perl
use strict;
use warnings;
use Expect;

my $will_print=undef;
my $current_epoch=time();
my $human_time=localtime($current_epoch);

my $rclone_file='/tmp/temp.conf';
my $rclone_keys='[FBGBU_SSDP_saas_migration]
type = s3
provider = Other
env_auth = false
access_key_id = xxxxxxxxx
secret_access_key = xxxxxx
region = us-ashburn-1
endpoint = https://oraclegbuprod.compat.objectstorage.us-ashburn-1.oraclecloud.com
location_constraint =
acl = bucket-owner-full-control
bucket_name = IC_migration_config_datapump_48165';

my ($a,$b,$c)=$human_time=~m/^[\w]{3}\s([\w]+)\s([\w]+)[\s\d:]+?(\d{4})/;
my $append_string="$a"."$b"."$c";
my $command_file="/home/oracle/oracle_install/patch_validate.sh";

my $src_file='/tmp/assign_patching_role.sh';
my $trg_file='/tmp/assign_patching_role_modified.sh';
my (@temp_in_array,@sh_output,@sh_output_fixed,@knife_output,@knife_output_fixed);
my $counter=0;
my $knife_file_output='/tmp/knife_comm';
my $is_role_assigned_already=undef;
my $package_in='#!/bin/bash
chef_check=`service chef-client status|perl -ne \'print $1 if /(is\srunning|\(running\))/\'`;
echo $chef_check
if [[ "$chef_check" == "(running)" ]] || [["$chef_check" == "is running" ]]; then
	echo "chef is running... continue with the assign";
else 
	echo "Chef is stopped... Not running the assign_role_patch.sh";
	exit 4;
fi
';

my $sql_query="sqlplus / as sysdba <<GBUCS \
exit; \
GBUCS";
my @sql_output;
my %SQL_OUTPUT;
$SQL_OUTPUT{'version'}='';
my $chef_role;
chomp(my $fqdn=`host \$\(hostname -i\) \| awk \'\{print \$5\}\' \| sed \'s\/\\.\$\/\/\'`);

my $knife_command=" knife node show $fqdn -r -c \/etc\/chef\/client.rb > $knife_file_output";
print "$knife_command \n";
#Sub declaration

sub run_external_comm {
	my $ext_comm_in=$_[0];
	my $ext_comm_out='FALSE';
	if ( $_[1] ) {
		$ext_comm_out='TRUE';
	}
	my @ext_comm_out=`$ext_comm_in`;
	if ( $ext_comm_out eq 'FALSE') {
		print "$_ " for @ext_comm_out;
	} else { return @ext_comm_out; }
}

#####MAIN######


@sql_output=run_external_comm("$sql_query",'TRUE');

foreach (@sql_output) {
	if ($_ =~ /(?:Release\s(\d+.\d+))/) {
		$SQL_OUTPUT{'version'}=$1;#Let hash handle duplicate. 
	}
}


print "DB VERSION : $SQL_OUTPUT{'version'}\n";

if ( $SQL_OUTPUT{'version'}=~ /19\.\d+/ ) {
	$chef_role='gbucs_oracledbaas_19c_latest';
} elsif ( $SQL_OUTPUT{'version'}=~ /12.2/ ) {
	$chef_role='gbucs_oracledbaas_12201_latest';
}  elsif ( $SQL_OUTPUT{'version'}=~ /12.1/ ) {
	$chef_role='gbucs_oracledbaas_12102_latest';
} elsif ( $SQL_OUTPUT{'version'}=~ /18\.\d+/ ) {
	$chef_role='gbucs_oracledbaas_18c_latest';
}  else {$chef_role='UNKNOWN';}
	
print "Required role : $chef_role \n";

#############################root section##########################################
#This is script is for oracle. So need to switch to root ro run the assign_role_patch.sh

my $session_knife = new Expect;
$session_knife->spawn("sudo su - ");
$session_knife->expect(5, -re => '\#');
$session_knife->send("$knife_command\r");
$session_knife->expect(5, -re => '\#');
$session_knife->send("chmod 777 $knife_file_output \r");
$session_knife->expect(5, -re => '\#');
$session_knife->clear_accum; 
$session_knife->do_soft_close();

open (KNIFE_FILE,'<',$knife_file_output) or die $!;
	foreach (<KNIFE_FILE>) {
		if ($_ =~ $chef_role) { $is_role_assigned_already='TRUE'; }
	}
close(KNIFE_FILE);

###################################################################################


if ($is_role_assigned_already) {
	print "Role assigned no need to run the assign script \n";
} else {print "role not assigned ";
	{
		#delete old files to be sure. 
		unlink "$src_file" if ( -e $src_file ); #Delete the existing assogn_patching_role.sh
		unlink "$trg_file" if ( -e $trg_file ); #Delete the existing modified assogn_patching_role.sh
		run_external_comm("sudo rm -rf $trg_file;sudo rm -rf $src_file;");
		run_external_comm("wget -P /tmp http://depot:8080/export/scripts/VM-DEPLOY/oci/DBaaS/orchestration/assign_patching_role.sh");
		open (TEMP_STRING_IN,'<',$src_file) or die $!;
			foreach (<TEMP_STRING_IN>) {
				if ( $counter > 0 ) {#sheban is in the first line( counter 0) so line 1 is skipped.
					push(@temp_in_array,$_);
				}
				$counter++;
			}
		close(TEMP_STRING_IN);

		open (TEMP_STRING_OUT,'>',$trg_file) or die $!;
			print TEMP_STRING_OUT $package_in;
			print TEMP_STRING_OUT "$_" for @temp_in_array;
			print TEMP_STRING_OUT "echo 'ASSIGN ROLE COMPLETED.'" ;
		close (TEMP_STRING_OUT);
	}
	
	{
		#############################root section##########################################
		#This is script is for oracle. So need to switch to root ro run the assign_role_patch.sh
		
		my $session = new Expect;
		$session->spawn("sudo su - ");
		$session->expect(5, -re => '\#');
		$session->send("chown root:root $trg_file; chmod +x $trg_file\r");
		$session->expect(5, -re => '\#');
		$session->send("$trg_file\r");
		#$session->expect(undef);
		$session->expect(1000, -re , qr/'ASSIGN ROLE COMPLETED.|ERROR: There is already a non-latest patching role assigned. Please review manually./);
		#$session->expect(60,-re => '\#');
		$session->clear_accum; 
		@sh_output=$session->expect(5, -re => '\#');
		$session->do_soft_close();
		@sh_output_fixed = split('\n',$sh_output[3]);
		###################################################################################
	}

}


#############################Patch_validate section################################

chomp(my $hostname_string=`hostname -s`);
my $logfile_string='/tmp/'."$hostname_string".'_patch_validate_'."$append_string".'.log';

if (-e $command_file) {
    print "Loggging patch_validate file to: $logfile_string \n";
    system ("$command_file > $logfile_string");
    print "Printing $logfile_string \n";
    system ("chmod 775 $logfile_string");
    if ($will_print) {
            open (PATCH_LOG,'<',$logfile_string) or die "$!";
                    while (<PATCH_LOG>) {
                            print "$_";
                    }
            close(PATCH_LOG)
    }
    my $rclone_mkdir_command='rclone --config='."$rclone_file".' mkdir FBGBU_SSDP_saas_migration:IC_migration_config_datapump_48165/'."$append_string";
    my $rclone_upload_command='rclone --config='."$rclone_file".' copy '."$logfile_string " . 'FBGBU_SSDP_saas_migration:IC_migration_config_datapump_48165/'."$append_string";

    open (RCLONE_CONFIG,'>',$rclone_file) or die $!;
        print RCLONE_CONFIG "$rclone_keys";
    close (RCLONE_CONFIG);
    print "Performing this now: $rclone_upload_command \n";
    system ("$rclone_upload_command");

} else {
        $logfile_string="patch_validate.sh_does_not_exists";
}
print "BULK_INFO $fqdn $logfile_string \nCheck done.\n";