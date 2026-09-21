int population_size = 100;
int elite_size = 1;
int resolution = 128;
String path_target_image = "glyphs_1693591751539/test8.png";
int num_genes = 14;
int num_layers = 5;
// Selection
float selection_pressure = 1.8; // linear ranking pressure for the roulette wheel range [1, 2]
int mu = 50; // number of the best individuals allowed to breed
// Crossover
float crossover_rate = 0.5;
float alpha = 0.5; // blx-alpha paramater for the variation in between crossovers
// Mutation
float t1 = 1 / sqrt(2 * num_genes);
float t2 = 1 / sqrt(2 * sqrt(num_genes));
float sigma_min = 0.02;
float sigma_max = 0.1;

Population pop;
PVector[][] cells;
boolean phenotype_mode = true;
boolean show_fitness = true;
// Run control
boolean paused = false; // when true the population stops evolving, so a generation can be looked at
boolean step_once = false; // runs a single generation on the next frame, even while paused
// Status bar
int status_bar_h = 100; // strip at the bottom of the window holding the target and the run stats
PImage target_display; // the target image at full size, only for showing on screen
float label_size; // text size of the per-individual fitness labels

void settings() {
  if (displayWidth <= 0 || displayHeight <= 0){
     displayWidth = 1024;   
     displayHeight = 768;
  }
  size(int(displayWidth * 0.9), int(displayHeight * 0.8), P2D);
  smooth(8);
}

void setup() {
  pop = new Population();
  target_display = loadImage(path_target_image);
  cells = calculateGrid(population_size, 0, 0, width, height - status_bar_h, 30, 10, 30, true);
  label_size = constrain(cells[0][0].z * 0.15, 11, 14);
}

void draw() {
  // Evolve unless paused; [n] lets a single generation through while paused
  if (!paused || step_once) {
    pop.evolve();
    step_once = false;
  }
  background(phenotype_mode ? 235 : 0);
  float cell_dim = cells[0][0].z;
  int row = 0, col = 0;
  for (int i = 0; i < pop.getSize(); i++) {
    noFill();
    if (phenotype_mode) {
      image(pop.getIndiv(i).getPhenotype(resolution), cells[row][col].x, cells[row][col].y, cell_dim, cell_dim);
    } else {
      strokeWeight(max(cell_dim * 0.01, 1));
      stroke(255, 50);
      pop.getIndiv(i).renderPoints(getGraphics(), cells[row][col].x + cell_dim / 2, cells[row][col].y + cell_dim / 2, cell_dim, cell_dim);
    }
    if (show_fitness) {
      noStroke();
      fill(phenotype_mode ? 80 : 200);
      textAlign(CENTER, TOP);
      textSize(label_size);
      text(nf(pop.getIndiv(i).getFitness(), 0, 4), cells[row][col].x +cell_dim / 2, cells[row][col].y + cell_dim + 2);
    }
    col += 1;
    if (col >= cells[row].length) {
      row += 1;
      col = 0;
    }
  }
  drawStatusBar();
}

// Draw the bottom strip: the target the population is evolving towards, the run stats and the controls
void drawStatusBar() {
  float bar_y = height - status_bar_h;
  float thumb = status_bar_h - 24;

  noStroke();
  fill(phenotype_mode ? 215 : 20);
  rect(0, bar_y, width, status_bar_h);

  // The target, so it is visible next to the population instead of only being a filename
  image(target_display, 30, bar_y + 12, thumb, thumb);
  noFill();
  stroke(phenotype_mode ? 130 : 150);
  strokeWeight(1);
  rect(30, bar_y + 12, thumb, thumb);

  // Best and mean fitness: their ratio is how much spread selection still has to work with,
  // so a value close to 1 means the roulette wheel is close to picking uniformly at random
  float best = pop.getBestFitness();
  float mean = pop.getMeanFitness();
  float text_x = 30 + thumb + 20;

  noStroke();
  fill(phenotype_mode ? 60 : 200);
  textAlign(LEFT, TOP);
  textSize(13);
  text("Generation: " + pop.getGenerations() + "     Nº of layers: " + num_layers + (paused ? "     [PAUSED]" : ""), text_x, bar_y + 12);
  text("Best Fitness: " + nf(best, 0, 4) + "     Mean Fitness of the population: " + nf(mean, 0, 4), text_x, bar_y + 34);
  fill(phenotype_mode ? 120 : 140);
  text("[p] pause     [n] one generation     [r] restart     [e] export best     [space] points view     [f] fitness labels", text_x, bar_y + 64);
}

void keyReleased() {
  if (key == 'e') {
    pop.getIndiv(0).export();
  } else if (key == ' ') {
    phenotype_mode = !phenotype_mode;
  } else if (key == 'f') {
    show_fitness = !show_fitness;
  } else if (key == 'p') {
    paused = !paused;
  } else if (key == 'n') {
    step_once = true;
  } else if (key == 'r') {
    pop.initialize(); // restart from a fresh random population, generation counter included
  }
}

// Calculate grid of square cells
PVector[][] calculateGrid(int cells, float x, float y, float w, float h, float margin_min, float gutter_h, float gutter_v, boolean align_top) {
  int cols = 0, rows = 0;
  float cell_size = 0;
  while (cols * rows < cells) {
    cols += 1;
    cell_size = ((w - margin_min * 2) - (cols - 1) * gutter_h) / cols;
    rows = floor((h - margin_min * 2) / (cell_size + gutter_v));
  }
  if (cols * (rows - 1) >= cells) {
    rows -= 1;
  }
  float margin_hor_adjusted = ((w - cols * cell_size) - (cols - 1) * gutter_h) / 2;
  if (rows == 1 && cols > cells) {
    margin_hor_adjusted = ((w - cells * cell_size) - (cells - 1) * gutter_h) / 2;
  }
  float margin_ver_adjusted = ((h - rows * cell_size) - (rows - 1) * gutter_v) / 2;
  if (align_top) {
    margin_ver_adjusted = min(margin_hor_adjusted, margin_ver_adjusted);
  }
  PVector[][] positions = new PVector[rows][cols];
  for (int row = 0; row < rows; row++) {
    float row_y = y + margin_ver_adjusted + row * (cell_size + gutter_v);
    for (int col = 0; col < cols; col++) {
      float col_x = x + margin_hor_adjusted + col * (cell_size + gutter_h);
      positions[row][col] = new PVector(col_x, row_y, cell_size);
    }
  }
  return positions;
}
