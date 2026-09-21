# Project Journal

## Day 1

### Starting point
- Understood the project requirements and objectives.
- Set up the development environment for Processing but I am using VSCode as a code editor, viewer and version control.

### Learning the project structure and implementing the Superformula in step 1
- Changed the project struture from harmonographs to superformulas on step 1
- Changed step 1 to now have white background with black stroke, with still noFill

### Implementing the Superformula in automatic evolution
- Adapted the already existing Harmonograph class to the SuperFormula class
- Started by implementing one layer of the Superformula w/ a params list of only the 6 parameters of the Superformula
- Switched Population and Evaluator to work with SuperFormula instead of Harmonograph

### Deciding how to encode the genes
- Kept the genes normalised in [0, 1] as in the original Harmonograph, and put each parameter's real range in the genotype to phenotype mapping, so crossover and mutation don't need to know what each gene means
- Ranges used: a and b from 0.1 to 5, m integer from 1 to 21, n1, n2 and n3 from 0.1 to 20
- Only restricted the ranges where a value would be invalid or degenerate (division by zero in a and b, the -1/n1 exponent, m having to be an integer to close the curve), and left the rest to the fitness function instead of guessing which shapes look good
- The 0.1 floor keeps every radius inside what a double can hold; below it the shapes are already thinner than a pixel at the 128px evaluation size

### Writing calculatePoints
- Reused the superformula equation from step 1 as an r() method
- Replaced step 1's fixed * 50 scale with a normalisation: a first pass finds the biggest radius and a second pass scales the figure to the canvas, since evolved genes give radii of very different magnitudes and the canvas size changes (128px for fitness, 2000px for export)
- Calculated the radius in double: in float the value overflows for extreme parameter combinations
- Found that an odd m only closes after two turns, because the cos and sin terms swap after the first one, so each layer sweeps 2PI or 4PI depending on its m
- Used endShape(CLOSE), because the loop stops just before the last angle and the gap would show at export size

### Adding the layers
- Went with 5 layers, following the nested drawings of step 1
- Changed the genome to 12 genes: 6 base values plus 6 steps, where layer i uses base + i * step, so the layer count doesn't change the number of genes and the layers stay related to each other
- Each layer's values are clamped to the valid ranges, so a negative step can't push a parameter out of its range in the outer layers
- Normalised all layers together with a single scale, otherwise each layer would fill the canvas and the nesting would disappear
- points became a list of point lists, and render() draws each layer as its own shape

## Day 2

### Realising the shape could only ever touch the canvas edge
- Noticed that normalising every genome to fill the canvas meant the population could never contain a shape sitting small with margins, or one that overflows and gets cropped at the edges, even though the target image likely has margins that no edge-touching shape could match
- Added a size gene (gene 12) so how big the shape is relative to the canvas is evolvable instead of fixed, changing scale from size * min(w,h) / 2 / max_rad, with size mapped from the gene to roughly 0.15x-2x the canvas

### Finding that a shared scale between layers hides most of them
- Realised that normalising all 5 layers with one shared scale means each layer's size relative to the others comes only from its raw radius, and those raw radii can differ by many orders of magnitude between layers
- Decided each layer needs its own size, using the same base + step pattern as the other parameters (a 7th value per layer, genes 7 & 13), and normalising each layer separately instead of all together;

### Tuning ranges, layer count and step sizes
- Swept a/b max and n1/n2/n3 max: left them at 5 and 20 
- Swept size min/max: left at 0.1-2, which gives a good range of small and large shapes after this, becomes less important
- Settled on 6 layers: more gives better results in testing, but it gets too slow past that

### Fixing the sub-pixel fitness stroke
- canvas.strokeWeight(canvas.height * 0.002) makes sub-pixel strokes at low resolutions, which causes bad fitness readings, instead, I capped it at max(1, canvas.height * 0.002) so it never goes below 1px, which is the minimum for a solid black stroke

### Fixing a NaN bug with a single layer
- num_layers = 1 always gave a blank canvas because of division by zero in the step term (i / (num_layers - 1))
- Fixed by flooring the denominator at 1 (layer_denom = max(num_layers - 1, 1));

