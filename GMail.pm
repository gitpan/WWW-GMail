package WWW::GMail;

# GoogleMail (GMail)
# a perl interface to google mail
# Copyright (c) 2004 - David Davis

our $VERSION = '0.02';

use HTTP::Cookies;
use LWP::UserAgent;
use HTTP::Request;
# XXX the makefile should make sure we have it
#use Crypt::SSLeay; # cause LWP::UserAgent needs it for https

sub new {
	my $class = shift;
	my %opts = @_;

	$self->{debug} && print STDERR "In new()\n";
	
	unless ($opts{agent}) {
		# fake as ie 6
		$opts{agent} = "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; .NET CLR 1.1.4322)";
	}
	
	my $obj = bless(\%opts,$class);
	
	$obj->{error} = '';
	$self->{debug} && print STDERR "Setting user-agent to [$opt{agent}]\n";
	
	$obj->{ua} = LWP::UserAgent->new();
	$obj->{ua}->agent($opts{agent});

	$self->{debug} && print STDERR "Setting up cookie jar (HTTP\:\:Cookies)\n";
	
	my $jar = $obj->{jar} = HTTP::Cookies->new(%{$opts{cookies}});

	$obj->{ua}->cookie_jar($jar);
	
	$self->{debug} && print STDERR "new() complete\n";
	
	return $obj;
}

sub login {
	my $self = shift;
	my $username = $self->{username};
	my $password = $self->{password};
	my $content = undef;
	
	$self->{debug} && print STDERR "In login()\n";
	
	# faster!
	return 1 if ($self->js_version());

	$self->{debug} && print STDERR "Setting up cookie jar\n";
	
	$self->{jar}->set_cookie("0",	# version
		"GMAIL_LOGIN",				# key
		sprintf("T%s/%s/%s",int(time()-2),int(time()-1),int time()),	# value
		"/",						# path
		".google.com",				# domain
		undef,						# port
		1,							# path_spec (bool)
		0,							# secure (bool)
		(60 * 60 * 24 * 7),			# max age ( 7 days )
		0,							# discard (bool)
		{ }							# rest (Comment, CommentURL)
	);
	
	$self->{debug} && print STDERR "Requesting login\n";
	
	my $req = HTTP::Request->new(POST => 'https://www.google.com/accounts/ServiceLoginBoxAuth');
	$req->content_type('application/x-www-form-urlencoded');
	$req->content(sprintf("service=mail&continue=https://gmail.google.com/gmail&Email=%s&Passwd=%s&PersistentCookie=yes&null=Sign%20in", $username, $password));
	my $res = $self->{ua}->request($req);
	delete $self->{http_status_line};
	
	if ($res->is_success) {
		$self->{debug} && print STDERR "Request success\n";
		$content = $res->content;

		if ($content =~ m/top.location\s=\s"([^"]+)";/) {
			$self->{debug} && print STDERR "Got login cookie\n";
			$self->{debug} && print STDERR "Saving cookie jar\n";
			
			# make sure we save our cookies
			$self->{jar}->save();
			
			$self->{debug} && print STDERR "Requesting cookie check\n";
			
			# load the CheckCookie url
			#PersistentCookie=yes
#			$req = HTTP::Request->new(GET => 'https://www.google.com/accounts/CheckCookie?service=mail&continue=http%3A%2F%2Fgmail.google.com%2Fgmail&chtml=LoginDoneHtml');
			$req = HTTP::Request->new(GET => 'https://www.google.com/accounts/'.$1);
			
			$res = $self->{ua}->request($req);
			delete $self->{http_status_line};
			if ($res->is_success) {
				$self->{debug} && print STDERR "Request success\n";
				$content = $res->content;
				# TODO check content?
				$req = HTTP::Request->new(GET => 'http://www.google.com/');
				$res = $self->{ua}->request($req);
				
				return 1 if ($self->js_version());
			} else {
				$self->{error} = $res->status_line;
			}
		} elsif ($content =~ m/Username and password do not match/i) {
			$self->{debug} && print STDERR "Username and/or password do not match\n";
			$self->{error} = "Username and/or password do not match";
			return -1;
		} else {
			$self->{debug} && do {
				open(FH,">/tmp/gmail-debug.txt");
				print FH $content;
				close(FH);
				print STDERR "Uknown error, content dumped to /tmp/gmail-debug.txt\n";
			};
			$self->{error} = "unknown error (module not smart enough)";
		}
	} else {
		$self->{debug} && print STDERR "Request failure error[".$res->status_line."]\n";
		$self->{error} = $res->status_line;
	}
	
	$self->{debug} && print STDERR "login() error...\n";
	
	return 0;
}

