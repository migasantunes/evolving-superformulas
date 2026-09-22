// Headless experiment runner for step 10.
//
// It extends the class Processing generates from step_10_automatic_evolution (see build.py), so it
// reuses Population, Evaluator and SuperFormula exactly as they are in the sketch, and every global
// keeps the sketch's value unless an argument overrides it. No window is ever opened: only offscreen
// JAVA2D graphics (and the PDF renderer) are used, so it runs without a display.
//
// Modes (--mode, default "run"):
//   run         evolve and log one run                  --target --seed --gens --out [ablation args]
//   make_target random genome -> PNG at 128 and 2000px   --seed --out
//   selfscore   genome against its 128 and 2000px render --genome --target128 --target2000 --out
//   score       RMSE / Dice of a genome (or "blank")     --target --genome
//   points      polyline of a genome, for vector figures --genome --size --out
//   render      PNG of a genome as the evaluator sees it  --genome --size --out
//
// Ablation args (run mode), each one change from the baseline:
//   --selection ranking|raw   raw = fitness-proportional roulette on raw fitness
//   --mu N                    size of the breeding pool (population_size = no truncation)
//   --sigma_fixed S           sigma_min = sigma_max = S, so there is no self-adaptation
//   --fitness dice|rmse       rmse = 1 - RMSE on grey levels
//   --weights default|equal   pyramid level weights

import processing.core.*;
import processing.awt.PGraphicsJava2D;
import java.io.*;
import java.util.*;

public class Runner extends step_10_automatic_evolution {

  Map<String, String> opts = new HashMap<String, String>();
  String selection = "ranking";
  String fitness_kind = "dice";
  String weights_kind = "default";

  public static void main(String[] args) {
    System.setProperty("java.awt.headless", "true");
    Runner r = new Runner();
    // createGraphics() consults the sketch's main renderer; give it an offscreen JAVA2D one, no window
    PGraphicsJava2D main_g = new PGraphicsJava2D();
    main_g.setParent(r);
    main_g.setPrimary(false);
    main_g.setSize(1, 1);
    r.g = main_g;
    // file loading refuses to run before setup() unless the (private) sketch path is set
    try {
      java.lang.reflect.Field f = PApplet.class.getDeclaredField("sketchPath");
      f.setAccessible(true);
      f.set(r, System.getProperty("user.dir"));
    } catch (Exception e) {
      throw new RuntimeException(e);
    }
    r.parseArgs(args);
    String mode = r.opt("mode", "run");
    if (mode.equals("run")) r.runExperiment();
    else if (mode.equals("make_target")) r.makeTarget();
    else if (mode.equals("selfscore")) r.selfScore();
    else if (mode.equals("score")) r.scoreGenome();
    else if (mode.equals("points")) r.writePoints();
    else if (mode.equals("render")) r.renderGenome();
    else throw new IllegalArgumentException("unknown mode " + mode);
    System.exit(0);
  }

  void parseArgs(String[] args) {
    for (int i = 0; i < args.length; i++) {
      if (!args[i].startsWith("--")) throw new IllegalArgumentException("bad arg " + args[i]);
      String k = args[i].substring(2);
      String v = (i + 1 < args.length && !args[i + 1].startsWith("--")) ? args[++i] : "true";
      opts.put(k, v);
    }
  }

  String opt(String k, String def) {
    return opts.containsKey(k) ? opts.get(k) : def;
  }

  String req(String k) {
    if (!opts.containsKey(k)) throw new IllegalArgumentException("missing --" + k);
    return opts.get(k);
  }

  // ---------------------------------------------------------------- run

  void applyGlobals() {
    if (opts.containsKey("mu")) mu = Integer.parseInt(opts.get("mu"));
    if (opts.containsKey("sigma_fixed")) {
      sigma_min = Float.parseFloat(opts.get("sigma_fixed"));
      sigma_max = sigma_min;
    }
    if (opts.containsKey("layers")) num_layers = Integer.parseInt(opts.get("layers"));
    selection = opt("selection", "ranking");
    fitness_kind = opt("fitness", "dice");
    weights_kind = opt("weights", "default");
  }

