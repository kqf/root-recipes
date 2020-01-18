# CERN's ROOT recipes

CERN's ROOT is a library analyzing data, but sometimes it gets really difficult to make it work.
There are tons of [libraries, wrappers, and projects](#Libraries) for `PyROOT` intended to simplify your work.
This is a collection of hacks and recipes to be used when you **really** need to get things done and there's no option (or time) to install the environment, learn the new syntax.


### Use contextmanagers
```python
import ROOT
from contextlib import contextmanager


def histogram():
    hist = ROOT.TH1F('test_hist', 'test', 100, -3, 3)
    hist.FillRandom("gaus")
    return hist


@contextmanager
def ropen(filename, option="read"):
    rfile = ROOT.TFile(filename, option)
    yield rfile
    rfile.Close()


if __name__ == '__main__':
    # Write
    with ropen("test.root", option="recreate"):
        ohist = histogram()
        original_entries = ohist.GetEntries()
        ohist.Write("test_hist")

    # ROOT removed the object after exiting file
    # NB and it's not None, but PyROOT_NoneTyp
    print(ohist)

    # Read
    with ropen("test.root", option="open") as f:
        hist = f.Get("test_hist")
        assert hist is not None
        assert hist.GetEntries() > 0
        assert original_entries == hist.GetEntries()

```


## Libraries
There is solid support of python versions of ROOT modules in [scikit-hep](https://github.com/scikit-hep/), the most commonly used are

| library |         |
|---------| ------- |
|[`rootpy`](https://github.com/rootpy/rootpy)| Most of the cases are covered here. It might not work in some environments, and docs are "still under construction".|
|[`uproot`](https://github.com/scikit-hep/uproot)| It handles some basic objects and there's no need to install ROOT library. It's very neat, but not useful (so far) if you have collections in your `*.root` files.|
|[`root_numpy`](https://github.com/scikit-hep/root_numpy)| Handy converters from `numpy.arrays` to various ROOT types . Requires `root` and sometimes may fail in nonstandard environments|
|[`root_pandas`](https://github.com/scikit-hep/root_pandas)| The same for pandas|
