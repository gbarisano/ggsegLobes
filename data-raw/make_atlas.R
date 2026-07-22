# Build the ggsegLobes atlas: lobar parcellation derived from ggseg::dk()
# by dissolving cortical regions into frontal / parietal / temporal /
# occipital / insula, per hemisphere.
#
# Run from package root: Rscript data-raw/make_atlas.R
# Requires: ggseg, ggseg.formats, dplyr, sf, tibble, usethis
#
# NOTE: uses a few unexported ggseg.formats internals (:::) to convert between
# the brain_polygons storage format and sf. This is a one-time build step; the
# shipped package stores only the resulting object and never calls these at
# runtime.

library(ggseg)
library(ggseg.formats)
library(dplyr)
library(sf)
library(smoothr)

# CRITICAL: brain coordinates are planar, not spherical. Without this, s2
# treats x/y as lon/lat and produces spikes/slivers across the shapes.
sf::sf_use_s2(FALSE)

# helper: drop interior holes, keeping only exterior ring(s)
fill_holes <- function(g) {
  sf::st_sfc(lapply(sf::st_geometry(g), function(geom) {
    if (sf::st_is(geom, "POLYGON")) {
      sf::st_polygon(geom[1])
    } else if (sf::st_is(geom, "MULTIPOLYGON")) {
      sf::st_multipolygon(lapply(geom, function(p) p[1]))
    } else geom
  }), crs = sf::st_crs(g))
}

# ---- 1. dk geometry as a flat sf -------------------------------------------
dk_atlas <- ggseg::dk()
geom <- ggseg.formats:::polygons_to_sf(dk_atlas$data$geom)  # brain_polygons -> sf

# make sure region / hemi / view columns exist
if (!"region" %in% names(geom)) geom$region <- sub("^[lr]h[_-]?", "", geom$label)
if (!"hemi"   %in% names(geom)) geom$hemi   <- ifelse(grepl("^lh", geom$label), "left", "right")
# dk carries a lateral/medial column; detect its name
view_col <- intersect(c("view", "side"), names(geom))
stopifnot(length(view_col) == 1)

# ---- 2. lobe membership (by region name; edit as needed) -------------------
# Mirrors the original mapping: isthmus cingulate -> parietal; precuneus and
# supramarginal -> parietal; all other cingulate -> frontal; insula separate.
frontal <- c("caudalanteriorcingulate","caudalmiddlefrontal","frontalpole",
             "lateralorbitofrontal","medialorbitofrontal","paracentral",
             "parsopercularis","parsorbitalis","parstriangularis","precentral",
             "rostralanteriorcingulate","rostralmiddlefrontal","superiorfrontal",
             "posteriorcingulate")
parietal <- c("inferiorparietal","isthmuscingulate","postcentral","precuneus",
              "superiorparietal","supramarginal")
occipital <- c("cuneus","lateraloccipital","lingual","pericalcarine")
temporal <- c("bankssts","entorhinal","fusiform","inferiortemporal",
              "middletemporal","parahippocampal","superiortemporal",
              "temporalpole","transversetemporal")
insula <- c("insula")

lobe_map <- dplyr::bind_rows(
  data.frame(region = frontal,   lobe = "frontal"),
  data.frame(region = parietal,  lobe = "parietal"),
  data.frame(region = occipital, lobe = "occipital"),
  data.frame(region = temporal,  lobe = "temporal"),
  data.frame(region = insula,    lobe = "insula")
)

# ---- 3. join + drop non-cortex (callosum / unknown / medial wall) ----------
geom <- geom |>
  dplyr::left_join(lobe_map, by = "region") |>
  dplyr::mutate(
    lobe = ifelse(is.na(lobe) | grepl("callosum|unknown|medialwall", region), NA, lobe)
  ) |>
  dplyr::filter(!is.na(lobe)) |>
  dplyr::mutate(label = paste(hemi, lobe))

# ---- 4. repair inputs, then dissolve WITHIN hemi + view + lobe -------------
# Keeping `view` separate is essential: lateral and medial outlines of the
# same lobe must NOT be unioned into one polygon (that causes cross-spikes).
geom <- sf::st_make_valid(geom)

lobes_sf <- geom |>
  dplyr::group_by(hemi, .data[[view_col]], region = lobe, label) |>
  dplyr::summarise(geometry = sf::st_union(geometry), .groups = "drop") |>
  sf::st_make_valid()

# --- make each lobe homogeneous: close micro-gaps, then fill interior holes ---
# morphological closing (buffer out then in) seals hairline cracks between the
# merged DK regions; fill_holes removes enclosed voids. Tune `gap` to taste.
gap <- 1
sf::st_geometry(lobes_sf) <- lobes_sf |>
  sf::st_buffer(gap) |>
  sf::st_buffer(-gap) |>
  sf::st_geometry()
