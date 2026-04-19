library(ggplot2)
library(dplyr)

# Count each item explicitly:
# Wealth: Poor, Middle, Upper-middle, Richest = 4
# Mother Ed: Primary, Secondary, Higher = 3  
# Child Age: 6-11, 12-23, 24-35, 36-47, 48-59 = 5 (NOT 6!)
# Wait - child age has 5 categories, not 6! Let me check your table...

# From your PDF table, child age groups are:
# 6-11 months, 12-23 months, 24-35 months, 36-47 months, 48-59 months
# That's 5 categories (0-5 is the reference, not included)

# Let me recount properly:
# Wealth: 4 items
# Mother Ed: 3 items
# Child Age: 5 items (6-11, 12-23, 24-35, 36-47, 48-59)
# Child Sex: 1 item
# Residence: 1 item
# Diarrhoea: 1 item
# Fever: 1 item
# Electricity: 1 item
# Media access: 1 item
# TOTAL = 4+3+5+1+1+1+1+1+1 = 18

# So you need 18 values for each vector, NOT 19!

df <- data.frame(
  variable = c(
    # Wealth Quintile (Ref: Poorest) - 4 items
    "Poor", "Middle", "Upper-middle", "Richest",
    # Mother's Education (Ref: No education) - 3 items
    "Primary", "Secondary", "Higher",
    # Child Age Group (Ref: 0-5 months) - 5 items
    "6–11 months", "12–23 months", "24–35 months", "36–47 months", "48–59 months",
    # Child Sex (Ref: Female) - 1 item
    "Male",
    # Residence (Ref: Rural) - 1 item
    "Urban",
    # Clinical symptoms (Ref: No) - 2 items
    "Diarrhoea", "Fever",
    # Environmental Factors (Ref: No) - 1 item
    "Electricity",
    # Information Access (Ref: No) - 1 item
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
  
  # AOR values - EXACTLY 18 VALUES
  aOR = c(
    1.08, 0.93, 0.81, 1.36,  # Wealth (4)
    1.15, 1.03, 0.83,        # Mother education (3)
    0.83, 1.08, 0.81, 0.83, 0.90,  # Child age (5)
    1.01,                     # Male (1)
    0.91,                     # Urban (1)
    0.54, 1.83,               # Diarrhoea, Fever (2)
    1.37,                     # Electricity (1)
    1.32                      # Media access (1)
  ),
  
  # Lower CI - EXACTLY 18 VALUES
  lower = c(
    0.72, 0.61, 0.54, 0.82,   # Wealth (4)
    0.72, 0.67, 0.51,         # Mother education (3)
    0.53, 0.70, 0.53, 0.53, 0.53,  # Child age (5)
    0.79,                     # Male (1)
    0.65,                     # Urban (1)
    0.40, 1.35,               # Diarrhoea, Fever (2)
    0.84,                     # Electricity (1)
    1.01                      # Media access (1)
  ),
  
  # Upper CI - EXACTLY 18 VALUES
  upper = c(
    1.62, 1.43, 1.24, 2.27,   # Wealth (4)
    1.82, 1.59, 1.36,         # Mother education (3)
    1.29, 1.67, 1.24, 1.30, 1.52,  # Child age (5)
    1.28,                     # Male (1)
    1.28,                     # Urban (1)
    0.73, 2.48,               # Diarrhoea, Fever (2)
    2.26,                     # Electricity (1)
    1.72                      # Media access (1)
  ),
  
  # P-values - EXACTLY 18 VALUES
  pvalue = c(
    0.721, 0.752, 0.336, 0.231,  # Wealth (4)
    0.561, 0.894, 0.468,         # Mother education (3)
    0.396, 0.717, 0.335, 0.409, 0.687,  # Child age (5)
    0.967,                       # Male (1)
    0.590,                       # Urban (1)
    0.000, 0.000,                # Diarrhoea, Fever (2)
    0.208,                       # Electricity (1)
    0.045                        # Media access (1)
  )
)

# Verify row count
cat("Total number of rows:", nrow(df), "\n")
cat("Expected: 18\n")
cat("Variable count:", length(df$variable), "\n")
cat("AOR count:", length(df$aOR), "\n")

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
  
  # Reference line
  geom_vline(xintercept = 1, linetype = "dashed", color = "grey50", linewidth = 0.5) +
  
  # Confidence interval lines
  geom_linerange(aes(xmin = lower, xmax = upper), linewidth = 0.7) +
  
  # Point estimates
  geom_point(aes(shape = significant), size = 3) +
  
  # aOR labels to the right
  geom_text(aes(x = 3.5, label = label), hjust = 0, size = 3, color = "black") +
  
  # Facet by variable group
  facet_grid(group ~ ., scales = "free_y", space = "free_y", switch = "y") +
  
  # Color & shape scales
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
  
  # x-axis on log scale
  scale_x_log10(
    breaks = c(0.25, 0.5, 1, 2, 4),
    labels = c("0.25", "0.5", "1", "2", "4"),
    limits = c(0.25, 4.5)
  ) +
  
  # Labels
  labs(
    title = "Factors Associated with Informal Antibiotic Use Among Children Under 5 Years in Bangladesh",
    subtitle = "Adjusted Odds Ratios from Multivariable Logistic Regression",
    x = "Adjusted Odds Ratio (log scale)",
    y = NULL,
    caption = "Error bars represent 95% confidence intervals.\nDiamond (red) = statistically significant (p < 0.05).\nAdjusted for wealth, mother's education, child age, sex, residence, diarrhoea, fever, electricity, and media access."
  ) +
  
  # Theme
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

# ── Save ──────────────────────────────────────────────────────────────────────
ggsave("forest_plot.png", width = 12, height = 10, dpi = 300)

# Print verification
cat("\n--- Group Counts ---\n")
print(table(df$group))
cat("\n--- Significant Variables ---\n")
print(df[df$significant, c("variable", "aOR", "lower", "upper", "pvalue")])