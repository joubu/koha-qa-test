package QohA::Benchmarks;

use Modern::Perl;
use Benchmark ':hireswallclock';
use HTTPD::Bench::ApacheBench;

use C4::Context;
use Koha::Cache;
use Koha::Cache::Memory::Lite;

our $COUNTS = { sysprefs => 2000000, opac_main => 10, opac_search => 10, koha_cache => 1000 };

sub run {
    my ($self) = @_;

    # Clear different caches
    Koha::Database->new_schema;
    Koha::Cache->get_instance->flush_all;
    Koha::Cache::Memory::Lite->get_instance->flush();

    my $r;
    $r->{syspref}     = $self->retrieve_syspref('OPACBaseURL');
    $r->{opac_main}   = $self->hit_opac_main;
    $r->{opac_search} = $self->hit_opac_search;
    $r->{koha_cache}  = $self->load_koha_cache;
    return $r;
}

sub retrieve_syspref {
    my ( $self, $syspref_name, $count ) = @_;
    my $t = timeit( $COUNTS->{sysprefs}, sub { C4::Context->preference($syspref_name) } );
    return $t->[0];
}

sub hit_opac_main {
    my ( $self, $count ) = @_;
    $count //= $COUNTS->{opac_main};
    my $opac_base_url = C4::Context->preference('OPACBaseURL');
    return $self->hit_url( $opac_base_url, $count );
}

sub hit_opac_search {
    my ( $self, $count ) = @_;
    $count //= $COUNTS->{opac_search};
    my $opac_base_url = C4::Context->preference('OPACBaseURL');
    return $self->hit_url( $opac_base_url . '/cgi-bin/koha/opac-search.pl?q=d', $count );
}

sub hit_url {
    my ( $self, $url, $count ) = @_;
    return unless $count;
    return unless $url;
    my $b = HTTPD::Bench::ApacheBench->new;
    for ( 1 .. $count ) {
        $b->add_run( HTTPD::Bench::ApacheBench::Run->new( { urls => [$url] } ) );
    }
    my $t = timeit( 1, sub { $b->execute } );
    return if $b->total_responses_failed;

    # say 1000*$b->total_requests/$b->total_time." req/sec";
    return $t->[0];
}

sub load_koha_cache {
    my ( $self, $count ) = @_;
    $count //= $COUNTS->{koha_cache};
    my $t;
    for my $i ( 1 .. 3 ) {
        for my $j ( 1 .. 10000 ) {
            $t->{$i}{$j} = "$i$j";
        }
    }
    my $cache = Koha::Cache->get_instance;
    my $key   = "my_key";
    my $t_set = timeit( $count, sub { $cache->set_in_cache( $key, $t ) } );
    my $t_get = timeit( $count, sub { $cache->get_from_cache($key) } );
    return $t_set->[0] + $t_get->[0];
}

1;
