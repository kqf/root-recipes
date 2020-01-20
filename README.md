# CERN's ROOT recipes

CERN's ROOT is a library for analyzing data, but sometimes it gets really difficult to make it work.
There are tons of [libraries, wrappers, and projects](#Libraries) for `PyROOT` intended to simplify your work.
This is a collection of hacks and recipes to be used when you **really** need to get things done and there's no option (or time) to install the environment, learn the new syntax.

### Use contextmanagers
```python
import ROOT
from contextlib import contextmanager


@contextmanager
def ropen(filename, option="read"):
    rfile = ROOT.TFile(filename, option)
    yield rfile
    rfile.Close()


def main():
    # Write
    with ropen("test.root", option="recreate"):
        ohist = ROOT.TH1F('test_hist', 'test', 100, -3, 3)
        ohist.FillRandom("gaus")
        ohist.Write("test_hist")
        original_entries = ohist.GetEntries()

    # ROOT removed the object after exiting file
    # NB and it's not None, but PyROOT_NoneType
    print(ohist)

    # Read
    with ropen("test.root", option="open") as f:
        hist = f.Get("test_hist")
        assert hist is not None
        assert hist.GetEntries() > 0
        assert original_entries == hist.GetEntries()


if __name__ == '__main__':
    main()

```
### `AttributeError: 'PyROOT_NoneType' object has no attribute`
This problem happens bacause `ROOT` has its own memory management. Usually it occurs when the associated file or directory is closed but you still want to use the object.
Adding the line `ROOT.TH1.AddDirectory(False)` fixes it
```python
import ROOT
from contextlib import contextmanager

# Force ROOT not to make the associations with the current directory
# Comment it and you will get the error
ROOT.TH1.AddDirectory(False)


@contextmanager
def ropen(filename, option="read"):
    rfile = ROOT.TFile(filename, option)
    yield rfile
    rfile.Close()


def main():
    with ropen("donothing.root", "recreate"):
        # Now hist is associated with the "donothing.root"
        hist = ROOT.TH1F('test_hist', 'test', 100, -3, 3)

    # Now it's out of the scope of "donothing.root"
    print(hist.GetEntries())


if __name__ == '__main__':
    main()
```

## Libraries
There is solid support of python versions of ROOT modules in [scikit-hep](https://github.com/scikit-hep/), the most commonly used are

| library |         |
|---------| ------- |
|[`rootpy`](https://github.com/rootpy/rootpy)| Most of the cases are covered here. It might not work in some environments, and docs are "still under construction".|
|[`uproot`](https://github.com/scikit-hep/uproot)| It handles some basic objects and there's no need to install ROOT library. It's very neat, but not useful (so far) if you have collections in your `*.root` files.|
|[`root_numpy`](https://github.com/scikit-hep/root_numpy)| Handy converters from `numpy.arrays` to various ROOT types . Requires `root` and sometimes may fail in nonstandard environments|
|[`root_pandas`](https://github.com/scikit-hep/root_pandas)| The same for pandas|