### Understanding the "double lines" per layer
- Noticed the rendered shape had exactly 2x as many visible lines as layers (12 for 6 layers, 14 for 7), which traced back to the odd-m quirk from Day 1: odd m needs two full turns to close, and during each turn the radius is different at the same angle, so it looks like two overlapping loops per layer even though it's coded as a single closed shape
- Confirmed it isn't a bug by running with the strokeWeight set to 10px where m came out even for every layer, which correctly gave exactly num_layers lines
- Suspected the GA was converging on odd m quickly because it's a genuine fitness advantage rather than a shortcut in the encoding/fitness function
- Decided not to restrict m to even values: that would remove every odd-fold-symmetric shape

### Brainstormed making step_scale evolvable
- Considered adding a step_scale gene so each individual could set its own ceiling on how much its layers diverge from each other, on top of the per-parameter step genes that already exist, similar to self-adaptive step sizes in evolution strategies
- Decided against it for now: it would need its own range tuned, which is the same problem just solved for the other genes, and there's no evidence yet that one fixed step ceiling is limiting the population; parked as a future task, to revisit only if evidence shows a fixed ceiling is a bottleneck

## Day 3

### Adapting the interactive evolution (step 11) to the SuperFormula
- Took SuperFormula from step 10, but kept step 11's Population and main code, but adapted each to work with SuperFormula
- Added phenotype caching (PImage cleared in randomize() and mutate()), took Harmonograph as an example.
- Changed uniformCrossover to return two children
- Switched mutation from replacing a gene to nudging it by +/-0.1
- Restored the max(1, canvas.height * 0.002) stroke floor from Day 2, lost while copying the class over

### Changing the fitness from 0/1 to 1-10
- Kept 0 as "unrated" so the existing fitness > 0 checks keep working
- Controls: keys 1-9 set the rating, UP/DOWN +/-1, RIGHT sets 10, LEFT clears, left click +1, right click -1
- Displayed the rating as an integer

### Replacing tournament with roulette selection
- Created the rouletteSelection() method, and replaced tournamentSelectionV2() with it in the crossover branch, and tournamentSelection() with it in the non-crossover branch

### Writing the roulette selection
- First attempt gave each individual its own coin flip of fitness / total while walking the array, which isn't proportional (10 vs 4 came out ~90%/10%) because whoever passes its flip first is taken, and evolve() sorts the population so the best was always first
- Shuffling before walking still isn't proportional, so I dropped the coin-flip approach
- Used the standard wheel: one random number between 0 and totalFitness, accumulate fitness, return the first individual where hit < addedFit
- Guarded total == 0 (evolving without rating anything) with a random individual

## Day 4

### Choosing the operators
- Same crossover in both modes, since the encoding is the same; different mutation, since the conditions differ (30 individuals / ~20 generations / noisy human ratings vs 100 / hundreds / deterministic RMSE)

### Crossover: paired BLX-alpha (both steps)
- One mixing fraction in [-alpha, 1+alpha] per (base, step) pair, used for both genes, so the child gets a layer progression between the parents' instead of one parent's base glued to the other's step
- m (genes 2 and 9) is swapped as a unit, never blended: it's rounded to an int and sets the symmetry, so the average of m=4 and m=8 is a different shape, not a mix
- alpha has to be >= 0.366, otherwise the operator shrinks the variance by itself (child variance = v/2 + (1+2*alpha)^2 * v/6); used 0.4 in step 11 and 0.5 in step 10
- Out-of-range values are reflected instead of clamped at 0 and 1
- Mutation stays per gene, not per pair

### Mutation in step 11: annealed Gaussian
- Rate = 0.1, and the uniform nudge became a Gaussian step scaled by sigma: mostly small, occasionally large
- sigma decays exponentially from 0.15 to 0.03 over 25 generations
- 5% of mutations are a random reset
- If no gene mutated, one is forced

### Elitism in step 11: threshold
- Keeps up to 3 individuals rated 10, or the single best if it was rated at all, or none if nothing was rated

