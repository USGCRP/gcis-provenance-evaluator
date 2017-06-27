#!/usr/bin/env perl


=head1 NAME

generate_resource_scores.pl -- generate the score tree for a resource

=head1 DESCRIPTION

generate_resource_scores -- Generate a score tree for a resource such as
a report, or chapters in a report.

This can be a long running script!

=head1 SYNOPSIS

./generate_resource_scores.pl [OPTIONS]

=head1 OPTIONS

=over

=item B<--url>

GCIS url, defaults to http://data.globalchange.gov

=item B<--resource>

GCIS resource, e.g. /report/nca3

=item B<--tree_file>

The file to save the output yaml

=item B<--connection_score>

File containing the Connection item scores. Default scores/connection_score.yaml

=item B<--internal_score>

File containing the Internal item scores. Default scores/internal_score.yaml

=item B<--components>

File containing the component relationships. Default config/components.yaml

=item B<--verbose>

Process & score tree is output to STDOUT


=item B<--progress>

Progress monitor printed to screen, to show the script is making progress.


=back

=head1 EXAMPLES

Score the nca3 report

./generate_resource_scores.pl --resouce /report/nca3  --tree_file ./nca3_tree.yaml

=cut


use Getopt::Long qw/GetOptions/;
use Pod::Usage qw/pod2usage/;

use Gcis::Exim qw();
use Gcis::Client;
use YAML::XS;
use Data::Dumper;
use FindBin qw( $RealBin );


use strict;
use v5.14;

# local $YAML::Indent = 2;

my $DEBUG = 1;
my $RUBRIC;
my $COMPONENTS;
my $url = "https://data.globalchange.gov";
my $connection_score = "scores/connection_score.yaml";
my $internal_score = "scores/internal_score.yaml";
my $components_map = "config/components.yaml";
GetOptions(
  'url=s'               => \$url,
  'resource=s'          => \(my $resource_uri),
  'tree_file=s'         => \(my $tree_file),
  'connection_score=s'  => \$connection_score,
  'internal_score=s'    => \$internal_score,
  'components=s'        => \$components_map,
  'verbose!'            => \(my $verbose),
  'progress!'           => \(my $progress),
  'help|?'              => sub { pod2usage(verbose => 2) },
) or die pod2usage(verbose => 1);

# test mode - always verbose;
$verbose = 1 if $DEBUG;
# nice minimal output for long running progress, but only in non-verbose.
$progress = 0 if $verbose;

pod2usage(verbose => 1, message => "$0: Resource option must be specified") unless $resource_uri;
pod2usage(verbose => 1, message => "$0: Tree_file option must be specified") unless $tree_file;

# Long running script - confirm our output file will work up front.
{
    if ( open(TEST, ">", $tree_file) ) {
        close TEST;
    } else {
        close Test;
        pod2usage(verbose => 1, message => "$0: Tree_file $tree_file can't be opened for writing");
    }
}

&main;

sub main {

    my $greeting = <<END;
Evaluating Provenance";
    url                    : $url";
    resource               : $resource_uri";
    output file            : $tree_file";
    internal scores file   : $internal_score";
    connection scores file : $connection_score";
    components file        : $components_map";

END
    say $greeting if $verbose;

    my $type = confirm_good_resource($url, $resource_uri);
    load_rubric_and_components();
    my $g = Gcis::Client->new(url => $url);

    my $score_tree = {
        $resource_uri => score_publication(
                            gcis           => $g,
                            resource       => $resource_uri,
                            type           => $type,
                            depth          => 0,
                         )
    };

    if ( $verbose ) {
        open( DEBUG_FILE, ">", "./debug_score_tree.dump" ) or die $!;
        print DEBUG_FILE "Score Tree: " . Dumper $score_tree;
        close DEBUG_FILE;
        say "Printed score tree hash dump to ./debug_score_tree.dump";
    };


    output_to_file( $score_tree );
    say "" if $progress;
    return;
}

sub score_publication {
    my %args = (@_);
    my $g               = $args{gcis};
    my $resource_uri    = $args{resource};
    my $type            = $args{type};
    my $depth           = $args{depth};

    my $resource = $g->get("$resource_uri") or die " Failed to retrieve resource: $resource_uri";
    my $score = calculate_internal_score( $type, $resource);

    my $contributors = score_contributors(
                            gcis           => $g,
                            contributors   => $resource->{contributors},
                            resource       => $resource_uri,
                            depth          => 0,
                         );

    return {
        score       => $score,
        connections => {
            contributors => $contributors,
            references   => "TODO references",
        },
        components => "TODO components",
    };
}

sub score_entity {
    my %args = (@_);
    my $g               = $args{gcis};
    my $resource_uri    = $args{resource};
    my $type            = $args{type};
    my $depth           = $args{depth};

    my $resource = $g->get("$resource_uri") or die " Failed to retrieve resource: $resource_uri";
    my $score = calculate_internal_score( $type, $resource);

    return { $resource_uri => {
        score       => $score,
        components => "TODO components",
    }};
}

