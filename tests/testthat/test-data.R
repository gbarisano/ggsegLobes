describe("dklobes atlas", {
  atlas <- dklobes()

  it("is a ggseg_atlas", {
    expect_s3_class(atlas, "ggseg_atlas")
  })

  it("is valid", {
    expect_true(ggseg.formats::is_ggseg_atlas(atlas))
  })

  it("has five lobes per hemisphere", {
    regs <- ggseg.formats::atlas_regions(atlas)
    expect_true(all(c("frontal","parietal","temporal","occipital","insula") %in% regs))
  })
})

describe("dklobes rendering", {
  it("renders with ggseg", {
    skip_if_not_installed("ggseg")
    skip_if_not_installed("ggplot2")
    p <- ggplot2::ggplot() +
      ggseg::geom_brain(atlas = dklobes(),
                        mapping = ggplot2::aes(fill = region),
                        show.legend = FALSE)
    expect_s3_class(p, "ggplot")
  })
})
