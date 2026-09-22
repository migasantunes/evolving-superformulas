import processing.pdf.*; // Needed to export PDFs


// This class represents and encodes a superformula.
class SuperFormula {
  float[] genes = new float[num_genes]; // Genes 0-6 are the base a, b, m, n1, n2, n3, size; genes 7-13 are how much each one changes per layer
  float fitness = 0; // Fitness value
  float theta_step = 0.005; // before it was 0.01, after tuning it is 0.005, no runtime loss
  ArrayList<ArrayList<PVector>> layers = new ArrayList<ArrayList<PVector>>();
  PImage phenotype = null;
  
  // Create a random SuperFormula
  SuperFormula() {
    randomize();
  }
  
  // Create a SuperFormula with the given genes
  SuperFormula(float[] genes_init) {
    for (int i = 0; i < genes_init.length; i++) {
      genes[i] = genes_init[i];
    }
  }
  
  // Set all genes to random values 
  void randomize() {
    for (int i = 0; i < num_genes; i++) {
      genes[i] = random(0, 1);
    }
    phenotype = null;
  }

  // This methods keeps x between [0, 1]
  float reflect(float x){
    x = abs(x) % 2;
    if (x > 1) {return 2 - x;}
    else {return x;}
  }

  // BLX-alpha Crossover
  SuperFormula blxAlphaCrossover(SuperFormula partner) {
    SuperFormula child = new SuperFormula(genes);
    
    for (int gene = 0; gene < num_genes/2; gene++){
      if (gene == 2){ // gene m
        if (random(1) < 0.5){
          child.genes[gene] = genes[gene];
          child.genes[gene + num_genes/2] = genes[gene + num_genes/2];
        } else {
          child.genes[gene] = partner.genes[gene];
          child.genes[gene + num_genes/2] = partner.genes[gene + num_genes/2];
        }
        continue;
      }

      // for the rest of genes will go between [min_gene - alpha, max_gene + alpha]
      float range = random(-alpha, 1 + alpha);
      if (genes[gene] < partner.genes[gene]){
        child.genes[gene] = reflect(genes[gene] + range * (partner.genes[gene] - genes[gene])); // min + range * (max - min) --- same as when I calculate the parameters for the layers
        child.genes[gene + num_genes/2] = reflect(genes[gene + num_genes/2] + range * (partner.genes[gene + num_genes/2] - genes[gene + num_genes/2]));
      } else {
        child.genes[gene] = reflect(partner.genes[gene] + range * (genes[gene] - partner.genes[gene]));
        child.genes[gene + num_genes/2] = reflect(partner.genes[gene + num_genes/2] + range * (genes[gene + num_genes/2] - partner.genes[gene + num_genes/2]));
      }
    }

    return child;
  } 
  
  // Mutation operator
  void mutate(float sigma) {
    boolean mutated = false;

    for (int i = 0; i < num_genes; i++) {
      if (random(1) <= mutation_rate) {
        mutated = true;
        if (random(1) < reset_rate) { // chance of just reseting the gene, incase the population gets stuck
          genes[i] = random(1); 
          continue;
        }

        genes[i] = reflect(genes[i] + randomGaussian() * sigma); // Adjust the value of the gene
        
      }
    }

    if (!mutated){
      int i = int(random(num_genes));
      genes[i] = reflect(genes[i] + randomGaussian() * sigma);
    }
    phenotype = null;
  }
  
  // Set the fitness value
  void setFitness(float fitness) {
    this.fitness = fitness;
  }
  
  // Get the fitness value
  float getFitness() {
    return fitness;
  }
  
  // Get a clean copy
  SuperFormula getCopy() {
    SuperFormula copy = new SuperFormula(genes);
    copy.fitness = fitness;
    return copy;
  }
  
  // Get the phenotype (image)
  PImage getPhenotype(int resolution) {
    if (phenotype != null && phenotype.height == resolution) {
      return phenotype;
    }
    PGraphics canvas = createGraphics(resolution, resolution);
    canvas.beginDraw();
    canvas.background(255);
    canvas.noFill();
    canvas.stroke(0);
    canvas.strokeWeight(max(1, canvas.height * 0.002)); // floor of 1 pixel so the stroke doesn't go sub-pixel at low resolutions
    render(canvas, canvas.width / 2, canvas.height / 2, canvas.width, canvas.height);
    canvas.endDraw();
    phenotype = canvas.copy();
    return phenotype;
  }
  
  // Draw the superformula layers on a given canvas, at a given position and with a given size
  void render(PGraphics canvas, float x, float y, float w, float h) {
    calculatePoints(w, h);
    canvas.pushMatrix();
    canvas.translate(x, y);
    for (ArrayList<PVector> points : layers) {
      canvas.beginShape();
      for (PVector point : points) {
        canvas.vertex(point.x, point.y);
      }
      canvas.endShape(CLOSE);
    }
    canvas.popMatrix();
  }

