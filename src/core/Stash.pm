my class Stash { # declared in BOOTSTRAP
    # class Stash is Hash {

    multi method AT-KEY(Stash:D: Str() $key, :$global_fallback) is raw {
        my Mu $storage := nqp::defined(nqp::getattr(self, Map, '$!storage')) ??
            nqp::getattr(self, Map, '$!storage') !!
            nqp::bindattr(self, Map, '$!storage', nqp::hash());
        if nqp::existskey($storage, nqp::unbox_s($key)) {
            nqp::atkey($storage, nqp::unbox_s($key))
        }
        elsif $global_fallback {
            nqp::existskey(GLOBAL.WHO, $key)
                ?? GLOBAL.WHO.AT-KEY($key)
                !! fail("Could not find symbol '$key'")
        }
        else {
            nqp::p6bindattrinvres(my $v, Scalar, '$!whence',
                 -> { nqp::bindkey($storage, nqp::unbox_s($key), $v) } )
        }
    }

    method package_at_key(Stash:D: str $key) {
        my Mu $storage := nqp::defined(nqp::getattr(self, Map, '$!storage')) ??
            nqp::getattr(self, Map, '$!storage') !!
            nqp::bindattr(self, Map, '$!storage', nqp::hash());
        if nqp::existskey($storage, nqp::unbox_s($key)) {
            nqp::atkey($storage, $key)
        }
        else {
            my $pkg := Metamodel::PackageHOW.new_type(:name($key));
            $pkg.^compose;
            nqp::bindkey($storage, $key, $pkg)
        }
    }

    method merge-symbols(Stash:D: Stash $globalish) {
        if $globalish !=== Stash {
            nqp::gethllsym('perl6', 'ModuleLoader').merge_globals(self, $globalish);
        }
    }
}

# vim: ft=perl6 expandtab sw=4
