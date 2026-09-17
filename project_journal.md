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

## Notes
- everything about the drawing style needs implementing as a gene (stroke weight, stroke color, fill color, etc.) as prof said
- step_scale could be made evolvable later, if a fixed value turns out to limit the population