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

=item B<--depth>

How many references deep to process. Default 1.

=item B<--verbose>

Process & score tree is output to STDOUT

=item B<--progress>

Progress monitor printed to screen, to show the script is making progress.


=back

=head1 EXAMPLES

Score the nca3 report

./generate_resource_scores.pl \
  --resouce /report/nca3 \
  --tree_file ./nca3_tree.yaml

Score the chapter extreme-events from the Report Climate Human Health Assessment 2016,
looking at dev, go deeper and normal and use custom scores.

./generate_resource_scores.pl \
  --resouce report/usgcrp-climate-human-health-assessment-2016/chapter/extreme-events \
  --tree_file ./hhs2016_ch_extreme_tree.yaml \
  --url https://data-dev.globalchange.gov \
  --depth 3 \
  --connection_score /tmp/new_scores.yml \
  --internal_score /tmp/new_inner_scores.yml \
  --components /tmp/comps.yml

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

my $MAX_DEPTH = 1;
my $RUBRIC;
my $COMPONENTS;
my $URL = "https://data.globalchange.gov";
my $connection_score = "scores/connection_score.yaml";
my $internal_score = "scores/internal_score.yaml";
my $components_map = "config/components.yaml";
GetOptions(
  'url=s'               => \$URL,
  'resource=s'          => \(my $resource_uri),
  'tree_file=s'         => \(my $tree_file),
  'connection_score=s'  => \$connection_score,
  'internal_score=s'    => \$internal_score,
  'components=s'        => \$components_map,
  'depth=i'             => \$MAX_DEPTH,
  'verbose!'            => \(my $verbose),
  'progress!'           => \(my $progress),
  'help|?'              => sub { pod2usage(verbose => 2) },
) or die pod2usage(verbose => 1);

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
my $g = Gcis::Client->new(url => $URL);

&main;

sub main {

    my $greeting = <<END;
Evaluating Provenance
    url                    : $URL
    resource               : $resource_uri
    output file            : $tree_file
    internal scores file   : $internal_score
    connection scores file : $connection_score
    components file        : $components_map
    depth                  : $MAX_DEPTH

END
    say $greeting if $verbose;

    confirm_good_resource($resource_uri);
    my $type =  get_resource_type($resource_uri);
    load_rubric_and_components();

    my $score_tree = {
        $resource_uri => score_publication(
                            resource_uri => $resource_uri,
                            type         => $type,
                            depth        => 0,
                         )
    };

    output_to_file( $score_tree );
    say "" if $progress;
    return;
}

=head1 FUNCTIONS

=cut

=head2 score_publication

Given a GCIS Resource URI, its type, and our current depth, returns a
publication score subtree for that publication.

A publication score subtree consists of a score, a connections hash of
contributors and references score subtrees, and a components score subtree.

=cut

sub score_publication {
    my %args = (@_);
    my $resource_uri = $args{resource_uri};
    my $type         = $args{type};
    my $depth        = $args{depth};

    my $resource = $g->get("$resource_uri") or die " Failed to retrieve resource: $resource_uri";

    say "Resource: $resource_uri Type: $type" if $verbose;
    my $score = calculate_internal_score( $type, $resource);

    # Only publication types get contributors. Person & Org return false readings.
    my $connections->{contributors} = {};
    if ( grep { $type eq $_ } qw/person organization/ ) {
        say "No contribs on Persons and Orgs." if $verbose;
    }
    else {
        $connections->{contributors} = score_contributors(
                            contributors => $resource->{contributors},
                            depth        => $depth,
                         );
    }

    # Only some publication types get references
    $connections->{references} = {};
    if ( grep { $type eq $_ } qw/report chapter figure finding table webpage book dataset journal/ ) {
        $connections->{references} = score_references(
            resource => $resource_uri,
            depth    => $depth,
        );
    }

    my $components = score_components(
        resource => $resource,
        type     => $type,
        depth    => $depth,
    );

    return {
        score       => $score,
        connections => $connections,
        components  => $components,
    };
}

#### CONTRIBUTORS SECTION

=head2 score_contributors

Given an array of contributors and the current depth, score all the contributors.

Returns a hash of contributor score trees.

=cut

