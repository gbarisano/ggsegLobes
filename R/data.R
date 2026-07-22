#' Lobar Parcellation Atlas
#'
#' Cortical lobar parcellation (frontal, parietal, temporal, occipital, and
#' insula, per hemisphere) derived from the Desikan-Killiany atlas
#' ([ggseg::dk()]) by dissolving its cortical regions into lobes. Provides 2D
#' polygon geometry for use with [ggseg::geom_brain()].
#'
#' @family ggseg_atlases
#' @family cortical_atlases
#'
#' @references
#'   Desikan RS, et al. (2006). An automated labeling system for subdividing
#'   the human cerebral cortex on MRI scans into gyral based regions of
#'   interest. *NeuroImage*, 31(3):968-980.
#'   \doi{10.1016/j.neuroimage.2006.01.021}
#'
#' @return A [ggseg.formats::ggseg_atlas] object (cortical).
#' @export
#' @examples
#' dklobes()
#' \dontrun{plot(dklobes())}
dklobes <- function() .dklobes
