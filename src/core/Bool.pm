my class Bool {
    method Bool() { self }

    multi method Str(Bool:D:) {
        self ?? 'Bool::True' !! 'Bool::False'
    }

    method Numeric() { self ?? 1 !! 0 }

    method pred() { Bool::False }

    method succ() { Bool::True }

    method ACCEPTS(Mu \$topic) { self }
}


proto prefix:<?>(|$) { * }
multi prefix:<?>(Bool \$a) { $a }
multi prefix:<?>(Mu \$a) { $a.Bool }

proto prefix:<so>(|$) { * }
multi prefix:<so>(Bool \$a) { $a }
multi prefix:<so>(Mu \$a) { $a.Bool }

# XXX These should use Bool::True and Bool::False eventually.
proto prefix:<!>(|$) { *}
multi prefix:<!>(Bool \$a) { nqp::p6bool($a ?? 0 !! 1) }
multi prefix:<!>(Mu \$a) { nqp::p6bool($a.Bool ?? 0 !! 1) }

proto prefix:<not>(|$) { *}
multi prefix:<not>(Bool \$a) { nqp::p6bool($a ?? 0 !! 1) }
multi prefix:<not>(Mu \$a) { nqp::p6bool($a.Bool ?? 0 !! 1) }