sub get_message_list {
	my $self = shift;
	my $folder = shift;
	my $offset = shift || 0;
	
	$self->{debug} && print STDERR "In get_message_list(folder[$folder],offset[$offset])\n";
	
	my $content = undef;
	my $req = HTTP::Request->new(GET => sprintf("http://gmail.google.com/gmail?search=%s&view=tl&start=%d&init=1&zx=%s%s", $folder, $offset, $self->{js_version}, $self->zx()));
	my $res = $self->{ua}->request($req);
	my @list;
	
	$self->{debug} && print STDERR "Got request\n";
	
	if ($res->is_success) {
		$self->{debug} && print STDERR "Request success\n";

		$content = $res->content;
		
		$self->{debug} && print STDERR "Request success, processing list (if any)\n";
		
		# process message list
		while ($content =~ m/
			     ,\["([^"]+)"		# 1 id
			     ,(\d+)				# 2 unread=1,read=0
			     ,(\d+)				# 3 starred=1,not=0
			     ,"([^"]+)"			# 4 date
			     ,"([^"]+)"			# 5 from
			     ,"([^"]+)"			# 6 indicator
			     ,"([^"]+)"			# 7 subj
			     ,"([^"]+)"			# 8 sent
			     ,\[(?:"(.+)")?\]\s # 9 tags
			     ,"([^"]+)?"		# 10 attachments
			     ,"([^"]+)"			# 11 id (again)
			     ,(\d+)				# 12 ?
			     /xg) {
			push(@list,[$1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12]);
			# turn the label tags into an array ref
			$list[-1][8] = [ split('","',$list[-1][8]) ];
		}
		
		#D(["qu","1 MB","1000 MB","0%","#006633"]\n);
		if ($content =~ m/D\(\["qu","([^"]+)","([^"]+)","([^"]+)/) {
			($self->{used}, $self->{total}, $self->{percent_used}) = ($1,$2,$3);
		}
	
		$self->{debug} && print STDERR "Processed percentages used[$self->{used}] total[$self->{total}] percent_used[$self->{percent_used}]\n";
		
		#D(["ts",0,50,88,0,"All Mail","fd5a5ed691",170]\n);
		if ($content =~ m/D\(\["ts",(\d+),(\d+),(\d+),(\d+),"([^"]+)","([^"]+)",(\d+)\]/) {
			($self->{unknown_0}, $self->{per_page}, $self->{list_total},
				$self->{unknown_1}, $self->{list_folder}, $self->{unknown_2},
				$self->{unknown_3}) = ($1,$2,$3,$4,$5,$6,$7);
		}
		
		$self->{debug} && print STDERR "Processed misc data per_page[$self->{per_page}] list_total[$self->{list_total}]".
			" list_folder[$self->{list_folder}] unknown_0[$self->{unknown_0}] unknown_1[$se2f->{unknown_1}]".
			" unknown_2[$self->{unknown_2}] unknown_3[$self->{unknown_3}]\n";
		
		# list of labels
		if ($content =~ m/D\(\["ct",\[(.*)\n\]\n\]\n\);/s) {
			delete $self->{labels};
			my $tmp = ",$1";
			while ($tmp =~ m/
			     ,\["([^"]+)" # 1 label
			     ,(\d+)       # 2 number of new
			     /xg) {
				push(@{$self->{labels}},[$1,$2]);
			}
		}
		
		$self->{debug} && print STDERR "Processed labels, complete\n";

		return @list;
	} else {
		$self->{debug} && print STDERR "Request failure error[".$res->status_line."]\n";
		$self->{error} = $res->status_line;
		return ();
	}
}

sub get_message_raw {
	my ($self, $msg_id) = @_;

	$self->{debug} && print STDERR "In get_message_raw(msg_id[$msg_id]), making request...\n";
	
	my $req = HTTP::Request->new(GET => sprintf("http://gmail.google.com/gmail?view=om&th=%s&zx=%s%s", $msg_id, $self->{js_version}, $self->zx()));
	my $res = $self->{ua}->request($req);
	
	$self->{debug} && print STDERR "Got request\n";
	
	if ($res->is_success) {
		$self->{debug} && print STDERR "Request success\n";
		return $res->content;
	} else {
		$self->{debug} && print STDERR "Request failure error[".$res->status_line."]\n";
		$self->{error} = $res->status_line;
	}
	
	return undef;
}

sub zx {
	return int ( rand ( 1000000000 ) );	
}

