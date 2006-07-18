use strict;
use Test::More tests => 3, import => ['is_deeply'];
use ok 'Object::Declare' => ['MyApp::Column'];

sub MyApp::Column::new { shift; return { @_ } }

sub do_declare { declare {
    column x =>
        field1 is 'xxx',
        field2 are 'XXX', 'XXX',
        is field3;

    column y =>
        field1 is 'yyy',
        field2 is 'YYY';
} }

my @objects = do_declare;

is_deeply(\@objects => [
    x => {
            'field1' => 'xxx',
            'field2' => ['XXX', 'XXX'],
            'field3' => 1
            },
    y => {
            'field1' => 'yyy',
            'field2' => 'YYY'
            },
], 'object declared correctly (list context)');

my $objects = do_declare;

is_deeply($objects => {
    x => {
            'field1' => 'xxx',
            'field2' => ['XXX', 'XXX'],
            'field3' => 1
            },
    y => {
            'field1' => 'yyy',
            'field2' => 'YYY'
            },
}, 'object declared correctly (scalar context)');

