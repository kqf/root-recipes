# CERN ROOT recipes

CERN's ROOT is a library analyzing data, but sometimes it gets really difficult to make it work.
There are tons of [libraries, wrappers, and projects](#Libraries) for `PyROOT` intended to simplify your work.
This is a collection of hacks and recipes to be used when you **really** need to get things done and there's no option (or time) to install the environment, learn the new syntax.


## Libraries
There is solid support of python versions of ROOT modules in [scikit-hep](https://github.com/scikit-hep/), the most commonly used are
    1. Most of the cases are covered by [`rootpy`](https://github.com/rootpy/rootpy). It might not work in some environments, and docs are "still under construction".
    2. [`uproot`](https://github.com/scikit-hep/uproot) handles some basic objects and there's no need to install ROOT library. It's very neat, but not useful (so far) if you have collections in your `*.root` files.
    3. Handy converters from `numpy.arrays` to various ROOT types [`root_numpy`](https://github.com/scikit-hep/root_numpy). Requires `root` and sometimes may fail in nonstandard environments
    4. The same for pandas [`root_pandas`](https://github.com/scikit-hep/root_pandas)
