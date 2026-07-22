# Lobar Parcellation Atlas

Cortical lobar parcellation (frontal, parietal, temporal, occipital, and
insula, per hemisphere) derived from the Desikan-Killiany atlas
([`ggseg::dk()`](https://ggsegverse.github.io/ggseg/reference/reexports.html))
by dissolving its cortical regions into lobes. Provides 2D polygon
geometry for use with
[`ggseg::geom_brain()`](https://ggsegverse.github.io/ggseg/reference/ggbrain.html).

## Usage

``` r
dklobes()
```

## Value

A
[ggseg.formats::ggseg_atlas](https://ggsegverse.github.io/ggseg.formats/reference/ggseg_atlas.html)
object (cortical).

## References

Desikan RS, et al. (2006). An automated labeling system for subdividing
the human cerebral cortex on MRI scans into gyral based regions of
interest. *NeuroImage*, 31(3):968-980.
[doi:10.1016/j.neuroimage.2006.01.021](https://doi.org/10.1016/j.neuroimage.2006.01.021)

## Examples

``` r
dklobes()
#> 
#> ── dklobes ggseg atlas ─────────────────────────────────────────────────────────
#> Type: cortical
#> Regions: 5
#> Hemispheres: left, right
#> Views: inferior, lateral, medial, superior
#> Palette: ✔
#> Rendering: ✔ ggseg
#> ✔ ggseg3d (vertices)
#> ────────────────────────────────────────────────────────────────────────────────
#>     hemi    region           label      lobe
#> 1   left   frontal    left frontal   frontal
#> 2   left    insula     left insula    insula
#> 3   left occipital  left occipital occipital
#> 4   left  parietal   left parietal  parietal
#> 5   left  temporal   left temporal  temporal
#> 6  right   frontal   right frontal   frontal
#> 7  right    insula    right insula    insula
#> 8  right occipital right occipital occipital
#> 9  right  parietal  right parietal  parietal
#> 10 right  temporal  right temporal  temporal
if (FALSE) plot(dklobes()) # \dontrun{}
```