sub score_contributors {
    my %args = (@_);
    my $contributors = $args{contributors};
    my $depth        = $args{depth};

    return {} unless $contributors; # Empty contributor is fine.

    my $contributors_scored = {};
    for my $contrib ( @$contributors ) {
        my $contrib_score = score_contributor(
            contributor => $contrib,
            depth       => $depth,
        );
        $contributors_scored->{"/contributor/$contrib->{id}"} = $contrib_score;
    }
    return $contributors_scored;
}

=head2 score_contributor

Given a single contributor object and our current depth, return the score
subtree for that contributor.

Contributor subtree consists of a score, a person entity, and organization
entity, and a reference.

=cut

sub score_contributor {
    my %args = (@_);
    my $depth       = $args{depth};
    my $contributor = $args{contributor};

    say "Resource: /contributor/$contributor->{id}" if $verbose;
    my $score = calculate_internal_score( 'contributor', $contributor);

    my $person = $contributor->{person_uri}
        ? score_entity (
            resource => $contributor->{person_uri},
            type     => 'person',
            depth    => $depth,
        )
        : {};

    my $organization = $contributor->{organization_uri}
        ? score_entity (
            resource => $contributor->{organization_uri},
            type     => 'organization',
            depth    => $depth,
        )
        : {};

    # Unsure if we can pull this reference (pub<->contrib) out of GCIS via API. :(
    my $reference = $contributor->{reference}
        ? score_reference (
            resource => $contributor->{reference},
            type     => 'reference',
            depth    => $depth,
        )
        : {};

    return {
        score        => $score,
        person       => $person,
        organization => $organization,
        reference    => $reference,
    };

}

=head2 score_entity

Given a person or organiation object and its type, return the score
subtree for that entity.

Entity subtree consists of a score and a components subtree.

=cut

sub score_entity {
    my %args = (@_);
    my $resource_uri = $args{resource};
    my $type         = $args{type};
    my $depth        = $args{depth};

    my $resource = $g->get("$resource_uri") or die " Failed to retrieve resource: $resource_uri";
    print "\t";
    say "Resource: $resource_uri" if $verbose;
    my $score = calculate_internal_score( $type, $resource);

    my $components = score_components(
        resource => $resource,
        type     => $type,
        depth    => $depth,
    );

    return { $resource_uri => {
        score      => $score,
        components => $components,
    }};
}


#### REFERENCES SECTION

=head2 score_references

Given a resource_uri and the current depth, score all the references related
to that resource.

Returns a hash of reference score trees.

=cut

sub score_references {
    my %args = (@_);
    my $resource_uri = $args{resource};
    my $depth        = $args{depth};

    my $references = $g->get("$resource_uri/reference");
    return {} unless $references; # Empty references is fine.

    my $references_scored = {};
    for my $ref ( @$references ) {
        my $ref_score = score_reference(
            reference => $ref,
            depth     => $depth,
        );
        $references_scored->{"/reference/$ref->{identifier}/"} = $ref_score;
    }
    return $references_scored;
}

=head2 score_reference

Given a single reference object and our current depth, return the score
subtree for that reference.

Reference subtree consisdes of a score plus a single child publication.
Child publication will only be analyzed if our depth is not maxed.

=cut

sub score_reference {
    my %args = (@_);
    my $reference = $args{reference};
    my $depth     = $args{depth};

    say "Resource: /reference/$reference->{identifier}" if $verbose;
    my $score = calculate_internal_score( 'reference', $reference );

    # does child pub exist?
    my $child_pub_id = $reference->{child_publication};
    my $type = get_resource_type($child_pub_id);
    # if so, get the type
    my $child_pub = {};
    if ( $child_pub_id && $MAX_DEPTH > $depth ) {
        $child_pub = score_publication(
            resource_uri => $reference->{child_publication},
            type         => $type,
            depth        => $depth + 1,
        );
    }

    my $child_publication = $child_pub_id ? { $child_pub_id => $child_pub  } : {};

    return {
        score             => $score,
        child_publication => $child_publication,
    };
}

#### COMPONENTS SECTION
=head2 score_components

Muckity function dealing with the various ways to find your components through the GCIS API.
Can handle types Activity, Journal, Chapter, Image, Array, Figure, Finding, and Table.

Given a resource, its type, and the analysis depth, return a hash of all the component types
for this resource, each holding an array of those publications' score subtrees.

=cut

