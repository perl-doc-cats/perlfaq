=head1 NAME 

perl create_question_list.pl - search the pod files for the questions

=head1 DESCRIPTION

Used to create the list in perlfaq.pod

=cut

use strict;
use warnings;

use Path::Class;
use Data::Dumper;
use Pod::Simple::SimpleTree;

# constants
my $SOURCE = './lib';

{
    my $source = Path::Class::Dir->new($SOURCE);

    while ( my $pod_file = $source->next ) {
        next unless $pod_file->stringify =~ /.pod$/;
        next unless $pod_file->stringify =~ /\d/;

        my $name;
        my $desc;
        my @questions;
        
        my $tree
            = Pod::Simple::SimpleTree->new->parse_file( $pod_file->stringify )
            ->root;
        
        shift @$tree;
        shift @$tree;
        
        my $num_nodes = scalar( @{$tree} );
        
        for ( my $i = 0; $i < $num_nodes; $i++ ) {
            my $node = $tree->[$i];
            if ( $node->[0] eq 'head1' && $node->[2] eq 'NAME' ) {
                $name = $tree->[ $i + 1 ]->[2];
            }
            if ( $node->[0] eq 'head1' && $node->[2] eq 'DESCRIPTION' ) {
                $desc = $tree->[ $i + 1 ]->[2];
            }
            if ( $node->[0] eq 'head2' ) {
                my $q = $node->[2];
                push @questions, $q;
            }

        }

        $name =~ s/(perlfaq.+) -/L<$1>:/;

        print "=head2 $name\n\n";
        print "$desc\n\n";
        print "=over 4\n";
        
        foreach my $q (@questions) {
            print "=item *\n\n";
            print "$q\n\n";
        }

        print "=back\n\n";

    }

}


