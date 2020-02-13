# CERN's ROOT recipes [![Build Status](https://travis-ci.com/kqf/root-recipes.svg?branch=master)](https://travis-ci.com/kqf/root-recipes)

CERN's ROOT is a library for analyzing data, but sometimes it gets really difficult to make it work.
There are tons of [libraries, wrappers, and projects](#Libraries) for `PyROOT` intended to simplify your work.
This is a collection of hacks and recipes to be used when you **really** need to get things done and there's no option (or time) to install the environment, learn the new syntax.

## Table of Contents

- [Context managers](#use-contextmanagers)
- [Local histograms](#attributeerror-pyroot_nonetype-object-has-no-attribute)
- [Drawing with `PyROOT`](#drawing-a-canvas-with-pyroot)
- [Bottom panel plots](#how-to-draw-bottom-panel-ratio-plot)
- [`lru_cache`](#how-to-draw-lines-and-texts-caching-hack)
- [Defining colors (`lru_cache` v2)](#nice-looking-palette-from-seaborn-defining-colors)
- [Function overloading](#singledispatch)
- [Persistent cache `*`](#persistent-cache-joblib)

Sections marked with `*` require installation of additional libraries.

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
    yield canvas

    # Update the canvas before it's rendered
    canvas.Update()

    # Save the image first if needed
    if oname is not None:
        canvas.SaveAs(oname)

    # Don't interrupt the script flow
    if not stop:
        return
    # Run a TApplication, that listens to events, such as mouse clicks
    # exit when the canvas window is closed
    canvas.Connect("Closed()", "TApplication",
                   ROOT.gApplication, "Terminate()")
    ROOT.gApplication.Run(True)


def main():
    with canvas(stop=True, oname="test.pdf", xsize=760) as figure:
        figure.SetTickx()
        figure.SetTicky()
        figure.SetGridx()
        figure.SetGridy()

        hist1 = ROOT.TH1F("test1", "test 1; x (cm); counts", 100, -3, 3)
        hist1.FillRandom("gaus")
        hist1.SetStats(False)
        hist1.Draw()


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


def bipanel(top, bottom, xtitle, ttitle, btitle, stop=False, oname=None):
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
        top_hists.GetYaxis().SetTitle(ttitle)
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
        bottom_hists.GetYaxis().SetTitle(btitle)
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
    bipanel(
        top=[numerator, denominator],
        bottom=[fraction],
        xtitle="x distance (cm)",
        ttitle="counts",
        btitle="Data/Theory",
        oname="basic.pdf"
    )


if __name__ == '__main__':
    main()
```
It's a good starting point to create own layout. The main tricks are margins (to align the pads) and `THstack` configurations to adjust fonts. It turns out that `THstack` shares lots of properties with `TH1`, and axes can be configured using stacks (which is weird).
All "magic" numbers within the `bipanel` definition are indeed magic (don't change them unless you know what you are doing).

### How to draw lines and texts (caching hack)
There is an obvious issue with memory management for objects like `TText`, `TPaveText`, `TLatex` etc. The objects created inside the function are deleted once the function returns its value. Here is a simple solution
```python
import ROOT
# available since python3.3
from functools import lru_cache
# this works for python2 and python3
# from repoze.lru import lru_cache
from contextlib import contextmanager

# Remove the potential memory leak for histograms
ROOT.TH1.AddDirectory(False)


@contextmanager
def canvas(name="c1", stop=True, oname=None, xsize=580, ysize=760):
    canvas = ROOT.TCanvas(name, "canvas", xsize, ysize)
    canvas.SetTicks(1, 1)
    yield canvas
    canvas.Update()
    if oname is not None:
        canvas.SaveAs(oname)
    if not stop:
        return
    canvas.Connect("Closed()", "TApplication",
                   ROOT.gApplication, "Terminate()")
    ROOT.gApplication.Run(True)


@lru_cache(maxsize=1024)
def caption(text, coordinates=(0.68, 0.75, 0.88, 0.88)):
    x1, y1, x2, y2 = coordinates
    pave = ROOT.TPaveText(x1, y1, x2, y2, "NDC")
    pave.AddText(text)
    pave.SetMargin(0)
    pave.SetBorderSize(0)
    pave.SetFillStyle(0)
    pave.SetTextAlign(13)
    pave.SetTextFont(42)
    return pave


@lru_cache(maxsize=1024)
def vline(x, ymin, ymax):
    line = ROOT.TLine(x, ymin, x, ymax)
    line.SetLineColor(1)
    line.SetLineStyle(7)
    return line


def main():
    for i in [10000, 100000]:
        hist = ROOT.TH1F("test_{}", ";#it{x} (cm); counts", 1000, -3, 3)
        hist.FillRandom("gaus", i)
        hist.SetStats(False)
        with canvas():
            hist.Draw()
            caption("#it{{s}} = {}".format(i)).Draw()
            ymin, ymax = hist.GetMinimum(), hist.GetMaximum()
            vline(1, ymin=ymin, ymax=ymax).Draw()
            vline(-1, ymin=ymin, ymax=ymax).Draw()


if __name__ == '__main__':
    main()

```
The lines and text will disappear if one removes the decorators `@lru_cache(maxsize=1024)`. This code tells python to store the output of functions `vline` and `caption` in somewhere the memory of a program and it's released when the program ends. It's a hack since `lru_cache` is usually used to save some time while doing expensive computations. When called multiple times with the same parameters, the cached object will be returned. In this solution, such speedup is a rather useful side-effect. The `maxsize=1024` is just an arbitrary parameter if you have more than `1024` calls of the decorated function the object cached earlier will be deleted. It's quite improbable that someone will draw `1024` primitives on the same canvas, so the effect will not be noticed. For python2 users, there is an external library that can be installed with
```bash
pip install repoze.lru
```
It works with python3 as well and the interface is the same as for `functools`.

### Nice-looking palette from `seaborn` (defining colors)
Another hack possible with `lru_cache` is the definition of own colors. This particular example requires the installation of a `seaborn` library, but it can be replaced with hardcoded values as well. The color palettes in `ROOT` are not sequential. It's impossible to use just index in the for loop to get nice colors automatically
```python
import ROOT
import seaborn as sns
from contextlib import contextmanager
from functools import lru_cache


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


def frame(canvas, xmin, xmax, ymin, ymax):
    frame = canvas.GetFrame()
    frame = canvas.DrawFrame(xmin, ymin, xmax, ymax)
    frame.SetXTitle("#varphi")
    frame.GetXaxis().SetTitleOffset(1.2)
    frame.SetYTitle("#it{f} (#varphi)")
    frame.GetYaxis().SetTitleSize(0.04)
    frame.GetYaxis().SetTitleOffset(1.2)


@lru_cache(maxsize=1024)
def define_color(r, g, b, alpha=1):
    colorindex = ROOT.TColor.GetFreeColorIndex()
    color = ROOT.TColor(colorindex, r, g, b)
    return colorindex, color  # NB: TColor object is returned to be cached


def colors(palette="tab10", n=10):
    return [define_color(*p)[0] for p in sns.color_palette(palette, n)]


def main():
    functions = [
        ROOT.TF1("f{}".format(i),
                 "sin(x + {i} * .5) * (7 - {i})".format(i=i), 0, 14)
        for i in range(1, 7)
    ]
    with canvas() as figure:
        # Draw the common frame to fit all functions on the same plot
        frame(figure, xmin=0, xmax=14, ymin=-7, ymax=7)

        # Define colors
        cols = colors(n=len(functions))
        for col, function in zip(cols, functions):
            function.Draw("same")
            function.SetLineColor(col)
            function.SetLineWidth(3)


if __name__ == "__main__":
    main()
``` 
This code should be used for plotting only. The metadata (like color codes) are not stored in the `ROOT` files. This has some justification (saves up to `3 * 8` bytes! per primitive) in theory, but is pretty useless on practice. The objects that are saved with custom colors, will be transparent (why not some default colors?) after reading them in a new session/program call.

### Singledispatch
Python doesn't have function signatures and it's impossible to have two methods with the same name. This complicates the code that involves `ROOT` objects that quite often have inconsistent interfaces. There is a built-in (standard library) mechanism that allows method redefinition.
In this example, we want to define a dedicated `decorate` function that has a different impact on histograms and functions. Such a method allows the creation of the generic plotting functions that accept different types
```python
import ROOT
from contextlib import contextmanager
from functools import singledispatch


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


@singledispatch
def decorate(primitive):                                     # <<<<<<
    primitive.SetMarkerStyle(20)
    primitive.SetMarkerSize(1)
    primitive.SetMarkerColor(ROOT.kRed + 1)


@decorate.register(ROOT.TF1)                                 # <<<<<<
def _(primitive):
    primitive.SetLineWidth(2)
    primitive.SetLineStyle(9)
    primitive.SetLineColor(ROOT.kBlue + 1)


def plot(primitives, xtitle, ytitle, xlimits, ylimits):
    with canvas() as figure:
        figure.SetTicks(1, 1)
        frame = figure.GetFrame()
        xmin, xmax = xlimits
        ymin, ymax = ylimits
        frame = figure.DrawFrame(xmin, ymin, xmax, ymax)
        frame.SetXTitle(xtitle)
        frame.GetXaxis().SetTitleOffset(1.2)
        frame.SetYTitle(ytitle)
        frame.GetYaxis().SetTitleSize(0.04)
        frame.GetYaxis().SetTitleOffset(1.2)

        for primitive in primitives:
            decorate(primitive)                              # <<<<<<
            primitive.Draw("same")


def main():
    func = ROOT.TF1("func", "sin(x + 1.5) + 1", 0, 14)
    hist = ROOT.TH1F("hist", "test", 100, 0, 14)
    hist.FillRandom("func", 100000)
    hist.Scale(100. / hist.Integral())
    plot(
        [func, hist],
        xlimits=(0, 14),
        ylimits=(-1, 3),
        xtitle="#it{t} (seconds)",
        ytitle="#it{L} (#it{c} #tau)",
    )


if __name__ == "__main__":
    main()
```
There is a limitation with `singledispatch`. It works only for the first positional argument. For example `ratio(a, b)` requires the types for both parameters to be validated. This can be achieved with [multimethod](https://github.com/coady/multimethod) library that has a quite similar interface.

### Persistent cache (joblib)
Usually, if one needs to plot the results of heavy, CPU intensive and time-consuming computation one writes it in a separate `ROOT` file and then read this object each time they need to adjust the plot. This clutters the filesystem and it becomes difficult to track all those files
```python
import ROOT
import joblib

memory = joblib.Memory(location='.joblib-cache/', verbose=0)


@memory.cache()                                              # <<<<<<
def heavy_histogram(entries):
    print("Time consuming computation")                      # <<<<<<
    hist = ROOT.TH1F("cached", "hist", 100, 0, 100)
    hist.FillRandom("gaus", entries)
    return hist


def main():
    hist = heavy_histogram(entries=137)                      # <<<<<<
    print(hist.GetName(), hist.GetTitle(), hist.GetEntries())


if __name__ == "__main__":
    main()

```
The cache is calculated each time a new value is passed as an argument to the decorated function. To see the effect one needs to run the script multiple times:
```bash
# This time "Time-consuming computation" will be prompted
python script.py

# Second time the prompt will be missing. Joblib retrieves the cached object
python script.py
```
The downsides of this method is you need to remember that you are using the cache, and your package should be installed separately:
```bash
pip install joblib --user
```
The main difference between `lru_cache` and `joblib.Memory.cache` is that the first stores the results only in the program and the functions will be recalculated each time one starts a new program.


## Libraries
There is solid support of python versions of ROOT modules in [scikit-hep](https://github.com/scikit-hep/), the most commonly used are

| library |         |
|---------| ------- |
|[`rootpy`](https://github.com/rootpy/rootpy)| Most of the cases are covered here. It might not work in some environments, and docs are "still under construction".|
|[`uproot`](https://github.com/scikit-hep/uproot)| It handles some basic objects and there's no need to install ROOT library. It's very neat, but not useful (so far) if you have collections in your `*.root` files.|
|[`root_numpy`](https://github.com/scikit-hep/root_numpy)| Handy converters from `numpy.arrays` to various ROOT types . Requires `root` and sometimes may fail in nonstandard environments|
|[`root_pandas`](https://github.com/scikit-hep/root_pandas)| The same for pandas|
