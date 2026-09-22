# Evolving Superformulas

**Miguel Antunes** — PCIA, MIA, Universidade de Coimbra

## 1. Overview

I adapted the *Evolving Harmonographs* tutorial to evolve **Superformula** (Gielis) curves instead, in
both evolution modes: **step 10**, automatic evolution against a target image, and **step 11**,
interactive evolution driven by my own ratings. Roulette selection was required; the recombination and
mutation operators were my choice. Both modes share the same genotype and mapping, so an individual
evolved in one is exactly representable in the other — I use step 11 to author targets that step 10
then tries to rediscover.

## 2. Representation

Each individual draws `num_layers` nested Superformula curves. A curve needs six parameters
(*a*, *b*, *m*, *n1*, *n2*, *n3*), to which I added a seventh, **size**, so that how much of the canvas
a layer fills is evolvable rather than fixed.

Genes are normalised in **[0, 1]** and each parameter's real range is applied only in the mapping, so
crossover and mutation never need to know what a gene means. Ranges are restricted only where a value
would be invalid or degenerate: *a*, *b* ∈ [0.1, 5] (0 divides), *n1*, *n2*, *n3* ∈ [0.1, 20] (the
−1/*n1* exponent), *m* an integer in [1, 21] (a non-integer never closes the curve), size ∈ [0.1, 1].
Everything else is left to the fitness function rather than to my guess about which shapes look good.

Layers use a **base + step** encoding: 7 base values and 7 per-layer deltas, with layer *i* taking
`base + i · step / (num_layers − 1)`. This gives **14 genes** regardless of layer count and keeps layers
visually related, which is what makes the nested drawing read as one object. Its cost is high
pleiotropy — one step gene affects every layer — and a forced *linear* progression across layers. The
layer count is a matching constraint rather than a tuned parameter: I set it to the target's.

## 3. Fitness function (step 10)

My first fitness function was RMSE. On thin targets it converged to a **blank canvas** with high
fitness: at ~3.5% ink, matching the 96.5% of white pixels scores better than any honest attempt. RMSE
rewards the background.

I replaced it with a **multi-scale Dice coefficient**. Dice is 2·TP / (2·TP + FP + FN) — it has no
true-negative term, so a blank canvas scores 0 however sparse the target is. It is computed on binarised
ink maps (threshold 0.02) at four block sizes **{1, 2, 4, 8}**, using the 2Σab / (Σa² + Σb²) form so that
pooled non-binary values still score exactly 1 on an equal match.

The pyramid matters because full-resolution Dice is a **needle in a haystack**: a candidate missing by
three pixels scores 0, exactly like one that overlaps nowhere, so there is no gradient to climb. The
coarse levels are tolerant of position and turn that needle into a basin of attraction, rewarding
*roughly* the right ink in *roughly* the right place — a signal the GA can follow before it has anything
precise to refine.

Weighting the levels equally proved to be a mistake. Between generations 51 and 100 of one run the
full-resolution score *fell* (0.484 → 0.471) while the total still rose: the GA was selling pixel
accuracy to buy cheaper gains at 4×4 and 8×8, which had little headroom left anyway. Weighting by 1/*k*
— **{1, 0.5, 0.25, 0.125}**, normalised by their sum — reverses that ranking.

I also rejected a weighted confusion matrix: since TP + FN and TN + FP are both fixed by the target, any
four-weight scheme collapses to TP − λ·FP, and on a sparse target a blank canvas again beats a decent
attempt — the RMSE failure in different clothing.

## 4. Selection

**Roulette** (required) on raw fitness fails here, because Dice has a high floor: a population spanning
0.45–0.46 gives every individual nearly the same slice and selection becomes uniformly random. I kept
the wheel but spun it on **linear ranking** weights, w(i) = (2 − sp) + 2(sp − 1)(n − 1 − i)/(n − 1) with
sp = 1.8. The weights average 1, so they sum to *n* and each weight *is* that individual's expected
number of offspring — the wheel stops depending on the absolute scale of the fitness values. I rejected
windowing (subtracting the worst fitness) because it over-amplifies once the spread is small: 0.46
against 0.45 becomes 0.01 against 0, handing the wheel to one individual.

Ranking alone was not enough, for reasons in §6. I added **survivor selection** by restricting the wheel
to the best **μ = 50** of the sorted population, turning the generational loop into a (μ, λ) strategy at
no extra evaluation cost. Linear ranking at sp = 1.8 has selection intensity (sp − 1)/√π ≈ 0.45;
truncating at 50% contributes a further ≈0.80. Sweeping μ, 20 and 30 converged prematurely while 50
held diversity and still climbed.

In **step 11** the same wheel needs different semantics, because fitness 0 there means *not rated*, not
*bad*. An unrated individual gets `unrated_weight = 0.1` of a slice rather than 0. With 30 individuals
on screen I can genuinely look at all of them, so unrated is close to rejected — but not identical, and
a hard 0 is degenerate: if only one individual is rated, BLX-α between it and itself makes the whole
next generation a copy of it.

## 5. Recombination (both modes)

**Paired BLX-α.** One mixing fraction is drawn in [−α, 1 + α] per (base, step) *pair* and used for both
genes, so a child inherits a layer progression lying between its parents' rather than one parent's base
glued to the other's step. Out-of-range results are **reflected**, not clamped, to avoid piling
probability mass on 0 and 1.

α has a lower bound: child variance is v/2 + (1 + 2α)²·v/6, so **α ≥ 0.366** is required or the operator
contracts population variance by itself, generation after generation, independently of selection. I use
0.5 in step 10 and 0.4 in step 11.

***m* is swapped as a unit, never blended.** It is rounded to an integer and sets the symmetry order, so
the average of *m* = 4 and *m* = 8 is a third unrelated shape rather than a mixture of its parents.

## 6. Mutation: a different operator per mode

The encoding is shared, but the modes run under very different conditions — 30 individuals over ~20
generations with noisy human ratings, versus 100 over hundreds of generations with a deterministic
fitness — so they do not want the same mutation.

**Step 11 — annealed Gaussian.** Rate 0.1, σ decaying geometrically from 0.15 to 0.03 over 25
generations, 5% of mutations being a full random reset. The schedule suits a short interactive session:
broad exploration while I am still deciding what I like, refinement once I have committed.

**Step 10 — self-adaptive Gaussian (ES).** Each individual carries its **own 14 σ values**, mutated
first and then used, so selection judges each step size together with the gene it produced:
σ' = σ·exp(t1·N + t2·Nj), with t1 = 1/√(2n), t2 = 1/√(2√n), n = 14, clamped to [0.02, 0.1]. Children
receive the average of their parents' σ. There is no mutation rate — every gene mutates, and the step
size replaces the rate as what controls how far children travel.

This cost me the most debugging time, and the lesson is that **self-adaptation is only half a
mechanism**. The log-normal update merely *proposes* step sizes; without a survivor selection stage that
discards most children, nothing disposes of the bad proposals. My original loop had λ = μ with nothing
discarded, so log σ random-walked the whole clamp range in about 50 generations and the best individual
froze for **1500 generations**. The μ = 50 truncation of §4 is what made self-adaptation actually adapt.
Separately, σ_max = 0.5 made every child effectively a fresh random individual (displacement 1.87 in a
14-dimensional unit cube), which showed as a large fitness cliff between first and second place.
Afterwards the mechanism was measurably working: mean σ settled at 0.040–0.044 against the 0.0497 that
log-uniform drift over the same range gives with no selection — selection was holding the step size ~17%
below its no-feedback value.

## 7. The target pipeline, not the search

Step 11 exported targets at 2000px while step 10 evaluates candidates at 128px. Measured after
downsampling, those targets had a **maximum** darkness of only 0.243–0.467 against 1.0 for the
tutorial's own glyphs: no pixel survived a 0.5 threshold, and `ink_threshold = 0.02` was the only reason
they registered at all. Worse, target and candidate reached the ink map by different routes — a 4px
stroke downsampled 15.6× versus a 1px stroke drawn natively at 128 — so their binarised line widths
differed and **an exact genome match could not have scored 1.0**. Part of what I had been reading as a
limit of the search was an artifact of the pipeline.

Exporting the target at the evaluation resolution is the change I believe mattered most, because it
raised the attainable ceiling rather than improving the search within it. I cannot separate its
contribution from the numbers I have: configuration B in §8 also changed μ, σ_min and the level weights,
and the weights in particular are expected to lift the 1×1 column. The claim I can defend is the
diagnosis, not a share of the gain. Before tuning a search, verify that the objective measures what you
think it measures.

## 8. Results

Raw per-level Dice for the best individual on a 5-layer target, under two configurations. The columns are
unweighted in both, so they are directly comparable.

| Config | Gen | 1×1 | 2×2 | 4×4 | 8×8 |
|---|---|---|---|---|---|
| A | 20 | 0.455 | 0.618 | 0.760 | 0.869 |
| A | 51 | 0.484 | 0.638 | 0.774 | 0.884 |
| A | 100 | 0.471 | 0.639 | 0.784 | 0.887 |
| B | 21 | 0.713 | 0.831 | 0.904 | 0.947 |
| B | 50 | 0.721 | 0.847 | 0.917 | 0.957 |
| B | 100 | 0.731 | 0.850 | 0.919 | 0.961 |

**A**: 2000px target, μ = 40, a lower σ_min, equal level weights. **B**: 128px target, μ = 50,
σ_min = 0.02, weights {1, 0.5, 0.25, 0.125}. Four changes at once, so the table shows that B is better
and not why; re-running B with each reverted in turn is the obvious next experiment. The within-run
observation that motivated §3's weighting — A's 1×1 falling from 0.484 to 0.471 while its total rose —
is unaffected by that confound.

## 9. Limitations

- **σ_min = 0.02 floors the total step at 0.02·√14 ≈ 0.075** in genome space, bounding how finely the
  population can refine; a polish phase with a lower floor should raise the final score.
- **The practical ceiling is unmeasured.** Exporting an individual and using it as its own target would
  separate "the GA cannot find it" from "the representation cannot express it".
- **The base + step encoding forces a linear layer progression**, so targets whose layers vary
  non-monotonically are unreachable by construction.
- All figures above are single runs, and the §8 configurations were never ablated; restart-to-restart
  variance was not characterised either.

## 10. Use of AI tools

I used Claude (Anthropic) in four ways. **Operator choices**: paired BLX-α, self-adaptive ES mutation
and linear ranking came out of discussion rather than being handed to me, and the σ update is from
*Introduction to Evolutionary Algorithms* (course material), which I was pointed to rather than given
the formula for. **Theory explanations** — why ranking beats raw fitness-proportional selection, what σ
does, why Dice rather than IoU or Fβ — which I then wrote up in my own words here. **Diagnosis**, where
it helped most: the frozen-best/survivor-selection link in §6 and the target artifact in §7 both came
out of that debugging. **Some code**: the status bar + run controls and the evaluator logic behind dice and the pyramid.

Not everything suggested was adopted or correct. I rejected windowing, an Fβ generalisation of Dice, and
the weighted confusion matrix of §3. Advice to widen the σ clamp to ~0.5 was wrong for my configuration
and directly produced the cliff in §6; the freeze was first attributed to parent selection before
survivor selection was identified; and a prediction that the coarse pyramid levels were saturated was
contradicted by my measurements. The Superformula adaptation, the encoding, both roulette
implementations, the interactive mode, all parameter tuning and all experiments reported here are my own
work.
