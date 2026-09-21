int population_size = 30;
int resolution = 256; 
int num_layers = 5;
int num_genes = 14;
// Selection
float unrated_weight = 0.1; // share of the wheel an unrated individual gets
// Crossover
float crossover_rate = 0.5;
float alpha = 0.4; // blx-alpha paramater for the variation in between crossovers
// Mutation
float mutation_rate = 0.1;
float reset_rate = 0.05;
int horizonG = 25; // horizon for the annealed gaussian mutation
float sigma_max = 0.15; // max for the annealed gaussian mutation
float sigma_min = 0.03; // min for the annealed gaussian mutation
// Elitism
int elite_fitness = 10;
int elite_max = 3;
int elite_min = 1;

Population pop;
PVector[][] cells;
SuperFormula hovered_indiv = null;

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
  cells = calculateGrid(population_size, 0, 0, width, height - 30, 30, 10, 30, true);
  textSize(constrain(cells[0][0].z * 0.15, 11, 14));
}

void draw() {
  background(235);
  hovered_indiv = null; // Temporarily clear selected individual
  int row = 0, col = 0;
  for (int i = 0; i < pop.getSize(); i++) {
    float x = cells[row][col].x;
    float y = cells[row][col].y;
    float d = cells[row][col].z;
    // Check if current individual is hovered by the cursor
    noStroke();
    fill(0);
    if (mouseX > x && mouseX < x + d && mouseY > y && mouseY < y + d) {
      hovered_indiv = pop.getIndiv(i);
      rect(x - 1, y - 1, d + 2, d + 2);
    }
    if (pop.getIndiv(i).getFitness() > 0) {
      rect(x - 3, y - 3, d + 6, d + 6);
    }
    // Draw phenotype of current individual
    image(pop.getIndiv(i).getPhenotype(resolution), x, y, d, d);
    // Draw fitness of current individual
    fill(0);
    textAlign(CENTER, TOP);
    text(int(pop.getIndiv(i).getFitness()), x + d / 2, y + d + 5);
    // Go to next grid cell
    col += 1;
    if (col >= cells[row].length) {
      row += 1;
      col = 0;
    }
  }

  // Draw text presenting controls
  fill(128);
  textSize(14);
  textAlign(LEFT, BOTTOM);
    text("Controls:     [1-9] set Fitness     [left-click/UP] Fitness +1     [right-click/DOWN] Fitness -1     [RIGHT] Fitness = 10     [LEFT] Fitness = 0\n" +
      "                       [enter] evolve     [r] reset     [e] export individ hovered by the cursor", 30, height - 30);
}

void keyReleased() {
  if (keyCode == ENTER || keyCode == RETURN) {
    // Press key [enter] to evolve new generation
    pop.evolve();
  } else if (key == ' ') {
    // Evolve (generate new population)
    pop.evolve();
  } else if (key == 'r') {
    // Reset population
    pop.initialize();
  } else if (key == 'e') {
    // Export selected individual
    if (hovered_indiv != null) {
      hovered_indiv.export();
    }
  } else {
    if (hovered_indiv != null) {
      // Change fitness of the selected (hovered) individual
      float fit = hovered_indiv.getFitness();
      if (keyCode == UP) {
        fit = min(fit + 1, 10);
      } else if (keyCode == DOWN) {
        fit = max(fit - 1, 0);
      } else if (keyCode == RIGHT) {
        fit = 10;
      } else if (keyCode == LEFT) {
        fit = 0;
      // added number keys to set fitness directly it's easier for testing
      } else if (key == '1') {
        fit = 1;
      } else if (key == '2') {
        fit = 2;
      } else if (key == '3') {
        fit = 3;
      } else if (key == '4') {
        fit = 4;
      } else if (key == '5') {
        fit = 5;
      } else if (key == '6') {
        fit = 6;
      } else if (key == '7') {
        fit = 7;
      } else if (key == '8') {
        fit = 8;
      } else if (key == '9') {
        fit = 9;
      }
      hovered_indiv.setFitness(fit);
    }
  }
}

void mouseReleased() {
  // Set fitness of clicked individual to +1 
  if (hovered_indiv != null) {
    float fit = hovered_indiv.getFitness();
    if (mouseButton == LEFT) {
      hovered_indiv.setFitness(min(fit + 1, 10));
    } else if (mouseButton == RIGHT) {
      hovered_indiv.setFitness(max(fit - 1, 0));
    }
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
