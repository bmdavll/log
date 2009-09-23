#!/usr/bin/perl
use strict;
use warnings;

use File::Basename qw(basename);
my $PROG = basename($0);
my $VERSION = '0.5';

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
        $_ = shift;
        s/\sat\s(?:$0|\(eval\s\d+\))\sline\s\d+\.?$//;
        return $_;
    }
    $SIG{__WARN__} = sub { print STDERR errorFormat(@_) };
    $SIG{__DIE__}  = sub { print STDERR $PROG, ': ', errorFormat(@_); exit 1 };
}

# options
use Getopt::Long;
Getopt::Long::Configure
qw(gnu_getopt no_gnu_compat no_auto_abbrev no_ignore_case);

sub Interpolate {
    my ($SPC, $PSPC) = (' ', ' ' x length($PROG));
    my $doc = join('', @_);
    $doc =~ s/\\\n//g;
    return eval 'qq('.$doc.')';
}
sub Man {
    open(STDIN, '-|', 'pod2man '.quotemeta($0).' | nroff -man') and
    open(STDOUT, '|-', $ENV{PERLDOC_PAGER} ||
                       $ENV{MANPAGER}      ||
                       $ENV{PAGER}         || 'less') or exit 127;
    print Interpolate(<STDIN>);
    close(STDOUT);
    exit $_[0];
}
sub Usage {
    my ($exitval, $verbose, @message) = @_;
    &Man if ($verbose == 2);
    my $OUT = ($exitval == 0 ? \*STDOUT : \*STDERR);
    if (@message or $exitval == 2) {
        local $, = "\n";
        print $OUT @message, "\n";
    }
    require Pod::Usage;
    Pod::Usage->import qw(pod2usage);
    open(USAGE, '+>', undef) or die $!;
    pod2usage(
        -exitval => "NOEXIT",
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
);
my %opts = (
    'grep' => [],
    'not' => \$not,
    'ignore-case' => \$ignore_case,
    'all' => \$all,
    'fixed' => [],
    'exclude' => [],
);
GetOptions(
    \%opts,
    'help|h',
    'man',
    'usage|?',
    'delimiter|d=s',
    'comment|c=s',
    'grep|g=s',
    'not|v',
    'ignore-case|i',
    'search-all|s',
    'all|a',
    'fixed|f=s',
    'exclude|e=s',
    'random|m',
    'first',
    'last',
    'first-line',
    'N:s',
    'n:s',
    'number:s',
    'canonical',
    'preserve|p',
    'raw|r',
    'tabs|t:8',
    'wrap|w:'.($ENV{COLUMNS} || 80),
    'list',
    'count',
) or Usage(2, 0);

# process options
Usage(0, 2) if $opts{man};
Usage(0, 1) if $opts{help};
Usage(0, 0) if $opts{usage};

sub argError {
    Usage(2, 0, "Invalid argument for --$_[0]: $_[1]");
}

my ($is_delimited, $re_delim);
if (exists $opts{delimiter}) {
    $is_delimited = 1;
    $re_delim = '[ \t]*\n?';
    eval { $re_delim = qr[^$opts{delimiter}$re_delim] };
    die errorFormat($@) if $@;
} else {
    $re_delim = qr[\S];
}

my $re_comment;
if (exists $opts{comment}) {
    eval { $re_comment = qr[(?:^|\s+)$opts{comment}.*] };
    die errorFormat($@) if $@;
} else {
    $re_comment = qr[];
}

my @grep;
$ignore_case = ($ignore_case ? 'i' : '');
foreach (@{$opts{grep}}) {
    push @grep, eval 'qr['.$_.']'.$ignore_case;
    die errorFormat($@) if $@;
}

my $ts = $opts{tabs} || 8;
argError('tabs', $ts) if $ts <= 0;

# main
if (not @ARGV) {
    Usage(1, 0, "No files given") if -t STDIN;
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
        open($file, '<', $_) or warn "$_: $!" and next;
    }
    while (<$file>) {
        if ($is_delimited) {
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
    $tmp =~ s/$re_comment//s if not $is_delimited;
    if ($tmp =~ /$re_delim/) {
        unshift @entries, '';
    }
}

# fixed and excluded entries
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
    my @range = grep {$_ ne ''}
                     split( /\s*,\s*/, join(',', @{$opts{$type}}) );
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
    $all = $random = 1;
}

sub skip {
    $_ = shift;
    if ($all or $fixed{$_} or $_ >= $threshold) {
        return 0 if exists $entries[$_];
    }
    return 1;
}

# strip delimiters and comments
# print first line only
# grep entries
# get selected indices
$opts{preserve} = 1 if $opts{raw};
my ($E_DELIM, $E_COMM, $E_FIRST,
    $S_DELIM, $S_COMM, $S_FIRST, $ops) = (
    1<<0,
    1<<1,
    1<<2,
    1<<3,
    1<<4,
    1<<5, 0);
{
    my $no_print = $opts{list} || $opts{count};
    $ops|= $E_DELIM if $is_delimited and not $no_print || $opts{raw};
    $ops|= $E_COMM  if not $no_print || $opts{preserve};
    $ops|= $E_FIRST if $opts{'first-line'} and not $no_print;
    $ops|= $S_DELIM if $is_delimited           and not $ops & $E_DELIM;
    $ops|= $S_COMM  if not $opts{'search-all'} and not $ops & $E_COMM;
    $ops|= $S_FIRST if not $opts{'search-all'} and not $ops & $E_FIRST;
}
my $re_first_line = qr[^\n*([^\n]*).*]s;
my $no_grep = not @grep;
my @indices;

LOOP: for (my $i = 1; $i <= $#entries; ++$i) {
    next if skip($i);
    push @indices, $i;
    $entries[$i] =~ s/$re_delim//        if $ops & $E_DELIM;
    $entries[$i] =~ s/$re_comment//gm    if $ops & $E_COMM;
    $entries[$i] =~ s/$re_first_line/$1/ if $ops & $E_FIRST;
    next if $no_grep;

    my $srch = $entries[$i];
    $srch        =~ s/$re_delim//        if $ops & $S_DELIM;
    $srch        =~ s/$re_comment//gm    if $ops & $S_COMM;
    $srch        =~ s/$re_first_line/$1/ if $ops & $S_FIRST;
    foreach (@grep) {
        if ($srch !~ /$_/) {
            unless ($not) {
                pop @indices;
                next LOOP;
            }
        }
    }
    pop @indices if $not;
}

# choose random, first, or last
if (@indices) {
    my $chosen;
    if ($opts{random} or $random and not ($opts{first} or $opts{last})) {
        $chosen = int(rand($#indices+1));
    } elsif ($opts{first}) {
        $chosen = 0;
    } elsif ($opts{last}) {
        $chosen = $#indices;
    }
    @indices = $indices[$chosen] if defined $chosen;
}

# print list, count
my $count = scalar(@indices);
unshift @indices, 0 if not skip(0);

if ($opts{count}) {
    print $count, "\n";
    exit;
}
exit if not @indices;

if ($opts{list}) {
    local ($,, $\) = ("\n", "\n");
    print @indices;
    exit;
}

# expand tabs
if (exists $opts{tabs} or exists $opts{wrap}) {
    my $re_tabs = qr[\G((?:[^\t\n]*\n)*)(.*?)(\t+)];
    $entries[$_] =~ s[$re_tabs]
                     [$1.$2.' 'x(length($3) * $ts - length($2) % $ts)]ge
    foreach @indices;
}

# Debug \@indices;

my $break = '\s';
my $separator = "\n";

# my $number = '*';
my $number = '[%d]';

my $limit = 230;

my $format;
my ($pre, $aft);

my $pad;
if ($number =~ /^(.*?)%d(.*)$/) {
    $pad = length($1) + length($2) + length($limit) + 1;
    $pre = $1;
    $aft = $2.' ';
    $format = "%".$pad."s";
}
else {
    $pad = length($number);
    $pre = $number;
    $aft = '';
}
my $line_limit = ($opts{wrap} || 80) - length($pad) - 1;
$line_limit = $pad+1 if $line_limit < $pad+1;

$pad = ' ' x $pad;
my $current = 0;

sub wrap {
    my $r = sprintf $format, $pre . $_[0] . $aft;
    my $lead;
    my $ret = '';
    foreach (map { $lead ? $pad.$_ : ($lead = $r.$_) } split(/\n/, $_)) {
        while ($_ =~ /\G(.{1,$line_limit})(\s|\z)/gc) {
            $ret .= $1;
            $ret .= "\n".$pad if pos != length;
        }
        $ret .= "\n";
    }
    return $ret;
}


#TODO check and not or
__END__

=head1 NAME

$PROG - extraction of lines or sections from text files

=head1 SYNOPSIS

   $PROG [-d DELIM]  [-c STR]  [-g PATTERN]... [-vis]
   $PSPC [-a] [-f LIST]...  [-e LIST]...  [ -m | --first | --last ]
   $PSPC [--first-line]  [-n[...]] [-N[...]] [--canonical]  [-pr]
   $PSPC [-t N] [-w]  [ --list | --count ]  [--help]  [--]  [FILE]...

=head1 DESCRIPTION

By default, prints a random line or section from files on the command line.
If the B<-d> option is given, a section delimited by its argument is printed;
otherwise a single non-empty line is printed. For example, if the file
contained the following, invoke with -d '>>':

>> foo\

>> bar\

...

Entries (sections or non-empty lines) can be non-randomly selected according
to the options.

=head1 OPTIONS

=over 8

=item B<-h, --help>

display this help message and exit

=item B<-?, --usage>

display the usage string and exit

=back

=cut

=for vim:set ts=4 sw=4 et:
