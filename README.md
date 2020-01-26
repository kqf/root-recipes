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
### How to draw bottom panel (ratio plot)
The best (simplest) option is to draw two separate plots on two separate canvases and never split a canvas into several parts. However, such necessity might occur in real life.
Here is the code that does this:
```python
import ROOT
from contextlib import contextmanager


@contextmanager
def canvas(name="c1", stop=True, oname=None, xsize=580, ysize=760):
    canvas = ROOT.TCanvas(name, "canvas", xsize, ysize)
    yield canvas
    canvas.Update()
    if oname is not None:
        canvas.SaveAs(oname)
    if not stop:
        return
    canvas.Connect("Closed()", "TApplication",
                   ROOT.gApplication, "Terminate()")
    ROOT.gApplication.Run(True)


def panelplot(top, bottom, xtitle, ytitlet, ytitleb, stop=False, oname=None):
    with canvas() as figure:
        figure.SetMargin(0.1, 0.05, 0.12, 0.05)
        figure.Divide(1, 2, 0, 0)

        top_pad = figure.cd(1)
        top_pad.SetPad(0, 0.3, 1, 1)  # (x0, y0, x1, y1)
        top_pad.SetMargin(0.1, 0.05, 0.0, 0.05)  # (left, right, bottom, top)
        top_pad.SetTicks(1, 1)

        top_hists = ROOT.THStack()
        for hist in top:
            top_hists.Add(hist)
        top_hists.Draw("nostack")
        top_hists.GetXaxis().SetTitle(xtitle)
        top_hists.GetXaxis().SetTitleOffset(1.2)
        top_hists.GetXaxis().SetMoreLogLabels(True)
        top_hists.GetYaxis().SetTitle(ytitlet)
        top_hists.GetYaxis().SetTitleSize(0.04)
        top_hists.GetYaxis().SetTitleOffset(1.2)

        bottom_pad = figure.cd(2)
        bottom_pad.SetPad(0, 0, 1, 0.3)
        bottom_pad.SetMargin(0.1, 0.05, 0.2, 0.0)  # (left, right, bottom, top)
        bottom_pad.SetTicks(1, 1)

        bottom_hists = ROOT.THStack()
        for hist in bottom:
            bottom_hists.Add(hist)
        bottom_hists.Draw("nostack")
        bottom_hists.GetXaxis().SetTitle(xtitle)
        bottom_hists.GetXaxis().SetTitleOffset(1.2)
        bottom_hists.GetXaxis().SetMoreLogLabels(True)
        bottom_hists.GetXaxis().SetTitleSize(0.08)
        bottom_hists.GetXaxis().SetLabelSize(0.08)
        bottom_hists.GetYaxis().SetTitle(ytitleb)
        bottom_hists.GetYaxis().SetTitleSize(0.04)
        bottom_hists.GetYaxis().SetTitleOffset(1.2)
        bottom_hists.GetYaxis().SetTitleOffset(0.5)
        bottom_hists.GetYaxis().SetTitleSize(0.08)
        bottom_hists.GetYaxis().SetLabelSize(0.08)
        bottom_hists.GetYaxis().CenterTitle()


def main():
    # This function is needed just to generate inputs
    def hist(name, npoints=1000):
        hist = ROOT.TH1F(name, "{}; x (cm); counts".format(name), 100, -3, 3)
        hist.FillRandom("gaus", npoints)
        hist.SetStats(False)
        return hist

    numerator = hist("numerator")
    numerator.SetLineColor(ROOT.kRed + 1)

    denominator = hist("denominator")
    denominator.SetLineColor(ROOT.kBlue + 1)

    fraction = numerator.Clone()
    fraction.Divide(denominator)
    panelplot(
        top=[numerator, denominator],
        bottom=[fraction],
        xtitle="x distance (cm)",
        ytitlet="counts",
        ytitleb="Data/Theory",
        oname="basic.pdf"
    )


if __name__ == '__main__':
    main()
```
It's a good starting point to create own layout. The main tricks are margins (to align the pads) and `THstack` configurations to adjust fonts. It turns out that `THstack` shares lots of properties with `TH1`, and axes can be configured using stacks (which is weird).
All "magic" numbers within the `panelplot` definition are indeed magic (don't change them unless you know what you are doing).

## Libraries
There is solid support of python versions of ROOT modules in [scikit-hep](https://github.com/scikit-hep/), the most commonly used are

| library |         |
|---------| ------- |
|[`rootpy`](https://github.com/rootpy/rootpy)| Most of the cases are covered here. It might not work in some environments, and docs are "still under construction".|
|[`uproot`](https://github.com/scikit-hep/uproot)| It handles some basic objects and there's no need to install ROOT library. It's very neat, but not useful (so far) if you have collections in your `*.root` files.|
|[`root_numpy`](https://github.com/scikit-hep/root_numpy)| Handy converters from `numpy.arrays` to various ROOT types . Requires `root` and sometimes may fail in nonstandard environments|
|[`root_pandas`](https://github.com/scikit-hep/root_pandas)| The same for pandas|
