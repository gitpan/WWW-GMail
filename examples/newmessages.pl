#!/usr/bin/perl

# for my dev env
use lib qw(/projects/lib);

use WWW::GMail;
use strict;

die "$0 <user> <pass>\n" unless ($ARGV[0] && $ARGV[1]);

my $g = WWW::GMail->new(
	username => $ARGV[0],
	password => $ARGV[1],
	cookies => {
		autosave => 1,
		file => "./gmail.cookie",
	},
#	debug => 1,
);

my $ret = $g->login();
if ($ret == -1) {
	print "password incorrect\n";
} elsif ($ret == 0) {
	print "unable to login, unknown error\n";
	exit;
}

# yay, we're logged in, now from here you can request a list,
# a raw message, ect

# inbox, starred, sent, all, spam, trash, and labels
my @list = $g->get_message_list('inbox');

# count the new messages in the inbox
my $new_msgs = 0;
for my $i ( 0 .. $#list ) {
	$new_msgs += $list[$i]->[1]; # count the unread flags
}

#require Data::Dumper;
#print Data::Dumper->Dump([\@list]);

print "Number of new messages in $g->{list_folder}: $new_msgs\n";

# grab the raw form of the first message in the inbox, if available
if (@list) {
	print "First message in $g->{list_folder}:\n";
	print $g->get_message_raw($list[0]->[0]);
}

# Don't logout, the cookie file keeps us logged in
#$obj->logout();

exit;

