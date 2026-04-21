library(ggplot2)
library(dplyr)

# ── Data Frame Setup ─────────────────────────────────────────────────────────
df <- data.frame(
  variable = c(
    "Poor", "Middle", "Upper-middle", "Richest",
    "Primary", "Secondary", "Higher",
    "6–11 months", "12–23 months", "24–35 months", "36–47 months", "48–59 months",
    "Male",
    "Urban",
    "Diarrhoea", "Fever",
    "Electricity",
    "Media access"
  ),
  
  group = c(
    rep("Wealth Quintile\n(Ref: Poorest)", 4),
    rep("Mother's Education\n(Ref: No education)", 3),
    rep("Child Age Group\n(Ref: 0–5 months)", 5),
    rep("Child Sex\n(Ref: Female)", 1),
    rep("Residence\n(Ref: Rural)", 1),
    rep("Clinical Symptoms\n(Ref: No)", 2),
    rep("Environmental Factors\n(Ref: No)", 1),
    rep("Information Access\n(Ref: No)", 1)
  ),
  
  aOR = c(
    1.08, 0.93, 0.81, 1.36,
    1.15, 1.03, 0.83,
    0.83, 1.08, 0.81, 0.83, 0.90,
    1.01,
    0.91,
    0.54, 1.83,
    1.37,
    1.32
  ),
  
  lower = c(
    0.72, 0.61, 0.54, 0.82,
    0.72, 0.67, 0.51,
    0.53, 0.70, 0.53, 0.53, 0.53,
    0.79,
    0.65,
    0.40, 1.35,
    0.84,
    1.01
  ),
  
  upper = c(
    1.62, 1.43, 1.24, 2.27,
    1.82, 1.59, 1.36,
    1.29, 1.67, 1.24, 1.30, 1.52,
    1.28,
    1.28,
    0.73, 2.48,
    2.26,
    1.72
  ),
  
  pvalue = c(
    0.721, 0.752, 0.336, 0.231,
    0.561, 0.894, 0.468,
    0.396, 0.717, 0.335, 0.409, 0.687,
    0.967,
    0.590,
    0.000, 0.000,
    0.208,
    0.045
  )
)

# ── Derived columns ───────────────────────────────────────────────────────────
df <- df %>%
  mutate(
    significant = pvalue < 0.05,
    label = sprintf("%.2f (%.2f–%.2f)", aOR, lower, upper),
    variable = factor(variable, levels = rev(unique(variable)))
  )

# Group order for faceting
group_order <- c(
  "Wealth Quintile\n(Ref: Poorest)",
  "Mother's Education\n(Ref: No education)",
  "Child Age Group\n(Ref: 0–5 months)",
  "Child Sex\n(Ref: Female)",
  "Residence\n(Ref: Rural)",
  "Clinical Symptoms\n(Ref: No)",
  "Environmental Factors\n(Ref: No)",
  "Information Access\n(Ref: No)"
)

df$group <- factor(df$group, levels = group_order)

# ── Forest Plot ──────────────────────────────────────────────────────────────
ggplot(df, aes(x = aOR, y = variable, color = significant)) +
  
  geom_vline(xintercept = 1, linetype = "dashed", color = "grey50", linewidth = 0.5) +
  geom_linerange(aes(xmin = lower, xmax = upper), linewidth = 0.7) +
  geom_point(aes(shape = significant), size = 3) +
  geom_text(aes(x = 3.5, label = label), hjust = 0, size = 3, color = "black") +
  
  facet_grid(group ~ ., scales = "free_y", space = "free_y", switch = "y") +
  
  scale_color_manual(
    values = c("TRUE" = "#c0392b", "FALSE" = "#2c3e50"),
    labels = c("TRUE" = "p < 0.05", "FALSE" = "p \u2265 0.05"),
    name = "Significance"
  ) +
  scale_shape_manual(
    values = c("TRUE" = 18, "FALSE" = 16),
    labels = c("TRUE" = "p < 0.05", "FALSE" = "p \u2265 0.05"),
    name = "Significance"
  ) +
  
  scale_x_log10(
    breaks = c(0.25, 0.5, 1, 2, 4),
    labels = c("0.25", "0.5", "1", "2", "4"),
    limits = c(0.25, 4.5)
  ) +
  
  labs(
    title = "Factors Associated with Informal Antibiotic Use Among Children Under 5 Years in Bangladesh",
    subtitle = "Adjusted Odds Ratios from Multivariable Logistic Regression",
    x = "Adjusted Odds Ratio (log scale)",
    y = NULL,
    caption = "Error bars represent 95% confidence intervals.\nDiamond (red) = statistically significant (p < 0.05).\nAdjusted for wealth, mother's education, child age, sex, residence, diarrhoea, fever, electricity, and media access."
  ) +
  
  theme_bw(base_size = 10) +
  theme(
    strip.placement = "outside",
    strip.text.y.left = element_text(angle = 0, hjust = 1, size = 9,
                                     face = "bold", color = "#2c3e50"),
    strip.background = element_rect(fill = "#ecf0f1", color = NA),
    panel.grid.major.y = element_blank(),
    panel.grid.minor = element_blank(),
    panel.spacing = unit(0.3, "lines"),
    legend.position = "bottom",
    plot.title = element_text(face = "bold", size = 12, hjust = 0.5),
    plot.subtitle = element_text(size = 10, hjust = 0.5),
    plot.caption = element_text(color = "grey40", size = 7),
    axis.text.y = element_text(size = 9),
    plot.margin = margin(t = 10, r = 10, b = 10, l = 220)
  )

# ── Save and Output ──────────────────────────────────────────────────────────
ggsave("forest_plot.png", width = 12, height = 10, dpi = 300)

cat("\n--- Group Counts ---\n")
print(table(df$group))
cat("\n--- Significant Variables ---\n")
print(df[df$significant, c("variable", "aOR", "lower", "upper", "pvalue")])