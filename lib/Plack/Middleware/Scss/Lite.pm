package Plack::Middleware::Scss::Lite;
use strict;
use warnings;
use 5.008008;
our $VERSION = '0.01';
use autodie;

use parent qw(Plack::Middleware);
use Plack::Util::Accessor qw(path_re root);
use Plack::Util qw();
use IPC::Open3 qw(open3);
use Carp ();
use File::Spec::Functions qw(catfile);
use File::Basename qw(dirname);
use POSIX;
use HTML::Entities qw(encode_entities);

sub prepare_app {
    my $self = shift;
}

sub call {
    my($self, $env) = @_;

    # Sort of depends on how App::File works
    my $orig_path_info = $env->{PATH_INFO};
    if ($env->{PATH_INFO} =~ $self->path_re) {
        (my $src = $env->{PATH_INFO}) =~ s/\.css$/\.scss/;
        open my $fh, '<', catfile($self->root, $src);

        my $body = do { local $/; <$fh> };
        if ($body !~ /\@charset\s*"utf-?8"/i) {
            my $buf = sprintf("'%s' does not contains \@charset directive. It makes compilation error on Ruby 1.9.", encode_entities($src));
            return [500, 
                [
                    'Content-Type' => 'text/plain; charset=utf-8',
                    'Content-Length' => length $buf,
                    'X-Content-Type-Options' => 'nosniff',
                ],
                [$buf]
            ];
        }
        my $incdir = dirname(catfile($self->root, $env->{PATH_INFO}));
        my $pid = open3(my $in, my $out, my $err,
            "sass", '--stdin', '--cache-location', "/tmp/scss-cache-$<", "--stdin", '--scss', '--style', 'expanded', '--unix-newlines', '-I', $incdir);
        print $in $body;
        close $in;

        # scss is not return correct output to stderr.
        my $buf = join '', <$out>;
        waitpid $pid, 0;

        if (POSIX::WIFEXITED($?) && POSIX::WEXITSTATUS($?) == 0) {
            return [200, [
                'Content-Type' => 'text/css; charset=utf-8',
                'Content-Length' => length $buf,
            ], [$buf]];
        } else {
            warn "SCSS compilation failed: $?\n$buf";
            $buf =~ s/\n/\\A/g;
            $buf =~ s/"/\\22/g;
            $buf =~ s/'/\\27/g;
            return [500, [
                'Content-Type' => 'text/css; charset=utf-8',
            ], [ qq{
                body:before {
                    display: block;
                    font-size: 20px;
                    padding: 20px;
                    white-space: pre;
                    line-height: 1.33;
                    font-family: "Monaco", monospace";
                    color: #fff;
                    background: #900;
                    content: "SCSS ERROR\\A$buf";
                }
            } ]]
        }
    }

    return $self->app->($env);
}


1;
__END__

=encoding utf8

=head1 NAME

Plack::Middleware::Scss::Lite - A module for you

=head1 SYNOPSIS

  use Plack::Middleware::Scss::Lite;

=head1 DESCRIPTION

Plack::Middleware::Scss::Lite is yet another SCSS handler middleware for debugging.

Do not use this module in production environment.
This middleware compiles scss on run time.
It's very heavy action. Please compile scss files on deployment hook.

=head1 What's different between Plack::Middleware::File::Sass?

=over 4

=item This module is simpler.

This module only supports sass command.

=item Better error handling

This module watches $? for error handling.

=back

=head1 AUTHOR

Tokuhiro Matsuno E<lt>tokuhirom AAJKLFJEF@ GMAIL COME<gt>

=head1 SEE ALSO

=head1 LICENSE

Copyright (C) Tokuhiro Matsuno

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