sub score_components {
    my %args = (@_);
    my $resource = $args{resource};
    my $type     = $args{type};
    my $depth    = $args{depth};

    my $component_types = [];
    my $optional = $COMPONENTS->{$type}->{optional};
    my $required = $COMPONENTS->{$type}->{required};
    return {} unless ( $optional || $required );
    push @$component_types, @{ $COMPONENTS->{$type}->{optional} };
    push @$component_types, @{ $COMPONENTS->{$type}->{required} };
    return {} unless $component_types;


    my $component_scores = {};
    for my $component_type ( @$component_types ) {
        if ( $component_type eq "activity" ) {
            # multi
            # Look under the "parents" section
            for my $parent ( @{ $resource->{parents} } ) {
                my $activity = $parent->{activity_uri};
                next unless $activity;
                $component_scores->{activities}->{$activity} = score_publication(
                    resource_uri => $activity,
                    type         => $component_type,
                    depth        => $depth,
                );
            }
        }
        elsif ( $component_type eq "journal" ) {
            # sing
            # Look under "journal_identifier"
            my $journal_id = $resource->{journal_identifier};
            next unless $journal_id;
            my $item_uri = "/journal/$journal_id";
            $component_scores->{journal}->{$item_uri} = score_publication(
                resource_uri => $item_uri,
                type         => $component_type,
                depth        => $depth,
            );
        }
        elsif ( $component_type eq "chapter" ) {
            # multi
            # look under the "*" section, grab the identifier. Construct the uri.
            my $plural_type = $component_type . "s";
            for my $item ( @{ $resource->{$plural_type} } ) {
                next unless $item;
                my $item_uri = "$resource->{uri}/$component_type/$item->{identifier}";
                $component_scores->{$plural_type}->{$item_uri} = score_publication(
                    resource_uri => $item_uri,
                    type         => $component_type,
                    depth        => $depth,
                );
            }

        }
        elsif ( grep { $component_type eq $_ } qw/image array/ ) {
            # multi
            # look under the "*" section, grab the identifier. Construct the uri.
            my $plural_type = $component_type . "s";
            for my $item ( @{ $resource->{$plural_type} } ) {
                next unless $item;
                my $item_uri = "/$component_type/$item->{identifier}";
                $component_scores->{$plural_type}->{$item_uri} = score_publication(
                    resource_uri => $item_uri,
                    type         => $component_type,
                    depth        => $depth,
                );
            }

        }
        elsif ( grep { $component_type eq $_ } qw/figure finding table/ ) {
            # multi
            # type report? look under "report_*"
            # otherwise, look under "*"
            # grab the "uri" directly
            my $component_name = $component_type;
            if ( $type eq "report" ) {
                $component_name = "report_" . $component_type;
            };
            my $plural_name = $component_name . "s"; # only for pulling info out
            my $plural_type = $component_type . "s"; # store under the normal plural
            for my $item ( @{ $resource->{$plural_name} } ) {
                next unless $item;
                $component_scores->{$plural_type}->{$item->{uri}} = score_publication(
                    resource_uri => "$item->{uri}",
                    type         => $component_type,
                    depth        => $depth,
                );
            }
        }
        # TODO files? here or in the main compare?
    }
    return $component_scores;
}

### SCORING SECTION

=head2 calculate_internal_score

Given a resource and its type, determine which provenance
rating the resource meets.

Process:
  Check for 'Acceptable'
  If 'Acceptable' (or skip), Check for 'Good'
  If 'Good' (or skip), Check for 'Very Good'
  If none of those returned 1 (all 0 or skip), Check for 'Poor'
  If not 'Poor', return 'Very Poor'

Returns 1-5, corresponding to the rating.

=cut

sub calculate_internal_score {
    my $type     = shift;
    my $resource = shift;

    print "." if $progress;
    my ( $very_poor, $poor, $acceptable, $good, $very_good ) = 0;
    $acceptable = score_is('acceptable', $type, $resource);
    #say Dumper $resource if $verbose;
    say "\tAcceptable? $acceptable" if $verbose;
    if ( $acceptable ) {
        $good = score_is('good', $type, $resource);
        say "\tGood? $good" if $verbose;
        if ( $good ) {
            $very_good = score_is('very_good', $type, $resource);
            say "\tVery Good? $very_good" if $verbose;
        }
    }
    if ( $very_good == 1 ) {
        return 5;
        say "\t\tScore: 5" if $verbose;
    }
    elsif ( $good == 1 ) {
        say "\t\tScore: 4" if $verbose;
        return 4;
    }
    elsif ( $acceptable == 1 ) {
        say "\t\tScore: 3" if $verbose;
        return 3;
    }

    $poor = score_is('poor', $type, $resource);
    say "\tPoor? $poor" if $verbose;
    if ( $poor == 1 ) {
        say "\t\tScore: 2" if $verbose;
        return 2;
    }
    say "\t\tScore: 1" if $verbose;
    return 1;
}

