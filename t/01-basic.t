use strict;
use Test::More tests => 2, import => ['is_deeply'];
use ok 'Object::Declare' => ['MyApp::Column'];

sub MyApp::Column::new { shift; return { @_ } }

my $objects = declare {

column x =>
    field1 is 'xxx',
    field2 is 'XXX',
    is field3;

column y =>
    field1 is 'yyy',
    field2 is 'YYY';

};

is_deeply($objects => {
    x => {
            'field1' => 'xxx',
            'field2' => 'XXX',
            'field3' => 1
            },
    y => {
            'field1' => 'yyy',
            'field2' => 'YYY'
            },
}, 'object declared correctly');

