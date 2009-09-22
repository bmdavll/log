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
    open(STDIN, '-|', 'pod2man '.quotemeta($0).' | nroff -man')
                                                      or die "$PROG: $!\n";
    open(STDOUT, '|-', $ENV{PERLDOC_PAGER} ||
                       $ENV{MANPAGER}      ||
                       $ENV{PAGER}         || 'less') or exit 127;
    my @man = <STDIN>;
    print @man[0..2], Interpolate(@man[3..$#man-1]), $man[$#man];
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
    open(USAGE, '+>', undef) or die "$PROG: $!\n";
    pod2usage(
        -exitval => "NOEXIT",
        -verbose => $verbose,
        -output  => \*USAGE,
    );
    seek USAGE, 0, 0;
    @message = <USAGE>;
    if ($message[0] =~ /^Usage:$/) {
        shift @message;
        $message[0] =~ s/^\s{6}/Usage:/;
    }
    print $OUT Interpolate(@message);
    exit $exitval;
}

my (
    $not,
    $ignore_case,
    $search_all,
    $all,
    $first_line
);
my %opts = (
    'grep' => [],
    'not' => \$not,
    'ignore-case' => \$ignore_case,
    'search-all' => \$search_all,
    'all' => \$all,
    'fixed' => [],
    'exclude' => [],
    'first-line' => \$first_line,
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
    'n:s',
    'N:s',
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

if (not @ARGV) {
    Usage(1, 0, "No files given") if -t STDIN;
    @ARGV = '-';
}

sub evalError {
    if ($@) {
        $@ =~ s/\sat\s(?:$0|\(eval\s\d+\))\sline\s\d+\.?$//;
        die "$PROG: $@";
    }
}

my ($is_delimited, $re_delim);
if (exists $opts{delimiter}) {
    $is_delimited = 1;
    $re_delim = '[ \t]*\n?';
    eval { $re_delim = qr[^$opts{delimiter}$re_delim] };
    evalError;
} else {
    $re_delim = qr[\S];
}

my $re_comment;
if (exists $opts{comment}) {
    eval { $re_comment = qr[(?:^|\s+)$opts{comment}.*] };
    evalError;
} else {
    $re_comment = qr[];
}

my @grep;
$ignore_case = ($ignore_case ? 'i' : '');
foreach (@{$opts{grep}}) {
    push @grep, eval 'qr['.$_.']'.$ignore_case;
    evalError;
}

# main
my $tmp;

# slurp entries
my (@entries, $entry);

foreach (@ARGV) {
    my $file;
    if ($_ eq '-') {
        $file = \*STDIN;
    } else {
        open($file, '<', $_) or warn "$_: $!\n" and next;
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
sub argError {
    Usage(2, 0, "Invalid argument for --$_[0]: $_[1]");
}
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

if (not @{$opts{fixed}} and not $all) {
    $all = $opts{random} = 1;
}

sub test {
    $_ = shift;
    if ($all or $fixed{$_} or $_ >= $threshold) {
        return 1 if exists $entries[$_];
    }
    return 0;
}

# remove (non-)matching entries
# strip delimiters
my $do_grep = scalar @grep;
my $do_strip = ($is_delimited and not $opts{raw});
if ($do_grep or $do_strip) {
    my $text;
    GREP: for (my $i = 1; $i <= $#entries; ++$i) {
        next if not test($i);
        if ($do_strip) {
            $entries[$i] =~ s/$re_delim//;
            next if not $do_grep;
            $text = $entries[$i];
        } else {
            $text = $entries[$i];
            $text =~ s/$re_delim// if $is_delimited;
        }
        if (not $search_all) {
            $text =~ s/$re_comment//gm;
            $text =~ s/^\n*([^\n]*).*/$1/s;
        }
        foreach (@grep) {
            if ($text !~ /$_/) {
                unless ($not) {
                    delete $entries[$i];
                    next GREP;
                }
            }
        }
        delete $entries[$i] if $not;
    }
}

# Debug $_ foreach (@entries);
# Debug \@entries;


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
