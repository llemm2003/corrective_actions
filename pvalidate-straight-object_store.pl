#!/usr/bin/perl
use strict;
use warnings;

my $will_print=undef;
my $current_epoch=time();
my $human_time=localtime($current_epoch);
my $rclone_file='/tmp/temp.conf';
my $rclone_keys='[FBGBU_SSDP_saas_migration]
type = s3
provider = Other
env_auth = false
access_key_id = 6aa98d0a9a512b59b02636564e8344c0e2b51199
secret_access_key = FxAnSaQdaggyw5ytpWTgnr9/awOWV/kuU/ppRhoM970=
region = us-ashburn-1
endpoint = https://oraclegbuprod.compat.objectstorage.us-ashburn-1.oraclecloud.com
location_constraint =
acl = bucket-owner-full-control
bucket_name = IC_migration_config_datapump_48165';
my ($a,$b,$c)=$human_time=~m/^[\w]{3}\s([\w]+)\s([\w]+)[\s\d:]+?(\d{4})/;
my $append_string="$a"."$b"."$c";
my $command_file="/home/oracle/oracle_install/patch_validate.sh";
chomp(my $hostname_string=`hostname -s`);
my $logfile_string='/tmp/'."$hostname_string".'_patch_validate_'."$append_string".'.log';
print "Loggging patch_validate file to: $logfile_string \n";
my $rclone_mkdir_command='rclone --config='."$rclone_file".' mkdir FBGBU_SSDP_saas_migration:IC_migration_config_datapump_48165/'."$append_string";
my $rclone_upload_command='rclone --config='."$rclone_file".' copy '."$logfile_string " . 'FBGBU_SSDP_saas_migration:IC_migration_config_datapump_48165/'."$append_string";
my $fqdn=qx/host `hostname -i`/; $fqdn =~ s/([\w.]+\.com)/$&/;
print "$fqdn \n";

#system ("$command_file > $logfile_string");
print "Printing $logfile_string \n";

if ($will_print) {
	open (PATCH_LOG,'<',$logfile_string) or die "$!";
		while (<PATCH_LOG>) {
			print "$_";
		}
	close(PATCH_LOG)
}

open (RCLONE_CONFIG,'>',$rclone_file) or die $!;
	print RCLONE_CONFIG "$rclone_keys";
close (RCLONE_CONFIG);
print "Performing this now: $rclone_upload_command \n";
#system ("$rclone_upload_command");
print "Check done.\n $hostname_string\n$logfile_string";