#!/usr/bin/perl
#####################################################################{{{1
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
#   2011-02-15  Added documentation
#
#########################################################################
#{{{1 initialization
use strict;
use warnings;
use File::Basename qw(basename);
use Getopt::Long;

my $PROG = basename($0);
my $VERSION = '1.0';
my $SEP = ':';

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

#{{{1 options
Getopt::Long::Configure
    qw(gnu_getopt no_gnu_compat no_auto_abbrev no_ignore_case);

#{{{2 help functions
sub Interpolate {
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
        print $OUT @message, "\n" x 2;
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
    print $OUT Interpolate(@message);
    exit $exitval;
}

#{{{2 variables
my (
    $ignore_case,
    $sort,
    $extract,
    $canonical,
    $separator,
    $tabs,
    $wrap,
);
my %opts = (
    'fixed' => [],
    'except' => [],
    'grep' => [],
    'grep-not' => [],
    'ignore-case' => \$ignore_case,
    'sort' => \$sort,
    'extract' => \$extract,
    'canonical' => \$canonical,
    'separate-entries' => \$separator,
    'tabs' => \$tabs,
    'wrap' => \$wrap,
);
#}}}
GetOptions(
    \%opts,
    'man',
    'help|h',
    'usage|?',
    'delimiter|d=s',
    'comment|c=s',
    'encoding=s',

    'all|a',
    'fixed|f=s',
    'except|e=s',
    'grep|g=s',
    'grep-not|G=s',
    'ignore-case|i',
    'only-first|o',
    'random|m',
    'sort|s:s',
    'extract=s',
    'first',
    'last',

    'N:s',
    'n:s',
    'number:s',
    'canonical|C',
    'separate-entries:s',
    'preserve|p',
    'raw|r',
    'first-line|F',
    'tabs|t:8',
    'wrap|w:'.($ENV{COLUMNS} || 80),
    'list',
    'count',
) or Usage(2, 0);
Usage(0, 2)                        if $opts{man};
Usage(0, 1, $PROG, '  ', $VERSION) if $opts{help};
Usage(0, 0)                        if $opts{usage};

#{{{1 process options
sub argError {
    Usage(2, 0, 'Invalid argument for option ', shift, ': ', shift);
}

#{{{2 delimiter
my ($delimited, $re_delim);
if (defined $opts{delimiter}) {
    $delimited = 1;
    $re_delim = '[ \t]*\n?';
    eval { $re_delim = qr[^$opts{delimiter}$re_delim] };
    die $@ if $@;
} else {
    $re_delim = qr[\S];
}

#{{{2 comment
my ($re_comment,
    $re_comment_s,
    $re_comment_line,
    $re_comment_trailing_part,
);
if (defined $opts{comment}) {
    eval {
      $re_comment   = qr[(^|\s)$opts{comment}.*];
      $re_comment_s = qr[(^|\s)$opts{comment}.*]s;
      $re_comment_line = qr[(?:^|\n|\G)\K[ \t]*$opts{comment}.*(?:\n|$)];
      $re_comment_trailing_part = qr[\S\K[ \t]+$opts{comment}.*];
    };
    die $@ if $@;
}

#{{{2 search
$ignore_case = ($ignore_case ? 'i' : '');

my @grep;
foreach (@{$opts{grep}}) {
    push @grep, eval 'qr['.$_.']'.$ignore_case;
    die $@ if $@;
}
my $vgrep;
if (@{$opts{'grep-not'}}) {
    $vgrep = eval 'qr['.join('|', @{$opts{'grep-not'}}).']'.$ignore_case;
    die $@ if $@;
}

