#!/usr/bin/perl

# for my dev env
use lib qw( blib/lib ../blib/lib);

use WWW::GMail;
use strict;

die "$0 <user> <pass>\n" unless ($ARGV[0] && $ARGV[1]);

my $g = WWW::GMail->new(
	username => $ARGV[0],
	password => $ARGV[1],
	cookies => {
		autosave => 1,
		file => "./.gmail.cookie",
	},
#	debug => 1,
);

$0 = (split(/ /,$0,1))[0]; # so user/pass don't show up in ps

my $ret = $g->login();
if ($ret == -1) {
	print "password incorrect\n";
	exit;
} elsif ($ret == 0) {
	print "unable to login, unknown error\n";
	exit;
}

# yay, we're logged in, now from here you can request a list,
# a raw message, ect

  my @contacts = $g->get_contact_list();
  print "you have ".(@contacts)." contacts\n";
  
  my $gmail = 0;
  for my $i ( 0 .. $#contacts ) {
  	$gmail += ($contacts[$i]->[3] =~ m/gmail\.com$/i);
  }
  
  print "$gmail of them are gmail addresses\n";
  
# Don't logout, the cookie file keeps us logged in
#$obj->logout();

exit;

