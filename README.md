# CERN's ROOT recipes [![Build Status](https://travis-ci.com/kqf/root-recipes.svg?branch=master)](https://travis-ci.com/kqf/root-recipes)

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
### Drawing a canvas with `PyROOT`
When drawing something with `PyROOT` it will not freeze, unless script flow is interrupted. This can be achieved with `input` or `raw_input`, but those are not the right tools. Here is the solution that relies on `ROOT`s ability to process events

```python
import ROOT
from contextlib import contextmanager


@contextmanager
def canvas(name="c1", stop=True, oname=None, xsize=580, ysize=760):
    canvas = ROOT.TCanvas(name, "canvas", xsize, ysize)
    # This is useless if you are making multiplots (like in example below)
    canvas.SetTickx()
    canvas.SetTicky()
    canvas.SetGridx()
    canvas.SetGridy()

    yield canvas
    # Update the canvas before it's rendered
    canvas.Update()

    # Save the image first if needed
    if oname is not None:
        canvas.SaveAs(oname)
    if not stop:
        return
    # Run a TApplication, that listens to events, such as mouse clicks
    # exit when the canvas window is closed
    canvas.Connect("Closed()", "TApplication",
                   ROOT.gApplication, "Terminate()")
    ROOT.gApplication.Run(True)


def main():
    with canvas(stop=True, oname="test.pdf", xsize=760) as figure:
        # Figure is just a normal TCanvas
        figure.Divide(2, 1)
        figure.cd(1)

        hist1 = ROOT.TH1F("test1", "test 1; x (cm); counts", 100, -3, 3)
        hist1.FillRandom("gaus")
        hist1.SetStats(False)
        hist1.Draw()

        figure.cd(2)
        hist2 = ROOT.TH1F("test2", "test 2; x (cm); counts", 100, -3, 3)
        hist2.FillRandom("gaus", 1000)
        hist2.SetStats(False)
        hist2.Draw()
        figure.cd()


if __name__ == "__main__":
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