sub js_version {
	my $self = shift;
	
	$self->{debug} && print STDERR "In js_version()\n";
	
	return 1 if ($self->{js_version});
	
	$self->{debug} && print STDERR "Requesting javascript from gmail.google.com\n";
	
	my $req = HTTP::Request->new(GET => 'http://gmail.google.com/gmail?view=page&name=js');
	my $res = $self->{ua}->request($req);

	$self->{debug} && print STDERR "Got request\n";
	
	if ($res->is_success) {
		$self->{debug} && print STDERR "Request success\n";
		my $content = $res->content;
		if ($content =~ m/var js_version\s*=\s*'([^']+)'/) {
			$self->{debug} && print STDERR "Got js_version[$1]\n";
			# save this for later
			$self->{js_version} = $1;
			$self->{logged_in} = 1;
			return 1;
		} else {
			$self->{debug} && print STDERR "Problem getting js_version, password incorrect?\n";
			$self->{error} = "Problem getting js_version, password incorrect?";
			# not logged in...
			$self->{logged_in} = 0;
		}
	} else {
		$self->{error} = $res->status_line;
	}
	
	return 0;
}

sub logout {
	my $self = shift;

	$self->{debug} && print STDERR "In logout(), making request...\n";
	
	my $req = HTTP::Request->new(GET => "http://gmail.google.com/gmail?logout");
	my $res = $self->{ua}->request($req);
	
	$self->{debug} && print STDERR "Got request\n";
	
	if ($res->is_success) {
		$self->{debug} && print STDERR "Request success\n";
		return 1;
	} else {
		$self->{debug} && print STDERR "Request failure error[".$res->status_line."]\n";
		$self->{error} = $res->status_line;
	}
	
	return 0;
}

1;

__END__

=head1 NAME

WWW::GMail - Perl extension for accessing Google Mail (gmail)

=head1 SYNOPSIS

  use WWW::GMail;
  
  my $obj = WWW::GMail->new(
  	username => "USERNAME",
  	password => "PASSWORD",
  	cookies => {
  		autosave => 1,
  		file => "./gmail.cookie",
  	},
  );
  
  
  my $ret = $obj->login();
  if ($ret == -1) {
  	print "password incorrect\n";
  } elsif ($ret == 0) {
  	print "unable to login $obj->{error}\n";
  	exit;
  }
  
  my @list = $obj->get_message_list('inbox');
  
  # count the new messages in the inbox
  my $new_msgs = 0;
  for my $i ( 0 .. $#list ) {
  	$new_msgs += $list[$i]->[1]; # count the unread flags
  }
  
  $obj->logout();

=head1 ABSTRACT

This module simplifies access to gmail.

=head1 DESCRIPTION

Currently it allows retrieval of message lists, and raw messages.

=head2 Methods

There are currently 5 methods

=over 4

=item C<new>

This will setup the object, useragent and cookie jar.

The L<HTTP::Cookies> object is stored  as $obj->{jar}
The L<LWP::UserAgent> object is stored as $obj->{ua}

The new method accepts a hash of options:

=over 4

=item C<username>

GMail username, stored as $obj->{username}

=item C<password>

GMail password, stored as $obj->{password}

=item C<cookies>

A hash ref of options passed to L<HTTP::Cookies>
Specify {} to make the session temporary.

=item C<agent>

* Optional!
A useragent string passed to L<LWP::UserAgent>

=back 4

=item C<login>

Logs into GMail, DO THIS FIRST, duh...

Return values are:
1 login correct
0 some error happend, check $obj->{error} for reason
-1 incorrect password and/or username

=item C<get_message_list>

This method returns an array of arrays
Each array has an array of info about the message
Currenly, WWW::GMail doesn't strip the html entities, do that yourself for now.
A future version will have an option passed to new() to adjust this.

The array

=over 4

  0	message id (pass this to get_message_raw)
  1	unread = 1,read = 0
  2	starred = 1,not = 0
  3	date
  4	from
  5	indicator
  6	subj
  7	sent
  8	labels
  9	attachments
  10	message id (again?)
  11	? unknown

=back 4

See the SYNOPSIS

Also available after calling get_message_list is:

  Used space	$self->{used}
  Total space	$self->{total}
  Percent used	$self->{percent_used}
  Per page	$self->{per_page}
  List total	$self->{list_total}
  List folder	$self->{list_folder}

  Labels	$self->{labels} (an array of arrays)
  The array
 	 0		label
 	 1		number of new

=item C<get_message_raw>

Pass it a message id from a message list (see get_message_list)
Retrieves the raw message as a scalar, headers and all.
Returns undef if there was an error or invalid id
Check $obj->{error} for messages

=item C<logout>

Logs out the current logged in account.

=back 4

=head1 EXPORT

Nothing. Its all Object Orientated.

=head1 SEE ALSO

L<LWP::UserAgent>, L<HTTP::Cookies>

=head1 TODO

Contact management, label management, and better docs.
Also, what happends when the js_version changes?
Enable persistant cookie?

=head1 AUTHOR

David Davis E<lt>xantus@cpan.orgE<gt>

=head1 NOTICE

**Use this module at your own risk, and read your Gmail terms of use**

=head1 COPYRIGHT AND LICENSE

Copyright 2004 by David Davis and Teknikill Software

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