### Mutation in step 10: self-adaptive Gaussian (ES)
- One sigma per gene, stored in the individual; the sigma is mutated first and the gene then moves by that new sigma, so selection judges the step size together with the gene
- sigma' = sigma * exp(t1\*N + t2\*Nj), with t1 = 1/sqrt(2n) and t2 = 1/sqrt(2*sqrt(n)), n = 14; Found in Introduction_to_Evolution_Algorithms.pdf
- sigma clamped to [0.01, 0.5]
- Every gene mutates, so mutation_rate is gone from step 10; the step size replaces it and selection tunes it
- Children get the average of the parents' sigmas
- Replacement stays generational with an elite of 1

## Day 5

### Replacing RMSE with a multi-scale Dice coefficient
- Thin targets kept evolving to an empty canvas with a high fitness, so I was thinking the cause was the RMSE
- Replaced it with a multi-scale Dice coefficient (pyramid), which is a better measure of shape similarity than RMSE, and is less sensitive to the target's sparsity
- The Dice coefficient is calculated at multiple scales and averaged, which helps to capture the shape at different levels of detail

### Speeding up the render
- calculatePoints swept theta twice per layer, once for max_rad and once to build the points, so r() was paid twice for every point; now it sweeps once and keeps the radii (both steps)
- Step 10 had no phenotype cache, so every individual was drawn twice per generation, once for the fitness and once for draw(); copied the cache from step 11
- The 1px stroke floor was an RMSE-era workaround; with binarised ink maps it no longer matters (0.993 correlation with it, 0.992 without), kept it because it makes the ink map depend only on geometry

## Day 6

### Globals and tidying
- Moved num_layers, num_genes and the sigma clamps into the main sketches; num_layers was a per-instance field duplicated in both steps and it is the value I change most
- Addressed the step half of the genome as gene + num_genes/2 instead of gene + 7, so adding genes later won't break the crossover
- Named the genes in the export .txt and removed the unused crossover and tournament methods

### Roulette in step 11: 0 means "not rated", not "bad"
- Used unrated_weight to give a small chance to individuals rated 0, so they can be selected to breed: inicially at 0.5 but now to to 0.1; with 30 canvas on the screen I can actually look at all of them, so unrated means rejected
- If I left it at 0.0 and only one individual is rated, the next generation would be all the same genes, because of BLX-alpha. That looks like a problem, but thanks to mutations it will still differentiate by a small amount

### Roulette in step 10: ranks instead of raw fitness
- Switched the wheel to linear ranking, w(i) = (2 - sp) + 2(sp - 1)(n - 1 - i)/(n - 1) with sp = 1.8;
- Thought about windowing (subtracting the worst fitness) at first, but it over-amplifies once the spread is tiny

### UI improvements
- Added a status bar with the target image, generation, layer count, best and mean fitness, and keys [p] pause, [n] iterate one generation, [r] restart

### Mutation was drowning selection
- sigma_max at 0.5 changes too much, so every child was effectively a random individual 
- Best then froze for 1500 generations, because there was no survivor selection: self-adaptive sigma is calibrated for (mu, lambda) truncation that discards most children, and with lambda = mu = 99 and nothing discarded log(sigma) just random-walks the clamp range in about 50 generations
- Restricted the parent pool to the best mu of the sorted population, which turns the generational loop into (mu, lambda) at no extra evaluation cost; truncating at 20% is selection intensity 1.40 against 0.45 for ranking alone
- Swept mu: 20 and 30 converged too early, settled on 50

## Day 7

### The target was the problem, not the search
- Step 11 exported targets at 2000px while step 10 evaluated candidates at 128px, causing mismatched resolution and line widths that limited the maximum Dice score.
- Exporting the target at 128px improved the best individual's full-resolution Dice score.

### Weighting the pyramid levels
- Weighted the pyramid levels toward higher resolutions because equal weights let the GA trade full-resolution pixel accuracy for cheaper gains at coarse scales, whose scores already had little headroom
- Weighted the levels by 1/k = {1, 0.5, 0.25, 0.125}, normalised by the weight sum