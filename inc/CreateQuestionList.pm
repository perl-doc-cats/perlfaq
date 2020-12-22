=pod

=head1 NAME

create_question_list.pl - search the pod files for the questions

=head1 DESCRIPTION

Used to create the list in perlfaq.pod

=cut

use strict;
use warnings;
package # hide from PAUSE
  inc::CreateQuestionList;

use Moose;
with
    'Dist::Zilla::Role::FileGatherer',
    'Dist::Zilla::Role::FileMunger';

use Template;
use HTML::TreeBuilder;
use Pod::Simple::XHTML;

my $HTML_CHARSET = 'UTF-8';

sub gather_files {
    my $self = shift;

    require Dist::Zilla::File::InMemory;
    $self->add_file(
        Dist::Zilla::File::InMemory->new({
            name    => 'lib/perlfaq.pod',
            content => '',  # filled in later
        })
    );
    return;
}

sub munge_files {
    my $self = shift;

    my ($file) = grep $_->name eq 'lib/perlfaq.pod', @{$self->zilla->files};

    my $encoded_content;
    open my $fh, sprintf('>:encoding(%s)', $file->encoding), \$encoded_content
        or $self->log_fatal('cannot open handle to create ' . $file->name . ' content: ' . $!);

    my $the_questions = $self->get_questions();
    my $tt = Template->new( { POST_CHOMP => 1, } );
    $tt->process( 'inc/perlfaq.tt', { the_questions => $the_questions }, $fh)
        || die $tt->error();
    close $fh;

    $file->encoded_content($encoded_content);
}

sub get_questions {
    my $self = shift;

    my $out;
    {
        foreach my $pod_file (@{$self->zilla->files}) {
            next unless $pod_file->name =~ /.pod$/;
            next unless $pod_file->name =~ /\d/;

            # next unless $pod_file->name =~ /3/;

            my $parser = Pod::Simple::XHTML->new;
            $parser->html_header('');
            $parser->html_footer('');
            $parser->html_charset($HTML_CHARSET);
            my $html = '';
            $parser->output_string( \$html );

            open my $pod_fh, sprintf('<:encoding(%s)', $pod_file->encoding), \$pod_file->encoded_content
                or $self->log_fatal('cannot open handle to ' . $pod_file->name . ' content: ' . $!);
            $parser->parse_file($pod_fh);

            my $root
                = HTML::TreeBuilder->new_from_content($html);    # empty tree
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

            $out .= "=head2 $name\n\n";
            $out .= "$desc\n\n";
            $out .= "=over 4\n\n";

            foreach my $q (@questions) {
                $out .= "=item *\n\n";
                $out .= "$q\n\n";
            }

            $out .= "=back\n\n\n";
        }

    }
    return $out;
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
        . ( join ' ', map ref($_) ? fetch_text($_) : $_, @nodes )
        . $end;
    $str =~ s/\s{2,}/ /g;    # Remove extra spaces
    $str =~ s/\s+$//;        # Remove trailing white spaces
    return $str;
}

1;
