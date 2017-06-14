package Buildctl::Constants;

use strict;
use warnings;

use Exporter;

our @ISA = 'Exporter';
our @EXPORT = qw($package_states);
our $package_states = { k => "keep", i => "ignore", f => "failed" };

