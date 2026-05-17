#!/usr/bin/env perl
# Copyright 2000-2018 The OpenSSL Project Authors. All Rights Reserved.
#
# Licensed under the OpenSSL license (the "License").  You may not use
# this file except in compliance with the License.  You can obtain a copy
# in the file LICENSE in the source distribution or at
# https://www.openssl.org/source/license.html

#
# Wrapper around the ca to make it easier to use
#

use strict;
use warnings;

my $openssl = "openssl";
if(defined $ENV{'OPENSSL'}) {
    $openssl = $ENV{'OPENSSL'};
} else {
    $ENV{'OPENSSL'} = $openssl;
}

my $verbose = 1;

my $OPENSSL_CONFIG = $ENV{"OPENSSL_CONFIG"} || "";
my $DAYS = "-days 730";		# 2 years
my $CADAYS = "-days 3650";	# 10 years
my $REQ = "$openssl req $OPENSSL_CONFIG";
my $CA = "$openssl ca $OPENSSL_CONFIG";
my $VERIFY = "$openssl verify";
my $X509 = "$openssl x509";
my $PKCS12 = "$openssl pkcs12";

# default openssl.cnf file has setup as per the following
my $CATOP = "./CA";
my $CAKEY = "cakey.pem";
my $CAREQ = "careq.pem";
my $CACERT = "cacert.pem";
my $CACRL = "crl.pem";

my $NEWKEY = "/tmp/newkey.pem";
my $NEWREQ = "/tmp/newreq.pem";
my $NEWCERT = "/tmp/newcert.pem";
my $NEWP12 = "/tmp/newcert.p12";
my $TMPREQ = "/tmp/tmpreq.pem";
my $RET = 0;
my $WHAT = shift @ARGV || "";
my @OPENSSL_CMDS = ("req", "ca", "pkcs12", "x509", "verify");
my %EXTRA = extra_args(\@ARGV, "-extra-");
my $FILE;