sf::st_geometry(lobes_sf) <- fill_holes(lobes_sf)
lobes_sf <- sf::st_make_valid(lobes_sf)

# --- simplify to reduce vertices (curvilinear, less zig-zag), then lightly
#     smooth the remaining corners. preserveTopology keeps shared edges intact.
lobes_sf <- sf::st_simplify(lobes_sf, dTolerance = 1, preserveTopology = TRUE)
lobes_sf <- smoothr::smooth(lobes_sf, method = "ksmooth", smoothness = 2)
lobes_sf <- sf::st_make_valid(lobes_sf)


# restore the view column name that group_by/summarise kept
names(lobes_sf)[names(lobes_sf) == view_col] <- view_col

# ---- 5. rebuild atlas data from the dissolved sf ---------------------------
new_data <- ggseg.formats:::rebuild_atlas_data(dk_atlas, lobes_sf)

dklobes <- dk_atlas
dklobes$atlas <- "dklobes"
dklobes$data  <- new_data
# ensure geom is stored as brain_polygons
if (!inherits(dklobes$data$geom, "brain_polygons"))
  dklobes$data$geom <- ggseg.formats:::sf_to_polygons(dklobes$data$geom)

# core: one row per hemi x lobe (bilateral region name in `region`)
core_tbl <- lobes_sf |>
  sf::st_drop_geometry() |>
  dplyr::distinct(hemi, region, label) |>
  dplyr::mutate(lobe = region)
dklobes$core <- tibble::as_tibble(core_tbl)

# ---- 3D vertices: pool dk's per-region surface vertex indices per lobe ------
# A cortical atlas stores 3D as vertex indices into the shared surface (not
# meshes). We build the lobe vertices by concatenating the dk regions' indices
# within each hemi + lobe. This is what makes ggseg3d able to render dklobes().
vd <- ggseg.formats::atlas_vertices(dk_atlas)   # label, vertices(list), hemi, region, (lobe), colour

# NOTE: atlas_vertices()'s `region` values may be full names ("banks of superior
# temporal sulcus") rather than the short dk keys ("bankssts") that lobe_map uses.
# Match on whichever aligns; here we strip to the short key if needed.
# Derive the SHORT dk key from `label` (e.g. "lh_superiorfrontal" -> "superiorfrontal");
# the vertex table's own `region` column may hold long names that don't match lobe_map.
vd$key <- sub("^[lr]h[_-]?", "", vd$label)

# fail loudly if any lobe_map region has no matching dk key (would drop vertices -> grey)
unmatched <- setdiff(lobe_map$region, unique(vd$key))
if (length(unmatched))
  stop("lobe_map regions not found in dk vertex keys: ", paste(unmatched, collapse=", "))

lobe_vertices <- vd |>
  dplyr::left_join(dplyr::rename(lobe_map, lobe_assign = lobe),
                   by = c("key" = "region")) |>
  dplyr::filter(!is.na(lobe_assign),
                !grepl("callosum|unknown|medialwall", key)) |>
  dplyr::mutate(label = paste(hemi, lobe_assign)) |>
  dplyr::group_by(hemi, region = lobe_assign, label) |>
  dplyr::summarise(vertices = list(sort(unique(unlist(vertices)))), .groups = "drop")

# coverage check: pooled vertices should approach dk's cortical total
message("pooled vertices: ", sum(lengths(lobe_vertices$vertices)),
        " / dk total: ", sum(lengths(vd$vertices)))

# order the vertices tibble to match the geom labels, keep just label + vertices
vtab <- tibble::tibble(label = unique(dklobes$data$geom$label)) |>
  dplyr::left_join(dplyr::select(lobe_vertices, label, vertices), by = "label")
dklobes$data$vertices <- vtab

# palette keyed by label (5 lobes, repeated per hemisphere)
lobe_cols <- c(frontal = "#4477AA", parietal = "#66CCEE", temporal = "#CCBB44",
               occipital = "#228833", insula = "#EE6677")
dklobes$palette <- setNames(lobe_cols[dklobes$core$region], dklobes$core$label)

# ---- 6. validate + inspect -------------------------------------------------
stopifnot(ggseg.formats::is_ggseg_atlas(dklobes))
print(ggseg.formats::atlas_regions(dklobes))

# 2D
plot(dklobes)

# 3D check (requires ggseg3d): every lobe should have pooled vertices
stopifnot(all(lengths(dklobes$data$vertices$vertices) > 0))
# ggseg3d::ggseg3d(atlas = dklobes) |> ggseg3d::pan_camera("left lateral")

# ---- 7. save as internal data ----------------------------------------------
.dklobes <- dklobes
usethis::use_data(.dklobes, internal = TRUE, overwrite = TRUE)
