# Generate the hex-sticker logo + favicons for ggsegLobes (left lateral view)
# Run from package root: Rscript data-raw/make_logo.R
# Requires: hexSticker, ggseg, ggplot2, ggsegLobes, ggseg.formats, sf, dplyr, pkgdown

library(hexSticker)
library(ggseg)
library(ggplot2)
library(ggsegLobes)
library(dplyr)
library(sf)

sf::sf_use_s2(FALSE)

atlas <- dklobes()

# geometry -> sf; the geom carries `label` ("left frontal") and `view`
g_sf <- ggseg.formats:::polygons_to_sf(atlas$data$geom)

# left hemisphere, lateral view only
g_left_lat <- g_sf |>
  dplyr::filter(grepl("left", label), view == "lateral")

# palette is keyed by label; fill = label keeps the original colours
p <- ggplot(g_left_lat) +
  geom_sf(aes(fill = label), colour = NA, show.legend = FALSE) +
  scale_fill_manual(values = atlas$palette, na.value = "grey") +
  theme_void()

dir.create("man/figures", recursive = TRUE, showWarnings = FALSE)

sticker(
  p,
  package  = "ggsegLobes",
  p_size   = 18, p_y = 0.6, p_color = "black",
  s_x = 1, s_y = 1.2, s_width = 1.4, s_height = 1.1,
  h_fill = "transparent",
  h_color = "black",
  filename = "man/figures/logo.png"
)

pkgdown::build_favicons(overwrite = TRUE)