sub score_contributors {
    my %args = (@_);
    my $g               = $args{gcis};
    my $resource_uri    = $args{resource};
    my $contributors    = $args{contributors};
    my $depth           = $args{depth};

    return {} unless $contributors; # Empty contributor is fine.

    my $contributors_scored = {};
    for my $contrib ( @$contributors ) {
        my $contrib_score = score_contributor(
            gcis           => $g,
            contributor    => $contrib,
            depth          => 0,

        );
        $contributors_scored->{$contrib->{uri}} = $contrib_score;
    }
    return $contributors_scored;
}

sub score_contributor {
    my %args = (@_);
    my $g               = $args{gcis};
    my $depth           = $args{depth};
    my $contributor     = $args{contributor};

    my $score = calculate_internal_score( 'contributor', $contributor);

    my $person = $contributor->{person_uri}
        ? score_entity (
            gcis           => $g,
            resource       => $contributor->{person_uri},
            type           => 'person',
            depth          => $depth,
        )
        : {};
    my $organization = $contributor->{organization_uri}
        ? score_entity (
            gcis           => $g,
            resource       => $contributor->{organization_uri},
            type           => 'organization',
            depth          => $depth,
        )
        : {};
    # Unsure if we can pull this reference out of GCIS via API. :(
    my $reference = $contributor->{reference}
        ? score_reference (
            gcis           => $g,
            resource       => $contributor->{reference},
            type           => 'reference',
            depth          => $depth,
        )
        : {};

    my $reference = {};

    return {
        score        => $score,
        person       => $person,
        organization => $organization,
        reference    => $reference,
    };

}

sub score_reference {
    my %args = (@_);
    my $g               = $args{gcis};
    my $resource_uri    = $args{resource};
    my $type            = $args{type};
    my $depth           = $args{depth};


}

sub calculate_internal_score {
    my $type = shift;
    my $resource = shift;

    print "" if $progress;
    say "Testing $resource->{uri}" if $DEBUG;
    if ( score_is('acceptable', $type, $resource) ) {
        if ( score_is('good', $type, $resource) ) {
            return 5 if score_is('very_good', $type, $resource);
                                               # Very Good
            return 4;                          # Good
        }                                      #   are only checked after a determination of
        return 3;                              # Acceptable
    }
    elsif ( score_is('poor', $type, $resource) ) {
        return 2;                              # Poor
    }
    return 1;                                  # Very Poor
}

sub score_is {
    my $quality = shift;
    my $type = shift;
    my $resource = shift;

say "\tTesting for $quality" if $DEBUG;
    # there can be multiple ways to get to the score
    for my $qualifying_grades ( @{ $RUBRIC->{$type}->{$quality} } ) {
        my @keys_to_look_for = @{ $qualifying_grades->{fields} };
        my $required_num_keys = $qualifying_grades->{required};
        my $count = 0;
        for my $key ( @keys_to_look_for ) {
            say "\t\t Checking Key $key, need $required_num_keys, have $count";
            if ( exists $resource->{$key} && $resource->{$key} &&  $resource->{$key} ne '') {
say "\t\t\tKey $key - Exists" if $DEBUG;
                $count++;
            }
            else {
say "\t\t\tKey $key - NO Exists" if $DEBUG;
            }
            return 1 if $count == $required_num_keys;
        }
    }

    return 0;
}

sub output_to_file {
    my $score_tree = shift;
    # given a perl hash of a tree, output some yaml file!
    my $eval_yaml = YAML::XS::Dump($score_tree);

    open( OUTPUT, ">", $tree_file ) or die $!;
    print OUTPUT $eval_yaml;
    close OUTPUT;
    say "Score tree written to $tree_file." if $verbose;
    print "." if $progress;
    return;
}

sub load_rubric_and_components {
    my $internal_rubric = YAML::XS::LoadFile("$RealBin/$internal_score") or die "Could not load Internal Score file: $RealBin/$internal_score";
    my $connection_rubric = YAML::XS::LoadFile("$RealBin/$connection_score") or die "Could not load Connection Score file: $RealBin/$connection_score";

    say "Loading $RealBin/$internal_score and $RealBin/$connection_score";
    my $COMPONENTS = YAML::XS::LoadFile("$RealBin/$components_map") or die "Could not load Components file $RealBin/$components_map";
    my %rubric = ( %$internal_rubric, %$connection_rubric );
    $RUBRIC = \%rubric;

    say "Loaded rubric and component files successfully" if $verbose;
    print "." if $progress;

    return;
}

sub confirm_good_resource {
    my $url = shift;
    my $resource_uri = shift;
    my $g = Exim->new($url, 'read');

    my $resource = $g->get("$resource_uri") or die " no resource";
    if (ref $resource eq 'ARRAY') {
        pod2usage(
            verbose => 1,
            message =>
                "$0: need a root resource (/report/nca3, "
                . " /report/nca3/chapter/water-resources) not a "
                . "list of resources (/report, /report/nca3/chapter)."
        );
    }
    print "." if $progress;

    return $g->extract_type_from_uri($resource_uri);
}

1;

