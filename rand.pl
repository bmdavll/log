#!/usr/bin/perl
#########################################################################
#
#   Copyright 2009 David Liang
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#   Revisions:
#   2009-09-20  File created
#
#########################################################################
use strict;
use warnings;
use File::Basename qw(basename);
use Getopt::Long;

my $PROG = basename($0);
my $VERSION = '0.8';
my $SEP = ':';

sub Debug {
	require Data::Dumper;
	Data::Dumper->import qw(Dumper);
	no warnings;
	$Data::Dumper::Terse = 1;
	$Data::Dumper::Indent = 0;
	local ($,, $\) = (" ", "\n");
	print STDERR map { Dumper($_) } @_;
}

BEGIN {
    sub errorFormat {
        s[(?:,?\ at\ (?:(?:$0|\(eval\ \d+\)|<\w+>|/usr/\S+)\ line\ \d+|
                        EOF|end\ of\ line))+
         ((?:,\ near\ ".*")?)\.?$]
         [$1]gmx for my @args = @_;
        return join('', @args);
    }
    $SIG{__WARN__} = sub { print STDERR errorFormat(@_)         };
    $SIG{__DIE__}  = sub { print STDERR errorFormat(@_); exit 1 };
}

# options
Getopt::Long::Configure
    qw(gnu_getopt no_gnu_compat no_auto_abbrev no_ignore_case);

sub Interpolate {
    my ($SPC, $PSPC) = (' ', ' ' x length($PROG));
    my $doc = join('', @_);
    $doc =~ s/\\\n//g;
    $doc =~ s/\*(\w+)\*/$1/g;
    return eval 'qq('.$doc.')';
}
sub Man {
    open(STDIN, '-|', 'pod2man '.quotemeta($0).' | nroff -man') and
    open(STDOUT, '|-', $ENV{PERLDOC_PAGER} ||
                       $ENV{MANPAGER}      ||
                       $ENV{PAGER}         || 'less') or exit 127;
    print Interpolate(<STDIN>);
    close(STDOUT);
    exit shift;
}
sub Usage {
    my ($exitval, $verbose, @message) = @_;
    &Man if $verbose == 2;
    my $OUT = ($exitval == 0 ? \*STDOUT : \*STDERR);
    if (@message) {
        print $OUT @message, "\n\n";
    } elsif ($exitval == 2) {
        print $OUT "\n";
    }
    require Pod::Usage;
    Pod::Usage->import qw(pod2usage);
    open(USAGE, '+>', undef) or die $!;
    pod2usage(
        -exitval => 'NOEXIT',
        -verbose => $verbose,
        -output  => \*USAGE,
    );
    seek USAGE, 0, 0;
    @message = <USAGE>;
    $verbose = 'Usage:';
    if (@message >= 2 and $message[0] =~ /^$verbose$/) {
        shift @message;
        $message[0] =~ s/^\s{6}/$verbose/;
    }
    print $OUT Interpolate(@message);
    exit $exitval;
}

my (
    $not,
    $ignore_case,
    $all,
    $sort,
    $extract,
    $canonical,
    $wrap,
);
my %opts = (
    'grep' => [],
    'grep-not' => [],
    'not' => \$not,
    'ignore-case' => \$ignore_case,
    'all' => \$all,
    'fixed' => [],
    'exclude' => [],
    'sort' => \$sort,
    'extract' => \$extract,
    'canonical' => \$canonical,
    'wrap' => \$wrap,
);
GetOptions(
    \%opts,
    'man',
    'help|h',
    'usage|?',
    'delimiter|d=s',
    'comment|c=s',
    'encoding=s',

    'grep|g=s',
    'grep-not|G=s',
    'not|v',
    'ignore-case|i',
    'search-all|s',
    'all|a',
    'fixed|f=s',
    'exclude|e=s',
    'random|m',
    'sort|S:s',
    'extract=s',
    'first',
    'last',

    'N:s',
    'n:s',
    'number:s',
    'canonical|C',
    'first-line|F',
    'preserve|p',
    'raw|r',
    'tabs|t:8',
    'wrap|w:'.($ENV{COLUMNS} || 80),
    'list',
    'count',
) or Usage(2, 0);