sub extra_args {
    my ($args_ref, $arg_prefix) = @_;
    my %eargs = map {
	if ($_ < $#$args_ref) {
	    my ($arg, $value) = splice(@$args_ref, $_, 2);
	    $arg =~ s/$arg_prefix//;
	    ($arg, $value);
	} else {
	    ();
	}
    } reverse grep($$args_ref[$_] =~ /$arg_prefix/, 0..$#$args_ref);
    my %empty = map { ($_, "") } @OPENSSL_CMDS;
    return (%empty, %eargs);
}

# See if reason for a CRL entry is valid; exit if not.
sub crl_reason_ok
{
    my $r = shift;

    if ($r eq 'unspecified' || $r eq 'keyCompromise'
        || $r eq 'CACompromise' || $r eq 'affiliationChanged'
        || $r eq 'superseded' || $r eq 'cessationOfOperation'
        || $r eq 'certificateHold' || $r eq 'removeFromCRL') {
        return 1;
    }
    print STDERR "Invalid CRL reason; must be one of:\n";
    print STDERR "    unspecified, keyCompromise, CACompromise,\n";
    print STDERR "    affiliationChanged, superseded, cessationOfOperation\n";
    print STDERR "    certificateHold, removeFromCRL";
    exit 1;
}

# Copy a PEM-format file; return like exit status (zero means ok)
sub copy_pemfile
{
    my ($infile, $outfile, $bound) = @_;
    my $found = 0;

    open IN, $infile || die "Cannot open $infile, $!";
    open OUT, ">$outfile" || die "Cannot write to $outfile, $!";
    while (<IN>) {
        $found = 1 if /^-----BEGIN.*$bound/;
        print OUT $_ if $found;
        $found = 2, last if /^-----END.*$bound/;
    }
    close IN;
    close OUT;
    return $found == 2 ? 0 : 1;
}

# Wrapper around system; useful for debugging.  Returns just the exit status
sub run
{
    my $cmd = shift;
    print "====\n$cmd\n" if $verbose;
    my $status = system($cmd);
    print "==> $status\n====\n" if $verbose;
    return $status >> 8;
}


if ( $WHAT =~ /^(-\?|-h|-help)$/ ) {
    print STDERR "usage: CA.pl -newcert | -newreq | -newreq-nodes | -xsign | -sign | -sign-client | -sign-server | -signCA | -signcert | -crl | -newca | -update-client | -update-server [prefix] [-extra-cmd extra-params]\n";
    print STDERR "       CA.pl -pkcs12 [-extra-pkcs12 extra-params] [certname] [prefix]\n";
    print STDERR "       CA.pl -verify [-extra-verify extra-params] certfile ...\n";
    print STDERR "       CA.pl -revoke [-extra-ca extra-params] certfile [reason]\n";
    exit 0;
}
if ($WHAT eq '-newcert' ) {
    # create a certificate
    my $keyfile = $ARGV[0] ? "${CATOP}/private/$ARGV[0].key" : $NEWKEY;
    my $keyargs = -e $keyfile ? "-key $keyfile" : "-keyout $keyfile";
    my $out = $ARGV[0] ? "${CATOP}/certs/$ARGV[0].pem" : $NEWCERT;
    $RET = run("$REQ -new -x509 $keyargs -out $out $DAYS $EXTRA{req}");
    print "Cert is in $out, private key is in $keyfile\n" if $RET == 0;
} elsif ($WHAT eq '-precert' ) {
    # create a pre-certificate
    my $keyfile = $ARGV[0] ? "${CATOP}/private/$ARGV[0].key" : $NEWKEY;
    my $keyargs = -e $keyfile ? "-key $keyfile" : "-keyout $keyfile";
    my $out = $ARGV[0] ? "${CATOP}/certs/$ARGV[0].pem" : $NEWCERT;
    $RET = run("$REQ -x509 -precert $keyargs -out $out $DAYS");
    print "Pre-cert is in $out, private key is in $keyfile\n" if $RET == 0;
} elsif ($WHAT =~ /^\-newreq(\-nodes)?$/ ) {
    # create a certificate request
    my $keyfile = $ARGV[0] ? "${CATOP}/private/$ARGV[0].key" : $NEWKEY;
    my $keyargs = -e $keyfile ? "-key $keyfile" : "-keyout $keyfile";
    $RET = run("$REQ -new $1 $keyargs -out $NEWREQ $DAYS $EXTRA{req}");
    print "Request is in $NEWREQ, private key is in $keyfile\n" if $RET == 0;
} elsif ($WHAT =~ /^\-newreq-client(\-nodes)?$/) {
    run("perl $0 -newreq$1 -extra-req \"-extensions v3_client_req\" @ARGV")
} elsif ($WHAT =~ /^\-newreq-server(\-nodes)?$/) {
    run("perl $0 -newreq$1 -extra-req \"-extensions v3_server_req\" @ARGV")
} elsif ($WHAT eq '-newca' ) {
    # create the directory hierarchy
    mkdir ${CATOP}, 0755;
    mkdir "${CATOP}/certs", 0755;
    mkdir "${CATOP}/crl", 0755;
    mkdir "${CATOP}/newcerts", 0755;
    mkdir "${CATOP}/pkcs12", 0700;
    mkdir "${CATOP}/pkcs15", 0700;
    mkdir "${CATOP}/private", 0700;
    open OUT, ">${CATOP}/index.txt";
    close OUT;
    open OUT, ">${CATOP}/crlnumber";
    print OUT "01\n";
    close OUT;
    # ask user for existing CA certificate
    print "CA certificate filename (or enter to create)\n";
    $FILE = "" unless defined($FILE = <STDIN>);
    $FILE =~ s{\R$}{};
    if ($FILE ne "") {
        copy_pemfile($FILE,"${CATOP}/private/$CAKEY", "PRIVATE");
        copy_pemfile($FILE,"${CATOP}/$CACERT", "CERTIFICATE");
    } else {
        print "Making CA certificate ...\n";
        $RET = run("$REQ -new -keyout"
                . " ${CATOP}/private/$CAKEY"
                . " -out ${CATOP}/$CAREQ $EXTRA{req}");
        $RET = run("$CA -create_serial"
                . " -out ${CATOP}/$CACERT $CADAYS -batch"
                . " -keyfile ${CATOP}/private/$CAKEY -selfsign"
                . " -extensions v3_intermediate $EXTRA{ca}"
                . " -in ${CATOP}/$CAREQ") if $RET == 0;
        print "CA certificate is in ${CATOP}/$CACERT\n" if $RET == 0;
    }
} elsif ($WHAT eq '-pkcs12' ) {
    my $cname = $ARGV[0];
    $cname = "My Certificate" unless defined $cname;
    shift if defined $cname;
    my $in = $ARGV[0] ? "${CATOP}/certs/$ARGV[0].pem" : $NEWCERT;
    my $inkey = $ARGV[0] ? "${CATOP}/private/$ARGV[0].key" : $NEWKEY;
    my $out = $ARGV[0] ? "${CATOP}/pkcs12/$ARGV[0].p12" : $NEWP12;
    $RET = run("$PKCS12 -in $in -inkey $inkey"
            . " -certfile ${CATOP}/$CACERT"
            . " -out $out"
            . " -export -name \"$cname\" $EXTRA{pkcs12}");
    print "PKCS #12 file is in $out\n" if $RET == 0;
} elsif ($WHAT eq '-xsign' ) {
    $RET = run("$CA -policy policy_anything $EXTRA{ca} -in $NEWREQ -notext");
} elsif ($WHAT eq '-sign' ) {
    my $out = $ARGV[0] ? "${CATOP}/certs/$ARGV[0].pem" : $NEWCERT;
    $RET = run("$CA -policy policy_anything -out $out $EXTRA{ca} -in $NEWREQ -notext");
    print "Signed certificate is in $out\n" if $RET == 0;
    unlink($NEWREQ) if $RET == 0;
} elsif ($WHAT eq '-sign-client') {
    run("perl $0 -sign -extra-ca \"-extensions v3_client_cert\" @ARGV");
} elsif ($WHAT eq '-sign-server') {
    run("perl $0 -sign -extra-ca \"-extensions v3_server_cert\" @ARGV");
} elsif ($WHAT eq '-signCA' ) {
    my $out = $ARGV[0] ? "${CATOP}/certs/$ARGV[0].pem" : $NEWCERT;
    $RET = run("$CA -policy policy_anything -out $out"
            . " -extensions v3_ca $EXTRA{ca} -in $NEWREQ -notext");
    print "Signed CA certificate is in $out\n" if $RET == 0;
    unlink($NEWREQ) if $RET == 0;
} elsif ($WHAT eq '-signcert' ) {
    my $out = $ARGV[0] ? "${CATOP}/certs/$ARGV[0].pem" : $NEWCERT;
    $RET = run("$X509 -x509toreq -in $NEWREQ -signkey $NEWREQ"
            . " -out $TMPREQ $EXTRA{x509}");
    $RET = run("$CA -policy policy_anything -out $out"
            . "$EXTRA{ca} -in $TMPREQ -notext") if $RET == 0;
    print "Signed certificate is in $out\n" if $RET == 0;
    unlink $NEWREQ, $TMPREQ if $RET == 0;
} elsif ($WHAT eq '-verify' ) {
    my @files = @ARGV ? @ARGV : ( $NEWCERT );
    my $file;
    foreach $file (@files) {
        my $status = run("$VERIFY \"-CAfile\" ${CATOP}/$CACERT $file $EXTRA{verify}");
        $RET = $status if $status != 0;
    }
} elsif ($WHAT eq '-crl' ) {
    $RET = run("$CA -gencrl -out ${CATOP}/crl/$CACRL $EXTRA{ca} -notext");
    print "Generated CRL is in ${CATOP}/crl/$CACRL\n" if $RET == 0;
} elsif ($WHAT eq '-revoke' ) {
    my $cname = $ARGV[0];
    if (!defined $cname) {
        print "Certificate filename is required; reason optional.\n";
        exit 1;
    }
    my $reason = $ARGV[1];
    my $certfile = "${CATOP}/certs/$cname.pem";
    my $keyfile = "${CATOP}/private/$cname.key";
    $reason = " -crl_reason $reason"
        if defined $reason && crl_reason_ok($reason);
    $RET = run("$CA -revoke \"$certfile\"" . $reason . $EXTRA{ca});
    unlink $certfile, $keyfile if $RET == 0;
} elsif ($WHAT eq '-update-client') {
    run("perl $0 -newreq-client @ARGV");
    run("perl $0 -sign-server @ARGV");
} elsif ($WHAT eq '-update-server') {
    run("perl $0 -newreq-server @ARGV");
    run("perl $0 -sign-server @ARGV");
} else {
    print STDERR "Unknown arg \"$WHAT\"\n";
    print STDERR "Use -help for help.\n";
    exit 1;
}

exit $RET;