#{{{2 sort
if (defined $sort) {
    if ($opts{random} or $opts{count}) {
        undef $sort;
    } else {
        if (defined $extract) {
            $extract = eval 'sub ($) { local $_ = shift; '.$extract.' }';
            die $@ if $@;
        } else {
            $extract = sub { shift };
        }
        $sort = '$a cmp $b' if $sort eq '';
        $sort =~ s/(?<!{)(\$[ab])\b(?!}|->)/$1\->[1]/g;
        $sort = eval 'sub () { no warnings; '.$sort.' }';
        die $@ if $@;
    }
}

#{{{2 other
if ($opts{all}) {
    unshift @{$opts{fixed}}, '0:';
} elsif (not @{$opts{fixed}}) {
    unshift @{$opts{fixed}}, '1:';
}

if (defined $separator) {
    $separator .= "\n";
}

$opts{preserve} = 1 if $opts{raw};

argError('tabs', $tabs) if defined $tabs and $tabs <= 0;
argError('wrap', $wrap) if defined $wrap and $wrap <= 0;
#}}}

#{{{1 slurp entries
if (not @ARGV) {
    Usage(1, 0, 'No files given') if -t STDIN;
    @ARGV = '-';
}

my (@entries, $entry);
my $tmp;

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
        if ($delimited or not defined $re_comment) {
            if (/$re_delim/) {
                push @entries, $entry;
                $entry = '';
            }
        } else {
            $tmp = $_;
            $tmp =~ s/$re_comment//;
            if ($tmp =~ /$re_delim/) {
                push @entries, $entry;
                $entry = '';
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
    $tmp =~ s/$re_comment_s// if not $delimited and defined $re_comment;
    unshift @entries, undef if $tmp =~ /$re_delim/;
}

#{{{1 determine included and excluded entries
sub convertIndex { #{{{2
    $_ = shift;
    if (/^-/) {
        return  0 if $_ == 0;
        $_ = $#entries + int($_) + 1;
        return -1 if $_ == 0;
        return $_;
    } else {
        return int($_);
    }
} #}}}
sub min { return $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { return $_[0] > $_[1] ? $_[0] : $_[1] }

my $re_range = qr[^(-?\d+)?($SEP)?(-?\d+)?$];

sub parseList { #{{{2
    my ($type, $href) = @_;
    my ($l_thresh, $u_thresh);
    foreach ( grep { $_ ne '' }
              split( /\s*,\s*/, join(',', @{$opts{$type}}) ) )
    {
        argError($type, $_) if not /$re_range/;
        my ($l, $u);
        if ($2) {
            argError($type, $_) if not (defined $1 or defined $3);
            if (not defined $1) {
                $u = convertIndex($3);
                $href->{0} = 1 if $u == 0;
                if (not defined $u_thresh) {
                    $u_thresh = $u if $u >= 1;
                } else {
                    $u_thresh = max($u_thresh, $u);
                }
                next;
            } elsif (not defined $3) {
                $l = convertIndex($1);
                $href->{0} = 1 if $l == 0;
                if (not defined $l_thresh) {
                    $l_thresh = $l if $l <= $#entries;
                } else {
                    $l_thresh = min($l_thresh, $l);
                }
                next;
            } else {
                $l = convertIndex($1);
                $u = convertIndex($3);
                next if $l > $u;
            }
        } else {
            argError($type, $_) if defined $3;
            $l = $u = convertIndex($1);
        }
        $href->{0} = 1 if $l == 0 or $u == 0;
        $l = max($l, (defined $u_thresh ? $u_thresh+1 : 1));
        $u = min($u, (defined $l_thresh ? $l_thresh-1 : $#entries));
        for (my $i = $l; $i <= $u; ++$i) {
            $href->{$i} = 1;
        }
    }
    return (defined $l_thresh ? max($l_thresh, 1)         : undef),
           (defined $u_thresh ? min($u_thresh, $#entries) : undef);
} #}}}
my (%fixed, %except);

my ($excpt_l_thresh, $excpt_u_thresh) = parseList 'except', \%except;

$#entries = $excpt_l_thresh - 1 if defined $excpt_l_thresh;
$excpt_u_thresh = 0 if not defined $excpt_u_thresh;

if ($except{0}) {
    delete $entries[0];
    delete $except{0};
}

my ($fixed_l_thresh, $fixed_u_thresh) = parseList 'fixed',  \%fixed;

my $fixed = 0;
my $UNDEF_L_THRESH = 1<<0;
my $UNDEF_U_THRESH = 1<<1;

if (not defined $fixed_l_thresh) {
    $fixed |= $UNDEF_L_THRESH;
    $fixed_l_thresh = $#entries + 1;
}
if (not defined $fixed_u_thresh) {
    $fixed |= $UNDEF_U_THRESH;
    $fixed_u_thresh = 0;
}

sub skip { #{{{2
    $_ = shift;
    if ($_ == 0) {
        return 0 if $fixed{0} and defined $entries[0];
        return 1;
    }
    return 0 if ($_ >= $fixed_l_thresh or
                 $_ <= $fixed_u_thresh or $fixed{$_})
                and not $except{$_};
    return 1;
} #}}}

#{{{1 get/sort selected indices
# search entries
my $ops = 0;

my $re_first_line = qr[(?:\s*\n|^)([^\n]*).*]s;
my $re_blank_line = qr[(?:\n|^)\K\s*\n];

my @indices;
my %entries;
#{{{2 fill cache
if (@grep or defined $vgrep or defined $sort) {
    my $S_DELIM = 1<<0;
    my $S_COMMT = 1<<1;
    my $S_FIRST = 1<<2;

    $ops|= $S_DELIM if $delimited;
    $ops|= $S_COMMT if $opts{'only-first'} and defined $opts{comment};
    $ops|= $S_FIRST if $opts{'only-first'};

    push @indices, 0 if not skip(0);
    LOOP: for my $i ($excpt_u_thresh+1..$#entries) {
        next if skip($i);

        my $srch = $entries[$i];
        $srch =~ s/$re_delim//        if $ops & $S_DELIM;
        $srch =~ s/$re_comment//g     if $ops & $S_COMMT;
        $srch =~ s/$re_first_line/$1/ if $ops & $S_FIRST;

        foreach (@grep) {
            next LOOP if ($srch !~ /$_/);
        }
        next if defined $vgrep and $srch =~ /$vgrep/;
        push @indices, $i;
        $entries{$i} = \$srch if defined $sort;
    }

} else {
    # no grep or sort
    if ( (keys %except == 0 or keys %except == 1 and $except{0}) and
         (keys %fixed  == 0 or keys %fixed  == 1 and $fixed{0} or
          $fixed_l_thresh == 1 or $fixed_u_thresh == $#entries) ) {
        if ($fixed != ($UNDEF_L_THRESH | $UNDEF_U_THRESH)) {
            @indices = (
                max( $fixed & $UNDEF_L_THRESH ? 1
                                              : $fixed_l_thresh,
                     $excpt_u_thresh+1 )
                .. ( $fixed & $UNDEF_U_THRESH ? $#entries
                                              : $fixed_u_thresh )
            );
        }
        unshift @indices, 0 if not skip(0);
    } else {
        for my $i (0, $excpt_u_thresh+1..$#entries) {
            push @indices, $i if not skip($i);
        }
    }
}
#}}}
my $max_index = $indices[$#indices];

# temporarily ignore entry zero
shift @indices if not skip(0);

#{{{2 choose random, first, or last; sort
if (@indices) {
    my @chosen;
    if ($opts{random}) {
        push @chosen, int(rand($#indices+1));
    } else {
        if (defined $sort) {
            @indices = map { $_->[0] }  sort $sort
                       map { [ $_, $extract->(${$entries{$_}}) ] }
                       sort keys %entries;
        }
        if ($opts{first}) {
            push @chosen, 0;
        }
        if ($opts{last}) {
            push @chosen, $#indices if not @chosen or $#indices != 0;
        }
    }
    if (@chosen) {
        @indices = @indices[@chosen];
        $max_index = (@indices == 2 ? max(@indices) : $indices[0]);
    }
}

#{{{1 print count/list
if ($opts{count}) {
    print scalar(@indices), "\n";
    exit;
}

unshift @indices, 0 if not skip(0);
exit if not @indices;

if ($opts{list}) {
    local ($,, $\) = ("\n", "\n");
    print @indices;
    exit;
}

#{{{1 print formatting
#{{{2 strip delimiters, comments, lines after the first, and blank lines
$ops = 0;

my $E_DELIM = 1<<0;
my $E_COMMT = 1<<1;
my $E_FIRST = 1<<2;
my $E_BLANK = 1<<3;

    $ops|= $E_DELIM if not $opts{raw} and $delimited;
    $ops|= $E_FIRST if $opts{'first-line'};
if (not $opts{preserve}) {
    $ops|= $E_COMMT if defined $opts{comment};
    $ops|= $E_BLANK if not $ops & $E_FIRST and not $delimited;
}
if ($ops) {
  for my $i (@indices) {
    $entries[$i] =~ s/$re_delim//                    if $ops & $E_DELIM;
    do {
    $entries[$i] =~ s/$re_comment_line//g;
    $entries[$i] =~ s/$re_comment_trailing_part//g;
    }                                                if $ops & $E_COMMT;
    $entries[$i] =~ s/$re_first_line/$1\n/           if $ops & $E_FIRST;
    $entries[$i] =~ s/$re_blank_line//g              if $ops & $E_BLANK;
    $entries[$i] = "\n" if $entries[$i] eq '';
  }
}

#{{{2 expand tabs
if ($tabs or $wrap) {
    $tabs = 8 if not defined $tabs;
    my $re_tabs = qr[\G((?:[^\t\n]*\n)*)([^\t]*)(\t+)];
    $entries[$_] =~ s[$re_tabs]
                     [$1.$2.' 'x(length($3) * $tabs - length($2) % $tabs)]ge
    foreach @indices;
}

#{{{2 format number or bullet
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
        $pad = length $pre.( $canonical ? $#indices + skip(0)
                                        : $max_index ).$suf;
    } else {
        $pad = length $suf;
    }
    $format = '%'.( $pre ne '' ? '-' : '' ).$pad.'s';
    $count = skip(0) ? 0 : -1;
} else {
    $pad = 0;
}

#{{{2 parameters for wrap
my ($lim, $lim_1, $lim_2, $wrapped);

if ($wrap) {
    $lim_1 = max($wrap - 1, $pad + 1);
    $lim_2 = $lim_1 - $pad;
}

$pad = ' ' x $pad;

#{{{1 print entries
binmode STDOUT, ':encoding('.$opts{encoding}.')' if defined $opts{encoding};

foreach (@indices) {
    if ($format) {
        $entry = sprintf $format, $pre.( $number ? $canonical ? ++$count
                                                              : $_
                                                 : '' ).$suf;
        $entry .= $entries[$_];
        $entry =~ s/\n\K/$pad/g;
        $entry =~ s/$pad$//;
        $entry .= $separator if $separator and $entry !~ /\n\n$/;
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

#{{{1 documentation
__END__

=head1 NAME

$PROG - extraction of lines or sections from text files

=head1 SYNOPSIS

$PROG  I<FILE>...

=head1 DESCRIPTION

This script reads text from files on the command line or from I<stdin>,
parsing the text into entries. Each entry begins with either a single
non-blank line that is not a comment, or, if the B<-d> option is specified,
with a delimiter located at the start of a line. An entry spans the stretch
of text up to the start of the next entry. The entries can be selected,
searched, sorted, and formatted for output to I<stdout> according to the
following options.

=head1 OPTIONS

=over 8

=item B<--man>

display the man page

=item B<-h>, B<--help>

print help message

=item B<-?>, B<--usage>

print usage string

=item

=item B<Input>

=item B< >B< >B<-d> I<DELIM>, B<--delimiter> I<DELIM>

use regex I<DELIM> to mark sections as entries (otherwise, each non-blank
line is treated as an entry)

=item B< >B< >B<-c> I<STR>, B<--comment> I<STR>

parse comments, which start with regex I<STR> and go to the end of the line

=item B< >B< >B<--encoding> I<NAME>

specify the file encoding

=item

=item B<Entry selection>

=item B< >B< >B<-a>, B<--all>

select all entries (including entry 0, before the first I<DELIM>); by
default, only entries starting from 1 are selected

=item B< >B< >B<-f> I<LIST>, B<--fixed> I<LIST>

select a subset of entries numerically

I<LIST> is a comma-separated list of I<RANGE>s, where each I<RANGE> may be
one of:

  N${SEP}M  entries N to M
  ${SEP}M   entries 1 to M
  N${SEP}   entry N to the last entry

I<RANGE>s are inclusive; numbers I<N> and I<M> may be negative for indexing
from the end

=item B< >B< >B<-e> I<LIST>, B<--except> I<LIST>

exclude entries numerically

=item B< >B< >B<-g> I<PATTERN>, B<--grep> I<PATTERN>

=item B< >B< >B<-G> I<PATTERN>, B<--grep-not> I<PATTERN>

grep for entries containing (or not containing) I<PATTERN>, from among the
selected entries

=item B< >B< >B<-i>, B<--ignore-case>

ignore case for searches

=item B< >B< >B<-o>, B<--only-first>

use only the first non-blank line in an entry (ignoring comments) for
searching and sorting

=item B< >B< >B<-m>, B<--random>

choose a random entry from among the matching entries

=item B< >B< >B<-s> [I<EXPR>], B<--sort> [I<EXPR>]

sort entries using a Perl expression I<EXPR> ('\$a cmp \$b' by default),
which compares two representative keys, denoted by '\$a' and '\$b', and
return a numeric result

=item B< >B< >B<--extract> I<EXPR>

specify an I<EXPR> to extract a key from each entry (stored in '\$_') for
use by the sort function; e.g. --sort '\$a <=> \$b' --extract '\$_ =~
/(\\d+)/' will sort entries numerically by the first number found in each

=item B< >B< >B<--first>

=item B< >B< >B<--last>

select only the first or last result

=item

=item B<Output>

=item B< >B< >B<-N> [I<PREFIX>]

=item B< >B< >B<-n> [I<SUFFIX>]

=item B< >B< >B<--number> [I<FORMAT>]

number entries, optionally with a I<PREFIX> or I<SUFFIX> attached, or using
a I<FORMAT> string, in which '%d', if present, represents the entry number

=item B< >B< >B<-C>, B<--canonical>

number resultant entries sequentially, starting from 1, and not by entry
index

=item B< >B< >B<--separate-entries> [I<STR>]

separate entries with I<STR> followed by a newline

=item B< >B< >B<-p>, B<--preserve>

do not strip comments and blank lines from the output

=item B< >B< >B<-r>, B<--raw>

like B<--preserve>, but also leaves delimiters in place

=item B< >B< >B<-F>, B<--first-line>

only print the first line of each entry

=item B< >B< >B<-t> [I<NUM>], B<--tabs> [I<NUM>]

expand tabs to I<NUM> spaces (8 by default)

=item B< >B< >B<-w> [I<NUM>], B<--wrap> [I<NUM>]

wrap text at I<NUM> columns (by default, \$COLUMNS or 80)

=item B< >B< >B<--list>

only print a list of indices for matching entries, one per line

=item B< >B< >B<--count>

only count and print the number of matching entries

=back

=cut

=for vim:set ts=4 sw=4 et fdm=marker:
