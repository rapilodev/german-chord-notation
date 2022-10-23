#!/usr/bin/perl
use warnings;
use strict;
use feature 'state';
use Data::Dumper;

my $pattern = $ARGV[0] // './';

sub process_chords {
    my ( $line, $fun, $lresult ) = @_;
    $lresult //= {};
    $lresult->{line}   = '';
    $lresult->{words}  = 0;
    $lresult->{chords} = 0;
    while ( $line =~ /([\S]+)/g ) {
        my $old   = $1;
        my $new   = $old;
        my $start = $-[0];

        if (
            $new =~ /^(
                (?<prefix>[\(\|])?
                (?<note>[A-Ha-h](?:b|\#|es|s|is)?)(?<moll>m)?
                (?<sh1num>\d+)?
                (?<sh2func>\#|b|M|maj|min|mi|hdim|minmaj|add|sus|\+|\-|dim|aug)?
                (?<sh2num>\d+)?
                (?<sh3func>\#|b|M|maj|min|mi|hdim|minmaj|add|sus|\+|\-|dim|aug)?
                (?<sh3num>\d+)?
                (?:\/(?<bass>[A-H](?:b|\#|es|s|is)?))?
                (?<postfix>[\)\|\*])?
                )$/x
          )
        {
            $lresult->{chords}++;
            my $chord = {
                note    => $+{note}    // '',
                moll    => $+{moll}    // '',
                int1    => $+{sh1num}  // '',
                fun2    => $+{sh2func} // '',
                int2    => $+{sh2num}  // '',
                fun3    => $+{sh3func} // '',
                int3    => $+{sh3num}  // '',
                bass    => $+{bass}    // '',
                prefix  => $+{prefix}  // '',
                postfix => $+{postfix} // '',
            };

            $chord = $fun->($chord) // $chord;
            $new   = join( '',
                $chord->{prefix}, $chord->{note},
                $chord->{int1},   $chord->{fun2},
                $chord->{int2},   $chord->{fun3},
                $chord->{int3},   $chord->{bass} ? "/$chord->{bass}" : '',
                $chord->{postfix} );
        } else {
            $lresult->{words}++ if $new =~ /[a-zA-Z]/;
        }

        $lresult->{line} .= ' ' x ( $start - length( $lresult->{line} ) )
          if $start > length( $lresult->{line} );
        $lresult->{line} .= $new;
        $lresult->{line} .= ' ' x ( length($new) - length($old) ) if length($new) > length($old);
    }
    return $lresult;
}

sub analyse_line {
    my ($line) = @_;
    my $lresult = process_chords(
        $line,
        sub {
            my ($chord) = @_;
            return ($chord);
        }
    );
    return $lresult;

}

sub classify {
    my ($note) = @_;
    state $classics;
    if ( !$classics ) {
        $classics = {
            'Ab' => 'As',
            'A'  => 'A',
            'A#' => 'B',
            'Bb' => 'B',
            'B'  => 'H',
            'B#' => 'C',
            'Cb' => 'H',
            'C'  => 'C',
            'C#' => 'Cis',
            'Db' => 'Des',
            'D'  => 'D',
            'D#' => 'Dis',
            'Eb' => 'Es',
            'E'  => 'E',
            'E#' => 'F',
            'Fb' => 'E',
            'F'  => 'F',
            'F#' => 'Fis',
            'Gb' => 'Ges',
            'G'  => 'G',
            'G#' => 'Gis',
            'H'  => 'H',
        };
        for my $key ( 'A', 'C', 'D', 'E', 'F', 'G', 'H' ) {
            $classics->{ $key . 'is' } = $key . 'is';
        }
        for my $key ( 'B', 'C', 'D', 'F', 'G', 'H' ) {
            $classics->{ $key . 'es' } = $key . 'es';
        }
        for my $key ( 'A', 'E' ) {
            $classics->{ $key . 's' } = $key . 's';
        }
        for my $key ( keys %$classics ) {
            $classics->{ lc $key } = lc $classics->{$key};
        }
    }
    return $classics->{$note} || die $note;
}

sub classify_line {
    my ($line)    = @_;
    my ($lresult) = process_chords(
        $line,
        sub {
            my ($chord) = @_;
            $chord->{note} = classify( $chord->{note} );
            if ( $chord->{fun2} =~ /M|ma|maj/ ) {
                $chord->{fun2} = '+';
            } elsif ( $chord->{fun2} eq 'dim' && $chord->{int2} eq '' ) {
                $chord->{fun2} = '-';
                $chord->{int2} = '5';
            } elsif ( $chord->{fun2} eq 'aug' && $chord->{int2} eq '' ) {
                $chord->{fun2} = '+';
                $chord->{int2} = '5';
            } elsif ( $chord->{fun2} =~ /min?/ ) {
                $chord->{fun2} = '';
                $chord->{moll} = 'm';
            }
            $chord->{bass} = classify( $chord->{bass} ) if $chord->{bass};
            $chord->{note} = lc $chord->{note}          if $chord->{moll} eq 'm';
            return $chord;
        }
    );
    return $lresult->{line};
}

sub transpose {
    my ( $content, $interval ) = @_;
    my $increase = {
        'Ces' => 'C',
        'C'   => 'Cis',
        'Cis' => 'D',
        'Des' => 'D',
        'D'   => 'Dis',
        'Dis' => 'E',
        'Es'  => 'E',
        'E'   => 'F',
        'Fes' => 'F',
        'F'   => 'Fis',
        'Fis' => 'G',
        'Ges' => 'G',
        'G'   => 'Gis',
        'Gis' => 'A',
        'As'  => 'A',
        'A'   => 'B',
        'Ais' => 'H',
        'B'   => 'H',
        'Hes' => 'H',
        'H'   => 'C',
        'His' => 'Cis',
    };
    for my $key ( keys %$increase ) {
        $increase->{ lc $key } = lc $increase->{$key};
    }
    my $result;
    for my $line ( split( /\n/, $content, -1 ) ) {
        my $ana = analyse_line($line);
        if ( $ana->{words} > $ana->{chords} ) {
            $result .= "$line\n";
            next;
        }
        my $lresult = process_chords(
            $line,
            sub {
                my ($chord) = @_;
                for ( 1 .. $interval ) {
                    $chord->{note} = $increase->{ $chord->{note} }
                      || die "cannot increase $chord->{note}";
                    $chord->{bass} = $increase->{ $chord->{bass} }
                      || die "cannot increase $chord->{bass}"
                      if $chord->{bass};
                }
                return $chord;
            }
        );
        $result .= $lresult->{line} . "\n";
    }
    return $result;
}

sub simplify {
    my ( $content, $interval ) = @_;
    my $simplify = {
        'Ces' => 'H',
        'C'   => 'C',
        'Cis' => 'Cis',
        'Des' => 'Des',
        'D'   => 'D',
        'Dis' => 'Dis',
        'Es'  => 'Es',
        'E'   => 'E',
        'Fes' => 'E',
        'F'   => 'F',
        'Fis' => 'Fis',
        'Ges' => 'Ges',
        'G'   => 'G',
        'Gis' => 'Gis',
        'As'  => 'As',
        'A'   => 'A',
        'Ais' => 'B',
        'B'   => 'B',
        'Hes' => 'B',
        'H'   => 'H',
        'His' => 'C',
    };
    for my $key ( keys %$simplify ) {
        $simplify->{ lc $key } = lc $simplify->{$key};
    }
    my $result;
    for my $line ( split( /\n/, $content, -1 ) ) {
        my $ana = analyse_line($line);
        if ( $ana->{words} > $ana->{chords} ) {
            $result .= "$line\n";
            next;
        }
        my $lresult = process_chords(
            $line,
            sub {
                my ($chord) = @_;
                $chord->{note} = $simplify->{ $chord->{note} }
                  || die "cannot simplify $chord->{note}";
                $chord->{bass} = $simplify->{ $chord->{bass} }
                  || die "cannot increase $chord->{bass}"
                  if $chord->{bass};
                return $chord;
            }
        );
        $result .= $lresult->{line} . "\n";
    }
    return $result;
}

sub get_complexity {
    my ($content) = @_;
    my $complexity = 0;
    for my $line ( split( /\n/, $content, -1 ) ) {
        my $ana = analyse_line($line);
        next if $ana->{words} > $ana->{chords};
        process_chords(
            $line,
            sub {
                my ($chord) = @_;
                $complexity += 3 if $chord->{note} =~ m/s$/;
                $complexity += 1 if $chord->{bass} =~ m/s$/;
                $complexity += 1 if $chord->{note} !~ m/[aBCDdEeFG]/;
                return $chord;
            }
        );
    }
    return $complexity;
}

sub auto_transpose {
    my ($content) = @_;
    my $result    = $content;
    my $min       = 1000;
    for my $interval ( 0 .. 12 ) {
        my ( $transposed, $args ) = transpose( $content, $interval );
        my $complexity = get_complexity($transposed);

        #print "$interval, $complexity\n";    #.substr($transposed,0,200);
        #$complexity-- if $interval==0;
        if ( $complexity < $min ) {
            $result = $transposed;
            $min    = $complexity;
        }
    }
    return $result;
}

my $lines_per_page = 84;

sub format_pages {
    my ($content) = @_;
    $content =~ s/ +\n/\n/g;
    $content =~ s/\n\n+/\n\n/g;
    my $lnr    = 1;
    my $result = '';
    for my $p ( split( /\n\n+/, $content, -1 ) ) {
        chomp $p;
        my $lines = scalar( split /\n/, $p, -1 ) + 1;
        if ( $lnr + $lines > $lines_per_page ) {
            $result .= "\n" x ( $lines_per_page - $lnr  );
            $lnr = 1;
        } else {
            $lnr += $lines;
        }
        $result .= "$p\n\n";
    }
    $result=~s/\n+$/\n/;
    return $result;
}

sub save {
    my ( $file, $content ) = @_;

    open my $wh, '>', $file or die $!;
    print $wh $content;
    close $wh or die $!;

}

for my $file ( glob( quotemeta($pattern) . "*.txt" ) ) {
    print "process file $file\n";

    my $content = '';
    open my $rh, "<", $file or die $!;
    for my $line (<$rh>) {
        $content .= $line;
    }
    close $rh;

    $content = format_pages($content);

    my $result = '';
    for my $line ( split /\n/, $content, -1 ) {
        my $ana = analyse_line($line);
        if ( $ana->{words} > $ana->{chords} ) {
            $result .= "$line\n";
        } else {
            $result .= classify_line($line) . "\n";
        }
    }
    $content = $result;
    $content = simplify $content;
    $content = format_pages($content);

    $content = auto_transpose $content;
    $content = simplify $content;

    save $file . ".done", $content;

    my @stats = stat($file);
    my $atime = $stats[8];
    my $mtime = $stats[9];
    utime $atime, $mtime, $file . '.done';
}

