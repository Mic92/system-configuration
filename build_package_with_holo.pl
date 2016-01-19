#!/usr/bin/perl
use strict;
use warnings;
use v5.20;

use autodie qw(:all);
use IPC::Open2;

# the first argument is the package definition file
my $filename = shift @ARGV;

# read file for package name
my $pkgname;
open my $fh, '<', $filename;
while (<$fh>) {
   if (/^\s*name\s*=\s*"(.+?)"\s*$/) {
      $pkgname = $1;
      last;
   }
}
close($fh);

# use holo-build to find the package file name
open $fh, '-|', 'sh', '-c', "holo-build --suggest-filename < $filename";
chomp(my $package_file = <$fh>);
close($fh);

# read makepkg.conf to see if signing is wanted
my ($sign, $gpg_key) = (0, undef);
open $fh, '<', '/etc/makepkg.conf';
while (<$fh>) {
   if (/^\s*BUILDENV\s*=\s*\((.+?)\)\s*$/) {
      $sign = $1 =~ /\b(?<!!)sign\b/;
   }
   elsif (/^\s*GPGKEY\s*=\s*"(.+?)"\s*$/) {
      $gpg_key = $1;
   }
}
close($fh);

################################################################################
# build package if it's not yet there
#
# (we're running inside the repo directory, so auto-output is fine)

if (not -f $package_file) {
   system("holo-build <$filename");
}
if ($sign and not -f "$package_file.sig") {
   system("gpg", "--detach-sign", "--use-agent", ($gpg_key ? ("-u", $gpg_key) : ()), "--no-armor", $package_file);
}

################################################################################
# clean earlier versions of this package

for my $other_file (glob("$pkgname-*.pkg.tar.xz")) {
   # check that this is not the latest version of the package
   next if $other_file eq $package_file;
   # check that this is really a file for this package, not for another package
   # whose name starts with that of the current package (globs can't tell that
   # apart)
   next if $other_file !~ m{^\Q$pkgname\E-[0-9.]+-[0-9]+-.*\.pkg\.tar\.xz};
   say "Cleaning up $other_file (looks like an old version of $package_file)";
   unlink $other_file;
}

