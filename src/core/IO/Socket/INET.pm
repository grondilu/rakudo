my class IO::Socket::INET does IO::Socket {
    my module PIO {
        constant PF_LOCAL       = 0;
        constant PF_UNIX        = 1;
        constant PF_INET        = 2;
        constant PF_INET6       = 3;
        constant PF_MAX         = 4;
        constant SOCK_PACKET    = 0;
        constant SOCK_STREAM    = 1;
        constant SOCK_DGRAM     = 2;
        constant SOCK_RAW       = 3;
        constant SOCK_RDM       = 4;
        constant SOCK_SEQPACKET = 5;
        constant SOCK_MAX       = 6;
        constant PROTO_TCP      = 6;
        constant PROTO_UDP      = 17;
    }

    has Str $.encoding = 'utf8';
    has Str $.host;
    has Int $.port = 80;
    has Str $.localhost;
    has Int $.localport;
    has Bool $.listen;
    has $.family = PIO::PF_INET;
    has $.proto = PIO::PROTO_TCP;
    has $.type = PIO::SOCK_STREAM;
    has Str $.input-line-separator is rw = "\n";
    has Int $.ins = 0;

    my sub v4-split($uri) {
        return $uri.split(':', 2);
    }

    my sub v6-split($uri) {
        my ($host, $port) = ($uri ~~ /^'[' (.+) ']' \: (\d+)$/)[0,1];
        return $host ?? ($host, $port) !! $uri;
    }

    method new (*%args is copy) {
        fail "Nothing given for new socket to connect or bind to" unless %args<host> || %args<listen>;

        if %args<host>  {
            my ($host, $port) = %args<family> && %args<family> == PIO::PF_INET6
                ?? v6-split(%args<host>)
                !! v4-split(%args<host>);
            if $port {
                %args<port> //= $port.Int;
                %args<host> = $host;
            }
        }
        if %args<localhost> {
            my ($peer, $port) = %args<family> && %args<family> == PIO::PF_INET6
                ?? v6-split(%args<localhost>)
                !! v4-split(%args<localhost>);
            if $port {
                %args<localport> //= $port.Int;
                %args<localhost> = $peer;
            }
        }

        %args<listen>.=Bool if %args.EXISTS-KEY('listen');

        #TODO: Learn what protocols map to which socket types and then determine which is needed.
        self.bless(|%args)!initialize()
    }

    method !initialize() {
        my $PIO := nqp::socket($.listen ?? 10 !! 0);
        #Quoting perl5's SIO::INET:
        #If Listen is defined then a listen socket is created, else if the socket type,
        #which is derived from the protocol, is SOCK_STREAM then connect() is called.
        if $.listen || $.localhost || $.localport {
            nqp::bindsock($PIO, nqp::unbox_s($.localhost || "0.0.0.0"),
                                 nqp::unbox_i($.localport || 0));
        }

        if $.listen {
        }
        elsif $.type == PIO::SOCK_STREAM {
            nqp::connect($PIO, nqp::unbox_s($.host), nqp::unbox_i($.port));
        }

        nqp::bindattr(self, $?CLASS, '$!PIO', $PIO);
        self;
    }

    method get() {
        my Mu $io       := nqp::getattr(self, $?CLASS, '$!PIO');
        my str $encoding = Rakudo::Internals.NORMALIZE_ENCODING($!encoding);
        nqp::setencoding($io, $encoding);
        my str $sep = nqp::unbox_s($!input-line-separator);
        nqp::setinputlinesep($io, $sep);
        my int $sep-len = nqp::chars($sep);
        my str $line    = nqp::readlinefh($io);
        my int $len     = nqp::chars($line);

        if $len == 0 { Str }
        else {
            ++$!ins;
            $len >= $sep-len && nqp::eqat($line, $sep, $len - $sep-len)
                ?? nqp::p6box_s(nqp::substr($line, 0, $len - $sep-len))
                !! nqp::p6box_s($line);
        }
    }

    method lines() {
        gather while (my $line = self.get()).defined {
            take $line;
        }
    }

    method accept() {
        ## A solution as proposed by moritz
        my $new_sock := $?CLASS.bless(:$!family, :$!proto, :$!type, :$!input-line-separator);
#?if jvm
        nqp::getattr($new_sock, $?CLASS, '$!buffer') = buf8.new;
#?endif
        nqp::bindattr($new_sock, $?CLASS, '$!PIO',
            nqp::accept(nqp::getattr(self, $?CLASS, '$!PIO'))
        );
        return $new_sock;
    }

    method remote_address() {
    }

    method local_address() {
    }
}

# vim: ft=perl6 expandtab sw=4