# process options
Usage(0, 2) if $opts{man};
Usage(0, 1, $PROG, "\t", $VERSION) if $opts{help};
Usage(0, 0) if $opts{usage};

sub argError {
    Usage(2, 0, 'Invalid argument for option ', shift, ': ', shift);
}

my ($delimited, $re_delim);
if (defined $opts{delimiter}) {
    $delimited = 1;
    $re_delim = '[ \t]*\n?';
    eval { $re_delim = qr[^$opts{delimiter}$re_delim] };
    die $@ if $@;
} else {
    $re_delim = qr[\S];
}

my $re_comment;
if (defined $opts{comment}) {
    eval {
      my $line_comment = '(?:^|\n|\G)\K[ \t]*'.$opts{comment}.'.*(?:\n|$)';
      my $trailing_part_comment = '\S\K[ \t]+'.$opts{comment}.'.*';
      $re_comment = qr[$line_comment|$trailing_part_comment];
    };
    die $@ if $@;
} else {
    $re_comment = qr[^];
}

my (@grep, @vgrep);
$ignore_case = ($ignore_case ? 'i' : '');
foreach (@{$opts{grep}}) {
    push @grep, eval 'qr['.$_.']'.$ignore_case;
    die $@ if $@;
}
foreach (@{$opts{'grep-not'}}) {
    push @vgrep, eval 'qr['.$_.']'.$ignore_case;
    die $@ if $@;
}

if (defined $sort) {
    if (defined $extract) {
        $extract = eval 'sub ($) { local $_ = shift; '.$extract.' }';
        die $@ if $@;
    } else {
        $extract = sub { shift };
    }
    $sort = '$a cmp $b' if $sort eq '';
    $sort =~ s/(?<!{)(\$[ab])(?!}|->)/$1\->[1]/g;
    $sort = eval 'sub () { no warnings; '.$sort.' }';
    die $@ if $@;
}

$opts{preserve} = 1 if $opts{raw};

my $ts = (defined $opts{tabs} ? $opts{tabs} : 8);
argError('tabs', $ts) if $ts <= 0;
argError('wrap', $wrap) if defined $wrap and $wrap <= 0;

# main
if (not @ARGV) {
    Usage(1, 0, 'No files given') if -t STDIN;
    @ARGV = '-';
}
my $tmp;

# slurp entries
my (@entries, $entry);

foreach (@ARGV) {
    my $file;
    if ($_ eq '-') {
        $file = \*STDIN;
    } else {
        open($file, '<', $_) or warn $_, ': ', $! and next;
    }
    if (defined $opts{encoding}) {
        binmode $file, ':encoding('.$opts{encoding}.')'
        or die $!, ' for option encoding: ', $opts{encoding};
    }
    while (<$file>) {
        if ($delimited) {
            if (/$re_delim/) {
                push @entries, $entry;
                undef $entry;
            }
        } else {
            $tmp = $_;
            $tmp =~ s/$re_comment//;
            if ($tmp =~ /$re_delim/) {
                push @entries, $entry;
                undef $entry;
            }
        }
        $entry .= $_;
    }
    close($file) if $file != \*STDIN;
}
push @entries, $entry;
shift @entries if not defined $entries[0];

# prepend zeroth entry if not present
if (@entries) {
    $tmp = $entries[0];
    $tmp =~ s/$opts{comment}.*//s if not $delimited and
                                     defined $opts{comment};
    unshift @entries, undef if $tmp =~ /$re_delim/;
}

