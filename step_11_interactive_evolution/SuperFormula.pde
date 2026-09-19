import processing.pdf.*; // Needed to export PDFs


// This class represents and encodes a superformula.
class SuperFormula {
  
  float[] genes = new float[14]; // Genes 0-6 are the base a, b, m, n1, n2, n3, size; genes 7-13 are how much each one changes per layer
  float fitness = 0; // Fitness value
  int num_layers = 1; // doesn't really matter the value here since fitness is chosen in the interface
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
    for (int i = 0; i < genes.length; i++) {
      genes[i] = random(0, 1);
    }
    phenotype = null;
  }

  // This methods keeps sigma between [0, 1]
  float reflect(float sigma){
    sigma = abs(sigma) % 2;
    if (sigma > 1) {return 2 - sigma;}
    else {return sigma;}
  }
  
  // One-point crossover operator
  SuperFormula onePointCrossover(SuperFormula partner) {
    SuperFormula child = new SuperFormula();
    int crossover_point = int(random(1, genes.length - 1));
    for (int i = 0; i < genes.length; i++) {
      if (i < crossover_point) {
        child.genes[i] = genes[i];
      } else {
        child.genes[i] = partner.genes[i];
      }
    }
    return child;
  }
  
  // Uniform crossover operator
  SuperFormula[] uniformCrossover(SuperFormula partner) {
    SuperFormula child1 = getCopy();
    SuperFormula child2 = partner.getCopy();

    for (int i = 0; i < genes.length; i++) {
      if (random(1) < 0.5) {
        Float geneTemp = child1.genes[i];
        child1.genes[i] = child2.genes[i];
        child2.genes[i] = geneTemp;
      }
    }
    return new SuperFormula[]{child1, child2};
  }
  
  // Mutation operator
  void mutate() {
    for (int i = 0; i < genes.length; i++) {
      if (random(1) <= mutation_rate) {
        //genes[i] = random(1); // Replace gene with a random one
        genes[i] = constrain(genes[i] + random(-0.1, 0.1), 0, 1); // Adjust the value of the gene
      }
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
    return canvas;
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
      float size = constrain(0.1 + genes[6] * 1.9 + i * (genes[13] - 0.5) * 2 * 1.9 / layer_denom, 0.1, 2);

      float[] p = {a, b, m, n1, n2, n3, size};

      float theta_max = (p[2] % 2 == 0) ? TWO_PI : 2 * TWO_PI; // Odd m only closes after two turns

      max_rad = 0;
      for (float theta = 0; theta < theta_max; theta += theta_step) {
        max_rad = Math.max(max_rad, r(theta, p));
      }
      
      scale = p[6] * min(w, h) / 2 / max_rad;

      ArrayList<PVector> points = new ArrayList<PVector>();
      for (float theta = 0; theta < theta_max; theta += theta_step) {
        float rad = (float) (r(theta, p) * scale);
        points.add(new PVector(rad * cos(theta), rad * sin(theta)));
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
    String output_path = sketchPath("outputs/" + output_filename);
    println("Exporting SuperFormula to: " + output_path);
    
    getPhenotype(2000).save(output_path + ".png");
    
    PGraphics pdf = createGraphics(500, 500, PDF, output_path + ".pdf");
    pdf.beginDraw();
    pdf.noFill();
    pdf.strokeWeight(pdf.height * 0.001);
    pdf.stroke(0);
    render(pdf, pdf.width / 2, pdf.height / 2, pdf.width, pdf.height);
    pdf.dispose();
    pdf.endDraw();
    
    String[] output_text_lines = new String[genes.length];
    for (int i = 0; i < genes.length; i++) {
      output_text_lines[i] = str(genes[i]);
    }
    saveStrings(output_path + ".txt", output_text_lines);
  }
}
