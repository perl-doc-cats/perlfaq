
=head1 NAME 

perl create_question_list.pl - search the pod files for the questions

=head1 DESCRIPTION

Used to create the list in perlfaq.pod

=cut

use strict;
use warnings;

use Path::Class;
use Data::Dumper;
use HTML::TreeBuilder;
use Pod::Simple::XHTML;

# constants
my $SOURCE       = './lib';
my $HTML_CHARSET = 'UTF-8';

{
    my $source = Path::Class::Dir->new($SOURCE);

    while ( my $pod_file = $source->next ) {
        next unless $pod_file->stringify =~ /.pod$/;
        next unless $pod_file->stringify =~ /\d/;

        # next unless $pod_file->stringify =~ /3/;

        my $parser = Pod::Simple::XHTML->new;
        $parser->html_header('');
        $parser->html_footer('');
        $parser->html_charset($HTML_CHARSET);
        my $html = '';
        $parser->output_string( \$html );
        $parser->parse_file( $pod_file->stringify );

        my $root = HTML::TreeBuilder->new_from_content($html);    # empty tree
        $root->elementify;

        my @doc  = $root->content_list();
        my @body = $doc[1]->content_list();

        my $html_nodes = scalar(@body);

        my %data;
        my @questions;

        for ( my $i = 0; $i <= $html_nodes; $i++ ) {
            my $h_node = $body[$i] || next;
            my $tag = $h_node->tag;
            next unless $tag =~ /^h/;
            my $text = fetch_text($h_node);

            if ( $tag eq 'h2' ) {

                # All a bit hacky, but works - patches welcome
                $text =~ s/</E<lt>/g;
                $text =~ s/([^lt])>/$1E<gt>/g;
                $text =~ s/CSTART/C</g;
                $text =~ s/CEND/>/g;
                push( @questions, $text );

            } else {
                $data{$tag}->{$text} = fetch_text( $body[ $i + 1 ] );
            }
        }

        my $name = $data{'h1'}->{'NAME'};
        my $desc = $data{'h1'}->{'DESCRIPTION'};

        $name =~ s/(perlfaq.+) -/L<$1>:/;

        print "=head2 $name\n\n";
        print "$desc\n\n";
        print "=over 4\n\n";

        foreach my $q (@questions) {
            print "=item *\n\n";
            print "$q\n\n";
        }

        print "=back\n\n\n";
    }

}

sub fetch_text {
    my $node = shift || return '';

    my $start = '';
    my $end   = '';
    if ( $node->tag eq 'code' ) {

        # All a bit hacky, but works - patches welcome
        $start = 'CSTART';
        $end   = 'CEND';
    }

    my @nodes = $node->content_list();

    # Wrap CSTART/CEND and recurse down if needed
    my $str
        = $start
        . ( join ' ', map { ref($_) ? fetch_text($_) : $_ } @nodes )
        . $end;
    $str =~ s/\s{2,}/ /g;    # Remove extra spaces
    return $str;
}