  void runExperiment() {
    applyGlobals();
    path_target_image = new File(req("target")).getAbsolutePath();
    int seed = Integer.parseInt(req("seed"));
    int gens = Integer.parseInt(req("gens"));
    File out = new File(req("out"));
    out.mkdirs();
    Set<Integer> snaps = new TreeSet<Integer>();
    for (String s : opt("snaps", "0,25,100").split(",")) snaps.add(Integer.parseInt(s.trim()));
    snaps.add(gens);

    long t0 = System.nanoTime();
    PImage target = loadImage(path_target_image);
    Evaluator ref = new Evaluator(target, resolution); // the baseline fitness, used for best_dice_ref in every config

    ExpPopulation p = new ExpPopulation(); // its constructor evaluates a throwaway population ...
    Evaluator ev = fitness_kind.equals("rmse") ? new RmseEvaluator(target, resolution) : new Evaluator(target, resolution);
    if (weights_kind.equals("equal")) ev.level_weights = new float[] {1, 1, 1, 1};
    p.evaluator = ev;
    pop = p;
    randomSeed(seed);
    p.initialize(); // ... so the seeded run starts here

    PrintWriter csv = createWriter(new File(out, "log.csv").getAbsolutePath());
    csv.println("gen,best_fitness,best_dice_ref,best_dice_k1,mean_fitness,mean_sigma");
    for (int g = 0; g <= gens; g++) {
      if (g > 0) p.evolve();
      SuperFormula best = p.getIndiv(0);
      PImage ph = best.getPhenotype(resolution);
      float dref = weightedDice(ref, ph);
      float dk1 = ref.dice(ref.target_pyramid[0], ref.getInk(ph));
      csv.println(g + "," + best.getFitness() + "," + dref + "," + dk1 + "," + p.getMeanFitness() + "," + meanSigma(p));
      if (snaps.contains(g)) snapshot(best, new File(out, "gen_" + nf(g, 3)).getAbsolutePath());
    }
    csv.close();
    double secs = (System.nanoTime() - t0) / 1e9;
    PrintWriter meta = createWriter(new File(out, "meta.txt").getAbsolutePath());
    meta.println("target: " + path_target_image);
    meta.println("seed: " + seed);
    meta.println("gens: " + gens);
    meta.println("selection: " + selection);
    meta.println("mu: " + mu);
    meta.println("sigma_min: " + sigma_min);
    meta.println("sigma_max: " + sigma_max);
    meta.println("fitness: " + fitness_kind);
    meta.println("weights: " + Arrays.toString(ev.level_weights));
    meta.println("num_layers: " + num_layers);
    meta.println("runtime_s: " + secs);
    meta.close();
    System.out.println("done " + out + " in " + String.format("%.1f", secs) + "s");
  }

  float meanSigma(Population p) {
    double s = 0;
    for (int i = 0; i < p.getSize(); i++) {
      for (int j = 0; j < num_genes; j++) s += p.getIndiv(i).sigmas[j];
    }
    return (float) (s / (p.getSize() * num_genes));
  }

  // Same computation as Evaluator.calculateFitness, but for any image (needed for the blank canvas)
  float weightedDice(Evaluator e, PImage img) {
    float[][] pyr = e.buildPyramid(e.getInk(img));
    float sim = 0, tw = 0;
    for (int l = 0; l < e.levels.length; l++) {
      sim += e.level_weights[l] * e.dice(e.target_pyramid[l], pyr[l]);
      tw += e.level_weights[l];
    }
    return sim / tw;
  }

  // PNG at 512px, PDF and genome, written like SuperFormula.export() but to a chosen path.
  // A fresh copy is rendered so the individual's cached 128px phenotype is left untouched.
  void snapshot(SuperFormula indiv, String path) {
    SuperFormula s = new SuperFormula(indiv.genes, indiv.sigmas);
    s.getPhenotype(512).save(path + ".png");
    PGraphics pdf = createGraphics(500, 500, PDF, path + ".pdf");
    pdf.beginDraw();
    pdf.noFill();
    pdf.strokeWeight(pdf.height * 0.001f);
    pdf.stroke(0);
    s.render(pdf, pdf.width / 2, pdf.height / 2, pdf.width, pdf.height);
    pdf.dispose();
    pdf.endDraw();
    saveStrings(path + ".txt", genomeLines(indiv, "fitness: " + indiv.getFitness()));
  }

  String[] genomeLines(SuperFormula s, String extra) {
    String[] titles = {"a", "b", "m", "n1", "n2", "n3", "size", "a_step", "b_step", "m_step", "n1_step", "n2_step", "n3_step", "size_step"};
    ArrayList<String> lines = new ArrayList<String>();
    for (int i = 0; i < num_genes; i++) lines.add(titles[i] + ": " + s.genes[i]);
    for (int i = 0; i < num_genes; i++) lines.add("sigma_" + titles[i] + ": " + s.sigmas[i]);
    if (extra != null) lines.add(extra);
    return lines.toArray(new String[0]);
  }

  // Reads the .txt written by export() in either sketch (sigmas optional)
  SuperFormula loadGenome(String path) {
    float[] g = new float[num_genes];
    float[] sg = new float[num_genes];
    Arrays.fill(sg, 0.02f);
    int gi = 0, si = 0;
    for (String line : loadStrings(new File(path).getAbsolutePath())) {
      String[] kv = line.split(":");
      if (kv.length != 2) continue;
      String k = kv[0].trim();
      if (k.equals("fitness")) continue;
      if (k.startsWith("sigma_")) { if (si < num_genes) sg[si++] = Float.parseFloat(kv[1].trim()); }
      else if (gi < num_genes) g[gi++] = Float.parseFloat(kv[1].trim());
    }
    if (gi != num_genes) throw new RuntimeException("genome " + path + " has " + gi + " genes");
    return new SuperFormula(g, sg);
  }

  // ---------------------------------------------------------------- other modes

