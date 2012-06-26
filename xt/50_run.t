use strict;
use warnings;
use utf8;
use Test::More;
use Test::Requires 'File::Which', 'HTTP::Request::Common';
which('sass') or plan skip_all => 'sass command is required but not found.';
use File::Spec;

use Plack::Builder;
use Plack::Test;

my $app = builder {
    enable 'Plack::Middleware::Scss::Lite',
        path_re => qr{^/scss/},
        root    => File::Spec->rel2abs('xt/');
    sub { [200, [], ['ok']] }
};

test_psgi $app, sub {
    my $cb = shift;
    my $res = $cb->(GET 'http://localhost/scss/basic.scss');
    is($res->code, 200);
    like($res->content, qr/color: red/);
};

test_psgi $app, sub {
    my $cb = shift;
    my $res = $cb->(GET 'http://localhost/scss/error.scss');
    is($res->code, 500);
    like($res->content, qr/body:before/);
};

done_testing;

