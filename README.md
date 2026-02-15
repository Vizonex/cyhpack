# cyhpack
A Drop in replacement of python's hpack for the faster C library backend. This has plans to be used for speeding up
server side related tools like h2 and I still have plans for making my version of ls-hpack (it's backend) more modernized
since it's not being maintained anymore. This still uses hpack exceptions however in order to be 1 to 1 so that exception 
handling is unified.

# TODOS
- I have yet to optimize more sections but this was due to me figuring out how it works.
- PYPI package soon.
- I'll need to make a pull request to h2 to figure out ways to support this extension.
- pytest testsuite. I'll probably be asking the python hpack maintainers for help with it.


