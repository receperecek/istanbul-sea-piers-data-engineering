"""Render portable figures from the checked Databricks notebook result extracts."""

import csv
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.ticker import FuncFormatter


ROOT = Path(__file__).resolve().parent
RESULTS = ROOT / "results"
CHARTS = ROOT / "charts"
CHARTS.mkdir(exist_ok=True)


def read_rows(name):
    with (RESULTS / name).open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def style(ax):
    ax.spines[["top", "right"]].set_visible(False)
    ax.grid(axis="y", color="#dddddd", linewidth=0.7)
    ax.set_axisbelow(True)
    ax.yaxis.set_major_formatter(FuncFormatter(lambda value, _: f"{value / 1_000_000:g}m"))
    ax.set_xticks(range(1, 13))
    ax.set_xlim(0.5, 12.5)


monthly = read_rows("monthly_2021_2025.csv")
by_year = {year: [] for year in range(2021, 2026)}
for row in monthly:
    by_year[int(row["yil"])].append((int(row["ay"]), int(row["yolcu_sayisi_toplami"])))

fig, ax = plt.subplots(figsize=(10, 5.2))
colors = ["#a6bddb", "#6baed6", "#3182bd", "#08519c", "#e6550d"]
for (year, points), color in zip(by_year.items(), colors):
    points.sort()
    ax.plot([month for month, _ in points], [value for _, value in points],
            marker="o", linewidth=2.2, markersize=4, color=color, label=str(year))
style(ax)
ax.set_title("Istanbul sea pier journeys by month, 2021–2025", loc="left", fontsize=15)
ax.set_xlabel("Month")
ax.set_ylabel("Published journeys (millions)")
ax.legend(ncol=5, frameon=False, loc="upper center", bbox_to_anchor=(0.5, -0.16))
fig.text(0.11, 0.01, "2025 Oct–Dec: one authority has no source records; missing does not mean zero.", fontsize=9, color="#555555")
fig.tight_layout(rect=(0, 0.06, 1, 1))
fig.savefig(CHARTS / "monthly_journeys_2021_2025.svg", bbox_inches="tight")
fig.savefig(CHARTS / "monthly_journeys_2021_2025.png", dpi=150, bbox_inches="tight")
plt.close(fig)


comparison = read_rows("monthly_comparison_2024_2025.csv")
months = [int(row["ay"]) for row in comparison]
differences = [int(row["fark"]) for row in comparison]
fig, ax = plt.subplots(figsize=(10, 5))
ax.bar(months, differences, color=["#27806a" if value >= 0 else "#c2554d" for value in differences], width=0.7)
style(ax)
ax.axhline(0, color="#333333", linewidth=0.8)
ax.set_title("Monthly difference in published journeys: 2025 minus 2024", loc="left", fontsize=15)
ax.set_xlabel("Month")
ax.set_ylabel("Journey difference (millions)")
fig.text(0.11, 0.01, "Oct–Dec: 2025 has records from 7 authorities versus 8 in 2024.", fontsize=9, color="#555555")
fig.tight_layout(rect=(0, 0.06, 1, 1))
fig.savefig(CHARTS / "monthly_difference_2024_2025.svg", bbox_inches="tight")
fig.savefig(CHARTS / "monthly_difference_2024_2025.png", dpi=150, bbox_inches="tight")
plt.close(fig)
