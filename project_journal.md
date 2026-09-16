# Project Journal

## Day 1

### Starting point
- Understood the project requirements and objectives.
- Set up the development environment for Processing but to use VSCode as a code editor, viewer and version control.

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

## Notes
- Ranges, layer count and step sizes still need tuning