  // Draw the superformula points on a given canvas, at a given position and with a given size
  void renderPoints(PGraphics canvas, float x, float y, float w, float h) {
    calculatePoints(w, h);
    canvas.pushMatrix();
    canvas.translate(x, y);
    for (ArrayList<PVector> points : layers) {
      for (PVector point : points) {
        canvas.point(point.x, point.y);
      }
    }
    canvas.popMatrix();
  }

  // Calculate the points of every layer of this superformula
  void calculatePoints(float w, float h) {
    double max_rad;
    double scale;
    layers.clear();

    float layer_denom = max(num_layers - 1, 1); // when num_layers == 1; this goes to a division by 0, to avoid it I flored it to 1

    for (int i = 0; i < num_layers; i++) {
      // Get a, b, m, n1, n2, n3, size of a given layer: each is base + layer * step, kept within [min, max]
      // with the step being: step = (gene - 0.5) * 2 * (max - min) / layer_denom
      float a  = constrain(0.1 + genes[0] * 4.9  + i * (genes[7]  - 0.5) * 2 * 4.9  / layer_denom, 0.1, 5);
      float b  = constrain(0.1 + genes[1] * 4.9  + i * (genes[8]  - 0.5) * 2 * 4.9  / layer_denom, 0.1, 5);
      float m  = constrain(round(1 + genes[2] * 20 + i * (genes[9] - 0.5) * 2 * 20 / layer_denom), 1, 21);
      float n1 = constrain(0.1 + genes[3] * 19.9 + i * (genes[10]  - 0.5) * 2 * 19.9 / layer_denom, 0.1, 20);
      float n2 = constrain(0.1 + genes[4] * 19.9 + i * (genes[11] - 0.5) * 2 * 19.9 / layer_denom, 0.1, 20);
      float n3 = constrain(0.1 + genes[5] * 19.9 + i * (genes[12] - 0.5) * 2 * 19.9 / layer_denom, 0.1, 20);
      float size = constrain(0.1 + genes[6] * 0.9 + i * (genes[13] - 0.5) * 2 * 0.9 / layer_denom, 0.1, 1.0);

      float[] p = {a, b, m, n1, n2, n3, size};

      float theta_max = (p[2] % 2 == 0) ? TWO_PI : 2 * TWO_PI; // Odd m only closes after two turns

      int capacity = (int) Math.ceil(theta_max / theta_step) + 2;
      double[] radii = new double[capacity];
      float[] thetas = new float[capacity];
      int num_points = 0;

      max_rad = 0;
      for (float theta = 0; theta < theta_max; theta += theta_step) {
        if (num_points >= capacity) break; // float drift could otherwise run past the array
        double rad = r(theta, p);
        thetas[num_points] = theta;
        radii[num_points] = rad;
        max_rad = Math.max(max_rad, rad);
        num_points++;
      }

      scale = p[6] * min(w, h) / 2 / max_rad;

      ArrayList<PVector> points = new ArrayList<PVector>();
      for (int s = 0; s < num_points; s++) {
        float rad = (float) (radii[s] * scale);
        points.add(new PVector(rad * cos(thetas[s]), rad * sin(thetas[s])));
      }
      layers.add(points);
    }
  }


  // Superformula radius at a given angle (in double, float has chance of overflowing)
  // Using Math.pow()/Math.abs()/Math.max() instead of Processing's pow()/abs()/max() because the it rejects doubles and I need to use them for the ranges of the params
  double r(float theta, float[] p) {
    double a = p[0], b = p[1], m = p[2], n1 = p[3], n2 = p[4], n3 = p[5];
    return Math.pow(Math.pow(Math.abs(Math.cos(m * theta / 4) / a), n2) + Math.pow(Math.abs(Math.sin(m * theta / 4) / b), n3), -1 / n1);
  }
  
  // Export image (png), vector (pdf) and genes (txt) of this SuperFormula
  void export() {
    String output_filename = year() + "-" + nf(month(), 2) + "-" + nf(day(), 2) + "-" + nf(hour(), 2) + "-" + nf(minute(), 2) + "-" + nf(second(), 2);
    export(sketchPath("outputs/" + output_filename));
  }

  // Same export, to a given path without extension (used by the session log)
  void export(String output_path) {
    println("Exporting SuperFormula to: " + output_path);
    
    getPhenotype(128).save(output_path + ".png");
    
    PGraphics pdf = createGraphics(500, 500, PDF, output_path + ".pdf");
    pdf.beginDraw();
    pdf.noFill();
    pdf.strokeWeight(pdf.height * 0.001);
    pdf.stroke(0);
    render(pdf, pdf.width / 2, pdf.height / 2, pdf.width, pdf.height);
    pdf.dispose();
    pdf.endDraw();
    
    String[] titles = {"a", "b", "m", "n1", "n2", "n3", "size", "a_step", "b_step", "m_step", "n1_step", "n2_step", "n3_step", "size_step"};
    String[] output_text_lines = new String[num_genes];
    for (int i = 0; i < num_genes; i++) {
      output_text_lines[i] = titles[i] + ": " + str(genes[i]);
    }
    saveStrings(output_path + ".txt", output_text_lines);
  }
}
