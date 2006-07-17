use strict;
use inc::Module::Install;

name        'Object-Declare';
license     'MIT';
all_from    'lib/Object/Declare.pm';

requires    'Sub::Override';

include_deps 'ok';
include_deps 'Test::More';

sign; WriteAll;
