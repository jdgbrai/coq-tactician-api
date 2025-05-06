# Build tool setup

Setup the tooling with 

    nix develop

We're not using the nix tooling to build the poetry file.  We're doing something a bit weirder at the moment, and using the fact that nix installs uv and python, and then
making our own venv, and using that it will install the right stuff.  It should work with the uv2nix stuff, I just haven't tested it yet.
`<todo: test it>`

If you're using `direnv` then in a bash shell with direnv generally enabled (e.g. with `eval "$(direnv hook bash)"` in the `~/.bashrc` file).

    echo "use flake ." > .envrc
    direnv allow

Then cd out and back into the directory in bash.  

If you're not using `direnv` then to activate the nix shell, just type `nix develop` within a bash shell, and that will activate the nix shell.

# Entry point test

We will compile the `<project-root>/adhoc_data/trivial.v` into a dataset, and we'll do so a bit carefully.

# Stdlib

At the moment, we're doing just enough to test that things are working out okay on building the standard lib.