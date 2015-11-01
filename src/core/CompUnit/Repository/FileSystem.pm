class CompUnit::Repository::FileSystem does CompUnit::Repository::Locally does CompUnit::Repository {
    has %!loaded;

    my %extensions =
      Perl6 => <pm6 pm>,
      Perl5 => <pm5 pm>,
      NQP   => <nqp>,
      JVM   => ();

    # global cache of files seen
    my %seen;

    method need(
        CompUnit::DependencySpecification $spec,
        \GLOBALish is raw = Any,
        CompUnit::PrecompilationRepository :$precomp = self.precomp-repository(),
        :$line
    )
        returns CompUnit:D
    {
        state Str $precomp-ext = $*VM.precomp-ext;  # should be $?VM probably
        my $dir-sep           := $*SPEC.dir-sep;
        my $name               = $spec.short-name;
        my $compunit;

        # pick a META6.json if it is there
        if (my $meta = ($!prefix.abspath ~ $dir-sep ~ 'META6.json').IO) && $meta.f {
            my $json = from-json $meta.slurp;
            if $json<provides>{$name} -> $file {
                my $has_precomp = $file.ends-with($precomp-ext);
                my $has_source  = !$has_precomp;
                my $path        = $file.IO.is-absolute
                                ?? $file
                                !! $!prefix.abspath ~ $dir-sep ~ $file;
                $has_precomp    = ?IO::Path.new-from-absolute-path($path ~ '.' ~ $precomp-ext).f
                    unless $has_precomp;

                $compunit = %seen{$path} = CompUnit.new(
                  $path, :name($name), :extension(''), :$has_source, :$has_precomp, :repo(self)
                ) if IO::Path.new-from-absolute-path($path).f;
            }
        }
        # deduce path to compilation unit from package name
        else {
            my $base := $!prefix.abspath ~ $dir-sep ~ $name.subst(:g, "::", $dir-sep) ~ '.';
            if %seen{$base} -> $found {
                $compunit = $found;
            }

            # have extensions to check
            elsif %extensions<Perl6> -> @extensions {
                for @extensions -> $extension {
                    my $path = $base ~ $extension;

                    $compunit = %seen{$base} = CompUnit.new(
                      $path, :$name, :$extension, :has-source, :repo(self)
                    ) if IO::Path.new-from-absolute-path($path).f;
                    $compunit = %seen{$base} = CompUnit.new(
                      $path, :$name, :$extension, :!has-source, :has-precomp, :repo(self)
                    ) if not $compunit and IO::Path.new-from-absolute-path($path ~ '.' ~ $precomp-ext).f;
                }
            }

            # no extensions to check, just check compiled version
            elsif $base ~ $precomp-ext -> $path {
                $compunit = %seen{$base} = CompUnit.new(
                  $path, :$name, :extension(''), :!has-source, :has-precomp, :repo(self)
                ) if IO::Path.new-from-absolute-path($path).f;
            }
        }

        if $compunit {
            $compunit.load(GLOBALish, :$line);
            return %!loaded{$compunit.name} = $compunit;
        }

        return self.next-repo.need($spec, GLOBALish, :$precomp, :$line) if self.next-repo;
        nqp::die("Could not find $spec in:\n" ~ $*REPO.repo-chain.map(*.Str).join("\n").indent(4));
    }

    method load(Str:D $file, \GLOBALish is raw = Any, :$line) returns CompUnit:D {
        state Str $precomp-ext = $*VM.precomp-ext;  # should be $?VM probably
        my $dir-sep           := $*SPEC.dir-sep;

        # We have a $file when we hit: require "PATH" or use/require Foo:file<PATH>;
        my $has_precomp = $file.ends-with($precomp-ext);
        my $path = $file.IO.is-absolute
                ?? $file
                !! $!prefix.abspath ~ $dir-sep ~ $file;

        if IO::Path.new-from-absolute-path($path).f {
            my $compunit = %seen{$path} = CompUnit.new(
              $path, :$file, :extension(''), :has-source(!$has_precomp), :$has_precomp, :repo(self)
            );
            $compunit.load(GLOBALish, :$line);
            return %!loaded{$compunit.name} = $compunit;
        }

        return self.next-repo.load($file, :$line) if self.next-repo;
        nqp::die("Could not find $file in:\n" ~ $*REPO.repo-chain.map(*.Str).join("\n").indent(4));
    }

    method short-id() { 'file' }

    method loaded() returns Iterable {
        return %!loaded.values;
    }

    method files($file, :$name, :$auth, :$ver) {
        my $base := $file.IO;
        $base.f
         ?? { files => { $file => $base.path }, ver => Version.new('0') }
         !! ();
    }
}

# vim: ft=perl6 expandtab sw=4