  void makeTarget() {
    File out = new File(req("out"));
    out.mkdirs();
    String prefix = opt("name", "tsyn");
    randomSeed(Integer.parseInt(req("seed")));
    SuperFormula s = new SuperFormula();
    saveStrings(new File(out, prefix + ".txt").getAbsolutePath(), genomeLines(s, null));
    new SuperFormula(s.genes, s.sigmas).getPhenotype(128).save(new File(out, prefix + "_128.png").getAbsolutePath());
    new SuperFormula(s.genes, s.sigmas).getPhenotype(2000).save(new File(out, prefix + "_2000.png").getAbsolutePath());
    System.out.println("target written to " + out);
  }

  void selfScore() {
    SuperFormula s = loadGenome(req("genome"));
    PrintWriter w = createWriter(new File(req("out")).getAbsolutePath());
    w.println("target,dice_ref,dice_k1,rmse");
    for (String key : new String[] {"target128", "target2000"}) {
      PImage t = loadImage(new File(req(key)).getAbsolutePath());
      Evaluator e = new Evaluator(t, resolution);
      PImage ph = new SuperFormula(s.genes, s.sigmas).getPhenotype(resolution);
      float d = e.calculateFitness(new SuperFormula(s.genes, s.sigmas));
      float d2 = weightedDice(e, ph);
      if (abs(d - d2) > 1e-6f) throw new RuntimeException("weightedDice differs from calculateFitness");
      float k1 = e.dice(e.target_pyramid[0], e.getInk(ph));
      float rm = rmse(t, ph);
      w.println(key + "," + d + "," + k1 + "," + rm);
      // what the evaluator actually sees after its resize, for the figure
      PImage seen = t.copy();
      seen.resize(resolution, resolution);
      seen.save(new File(new File(req("out")).getParentFile(), key + "_as_seen.png").getAbsolutePath());
    }
    w.close();
  }

  void scoreGenome() {
    PImage t = loadImage(new File(req("target")).getAbsolutePath());
    Evaluator e = new Evaluator(t, resolution);
    PImage ph;
    String g = req("genome");
    if (g.equals("blank")) {
      PGraphics c = createGraphics(resolution, resolution);
      c.beginDraw();
      c.background(255);
      c.endDraw();
      ph = c.copy();
    } else {
      ph = loadGenome(g).getPhenotype(resolution);
    }
    System.out.println("rmse,dice_ref,dice_k1");
    System.out.println(rmse(t, ph) + "," + weightedDice(e, ph) + "," + e.dice(e.target_pyramid[0], e.getInk(ph)));
  }

  void writePoints() {
    SuperFormula s = loadGenome(req("genome"));
    float size = Float.parseFloat(opt("size", "512"));
    s.calculatePoints(size, size);
    PrintWriter w = createWriter(new File(req("out")).getAbsolutePath());
    for (ArrayList<PVector> layer : s.layers) {
      StringBuilder sb = new StringBuilder();
      for (PVector p : layer) sb.append(String.format(Locale.ROOT, "%.2f %.2f ", p.x, p.y));
      w.println(sb.toString().trim());
    }
    w.close();
  }

  void renderGenome() {
    SuperFormula s = loadGenome(req("genome"));
    s.getPhenotype(Integer.parseInt(opt("size", "128"))).save(new File(req("out")).getAbsolutePath());
  }

  // Root mean squared error on grey levels in [0, 1], both images at the evaluation resolution
  float rmse(PImage target, PImage ph) {
    float[] a = grey(target), b = grey(ph);
    double s = 0;
    for (int i = 0; i < a.length; i++) s += (a[i] - b[i]) * (a[i] - b[i]);
    return (float) Math.sqrt(s / a.length);
  }

  float[] grey(PImage img) {
    PImage c = img.copy();
    if (c.width != resolution || c.height != resolution) c.resize(resolution, resolution);
    c.loadPixels();
    float[] v = new float[c.pixels.length];
    for (int i = 0; i < v.length; i++) v[i] = (c.pixels[i] & 0xFF) / 255.0f; // same channel as getInk
    return v;
  }

  // ---------------------------------------------------------------- variants

  class ExpPopulation extends Population {
    public SuperFormula rouletteSelectionLinearRanking() {
      if (!selection.equals("raw")) return super.rouletteSelectionLinearRanking();
      // Fitness-proportional roulette on raw fitness over the best mu individuals
      int n = min(mu, individuals.length);
      float total = 0;
      for (int i = 0; i < n; i++) total += individuals[i].getFitness();
      if (total <= 0) return individuals[(int) random(n)];
      float hit = random(total);
      float added = 0;
      for (int i = 0; i < n; i++) {
        added += individuals[i].getFitness();
        if (hit < added) return individuals[i];
      }
      return individuals[n - 1];
    }
  }

  // The pre-Dice fitness: 1 - RMSE between grey levels
  class RmseEvaluator extends Evaluator {
    float[] target_grey;

    RmseEvaluator(PImage image, int res) {
      super(image, res);
      target_grey = grey(image);
    }

    public float calculateFitness(SuperFormula indiv) {
      float[] b = grey(indiv.getPhenotype(res));
      double s = 0;
      for (int i = 0; i < b.length; i++) s += (target_grey[i] - b[i]) * (target_grey[i] - b[i]);
      return 1 - (float) Math.sqrt(s / b.length);
    }
  }
}