# determine included and excluded entries
sub convertIndex {
    $_ = shift;
    if (substr($_, 0, 1) eq '-') {
        return  0 if $_ == 0;
        $_ = $#entries + int($_) + 1;
        return -1 if $_ == 0;
        return $_;
    } else {
        return int($_);
    }
}
sub min { return $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { return $_[0] > $_[1] ? $_[0] : $_[1] }

my $re_range = qr[^(-?\d+)?($SEP)?(-?\d+)?$];

sub parseList {
    my ($type, $threshold) = (shift, undef);
    my %hash;
    my $list = join(',', @{$opts{$type}});
    $list =~ s/^\s+|\s+$//g;
    my @range = grep { $_ ne '' } split(/\s*,\s*/, $list);
    foreach (@range) {
        argError($type, $_) if not /$re_range/;
        my ($l, $u);
        if ($2) {
            argError($type, $_) if not (defined $1 or defined $3);
            if (not defined $1) {
                $l = 1;
                $u = convertIndex($3);
            } elsif (not defined $3) {
                $l = convertIndex($1);
                $hash{0} = 1 if $l == 0;
                if (not defined $threshold) {
                    $threshold = $l if $l <= $#entries;
                } else {
                    $threshold = min($threshold, $l);
                }
                next;
            } else {
                $l = convertIndex($1);
                $u = convertIndex($3);
            }
        } else {
            argError($type, $_) if defined $3;
            $l = $u = convertIndex($1);
        }
        next if $l > $u;
        $hash{0} = 1 if $l == 0 or $u == 0;
        $u = min($u, (defined $threshold ? $threshold : $#entries));
        for (my $i = max($l, 1); $i <= $u; ++$i) {
            $hash{$i} = 1;
        }
    }
    return \%hash, (defined $threshold ? max($threshold, 0) : undef);
}
my $threshold;

($tmp, $threshold) = parseList 'exclude';
delete $entries[$_] foreach keys %{$tmp};
$#entries = $threshold-1 if defined $threshold;

($tmp, $threshold) = parseList 'fixed';
my %fixed = %{$tmp};
delete $entries[0] if not $fixed{0};
$threshold = $#entries+1 if not defined $threshold;

my $random = $opts{random};
if (not @{$opts{fixed}} and not $all) {
    $random = $all = 1;
}

sub skip {
    my $i = shift;
    if ($all or $fixed{$i} or $i >= $threshold) {
        return 0 if defined $entries[$i];
    }
    return 1;
}

# search entries
# get selected indices
my $ops = 0;
my ($E_DELIM, $E_COMMT, $E_FIRST, $E_BLANK,
    $S_DELIM, $S_COMMT, $S_FIRST) = (
    1<<0,
    1<<1,
    1<<2,
    1<<3,
    1<<4,
    1<<5,
    1<<6,
);
if (not $opts{'search-all'}) {
  do {
      $ops|= $E_DELIM if not $opts{raw} and $delimited;
      $ops|= $E_FIRST if $opts{'first-line'};
    do {
      $ops|= $E_COMMT if defined $opts{comment};
      $ops|= $E_BLANK if not $ops & $E_FIRST and not $delimited;
    } if not $opts{preserve};
  } if not $opts{list} || $opts{count};
  do {
      $ops|= $S_DELIM if not $ops & $E_DELIM and $delimited;
      $ops|= $S_COMMT if not $ops & $E_COMMT and defined $opts{comment};
      $ops|= $S_FIRST if not $ops & $E_FIRST;
  }
}
my $re_first_line = qr[(?:^|\s*\n)([^\n]*).*]s;
my $re_blank_line = qr[(?:^|\n)\K\s*\n];

my $no_grep = not (@grep or @vgrep);
my $no_grep_or_sort = ($no_grep and not defined $sort);

my @indices;
my %entries;

LOOP: for (my $i = 0; $i <= $#entries; ++$i) {
    next if skip($i);
    push @indices, $i;
    $entries[$i] =~ s/$re_delim//          if $ops & $E_DELIM;
    $entries[$i] =~ s/$re_comment//g       if $ops & $E_COMMT;
    $entries[$i] =~ s/$re_first_line/$1\n/ if $ops & $E_FIRST;
    $entries[$i] =~ s/$re_blank_line//g    if $ops & $E_BLANK;
    $entries[$i] = "\n" if $entries[$i] eq '';

    next if $no_grep_or_sort or $i == 0;
    my $srch = $entries[$i];
    $srch =~ s/$re_delim//          if $ops & $S_DELIM;
    $srch =~ s/$re_comment//g       if $ops & $S_COMMT;
    $srch =~ s/$re_first_line/$1\n/ if $ops & $S_FIRST;
    $srch = "\n" if $srch eq '';
    $entries{$i} = \$srch if defined $sort;

    next if $no_grep;
    foreach (@grep) {
        if ($srch !~ /$_/) {
            goto REMOVE unless $not;
            next LOOP;
        }
    }
    foreach (@vgrep) {
        if ($srch =~ /$_/) {
            goto REMOVE unless $not;
            next LOOP;
        }
    }
    goto REMOVE if $not;
    next;

REMOVE:
    pop @indices;
    delete $entries{$i};
}
my $max_index = $indices[$#indices];

# temporarily ignore entry zero
shift @indices if not skip(0);

# choose random, first, or last
# sort
if (@indices) {
    my $chosen;
    if ($opts{random} or ($random and not $opts{first} || $opts{last})) {
        $chosen = int(rand($#indices+1));
    } elsif (defined $sort and not $opts{count}) {
        @indices = map { $_->[0] } sort $sort
                   map { [ $_, $extract->(${$entries{$_}}) ] }
                   sort keys %entries;
    }
    if ($opts{first}) {
        $chosen = 0;
    } elsif ($opts{last}) {
        $chosen = $#indices;
    }
    if (defined $chosen) {
        @indices = $indices[$chosen];
        $max_index = $chosen;
    }
}

# print count
if ($opts{count}) {
    print scalar(@indices), "\n";
    exit;
}

unshift @indices, 0 if not skip(0);
exit if not @indices;

# print list
if ($opts{list}) {
    local ($,, $\) = ("\n", "\n");
    print @indices;
    exit;
}

# strip delimiters, comments, lines after the first, and blank lines
$ops = 0;
if ($opts{'search-all'}) {
    $ops|= $E_DELIM if not $opts{raw} and $delimited;
    $ops|= $E_FIRST if $opts{'first-line'};
  do {
    $ops|= $E_COMMT if defined $opts{comment};
    $ops|= $E_BLANK if not $ops & $E_FIRST and not $delimited;
  } if not $opts{preserve};
}
if ($ops) {
    for my $i (@indices) {
        $entries[$i] =~ s/$re_delim//          if $ops & $E_DELIM;
        $entries[$i] =~ s/$re_comment//g       if $ops & $E_COMMT;
        $entries[$i] =~ s/$re_first_line/$1\n/ if $ops & $E_FIRST;
        $entries[$i] =~ s/$re_blank_line//g    if $ops & $E_BLANK;
        $entries[$i] = "\n" if $entries[$i] eq '';
    }
}

# expand tabs
if ($opts{tabs} or $wrap) {
    my $re_tabs = qr[\G((?:[^\t\n]*\n)*)([^\t]*)(\t+)];
    $entries[$_] =~ s[$re_tabs]
                     [$1.$2.' 'x(length($3) * $ts - length($2) % $ts)]ge
    foreach @indices;
}

# format number or bullet
my ($number, $pre, $suf, $pad, $format, $count);

if (defined $opts{N} or defined $opts{n} or defined $opts{number}) {
    $number = 1;
    foreach ('N', 'n', 'number') {
        $opts{$_} = '' if not defined $opts{$_};
    }
    if ($opts{number} ne '') {
        if ($opts{number} =~ /(.*?(?:\A|(?<=[^%]))(?:%%)*)%d(.*)/s) {
            $pre = $1;
            $suf = $2;
        } else {
            $number = 0;
            $pre = '';
            $suf = $opts{number};
        }
    } else {
        $pre = $opts{N};
        $suf = $opts{n};
    }
    $pre =~ s/%%/%/g;
    $suf =~ s/%%/%/g;
    if ($number) {
        $suf .= ' ';
        $pad = length $pre.( $canonical ? $#indices+skip(0)
                                        : $max_index ).$suf;
    } else {
        $pad = length $suf;
    }
    $format = '%'.( $pre ne '' ? '-' : '' ).$pad.'s';
    $count = skip(0) ? 0 : -1;
} else {
    $pad = 0;
}

# parameters for wrap
my ($lim, $lim_1, $lim_2, $wrapped);
if ($wrap) {
    $lim_1 = max($wrap - 1, $pad + 1);
    $lim_2 = $lim_1 - $pad;
}
$pad = ' ' x $pad;

# print entries
binmode STDOUT, ':encoding('.$opts{encoding}.')' if defined $opts{encoding};
foreach (@indices) {
    if ($format) {
        $entry = sprintf $format, $pre.( $number ? $canonical ? ++$count
                                                              : $_
                                                 : '' ).$suf;
        $entry .= $entries[$_];
        $entry =~ s/\n\K/$pad/g;
        $entry =~ s/$pad$//;
    } else {
        $entry = $entries[$_];
    }
    if ($wrap) {
        chomp $entry;
        foreach (split(/\n/, $entry, -1)) {
            $lim = $lim_1;
            $wrapped = 0;
            while ($_ !~ /\G\z/gc) {
                print "\n", $pad if $wrapped;
                if (/\G(.{0,$lim})(\s|\z)/gc) {
                    print $1, $2;
                } elsif (/\G(.{$lim})/gc) {
                    print $1;
                }
                $lim = $wrapped = $lim_2;
            }
            print "\n";
        }
    } else {
        print $entry;
    }
}

__END__
=head1 NAME

$PROG - extraction of lines or sections from text files

=head1 SYNOPSIS

   $PROG
   $PSPC

=head1 DESCRIPTION

=head1 OPTIONS

=over 8

=item B<--man>

=item B<-h>, B<--help>

=item B<-?>, B<--usage>

=item

=item B<Input>

=item B< >B< >B<-d> I<DELIM>, B<--delimiter> I<DELIM>

=item B< >B< >B<-c> I<STR>, B<--comment> I<STR>

=item B< >B< >B<--encoding> I<NAME>

=item

=item B<Entry selection>

=item B< >B< >B<-g> I<PATTERN>, B<--grep> I<PATTERN>

=item B< >B< >B<-G> I<PATTERN>, B<--grep-not> I<PATTERN>

=item B< >B< >B<-v>, B<--not>

=item B< >B< >B<-i>, B<--ignore-case>

=item B< >B< >B<-s>, B<--search-all>

=item B< >B< >B<-a>, B<--all>

=item B< >B< >B<-f> I<LIST>, B<--fixed> I<LIST>

=item B< >B< >B<-e> I<LIST>, B<--exclude> I<LIST>

=item B< >B< >B<-m>, B<--random>

=item B< >B< >B<-S> [I<COMMAND>], B<--sort> [I<COMMAND>]

=item B< >B< >B<--extract> I<COMMAND>

=item B< >B< >B<--first>

=item B< >B< >B<--last>

=item

=item B<Output>

=item B< >B< >B<-N> [I<PREFIX>]

=item B< >B< >B<-n> [I<SUFFIX>]

=item B< >B< >B<--number> [I<FORMAT>]

=item B< >B< >B<-C>, B<--canonical>

=item B< >B< >B<-F>, B<--first-line>

=item B< >B< >B<-p>, B<--preserve>

=item B< >B< >B<-r>, B<--raw>

=item B< >B< >B<-t> [I<NUM>], B<--tabs> [I<NUM>]

=item B< >B< >B<-w> [I<NUM>], B<--wrap> [I<NUM>]

=item B< >B< >B<--list>

=item B< >B< >B<--count>

=back

=cut

=for vim:set ts=4 sw=4 et:
