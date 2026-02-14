from setuptools import Extension, setup
from setuptools.command.build_ext import build_ext
import os


class cyhpack_build_ext(build_ext):

    # Brought over from winloop since these can be very useful.
    user_options = build_ext.user_options + [
        ("cython-always", None, "run cythonize() even if .c files are present"),
        (
            "cython-annotate",
            None,
            "Produce a colorized HTML version of the Cython source.",
        ),
        ("cython-directives=", None, "Cythion compiler directives"),
    ]

    def build_extensions(self):
        self.add_include_dir("ls-hpack")
        self.add_include_dir(os.path.join("ls-hpack", "compat"))
        self.add_include_dir(os.path.join("ls-hpack", "queue"))
        self.add_include_dir(os.path.join("ls-hpack", ""))


        # self.add_include_dir(os.path.join("ls-hpack", "windows"))

        return super().build_extensions()

    def finalize_options(self):
        need_cythonize = self.cython_always
        cfiles = {}

        for extension in self.distribution.ext_modules:
            for i, sfile in enumerate(extension.sources):
                if sfile.endswith(".pyx"):
                    prefix, ext = os.path.splitext(sfile)
                    cfile = prefix + ".c"

                    if os.path.exists(cfile) and not self.cython_always:
                        extension.sources[i] = cfile
                    else:
                        if os.path.exists(cfile):
                            cfiles[cfile] = os.path.getmtime(cfile)
                        else:
                            cfiles[cfile] = 0
                        need_cythonize = True

        if need_cythonize:

            # Double check Cython presence in case setup_requires
            # didn't go into effect (most likely because someone
            # imported Cython before setup_requires injected the
            # correct egg into sys.path.
            try:
                import Cython  # noqa: F401
            except ImportError:
                raise RuntimeError(
                    "please install cython to compile cyares from source"
                )

            from Cython.Build import cythonize

            directives = {}
            if self.cython_directives:
                for directive in self.cython_directives.split(","):
                    k, _, v = directive.partition("=")
                    if v.lower() == "false":
                        v = False
                    if v.lower() == "true":
                        v = True
                    directives[k] = v
                self.cython_directives = directives

            self.distribution.ext_modules[:] = cythonize(
                self.distribution.ext_modules,
                compiler_directives=directives,
                annotate=self.cython_annotate,
                emit_linenums=self.debug,
                # Try using a cache to help with compiling as well...
                cache=True,
            )

        return super().finalize_options()

    def initialize_options(self):
        self.cython_always = False
        self.cython_annotate = False
        self.cython_directives = None
        self.parallel = True
        super().initialize_options()

    def add_include_dir(self, dir, force=False):
        dirs = self.compiler.include_dirs
        dirs.insert(0, dir)
        self.compiler.set_include_dirs(dirs)


# NOTE: ls-hpack/lshpack_lib_init.c belongs to us and it is currently custom to give 
# Python allocators full control over the library.
if __name__ == "__main__":
    setup(
        cmdclass={"build_ext": cyhpack_build_ext},
        ext_modules=[
            Extension(
                "cyhpack.hpack",
                ["cyhpack/hpack.pyx", "ls-hpack/lshpack.c", "ls-hpack/lshpack_lib_init.c", "ls-hpack/deps/xxhash/xxhash.c"],
                extra_compile_args=["-O2"]
            )
        ]
    )