=head2 score_is

Given a resource, its type, and a quality level, return if
the resource has enough keys to qualify for that quality level.

Returns 1 if it meets the quality, 0 if it does not, and -1 if that
quality level is to be skipped.

=cut

sub score_is {
    my $quality  = shift;
    my $type     = shift;
    my $resource = shift;

    # there can be multiple ways to get to the score
    for my $qualifying_grades ( @{ $RUBRIC->{$type}->{$quality} } ) {
        return -1 if $qualifying_grades->{required} == -1;
        my @keys_to_look_for = @{ $qualifying_grades->{fields} };
        my $count = 0;
        for my $key ( @keys_to_look_for ) {
            if ( $key =~ /:/ ) {
                $count += score_subkey( key => $key, resource => $resource );
            }
            elsif ( exists $resource->{$key} && $resource->{$key} &&  $resource->{$key} ne '') {
                $count++;
            }
            return 1 if $count == $qualifying_grades->{required};
        }
    }

    return 0;
}

=head2 score_subkey

Handles scoring when the desired item is stored inside a
hash, array, or other combination thereof.

Takes a colon seperated key and the resource.

Knows how to handle: attrs:Foo, files:N:Foo, and figures:N:Foo

Returns 1 if the key exists. 0 otherwise.

=cut

sub score_subkey {
    my %args = @_;
    my $multi_key = $args{key};
    my $resource = $args{resource};

    my @keys = split ':', $multi_key;

    # attributes have subkeys in a hash
    if ( $keys[0] eq 'attrs' ) {
        if (
          exists $resource->{$keys[0]}->{$keys[1]}
          && $resource->{$keys[0]}->{$keys[1]}
          &&  $resource->{$keys[0]}->{$keys[1]} ne '') {
            return 1;
        }
    }
    # files and figures have an array, and one of those has a key.
    elsif ( $keys[0] eq 'files' || $keys[0] eq 'figures' || $keys[0] eq 'contributors' ) {
        if (
          exists $resource->{$keys[0]}->[$keys[1]]->{$keys[2]}
          && $resource->{$keys[0]}->[$keys[1]]->{$keys[2]}
          &&  $resource->{$keys[0]}->[$keys[1]]->{$keys[2]} ne '') {
            return 1;
        }
    }

    return 0;
}

### UTILITY FUNCTIONS

=head2 output_to_file

Print out the YAML score tree.

=cut

sub output_to_file {
    my $score_tree = shift;
    # given a perl hash of a tree, output some yaml file!
    my $eval_yaml;
    {
        local $YAML::SortKeys = 0;
        $eval_yaml = YAML::XS::Dump($score_tree);
    }
    open( OUTPUT, ">", $tree_file ) or die $!;
    print OUTPUT $eval_yaml;
    close OUTPUT;
    say "Score tree written to $tree_file." if $verbose;
    print "." if $progress;
    return;
}

=head2 load_rubric_and_components

Load in the YAML rubrics, components.

=cut

sub load_rubric_and_components {
    my $internal_rubric = YAML::XS::LoadFile("$RealBin/$internal_score")
        or die "Could not load Internal Score file: $RealBin/$internal_score";
    my $connection_rubric = YAML::XS::LoadFile("$RealBin/$connection_score")
        or die "Could not load Connection Score file: $RealBin/$connection_score";

    $COMPONENTS = YAML::XS::LoadFile("$RealBin/$components_map")
        or die "Could not load Components file $RealBin/$components_map";
    my %rubric = ( %$internal_rubric, %$connection_rubric );
    $RUBRIC = \%rubric;

    print "." if $progress;

    return;
}

=head2 confirm_good_resource

Confirm we have a singular GCIS resource, and not an array.

=cut

sub confirm_good_resource {
    my $resource_uri = shift;

    my $resource = $g->get("$resource_uri") or die " Failed to retrieve resource: $resource_uri";

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

    return 1;
}

=head2 get_resource_type

Given a resource URI, return the type.

=cut

sub get_resource_type {
    my $resource_uri = shift;
    my $gx = Exim->new($URL, 'read');

    return $gx->extract_type_from_uri($resource_uri);
}

1;

